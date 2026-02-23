#!/usr/bin/env bash

set -e

COUNTRY=""

# --- Parse flags ---
while getopts "c:" opt; do
  case $opt in
    c) COUNTRY="$OPTARG" ;;
    *) echo "Usage: $0 [-c country_code]"; exit 1 ;;
  esac
done

echo "[+] Updating packages..."
apt update -y

echo "[+] Installing dependencies..."
apt install -y docker.io iptables ipset wget curl

systemctl enable --now docker

# --- Generate secure credentials ---
echo "[+] Generating VPN credentials..."

VPN_IPSEC_PSK=$(openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c 32)
VPN_USER="vpn$(openssl rand -hex 3)"
VPN_PASSWORD=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 20)

# --- Remove old container if exists ---
docker rm -f l2tp-vpn 2>/dev/null || true

echo "[+] Starting VPN container..."

docker run -d \
  --name l2tp-vpn \
  --restart=unless-stopped \
  --privileged \
  -e VPN_IPSEC_PSK="$VPN_IPSEC_PSK" \
  -e VPN_USER="$VPN_USER" \
  -e VPN_PASSWORD="$VPN_PASSWORD" \
  -p 500:500/udp \
  -p 4500:4500/udp \
  -p 1701:1701/udp \
  hwdsl2/ipsec-vpn-server >/dev/null

echo "[+] Waiting for container to initialize..."
sleep 8

# --- Firewall Kill Switch Setup ---
echo "[+] Configuring firewall kill-switch..."

iptables -F
iptables -t nat -F

iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP

# Allow loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Allow established sessions
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow Docker bridge network
iptables -A INPUT -i docker0 -j ACCEPT
iptables -A OUTPUT -o docker0 -j ACCEPT

# Allow VPN ports inbound
iptables -A INPUT -p udp --dport 500 -j ACCEPT
iptables -A INPUT -p udp --dport 4500 -j ACCEPT
iptables -A INPUT -p udp --dport 1701 -j ACCEPT

# Allow outbound for IPsec negotiation
iptables -A OUTPUT -p udp --sport 500 -j ACCEPT
iptables -A OUTPUT -p udp --sport 4500 -j ACCEPT
iptables -A OUTPUT -p udp --sport 1701 -j ACCEPT

# Allow traffic through VPN tunnel interface (ppp+ wildcard)
iptables -A INPUT -i ppp+ -j ACCEPT
iptables -A OUTPUT -o ppp+ -j ACCEPT

# Allow DNS outbound (optional but useful)
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

# --- Country Blocking ---
if [ -n "$COUNTRY" ]; then
  echo "[+] Blocking country: $COUNTRY"

  ipset create blocked_country hash:net 2>/dev/null || true
  ipset flush blocked_country

  TMPFILE=$(mktemp)

  if wget -qO "$TMPFILE" "https://www.ipdeny.com/ipblocks/data/countries/${COUNTRY}.zone"; then
      while read -r ip; do
          ipset add blocked_country "$ip" 2>/dev/null || true
      done < "$TMPFILE"

      iptables -A INPUT -m set --match-set blocked_country src -j DROP
      iptables -A OUTPUT -m set --match-set blocked_country dst -j DROP

      echo "[+] Country block applied."
  else
      echo "[!] Failed to download country list, skipping geo-block."
  fi

  rm -f "$TMPFILE"
fi

# --- Persist firewall ---
echo "[+] Saving firewall rules..."
iptables-save > /etc/iptables.rules

cat >/etc/network/if-pre-up.d/iptables <<'EOF'
#!/bin/sh
iptables-restore < /etc/iptables.rules
EOF

chmod +x /etc/network/if-pre-up.d/iptables

# --- Detect public IP ---
SERVER_IP=$(curl -s ifconfig.me || echo "SERVER_IP")

echo ""
echo "======================================"
echo "        VPN SETUP COMPLETE"
echo "======================================"
echo "Server IP: $SERVER_IP"
echo "IPsec PSK: $VPN_IPSEC_PSK"
echo "Username : $VPN_USER"
echo "Password : $VPN_PASSWORD"
echo "======================================"
echo ""
echo "[+] Save these credentials securely."
