BEGIN { push(@INC, ".."); }
use WebminCore;

sub module_install
{
my $module = "wireguard_webmin";
my $target = &module_root_directory($module);
if (-d "/etc/cron.d") {
	my $cron = "/etc/cron.d/$module";
	&open_tempfile(CRON, ">$cron");
	&print_tempfile(CRON,
		"*/5 * * * * root $target/expire_peers.pl >/dev/null 2>&1\n");
	&close_tempfile(CRON);
	chmod(0644, $cron);
	}
}

sub module_uninstall
{
unlink("/etc/cron.d/wireguard_webmin");
}

1;
