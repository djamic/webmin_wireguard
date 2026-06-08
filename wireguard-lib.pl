BEGIN { push(@INC, ".."); }
use warnings;
use WebminCore;

our (%config, %text);

&init_config();
umask(077);

sub wg_config_dir {
    return &safe_dir_path($config{'wireguard_dir'} || "/etc/wireguard");
}

sub wg_cmd {
    return &safe_command_path($config{'wg_cmd'} || "/usr/bin/wg");
}

sub systemctl_cmd {
    return &safe_command_path($config{'systemctl_cmd'} || "/usr/bin/systemctl");
}

sub client_config_dir {
    return &safe_dir_path($config{'client_config_dir'} || "/root");
}

sub default_client_dns {
    return $config{'default_client_dns'} || "8.8.8.8, 8.8.4.4";
}

sub expire_check_minutes {
    return $config{'expire_check_minutes'} || 5;
}

sub valid_interface {
    my ($iface) = @_;
    return defined($iface) && $iface =~ /\A[A-Za-z0-9_.-]+\z/;
}

sub safe_command_path {
    my ($path) = @_;
    &error("Invalid command path") if !$path || $path !~ m!\A/[A-Za-z0-9_./+-]+\z!;
    &error("Invalid command path") if $path =~ m!(?:^|/)\.\.(?:/|$)!;
    return $path;
}

sub safe_dir_path {
    my ($path) = @_;
    &error("Invalid directory path") if !$path || $path !~ m!\A/[A-Za-z0-9_./+-]+\z!;
    &error("Invalid directory path") if $path =~ m!(?:^|/)\.\.(?:/|$)!;
    $path =~ s!/+\z!! if $path ne "/";
    return $path;
}

sub ip_cmd {
    return "/usr/sbin/ip" if -x "/usr/sbin/ip";
    return "/usr/bin/ip" if -x "/usr/bin/ip";
    return "";
}

sub shell_quote {
    my ($value) = @_;
    $value = "" if !defined($value);
    $value =~ s/'/'"'"'/g;
    return "'$value'";
}

sub valid_public_key {
    my ($key) = @_;
    return defined($key) && $key =~ /\A[A-Za-z0-9+\/]{43}=\z/;
}

sub clean_single_line {
    my ($value) = @_;
    $value = "" if !defined($value);
    $value =~ s/[\r\n]//g;
    return $value;
}

sub clean_config_value {
    my ($value, $label) = @_;
    $value = "" if !defined($value);
    &error("Invalid $label") if $value =~ /[\r\n]/;
    return $value;
}

sub validate_dns {
    my ($dns) = @_;
    $dns = &clean_single_line($dns || &default_client_dns());
    &error("Invalid DNS value") if $dns !~ /\A[0-9A-Fa-f:., \t]+\z/;
    return $dns;
}

sub valid_cidr {
    my ($net) = @_;
    return defined($net) && $net =~ /\A(?:(?:25[0-5]|2[0-4]\d|1?\d?\d)\.){3}(?:25[0-5]|2[0-4]\d|1?\d?\d)\/(?:[0-9]|[12][0-9]|3[0-2])\z/;
}

sub valid_ipv6_cidr {
    my ($net) = @_;
    return defined($net) &&
        $net =~ /\A[0-9A-Fa-f:]+\/(?:[0-9]|[1-9][0-9]|1[01][0-9]|12[0-8])\z/ &&
        index($net, ":") >= 0;
}

sub valid_allowed_ip {
    my ($net) = @_;
    return &valid_cidr($net) || &valid_ipv6_cidr($net);
}

sub validate_allowed_ips {
    my ($allowed_ips, $label) = @_;
    $allowed_ips = &clean_config_value($allowed_ips, $label || "allowed IPs");
    my @nets = grep { $_ ne "" } split(/[,\s]+/, $allowed_ips);
    &error($text{'missing_allowed_ips'}) if !@nets;
    foreach my $net (@nets) {
        &error("Invalid network: " . &html_escape($net)) if !&valid_allowed_ip($net);
    }
    return join(", ", @nets);
}

