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

#  Validate login
my $session = validate_user();
my $role = $session->param("role");
 
my %hw_vars = hw_get_vars();

if($role ne "admin") {
	error("You are not authorized to access this page.", "true");
}


display_header_page($session);
check_action();
display_page();
display_footer_page();

# Check if we are adding, editing or updating a rule.
sub check_action {
	
	my $action = "";

	if(defined param("addRule")) {
		$action = "add";
	}

	if(defined param("addAsNew")) {
		$action = "addAsNew";
	}

	if(defined param("update")) {
		$action = "update";
	}

	
	SWITCH: {
		if($action eq "add") { add_rule(); last SWITCH;}
		if($action eq "update") { update_rule(); last SWITCH;}
		if($action eq "addAsNew") { add_as_new_rule(); last SWITCH;}
	}

}

sub add_as_new_rule {
	my $category;
	my $sid;
	my $msg;
	my $rule;
	my $notes;
	my $enabled = 0;
	my $query;
	my %sid_list = get_sid_list();
	my $max_sid = get_last_sid();
	my $match_sid_msg;
	my $title = "Edit Snort Rule";
	my $message = "The Snort rule has been added as a new rule.";

	# Get category
	if(defined param("category")) {
		$category = param("category");
	}

	if(defined param("enableNewRule")) {
		$enabled = 1;
	}

	if(defined param("notes")) {
		$notes = param("notes");
	}


	if(defined param("newCategory") && param("newCategory") ne "") {
		$category = param("newCategory");
	}

	if(defined param("rule")) {
		$rule = param("rule");
	}

	#parse rule
	# Remove any new lines
	$rule =~ s/\\\s*\n$//;	
	
	if ($rule =~ /\bmsg\s*:\s*"(.+?)"\s*;/i) {
    	$msg = $1;
	} 

    if ($rule =~ /\bsid\s*:\s*(\d+)\s*;/i) {
    	$sid = $1;
	}

	# Check for matching sid number
	if($sid_list{$sid} == $sid) {
		if($max_sid < 10000) { $max_sid = 10000; }
		$sid = ++$max_sid;
		$match_sid_msg = "The sid number for the rule matches an existing rules sid.  The sid number for this rule has been changed to $sid";
		$rule = replace_sid($sid, $rule);
	}

	ConnectToDatabase();
	$query = "insert into snort_rules (sid,category,rule,msg,notes,enabled) values($sid,'$category','$rule','$msg','$notes',$enabled)";
	SendSQL($query);

	create_snort_rules_files();
	create_snort_conf();
	restart_snort();

	display_admin_msg($title, $message);

}

sub update_rule {
	my $category;
	my $sid;
	my $msg;
	my $rule;
	my $notes;
	my $enabled = 0;
	my $query;
	my $title = "Edit Snort Rule";
	my $message = "The Snort rule has been updated.";


	# Get category
	if(defined param("category")) {
		$category = param("category");
	}

	if(defined param("enableNewRule")) {
		$enabled = 1;
	}

	if(defined param("notes")) {
		$notes = param("notes");
	}


	if(defined param("newCategory") && param("newCategory") ne "") {
		$category = param("newCategory");
	}

	if(defined param("rule")) {
		$rule = param("rule");
	}
   
	if(defined param("sid")) {
		$sid = param("sid");
	}


	#parse rule
	# Remove any new lines
	$rule =~ s/\\\s*\n$//;	
	
	if ($rule =~ /\bmsg\s*:\s*"(.+?)"\s*;/i) {
    	$msg = $1;
	} 

	ConnectToDatabase();
	$query = "update snort_rules set category='$category', rule='$rule', msg='$msg', enabled=$enabled, notes='$notes' where sid=$sid";
	SendSQL($query);

	create_snort_rules_files();
	create_snort_conf();
	restart_snort();

	display_admin_msg($title, $message);
}

sub add_rule {
	my $category;
	my $sid;
	my $msg;
	my $rule;
	my $notes;
	my $enabled = 0;
	my $query;
	my %sid_list = get_sid_list();
	my $max_sid = get_last_sid();
	my $match_sid_msg;
	my $title = "Add Snort Rule";
	my $message = "The Snort rule has been added.";


	# Get category
	if(defined param("category")) {
		$category = param("category");
	}

	if(defined param("enableNewRule")) {
		$enabled = 1;
	}


	if(defined param("notes")) {
		$notes = param("notes");
	}


	if(defined param("newCategory") && param("newCategory") ne "") {
		$category = param("newCategory");
	}

	if(defined param("rule")) {
		$rule = param("rule");
	}

	#parse rule
	# Remove any new lines
	$rule =~ s/\\\s*\n$//;	
	
	if ($rule =~ /\bmsg\s*:\s*"(.+?)"\s*;/i) {
    	$msg = $1;
	} 

    if ($rule =~ /\bsid\s*:\s*(\d+)\s*;/i) {
    	$sid = $1;
	}

	# Check for matching sid number
	if($sid_list{$sid} == $sid) {
		if($max_sid < 10000) { $max_sid = 10000; }
		$sid = ++$max_sid;
		$match_sid_msg = "The sid number for the rule matches an existing rules sid.  The sid number for this rule has been changed to $sid";
		$rule = replace_sid($sid, $rule);
	}
	
	ConnectToDatabase();
	$query = "insert into snort_rules (sid,category,rule,msg,notes,enabled) values($sid,'$category','$rule','$msg','$notes',$enabled)";
	SendSQL($query);

	create_snort_rules_files();
	create_snort_conf();
	restart_snort();

	display_admin_msg($title, $message);
}

sub display_page {

	my $input;
	my @categories;
	my @row;
	my $category;
	my $sid;
	my $rule;
	my $notes;
	my $lastUpdated;
	my $enabled;
	my $disp;
	my $action = "Add";

	if(defined param("sid")) {
		$action = "Edit";
    	@row = get_rule(param("sid"));
        $sid = $row[0];
        $category = $row[1];
        $rule = $row[2];
        $notes = $row[3];
		$enabled = $row[5];
        $lastUpdated = $row[7];
    }

	# Refresh honeywall variables
	my %hw_vars = hw_get_vars();

	@categories = get_categories();

	$input = "templates/addEditSnortRules.htm";
	
	my $tt = Template->new( );
	
	my $vars  = {
		vars => \%hw_vars,
		categories => \@categories,
		sid => $sid,
		category => $category,
		rule => $rule,
		notes => $notes,
		enabled => $enabled,
		action => $action,
	};
	
	$tt->process($input, $vars)
	    || die $tt->error( );


}

# Returns a rule.
sub get_rule {
	my($sid) = @_;
	
    my @row;

    my $query = "select * from snort_rules where sid=$sid";
    ConnectToDatabase();
	SendSQL($query);

    @row = FetchSQLData();

	return @row;
}

