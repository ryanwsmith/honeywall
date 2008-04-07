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

# Check to see if the snort rules that were installed
# are in the database.
init_snort_inline_rules();

# Get rule information
#my $max_sid = get_max_inline_sid();
#my %sid_list = get_inline_sid_list();

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
		if($action eq "uploadSnortInlineRules") { upload_snort_inline_rules(); last SWITCH;}
	}

}

sub upload_snort_inline_rules {
	my $file = param("uploadFile");
	my $dir = "/tmp";
	my $tmp_dir;
	my $tmp_file;
	my %rule_files;
	my $key;
	my $enable = "no";
	my $cmd;
	my $overwrite_rule_type = "";

	my $status;
	my $title = "Upload Snort Inline Rules File";
	my $msg = "The Snort_Inline rules file has been uploaded.";

	 if(defined param("enableAll")) {
        if( param("enableAll") eq "enable") {$enable = "yes"; }
    }
	
	if(defined param("overwriteRuleType")) {
		if(param("overwriteRuleType") eq "no") { $overwrite_rule_type = "no"; }
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
		process_inline_rule_file($key, $rule_files{$key}, $enable, $overwrite_rule_type);
	}

	$cmd = "/bin/rm -rf $tmp_dir";
	$status = system("sudo $cmd");
	error("Could not run command: $cmd $?") unless $status == 0;

	# Need to copy enabled rules from db to rules directory and restart snort.
	create_snort_inline_rules_files();	
	create_snort_inline_conf();
	restart_snort_inline();

	display_admin_msg($title, $msg);

		
}	

sub display_page {

	my $input;
	my @categories;
	my $category;

	if(defined param("category")) {
        $category = param("category");
    }

	# Refresh honeywall variables
	my %hw_vars = hw_get_vars();
	
	SWITCH: {
		if(param("disp") eq "uploadSnortRules") { $input = "templates/uploadSnortInlineRules.htm"; last SWITCH;}

		$input = "templates/status.htm";
	}

	my $tt = Template->new( );
	
	my $vars  = {
		vars => \%hw_vars,
		categories => \@categories,
		category => $category,
	};
	
	$tt->process($input, $vars)
	    || die $tt->error( );


}



