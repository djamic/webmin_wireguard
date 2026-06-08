#!/usr/bin/perl
require './wireguard-lib.pl';

&ReadParse();
&disable_expired_peers();
&print_header($text{'index_title'});

my @ifaces = &list_interfaces();
print &ui_buttons_start();
print &ui_buttons_row("../config.cgi?wireguard_webmin", $text{'config_title'}, "");
print &ui_buttons_end();

my @tabs = (
    [ "list", $text{'tab_interfaces'}, "index.cgi?mode=list" ],
    [ "create", $text{'tab_create'}, "index.cgi?mode=create" ],
);
my $mode = $in{'mode'} || "list";
$mode = "list" if $mode ne "list" && $mode ne "create";
print &ui_tabs_start(\@tabs, "mode", $mode, 1);

print &ui_tabs_start_tab("mode", "list");

if (!@ifaces) {
    print &ui_subheading($text{'interfaces'});
    print "<p>$text{'no_interfaces'}</p>\n";
}
else {
    my @headers = (
        "",
        $text{'interface'},
        $text{'status'},
        $text{'enabled'},
        $text{'peer_name'},
        $text{'peer_status'},
        $text{'expires'},
        $text{'access_networks'},
        $text{'public_key_short'},
        $text{'allowed_ips'},
        $text{'endpoint'},
        $text{'client_config'},
        $text{'actions'},
    );
    my @data;

    foreach my $iface (@ifaces) {
        my $status = &iface_status_text($iface);
        my $conf = &read_iface_config($iface);
        my @peers = &list_peers($conf);
        my %handshakes = &latest_handshakes($iface);
        my $iface_actions =
            "<a href='edit_conf.cgi?iface=" . &urlize($iface) . "'>$text{'edit'}</a> " .
            "<a href='add_peer.cgi?iface=" . &urlize($iface) . "'>$text{'add_peer'}</a> " .
            "<a href='start.cgi?iface=" . &urlize($iface) . "'>$text{'start'}</a> " .
            "<a href='stop.cgi?iface=" . &urlize($iface) . "'>$text{'stop'}</a> " .
            "<a href='restart.cgi?iface=" . &urlize($iface) . "'>$text{'restart'}</a>";

        if (!@peers) {
            push(@data, [
                "",
                &html_escape($iface),
                $status,
                "-",
                "-",
                "-",
                "-",
                "-",
                "-",
                "-",
                "-",
                "-",
                $iface_actions,
            ]);
            next;
        }

        for (my $i = 0; $i < @peers; $i++) {
            my $peer = $peers[$i];
            my $key = $peer->{'public_key'};
            my $short = substr($key, 0, 12) . "...";
            my $name = $peer->{'name'} ? $peer->{'name'} : "-";
            my $config_status = $peer->{'disabled'} ? $text{'disabled'} : $text{'enabled'};
            my $runtime_status = $peer->{'disabled'} ? $text{'disabled'} : &peer_status_text($handshakes{$key});
            my $client_allowed = $peer->{'client_allowed_ips'} || "0.0.0.0/0, ::/0";
            my $client_file = $peer->{'name'} ? &client_config_file($peer->{'name'}) : "";
            my $download = $client_file && -f $client_file ?
                "<a href='download_conf.cgi?name=" . &urlize($peer->{'name'}) . "'>$text{'download'}</a>" : "-";
            my $peer_actions = "";

            push(@data, [
                { 'type' => 'checkbox', 'name' => 'd', 'value' => $iface . "|" . $key . "|" . ($peer->{'name'} || "") },
                $i == 0 ? &html_escape($iface) : "",
                $i == 0 ? $status : "",
                $config_status,
                &html_escape($name),
                $runtime_status,
                &expiry_text($peer->{'expires'}),
                &html_escape($client_allowed),
                &html_escape($short),
                &html_escape($peer->{'allowed_ips'} || "-"),
                &html_escape($peer->{'endpoint'} || "-"),
                $download,
                ($i == 0 ? $iface_actions : "") . $peer_actions,
            ]);
        }
    }

    print &ui_form_columns_table(
        "peer_action.cgi",
        [ [ "enable", $text{'enable_selected_peers'} ],
          [ "disable", $text{'disable_selected_peers'} ],
          [ "delete", $text{'delete_selected_peers'} ] ],
        1, [ ], [ ], \@headers, 100, \@data);
}
print &ui_tabs_end_tab();

print &ui_tabs_start_tab("mode", "create");
print &ui_form_start("save_peer.cgi", "post");
print &ui_table_start($text{'generate_client'}, "width=100%", 2);
print &ui_table_row($text{'interface'}, &ui_select("iface", $ifaces[0], [ map { [ $_, $_ ] } @ifaces ]));
print &ui_table_row($text{'peer_name'}, &ui_textbox("name", "", 40));
print &ui_table_row($text{'default_client_dns'}, &ui_textbox("dns", &default_client_dns(), 40));
print &ui_table_row($text{'duration'}, &ui_select("months", 0,
    [ [ 0, $text{'unlimited'} ],
      map { [ $_, $_ . " " . $text{'months'} ] } (1..12) ]));
my @nets = &list_route_networks();
my $net_select = "<select name='networks' multiple size='10'>\n" .
    join("", map { "<option value='" . &html_escape($_->[0]) . "'>" .
        &html_escape($_->[0] . ($_->[1] ? " (" . $_->[1] . ")" : "")) . "</option>\n" } @nets) .
    "</select>";
print &ui_table_row($text{'access_networks'},
    &ui_radio("network_mode", "all",
        [ [ "all", $text{'all_networks'} . "<br>" ],
          [ "selected", $text{'selected_networks'} . "<br>" ] ]) .
    $net_select . "<br>" .
    $text{'other_networks'} . ": " . &ui_textbox("other_networks", "", 70));
print &ui_table_end();
print &ui_form_end([ [ undef, $text{'generate_peer'} ] ]);
print &ui_tabs_end_tab();

print &ui_tabs_end(1);

&print_footer();
