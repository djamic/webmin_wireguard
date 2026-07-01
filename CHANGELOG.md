# Changelog

## 1.0.2

- Removed the invalid `depends=core` module dependency that prevented Webmin's
  module installer from installing the package.

## 1.0.1

- Fixed the Webmin module package layout so Webmin's module installer sees
  `wireguard_webmin/module.info` instead of treating support directories as
  separate modules.
- Added Webmin post-install and uninstall hooks for the peer expiry cron job
  when installing from the Webmin UI.

## 1.0.0

- First stable public package.
- Webmin Servers menu integration.
- Interface list with peer status, expiry, access networks, and downloads.
- Peer filtering by enabled, disabled, online, idle, and never.
- Peer generation with duration and network selection.
- Enable, disable, delete, and expiry mechanisms for peers.
- Security hardening for command paths, directories, peer keys, ports,
  allowed IPs, downloads, and package contents.

## 0.1.0

- Initial Webmin module for WireGuard.
- Interface list and service controls.
- Peer generation, download, enable, disable, delete.
- Peer expiry and access network selection.
