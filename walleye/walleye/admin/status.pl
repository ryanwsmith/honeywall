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
use File::Find;

use Walleye::Admin;
use Walleye::AdminUtils;

my %hw_vars = Walleye::AdminUtils::hw_get_vars();

#  Validate login
my $session = validate_user();
my $role = $session->param("role");


if($role ne "admin-read-only" && $role ne "admin" ) {
	error("You are not authorized to access this page.","true");
}

my $sess_cookie = cookie(CGISESSID => $session->id);

#	Print header to create cookie
#	This is a hack and will be removed once it is decided
#	where the user will be sent after logging in.
#
#    print header( -TYPE => 'text/html',
#		  -EXPIRES => 'now',
#		  -cookie=>$sess_cookie
#		  );

# Check to see if the Honeywall has been configured
#check_honeywall_init();
my $tab = "sysAdminNav";
my @status = get_status();
my $title = $status[0];
if ($title eq "Documentation") {
   $tab = "docs";
}

display_header_page($session, $tab);
display_status();
display_footer_page();


sub get_status {

	my @status;

	my $action = "";

	if(defined param("act")) {
		$action = param("act");
	}

	
	SWITCH: {
		if($action eq "1") { @status = get_network_interface(); last SWITCH;}
		if($action eq "2") { @status = get_honeywall_conf(); last SWITCH;}
		if($action eq "3") { @status = get_firewall_rules(); last SWITCH;}
		if($action eq "4") { @status = get_running_processes(); last SWITCH;}
		if($action eq "5") { @status = get_listening_ports(); last SWITCH;}
		if($action eq "6") { @status = get_snort_inline_alerts_fast(); last SWITCH;}
		if($action eq "7") { @status = get_snort_inline_alerts_full(); last SWITCH;}
		if($action eq "8") { @status = get_snort_alerts(); last SWITCH;}
		if($action eq "9") { @status = get_system_logs(); last SWITCH;}
		if($action eq "10") { @status = get_inbound_connections(); last SWITCH;}
		if($action eq "11") { @status = get_outbound_connections(); last SWITCH;}
		if($action eq "12") { @status = get_dropped_connections(); last SWITCH;}
		if($action eq "13") { @status = get_traffic_statistics(); last SWITCH;}
		if($action eq "14") { @status = get_argus_flow_summaries(); last SWITCH;}
		if($action eq "15") { @status = get_tracked_connections(); last SWITCH;}
		if($action eq "16") { @status = get_documentation(); last SWITCH;}
		#@status = get_network_interface();
		@status = get_welcome_message();

	}

	return @status;

}

sub display_status {
	my $list;
	my $title;
	my %pcap_files;
	my $file;

	my @status = get_status();
	my $act;

	$title = $status[0];
	$list = $status[1];

	if ($title eq "tcpdstat traffic statistics") {
		%pcap_files = get_pcap_files();
		$act = "13";
		$file = $status[2];		
	}

	if ($title eq "Argus traffic summaries") {
		%pcap_files = get_pcap_files();
		$act = "14";
		$file = $status[2];		
	}

	if ($title eq "Documentation") {
		%pcap_files = get_document_files();
		$act = "16";
		$file = $status[2];
	}


	
	
	my $tt = Template->new( );
	
	my $input = 'templates/status.htm';
	my $vars  = {
		health_table=>  Walleye::Admin::gen_honeywall_health(),
	       	file => $list,
	       	title => $title,
		   	pcap => \%pcap_files,
		   	act => $act,
			fileSelected => $file,		   
	};
	
	$tt->process($input, $vars)
	    || die $tt->error( );
}

sub get_welcome_message {
	#my @list;
	my $title = "Honeywall System Administration";
	my @title_status;

	$title_status[0] = $title;
	#$title_status[1] = \@list;

	return @title_status;

}

sub get_pcap_files {
	my @dir;
	$dir[0]="/var/log/pcap";
	my %files;
	my $key;

	find sub {
			return unless -f;
                        return unless m/^log$/;
			$files{$File::Find::name} = -s;
			}, @dir;

	#if(!defined %files) {
	if(keys(%files) == 0 ) {
		$files{"No Snort log files found"} = "";
	}

	return %files;

}

