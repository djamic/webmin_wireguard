#!/usr/bin/perl
require './wireguard-lib.pl';

&ReadParse();
&require_post();

my @selected = split(/\0/, $in{'d'});
if ($in{'delete'} || $in{'enable'} || $in{'disable'}) {
    foreach my $item (@selected) {
        my ($iface, $public_key) = split(/\|/, $item, 3);
        next if !&valid_interface($iface) || !$public_key;
        if ($in{'enable'}) {
            &set_peer_enabled($iface, $public_key, 1);
        }
        elsif ($in{'disable'}) {
            &set_peer_enabled($iface, $public_key, 0);
        }
        elsif ($in{'delete'}) {
            my $name = &peer_name_for_key($iface, $public_key);
            &remove_peer_live($iface, $public_key);
            &delete_peer_by_public_key($iface, $public_key);
            if ($name) {
                my $file = &client_config_file($name);
                unlink($file) if -f $file;
            }
        }
    }
}

&redirect("index.cgi?mode=list&msg=" . &urlize($text{'peer_deleted'}));
