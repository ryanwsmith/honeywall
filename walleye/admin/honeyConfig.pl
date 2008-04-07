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

use Walleye::AdminUtils;
use Walleye::Util;
use Time::Local;

#  Validate login
my $session = validate_user();

my $role = $session->param("role");

if($role ne "admin") {
	error("You are not authorized to access this page.", "true");
}

my %hw_vars = hw_get_vars();

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
		if($action eq "configIP") { mode_ip_config(); last SWITCH;}
		if($action eq "configRemote") { config_remote(); last SWITCH;}
		if($action eq "configLimiting") { config_limiting(); last SWITCH;}
		if($action eq "configDNS") { config_dns(); last SWITCH;}
		if($action eq "configAlerting") { config_alerting(); last SWITCH;}
		if($action eq "configSnort") { config_snort(); last SWITCH;}
		if($action eq "configUpload") { config_upload(); last SWITCH;}
		if($action eq "configSummary") { config_summary(); last SWITCH;}
		if($action eq "configBlackWhite") { config_black_white(); last SWITCH;}
		if($action eq "configSebek") { config_sebek(); last SWITCH;}
		if($action eq "configFence") { config_fence(); last SWITCH;}
		if($action eq "configRoach") { config_roach(); last SWITCH;}
		if($action eq "configUploadFile") { config_upload_file(); last SWITCH;}
		if($action eq "configDataManage") { config_data_manage(); last SWITCH;}
		if($action eq "configSensor") { config_sensor(); last SWITCH;}


	}

}

sub view_sensor_details {
	my $sensor = param("sensorId");
	my $query = "select * from sensor where sensor_id=$sensor";
    my $results;
    my $ref;
	my $installed;
	my $updated;

    Walleye::Util::setup(1,1,1);
    $results = $Walleye::Util::dbh->prepare($query);
    $results->execute();
    $ref = $results->fetchrow_arrayref();

	# format dates installed and updated
	$installed = gmtime($$ref[1]);
	$updated = gmtime($$ref[2]);
	$$ref[1] = $installed;
	$$ref[2] = $updated;
    return $ref;


}

sub get_sensors {
	my $query = "select * from sensor";
	my $results;
	my $ref;

	Walleye::Util::setup(1,1,1);
	$results = $Walleye::Util::dbh->prepare($query);
	$results->execute();
	$ref = $results->fetchall_arrayref();

	return $ref;

}

sub config_sensor {
	my $name = SqlQuote(param("name"));
	my $timeZone = param("timeZone");
	my $countryCode = SqlQuote(param("countryCode"));
	#my $latitude = param("latitude");
	#my $longitude = param("longitude");
	my $notes = SqlQuote(param("notes"));
	my $networkType = SqlQuote(param("networkType"));
	my $sensorId = param("sensorId");
	my $results;
	my $ref;
	my $time = timelocal(localtime);
	my $title = "Honeynet Demographics";
	my $msg = "Your Honeywall Demographics have been configured.";

	#my $query = "update sensor set name=". $name . ", timezone=" . $timeZone . ", country_code=" 
	#			. $countryCode . ", latitude=" . $latitude . ", longitude=". $longitude . ",
	#			notes=" . $notes . ", network_type=" . $networkType . ", last_upd_sec=" . $time
	#			. " where sensor_id=" . $sensorId;

	my $query = "update sensor set name=". $name . ", timezone=" . $timeZone . ", country_code=" 
				. $countryCode . ", notes=" . $notes . ", network_type=" . $networkType . ",
				 last_upd_sec=" . $time . " where sensor_id=" . $sensorId;

				

	ConnectToWalleyeDatabase();
    SendSQL($query);

	display_admin_msg($title, $msg);

}


sub config_upload_file {
	my $file = param("uploadFile");
	my $save_to_file = param("saveToFile");

	# Strip off path from file name
	my @tmp_name = split /\//, $save_to_file;

        my $tmp_file = "/tmp/$tmp_name[2]";
        my $cmd = "mv -f $tmp_file $save_to_file";
        my $status;

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

}

sub config_roach {
        my %input;
        my $conf_dir = get_conf_dir();
        my $status;
        my $process;
        my $title = "Roach Motel Mode";
        my $msg = "The Honeywall Gateway Roach Motel Mode has been configured.";
		my $key;

		$input{HwROACHMOTEL_ENABLE} = param("HwROACHMOTEL_ENABLE");

		if(!defined $input{"HwROACHMOTEL_ENABLE"}) {
        	$input{"HwROACHMOTEL_ENABLE"} = "no";
    	}

		#hw_set_vars(\%input);
		hw_run_hwctl(\%input);

    	display_admin_msg($title, $msg);

}

