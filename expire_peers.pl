#!/usr/bin/perl
BEGIN {
    $ENV{'WEBMIN_CONFIG'} ||= "/etc/webmin";
    $ENV{'WEBMIN_VAR'} ||= "/var/webmin";
    chdir("/usr/share/webmin/wireguard_webmin");
    push(@INC, "..");
}
require './wireguard-lib.pl';

&disable_expired_peers();
