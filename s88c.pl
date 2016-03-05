#!/usr/bin/perl

#--------------------------------------------

use strict;
use warnings;
use Text::Template;
use File::Basename;
use URI;

#--------------------------------------------
sub actionVHost {

	my $action = &promptUserWithLabel('Vhost menu', 'Please choose an action :', 'create vhost', 'enable vhost', 'disable vhost', 'delete vhost/host', 'reload nginx configuration', 'generate htpasswd', 'return', 'quit');

	my $available = "/etc/nginx/sites-available";
	my $enabled = "/etc/nginx/sites-enabled";

	if($action eq 'create vhost') {
		printLabel('create vhost');
		my $vhost = listVHost($available, $enabled, "list");
		createVHost($vhost, $available, $enabled);
	}
	elsif($action eq 'enable vhost') {
		printAction($action);
		my $vhost = listVHost($available, $enabled, 'enable');
		enableVHost($vhost, $available, $enabled);
	}
	elsif($action eq 'disable vhost') {
		printAction($action);
		my $vhost = listVHost($available, $enabled, 'disable');
		disableVHost($vhost, $available, $enabled);
	}
	elsif($action eq 'delete vhost/host') {
		printAction($action);
		my $vhost = listVHost($available, $enabled, 'delete');
		deleteVHost($vhost, $available, $enabled);
	}
	elsif($action eq 'reload nginx configuration') {
		printAction($action);
		reloadNginx();
	}
	elsif($action eq 'generate htpasswd') {
		printAction($action);

		my $username = &promptUser('username', $main::username);
		my $password = &promptUser('password', '');
		my $filename = &promptUser('filename (will be saved under /etc/nginx/password/)', 'htpasswd');

		if($username && $password && $filename) {
			htpasswd($username, $password, $filename);
			printNotice('Saved', "/etc/nginx/password/$filename");
		}
	}
	elsif($action eq 'return') {
		mainAction();
	}
	elsif($action eq 'quit') {
		quit();
	}

	actionVHost();
}

sub actionServer {

	my $action = &promptUserWithLabel('Server menu', 'Please choose an action :', 'disk usage', 'wizard', 'return', 'quit');

	if($action eq 'disk usage') {
		diskUsage();
	}
	elsif($action eq 'wizard') {
		createConfiguration();
	}
	elsif($action eq 'return') {
		mainAction();
	}
	elsif($action eq 'quit') {
		quit();
	}

	actionServer();
}

sub mainAction {

	my $action =  &promptUserWithLabel('Main menu', 'Please choose an action :', 'vhosts configuration', 'server', 'quit');

	if($action eq 'vhosts configuration') {
		actionVHost();
	}
	elsif($action eq 'server') {
		actionServer();
	}
	elsif($action eq 'quit') {
		quit();
	}

	mainAction();
}

sub checkUser {
	my $login = (getpwuid($>));
	die "\nYou cannot run this Perl script as user \"$login\", you must be root!\n\n" unless ($login eq 'root');
}

sub quit {
	printAction('bye bye');
	print "\n";
	exit;
}

#--------------------------------------------

sub init {

	checkUser();

	my $scriptPath = dirname(__FILE__);

	package main; {
		our $username = getlogin();
		our $scriptPath = $scriptPath;
	}

	require("$scriptPath/s88c/screen.pm");
	require("$scriptPath/s88c/util.pm");
	require("$scriptPath/s88c/server.pm");

	if(not -f "$scriptPath/s88c/config.cfg") {
		createConfiguration();
	}

	readConfigurationFile("$scriptPath/s88c/config.cfg");

	require("$scriptPath/s88c/db.pm");
	require("$scriptPath/s88c/domain.pm");
	require("$scriptPath/s88c/vhost.pm");
	require("$scriptPath/s88c/disk.pm");

	require("$scriptPath/s88c/welcome.pm") if (-f "$scriptPath/s88c/welcome.pm");

	welcome() if(functionExists('welcome'));
	diskUsage();
	mainAction();
}

#--------------------------------------------

init();
