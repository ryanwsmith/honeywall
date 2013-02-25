# This contains some basic functions for
# database access
#


#----- Module stuff
package Walleye::AdminUtils;

require Exporter;
our @ISA=("Exporter");


#--- we should look at restricting the list of exported funtion
#--- but this is a step in the right direction.
our @EXPORT = qw( 
                   create_session
                   remove_session
 
		  check_honeywall_init
		  get_conf_dir
		  get_log_dir
		  hw_get_vars
		  hw_set_vars
		  hwsetvar
		  todays_date
		  formatted_date
		  validate_user
		  check_password_aged
		  check_password_attempts
		  validate_password
		  get_user_info
		  check_password_changed
		  check_password_history
		  error
		  display_login_page
		  display_new_password_page
		  display_error_page
		  display_admin_msg
		  display_header_page
		  display_footer_page
		  ConnectToDatabase
		  SendSQL
		  MoreSQLData
		  FetchSQLData
		  FetchOneColumn
		  SqlQuote
		  check_file_status
		  loadvars
		logger
		update_password_attempts
		clear_user_from_password_attempts
		ConnectToWalleyeDatabase
		prepare_query
		Disconnect_from_db
		hw_run_hwctl
		ConnectAdminToDatabase
	       );
		 





use diagnostics;
use strict;

#use hwctl;

use DBI;
use CGI::Session;
use CGI qw/:standard/;
use CGI::Carp 'fatalsToBrowser';

#use CGI::Carp qw(fatalsToBrowser);
#use CGI qw(:standard);

use Template;
use Time::Local;
use Date::Format;

#$::confdir = "/hw/conf";
#$::logdir = "/var/log";
#$::hwdir = "/mnt/hw";

$::max_attempts = 3;

$::db_host = "";
$::db_port = "";
$::db_name = "walleye_users_0_3";
$::db_user = "admin";
$::db_pass = "honey";

my $PASSWORD_EXPIRES = 90;

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

################################## Honeywall functions #######################

# Check to see if the honeywall has been configured.
sub check_honeywall_init {
	my %hw_vars = hw_get_vars();
	my $err_msg = "This Honeywall has not been configured.  Please run Initial Setup from the administration menu first.";

	if ($hw_vars{"HwINIT_SETUP"} ne "done") {
		error($err_msg,"full");
	}

	return 1;

}

sub hwgetvar {
    my($var) = @_;
    my($result) = "";
    chomp($result = `. /etc/rc.d/init.d/hwfuncs.sub; echo \$$var; exit 0`);
	#chomp($result = `. /usr/local/bin/hwfuncs.sub; echo \$$var; exit 0`);
	#chomp($result = `. $hwfuncs; echo \$$var; exit 0`);
    $result;
}

sub hwsetvar {
    my($var, $val) = @_;
	my $file;
	my $status;
	
	my $conf_dir = get_conf_dir();

	$file = "$conf_dir/$var";
	my $tmp = "/tmp/$var";
	open(TMP, ">$tmp");
	print TMP $val;
	close(TMP);
	my $cmd = "sudo mv -f $tmp $file";
	$status = system($cmd);
	#$status = system("sudo echo $val > $file");
	error("Could not run command $cmd $?") unless $status == 0;

	# Remove temp files
	#$cmd = "sudo rm $tmp";
	#$status = system($cmd);
	#error("Could not run command $cmd $?") unless $status == 0;

   	# `. /etc/rc.d/init.d/hwfuncs.sub; hw_set \"$var\" \"$val\"; exit 0`;
	#`. sudo /usr/local/bin/hwfuncs.sub; hw_set \"$var\" \"$val\"; exit 0`;
	#`. sudo $hwfuncs; hw_set \"$var\" \"$val\"; exit 0`;
}

sub get_conf_dir {
	my $dir = hwgetvar("CONFDIR");
	return $dir;
}

sub get_log_dir {
	my $log_dir = hwgetvar("LOGDIR"); 
	return $log_dir;
}

sub hw_get_vars {

	my %hw_vars;
	my $dir = hwgetvar("CONFDIR");
    die "could not get CONFDIR $!\n" unless ($dir);
    opendir DIR, $dir,
        or die "can't read directory $dir\n";
    my @vars = grep("Hw", readdir DIR);
    closedir DIR;
    foreach my $var (@vars) {
        if( -f "$dir/$var" ) {
            my $val;
            chomp($val=`sudo cat $dir/$var`);
			$hw_vars{$var} = $val;
        }
    }
	return %hw_vars;
}

sub hw_set_vars {
	my ($hw_vars) = (@_);
	my $key;
	my $var;
	my $val;

	foreach $key (keys %$hw_vars) {
		$var = $key;
		$val = $hw_vars->{$key};
		hwsetvar($var, $val);
	}
}	

# Runs the command /usr/local/bin/hwctl
sub hw_run_hwctl {
	my ($hw_vars) = (@_);
	my $key;
	my $var;
	my $val;
	my $cmd;
	my $hwctl_args;
	my $status;

	foreach $key (keys %$hw_vars) {
		$hwctl_args .="$key=\"$hw_vars->{$key}\"";
        $hwctl_args .=" ";
	}

	$cmd = "/usr/local/bin/hwctl -r $hwctl_args > /dev/null";
   $status = system("sudo $cmd");
   error("Could not run process: $cmd $?") unless $status == 0;
	
}