sub valid_port {
    my ($port) = @_;
    return defined($port) && $port =~ /\A\d+\z/ && $port > 0 && $port <= 65535;
}

sub require_post {
    &error($text{'post_required'}) if ($ENV{'REQUEST_METHOD'} || "") ne "POST";
}

sub confirm_service_action_or_run {
    my ($action, $done_msg) = @_;
    &ReadParse();
    my $iface = $in{'iface'};
    &error($text{'invalid_interface'}) if !&valid_interface($iface);
    if (($ENV{'REQUEST_METHOD'} || "") eq "POST") {
        &redirect("index.cgi?mode=list") if $in{'cancel'};
        &run_service_action($iface, $action);
        &redirect("index.cgi?msg=" . &urlize($done_msg));
    }

    &print_header(ucfirst($action) . " $iface");
    print &ui_confirmation_form(
        "$action.cgi",
        &html_escape("Are you sure you want to $action $iface?"),
        [ [ "iface", $iface ] ],
        [ [ undef, ucfirst($action) ], [ "cancel", $text{'cancel'} ] ]);
    &print_footer();
}

sub sanitize_peer_name {
    my ($name) = @_;
    $name ||= "";
    $name =~ s/[^0-9A-Za-z_-]/_/g;
    $name = substr($name, 0, 15);
    return $name;
}

sub iface_file {
    my ($iface) = @_;
    &error($text{'invalid_interface'}) if !&valid_interface($iface);
    return &wg_config_dir() . "/" . $iface . ".conf";
}

sub list_interfaces {
    my $dir = &wg_config_dir();
    return () if !-d $dir;

    opendir(my $dh, $dir) || return ();
    my @ifaces;
    while (my $file = readdir($dh)) {
        next if $file !~ /\A(.+)\.conf\z/;
        my $iface = $1;
        next if !&valid_interface($iface);
        push(@ifaces, $iface);
    }
    closedir($dh);
    return sort @ifaces;
}

sub read_iface_config {
    my ($iface) = @_;
    my $file = &iface_file($iface);
    return "" if !-f $file;
    return &read_file_contents($file);
}

sub write_iface_config {
    my ($iface, $contents) = @_;
    my $file = &iface_file($iface);
    &open_tempfile(CONF, ">$file");
    &print_tempfile(CONF, $contents);
    &close_tempfile(CONF);
    chmod(0600, $file);
}

sub generate_private_key {
    my $cmd = &wg_cmd();
    &error("wg was not found") if !-x $cmd;
    my $key = &backquote_command("$cmd genkey 2>&1");
    &error("<pre>" . &html_escape($key) . "</pre>") if $?;
    $key =~ s/\s+\z//;
    return $key;
}

sub create_interface {
    my ($iface, $opts) = @_;
    &error($text{'invalid_interface'}) if !&valid_interface($iface);
    my $file = &iface_file($iface);
    &error($text{'interface_exists'}) if -e $file;

    my $private_key = &clean_config_value($opts->{'private_key'}, "private key") || &generate_private_key();
    &error("Invalid private key") if !&valid_public_key($private_key);
    my $address = &clean_config_value($opts->{'address'}, "address");
    $address = &validate_allowed_ips($address, "address") if $address;
    my $listen_port = &clean_config_value($opts->{'listen_port'}, "listen port");
    &error("Invalid listen port") if $listen_port && !&valid_port($listen_port);
    my $post_up = &clean_config_value($opts->{'post_up'}, "PostUp");
    my $post_down = &clean_config_value($opts->{'post_down'}, "PostDown");

    my $conf = "[Interface]\n";
    $conf .= "PrivateKey = $private_key\n";
    $conf .= "Address = $address\n" if $address;
    $conf .= "ListenPort = $listen_port\n" if $listen_port;
    $conf .= "PostUp = $post_up\n" if $post_up;
    $conf .= "PostDown = $post_down\n" if $post_down;
    &write_iface_config($iface, $conf);
}

