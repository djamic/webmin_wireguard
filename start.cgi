#!/usr/bin/perl
require './wireguard-lib.pl';

&confirm_service_action_or_run("start", $text{'service_started'});
