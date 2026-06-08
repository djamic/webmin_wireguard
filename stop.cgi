#!/usr/bin/perl
require './wireguard-lib.pl';

&confirm_service_action_or_run("stop", $text{'service_stopped'});