sub config_fence {

        my $DEFAULT_FENCE = "/etc/fencelist.txt";
        my %input;
        my $conf_dir = get_conf_dir();
        my $status;
        my $proc;
        my $title = "Fence List Variables";
        my $msg = "The Honeywall Gateway Fence list variables have been configured.";
		my $key;

        $input{"HwFWFENCE"} = param("HwFWFENCE");
	    $input{"HwFENCELIST_ENABLE"} = param("HwFENCELIST_ENABLE");

        if (!defined $input{"HwFWFENCE"} || $input{"HwFWFENCE"} eq "") {
                $input{"HwFWFENCE"} = $DEFAULT_FENCE;
        }

		if(!defined $input{"HwFENCELIST_ENABLE"}) {
			$input{"HwFENCELIST_ENABLE"} = "no";
		}
 
        # Check to see if files exist
        check_file_status($input{"HwFWFENCE"});


        #hw_set_vars(\%input);
		hw_run_hwctl(\%input);

    display_admin_msg($title, $msg);

}

sub config_sebek {

	my %input;
	my $conf_dir = get_conf_dir();
	my $status;
	my $key;
	my $file;
	my @process;
	my $proc;
	my $options;
	my $title = "Configure Sebek Variables";
    my $msg = "The Honeywall Gateway Sebek variables have been configured.";

	my $err_msg = "This Honeywall has not been configured.  Please run Initial Setup from the main menu.  Then use this option to configure your sebek variables.";
	
	$input{"HwSEBEK"} = param("HwSEBEK");
	$input{"HwSEBEK_DST_IP"} = param("HwSEBEK_DST_IP");
	$input{"HwSEBEK_DST_PORT"} = param("HwSEBEK_DST_PORT");
	$options = param("options");

	if(!defined param("HwSEBEK")) {
		$input{"HwSEBEK"} = "no";
	}


	SWITCH: {
		if($options eq "drop") { $input{"HwSEBEK_FATE"} = "DROP";
					          $input{"HwSEBEK_log"} = "no"; last SWITCH;}
		if($options eq "dropLog") { $input{"HwSEBEK_FATE"} = "DROP";
						     $input{"HwSEBEK_log"} = "yes"; last SWITCH;}
		if($options eq "accept") { $input{"HwSEBEK_FATE"} = "ACCEPT";
						    $input{"HwSEBEK_log"} = "no"; last SWITCH;}
		if($options eq "acceptLog") { $input{"HwSEBEK_FATE"} = "ACCEPT";
						       $input{"HwSEBEK_log"} = "yes"; last SWITCH;}
	}

	#hw_set_vars(\%input);	
	hw_run_hwctl(\%input);

	display_admin_msg($title, $msg);
	
}

sub config_black_white {

	my $DEFAULT_BLACK = "/etc/blacklist.txt";
	my $DEFAULT_WHITE = "/etc/whitelist.txt";
	my %input;
	my $conf_dir = get_conf_dir();
	my $status;
	my $key;
	my $file;
	my @process;
	my $proc;
	my $title = "Black and White List Variables";
        my $msg = "The Honeywall Gateway Black and White list variables have been configured.";

	
	$input{"HwFWBLACK"} = param("HwFWBLACK");
	$input{"HwFWWHITE"} = param("HwFWWHITE");
	$input{"HwBWLIST_ENABLE"} = param("HwBWLIST_ENABLE");
	
	if (!defined $input{"HwFWBLACK"} || $input{"HwFWBLACK"} eq "") {
		$input{"HwFWBLACK"} = $DEFAULT_BLACK;
	}

	if (!defined $input{"HwFWWHITE"} || $input{"HwFWWHITE"} eq "") {
		$input{"HwFWWHITE"} = $DEFAULT_WHITE;
	}

	# Check to see if files exist
	#check_file_status($input{"HwFWWHITE"});
	#check_file_status($input{"HwFWBLACK"});


	if (defined $input{"HwBWLIST_ENABLE"}) {
		 # Check to see if files exist
        	check_file_status($input{"HwFWWHITE"});
        	check_file_status($input{"HwFWBLACK"});
		$process[0] = "/dlg/config/createWhiteRules.pl > /dev/null";
		$process[1] = "/dlg/config/createBlackRules.pl > /dev/null";
		$process[2] = "/dlg/config/createBPFFilter.pl > /dev/null";
		$process[3] = "/etc/init.d/rc.firewall restart > /dev/null";
		$process[4] = "/etc/init.d/hw-pcap restart > /dev/null";
		$process[5] = "/etc/init.d/hflow restart > /dev/null";
	} else {
		$input{"HwBWLIST_ENABLE"} = "no";
		$process[0] = "/etc/init.d/rc.firewall restart > /dev/null";
		$process[1] = "/etc/init.d/hw-pcap restart > /dev/null";
		$process[2] = "/etc/init.d/hflow restart > /dev/null";
		$msg = "The Honeywall Gateway Black and White list have been disabled.";
	}

	hw_set_vars(\%input);
	
	# loop through process array here
	foreach $proc (@process) {
		$status = system("sudo $proc");
		error("Could not run $proc $?") unless $status == 0;
	}

	display_admin_msg($title, $msg);

}

