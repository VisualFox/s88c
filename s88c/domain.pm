use strict;
use warnings;
use File::Which;

my $scriptPath = $main::scriptPath;

sub initApp {

	my $dir = shift;
	my $domain = shift;

	my $confirm = 'yes';

	my $user = 'www-data', #$main::username;
	my $scriptPath = $main::scriptPath;
	my $app = $main::config->{'app'};

	my $dbuser;
	my $dbpass;
	my $db;
	my $filesparent;
	my $filesname;

	my $filter;

    my $defaultName = $domain;

	if($defaultName =~ m/^(.+)\.(.+)$/) {
    	$defaultName = $1;
	}

	my $template;
    my %vars;
    my $result;

    my $envUser;

    if(!$ENV{USER}) {
        $envUser = 'root';
    } else {
        $envUser = $ENV{USER};
    }

	#create some system folder...
	unless(-d "$dir/$domain/httpdocs") {

		$user = &promptUser("Enter user for $domain", $defaultName) unless ($user);
		system "mkdir -p $dir/$domain/httpdocs && chown $user:$user $dir/$domain/httpdocs";
		printNotice('httpdocs folder created', "$dir/$domain/httpdocs");
	}

	#create the private folder...
	unless(-d "$dir/$domain/private") {

		$user = &promptUser("Enter user for $domain", $defaultName) unless ($user);
		system "mkdir -p $dir/$domain/private && chown $user:root $dir/$domain/private";
		printNotice('private folder created', "$dir/$domain/private");
	}
	else {
		printComment('private folder already exists');
	}

	#create db...
	if(&promptUser("Create a new db? (yes|no)", 'yes') eq 'yes') {

		if (not -f "$dir/$domain/private/db.pl") {
			my $host = $main::database->{'host'};
			my $tcp = $main::database->{'tcp'};

            my $db = join'', map +(0..9,'a'..'z','A'..'Z')[rand(10+26*2)], 1..16;
            my $dbuser = join'', map +(0..9,'a'..'z','A'..'Z')[rand(10+26*2)], 1..16;
            my $dbpass = join'', map +(0..9,'a'..'z','A'..'Z')[rand(10+26*2)], 1..24;

            #check if we want to enter a specific db name
            if(&promptUser("Enter the db name? (yes|no)", 'no') eq 'yes') {
                $db = &promptUser("Enter a db name");
            }

            if(&promptUser("Enter the db user's name? (yes|no)", 'no') eq 'yes') {
                $dbuser = &promptUser("Enter the db user's name");
            }

            if(&promptUser("Enter the db user's password? (yes|no)", 'no') eq 'yes') {
                $dbpass = &promptUser("Enter the db user's password");
            }

			#generate prefixes...
			my @prefixes = ('app');
			my $new_prefix = &promptUser("Add a new prefix to this db (current prefixes: @prefixes)? (yes|no)", 'no');

            while($new_prefix eq 'yes') {
                my $prefix = &promptUser('prefix', '');

                if($prefix) {
                    push (@prefixes, $prefix);
                }

                $new_prefix = &promptUser("Add a new prefix to this db (current prefixes: @prefixes)? (yes|no)", 'no');
            }

			#save db file...
			$template = Text::Template->new(SOURCE => "$scriptPath/s88c/tmpl/db.tmpl") or die "Couldn't construct template: $Text::Template::ERROR";
	    	%vars = (host => $host, tcp => $tcp, prefixes => join(' ', @prefixes), db => $db, user => $dbuser, pass => $dbpass);
	   		$result = $template->fill_in(HASH => \%vars);

	    	if (defined $result) {
				open (FILE, ">$dir/$domain/private/db.pl");
				print FILE $result;
				close (FILE);
				system "chown root:root $dir/$domain/private/db.pl";
				system "chmod +x $dir/$domain/private/db.pl";

				printNotice('script created', "$dir/$domain/private/db.pl");
			}
		}
		else {
			printComment('db.pl already exists');
		}
	}

	#load db
	if (-f "$dir/$domain/private/db.pl") {

		system "$dir/$domain/private/db.pl create ".$main::database->{'host'}." ".$main::database->{'username'}." ".$main::database->{'password'};
		system "$dir/$domain/private/db.pl info";

		$db = `$dir/$domain/private/db.pl database`; #@see backticks
		$dbuser = `$dir/$domain/private/db.pl username`; #@see backticks
		$dbpass = `$dir/$domain/private/db.pl password`; #@see backticks

        my $duser = 'admin';
        my $dpass = join'', map +(0..9,'a'..'z','A'..'Z')[rand(10+26*2)], 1..24;

        #check if we want to enter a specific admin user name
        if(&promptUser("Enter the admin username? (yes|no)", 'no') eq 'yes') {
            $duser = &promptUser("Enter the admin username");
        }

        if(&promptUser("Enter the admin password? (yes|no)", 'no') eq 'yes') {
            $dpass = &promptUser("Enter the admin password");
        }

        unless(-f "$dir/$domain/httpdocs/credentials.drupal") {

            $template = Text::Template->new(SOURCE => "$scriptPath/s88c/tmpl/credentials.drupal.tmpl") or die "Couldn't construct template: $Text::Template::ERROR";
            %vars = (db => $db, user => $dbuser, pass => $dbpass, duser => $duser, dpass => $dpass);
            $result = $template->fill_in(HASH => \%vars);

            if (defined $result) {
                open (FILE, ">$dir/$domain/httpdocs/credentials.drupal");
                print FILE $result;
                close (FILE);

                printNotice('credentials for drupal created', "$dir/$domain/httpdocs/credentials.drupal");
            }
        }

        unless(-f "$dir/$domain/httpdocs/install.drupal7") {

            $template = Text::Template->new(SOURCE => "$scriptPath/s88c/tmpl/install.drupal7.tmpl") or die "Couldn't construct template: $Text::Template::ERROR";
            %vars = (dir => "$dir/$domain/httpdocs", app => "app", db => $db, user => $dbuser, pass => $dbpass, duser => $duser, dpass => $dpass);
            $result = $template->fill_in(HASH => \%vars);

            if (defined $result) {
                open (FILE, ">$dir/$domain/httpdocs/install.drupal7");
                print FILE $result;
                close (FILE);

                system "chmod +x $dir/$domain/httpdocs/install.drupal7";

                printNotice('install script for drupal 7 created', "$dir/$domain/httpdocs/install.drupal7");
            }
        }

        unless(-f "$dir/$domain/httpdocs/install.drupal8") {

            $template = Text::Template->new(SOURCE => "$scriptPath/s88c/tmpl/install.drupal8.tmpl") or die "Couldn't construct template: $Text::Template::ERROR";
            %vars = (dir => "$dir/$domain/httpdocs", app => "app", db => $db, user => $dbuser, pass => $dbpass, duser => $duser, dpass => $dpass);
            $result = $template->fill_in(HASH => \%vars);

            if (defined $result) {
                open (FILE, ">$dir/$domain/httpdocs/install.drupal8");
                print FILE $result;
                close (FILE);

                system "chmod +x $dir/$domain/httpdocs/install.drupal8";

                printNotice('install script for drupal 8 created', "$dir/$domain/httpdocs/install.drupal8");
            }
        }

        #ask to run install script
        if(&promptUser("Install drupal? (yes|no)", 'yes') eq 'yes') {
            if(&promptUser("Install drupal? (7|8)", '7') eq '7') {
                system "$dir/$domain/httpdocs/install.drupal7";
            }
            else {
                system "$dir/$domain/httpdocs/install.drupal8";
            }
        }
	}

	#create db backup script
	if(&promptUser("Setup basic Drupal backup? (yes|no)", 'yes') eq 'yes') {

		#- - -

		unless(-d "$dir/$domain/private/db.backup") {

			$user = &promptUser("Enter user for $domain", $defaultName) unless ($user);
			system "mkdir $dir/$domain/private/db.backup && chown $user:$user $dir/$domain/private/db.backup";
		}

		unless(-f "$dir/$domain/private/db.backup/backup.pl") {

			$user = &promptUser("Enter user for $domain", $defaultName) unless ($user);
			$app = &promptUser("Enter application name", "app") unless ($app);

			$db = &promptUser("Enter database's name") unless ($db);
			$dbuser = &promptUser("Enter database's user") unless ($dbuser);
			$dbpass = &promptUser("Enter database's password") unless ($dbpass);

			$template = Text::Template->new(SOURCE => "$scriptPath/s88c/tmpl/db.backup.tmpl") or die "Couldn't construct template: $Text::Template::ERROR";
	        %vars = (dir => $dir, domain => $domain, app => $app, user => $dbuser, pass => $dbpass, db => $db);
	        $result = $template->fill_in(HASH => \%vars);

	        if (defined $result) {
				open (FILE, ">$dir/$domain/private/db.backup/backup.pl");
				print FILE $result;
				close (FILE);
				system "chmod +x $dir/$domain/private/db.backup/backup.pl && chown $user:$user $dir/$domain/private/db.backup/backup.pl";

				printNotice('script created', "$dir/$domain/private/db.backup/backup.pl");
			}
		}
		else {
			printComment('db.backup/backup.pl file already exists');
		}

		#- - -

		unless(-d "$dir/$domain/private/db.auto.backup") {

			$user = &promptUser("Enter user for $domain", $defaultName) unless ($user);
			system "mkdir $dir/$domain/private/db.auto.backup && chown $user:$user $dir/$domain/private/db.auto.backup";
		}

		unless(-f "$dir/$domain/private/db.auto.backup/backup.pl") {

			$user = &promptUser("Enter user for $domain", $defaultName) unless ($user);
			$app = &promptUser("Enter application name", "app") unless ($app);

			$db = &promptUser("Enter database's name") unless ($db);
			$dbuser = &promptUser("Enter database's user") unless ($dbuser);
			$dbpass = &promptUser("Enter database's password") unless ($dbpass);

			$template = Text::Template->new(SOURCE => "$scriptPath/s88c/tmpl/db.auto.backup.tmpl") or die "Couldn't construct template: $Text::Template::ERROR";
	        %vars = (dir => $dir, domain => $domain, app => $app, user => $dbuser, pass => $dbpass, db => $db);
	        $result = $template->fill_in(HASH => \%vars);

	        if (defined $result) {
				open (FILE, ">$dir/$domain/private/db.auto.backup/backup.pl");
				print FILE $result;
				close (FILE);
				system "chmod +x $dir/$domain/private/db.auto.backup/backup.pl && chown $user:$user $dir/$domain/private/db.auto.backup/backup.pl";

				printNotice('script created', "$dir/$domain/private/db.auto.backup/backup.pl");
			}
		}
		else {
			printComment('db.auto.backup/backup.pl file already exists');
		}

		#create files backup scripts
		unless(-d "$dir/$domain/private/files.backup") {

			$user = &promptUser("Enter user for $domain", $defaultName) unless ($user);
			system "mkdir $dir/$domain/private/files.backup && chown $user:$user $dir/$domain/private/files.backup";
		}

		unless(-f "$dir/$domain/private/files.backup/backup.pl") {

			$user = &promptUser("Enter user for $domain", $defaultName) unless ($user);
			$app = &promptUser("Enter application name", "app") unless ($app);
			$filesparent = &promptUser("Enter drupal files parent path", "sites/default") unless ($filesparent);
			$filesname = &promptUser("Enter drupal files name", "files") unless ($filesname);

			$template = Text::Template->new(SOURCE => "$scriptPath/s88c/tmpl/files.backup.tmpl") or die "Couldn't construct template: $Text::Template::ERROR";
	        %vars = (dir => $dir, domain => $domain, user => $user, app => $app, filesparent => $filesparent, filesname => $filesname);
	        $result = $template->fill_in(HASH => \%vars);

	        if (defined $result) {
				open (FILE, ">$dir/$domain/private/files.backup/backup.pl");
				print FILE $result;
				close (FILE);
				system "chmod +x $dir/$domain/private/files.backup/backup.pl && chown $user:$user $dir/$domain/private/files.backup/backup.pl";

				printNotice('script created', "$dir/$domain/private/files.backup/backup.pl");
			}
		}
		else {
			printComment('files.backup/backup.pl file already exists');
		}

		#- - -

		unless(-d "$dir/$domain/private/files.auto.backup") {

			$user = &promptUser("Enter user for $domain", $defaultName) unless ($user);
			system "mkdir $dir/$domain/private/files.auto.backup && chown $user:$user $dir/$domain/private/files.auto.backup";
		}

		unless(-f "$dir/$domain/private/files.auto.backup/backup.pl") {

			$user = &promptUser("Enter user for $domain", $defaultName) unless ($user);
			$app = &promptUser("Enter application name", "app") unless ($app);
			$filesparent = &promptUser("Enter drupal files parent path", "sites/default") unless ($filesparent);
			$filesname = &promptUser("Enter drupal files name", "files") unless ($filesname);

			$template = Text::Template->new(SOURCE => "$scriptPath/s88c/tmpl/files.auto.backup.tmpl") or die "Couldn't construct template: $Text::Template::ERROR";
	        %vars = (dir => $dir, domain => $domain, user => $user, app => $app, filesparent => $filesparent, filesname => $filesname);
	        $result = $template->fill_in(HASH => \%vars);

	        if (defined $result) {
				open (FILE, ">$dir/$domain/private/files.auto.backup/backup.pl");
				print FILE $result;
				close (FILE);
				system "chmod +x $dir/$domain/private/files.auto.backup/backup.pl && chown $user:$user $dir/$domain/private/files.auto.backup/backup.pl";

				printNotice('script created', "$dir/$domain/private/files.auto.backup/backup.pl");
			}
		}
		else {
			printComment('files.auto.backup/backup.pl file already exists');
		}

		#create full site backup

		unless(-d "$dir/$domain/private/backup") {

			$user = &promptUser("Enter user for $domain", $defaultName) unless ($user);
			system "mkdir $dir/$domain/private/backup && chown $user:$user $dir/$domain/private/backup";
		}

		unless(-f "$dir/$domain/private/backup/backup.pl") {

			$user = &promptUser("Enter user for $domain", $defaultName) unless ($user);
			$app = &promptUser("Enter application name", "app") unless ($app);

			$db = &promptUser("Enter database's name") unless ($db);
			$dbuser = &promptUser("Enter database's user") unless ($dbuser);
			$dbpass = &promptUser("Enter database's password") unless ($dbpass);

			$template = Text::Template->new(SOURCE => "$scriptPath/s88c/tmpl/backup.tmpl") or die "Couldn't construct template: $Text::Template::ERROR";
	        %vars = (dir => $dir, domain => $domain, user => $user, app => $app, user => $dbuser, pass => $dbpass, db => $db);
	        $result = $template->fill_in(HASH => \%vars);

	        if (defined $result) {
				open (FILE, ">$dir/$domain/private/backup/backup.pl");
				print FILE $result;
				close (FILE);
				system "chmod +x $dir/$domain/private/backup/backup.pl && chown $user:$user $dir/$domain/private/backup/backup.pl";

				printNotice('script created', "$dir/$domain/private/backup/backup.pl");
			}
		}
		else {
			printComment('backup/backup.pl file already exists');
		}

		#- - -

        if(-d "/etc/cron.d") {
		    if(&promptUser("Run auto backup with cron? (yes|no)", 'yes') eq 'yes') {

                #create cron job...
                my $cron = getSitedomain($domain);
                $cron =~ s/\//_/g;
                $cron =~ s/\./_/g;

                if(not -f "/etc/cron.d/$cron") {

                    my $mdb = int(rand(60));
                    $mdb = ($mdb < 10)? '0'.$mdb : $mdb;

                    my $hdb = int(rand(24));
                    $hdb = ($hdb < 10)? '0'.$hdb : $hdb;

                    my $mfile = int(rand(60));
                    $mfile = ($mfile < 10)? '0'.$mfile : $mfile;

                    my $hfile = int(rand(24));
                    $hfile = ($hfile < 10)? '0'.$hfile : $hfile;

                    my $dfile = int(rand(7));
                    $dfile = ($dfile < 10)? '0'.$dfile : $dfile;

                    %vars = (
                                'perl', which('perl'),
                                'envShell', which('bash'),
                                'envUser', $envUser,
                                'envPath', $ENV{PATH},
                                'path', "$dir/$domain/private",
                                'mdb', $mdb,
                                'hdb', $hdb,
                                'mfile', $mfile,
                                'hfile', $hfile,
                                'dfile', $dfile
                            );

                    $template = Text::Template->new(SOURCE => "$scriptPath/s88c/tmpl/cron.tmpl") or die "Couldn't construct template: $Text::Template::ERROR";
                    $result = $template->fill_in(HASH => \%vars);

                    if (defined $result) {

                        open (FILE, ">/etc/cron.d/$cron");
                        print FILE $result;
                        close (FILE);

                        system "chown root:root /etc/cron.d/$cron";

                        printNotice('Cron created', "/etc/cron.d/$cron");
                    }
                }
                else {
                    printComment("/etc/cron.d/$cron file already exists");
                }
            }
		}
	}

	if(-d "/etc/cron.d") {
	    if(&promptUser("Setup Drupal Cron? (yes|no)", 'yes') eq 'yes') {
	        drupalCron($dir, $domain);
	    }
	}
}