sub iface_is_running {
    my ($iface) = @_;
    return 0 if !&valid_interface($iface);
    my $cmd = &systemctl_cmd();
    return 0 if !-x $cmd;
    my $out = &backquote_command("$cmd is-active wg-quick\@$iface 2>/dev/null");
    return $out =~ /\Aactive\b/ ? 1 : 0;
}

sub iface_status_text {
    my ($iface) = @_;
    return &iface_is_running($iface) ? $text{'running'} : $text{'stopped'};
}

sub wg_show {
    my ($iface) = @_;
    return "" if !&valid_interface($iface);
    my $cmd = &wg_cmd();
    return "" if !-x $cmd;
    return &backquote_command("$cmd show $iface 2>&1");
}

sub latest_handshakes {
    my ($iface) = @_;
    my %handshakes;
    return %handshakes if !&valid_interface($iface);
    my $cmd = &wg_cmd();
    return %handshakes if !-x $cmd;

    my $out = &backquote_command("$cmd show $iface latest-handshakes 2>/dev/null");
    foreach my $line (split(/\n/, $out)) {
        my ($key, $timestamp) = split(/\s+/, $line);
        next if !$key || !defined($timestamp);
        next if !&valid_public_key($key) || $timestamp !~ /\A\d+\z/;
        $handshakes{$key} = int($timestamp);
    }
    return %handshakes;
}

sub peer_status_text {
    my ($timestamp) = @_;
    return $text{'never'} if !$timestamp;

    my $age = time() - $timestamp;
    $age = 0 if $age < 0;
    my $state = $age <= 180 ? $text{'online'} : $text{'idle'};
    return $state . "<br><small>" . $text{'last_seen'} . ": " . &html_escape(&format_timestamp($timestamp)) . "</small>";
}

sub peer_filter_state {
    my ($peer, $timestamp) = @_;
    return "disabled" if $peer->{'disabled'};
    return "never" if !$timestamp;

    my $age = time() - $timestamp;
    $age = 0 if $age < 0;
    return $age <= 180 ? "online" : "idle";
}

sub peer_matches_filter {
    my ($peer_state, $show_only) = @_;
    $show_only ||= "all";
    return 1 if $show_only eq "all";
    return $peer_state ne "disabled" if $show_only eq "enabled";
    return $peer_state eq $show_only;
}

sub format_timestamp {
    my ($timestamp) = @_;
    my @t = localtime($timestamp);
    return sprintf("%04d-%02d-%02d %02d:%02d",
        $t[5] + 1900, $t[4] + 1, $t[3], $t[2], $t[1]);
}

sub expiry_text {
    my ($timestamp) = @_;
    return $text{'unlimited'} if !$timestamp;
    my $label = &format_timestamp($timestamp);
    $label .= " (" . $text{'expired'} . ")" if $timestamp <= time();
    return &html_escape($label);
}

sub run_service_action {
    my ($iface, $action) = @_;
    &error($text{'invalid_interface'}) if !&valid_interface($iface);
    &error("Invalid action") if $action !~ /\A(?:start|stop|restart)\z/;
    my $cmd = &systemctl_cmd();
    &error("systemctl was not found") if !-x $cmd;
    my $out = &backquote_logged("$cmd $action wg-quick\@$iface 2>&1");
    &error("<pre>" . &html_escape($out) . "</pre>") if $?;
    return $out;
}

