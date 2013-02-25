# (C) 2005 The Honeynet Project.  All rights reserved.
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#


#--- Author: Scott Buchan

package Walleye::Login;

use strict;

#----- Module stuff
require Exporter;
our @ISA=("Exporter");

our @EXPORT = qw(validate_user 
		 error 
		 create_session 
		 remove_session
		 
		 display_login_page
		 display_new_password_page
		 display_error_page
	       );
		 

#use hwctl;

use DBI;
use CGI::Session;
use CGI qw/:standard/;
use CGI::Carp 'fatalsToBrowser';

#use CGI::Carp qw(fatalsToBrowser);
#use CGI qw(:standard);

use Template;
use Time::Local;

my $templates_dir = "/var/www/html/walleye/admin/templates";

$::max_attempts = 3;

$::db_host = "";
$::db_port = "";
$::db_name = "walleye_users_0_3";
$::db_user = "admin";
$::db_pass = "honey";

my $sid;
my $login_message;

################################## Logging  #################################
# Use for debugging
sub logger {
	my ($msg) = (@_);
	my $logfile = "/tmp/adminlog.txt";
	open(LOG, ">>$logfile");
	print LOG $msg . "\n";
	close(LOG);
}


################################## Session ###################################

# Function will check to see if session exits
# Returns session
sub verify_session {

	ConnectToDatabase();
	my $sess_cookie = cookie("CGISESSID") || undef;
	
	if(!defined $sess_cookie) {
		return 0;
	}
		
	my $session = new CGI::Session("driver:MySQL", $sess_cookie, {Handle=>$::db});
	
	# Check to see if session id matches cookie
	my $sess_id = $session->id();
	
	if($sess_cookie ne $sess_id) {
		# Session is not valid
		$session->delete();
		return 0;
	}
	
	# Session is valid
	return $session;
}
	
# Creates a new session and saves session id in a cookie	
sub create_session {
	ConnectToDatabase();
	
	my $session = new CGI::Session("driver:MySQL", undef, {Handle=>$::db});
	
	my $cookie = cookie(CGISESSID => $session->id);
	
	# Need to clean up old sessions in the database that are not
	# removed when a user does not log out.
	session_clean_up();
	
	return $session;
}

# Deletes session when user logs out.
sub remove_session {
	
	ConnectToDatabase();
	my $sess_cookie = cookie("CGISESSID") || undef;
	my $session = new CGI::Session("driver:MySQL", $sess_cookie, {Handle=>$::db});
	$session->delete();
		
}

# Removes old sessions from the database
sub session_clean_up {
	
	my $sec;
    my $min;
    my $hour;
    my $day;
    my $month;
    my $year;
    my $time;
    my $expireDate;
    my $timestamp;
    my $query;

    $time = timelocal(localtime);
    
    # Subtract 1 day (in seconds from todays date
    $time -= 86400;
    ($sec, $min, $hour, $day, $month, $year) = (localtime($time))[0,1,2,3,4,5];
    $month += 1;
    $year += 1900;
    $timestamp = $year . "-" . $month . "-" . $day . " " . $hour . ":" . $min . ":" . $sec;

	$query = "delete from sessions where loggedIn < " . SqlQuote($timestamp);
	
    ConnectToDatabase();
    SendSQL($query);
	
}

################################## Date #######################################
sub todays_date {
	
    my $time = timelocal(localtime);
    return scalar(localtime($time));
}	

sub formatted_date {
	my $day;
	my $month;
	my $year;
	my $date;

	($day, $month, $year) = (localtime)[3,4,5];
	$month = $month + 1;

	if ($month < 10) {
		$month = "0" . $month;
	}

	if ($day < 10 ) {
		$day = "0" . $day;
	}

	$year = $year + 1900;

	$date = $year . $month . $day;

	return $date;
}
	
