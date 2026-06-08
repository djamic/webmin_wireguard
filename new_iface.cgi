#!/usr/bin/perl
require './wireguard-lib.pl';

&print_header($text{'new_interface'});

print &ui_form_start("save_iface.cgi", "post");
print &ui_table_start($text{'new_interface'}, undef, 2);
print &ui_table_row($text{'interface'}, &ui_textbox("iface", "wg0", 20));
print &ui_table_row($text{'private_key'}, &ui_textbox("private_key", "", 80) . "<br>" . $text{'generate_private_key'});
print &ui_table_row($text{'address'}, &ui_textbox("address", "10.0.0.1/24", 40));
print &ui_table_row($text{'listen_port'}, &ui_textbox("listen_port", "51820", 10));
print &ui_table_row($text{'post_up'}, &ui_textbox("post_up", "", 100));
print &ui_table_row($text{'post_down'}, &ui_textbox("post_down", "", 100));
print &ui_table_end();
print &ui_form_end([
    [ undef, $text{'save'} ],
    [ 'cancel', $text{'cancel'} ],
]);

&print_footer();
