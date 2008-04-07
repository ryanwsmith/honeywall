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
use File::Basename;
use File::Copy;
use File::Path;
use File::Spec;
use Getopt::Long;
use File::Temp qw(tempdir);
use File::Find;
use IO::File;

use Walleye::Admin;
use Walleye::AdminUtils;
use Walleye::SnortUtils;
use Walleye::Pager;


#  Validate login
my $session = validate_user();
my $role = $session->param("role");
 
my %hw_vars = hw_get_vars();

if($role ne "admin") {
	error("You are not authorized to access this page.", "true");
}

# Get reference configuration
my %config = parse_reference_config();

# Check to see if the snort rules that were installed
# are in the database.
my $max_sid = get_last_sid();
init_snort_rules();

# Get rule information
my %sids = get_sid_list();
my %no_overwrite = get_snort_no_overwrite_list();

# Create a new pager
my $pager = Walleye::Pager->new();

display_header_page($session);
check_action();
display_page();
display_footer_page();


sub check_action {
	
	my $action = "";

        if(defined param("act")) {
                $action = param("act");
        }

		if(defined param("submitAction")) {
                $action = param("processRules");
        }

	SWITCH: {
		if($action eq "uploadSnortRules") { upload_snort_rules(); last SWITCH;}
		if($action eq "enable") { enable_snort_rules(); last SWITCH;}
		if($action eq "remove") { remove_snort_rules(); last SWITCH;}
	}

}

sub enable_snort_rules {
	my $rule_num = 0;
	my $count;
	my $sid;
	my $ruleChecked;
	my $sidParam;
	my $query;
	my $enable;
	my $no_overwrite;
	my $overwriteChecked;

	if(defined param("ruleNum")) {
		$rule_num = param("ruleNum");
	}

	ConnectToDatabase();
	for($count = 1; $count <= $rule_num; $count++) {
		$ruleChecked = "ruleCheck$count";
		$sidParam = "sidCheck$count";
		$overwriteChecked = "overwrite$count";
		
		if(defined param($ruleChecked)) {
			$sid = param($ruleChecked);
			$enable = 1;
		} else {
			$enable = 0;
		}

		if(defined param($overwriteChecked)) {
			$sid = param($overwriteChecked);
			$no_overwrite = 1;
		} else {
			$no_overwrite = 0;
		}

		if(!defined param($overwriteChecked) && !defined param($ruleChecked)) {
			$sid = param($sidParam);
			$no_overwrite = 0;
			$enable = 0;
		}

		$query = "update snort_rules set enabled=$enable, noupdate=$no_overwrite where sid=$sid";

		SendSQL($query);
	}
	create_snort_rules_files();
	create_snort_conf();
	restart_snort();
}

sub remove_snort_rules {
    my $rule_num = 0;
    my $count;
    my $sid;
    my $ruleChecked;
    my $query;

    if(defined param("ruleNum")) {
        $rule_num = param("ruleNum");
    }

    ConnectToDatabase();
    for($count = 1; $count <= $rule_num; $count++) {
        $ruleChecked = "ruleCheck$count";
        if(defined param($ruleChecked)) {
            $sid = param($ruleChecked);
            $query = "delete from snort_rules where sid=$sid";
			SendSQL($query);
        } 
    }
    create_snort_rules_files();
	create_snort_conf();
	restart_snort();

}

sub upload_snort_rules {
	my $file = param("uploadFile");
	my $dir = "/tmp";
	my $tmp_dir;
	my $tmp_file;
	my %rule_files;
	my $key;
	my $enable = "no";
	my $cmd;

	my $status;
	my $title = "Upload Snort Rules File";
	my $msg = "The Snort rules file has been uploaded.";

	 if(defined param("enableAll")) {
        if( param("enableAll") eq "enable") {$enable = "yes"; }
    }


	$tmp_dir = create_temp_dir($dir);
	# Get file name 
	my ($volume,$directories,$filename) = File::Spec->splitpath( $file );
	$tmp_file = "$tmp_dir/$filename";


	if($file) {
		open(UPLOAD, ">$tmp_file") or error("Could not open file $tmp_file $!");
		my ($data, $length, $chunk);
		while($chunk = read($file, $data, 1024)) {
			print UPLOAD $data;
			$length += $chunk;
			if($length > 4766903) {
				error("File length is too long");
			}
		}
		close(UPLOAD);
	}

	# Unpack the rules file
	unpack_rules_file($tmp_dir, $filename);

	# Find all of the rule files
	%rule_files = find_rules_files($tmp_dir);

	foreach $key (keys %rule_files) {
		process_rule_file($key, $rule_files{$key}, $enable);
	}

	$cmd = "/bin/rm -rf $tmp_dir";
	$status = system("sudo $cmd");
	error("Could not run command: $cmd $?") unless $status == 0;

	# Need to copy enabled rules from db to rules directory and restart snort.
	create_snort_rules_files();	
	create_snort_conf();
	restart_snort();

	display_admin_msg($title, $msg);

		
}	