sub append_peer {
    my ($iface, $peer) = @_;
    &error($text{'missing_public_key'}) if !$peer->{'public_key'};
    &error($text{'missing_allowed_ips'}) if !$peer->{'allowed_ips'};
    &error($text{'missing_public_key'}) if !&valid_public_key($peer->{'public_key'});
    &error("Invalid preshared key") if $peer->{'preshared_key'} && !&valid_public_key($peer->{'preshared_key'});

    my $conf = &read_iface_config($iface);
    $conf =~ s/\s+\z/\n/s;
    $conf .= "\n" if $conf ne "" && $conf !~ /\n\n\z/s;
    my $name = $peer->{'name'} || "";
    $name =~ s/[\r\n]//g;
    my $allowed_ips = &validate_allowed_ips($peer->{'allowed_ips'}, "allowed IPs");
    my $client_allowed_ips = $peer->{'client_allowed_ips'} ?
        &validate_allowed_ips($peer->{'client_allowed_ips'}, "client allowed IPs") : "";
    my $endpoint = &clean_config_value($peer->{'endpoint'}, "endpoint");
    my $keepalive = &clean_config_value($peer->{'persistent_keepalive'}, "persistent keepalive");
    &error("Invalid persistent keepalive") if $keepalive && $keepalive !~ /\A\d+\z/;

    $conf .= "# BEGIN_PEER $name\n" if $name;
    $conf .= "# EXPIRES " . $peer->{'expires'} . "\n" if $peer->{'expires'};
    $conf .= "# CLIENT_ALLOWED_IPS $client_allowed_ips\n" if $client_allowed_ips;
    $conf .= "[Peer]\n";
    $conf .= "PublicKey = " . $peer->{'public_key'} . "\n";
    $conf .= "PresharedKey = " . $peer->{'preshared_key'} . "\n" if $peer->{'preshared_key'};
    $conf .= "AllowedIPs = $allowed_ips\n";
    $conf .= "Endpoint = $endpoint\n" if $endpoint;
    $conf .= "PersistentKeepalive = $keepalive\n" if $keepalive;
    $conf .= "# END_PEER $name\n" if $name;
    &write_iface_config($iface, $conf);
}

sub server_public_key {
    my ($iface) = @_;
    my $conf = &read_iface_config($iface);
    my ($private_key) = $conf =~ /^[ \t]*PrivateKey[ \t]*=[ \t]*(\S+)[ \t]*$/mi;
    &error("Server private key was not found") if !$private_key;
    &error("Invalid server private key") if !&valid_public_key($private_key);
    my $cmd = &wg_cmd();
    &error("wg was not found") if !-x $cmd;
    my $pub = &backquote_command("printf %s " . &shell_quote($private_key) . " | $cmd pubkey 2>&1");
    &error("<pre>" . &html_escape($pub) . "</pre>") if $?;
    $pub =~ s/\s+\z//;
    return $pub;
}

sub server_endpoint {
    my ($iface) = @_;
    my $conf = &read_iface_config($iface);
    my ($host) = $conf =~ /^#[ \t]*ENDPOINT[ \t]+(\S+)[ \t]*$/mi;
    $host ||= &get_system_hostname();
    $host = &clean_config_value($host, "endpoint host");
    &error("Invalid endpoint host") if $host !~ /\A[0-9A-Za-z_.:-]+\z/;
    my ($port) = $conf =~ /^[ \t]*ListenPort[ \t]*=[ \t]*(\d+)[ \t]*$/mi;
    $port ||= "51820";
    &error("Invalid listen port") if !&valid_port($port);
    return "$host:$port";
}

