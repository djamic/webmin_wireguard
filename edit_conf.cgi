#!/usr/bin/perl
require './wireguard-lib.pl';

&ReadParse();
my $iface = $in{'iface'};
&error($text{'invalid_interface'}) if !&valid_interface($iface);

&print_header("$text{'edit'} $iface");

print &ui_form_start("save_conf.cgi", "post");
print &ui_hidden("iface", $iface);
print &ui_table_start($text{'raw_config'}, undef, 2);
print &ui_table_row($text{'interface'}, &html_escape($iface));
print &ui_table_row($text{'raw_config'}, &ui_textarea("config", &read_iface_config($iface), 24, 100));
print &ui_table_end();
print &ui_form_end([
    [ undef, $text{'save'} ],
    [ 'cancel', $text{'cancel'} ],
]);

&print_footer();
