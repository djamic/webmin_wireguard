#!/usr/bin/perl
require './wireguard-lib.pl';

&ReadParse();
my $name = &sanitize_peer_name($in{'name'});
&error($text{'missing_peer_name'}) if !$name;
&error($text{'client_config_missing'}) if !&peer_name_exists($name);
my $file = &client_config_file($name);
&error($text{'client_config_missing'}) if !-f $file;

print "Content-Type: application/octet-stream\n";
print "Content-Disposition: attachment; filename=\"$name.conf\"\n";
print "X-Content-Type-Options: nosniff\n\n";
print &read_file_contents($file);