sub process_rule_file {
	my ($filename, $category, $enable) = @_;
	my $line;
	my $msg;
	my $sid;
	my $multi;
	my $rule;
	my $conn;
	my $enable_rule = 0;
	# Need to have string for updates
	my $enable_string = ""; 
	my $overwrite = "no";
	
	# Sid numbers > 10000 will be given to any new rule that has a new sid number assigned.
	if($max_sid < 10000) { $max_sid = 10000; }

	if($enable eq "yes") {
		$enable_rule = 1;
		$enable_string = ", enabled=1";
	}
	
	ConnectToDatabase();

	my $query = "insert into snort_rules (sid,category,rule,msg,enabled) values(?,?,?,?,?)";
    my $update_query = "update snort_rules set msg=?, category=?, rule=? $enable_string where sid=?";

    my $conn_update = prepare_query($update_query);
	my $conn = prepare_query($query);

	open(FILE,"<$filename") or die "Could not open file $filename";

	LINE:while(defined($line = <FILE>)) {
		next if($line =~ s/#.*//);  # skip commented lines
		next unless($line =~ /[A-Z|a-z|0-9]+/);  # skip empty or blank lines
		# Multi-line start/continuation?
        if ($line =~ /\\\s*\n$/) {
            $line =~ s/\\\s*\n$//;
            $multi .= $line;
            next LINE;
        }

      	# Last line of multi-line directive?
        if (defined($multi)) {
            $multi .= $line;
            $line = $multi;
            undef($multi);
        }

		$rule = $line;

		if ($line =~ /\bmsg\s*:\s*"(.+?)"\s*;/i) {
            $msg = $1;
        } 
        if ($line =~ /\bsid\s*:\s*(\d+)\s*;/i) {
            $sid = $1;
            # Make sure the max sid number is not exceeded
            if($sid >= $max_sid) {
                $max_sid = $sid + 1;
            }
        } else {
			# We need to add a sid since none was included in the rule
			$sid = ++$max_sid;
			$rule = replace_sid($sid, $rule);
		}

		} elsif (!defined $sids{$sid} ) {
			$conn->execute($sid,$category,$rule,$msg,$enable_rule);
		}

	}

	close(FILE);
	Disconnect_from_db();

}

sub display_page {

	my $input;
	my @categories = get_categories();
	my $rules_list;
	my %pager_vars;

	my $search = "no search";
	my $category;
	my $search_criteria = "";

	if(defined param("category")) {
        $category = param("category");
    }

	if(defined param("searchCriteria")) {
        $search_criteria = param("searchCriteria");
    }

	if(defined param("displayResults")) {
		$pager->set_disp_rec(param("displayResults"));
	} else {
		$pager->set_disp_rec(10);  # default
	}


	# Refresh honeywall variables
	my %hw_vars = hw_get_vars();
	
	SWITCH: {
		if(defined param("prev") || defined param("next")) {
			$input = "templates/viewSnortRules.htm";
			$rules_list = get_new_page();
			last SWITCH;
		}

		if(param("disp") eq "uploadSnortRules") { 
			$input = "templates/uploadSnortRules.htm"; 
			last SWITCH;
		}
		if(param("disp") eq "viewSnortRules") { 
			$input = "templates/viewSnortRules.htm";
			$rules_list = get_rules_list($category,$search_criteria);
			last SWITCH;
		}

		$input = "templates/status.htm";
	}

	%pager_vars = $pager->get_pager_vars();

	my $tt = Template->new( );
	
	my $vars  = {
		vars => \%hw_vars,
		pager => \%pager_vars,
		categories => \@categories,
		category => $category,
		rules => $rules_list,
		searchCriteria => $search_criteria,
		evenOdd => sub {
						my ($loopNum) = @_;
						my $num = $loopNum%2;
						if($num == 0) {
							return "even";
						}
						return "odd";
						}
	};
	
	$tt->process($input, $vars)
	    || die $tt->error( );


}

sub get_new_page {
	my $action;
	my $result_list;
	my $query = "select * from snort_rules";

	$pager->set_query($query);
	$pager->set_query_params(param("queryParams"));

	if(param("displayResults") != param("dispRec")) {
		$pager->init_vars();
		$pager->set_query($query);
		$pager->set_query_params(param("queryParams"));
		$pager->set_disp_rec(param("displayResults"));
	} else {
		$pager->set_disp_rec(param("dispRec"));
		$pager->set_curr_page(param("currPage"));
		$pager->set_prev_page(param("prevPage"));
		$pager->set_next_page(param("nextPage"));
	}

	if(defined param("prev")) {
		$pager->set_page_direction("prev");
	} elsif(defined param("next")) {
		$pager->set_page_direction("next");
	}

	$result_list = $pager->get_results();

	return $result_list;
}

