#!/usr/bin/perl
require './wireguard-lib.pl';

&ReadParse();
my $iface = $in{'iface'};
&error($text{'invalid_interface'}) if !&valid_interface($iface);

&print_header("$text{'add_peer'} $iface");

print &ui_form_start("save_peer.cgi", "post");
print &ui_hidden("iface", $iface);
print &ui_table_start($text{'add_peer'}, undef, 2);
print &ui_table_row($text{'interface'}, &html_escape($iface));
print &ui_table_row($text{'peer_name'}, &ui_textbox("name", "", 40));
print &ui_table_row($text{'default_client_dns'}, &ui_textbox("dns", &default_client_dns(), 40));
print &ui_table_end();
print &ui_form_end([
    [ undef, $text{'generate_peer'} ],
    [ 'cancel', $text{'cancel'} ],
]);

&print_footer();