sub get_document_files {
	my @dir;
	$dir[0]="/hw/docs";
	my %files;
	my $key;

	find sub {
			return unless -f;
			#$files{$File::Find::name} = $_;
			$files{$_} = ""
			}, @dir;

	#if(!defined %files) {
	if(keys(%files) == 0 ) {
		$files{"No documentation found"} = "";
	}

	return %files;

}

sub get_network_interface {

	my @list;
	my $title = "Network Interface";
	my @title_status;

	my $cmd = "sudo /sbin/ifconfig -a 2>&1 |";

	@list = get_command_output($cmd);

	$title_status[0] = $title;
	$title_status[1] = \@list;

	return @title_status;

}

sub get_honeywall_conf {

	my $title = "Honeywall Configuration";
	my @title_status;
	my @list;
	my $file = "/etc/honeywall.conf";
	my $cmd = "sudo cat $file 2>&1 |";

	check_file_status($file);

	@list = get_command_output($cmd);

	$title_status[0] = $title;
	$title_status[1] = \@list;

	return @title_status;

}

sub get_firewall_rules {

	my @list;
	my $title = "Firewall Rules (iptables)";
	my @title_status;
	my $cmd = "sudo /sbin/iptables -L -n -v 2>&1 |";

	@list = get_command_output($cmd);

	$title_status[0] = $title;
	$title_status[1] = \@list;

	return @title_status;
}

sub get_running_processes {

	my @list;
	my $title = "Running Processes";
	my @title_status;
	my $cmd = "sudo ps aux 2>&1 |";

	@list = get_command_output($cmd);
	
	$title_status[0] = $title;
	$title_status[1] = \@list;

	return @title_status;

}

sub get_listening_ports {

	my @list;
	my $title = "Listening Ports";
	my @title_status;
	my $cmd = "sudo netstat -pan -A inet 2>&1 |";

	@list = get_command_output($cmd);
	
	$title_status[0] = $title;
	$title_status[1] = \@list;

	return @title_status;

}

sub get_snort_inline_alerts_fast {

	my @list;
	my $date = formatted_date();
	my $title = "Snort_inline Alerts (fast) for $date";
	my @title_status;

	my $logdir = get_log_dir();
	my $dir = "$logdir/snort_inline";
	my $file = "$dir/$date/snort_inline-fast";

	my $cmd = "sudo cat $file 2>&1 |";

	if (stat($file)) {
		@list = get_command_output($cmd);
	} else {
		$list[0] = "$file does not exists yet.";
		$list[1] = "Probably haven't dropped any packets today yet!";
	}

	# Check to see if file exists but it empty
    if(!defined $list[0]) {
    	$list[0] = "$file is empty.";
		$list[1] = "Probably haven't dropped any packets today yet!";
    }

	$title_status[0] = $title;
	$title_status[1] = \@list;

	return @title_status;

}

sub get_snort_inline_alerts_full {

	my @list;
	my $date = formatted_date();
	my $title = "Snort_inline Alerts (full) for $date";
	my @title_status;

	my $logdir = get_log_dir();
	my $dir = "$logdir/snort_inline";
	my $file = "$dir/$date/snort_inline-full";

	my $cmd = "sudo cat $file 2>&1 |";

	if (stat($file)) {
		@list = get_command_output($cmd);
	} else {
		$list[0] = "$file does not exists yet.";
		$list[1] = "Probably haven't dropped any packets today yet!";
	}

	# Check to see if file exists but it empty
    if(!defined $list[0]) {
    	$list[0] = "$file is empty.";
		$list[1] = "Probably haven't dropped any packets today yet!";
    }


	$title_status[0] = $title;
	$title_status[1] = \@list;

	return @title_status;


}

sub get_snort_alerts {
	my @list;
	my $date = formatted_date();
	my $title = "Snort Alerts for $date";
	my @title_status;

	my $logdir = get_log_dir();
	my $dir = "$logdir/snort";
	#my $file = "$dir/$date/snort_full";
	my $file = "/var/lib/hflow/snort/snort_full";

	my $cmd = "sudo cat $file 2>&1 |";

	if (stat($file)) {
		@list = get_command_output($cmd);
	} else {
		$list[0] = "$file does not exists yet.";
		$list[1] = "Probably haven't dropped any packets today yet!";
	}

	# Check to see if file exists but it empty
    if(!defined $list[0]) {
    	$list[0] = "$file is empty.";
		$list[1] = "Probably haven't dropped any packets today yet!";
    }

	$title_status[0] = $title;
	$title_status[1] = \@list;

	return @title_status;

}