################################## Login ######################################	
sub validate_user {
	my $session;
	my @user_info;
	
	$login_message = "";
	
	# If session exist and is valid - we're done.
	$session = verify_session();
	if($session) {
		return $session;
	}
	
	#  Check if user is comming from login page.
	if(defined param('userName') && defined param('password')) {
		my $login =  param('userName');
		my $password =  param('password');
	
		# Remove any password attempts older than 15 min.
		clean_out_password_attempts();
		
		@user_info = get_user_info($login);
		my $valid_password = $user_info[1];

		# Check if user has exceeded password attempts
		my $attempts = check_password_attempts($login);
		if (defined $attempts && $attempts >= $::max_attempts) {
			$login_message = "You have exceeded the maximum number of login attempts.";
			display_login_page();
			exit;
		}
		
		if ($valid_password eq "" || $password ne $valid_password) {
			$login_message = "The username or password you entered is not valid.";
		
			# Check the number of invalid password attempts
			update_password_attempts($login);
			
			# Display login page with error message
			display_login_page();
			exit;
		} else {
			# Check to see if password has expired
			if (check_password_aged($user_info[0])) {
				display_new_password_page($login);
				exit;
			}

			clear_user_from_password_attempts($login);
			# User has been validated so create a new session
			$session = create_session();
			$session->param("userId", $user_info[0]);
			$session->param("role", $user_info[2]);
			# Have the session expire if it has been idle for more than 1 hour.
			$session->expire('+1h');
			return $session;
		}
	} else {
		# No valid session so display login page
		display_login_page();
		exit;
	}

}

sub check_password_aged {

	 my ($userid) = (@_);

        my @row;

        ConnectToDatabase();
        my $query = "select to_days(now()) - to_days(created), pass_num from passwords where userid=$userid order by pass_num desc";

        SendSQL($query);
	
	# Just need the first row
        @row = FetchSQLData();

	if(defined $row[0] && $row[0] >= 90) {
		return 1;
	}

	# Check to see if password exists
	if($row[0] eq "") {
		return 1;
	}

        return 0;

}


sub clean_out_password_attempts {
	my $sec;
    my $min;
    my $hour;
    my $day;
    my $month;
    my $year;
    my $time;
    my $expireDate;
    my $timestamp;
    my $query;

    $time = timelocal(localtime);
    
    # Subtract 15 minutes (in seconds from todays date
    $time -= 900;
    ($sec, $min, $hour, $day, $month, $year) = (localtime($time))[0,1,2,3,4,5];
    $month += 1;
    $year += 1900;
    $timestamp = $year . "-" . $month . "-" . $day . " " . $hour . ":" . $min . ":" . $sec;

	$query = "delete from passwordattempts where loggedIn < " . SqlQuote($timestamp);
	
    ConnectToDatabase();
    
	SendSQL($query);


}

sub check_password_attempts {
	my ($user) = (@_);
	my $result;
	ConnectToDatabase();
	
	SendSQL("select attempts from passwordattempts where login_name = " . SqlQuote($user));
	$result = FetchOneColumn();

	return $result;

}

sub clear_user_from_password_attempts {
	my ($user) = (@_);
	my $result;
	ConnectToDatabase();
	
	SendSQL("delete from passwordattempts where login_name = " . SqlQuote($user));

}


sub update_password_attempts {
	my ($user) = (@_);
	my $result;
	ConnectToDatabase();

	SendSQL("select attempts from passwordattempts where login_name = " . SqlQuote($user));
	$result = FetchOneColumn();
	
	# If no record exist, create a new one
	if (!defined $result) {
        SendSQL("insert into passwordattempts (login_name, attempts) values(" . SqlQuote($user) . ", 1)");
    } else {
		$result++; 
		SendSQL("update passwordattempts  set attempts=$result where login_name=" . SqlQuote($user));
	}

}

sub validate_password {
	my ($user, $pass) = (@_);
	my $result;
	ConnectToDatabase();
	
	SendSQL("select password from user where login_name = " . SqlQuote($user));
	$result = FetchOneColumn();
	if (!defined $result) {
        $result = "";
    }
    return $result;

}

sub get_user_info {
	my ($user) = (@_);
	my @result;
	
	ConnectToDatabase();
	SendSQL("select userid, password, role from user where login_name = " . SqlQuote($user));
	
	@result = FetchSQLData();
	
	return @result;
}

# Returns a reference to an array containing a reference to an array for each row
sub get_password_history {
	my ($userid) = (@_);
	
	my @row;
	my @list;

	ConnectToDatabase();
	my $query = "select * from passwords where userid=$userid order by created desc limit 10";
	SendSQL($query);

	while(MoreSQLData()) {
		@row = FetchSQLData();
		push @list, [@row];
	}
	
	return \@list;

}	

