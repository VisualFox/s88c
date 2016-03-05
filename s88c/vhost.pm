use strict;
use warnings;
use File::Which;

sub createVHost {

	my $vhost = shift;
	my $available = shift;
	my $enabled = shift;

	while(-f "$available/$vhost") {
		print "\n$vhost is already in use choose another one\n";
		$vhost = listVHost($available, $enabled, "list");
	}

	if($vhost) {
        my $perusio = $main::config->{'perusio'};
		my $scriptPath = $main::scriptPath;

		my @vhosts = split(/\./, $vhost);

		if(@vhosts<3) {

            #template variable
            my %vars = (domain => $vhost);

		    if($perusio) {
		        my $template = Text::Template->new(SOURCE => "$scriptPath/s88c/tmpl/nginx/drupal/perusio/drupal.vhost.tmpl") or die "Couldn't construct template: $Text::Template::ERROR";
                my $result = $template->fill_in(HASH => \%vars);

                if (defined $result) {
                    open (FILE, ">$available/$vhost");
                    print FILE $result;
                    close (FILE);
                }
		    } else {
		        my $template = Text::Template->new(SOURCE => "$scriptPath/s88c/tmpl/nginx/drupal/drupal.vhost.tmpl") or die "Couldn't construct template: $Text::Template::ERROR";
                my $result = $template->fill_in(HASH => \%vars);

                if (defined $result) {
                    open (FILE, ">$available/$vhost");
                    print FILE $result;
                    close (FILE);
                }

                $template = Text::Template->new(SOURCE => "$scriptPath/s88c/tmpl/nginx/drupal/drupal.vhost.ssl.tmpl") or die "Couldn't construct template: $Text::Template::ERROR";
                $result = $template->fill_in(HASH => \%vars);

                if (defined $result) {
                    open (FILE, ">$available/$vhost-ssl");
                    print FILE $result;
                    close (FILE);
                }
		    }

			#run wizard...
			enableVHost($vhost, $available, $enabled);

			if(&promptUser("Init $vhost? (yes|no)", 'yes') eq 'yes') {
				initApp("/var/www/vhosts", $vhost);
			}
		}
		else {

            #template variable
            my $subdomain = shift(@vhosts);
            my $domain = join('.', @vhosts);
            my %vars = (domain => $domain, subdomain => $subdomain);

            if($perusio) {
                my $template = Text::Template->new(SOURCE => "$scriptPath/s88c/tmpl/nginx/drupal/perusio/drupal.sub.vhost.tmpl") or die "Couldn't construct template: $Text::Template::ERROR";
                my $result = $template->fill_in(HASH => \%vars);

                if (defined $result) {
                    open (FILE, ">$available/$vhost");
                    print FILE $result;
                    close (FILE);
                }
			} else {
			    my $template = Text::Template->new(SOURCE => "$scriptPath/s88c/tmpl/nginx/drupal/drupal.sub.vhost.tmpl") or die "Couldn't construct template: $Text::Template::ERROR";
                my $result = $template->fill_in(HASH => \%vars);

                if (defined $result) {
                    open (FILE, ">$available/$vhost");
                    print FILE $result;
                    close (FILE);
                }

                $template = Text::Template->new(SOURCE => "$scriptPath/s88c/tmpl/nginx/drupal/drupal.sub.vhost.ssl.tmpl") or die "Couldn't construct template: $Text::Template::ERROR";
                $result = $template->fill_in(HASH => \%vars);

                if (defined $result) {
                    open (FILE, ">$available/$vhost-ssl");
                    print FILE $result;
                    close (FILE);
                }
			}

			#run wizard...
			enableVHost($vhost, $available, $enabled);

			if(&promptUser("Init $vhost? (yes|no)", 'yes') eq 'yes') {
				initApp("/var/www/vhosts", "$domain/subdomains/$subdomain");
			}
		}
	}
}

sub enableVHost {
	my $vhost = shift;
	my $available = shift;
	my $enabled = shift;

	if($vhost) {
		if(&promptUser("Enable $vhost? (yes|no)", 'yes') eq 'yes') {

			if(-f "$enabled/$vhost") {
				print "\n";
				return;
			}

			if(-f "$available/$vhost") {
			    #system "ln -s $available/$vhost $enabled/$vhost";
				system "cd $enabled && ln -s ../sites-available/$vhost";

				if(&promptUser('Reload nginx? (yes|no)', 'yes') eq 'yes') {
					reloadNginx();
				}
				else {
					print "\n";
				}
			}
		}
	}
	else {
		print "\nNo vhost to enable\n";
	}
}

sub disableVHost {
	my $vhost = shift;
	my $available = shift;
	my $enabled = shift;

	if($vhost) {
		if(&promptUser("Disable $vhost? (yes|no)", 'yes') eq 'yes') {

			if(-f "$enabled/$vhost") {
				system "rm -f $enabled/$vhost";

				if(&promptUser('Reload nginx? (yes|no)', 'yes') eq 'yes') {
					reloadNginx();
				}
				else {
					print "\n";
				}
			}
		}
	}
	else {
		print "\nNo vhost to disable\n";
	}
}

sub deleteVHost {
	my $vhost = shift;
	my $available = shift;
	my $enabled = shift;

	if($vhost) {
		if(&promptUser("Delete $vhost? (yes|no)", 'no') eq 'yes') {

            my $perusio = $main::config->{'perusio'};

            if($perusio) {
                if(-f "$enabled/$vhost") {
                    system "rm -f $enabled/$vhost";
                }
            } else {
                if(-f "$enabled/$vhost") {
                    system "rm -f $enabled/$vhost";
                }

                if(-f "$enabled/$vhost-ssl") {
                    system "rm -f $enabled/$vhost-ssl";
                }
            }

			if(-f "$available/$vhost") {

                if($perusio) {
                    system "rm -f $available/$vhost";
                } else {
                    system "rm -f $available/$vhost";

                    if(-f "$available/$vhost-ssl") {
                        system "rm -f $available/$vhost-ssl";
                    }
                }

				if(&promptUser("Reload nginx? (yes|no)", 'yes') eq 'yes') {
					reloadNginx();
				}
				else {
					print "\n";
				}

				my $path = "/var/www/vhosts";
				my $dir = $vhost;
				my @vhosts = split(/\./, $vhost);

				if(@vhosts>2) {
					my $subdomain = shift(@vhosts);
					my $domain = join('.', @vhosts);

					$dir = "$domain/subdomains/$subdomain";
				}

				deleteSite($path, $dir);

				#delete cron
				my $cron = getSitedomain($dir);
				$cron =~ s/\//./g;

				if(-f "/etc/cron.d/$cron") {
					system "rm -f /etc/cron.d/$cron";
				}
			}
		}
	}
	else {
		print "\nNo vhost to delete\n";
	}
}

sub reloadNginx {
    my $nginx = which('nginx');

    if($nginx) {
        system "$nginx -t";

        if(&promptUser("Are you sure that you want to reload Nginx? (yes|no)", 'yes') eq 'yes') {
            system "$nginx -s reload";
        }
    }
}

1;