sub get_system_logs {
	my @list;
	my $title = "System Logs";
	my @title_status;
	my $cmd = "sudo cat /var/log/messages 2>&1 |";

	@list = get_command_output($cmd);

	$title_status[0] = $title;
	$title_status[1] = \@list;

	return @title_status;
}

sub get_inbound_connections {
	my @list;
	my $title = "Inbound Connections";
	my @title_status;
	my $cmd = "sudo cat /var/log/iptables | grep INBOUND 2>&1 |";

	check_file_status("/var/log/iptables");

	@list = get_command_output($cmd);

	# Check to see if file exists but it empty
	if(!defined $list[0]) {
		$list[0] = "No inbound connections found.";
	}

	$title_status[0] = $title;
	$title_status[1] = \@list;

	return @title_status;
}

sub get_outbound_connections {
	my @list;
	my $title = "Outbound Connections";
	my @title_status;
	my $cmd = "sudo cat /var/log/iptables | grep OUTBOUND|";

	check_file_status("/var/log/iptables");
	@list = get_command_output($cmd);

	# Check to see if file exists but it empty
	if(!defined $list[0]) {
		$list[0] = "No outbound connections found.";
	}
	
	$title_status[0] = $title;
	$title_status[1] = \@list;

	return @title_status;
}

sub get_dropped_connections {
	my @list;
	my $title = "Dropped Connections";
	my @title_status;
	my $cmd = "sudo cat /var/log/iptables | grep Drop|";
	
	check_file_status("/var/log/iptables");

	@list = get_command_output($cmd);

	# Check to see if file exists but it empty
	if(!defined $list[0]) {
		$list[0] = "No dropped connections found.";
	}


	$title_status[0] = $title;
	$title_status[1] = \@list;

	return @title_status;
}

sub get_documentation {
	my @list;
	my $title = "Documentation";
	my @title_status;
	my $dir = "/hw/docs";
	my $file_name = param("file");
	my $file;
	
	if (defined $file_name && param("file") ne "No documents found") {
		$file = $dir . "/" . $file_name;
	}
	
	if(defined $file || $file ne "") {
		my $cmd = "sudo cat $file 2>&1 |";
		@list = get_command_output($cmd);	
	}

	$title_status[0] = $title;
	$title_status[1] = \@list;
	$title_status[2] = $file_name;

	return @title_status;


}

sub get_traffic_statistics {
	my @list;
	my $title = "tcpdstat traffic statistics";
	my @title_status;
	my $file;
	
	if (param("file") ne "No Snort log files found") {
		$file = param("file");
	}
	
	if(defined $file || $file ne "") {
		my $cmd = "sudo /usr/bin/tcpdstat $file 2>&1 |";
		@list = get_command_output($cmd);	
	}

	$title_status[0] = $title;
	$title_status[1] = \@list;
	$title_status[2] = $file;

	return @title_status;

}

sub get_argus_flow_summaries {
	my @list;
	my $title = "Argus traffic summaries";
	my @title_status;
	my $file;
	
	if (param("file") ne "No Snort log files found") {
		$file = param("file");
	}

	if(defined $file || $file ne "") {
		my $cmd = "sudo /usr/sbin/argus -n /var/run/argus2.pid -w - -r $file | rasort -n  2>&1 |";
		@list = get_command_output($cmd);	
	}

	$title_status[0] = $title;
	$title_status[1] = \@list;
	$title_status[2] = $file;

	return @title_status;


}

sub get_tracked_connections {
	my @list;
	my $title = "Connections Currently Tracked by iptables";
	my @title_status;

	my $cmd = "sudo cat /proc/net/ip_conntrack 2>&1 |";

	check_file_status("/proc/net/ip_conntrack");
	
	@list = get_command_output($cmd);

	# Check to see if file exists but is empty
	if(!defined $list[0]) {
		$list[0] = "No tracked connections found.";
	}


	$title_status[0] = $title;
	$title_status[1] = \@list;

	return @title_status;

}

sub get_command_output {
	my($cmd) = (@_);
	
	my @list;
	my $count=0;

	my $pid = open(README, $cmd) || error("Could not run $cmd $!");

	while(<README>) {
		chomp $_;
		$list[$count] = $_;
		++$count;
	}
	close(README);

	return @list;


}

