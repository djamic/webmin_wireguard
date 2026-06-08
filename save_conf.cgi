#!/usr/bin/perl
require './wireguard-lib.pl';

&ReadParse();
&require_post();
my $iface = $in{'iface'};
&error($text{'invalid_interface'}) if !&valid_interface($iface);

if (!$in{'cancel'}) {
    &write_iface_config($iface, $in{'config'});
}

&redirect("index.cgi?msg=" . &urlize($text{'saved'}));
