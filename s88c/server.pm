use strict;
use warnings;

sub createConfiguration {

	my $scriptPath = $main::scriptPath;

	my $app = 'app';
	my $perusio = 0;

	my $dbhost;
	my $dbusername;
	my $dbpassword;
	my $tcp = 0;

	printLabel('Wizard');

	if((not -f "$scriptPath/s88c/config.cfg") || confirm('Overwrite config file')) {
		$app = &promptUser("Enter application folder name", 'app') unless ($app);


        if(&promptUser("Use perusio nginx configuration? (yes|no)", 'no') eq 'yes') {
            $perusio = 1;
        }

		$dbhost = &promptUser("Enter mysql host", 'localhost') unless ($dbhost);

        if(&promptUser("Force TCP? (yes|no)", 'no') eq 'yes') {
            $tcp = 1;
        }

		$dbusername = &promptUser("Enter mysql root username", 'root') unless ($dbusername);
		$dbpassword = &promptUser("Enter mysql root password") unless ($dbpassword);

		if($dbusername eq 'root' && confirm('Set mysql root password')) {

			print "\nThis will only work if the previous mysql root password was empty (fresh install)\n";
			system "mysqladmin -h$dbhost -u$dbusername password '$dbpassword'";
		}

		if(confirm('Test mysql connection', 'yes')) {
			system "mysqladmin -h$dbhost -u$dbusername -p$dbpassword version";

			while(not confirm('Did the connection works?', 'yes')) {
				$dbhost = &promptUser("Enter mysql host", $dbhost);
				$dbusername = &promptUser("Enter mysql root username", 'root');
				$dbpassword = &promptUser("Enter mysql root password", $dbpassword);

				system "mysqladmin -h$dbhost -u$dbusername -p$dbpassword version";
			}
		}

		package main; {
			our $config = {
						'app' => $app,
						'perusio' => $perusio
	                };

			our $database = {
						'password' => $dbpassword,
						'username' => $dbusername,
						'host' => $dbhost,
						'tcp' => $tcp
	                };
		}

		writeConfigurationFile("$scriptPath/s88c/config.cfg");
	}
}

1;