sub config_data_manage{
        my $DEFAULT_PCAPDAYS = "280";
        my $DEFAULT_DBDAYS = "240";
	my $purge_now="no";
        my %input;
        my $conf_dir = get_conf_dir();
        my $status;
        my $key;
        my $file;
        my @process;
        my $proc;

        $input{"HwPCAPDAYS"} = param("HwPCAPDAYS");
        $input{"HwDBDAYS"} = param("HwDBDAYS");
        $purge_now = param("HwDATA_PURGE_NOW");

        if (!defined $input{"HwPCAPDAYS"} || $input{"HwPCAPDAYS"} eq "") {
                $input{"HwPCAPDAYS"} = $DEFAULT_PCAPDAYS;
        }

        if (!defined $input{"HwDBDAYS"} || $input{"HwDBDAYS"} eq "") {
                $input{"HwDBDAYS"} = $DEFAULT_DBDAYS;
        }

	hw_set_vars(\%input);

	#now make the processes
	if($purge_now eq "yes"){
		$process[0] = "/dlg/config/purgePcap.pl";
		$process[1] = "/dlg/config/purgeDB.pl";
	}

        # loop through process array here
        foreach $proc (@process) {
		#again more into sudo
                $status = system("sudo $proc");
                error("Could not run $proc $?") unless $status == 0;
        }




}

sub config_summary {

	my %input;
	my $conf_dir = get_conf_dir();
	my $status;
	my $key;
	my $file;
	my $title = "Honeywall Summary Configuration";
        my $msg = "The Honeywall Gateway summary has been configured.";
	
	$input{"HwSUMNET"} = param("HwSUMNET");

	#hw_set_vars(\%input);
	hw_run_hwctl(\%input);

    display_admin_msg($title, $msg);

}

sub config_upload {

	my %input;
	my $conf_dir = get_conf_dir();
	my $status;
	my $key;
	my $file;
	my $title = "Honeywall Upload Configuration";
    my $msg = "The Honeywall Gateway upload has been configured.";
	
	# dlg script sets default ???
	#$input{"Hw_UP_SYSLOG"} = "1";
	$input{"Hw_UP_HOST"} = param("Hw_UP_HOST");
	$input{"Hw_UP_PORT"} = param("Hw_UP_PORT");
	$input{"Hw_UP_USER"} = param("Hw_UP_USER");
	$input{"Hw_UP_SYSLOG"} = param("Hw_UP_SYSLOG");
	$input{"Hw_UP_SRC"} = param("Hw_UP_SRC");
	$input{"Hw_UP_DEST"} = param("Hw_UP_DEST");
	$input{"Hw_UP_FWLOG"} = param("Hw_UP_FWLOG");
	$input{"Hw_UP_PCAPLOG"} = param("Hw_UP_PCAPLOG");
	$input{"Hw_UP_OBFUSCATE"} = param("Hw_UP_OBFUSCATE");

	if (!defined $input{"Hw_UP_FWLOG"} ) {
		$input{"Hw_UP_FWLOG"} = "0";
	}

	if (!defined $input{"Hw_UP_PCAPLOG"}) {
		$input{"Hw_UP_PCAPLOG"} = "0";
	}

	if (!defined $input{"Hw_UP_OBFUSCATE"} ) {
		$input{"Hw_UP_OBFUSCATE"} = "0";
	}

	#hw_set_vars(\%input);
	hw_run_hwctl(\%input);

	display_admin_msg($title, $msg);

}

sub config_snort {
	my $rule;
	my %input;
	my $conf_dir = get_conf_dir();
	my $status;
	my $key;
	my $file;
	my @process;
	my $proc;
	my $title = "Configure snort_inline";
	my $msg = "The Honeywall Gateway snort_inline has been configured.";
	
	$rule = param("rule");
	$proc = "/dlg/config/snort_inline_conf.pl $rule > /dev/null";
	$status = system("sudo $proc");
	error("Could not run $proc $?") unless $status == 0;

	if(defined param("HwQUEUE")) {
		$input{"HwQUEUE"} =  param("HwQUEUE");
	} else {
		$input{"HwQUEUE"} = "no";
	}

	if( $input{"HwQUEUE"}  eq "no") {
		$process[0] = "/etc/init.d/hw-snort_inline stop";
		$process[1] = "/etc/init.d/rc.firewall restart";
	} else {
		$process[0] = "/etc/init.d/rc.firewall restart > /dev/null";
        $process[1] = "/etc/init.d/hw-snort_inline restart > /dev/null";
	}

	#hw_set_vars(\%input);
	hw_run_hwctl(\%input);

	# loop through process array here
	foreach $proc (@process) {
		$status = system("sudo $proc");
		error("Could not run $proc $?") unless $status == 0;
	}
	
	display_admin_msg($title, $msg);

}

sub config_alerting {

	my %input;
	my $conf_dir = get_conf_dir();
	my $status;
	my $key;
	my $file;
	my @process;
	my $proc;
	my $title = "Configure Alerting";
	my $msg = "The Honeywall Gateway Alerting has been updated.";
	
	$input{"HwALERT_EMAIL"} = param("HwALERT_EMAIL");
	$input{"HwALERT"} = param("HwALERT");

	if ($input{"HwALERT"} ne "yes") {
		$input{"HwALERT"} = "no";
	}

	hw_run_hwctl(\%input);

	display_admin_msg($title, $msg);

}



