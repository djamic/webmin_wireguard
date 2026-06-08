#!/usr/bin/perl
require './wireguard-lib.pl';

&ReadParse();
&require_post();
my $iface = $in{'iface'};
&error($text{'invalid_interface'}) if !&valid_interface($iface);

if (!$in{'cancel'}) {
    &generate_client_peer($iface, {
        name => $in{'name'},
        dns => $in{'dns'},
        months => $in{'months'},
        network_mode => $in{'network_mode'},
        networks => $in{'networks'},
        other_networks => $in{'other_networks'},
    });
}

&redirect("index.cgi?mode=list&msg=" . &urlize($text{'peer_added'}));
