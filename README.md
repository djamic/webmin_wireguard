# Webmin WireGuard VPN Module

Webmin module for managing WireGuard interfaces and clients from the Webmin
UI.

## Features

- List WireGuard interfaces from `/etc/wireguard`
- Generate client peers with private key, public key, and preshared key
- Create downloadable client config files
- Enable, disable, or delete selected peers
- Automatically disable expired peers with cron
- Choose client access networks during generation
- Show latest handshake status for each peer
- Start, stop, and restart `wg-quick@interface`
- Edit raw interface configuration
- Configure paths and defaults from Webmin module configuration

## Install From Webmin

In Webmin, open **Webmin -> Webmin Configuration -> Webmin Modules** and
install from this URL:

```text
https://raw.githubusercontent.com/djamic/webmin_wireguard/main/dist/wireguard_webmin.wbm.gz
```

Then open **Servers -> WireGuard VPN**.

## Install From Source

From this directory:

```sh
sudo ./install.sh
```

You can also build a Webmin module archive:

```sh
./build.sh
```

The output is `wireguard_webmin.wbm.gz`.

## Notes

Webmin must run with permissions that can read and write the WireGuard
configuration directory and manage `wg-quick@...` services.

Generated client configs are stored in `/root` by default. Change
`client_config_dir` from Webmin module configuration if needed.

This module is intended for trusted Webmin administrators only.
