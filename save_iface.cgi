#!/usr/bin/perl
require './wireguard-lib.pl';

&ReadParse();
&require_post();
my $iface = $in{'iface'};
&error($text{'invalid_interface'}) if !&valid_interface($iface);

if (!$in{'cancel'}) {
    &create_interface($iface, {
        private_key => $in{'private_key'},
        address => $in{'address'},
        listen_port => $in{'listen_port'},
        post_up => $in{'post_up'},
        post_down => $in{'post_down'},
    });
}

&redirect("index.cgi?msg=" . &urlize($text{'interface_created'}));