sub config_dns {
	my %input;
	my $conf_dir = get_conf_dir();
	my $status;
	my $key;
	my $file;
	my $title = "DNS Handling";
    my $msg = "The Honeywall Gateway DNS Handling has been updated.";

	$input{"HwDNS_HOST"} = param("HwDNS_HOST");
	$input{"HwDNS_SVRS"} = param("HwDNS_SVRS");

	#hw_set_vars(\%input);
	hw_run_hwctl(\%input);

	display_admin_msg($title, $msg);


}

sub config_limiting {
	my %input;
	my $conf_dir = get_conf_dir();
	my $status;
	my $key;
	my $file;
	my $title = "Connection Limiting";
    my $msg = "The Honeywall Gateway Connection Limiting has been updated.";
	
	$input{"HwSCALE"} = param("HwSCALE");
	$input{"HwTCPRATE"} = param("HwTCPRATE");
	$input{"HwUDPRATE"} = param("HwUDPRATE");
	$input{"HwICMPRATE"} = param("HwICMPRATE");
	$input{"HwOTHERRATE"} = param("HwOTHERRATE");

	#hw_set_vars(\%input);
	hw_run_hwctl(\%input);

	display_admin_msg($title, $msg);

}

sub config_remote {

	my %input;
	my $conf_dir = get_conf_dir();
	my $status;
	my $key;
	my $file;
	my $title = "Remote Management";
    my $msg = "The Honeywall Gateway remote configuration has been updated.";
	my $restrict = "";
	my $run_walleye = "";
	
	$input{"HwMANAGE_IP"} = param("HwMANAGE_IP");
	$input{"HwMANAGE_NETMASK"} = param("HwMANAGE_NETMASK");
	$input{"HwMANAGE_GATEWAY"} = param("HwMANAGE_GATEWAY");
	$input{"HwDOMAIN"} = param("HwDOMAIN");
	$input{"HwMANAGE_DNS"} = param("HwMANAGE_DNS");
	$input{"HwMANAGER"} = param("HwMANAGER");
	$input{"HwALLOWED_TCP_IN"} = param("HwALLOWED_TCP_IN");
	$input{"HwALLOWED_TCP_OUT"} = param("HwALLOWED_TCP_OUT");
	$input{"HwALLOWED_UDP_OUT"} = param("HwALLOWED_UDP_OUT");
	$input{"HwRESTRICT"} = param("HwRESTRICT");
	$input{"HwWALLEYE"} = param("HwWALLEYE");

	if(defined $input{"HwRESTRICT"}) {
		$restrict = $input{"HwRESTRICT"};
	}

	if(defined $input{"HwWALLEYE"}) {
		$run_walleye = $input{"HwWALLEYE"};
	}

	if ($restrict ne "yes") {
		$input{"HwRESTRICT"} = "no";
	}

	if ($run_walleye ne "yes") {
		$input{"HwWALLEYE"} = "no";
	}

	#hw_set_vars(\%input);
	
	hw_run_hwctl(\%input);
	
	display_admin_msg($title, $msg);
}	

sub mode_ip_config {
	my $conf_dir = get_conf_dir();
	my $status;

	my %input;
	my $key;
	my $file;
	my @process;
	my $proc;
	my $title = "Mode and IP Configuration";
	my $msg = "Mode and IP has been configured.";

	#$input{"HwMODE"} = param("HwMODE");
	$input{"HwHPOT_PUBLIC_IP"} = param("HwHPOT_PUBLIC_IP");
	#$input{"HwHPOT_IP"} = param("HwHPOT_IP");
	#$input{"HwALIAS_MASK"} = param("HwALIAS_MASK");
	$input{"HwINET_IFACE"} = param("HwINET_IFACE");
	$input{"HwLAN_IFACE"} = param("HwLAN_IFACE");
	$input{"HwLAN_BCAST_ADDRESS"} = param("HwLAN_BCAST_ADDRESS");
	$input{"HwLAN_IP_RANGE"} = param("HwLAN_IP_RANGE");

	if($hw_vars{"HwINET_IFACE"} ne $input{"HwINET_IFACE"} || $hw_vars{"HwLAN_IFACE"} ne $input{"HwLAN_IFACE"}) {
		$process[0] = "/etc/rc.d/init.d/hwdaemons stop > /dev/null";
    		$process[1] = "/etc/rc.d/init.d/hwdaemons start > /dev/null";
		
		# loop through process array here
        	foreach $proc (@process) {
                	$status = system("sudo $proc");
                	error("Could not run $proc $?") unless $status == 0;
        	}
	}


	#hw_set_vars(\%input);
	hw_run_hwctl(\%input);

	display_admin_msg($title, $msg);

}


# Copy the honeywall.conf file to a directory that apache can access for downloading.
sub copy_conf {
	my $file = "/etc/honeywall.conf";
	my $cmd = "cp $file honeywall.conf"; 
	my $status;

	$status = system("sudo $cmd");
	error("Could not run command: $cmd $?") unless $status == 0;	

}

