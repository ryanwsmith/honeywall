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
#use CGI::Carp qw(fatalsToBrowser);
#use CGI qw(:standard fatalsToBrowser);

use CGI qw/:standard/;
use CGI::Carp 'fatalsToBrowser';

use Walleye::AdminUtils;

#  Validate login
my $session = validate_user();
my $role = $session->param("role");

if($role ne "admin") {
	error("You are not authorized to access this page.", "true");
}

display_header_page($session);
display_add_edit();
display_footer_page();

sub check_add_or_edit {
	my $act = "";

	if(defined param("act")) {
		$act = param("act");
	}
	
    if($act eq "editUser") {
		return "Edit";
    }

    return "Add";
}


sub get_user {
    my ($user_id) = (@_);
    my $query;

    $query = "select userid, firstname, lastname, login_name, password, role from user where userid=" . $user_id;

    ConnectToDatabase();
    SendSQL($query);
    my @row = FetchSQLData();

    return @row;
}


sub display_add_edit {

	my $userid = "";
    my $firstname = "";
    my $lastname = "";
    my $loginId = "";
    my $password = "";
    my $userSelected = "";
    my $adminSelected = "";
    my $adminReadOnlySelected = "";

    my @row;

    my $addEdit = check_add_or_edit();

    if($addEdit eq "Edit") {
		@row = get_user(param("userid"));
		$userid = $row[0];
		$firstname = $row[1];
		$lastname = $row[2];
		$loginId = $row[3];
		$password = $row[4];
		my $role = $row[5];
		
		if($role eq "user") {
		    $userSelected = "selected";
	 	} elsif($role eq "admin") {
		    $adminSelected = "selected";
		} else {
			$adminReadOnlySelected = "selected";
		}
    }

    my $query;

    #$| = 1;
	#print "Content-type: text/html\n\n";
	
	my $tt    = Template->new( );
	
	my $input = 'templates/addEditUser.htm';
	my $vars  = {
		userid => $userid,
	    firstname  => $firstname,
	    lastname => $lastname,
	    loginId => $loginId,
	    password => $password,
	    userSelected => $userSelected,
	    adminSelected => $adminSelected,
	    adminReadOnlySelected => $adminReadOnlySelected,
	    addEdit => $addEdit,
	};
	
	$tt->process($input, $vars)
	    || die $tt->error( );
}

