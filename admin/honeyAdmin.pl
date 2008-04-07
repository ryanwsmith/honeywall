#!/usr/bin/perl -w

# (C) 2005 The Honeynet Project.  All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA
#
#----- Authors: Scott Buchan <sbuchan@hush.com>

use strict;
use warnings;
use Template;

use DBI;
use DBD::mysql;

use CGI qw/:standard/;
use CGI::Carp 'fatalsToBrowser';
use File::stat;
use Walleye::Admin;
use Walleye::AdminUtils;

#  Validate login
my $session = validate_user();
my $role = $session->param("role");
 
my %hw_vars = hw_get_vars();

if($role ne "admin") {
	error("You are not authorized to access this page.", "true");
}

#check_action();

display_header_page($session);
check_action();
display_page();
display_footer_page();


sub check_action {
	
	my $action = "";

        if(defined param("act")) {
                $action = param("act");
        }
	
	SWITCH: {
		if($action eq "createConfig") { create_config(); last SWITCH;}
		if($action eq "uploadConfig") { upload_config(); last SWITCH;}		
		if($action eq "lockdown") { emergency_lockdown(); last SWITCH;}
		if($action eq "activate") { activate_honeywall(); last SWITCH;}
		if($action eq "reload") { reload_honeywall(); last SWITCH;}
	}

}


sub create_config {
	my $title = "Create configuration file(s)";
	my $msg;
	
	# Check to see if the honeywall is configured.  Following along with the dialog script,
	# if the HwHOSTNAME file exists and is not empty then the system is configured.
	if (!defined $hw_vars{"HwHOSTNAME"} && $hw_vars{"HwHOSTNAME"} eq "") {
		error("This Honeywall has not been configured.");
	}
	
	if (param("cmd") eq "file") {
		create_honeywall_conf_file();
		$msg = "The /etc/honeywall.conf file has been created.";
	} elsif (param("cmd") eq "files") {
		create_honeywall_conf_files();
		$msg = "The configuration files have been created.";
	}
	display_admin_msg($title, $msg);

}

# Creates a honeywall.conf file from conf files
sub create_honeywall_conf_file {

	# Create a temp file
	my $tmp_file = "/tmp/tmp.conf";
	my $key;
	my $file = "/etc/honeywall.conf";
	my $cmd = "mv -f $tmp_file $file"; 
	my $status;
	
	open(FILE,">$tmp_file") or error("Could not open file $tmp_file $!");
	foreach $key (keys %hw_vars) {
		print FILE "$key=$hw_vars{$key}\n";
	}

	close(FILE);
	
	$status = system("sudo $cmd");
	error("Could not run command: $cmd $?") unless $status == 0;	

}

# Creates conf files from honeywall.conf
sub create_honeywall_conf_files {
	my $key;
	my $conf_file = "/etc/honeywall.conf";
	my $status;
	my $file;

	my $conf_dir = get_conf_dir();

	open(FILE,"<$conf_file") or error("Could not open file $conf_file $!");
	while(<FILE>) {
		chomp;
		s/#.*//;
		s/^\s+//;
		s/\s+$//;
		next unless length;
		my($var, $value) = split(/\s*=\s*/, $_, 2);
		hwsetvar($var, $value);
	}


}

sub upload_config {
	my $file = param("uploadFile");
	my $tmp_file = "/tmp/tmp_honeywall.conf";
	my $cmd = "mv -f $tmp_file /etc/honeywall.conf"; 
	my $status;
	my $title = "Upload Configuration file";
	my $msg = "Configuration file has been uploaded to /etc/honeywall.conf.";

	# Check to see if the honeywall is configured.  Following along with the dialog script,
	# if the HwHOSTNAME file exists and is not empty then the system is configured.
	if (!defined $hw_vars{"HwHOSTNAME"} || $hw_vars{"HwHOSTNAME"} eq "") {
		error("This Honeywall has not been configured.");
	}


	if($file) {
		open(UPLOAD, ">$tmp_file") or error("Could not open file $tmp_file $!");
		my ($data, $length, $chunk);
		while($chunk = read($file, $data, 1024)) {
			print UPLOAD $data;
			$length += $chunk;
			if($length > 51200) {
				error("File length is too long");
			}
		}
		close(UPLOAD);
	}

	$status = system("sudo $cmd");
	error("Could not run command: $cmd $?") unless $status == 0;

	#display_admin_msg($title, $msg);

		
}	

sub emergency_lockdown {
	my $cmd = "/etc/init.d/rc.firewall stop >/dev/null";
	my $cmd2 = "/etc/init.d/bridge.sh stop > /dev/null";
	my $status;
	my $title = "Emergency Lockdown";
	my $msg = "All traffic has been dropped except to management interface";
	
	$status = system("sudo $cmd");
	error("Could not run command: $cmd $?") unless $status == 0;

	$status = system("sudo $cmd2");
        error("Could not run command: $cmd2 $?") unless $status == 0;

	display_admin_msg($title, $msg);	

}