sub deleteSite {

	my $path = shift;
	my $dir = shift;

	#delete db
	if (-f "$path/$dir/private/db.pl") {
		if(&promptUser('Delete db? (yes|no)', 'no') eq 'yes') {
			if(confirm()) {
				system "$path/$dir/private/db.pl delete ".$main::database->{'host'}." ".$main::database->{'username'}." ".$main::database->{'password'};

				#delete cron
				my $cron = getSitedomain($dir);
				$cron =~ s/\//_/g;
				$cron =~ s/\./_/g;

				if(-f "/etc/cron.d/$cron") {
					system "rm -f /etc/cron.d/$cron";
				}
			}
		}
	}

	if (-d "$path/$dir/httpdocs") {
		if(&promptUser("Delete httpdocs? (yes|no)", 'no') eq 'yes') {
			system "rm -rf $path/$dir/httpdocs" if(confirm());

			#delete cron
			my $cron = "drupal_".getSitedomain($dir);
			$cron =~ s/\//_/g;
			$cron =~ s/\./_/g;

			if(-f "/etc/cron.d/$cron") {
				system "rm -f /etc/cron.d/$cron";
			}
		}
	}

	if (-d "$path/$dir/private") {
		if(&promptUser("Delete private? (yes|no)", 'no') eq 'yes') {
			system "rm -rf $path/$dir/private" if(confirm());
		}
	}

	#final clean up
	if(-d "$path/$dir") {
		opendir(DIR, "$path/$dir");

		my $file;
		my $count = 0;

		foreach $file (readdir(DIR)) {
			$count++;
		}

		closedir(DIR);

		if($count==2) {
			system "rm -rf $path/$dir";
		}
	}
}