sub display_page {

	my $input;
	my $title = "";
	my $forwardPage = "";
	my $file = "";
	my $sensors;
	my $sensor_details;
	my $time_zones;
	my $country_codes;

	# Refresh honeywall variables
	my %hw_vars = hw_get_vars();

	my $disp = "";

        if(defined param("disp")) {
                $disp = param("disp");
        }

	
	SWITCH: {
		if($disp eq "configIP") { $input = "templates/adminConfigIp.htm"; last SWITCH;}
		if($disp eq "configRemote") { $input = "templates/adminConfigRemote.htm"; last SWITCH;}
		if($disp eq "configLimiting") { $input = "templates/adminConfigLimiting.htm"; last SWITCH;}
		if($disp eq "configDNS") { $input = "templates/adminConfigDNS.htm"; last SWITCH;}
		if($disp eq "configAlerting") { $input = "templates/adminConfigAlerting.htm"; last SWITCH;}
		if($disp eq "configSnort") { $input = "templates/adminConfigSnort.htm"; last SWITCH;}
		if($disp eq "configUpload") { $input = "templates/adminConfigUpload.htm"; last SWITCH;}
		if($disp eq "configSummary") { $input = "templates/adminConfigSummary.htm"; last SWITCH;}
		if($disp eq "configBlackWhite") { $input = "templates/adminConfigBlackWhite.htm"; last SWITCH;}
		if($disp eq "configSebek") { $input = "templates/adminConfigSebek.htm"; last SWITCH;}
		if($disp eq "configFence") { $input = "templates/adminConfigFence.htm"; last SWITCH;}
		if($disp eq "configRoach") { $input = "templates/adminConfigRoach.htm"; last SWITCH;}
		if($disp eq "configDataManagement") { $input = "templates/adminConfigDataManage.htm"; last SWITCH;}
		if($disp eq "configUploadBlack") { $input = "templates/adminConfigUploadFiles.htm"; 
											$title="Upload Black List File"; 
											$file = "/etc/blacklist.txt";
											$forwardPage = "configBlackWhite";
											last SWITCH;}
		if($disp eq "configUploadWhite") { $input = "templates/adminConfigUploadFiles.htm"; 
											$title="Upload White List File";
											$file = "/etc/whitelist.txt";
                                            $forwardPage = "configBlackWhite";
											last SWITCH;}
		if($disp eq "configUploadFence") { $input = "templates/adminConfigUploadFiles.htm";
                                            $title="Upload Fence List File"; 
											$file = "/etc/fencelist.txt";
                                            $forwardPage = "configFence";
                                            last SWITCH;}
		if($disp eq "configSensor") { $input = "templates/adminConfigSensor.htm";
									  $sensors = get_sensors();
								      last SWITCH;}
		if($disp eq "viewSensor") { $input = "templates/adminConfigEditSensor.htm";
                                      $sensor_details = view_sensor_details();
									  $time_zones = get_time_zones($sensor_details);
									  $country_codes = get_country_codes($sensor_details);
                                      last SWITCH;}
		$input = "templates/admin.htm";

	}

	my $tt = Template->new( );
	
	my $vars  = {
		vars => \%hw_vars,
		title => $title,
		file => $file,
		forwardPage => $forwardPage,
		sensors => $sensors,
		sensorDetails => $sensor_details,
		timeZones => $time_zones,
		countryCodes => $country_codes,
	};
	
	$tt->process($input, $vars)
	    || die $tt->error( );


}

sub check_time_zone {
	my ($sensor, $offset) = @_;
	my $selected = "";

	my $zone = "";
	$zone = $sensor->[5];
	if($zone eq  $offset) {
		$selected = "selected";
	}

	return $selected;
}