sub activate_honeywall {

	my @process;
	my $proc;
	my $conf_dir = get_conf_dir();
	my $status;
	my %input;
	my $key;
	my $file;
	my $title = "Activate Honeywall";
	my $msg = "The Honeywall has been activated.";

	$input{"HwHONEYWALL_RUN"} = param("HwHONEYWALL_RUN");
	if ($input{"HwHONEYWALL_RUN"} ne "yes") {
		$input{"HwHONEYWALL_RUN"} = "no";
	}

	# Check to see if the honeywall is configured.  Following along with the dialog script,
	# if the HwHOSTNAME file exists and is not empty then the system is configured.
	if (!defined $hw_vars{"HwHOSTNAME"} && $hw_vars{"HwHOSTNAME"} eq "") {
		error("This Honeywall has not been configured.");
	}

	$process[0] = "/etc/init.d/bridge.sh start &>/dev/null";
	$process[1] = "/etc/init.d/rc.firewall restart >/dev/null";

	# The following have been commented out of the dialog script.
	#$process[2] = "/etc/init.d/snort.sh restart >/dev/null";
	#$process[3] = "/etc/init.d/pcap.sh restart >/dev/null";
	#if ($hw_vars{"HwQUEUE"} ne "yes") {
	#	$process[4] = "/etc/init.d/snort_inline.sh restart >/dev/null";
	#}

	hw_set_vars(\%input);

	# loop through process array here
	foreach $proc (@process) {
		$status = system("sudo $proc");
		error("Could not run $proc $?") unless $status == 0;
	}

	display_admin_msg($title, $msg);

}

sub reload_honeywall {

	my @process;
	my $proc;
	my $conf_dir = get_conf_dir();
	my $status;
	my $file;
	my %input;
	my $selection;
	my $title = "Reload Honeywall";
	my $msg = "The following processes have been started or restarted: ";

	$input{"HwHONEYWALL_RUN"} = param("HwHONEYWALL_RUN");
    if ($input{"HwHONEYWALL_RUN"} ne "yes") {
        $input{"HwHONEYWALL_RUN"} = "no";
    }

	hw_set_vars(\%input);

	$selection = param("reload");
	if($selection eq "bridge") {
		$process[0] = "/etc/init.d/bridge.sh start &>/dev/null";
    	$process[1] = "/etc/init.d/rc.firewall restart >/dev/null";
        $msg .= "Bridge and Firewall(restarted)";
	} elsif($selection eq "ids") {
		$process[0] = "/etc/init.d/hflow-snort restart > /dev/null";
		$msg .= "IDS Snort";
	} elsif ($selection eq "inline" && $hw_vars{"HwQUEUE"} eq "yes" ) {
		$process[0] = "/etc/init.d/hflow-snort_inline restart > /dev/null";
		$msg .= "Snort-Inline";
	} elsif ($selection eq "pcap") {
		$process[0] = "/etc/init.d/hflow-pcap restart > /dev/null";
		$msg .= "Pcap Snort";
	} elsif ($selection eq "firewall") {
		$process[0] = "/etc/init.d/rc.firewall restart > /dev/null";
		$msg .= "Firewall";
	} elsif ($selection eq "honeywall") {
		$process[0] = "/etc/init.d/rc.firewall restart > /dev/null";
		$process[1] = "/etc/init.d/hflow-snort restart > /dev/null";
		$process[2] = "/etc/init.d/hflow-pcap restart > /dev/null";
		$process[3] = "/etc/init.d/hflow-p0f restart > /dev/null";
		$process[4] = "/etc/init.d/sebekd restart > /dev/null";
		$process[5] = "/etc/init.d/hflow-argus restart > /dev/null";
		$process[6] = "/etc/init.d/hflowd restart ";
		$msg .= "Firewall, Snort, Pcap, p0f, sebekd, argus, hflowd";
		if ($hw_vars{"HwQUEUE"} eq "yes" ) {
			$process[7] = "/etc/init.d/hflow-snort_inline restart > /dev/null";
			$msg .= ", Snort-Inline";
		}
	}
		
	# loop through process array here
	foreach $proc (@process) {
		$status = system("sudo $proc");
		error("Could not run $proc $?") unless $status == 0;
	}
	
	display_admin_msg($title, $msg);
}

# Copy the honeywall.conf file to a directory that apache can access for downloading.
sub copy_conf {
	my $file = "/etc/honeywall.conf";
	my $cmd = "cp $file /var/www/html/walleye/admin/honeywall.conf"; 
	my $status;

	$status = system("sudo $cmd");
	error("Could not run command: $cmd $?") unless $status == 0;	

}
	
sub display_page {

	my $input;

	# Refresh honeywall variables
	my %hw_vars = hw_get_vars();
	
	SWITCH: {
		if(param("disp") eq "createConfig") { $input = "templates/adminCreateConfig.htm"; copy_conf(); last SWITCH;}
		if(param("disp") eq "uploadConfig") { $input = "templates/adminUploadConfig.htm"; last SWITCH;}
		if(param("disp") eq "lockdown") { $input = "templates/adminLockdown.htm"; last SWITCH;}
		if(param("disp") eq "activate") { $input = "templates/adminActivate.htm"; last SWITCH;}
		if(param("disp") eq "reload") { $input = "templates/adminReload.htm"; last SWITCH;}

		$input = "templates/admin.htm";
	}



	my $tt = Template->new( );
	
	my $vars  = {
		health_table =>  Walleye::Admin::gen_honeywall_health(),
		vars => \%hw_vars,
	};
	
	$tt->process($input, $vars)
	    || die $tt->error( );


}

