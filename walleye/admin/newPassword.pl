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

use CGI qw/:standard/;
use CGI::Carp 'fatalsToBrowser';

use Walleye::AdminUtils;

my $login_message;

validate_new_password();

sub validate_new_password {
	my @user_info;
	my $session;
	
	$login_message = "";
	
	#  Check if user is comming from login page.
	if(defined param('userName') && defined param('password')) {
		my $login =  param('userName');
		my $password =  param('password');
		my $newpassword = param("newpassword");
	
		@user_info = get_user_info($login);
		my $valid_password = $user_info[1];

		 # Check if user has exceeded password attempts
         my $attempts = check_password_attempts($login);
         if (defined $attempts && $attempts >= $::max_attempts) {
            $login_message = "You have exceeded the maximum number of login attempts.";
            display_new_password_page($login, $login_message); 
        	exit;
		}


		if ($valid_password eq "" || $password ne $valid_password) {
			$login_message = "The username or password you entered is not valid.";
			update_password_attempts($login);
			display_new_password_page($login, $login_message);
			exit;

		# Check if new password matches any of the previous 10 
		} elsif(check_password_history($user_info[0], $newpassword)) {
			$login_message = "The password entered is the same as one of your previous 10 passwords.";
			 display_new_password_page($login, $login_message);
            exit;

		} else {
			# user has been validated - update user with new password
			update_user_password($user_info[0], param("newpassword"));

			clear_user_from_password_attempts($login);

			# User has been validated so create a new session
			$session = create_session();
			$session->param("userId", $user_info[0]);
			$session->param("role", $user_info[2]);
			# Have the session expire if it has been idle for more than 1 hour.
			$session->expire('+1h');

			#display_header_page($session);
			display_changed_password_page($session);
			#display_footer_page();
		}
	} else {
		# No valid session so display login page
		display_new_password_page();
		exit;
	}

}

sub update_user_password {
	my($userid, $pass) = (@_);

	my $query1 = "update user set password=" . SqlQuote($pass) . " where userid=$userid";
	my $query2 = "insert into passwords (userid, password) values($userid, " . SqlQuote($pass) . ")";
	
	ConnectToDatabase();
	SendSQL($query1);
	SendSQL($query2);
}

sub display_changed_password_page {
	my($session) = (@_);
	my $msg = "Your password has been changed.";
	my $tt = Template->new( );

	# We are redirecting the page to walleye.pl but we
	# need to add the session id to the cookie first
	my $sess_cookie = cookie(CGISESSID => $session->id);

    print header( -TYPE => 'text/html',
                  -EXPIRES => 'now',
                  -cookie=>$sess_cookie
                  );


	 $| = 1;
 #    print "Content-type: text/html\n\n";

	my $input = 'templates/redirect.htm';
	my $vars  = {
	    msg  => $msg,	    
	};
	
	$tt->process($input, $vars)
	    || die $tt->error( );

}