sub infoSite {

	my $dir = shift;
	my $domain = shift;

	printNotice('root', "$dir/$domain");

	print "\n";
	system "ls -l --color=always $dir/$domain/httpdocs";

	if (-f "$dir/$domain/private/db.pl") {
		system "$dir/$domain/private/db.pl info";
	}
}

sub dropDb {

	my $path = shift;
	my $dir = shift;

	#delete db
	if (-f "$path/$dir/private/db.pl") {
		if(&promptUser("Drop db? (yes|no)", 'no') eq 'yes') {
			if(confirm()) {
				system "$path/$dir/private/db.pl drop";
			}
		}
	}
}

sub drupalCron {

	my $dir = shift;
	my $domain = shift;

	my $target = "$dir/$domain/httpdocs";
	my $app = $main::config->{'app'};
	my $scriptPath = $main::scriptPath;

    my $envUser;

    if(!$ENV{USER}) {
        $envUser = 'root';
    } else {
        $envUser = 'www-data';
    }

	#create cron job...
	my $cron = "drupal_".getSitedomain($domain);
	$cron =~ s/\//_/g;
	$cron =~ s/\./_/g;

	if(not -f "/etc/cron.d/$cron") {

        my $drush = which('drush');

		if($drush) {

			$app = &promptUser("Enter application name",  'app') unless ($app);

			my $m = int(rand(60));
			$m = ($m < 10)? '0'.$m : $m;

			my %vars = (
							'drush', $drush,
							'envShell', which('bash'),
                            'envPath', $ENV{PATH},
                            'envUser', $envUser,
							'domain', $domain,
							'path', "$target/$app",
							'm', $m
				       );

			my $template = Text::Template->new(SOURCE => "$scriptPath/s88c/tmpl/drupal.cron.tmpl") or die "Couldn't construct template: $Text::Template::ERROR";
	        my $result = $template->fill_in(HASH => \%vars);

	        if (defined $result) {

				open (FILE, ">/etc/cron.d/$cron");
				print FILE $result;
				close (FILE);

				system "chown root:root /etc/cron.d/$cron";

				printNotice('Cron created', "/etc/cron.d/$cron");
			}
		}
		else {
			printError('Drush is not installed');
		}
	}
	else {
		printComment("/etc/cron.d/$cron file already exists");
	}
}

#--------------------------------------------

1;