sub check_password_changed {

	my ($userid, $pass) = (@_);
	my $last_password = "";
	my $passwords = get_password_history($userid);

	if(defined $passwords->[0][1]) {
		$last_password = $passwords->[0][1];
	}
	
	if ($pass eq $last_password) {
		return 0;
	}

	return 1;
}

sub check_password_history {
	my ($userid, $pass) = (@_);
	my $row;
	my $last_password;
	my $prev_found = "";
	
	my $passwords = get_password_history($userid);
	
	foreach $row(@$passwords){
		$last_password = $$row[1];
		if ($pass eq $last_password) {
			$prev_found = "true";
		}
	}

	return $prev_found;
}


	

################################### Display login and error pages ############


sub display_login_page {
	
	my $date = todays_date();
	
	$| = 1;
	print "Content-type: text/html\n\n";

	my $tt    = Template->new(
				  INCLUDE_PATH => $templates_dir
				  );

	my $input = "login.htm";
	my $vars  = {
		date  => $date,
	    message  => $login_message,	    
	};
	
	$tt->process($input, $vars)
	    || die $tt->error( );

}

sub display_new_password_page {
	my ($login_name, $login_message) = (@_);
	
	my $date = todays_date();
	
	$| = 1;
	print "Content-type: text/html\n\n";

	my $tt    = Template->new(
				INCLUDE_PATH => $templates_dir
				 );

	my $input = "newPassword.htm";
	my $vars  = {
		date  => $date,
		login_name => $login_name,
	    	message  => $login_message,	    
	};
	
	$tt->process($input, $vars)
	    || die $tt->error( );

}


sub error {
	my ($msg) = (@_);
	my $session = validate_user();
	
	display_header_page($session);
	display_error_page($msg);
	display_footer_page();

	exit;

}	

sub display_error_page {
	
	my ($err_msg) = (@_);
	
	#$| = 1;
	print "Content-type: text/html\n\n";

	my $tt = Template->new(
			   INCLUDE_PATH => $templates_dir
 			       );

	my $input = 'errorPage.htm';
	my $vars  = {
	    error_msg  => $err_msg,	    
	};
	
	$tt->process($input, $vars)
	    || die $tt->error( );
        
       exit;
}

sub display_admin_msg {
	my($title, $msg) = (@_);
	
	my $tt    = Template->new( );
	
	my $input = 'templates/adminMessage.htm';
	my $vars  = {
	    title  => $title,
	    msg  => $msg,
	    
	};
	
	$tt->process($input, $vars)
	    || die $tt->error( );
	   
	display_footer_page();

	exit;
}




###################################  Database  ################################
sub ConnectToDatabase {

    if (!defined $::db) {
        my $name = $::db_name;
	
        $::db = DBI->connect("DBI:mysql:host=$::db_host;database=$name;port=$::db_port", $::db_user, $::db_pass);

	if(!defined $::db){
          display_error_page( "Cannot connect to the database " . $DBI::errstr); 
        }
    }
}


sub SendSQL {

    my ($str) = (@_);   
    
    $::currentquery = $::db->prepare($str);
    if (!$::currentquery->execute) {
        my $errstr = $::db->errstr;
        # Cut down the error string to a reasonable.size
        $errstr = substr($errstr, 0, 2000) . ' ... ' . substr($errstr, -2000)
                if length($errstr) > 4000;
        die "$str: " . $errstr;
    }
    
}

sub MoreSQLData {
    # $::ignorequery is set in SendSQL
    if ($::ignorequery) {
        return 0;
    }
    if (defined @::fetchahead) {
        return 1;
    }
    if (@::fetchahead = $::currentquery->fetchrow_array) {
        return 1;
    }
    return 0;
}

sub FetchSQLData {
    # $::ignorequery is set in SendSQL
    if ($::ignorequery) {
        return;
    }
    if (defined @::fetchahead) {
        my @result = @::fetchahead;
        undef @::fetchahead;
        return @result;
    }
    return $::currentquery->fetchrow_array;
}

sub FetchOneColumn {
    my @row = FetchSQLData();
    return $row[0];
}

sub SqlQuote {
    my ($str) = (@_);
    $str =~ s/([\\\'])/\\$1/g;
    $str =~ s/\0/\\0/g;
    return "'$str'";
}




1;
