#!/usr/bin/perl
require './wireguard-lib.pl';

&confirm_service_action_or_run("restart", $text{'service_restarted'});
