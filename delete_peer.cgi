#!/usr/bin/perl
require './wireguard-lib.pl';

&ReadParse();
&require_post();
my $iface = $in{'iface'};
my $public_key = $in{'public_key'};
&error($text{'invalid_interface'}) if !&valid_interface($iface);

my $name = &peer_name_for_key($iface, $public_key);
&remove_peer_live($iface, $public_key);
&delete_peer_by_public_key($iface, $public_key);
if ($name) {
    my $file = &client_config_file($name);
    unlink($file) if -f $file;
}
&redirect("index.cgi?msg=" . &urlize($text{'peer_deleted'}));
