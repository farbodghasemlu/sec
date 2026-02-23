# Secure Remote Access Bootstrap (Docker-Based)

## Overview

This repository contains a **one-command bootstrap script** that prepares a Linux host for secure remote connectivity using containerized networking components.

It is intended for:

- fresh server deployments
- private remote access setups
- hardened network entry points
- reproducible infrastructure provisioning
- self-hosted secure connectivity nodes

The script installs dependencies, launches the networking container, configures restrictive firewall policies, and optionally blocks traffic from specific geographic regions.

---

## What the Script Does

### 1. Installs Required Components

The script installs and configures:

- Docker runtime
- packet filtering utilities
- IP set management tools
- download helpers and networking utilities

This ensures the host can run containerized networking services and enforce traffic policy rules.

---

### 2. Deploys the Containerized Access Service

A prebuilt container providing encrypted remote connectivity is started automatically.

During setup the script generates:

- a strong shared secret
- a randomized account name
- a secure password

No manual credential configuration is required.

---

### 3. Applies a Restrictive Firewall Policy

The script configures a deny-by-default host firewall.

Only essential traffic is allowed, including:

- service negotiation ports
- container bridge traffic
- loopback traffic
- established sessions
- encrypted tunnel interface traffic

This prevents unintended traffic leakage if networking fails or the service stops.

---

### 4. Optional Geographic Traffic Blocking

You can optionally block a country’s address ranges.

Blocking applies to:

- inbound traffic
- outbound traffic

Address lists are downloaded at runtime from public allocation sources.

---

### 5. Ensures Firewall Persistence

All firewall rules are saved and automatically restored after reboot.

---

### 6. Outputs Access Credentials

When setup completes successfully, the script prints:

- server public IP
- shared secret
- username
- password

Store these values securely — they will not be shown again automatically.

---

## Requirements

- Ubuntu 20.04 / 22.04 / 24.04 server
- root or sudo access
- internet-reachable host
- required UDP ports open in provider firewall

---

## Installation

Clone the repository:

```bash
git clone https://github.com/farbodghasemlu/sec.git
cd sec
```

Make the script executable:

```bash
chmod +x src/setup.sh
```

## Usage
Basic setup

```bash
sudo ./src/setup.sh
```

### Setup with geographic blocking

Example: block SWITZERLAND

```bash
sudo ./src/setup.sh -c ch
```

Country codes must be ISO-3166 lowercase.

## Security Notes

This script provides a hardened baseline, but you should still:
- rotate credentials periodically
- keep the host updated
- disable unused services
- restrict SSH access
- monitor logs for unusual activity
- limit the number of authorized users

## Uninstalling

To remove the container:

```bash
docker rm -f l2tp-vpn
```

To clear firewall rules:

```bash
iptables -F
iptables -t nat -F
```

To remove persisted rules:

```bash
rm /etc/iptables.rules
rm /etc/network/if-pre-up.d/iptables
```

## Disclaimer

This project is provided as-is for administrative and educational purposes.

Always review security configurations before deploying on production infrastructure.

License

MIT License (see LICENSE file)