sub next_client_address {
    my ($iface) = @_;
    my $conf = &read_iface_config($iface);
    my ($base) = $conf =~ /^[ \t]*Address[ \t]*=[ \t]*(\d+\.\d+\.\d+)\.\d+\/\d+/mi;
    $base ||= "10.22.0";

    my %used;
    while ($conf =~ /^[# \t]*AllowedIPs[ \t]*=[ \t]*\Q$base\E\.(\d+)\/32\b/mig) {
        $used{$1} = 1;
    }
    for (my $octet = 2; $octet < 255; $octet++) {
        return ("$base.$octet/32", "$base.$octet/24") if !$used{$octet};
    }
    &error("WireGuard internal subnet is full");
}

sub client_config_file {
    my ($name) = @_;
    my $safe = &sanitize_peer_name($name);
    &error($text{'missing_peer_name'}) if !$safe;
    return &client_config_dir() . "/" . $safe . ".conf";
}

sub peer_name_exists {
    my ($name) = @_;
    $name = &sanitize_peer_name($name);
    return 0 if !$name;
    foreach my $iface (&list_interfaces()) {
        foreach my $peer (&list_peers(&read_iface_config($iface))) {
            return 1 if ($peer->{'name'} || "") eq $name;
        }
    }
    return 0;
}

sub peer_name_for_key {
    my ($iface, $public_key) = @_;
    return "" if !&valid_interface($iface) || !&valid_public_key($public_key);
    foreach my $peer (&list_peers(&read_iface_config($iface))) {
        return $peer->{'name'} || "" if $peer->{'public_key'} eq $public_key;
    }
    return "";
}

sub generate_client_peer {
    my ($iface, $opts) = @_;
    my $name = &sanitize_peer_name($opts->{'name'});
    &error($text{'missing_peer_name'}) if !$name;

    my $conf = &read_iface_config($iface);
    &error($text{'peer_exists'}) if $conf =~ /^#[ \t]*BEGIN_PEER[ \t]+\Q$name\E[ \t]*$/m;

    my $cmd = &wg_cmd();
    &error("wg was not found") if !-x $cmd;
    my $private_key = &backquote_command("$cmd genkey 2>&1");
    &error("<pre>" . &html_escape($private_key) . "</pre>") if $?;
    $private_key =~ s/\s+\z//;
    &error("Invalid generated private key") if !&valid_public_key($private_key);
    my $public_key = &backquote_command("printf %s " . &shell_quote($private_key) . " | $cmd pubkey 2>&1");
    &error("<pre>" . &html_escape($public_key) . "</pre>") if $?;
    $public_key =~ s/\s+\z//;
    &error("Invalid generated public key") if !&valid_public_key($public_key);
    my $psk = &backquote_command("$cmd genpsk 2>&1");
    &error("<pre>" . &html_escape($psk) . "</pre>") if $?;
    $psk =~ s/\s+\z//;
    &error("Invalid generated preshared key") if !&valid_public_key($psk);

    my ($server_allowed_ip, $client_address) = &next_client_address($iface);
    my $months = int($opts->{'months'} || 0);
    my $expires = $months > 0 ? time() + ($months * 30 * 24 * 60 * 60) : 0;
    my $client_allowed_ips = &client_allowed_ips_from_input($opts);
    &append_peer($iface, {
        name => $name,
        public_key => $public_key,
        preshared_key => $psk,
        allowed_ips => $server_allowed_ip,
        expires => $expires,
        client_allowed_ips => $client_allowed_ips,
    });

    my $client_conf = "[Interface]\n";
    $client_conf .= "Address = $client_address\n";
    $client_conf .= "DNS = " . &validate_dns($opts->{'dns'}) . "\n";
    $client_conf .= "PrivateKey = $private_key\n\n";
    $client_conf .= "[Peer]\n";
    $client_conf .= "PublicKey = " . &server_public_key($iface) . "\n";
    $client_conf .= "PresharedKey = $psk\n";
    $client_conf .= "AllowedIPs = $client_allowed_ips\n";
    $client_conf .= "Endpoint = " . &server_endpoint($iface) . "\n";
    $client_conf .= "PersistentKeepalive = 25\n";

    my $file = &client_config_file($name);
    &make_dir(&client_config_dir(), 0700) if !-d &client_config_dir();
    &open_tempfile(CLIENTCONF, ">$file");
    &print_tempfile(CLIENTCONF, $client_conf);
    &close_tempfile(CLIENTCONF);
    chmod(0600, $file);

    &apply_peer_live($iface, $public_key, $psk, $server_allowed_ip);
    return $file;
}

sub client_allowed_ips_from_input {
    my ($opts) = @_;
    return "0.0.0.0/0, ::/0" if ($opts->{'network_mode'} || "all") eq "all";
    my @nets = split(/\0/, $opts->{'networks'} || "");
    if ($opts->{'other_networks'}) {
        push(@nets, split(/[,\s]+/, $opts->{'other_networks'}));
    }
    @nets = grep { $_ ne "" } @nets;
    foreach my $net (@nets) {
        &error("Invalid network: " . &html_escape($net)) if !&valid_allowed_ip($net);
    }
    return @nets ? join(", ", @nets) : "0.0.0.0/0, ::/0";
}

sub list_route_networks {
    my @rows;
    my $cmd = &ip_cmd();
    return @rows if !$cmd;
    my $out = &backquote_command("$cmd -o -4 route show 2>/dev/null");
    foreach my $line (split(/\n/, $out)) {
        next if $line =~ /^default\b/;
        my ($net) = $line =~ /^(\d+\.\d+\.\d+\.\d+\/\d+)\b/;
        next if !$net;
        my ($dev) = $line =~ /\bdev\s+(\S+)/;
        next if ($dev || "") =~ /^wg/;
        push(@rows, [ $net, $dev || "" ]);
    }
    my %seen;
    return grep { !$seen{$_->[0]}++ } @rows;
}

sub apply_peer_live {
    my ($iface, $public_key, $psk, $allowed_ips) = @_;
    &error($text{'invalid_interface'}) if !&valid_interface($iface);
    &error($text{'missing_public_key'}) if !&valid_public_key($public_key);
    &error("Invalid preshared key") if $psk && !&valid_public_key($psk);
    foreach my $net (split(/[,\s]+/, $allowed_ips || "")) {
        next if $net eq "";
        &error("Invalid allowed IP: " . &html_escape($net)) if !&valid_allowed_ip($net);
    }
    return if !&iface_is_running($iface);
    my $cmd = &wg_cmd();
    return if !-x $cmd;
    my $pskfile = &tempname();
    &open_tempfile(PSK, ">$pskfile");
    &print_tempfile(PSK, $psk . "\n");
    &close_tempfile(PSK);
    chmod(0600, $pskfile);
    my $out = &backquote_logged("$cmd set " . &shell_quote($iface) .
        " peer " . &shell_quote($public_key) .
        " preshared-key " . &shell_quote($pskfile) .
        " allowed-ips " . &shell_quote($allowed_ips) . " 2>&1");
    unlink($pskfile);
    &error("<pre>" . &html_escape($out) . "</pre>") if $?;
}

sub remove_peer_live {
    my ($iface, $public_key) = @_;
    &error($text{'invalid_interface'}) if !&valid_interface($iface);
    &error($text{'missing_public_key'}) if !&valid_public_key($public_key);
    return if !&iface_is_running($iface);
    my $cmd = &wg_cmd();
    return if !-x $cmd;
    &backquote_logged("$cmd set " . &shell_quote($iface) . " peer " . &shell_quote($public_key) . " remove 2>&1");
}

sub set_peer_enabled {
    my ($iface, $public_key, $enabled) = @_;
    &error($text{'invalid_interface'}) if !&valid_interface($iface);
    &error($text{'missing_public_key'}) if !&valid_public_key($public_key);
    my $conf = &read_iface_config($iface);
    my $out = "";
    my @block;
    my $in_block = 0;

    foreach my $line (split(/(?<=\n)/, $conf)) {
        if ($line =~ /^#[ \t]*BEGIN_PEER[ \t]+/) {
            if ($in_block) {
                $out .= &rewrite_peer_block(\@block, $public_key, $enabled);
            }
            @block = ($line);
            $in_block = 1;
            next;
        }

        if ($in_block) {
            push(@block, $line);
            if ($line =~ /^#[ \t]*END_PEER[ \t]+/) {
                $out .= &rewrite_peer_block(\@block, $public_key, $enabled);
                @block = ();
                $in_block = 0;
            }
            next;
        }

        $out .= $line;
    }
    $out .= &rewrite_peer_block(\@block, $public_key, $enabled) if $in_block;
    &write_iface_config($iface, $out);

    if ($enabled) {
        my @peers = &list_peers(&read_iface_config($iface));
        foreach my $peer (@peers) {
            if ($peer->{'public_key'} eq $public_key) {
                &apply_peer_live($iface, $peer->{'public_key'}, $peer->{'preshared_key'}, $peer->{'allowed_ips'});
                last;
            }
        }
    }
    else {
        &remove_peer_live($iface, $public_key);
    }
}

sub rewrite_peer_block {
    my ($block_ref, $public_key, $enabled) = @_;
    my @lines = @$block_ref;
    my $block = join("", @lines);
    return $block if $block !~ /^[# \t]*PublicKey[ \t]*=[ \t]*\Q$public_key\E[ \t]*$/mi;

    my @out;
    my $has_disabled = 0;
    foreach my $line (@lines) {
        if ($line =~ /^#[ \t]*DISABLED\b/) {
            $has_disabled = 1;
            push(@out, $line) if !$enabled;
            next;
        }
        if ($line =~ /^([ \t]*)(\[Peer\]|PublicKey[ \t]*=.*|PresharedKey[ \t]*=.*|AllowedIPs[ \t]*=.*|Endpoint[ \t]*=.*|PersistentKeepalive[ \t]*=.*)$/i) {
            push(@out, $enabled ? $line : "# " . $line);
            next;
        }
        if ($line =~ /^#[ \t]*(\[Peer\]|PublicKey[ \t]*=.*|PresharedKey[ \t]*=.*|AllowedIPs[ \t]*=.*|Endpoint[ \t]*=.*|PersistentKeepalive[ \t]*=.*)$/i) {
            push(@out, $enabled ? $1 . "\n" : $line);
            next;
        }
        push(@out, $line);
        if (!$enabled && !$has_disabled && $line =~ /^#[ \t]*BEGIN_PEER[ \t]+/) {
            push(@out, "# DISABLED 1\n");
            $has_disabled = 1;
        }
    }
    return join("", @out);
}

sub disable_expired_peers {
    foreach my $iface (&list_interfaces()) {
        my @peers = &list_peers(&read_iface_config($iface));
        foreach my $peer (@peers) {
            next if $peer->{'disabled'};
            next if !$peer->{'expires'} || $peer->{'expires'} > time();
            &set_peer_enabled($iface, $peer->{'public_key'}, 0);
        }
    }
}

sub delete_peer_by_public_key {
    my ($iface, $public_key) = @_;
    &error($text{'missing_public_key'}) if !$public_key;
    &error($text{'missing_public_key'}) if !&valid_public_key($public_key);

    my $conf = &read_iface_config($iface);
    my $out = "";
    my @block;
    my $in_block = 0;
    my $delete_block = 0;

    foreach my $line (split(/(?<=\n)/, $conf)) {
        if ($line =~ /^#[ \t]*BEGIN_PEER[ \t]+/) {
            if ($in_block) {
                $out .= join("", @block) if !$delete_block;
            }
            @block = ($line);
            $in_block = 1;
            $delete_block = 0;
            next;
        }

        if ($line =~ /^(#\s*)?\[Peer\][ \t]*$/) {
            if ($in_block && grep { /^(#\s*)?\[Peer\][ \t]*$/ } @block) {
                $out .= join("", @block) if !$delete_block;
                @block = ();
                $delete_block = 0;
            }
            $in_block = 1;
            push(@block, $line);
            next;
        }

        if ($in_block) {
            push(@block, $line);
            $delete_block = 1 if $line =~ /^[# \t]*PublicKey[ \t]*=[ \t]*\Q$public_key\E[ \t]*$/i;
            if ($line =~ /^#[ \t]*END_PEER[ \t]+/) {
                $out .= join("", @block) if !$delete_block;
                @block = ();
                $in_block = 0;
                $delete_block = 0;
            }
            next;
        }

        $out .= $line;
    }

    if ($in_block) {
        $out .= join("", @block) if !$delete_block;
    }
    &write_iface_config($iface, $out);
}

sub extract_peer_keys {
    my ($conf) = @_;
    my @keys;
    while ($conf =~ /^[ \t]*PublicKey[ \t]*=[ \t]*(\S+)[ \t]*$/mig) {
        push(@keys, $1);
    }
    return @keys;
}

sub list_peers {
    my ($conf) = @_;
    my @peers;
    my $pending_name = "";
    my $pending_expires = 0;
    my $pending_client_allowed_ips = "";
    my $pending_disabled = 0;
    my $peer;

    foreach my $line (split(/\n/, $conf)) {
        if ($line =~ /^#[ \t]*BEGIN_PEER[ \t]+(.+?)[ \t]*$/) {
            push(@peers, $peer) if $peer && $peer->{'public_key'};
            $peer = undef;
            $pending_name = $1;
            $pending_expires = 0;
            $pending_client_allowed_ips = "";
            $pending_disabled = 0;
            next;
        }

        if ($line =~ /^#[ \t]*DISABLED\b/ && !$peer) {
            $pending_disabled = 1;
            next;
        }

        if ($line =~ /^(#\s*)?\[Peer\][ \t]*$/) {
            push(@peers, $peer) if $peer && $peer->{'public_key'};
            $peer = {
                public_key => "",
                preshared_key => "",
                name => $pending_name,
                allowed_ips => "",
                endpoint => "",
                client_allowed_ips => $pending_client_allowed_ips,
                expires => $pending_expires,
                disabled => ($line =~ /^#/ ? 1 : 0) || $pending_disabled,
            };
            $pending_name = "";
            $pending_expires = 0;
            $pending_client_allowed_ips = "";
            $pending_disabled = 0;
            next;
        }

        if ($line =~ /^#[ \t]*EXPIRES[ \t]+(\d+)[ \t]*$/) {
            $pending_expires = $1;
            next;
        }
        if ($line =~ /^#[ \t]*CLIENT_ALLOWED_IPS[ \t]+(.+?)[ \t]*$/) {
            $pending_client_allowed_ips = $1;
            next;
        }

        next if !$peer;

        if ($line =~ /^#[ \t]*DISABLED\b/) {
            $peer->{'disabled'} = 1;
        }
        elsif ($line =~ /^#[ \t]*EXPIRES[ \t]+(\d+)[ \t]*$/) {
            $peer->{'expires'} = $1;
        }
        elsif ($line =~ /^#[ \t]*CLIENT_ALLOWED_IPS[ \t]+(.+?)[ \t]*$/) {
            $peer->{'client_allowed_ips'} = $1;
        }
        elsif ($line =~ /^[# \t]*PublicKey[ \t]*=[ \t]*(\S+)[ \t]*$/i) {
            $peer->{'public_key'} = $1;
        }
        elsif ($line =~ /^[# \t]*PresharedKey[ \t]*=[ \t]*(\S+)[ \t]*$/i) {
            $peer->{'preshared_key'} = $1;
        }
        elsif ($line =~ /^[# \t]*AllowedIPs[ \t]*=[ \t]*(.+?)[ \t]*$/i) {
            $peer->{'allowed_ips'} = $1;
        }
        elsif ($line =~ /^[# \t]*Endpoint[ \t]*=[ \t]*(.+?)[ \t]*$/i) {
            $peer->{'endpoint'} = $1;
        }
        elsif ($line =~ /^[ \t]*#[ \t]*(?!BEGIN_PEER\b|END_PEER\b)(.+?)[ \t]*$/ && !$peer->{'name'}) {
            $peer->{'name'} = $1;
        }
        elsif ($line =~ /^#[ \t]*END_PEER[ \t]+(.+?)[ \t]*$/) {
            $peer->{'name'} ||= $1;
            push(@peers, $peer) if $peer->{'public_key'};
            $peer = undef;
        }
    }
    push(@peers, $peer) if $peer && $peer->{'public_key'};

    return @peers;
}

sub print_header {
    my ($title) = @_;
    &ui_print_header(undef, $title, "", undef, 1, 1);
}

sub print_footer {
    &ui_print_footer("/", $text{'index_title'});
}

1;