# Check to see if this is the first time viewing snort rules.
# If so, we need to add the rules in /etc/snort/rules to the
# database.
sub init_snort_rules {
	my %rule_files;
	my $dir = "/etc/snort/rules";
	my $key;
	my @row;
	my $query = "select count(sid) from snort_rules";
	my $enable = "yes";

	# THIS SHOULD BE REMOVED BEFORE THE NEXT ISO RELEASE
	# Checks to see if snort table needs to be updated
	check_for_updated_snort_table();

	ConnectToDatabase();
    SendSQL($query);
	@row = FetchSQLData();

	if($row[0] == 0) {
		%rule_files = find_rules_files($dir);

    	foreach $key (keys %rule_files) {
        	process_rule_file($key, $rule_files{$key}, $enable);
    	}
	}
}

# THIS SHOULD BE REMOVED BEFORE THE NEXT ISO RELEASE
# Checks to see if snort table needs to be updated
sub check_for_updated_snort_table {
	my @row;
	my $query = "select * from snort_rules limit 1";
	my $drop_query = "drop table snort_rules";
	my $create_query = "create table snort_rules (";
	$create_query .= "sid int not null,";
	$create_query .= "category varchar(50),";
	$create_query .= "rule text,";
	$create_query .= "notes text,";
	$create_query .= "msg text,";
	$create_query .= "enabled tinyint UNSIGNED NOT NULL DEFAULT 0,";
	$create_query .= "noupdate tinyint unsigned not null default 0,";
	$create_query .= "lastupdate timestamp default 'current_timestamp',";
	$create_query .= "primary key(sid)";
	$create_query .= ")";

	ConnectAdminToDatabase();
	SendSQL($query);

	@row = FetchSQLData();

	my $size = scalar(@row);

	if ($size < 8) {
		SendSQL($drop_query);
		SendSQL($create_query);
	}

}



# Returns a reference to a 2d array of rules.
sub get_rules_list {
		my($category, $search_criteria) = @_;
        my @row;
        my @list;
		my $cat = "";
		my $cat_search = "";
		my $search = "";
		my $query;
		my $criteria = "";
		my $and = "";
		my $where = "";
		my $rules_list;
		my $query_params = "";

		if($category ne "All Categories") {
        	$cat = SqlQuote($category);
        	$cat_search = "category=$cat";
			$where = "where";
		}

		if(defined param("submitSearch")) {
        	$search = param("submitSearch");
		}

		if($search_criteria ne "") {
			$criteria = "rule like '%$search_criteria%'";
			$where = "where";
			
			#Check if a category has been selected, if so the we need an "and" in the query
			if($category ne "All Categories") {
				$and = "and";
			}
		}

		if($search eq "Search" || defined $category) {
        	$query = "select * from snort_rules";
			$query_params = " $where $criteria $and $cat_search order by category, sid";

		} else {
			$query = "select * from snort_rules";
			$query_params = " order by category, sid";
		}

	$pager->set_query_params($query_params);	
	$pager->set_query($query);

	$rules_list = $pager->get_results();
	
	return $rules_list;
}

sub add_reference_links {
	my($rule) = @_;
	my $key;
	my $reference;
	my $param;
	my $http = "<a href=\"";

	foreach $key (keys %config) {
		if ($rule =~ /\breference\s*:\s*($key)\s*,([a-zA-Z_0-9|-]*);(.+)/i) {
            $reference = $1;
			$param = $2;
        } 

		
		if ($rule =~ s/\breference\s*:\s*$key\s*,([a-zA-Z_0-9|-]*);/$http$config{$key}$param\">reference:$key,$param<\/a>/) {
        } 

	}

	return $rule;

}


# Parse the reference.config file.  The references in this file will replace the 
# references in the rules.
sub parse_reference_config {
	my $line;
	my $reference;
	my $url;
	my %config;
	my $filename = "/etc/snort/reference.config";
	
	open(FILE,"<$filename") or die "Could not open file $filename";

	while(defined($line = <FILE>)) {
		next if($line =~ s/#.*//);  # skip commented lines
		next unless($line =~ /[A-Z|a-z|0-9]+/);  # skip empty or blank lines

		if ($line =~ /\breference\s*:\s*(\w+)\s*(.+)/i) {
            $reference = $1;
			$url = $2;
			$config{$reference} = $url;
        } 

	}

	close(FILE);

	return %config;
}