sub get_time_zones {
	my ($sensor) = @_;
	my $select;

	    $select = "<select name=\"timeZone\">\n
<option " . check_time_zone($sensor, -12) . " value=\"-12\" >(GMT -12:00 hours) Eniwetok, Kwajalein</option>\n
<option " . check_time_zone($sensor, -11) . " value=\"-11\" >(GMT -11:00 hours) Midway Island, Samoa</option>\n
<option " . check_time_zone($sensor, -10) . " value=\"-10\" >(GMT -10:00 hours) Hawaii</option>\n
<option " . check_time_zone($sensor, -9) . " value=\"-9\" >(GMT -9:00 hours) Alaska</option>\n
<option " . check_time_zone($sensor, -8) . " value=\"-8\" >(GMT -8:00 hours) Pacific Time (US & Canada)</option>\n
<option " . check_time_zone($sensor, -7) . " value=\"-7\" >(GMT -7:00 hours) Mountain Time (US & Canada)</option>\n
<option " . check_time_zone($sensor, -6) . " value=\"-6\" >(GMT -6:00 hours) Central Time (US & Canada), Mexico City</option>\n
<option " . check_time_zone($sensor, -5) . " value=\"-5\" >(GMT -5:00 hours) Eastern Time (US & Canada), Bogota, Lima, Quito</option>\n
<option " . check_time_zone($sensor, -4) . " value=\"-4\" >(GMT -4:00 hours) Atlantic Time (Canada), Caracas, La Paz</option>\n
<option " . check_time_zone($sensor, -3) . " value=\"-3\" >(GMT -3:00 hours) Brazil, Buenos Aires, Georgetown</option>\n
<option " . check_time_zone($sensor, -2) . " value=\"-2\" >(GMT -2:00 hours) Mid-Atlantic</option>\n
<option " . check_time_zone($sensor, -1) . " value=\"-1\" >(GMT -1:00 hours) Azores, Cape Verde Islands</option>\n
<option " . check_time_zone($sensor, 0) . " value=\"0\" >(GMT) Western Europe Time, London, Lisbon, Casablanca, Monrovia</option>\n
<option " . check_time_zone($sensor, 1) . " value=\"+1\" >(GMT +1:00 hours) CET(Central Europe Time), Brussels, Copenhagen, Madrid, Paris</option>\n
<option " . check_time_zone($sensor, 2) . " value=\"+2\" >(GMT +2:00 hours) EET(Eastern Europe Time), Kaliningrad, South Africa</option>\n
<option " . check_time_zone($sensor, 3) . " value=\"+3\" >(GMT +3:00 hours) Baghdad, Kuwait, Riyadh, Moscow, St. Petersburg, Volgograd, Nairobi</option>\n
<option " . check_time_zone($sensor, 4) . " value=\"+4\" >(GMT +4:00 hours) Abu Dhabi, Muscat, Baku, Tbilisi</option>\n
<option " . check_time_zone($sensor, 5) . " value=\"+5\" >(GMT +5:00 hours) Ekaterinburg, Islamabad, Karachi, Tashkent</option>\n
<option " . check_time_zone($sensor, 6) . " value=\"+6\" >(GMT +6:00 hours) Almaty, Dhaka, Colombo</option>\n
<option " . check_time_zone($sensor, 7) . " value=\"+7\" >(GMT +7:00 hours) Bangkok, Hanoi, Jakarta</option>\n
<option " . check_time_zone($sensor, 8) . " value=\"+8\" >(GMT +8:00 hours) Beijing, Perth, Singapore, Hong Kong, Chongqing, Urumqi, Taipei</option>\n
<option " . check_time_zone($sensor, 9) . " value=\"+9\" >(GMT +9:00 hours) Tokyo, Seoul, Osaka, Sapporo, Yakutsk</option>\n
<option " . check_time_zone($sensor, 10) . " value=\"+10\" >(GMT +10:00 hours) EAST(East Australian Standard), Guam, Papua New Guinea, Vladivostok</option>\n
<option " . check_time_zone($sensor, 11) . " value=\"+11\" >(GMT +11:00 hours) Magadan, Solomon Islands, New Caledonia</option>\n
<option " . check_time_zone($sensor, 12) . " value=\"+12\" >(GMT +12:00 hours) Auckland, Wellington, Fiji, Kamchatka, Marshall Island</option>\n
</select>\n";


	return $select;

}

sub check_country_code {
    my ($sensor, $code) = @_;
    my $selected = "";

    if($sensor->[6] eq  $code) {
        $selected = "selected";
    }

    return $selected;
}