sub loadvars {
    my($file)= @_;
    my $dir = get_conf_dir(); 
	my $var;
	my $val;
    open(I, $file) || error("can't open file $file: $!");
    while (<I>) {
        next if m|^\s*#|;    # Skip comment lines.
        next if m|^\s*$|;    # Skip blank lines.
        # For now, ensure nobody screws up and sticks a
        # a comment at the end of a variable declaration
        warn "Comment after variable declaration on line $. (stripped)\n"
            if m|#|;
        # Stripped trailing comments and whitespace.
        s|\s*#.*||;
        s|\s+$||;
        ($var,$val) = split("=",$_);
        if ($var =~ m|[^A-Za-z_0-9]+|) {
            warn "Variable \"$var\" contains illegal characters (ignoring)\n";
        #} elsif (! open(V, ">$dir/$var")) {
        #    warn "Could not create \"$dir/$var\" : $!\n";
        } else {
			#logger("var: $var, val: $val");
			hwsetvar($var, $val);
            #print V "$val";
            #close(V);
        }
    }
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
	
    #my $time = timelocal(localtime);
    #return scalar(localtime($time));
	my $tz = time2str('%a %b %d %X %Y %Z', time);
	return $tz;
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
			if (check_password_aged($user_info[0], $PASSWORD_EXPIRES)) {
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
        my ($userid, $age) = (@_);

        my @row;

        ConnectToDatabase();
        my $query = "select to_days(now()) - to_days(created), pass_num from passwords where userid=$userid order by pass_num";

        SendSQL($query);

        # Just need the first row
        @row = FetchSQLData();

        if(defined $row[0] && $row[0] >= $age) {
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
# Since this application uses a header and footer template, we need to let
# the function know if the error has occurred before or after the display_header
# method has been called.  This function takes 2 parameters, an error message
# and parameter to let it know whether the dislpay header method needs to be
# called
sub error {
	my ($msg, $disp) = (@_);
	my $session = validate_user();

	if(defined $disp) {
		display_header_page($session);
	}

	display_error_page($msg);
	display_footer_page();

	exit;

}	

sub display_login_page {
	
	my $date = todays_date();
	
	$| = 1;
	print "Content-type: text/html\n\n";

	my $tt    = Template->new( );

	my $input = 'templates/login.htm';
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

	my $tt    = Template->new( );

	my $input = 'templates/newPassword.htm';
	my $vars  = {
		date  => $date,
		login_name => $login_name,
	    message  => $login_message,	    
	};
	
	$tt->process($input, $vars)
	    || die $tt->error( );

}


sub display_error_page {
	
	my ($err_msg) = (@_);
	
	#$| = 1;
	#print "Content-type: text/html\n\n";

	my $tt = Template->new( );

	my $input = 'templates/errorPage.htm';
	my $vars  = {
	    error_msg  => $err_msg,	    
	};
	
	$tt->process($input, $vars)
	    || die $tt->error( );

}

sub display_admin_msg {
	my($title, $msg, $menu) = (@_);
	
	my $tt    = Template->new( );
	
	my $input = 'templates/adminMessage.htm';
	my $vars  = {
	    title  => $title,
	    msg  => $msg,
		menu => $menu,
	    
	};
	
	$tt->process($input, $vars)
	    || die $tt->error( );
	   
	display_footer_page();

	# Need to exit script
	exit;
}


sub display_header_page {
	my($session, $tab) = (@_);
	
	my $date = todays_date();

	my $role = $session->param("role");
	my $sess_cookie = cookie(CGISESSID => $session->id);

    print header( -TYPE => 'text/html',
		  -EXPIRES => 'now',
		  -cookie=>$sess_cookie
		  );

	
	$| = 1;
	#print "Content-type: text/html\n\n";
	
	my $tt    = Template->new( );
	
	my $input = 'templates/header.htm';
	my $vars  = {
	    date  => $date,
	    role  => $role,
		tab => $tab,
	    
	};
	
	$tt->process($input, $vars)
	    || die $tt->error( );
	    
}

sub display_footer_page {
	
	my $tt    = Template->new( );
	
	my $input = 'templates/footer.htm';
	my $vars  = {
	    
	};
	
	$tt->process($input, $vars)
	    || die $tt->error( );
	    
}

###################################  Database  ################################
sub ConnectToDatabase {

    #if (!defined $::db) {
    #    my $name = $::db_name;
	
        $::db = DBI->connect("DBI:mysql:host=$::db_host;database=$::db_name;port=$::db_port", $::db_user, $::db_pass, {AutoCommit => 0})
            || die "Cannot connect to the database " . $DBI::errstr; 
    #}
}

sub ConnectToWalleyeDatabase {

	my $db_name          = "hflow";
	my $db_server        = "";
	my $db_port          = "";
	my $db_uid           = "walleye";
	my $db_passwd        = "honey";

	$::db = DBI->connect("DBI:mysql:database=$db_name;host=$db_server;port=$db_port",$db_uid, $db_passwd)
    	|| error("Cannot connect to the database " . $DBI::errstr);

}

# Need a way for db admin to connect
sub ConnectAdminToDatabase {

	my $db_name          = "walleye_users_0_3";
	my $db_server        = "";
	my $db_port          = "";
	my $db_uid           = "roo";
	my $db_passwd        = "honey";

	$::db = DBI->connect("DBI:mysql:database=$db_name;host=$db_server;port=$db_port",$db_uid, $db_passwd)
    	|| error("Cannot connect to the database " . $DBI::errstr);

}


sub prepare_query {
	my ($query) = @_;
	my $connection;
	
	$connection = $::db->prepare($query);
	return $connection;
}

sub Disconnect_from_db {
	$::db->disconnect()
            || die "Cannot connect to the database " . $DBI::errstr;

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

#################################### Misc  ####################################

# Checks to see if file exists
sub check_file_status {
	my ($file) = (@_);
	my @info;
	@info = stat $file || error("$file: $!");

	return \@info;

}


1;
