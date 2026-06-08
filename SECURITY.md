# Security

This module manages WireGuard as root through Webmin. Only grant access to
trusted Webmin administrators.

## Notes

- Destructive peer actions are submitted with POST forms.
- Generated client configs are limited to known peer names.
- Peer keys, DNS values, command paths, directories, ports, and allowed IP
  inputs are validated.
- Generated client configuration downloads are sent with no-store headers.
- Expired peers are disabled by `/etc/cron.d/wireguard_webmin`.
- A Webmin user with access to this module can edit raw WireGuard config and
  should be treated as root-equivalent.

## Reporting

Please report security issues privately before publishing details.
