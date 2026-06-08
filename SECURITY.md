# Security

This module manages WireGuard as root through Webmin. Only grant access to
trusted Webmin administrators.

## Notes

- Destructive peer actions are submitted with POST forms.
- Generated client configs are limited to known peer names.
- Peer keys, DNS values, command paths, and CIDR inputs are validated.
- Expired peers are disabled by `/etc/cron.d/wireguard_webmin`.

## Reporting

Please report security issues privately before publishing details.
