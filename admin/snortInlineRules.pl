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
use POSIX qw(ceil floor);

use Walleye::Admin;
use Walleye::AdminUtils;
use Walleye::SnortUtils;
use Walleye::Pager;
use Walleye::Rule;


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
		if($action eq "enable") { enable_snort_rules(); last SWITCH;}
		if($action eq "remove") { remove_snort_rules(); last SWITCH;}
		if($action eq "drop" || $action eq "reject" || $action eq "replace") { modify_rule($action); last SWITCH;}
		 
	}

}

sub modify_rule {
	my ($action) = @_;
	my $where = "";
	my $rule_num = 0;
    my $count;
    my $sid;
    my $ruleChecked;
    my $query;
	my $first_sid = 1;
	my %rules;
	my @row;
	my $type = $action;
	my $replaced_rule;
	my $parser = Walleye::Rule->new();
	my $rule;
	my $remove_replace = "";

	if($action eq "replace") {
		$type = "alert";
	}

    if(defined param("ruleNum")) {
        $rule_num = param("ruleNum");
    }

    ConnectToDatabase();
    for($count = 1; $count <= $rule_num; $count++) {
        $ruleChecked = "ruleCheck$count";
        if(defined param($ruleChecked)) {
            $sid = param($ruleChecked);
			if($first_sid) {
				$where = "where ";
				$first_sid = 0;
			} else {
				$where .= " or ";
			}
			$where .= "sid=$sid";
        } 
    }

	if($where ne "") {
		$query = "select sid, rule from snort_inline_rules $where";
		SendSQL($query);

		while(MoreSQLData()) {
		@row = FetchSQLData();
		$rules{$row[0]} = $row[1];
		}

	}

	foreach my $key (keys %rules) {
		$rule = $parser->parse_rule($rules{$key});
		$parser->make_generic($type, $rule);
		if($action eq "replace") {
			$parser->make_replace($action, $rule);
		} else {
			$remove_replace = "true";
			#$parser->make_generic($type, $rule);
		}

		$replaced_rule = $parser->build_rule($rule, $remove_replace);

		$query = "update snort_inline_rules set type='$type', rule='$replaced_rule' where sid=$key";
		SendSQL($query);
	}

	# Need to copy enabled rules from db to rules directory and restart snort.
	create_snort_inline_rules_files();	
	create_snort_inline_conf();
	restart_snort_inline();


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

		$query = "update snort_inline_rules set enabled=$enable, noupdate=$no_overwrite where sid=$sid";


		#if(defined param($ruleChecked)) {
		#	$sid = param($ruleChecked);
		#	$query = "update snort_inline_rules set enabled=1 where sid=$sid";
		#} else {
		#	$sid = param($sidParam);
		#	$query = "update snort_inline_rules set enabled=0 where sid=$sid";
		#}
		SendSQL($query);
	}

	# Need to copy enabled rules from db to rules directory and restart snort.
	create_snort_inline_rules_files();	
	create_snort_inline_conf();
	restart_snort_inline();

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
            $query = "delete from snort_inline_rules where sid=$sid";
			SendSQL($query);
        } 
    }

	# Need to copy enabled rules from db to rules directory and restart snort.
	create_snort_inline_rules_files();	
	create_snort_inline_conf();
	restart_snort_inline();

}


sub display_page {

	my $input;
	my @categories = get_inline_categories();
	my $rules_list;
	my %pager_vars;

	my $search = "no search";
	my $category;
	my $search_criteria = "";
	my $disp_rec;

	if(defined param("category")) {
        $category = param("category");
    }

	if(defined param("searchCriteria")) {
        $search_criteria = param("searchCriteria");
    }

    if(defined param("submitSearch")) {
    	$search = param("submitSearch");
    }

	if(defined param("displayResults")) {
		$disp_rec = param("displayResults");
		$pager->set_disp_rec($disp_rec);
	} else {
		$pager->set_disp_rec(10);  # default
	}

	# Refresh honeywall variables
	my %hw_vars = hw_get_vars();
	
	SWITCH: {
		if(defined param("prev") || defined param("next")) {
			$input = "templates/viewSnortInlineRules.htm";
			$rules_list = get_new_page();
			last SWITCH;
		}
		if(param("disp") eq "viewSnortInlineRules") { 
			$input = "templates/viewSnortInlineRules.htm";
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
	my $query = "select * from snort_inline_rules";

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
			$query = "select * from snort_inline_rules";
			$query_params = " $where $criteria $and $cat_search order by category, type, sid";

		} else {
			$query = "select * from snort_inline_rules";
			$query_params = " order by category, type, sid";
		}

	$pager->set_query_params($query_params);	
	$pager->set_query($query);

	$rules_list = $pager->get_results();

#        ConnectToDatabase();
#		SendSQL($query);

#		while(MoreSQLData()) {
#               @row = FetchSQLData();
#				#$row[2] = add_reference_links($row[2]); 
#                push @list, [@row];
#        }

#        return \@list;
	return $rules_list;
}

