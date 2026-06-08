#!/usr/bin/perl
require './wireguard-lib.pl';

&ReadParse();
&require_post();
my $iface = $in{'iface'};
my $public_key = $in{'public_key'};
&error($text{'invalid_interface'}) if !&valid_interface($iface);
&set_peer_enabled($iface, $public_key, 1);
&redirect("index.cgi?mode=list");
