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

#use DBI;
#use DBD::mysql;
#use CGI::Carp qw(fatalsToBrowser);
#use CGI qw(:standard fatalsToBrowser);

use CGI qw/:standard/;
use CGI::Carp 'fatalsToBrowser';

use Walleye::AdminUtils;

#  Validate login
my $session = validate_user();
my $role = $session->param("role");

my $PASSWORD_AGED = 1;

if($role ne "admin") {
	error("You are not authorized to access this page.", "true");
}

#check_parameters();

display_header_page($session);
check_parameters();
display_user_list();
display_footer_page();


sub check_parameters {

	my $act = "";
	my $userId = "";

	if(defined param("act")) {
		$act = param("act");
	}
	
	if(defined param("userid")) {
		$userId = param("userid");
	}

    if ($act eq "saveUser") {
		save_user();
    }

    if ($act eq "removeUser") {
		remove_user($userId);
    }
}

sub remove_user {
    my($id) = (@_);
    my $query;
    $query = "delete from user where userid=" . $id;

    ConnectToDatabase();
    SendSQL($query);

	# Remove password history
	$query = "delete from passwords where userid=" . SqlQuote($id);
	SendSQL($query);


}

sub save_user {

    my $first = SqlQuote(param("firstName"));
    my $last = SqlQuote(param("lastName"));
    my $userId = param("loginId");
    my $pass = param("password");
    my $role = SqlQuote(param("role"));
	
    my $query;
    my $id = param("userid");
	my $new_user = "";

    if($id eq "" || !defined $id) {
        $query = "insert into user (firstname, lastname, login_name, password, role) "
			     . "values($first, $last, ". SqlQuote($userId) . ", " . SqlQuote($pass) . ", $role)";
        
        # Check if user already exists
    	if(duplicate_user(param("loginId"))) {
    		display_error_page("The user " . param("loginId") . " already exists.");
    		exit;
    	}

		# New user - add password to history
		$new_user = "true";
    	
    } else {
		$query = "update user set firstname=" . $first . ", lastname=" . $last . ", login_name=" 
				. SqlQuote($userId) . ", password=" . SqlQuote($pass) . ", role=" . $role . " where userid=" . $id;

		# Has password changed?
		if (check_password_changed($id, $pass)) {
            # Has password been changed in the past 24 hours
            if (!check_password_aged($id, $PASSWORD_AGED)) {
				display_error_page("A password can only be chaged once every $PASSWORD_AGED day(s).");
				exit;
			}

			# Is it equal to any of the previous 10:
			if (check_password_history($id, $pass)) {
				display_error_page("The password entered is equals one of your previous passwords.");
	    		exit;
			} else {
				# Update password history
				ConnectToDatabase();
				SendSQL("insert into passwords (userid, password) values($id, " . SqlQuote($pass) . ")");
			}
		}
	}
    
	ConnectToDatabase();
    SendSQL($query);

	if($new_user) {
		# Get the user id for the new user
		my @user_data = get_user_info($userId);
		#ConnectToDatabase();
		SendSQL("insert into passwords (userid, password) values(" . $user_data[0] . ", " . SqlQuote($pass) . ")");
	}
    	


}

# Checks if user already exists
sub duplicate_user {
	my($login) = (@_);
	
	my $query = "select login_name from user where login_name=" . SqlQuote($login);
	
	ConnectToDatabase();
	SendSQL($query);
	
	my $login_name = FetchOneColumn();
	
	if($login_name eq "" || !defined $login_name) {
		return 0;
	}
	
	return 1;
}

# Checks to see if query will be sorted
sub get_query {
	my $order_by = "";
	my $sort_order = "";
	my $query;

	if (defined param("orderBy")) {
		$order_by = param("orderBy");
	}
	
	if($order_by eq "lastname" || $order_by eq "role") {
		$order_by = "order by " . param("orderBy");
	} else {
		$order_by = "";
	}
	
	if(defined param("sort")) {
		$sort_order = param("sort");	
	}
	
	$query = "select * from user " . $order_by . " " . $sort_order;
	
	return $query;
}

# Returns a reference to a 2d array of users.
sub get_user_list {
	
	my @row;
	my @list;
	
	my $query = get_query();
	ConnectToDatabase();
    SendSQL($query);
    
    while(MoreSQLData()) {
		@row = FetchSQLData();
		push @list, [@row];
	}
	
	return \@list;
}

sub check_sort_ascDesc {
	
	if(param("orderBy") eq "lastname") {
		if (param("sort") eq "asc") {
			return "desc";
		} else {
			return "asc";
		}
	}
	
	if(param("orderBy") eq "role") {
		if( param("sort") eq "asc") {
			return "desc";
		} else {
			return "asc";
		}
	}
	
	return "asc";
	
}

sub display_user_list {

	my $users = get_user_list();
    my $user_sort = "asc";
    my $role_sort = "asc";
	my $order_by = "";
	my $sort = "";

	if(defined param("orderBy")) {
		$order_by = param("orderBy");
	}
    
	if(defined param("sort")) {
		$sort = param("sort");
	}

    if($order_by eq "role") {
		if( $sort eq "asc") {
			$role_sort = "desc";
			$user_sort = "asc";
		} else {
			$role_sort = "asc";
			$user_sort = "desc";
		}
	} elsif($order_by eq "lastname") {
		if( $sort eq "asc") {
			$role_sort = "asc";
			$user_sort = "desc";
		} else {
			$role_sort = "desc";
			$user_sort = "asc";
		}
	} 
    

    #$| = 1;
	#print "Content-type: text/html\n\n";
	
	my $tt    = Template->new( );
	
	my $input = 'templates/userList.htm';
	my $vars  = {
	    users  => $users,
	    nameSort => $user_sort,
	    roleSort => $role_sort,	    
	};
	
	$tt->process($input, $vars)
	    || die $tt->error( );
}