sub get_country_codes {
	my ($sensor) = @_;
	my %codes;
	my $select;
	my $item;
	my @list;
	my $selected = "";

	$list[0] = "AF;AFGHANISTAN";
	$list[1] = "AL;ALBANIA";
	$list[2] = "DZ;ALGERIA";
	$list[3] = "AS;AMERICAN SAMOA";
	$list[4] = "AD;ANDORRA";
	$list[5] = "AO;ANGOLA";
	$list[6] = "Al;ANGUILLA";
	$list[7] = "AQ;ANTARCTICA";
	$list[8] = "AG;ANTIGUA AND BARBUDA";
	$list[9] = "AR;ARGENTINA";
	$list[10] = "AU;AUSTRALIA";
	$list[11] = "AT;AUSTRIA";
	$list[12] = "BS;BAHAMAS, THE";
	$list[13] = "BH;BAHRAIN";
	$list[14] = "BD;BANGLADESH";
	$list[15] = "BB;BARBADOS";
	$list[16] = "BE;BELGIUM";
	$list[17] = "BZ;BELIZE";
	$list[18] = "BJ;BENIN";
	$list[19] = "BM;BERMUDA";
	$list[20] = "BT;BHUTAN";
	$list[21] = "BO;BOLIVIA";
	$list[22] = "BW;BOTSWANA";
	$list[23] = "BV;BOUVET ISLAND";
	$list[24] = "BR;BRAZIL";
	$list[25] = "IO;BRITISH INDIAN OCEAN TERRITORY";
	$list[26] = "VG;BRITISH VIRGIN ISLANDS";
	$list[27] = "BN;BRUNEI";
	$list[28] = "BG;BULGARIA";
	$list[29] = "BU;BURMA";
	$list[30] = "BI;BURUNDI";
	$list[31] = "CM;CAMEROON";
	$list[32] = "CA;CANADA";
	$list[33] = "CV;CAPE VERDE";
	$list[34] = "KY;CAYMAN ISLANDS";
	$list[35] = "CF;CENTRAL AFRICAN REPUBLIC";
	$list[36] = "TD;CHAD";
	$list[37] = "CL;CHILE";
	$list[38] = "CN;CHINA";
	$list[39] = "CX;CHRISTMAS ISLAND";
	$list[40] = "CC;COCOS (KEELING) ISLANDS";
	$list[41] = "CO;COLOMBIA";
	$list[42] = "KM;COMOROS";
	$list[43] = "CG;CONGO";
	$list[44] = "CK;COOK ISLANDS";
	$list[45] = "CR;COSTA RICA";
	$list[46] = "CU;CUBA";
	$list[47] = "CY;CYPRUS";
	$list[48] = "CS;CZECHOSLOVAKIA";
	$list[49] = "DK;DENMARK";
	$list[50] = "DJ;DJIBOUTI";
	$list[51] = "DM;DOMINICA";
	$list[52] = "DO;DOMINICAN REPUBLIC";
	$list[53] = "EC;ECUADOR";
	$list[54] = "EG;EGYPT";
	$list[55] = "SV;ELSALVADOR";
	$list[56] = "GQ;EQUATORIAL GUINEA";
	$list[57] = "ET;ETHIOPIA";
	$list[58] = "FK;FALKLAND ISLANDS";
	$list[59] = "FO;FAROE ISLANDS";
	$list[60] = "FJ;FIJI";
	$list[61] = "FI;FINLAND";
	$list[62] = "FR;FRANCE";
	$list[63] = "GF;FRENCH GUIANA";
	$list[64] = "PF;FRENCH POLYNESIA";
	$list[65] = "TF;FRENCH SOUTHERN AND ANTARCTIC";
	$list[66] = "GA;GABON";
	$list[67] = "GM;GAMBIA, THE";
	$list[68] = "DD;GERMAN DEMOCRATIC REPUBLIC";
	$list[69] = "DE;GERMANY, FEDERAL REPUBLIC OF";
	$list[70] = "GH;GHANA";
	$list[71] = "GI;GIBRALTAR";
	$list[72] = "GR;GREECE";
	$list[73] = "GL;GREENLAND";
	$list[74] = "GD;GRENADA";
	$list[75] = "GP;GUADELOUPE";
	$list[76] = "GU;GUAM";
	$list[77] = "GT;GUATEMALA";
	$list[78] = "GW;GUINEA-BISSAU";
	$list[79] = "GN;GUINEA";
	$list[80] = "GY;GUYANA";
	$list[81] = "HT;HAITI";
	$list[82] = "HM;HEARD AND MCDONALD ISLANDS";
	$list[83] = "HN;HONDURAS";
	$list[84] = "HK;HONG KONG";
	$list[85] = "HU;HUNGARY";
	$list[86] = "IS;ICELAND";
	$list[87] = "IN;INDIA";
	$list[88] = "ID;INDONESIA";
	$list[89] = "IR;IRAN";
	$list[90] = "NT;IRAQ-SAUDI ARABIA NEUTRAL ZONE";
	$list[91] = "IQ;IRAQ";
	$list[92] = "IE;IRELAND";
	$list[93] = "IL;ISRAEL";
	$list[94] = "IT;ITALY";
	$list[95] = "CI;IVORY COAST";
	$list[96] = "JM;JAMAICA";
	$list[97] = "JP;JAPAN";
	$list[98] = "JT;JOHNSTON ATOLL";
	$list[99] = "JO;JORDAN";
	$list[100] = "KH;KAMPUCHEA";
	$list[101] = "KE;KENYA";
	$list[102] = "KI;KIRIBATI";
	$list[103] = "KP;KOREA, DEMOCRATIC S REPUBLIC OF";
	$list[104] = "KR;KOREA, REPUBLIC OF";
	$list[105] = "KW;KUWAIT";
	$list[106] = "LA;LAOS";
	$list[107] = "LB;LEBANON";
	$list[108] = "LS;LESOTHO";
	$list[109] = "LR;LIBERIA";
	$list[110] = "LY;LIBYA";
	$list[111] = "LI;LIECHTENSTEIN";
	$list[112] = "LU;LUXEMBOURG";
	$list[113] = "MO;MACAU";
	$list[114] = "MG;MADAGASCAR";
	$list[115] = "MW;MALAWI";
	$list[116] = "MY;MALAYSIA";
	$list[117] = "MV;MALDIVES";
	$list[118] = "ML;MALI";
	$list[119] = "MT;MALTA";
	$list[120] = "MQ;MARTINIQUE";
	$list[121] = "MR;MAURITANIA";
	$list[122] = "MU;MAURITIUS";
	$list[123] = "YO;MAYOTTE";
	$list[124] = "MX;MEXICO";
	$list[125] = "MI;MIDWAY ISLANDS";
	$list[126] = "MC;MONACO";
	$list[127] = "MN;MONGOLIA";
	$list[128] = "MS;MONTSERRAT";
	$list[129] = "MA;MOROCCO";
	$list[130] = "MZ;MOZAMBIQUE";
	$list[131] = "NA;NAMIBIA";
	$list[132] = "NR;NAURU";
	$list[133] = "NV;NAVASSA ISLAND";
	$list[134] = "NP;NEPAL";
	$list[135] = "AN;NETHERLANDS ANTILLES";
	$list[136] = "NL;NETHERLANDS";
	$list[137] = "NC;NEW CALEDONIA";
	$list[138] = "NZ;NEW ZEALAND";
	$list[139] = "NI;NICARAGUA";
	$list[140] = "NE;NIGER";
	$list[141] = "NG;NIGERIA";
	$list[142] = "NU;NIUE";
	$list[143] = "NF;NORFOLK ISLAND";
	$list[144] = "NO;NORWAY";
	$list[145] = "OM;OMAN";
	$list[146] = "PK;PAKISTAN";
	$list[147] = "PA;PANAMA";
	$list[148] = "PG;PAPUA NEW GUINEA";
	$list[149] = "PI;PARACEL ISLANDS";
	$list[150] = "PY;PARAGUAY";
	$list[151] = "PE;PERU";
	$list[152] = "PH;PHILIPPINES";
	$list[153] = "PN;PITCAIRN ISLANDS";
	$list[154] = "PL;POLAND";
	$list[155] = "PT;PORTUGAL";
	$list[156] = "PR;PUERTO RICO (1)";
	$list[157] = "RQ;PUERTO RICO (2)";
	$list[158] = "QA;QATAR";
	$list[159] = "RE;REUNION";
	$list[160] = "RO;ROMANIA";
	$list[161] = "RW;RWANDA";
	$list[162] = "SM;SAN MARINO";
	$list[163] = "ST;SAO TOME AND PRINCIPE";
	$list[164] = "SA;SAUDI ARABIA";
	$list[165] = "SN;SENEGAL";
	$list[166] = "SC;SEYCHELLES";
	$list[167] = "SL;SIERRA LEONE";
	$list[168] = "SG;SINGAPORE";
	$list[169] = "SB;SOLOMON ISLANDS";
	$list[170] = "SO;SOMALIA";
	$list[171] = "ZA;SOUTH AFRICA";
	$list[172] = "ES;SPAIN";
	$list[173] = "SI;SPRATLY ISLANDS";
	$list[174] = "LK;SRILANKA";
	$list[175] = "VC;ST.  VINCENT AND THE GRENADINES";
	$list[176] = "KN;ST. CHRISTOPHER AND NEVIS";
	$list[177] = "SH;ST. HELENA";
	$list[178] = "LC;ST. LUCIA";
	$list[179] = "PM;ST. PIERRE ANDMIQUELON";
	$list[180] = "SD;SUDAN";
	$list[181] = "SR;SURINAME";
	$list[182] = "SZ;SWAZILAND";
	$list[183] = "SE;SWEDEN";
	$list[184] = "CH;SWITZERLAND";
	$list[185] = "SY;SYRIA";
	$list[186] = "TW;TAIWAN";
	$list[187] = "TZ;TANZANIA, UNITED REPUBLIC OF";
	$list[188] = "TH;THAILAND";
	$list[189] = "TG;TOGO";
	$list[190] = "TK;TOKELAU";
	$list[191] = "TO;TONGA";
	$list[192] = "TT;TRINIDAD AND TOBAGO";
	$list[193] = "PC;TRUST TERR OF PACIFIC ISLANDS";
	$list[194] = "TN;TUNISIA";
	$list[195] = "TR;TURKEY";
	$list[196] = "TC;TURKS AND CAICOS ISLANDS";
	$list[197] = "TV;TUVALU";
	$list[198] = "UG;UGANDA";
	$list[199] = "SU;UNION OF SOVIET SOCIALIST REPS";
	$list[200] = "AE;UNITED ARAB ERMIRATES";
	$list[201] = "GB;UNITED KINGDOM";
	$list[202] = "US;UNITED STATES";
	$list[203] = "HV;UPPER VOLTA";
	$list[204] = "UY;URUGUAY";
	$list[205] = "VU;VANUATU";
	$list[206] = "VA;VATICAN CITY";
	$list[207] = "VE;VENEZUELA";
	$list[208] = "VN;VIETNAM";
	$list[209] = "VI;VIRGIN ISLANDS";
	$list[210] = "WK;WAKE ISLAND";
	$list[211] = "WF;WALLIS AND FUTUNA";
	$list[212] = "EH;WESTERN SAHARA";
	$list[213] = "WS;WESTERN SAMOA";
	$list[214] = "YD;YEMEN (ADEN)";
	$list[215] = "YE;YEMEN (SANAA)";
	$list[216] = "YU;YUGOSLAVIA";
	$list[217] = "ZR;ZAIRE";
	$list[218] = "ZM;ZAMBIA";
	$list[219] = "ZW;ZIMBABWE";


	$select="<SELECT NAME=\"countryCode\">\n";
	foreach $item (@list) {
		my($code, $country) = split /;/, $item;
		$selected = check_country_code($sensor, $code);
		$select .= "<option $selected value=\"$code\">$country</option>\n";
	}

	$select .="</select>\n";
	
	

	return $select;
}
