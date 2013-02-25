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


if($role ne "admin" ) {
	error("You are not authorized to access this page.","true");
}

my $sess_cookie = cookie(CGISESSID => $session->id);

# Pass the tab to display on the header page.
my $tab = "cdRom";

display_header_page($session, $tab);
check_action();
display_page();
display_footer_page();


sub check_action {

	my $action = "";

	if(defined param("act")) {
		$action = param("act");
	}
		
	SWITCH: {
		if($action eq "unpackIso") { unpack_iso(); last SWITCH;}
		if($action eq "createConfig") { create_config(); last SWITCH;}
		if($action eq "uploadFile") { upload_file(); last SWITCH;}
		if($action eq "editConfig") { edit_config(); last SWITCH;}
		if($action eq "changePassword") {change_password(); last SWITCH;}
		if($action eq "removePassword") {remove_password(); last SWITCH;}
		if($action eq "removeFile") {remove_file(); last SWITCH;}

	}

}

sub remove_file {
    my $file_num = 0;
    my $count;
    my $file;
    my $fileChecked;
	my $title = "Remove customized files";
	my $msg = "The following files have been removed:<br>";
	my $menu = "cdrom";
	my $cmd;	
	my $status;
	

    if(defined param("fileNum")) {
        $file_num = param("fileNum");
    }

    for($count = 1; $count <= $file_num; $count++) {
        $fileChecked = "fileCheck$count";
        if(defined param($fileChecked)) {
            $file = param($fileChecked);
			$msg .= "<br>$file";
			$cmd = "rm -f $file";
			$status = system("sudo $cmd");
			error("Could not run command: $cmd $?") unless $status == 0;
		} 
    }

	display_admin_msg($title, $msg, $menu);
}

sub remove_password {
	my $user;
	my $tmp_file = "/tmp/password.txt";
	my $password_file = $hw_vars{"HwISO_UNPACK"} . "/customization/passwords.txt";
	my $title = "Remove user from passwords file";
	my $msg;
	my $menu = "cdrom";
	my $cmd = "mv -f $tmp_file $password_file";	
	my $status;
	my $line;
	my $user_no_change = "";

	# Veriry iso has been unpacked
	verify_iso_unpacked();

	$user = param('user');

	$msg = "The user $user has been removed from the passwords file.";

	open(FILE,"< $password_file") or error("Could not open file $password_file $!");
	while(defined ($line = <FILE>)) {
		chomp $line;
		if($line =~ /$user:/) {
			next;
		} else {	
			$user_no_change = $line;
		}	
	}	
	close(FILE);

	open(TMP,">$tmp_file") or error("Could not open file $password_file $!"); 
	if($user_no_change ne "") {
		print TMP $user_no_change . "\n";
	}
	close(TMP);

	# If there are no users left in the passwords.txt file
	# then we will remove the file
	if($user_no_change eq "") {
		$cmd = "rm -f $password_file";
	}

	$status = system("sudo $cmd");
	error("Could not run command: $cmd $?") unless $status == 0;

	display_admin_msg($title, $msg, $menu);
}

sub change_password {
	my $user;
	my $password;
	my $salt;
	my $encrypt_password;
	my $user_no_change = "";
	my $tmp_file = "/tmp/password.txt";
	my $password_file = $hw_vars{"HwISO_UNPACK"} . "/customization/passwords.txt";
	my $title = "Change user passwords";
	my $msg;
	my $menu = "cdrom";
	my $cmd = "mv -f $tmp_file $password_file";	
	my $status;
	my $line;

	$user = param('user');
	$password = param('newpassword');
	$msg = "The $user user password has been changed.";
	
	# Veriry iso has been unpacked
	verify_iso_unpacked();

	# Check if passwords file exist and pull out user info
	# that is not changing
	if(-f $password_file ) {
		open(FILE,"< $password_file") or error("Could not open file $password_file $!");
		while(defined ($line = <FILE>)) {
			chomp $line;
			if($line =~ /$user:/) {
				next;
			} else {
				$user_no_change = $line;
			}	
		}	
		close(FILE);
	}

	# Encrypt password
	$salt  = substr($password, 0, 2);
	$encrypt_password = crypt($password, $salt);

	open(TMP,">$tmp_file") or error("Could not open file $password_file $!"); 
	if($user_no_change ne "") {
		print TMP $user_no_change . "\n";
	}
	print TMP "$user:$encrypt_password";
	close(TMP);

	$status = system("sudo $cmd");
	error("Could not run command: $cmd $?") unless $status == 0;

	display_admin_msg($title, $msg, $menu);

}

sub upload_file {
	my $file = param("uploadFile");
	my $save_to_dir = param("saveToDir");
	#my $save_to_file = param("saveToFile");
	my $tmp_file = "/tmp/$file";
	my $upload_file = $hw_vars{"HwISO_UNPACK"} . "/customization/";
	my $cmd; 
	my $status;
	my $title = "Uploaded $file";
	my $msg;
	my $menu = "cdrom";
	my $user = "";

	if (defined param("user")) {
		$user = param("user");
	}	

	# Veriry iso has been unpacked
	verify_iso_unpacked();
	
	if($file) {
		open(UPLOAD, ">$tmp_file") or error("Could not open file $tmp_file $!");
		my ($data, $length, $chunk);
		while($chunk = read($file, $data, 1024)) {
			print UPLOAD $data;
			$length += $chunk;
			if($length > 51200) {
				error("File length is too long");
			}
		}
		close(UPLOAD);
	}

	if($save_to_dir eq "customization") {
		$upload_file .= $file;
	}

	if($save_to_dir eq "ssh") {
		$upload_file .= "ssh-files/$file";
	}

	if($save_to_dir eq "home-dirs") {
		$upload_file .= "home-dirs/$user/$file";
	}

	if($save_to_dir eq "walleye") {
		$upload_file .= "walleye/$file";
	}




	$cmd = "mv -f $tmp_file $upload_file";
	$msg = "$file has been uploaded to $upload_file";

	$status = system("sudo $cmd");
	error("Could not run command: $cmd $?") unless $status == 0;

	display_admin_msg($title, $msg, $menu);
}


sub edit_config {
	my $title = "Customize configuration file";
	my $msg = "The honeywall.conf file has been saved";
	my $menu = "cdrom";
	my $config_file = $hw_vars{"HwISO_UNPACK"} . "/customization/honeywall.conf";
	my $tmp_file = "/tmp/honeywall.conf";
	my $cmd = "mv -f $tmp_file $config_file"; 
	my $status;

	my $file_contents = param("confFile");

	# Veriry iso has been unpacked
	verify_iso_unpacked();

	open(FILE,">$tmp_file") or error("Could not open file $tmp_file $!");
	print FILE "$file_contents";

	$status = system("sudo $cmd");
	error("Could not run command: $cmd $?") unless $status == 0;

	display_admin_msg($title, $msg, $menu);
}

sub create_config {
	my $title = "Customize configuration file";
	my $msg;
	my $menu = "cdrom";

	# Veriry iso has been unpacked
	verify_iso_unpacked();

	if (param("cmd") eq "createFile") {
		create_honeywall_conf_file();
		$msg = "The honeywall.conf file has been created.";
	} elsif (param("cmd") eq "copyFile") {
		copy_honeywall_conf_file();
		$msg = "The honeywall.conf file has been copied over from the installed roo..";
	} elsif (param("cmd") eq "removeFile") {
		remove_honeywall_conf_file();
		$msg = "The honeywall.conf file has been removed.";
	}

	display_admin_msg($title, $msg, $menu);

}

# Creates a honeywall.conf file from conf files
sub copy_honeywall_conf_file {

	my $roo_file = "/etc/honeywall.conf";
	my $file = $hw_vars{"HwISO_UNPACK"} . "/customization/honeywall.conf";
	my $cmd = "cp  $roo_file $file"; 
	my $status;

	# Veriry iso has been unpacked
	verify_iso_unpacked();

	$status = system("sudo $cmd");
	error("Could not run command: $cmd $?") unless $status == 0;	

}

# Creates a honeywall.conf file from conf files
sub remove_honeywall_conf_file {

	my $file = $hw_vars{"HwISO_UNPACK"} . "/customization/honeywall.conf";
	my $cmd = "rm -f $file"; 
	my $status;

	# Veriry iso has been unpacked
	verify_iso_unpacked();

	$status = system("sudo $cmd");
	error("Could not run command: $cmd $?") unless $status == 0;	

}



# Creates a honeywall.conf file from conf files
sub create_honeywall_conf_file {

	# Create a temp file
	my $tmp_file = "/tmp/tmp.conf";
	my $key;
	my $file = $hw_vars{"HwISO_UNPACK"} . "/customization/honeywall.conf";
	my $cmd = "mv -f $tmp_file $file"; 
	my $status;

	# Veriry iso has been unpacked
	verify_iso_unpacked();

	open(FILE,">$tmp_file") or error("Could not open file $tmp_file $!");
	foreach $key (keys %hw_vars) {
		if($key =~ /.*?HwISO/ ) {
			#print FILE "$key=$hw_vars{$key}\n";
		} else {	
			print FILE "$key=$hw_vars{$key}\n";
		}	
	}

	close(FILE);
	
	$status = system("sudo $cmd");
	error("Could not run command: $cmd $?") unless $status == 0;	

}


# Need to check if iso file exists and get its size.
# Need to check if mount directory exist
# Need to check if unpack directory exists and has enough space
# Mount iso dir
# unpack iso
sub unpack_iso() {
	my $title = "Unpack ISO";
	my $msg = "The iso has been unpacked.";
	my $menu = "cdrom";
	my %input;
	my $errorMsg;
	my $iso_size;
	my @iso_stats;
	my $iso_file;
	my @space;
	my $unpack_space;
	my $unpack_dir;
	my @unpack_stats;
	my $mount_dir;
	my $cmd;
	my $status;
	my $mount_cdrom;
	my @cdrom_stats;

	$input{"HwISO_MOUNT"} = param("HwISO_MOUNT");
	$input{"HwISO_UNPACK"} = param("HwISO_UNPACK");
	$unpack_dir = $input{"HwISO_UNPACK"};
	$mount_dir = $input{"HwISO_MOUNT"};

	if(! -d $input{"HwISO_MOUNT"} ) {
		error("ERROR: Mount directory is not correct. " . $input{"HwISO_MOUNT"} . " does not exist or is not a directory.");
	}

	if(! -d $input{"HwISO_UNPACK"} ) {
		error("ERROR: Unpack directory is not correct. " . $input{"HwISO_UNPACK"} . " does not exist or is not a directory.");
	}	

	
	# Check if iso is being mounted from cdrom drive
	if(defined param("mountCdrom")) {
		$mount_cdrom = param("mountCdrom");
		$cmd = "sudo mount -r /dev/cdrom $mount_dir 2>&1";

		$status = system("$cmd");
		error("Could not run command: $cmd $?") unless $status == 0;

		$cmd = "sudo /usr/bin/du -ms $mount_dir 2>&1 |";
		@cdrom_stats = get_command_output($cmd);
		@space = split /\s/, $cdrom_stats[0];
		$iso_size = $space[0];
	} else {	
		$input{"HwISO_FILE"} = param("HwISO_FILE");
		# Check to make sure files and directories exist
		if(! -f $input{"HwISO_FILE"} ) {
			error("ERROR: Iso file is not correct.  " .$input{"HwISO_FILE"} . " does not exist or is not a file.");
		}	

		$iso_file = $input{"HwISO_FILE"};
		$cmd = "sudo /bin/ls -lk $iso_file 2>&1 |";
		@iso_stats = get_command_output($cmd);
		@space = split /\s/, $iso_stats[0];
		$iso_size = $space[5] / 1024;
	}

	# Check to make sure files and directories exist
#	if(! -f $input{"HwISO_FILE"} ) {
#		error("ERROR: Iso file is not correct.  " .$input{"HwISO_FILE"} . " does not exist or is not a file.");
#	}	

#	if(! -d $input{"HwISO_MOUNT"} ) {
#		error("ERROR: Mount directory is not correct. " . $input{"HwISO_MOUNT"} . " does not exist or is not a directory.");
#	}
#
#	if(! -d $input{"HwISO_UNPACK"} ) {
#		error("ERROR: Unpack directory is not correct. " . $input{"HwISO_UNPACK"} . " does not exist or is not a directory.");
#	}	

#	$iso_file = $input{"HwISO_FILE"};
#	$cmd = "sudo /bin/ls -lk $iso_file 2>&1 |";
#	@iso_stats = get_command_output($cmd);
#	@space = split /\s/, $iso_stats[0];
#	$iso_size = $space[5] / 1024;

#	$unpack_dir = $input{"HwISO_UNPACK"};
	$cmd = "sudo /bin/df -m $unpack_dir 2>&1 |";
	@unpack_stats = get_command_output($cmd);
	@space = split /\s+/, $unpack_stats[1];
	$unpack_space = $space[3];

	if ($unpack_space < $iso_size) {
		error("The directory to unpack the iso($unpack_space MB) does not have enough space.  You need at least $iso_size MB");
	}	

	# Mount iso directory
#	$mount_dir = $input{"HwISO_MOUNT"};

	# Check if iso is being mounted from cdrom drive
	if(!defined param("mountCdrom")) {
		$cmd = "sudo mount -o ro,loop $iso_file $mount_dir 2>&1";
		$status = system("$cmd");
		error("Could not run command: $cmd $?") unless $status == 0;
	}
	
	# Copy the unpack-iso.sh script to /tmp so that we can run with sudo
	$cmd = "sudo /bin/cp $mount_dir/dev/unpack-iso.sh /tmp/. 2>&1";
	$status = system("$cmd");
	error("Could not run command: $cmd $?") unless $status == 0;

	# Unpack iso
	$cmd = "sudo /tmp/unpack-iso.sh $mount_dir $unpack_dir 2>&1";
	$status = system("$cmd");
	error("Could not run command: $cmd $?") unless $status == 0;

	# Clean up unpack-iso.sh file
	$cmd = "sudo rm -f /tmp/unpack-iso.sh";
	$status = system("$cmd");
	error("Could not run command: $cmd $?") unless $status == 0;

	hw_set_vars(\%input);

	display_admin_msg($title, $msg, $menu);

}

sub display_page {
	my $input;
	my $disp = "";
	my $conf_file;
	my $msg;
	my $users;
	my $title;
	my $description;
	my $upload_directory;
	my $save_to_file;
	my %files;

	# Update configuration variables
	%hw_vars = hw_get_vars();

	if(defined param("disp")) {
		$disp = param("disp");
	}

	
	SWITCH: {
		if($disp eq "unpackIso") { $input = "templates/customizeIsoUnpack.htm"; last SWITCH;}
		if($disp eq "conf") { $input = "templates/customizeIsoConfig.htm"; last SWITCH; } 
		if($disp eq "editConfig") { $input = "templates/customizeIsoEditConfig.htm"; 
							  $conf_file = get_honeywall_conf();
							  last SWITCH;
							}
		if($disp eq "uploadConfig") { $input = "templates/customizeIsoUpload.htm"; 
									  $title = "Upload honeywall.conf file";
									  $description = "Upload a file to be used to create the honeywall.conf file.";
									  $upload_directory = "customization";
									  #$save_to_file = "honeywall.conf";
									  last SWITCH;
									 }					
		if($disp eq "uploadSsh") { $input = "templates/customizeIsoUpload.htm"; 
									  $title = "Upload ssh files";
									  $description = "Upload files to customize ssh.";
									  $upload_directory = "ssh";
									  last SWITCH;
									 }											 
		if($disp eq "uploadUser") { $input = "templates/customizeIsoUpload.htm"; 
									  $title = "Upload files to users home directory";
									  $description = "Upload files to the appropriate home directory.";
									  $upload_directory = "home-dirs";
									  last SWITCH;
									 }													 
		if($disp eq "uploadWalleye") { $input = "templates/customizeIsoUpload.htm"; 
									  $title = "Upload files to customize walleye";
									  $description = "Upload files to customize the Walleye web application.";
									  $upload_directory = "walleye";
									  last SWITCH;
									 }											 
		if($disp eq "removeSsh") { $input = "templates/customizeIsoRemoveFiles.htm"; 
									  $title = "Files added to customize ssh";
									  $description = "Listed below are the files that will be used to customize ssh.";
									  %files = get_files("ssh-files");
									  last SWITCH;
									 }											 
		if($disp eq "removeUser") { $input = "templates/customizeIsoRemoveFiles.htm"; 
									  $title = "Files added to customize users";
									  $description = "Listed below are the files that will added to the users home directory.";
									  %files = get_files("home-dirs");
									  last SWITCH;
									 }	
		if($disp eq "removeWalleye") { $input = "templates/customizeIsoRemoveFiles.htm"; 
									  $title = "Files added to customize the Walleye application";
									  $description = "Listed below are the files that will be used to customize the Walleye web application.";
									  %files = get_files("walleye");
									  last SWITCH;
									 }										 
		if($disp eq "changePassword") {$input = "templates/customizeIsoChangePassword.htm"; last SWITCH}
		if($disp eq "removePassword") {$input = "templates/customizeIsoRemovePassword.htm"; 
										verify_iso_unpacked();
										$msg = check_for_password_file();
										$users = get_users_from_password_file();
										last SWITCH
									  }
					

		$input = "templates/customizeIso.htm";
	}	
		
	
	my $tt = Template->new( );
	
	my $vars  = {
			vars => \%hw_vars,
			file => $conf_file,
			files => \%files,
			msg => $msg,
			users => $users,
			title => $title,
			directory => $upload_directory,
			description => $description,
			saveToFile => $save_to_file,
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

sub get_users_from_password_file {
	my @users;
	my $line;
	my $count = 0;
	my @file_contents;

	my $password_file = $hw_vars{"HwISO_UNPACK"} . "/customization/passwords.txt";

	if(! -f $password_file ) {
		return \@users;
	} else {
		open(FILE,"< $password_file") or error("Could not open file $password_file $!");
		while(defined ($line = <FILE>)) {
			chomp $line;
			@file_contents = split /:/, $line;
			$users[$count] = $file_contents[0];
			++$count;
		}	
		close(FILE);
	}	

	return \@users

}

sub check_for_password_file {
	my $msg = "";
	my $password_file = $hw_vars{"HwISO_UNPACK"} . "/customization/passwords.txt";

	if(! -f $password_file ) {
		$msg = "You have made no changes to users passwords.";
	}

	return $msg;
}

sub get_honeywall_conf {

	my @list;
	my $iso_config_file = $hw_vars{"HwISO_UNPACK"} . "/customization/honeywall.conf";
	my $orig_iso_config = $hw_vars{"HwISO_UNPACK"} . "cdrom/roo/honeywall.conf.orig";
	my $cmd;
	my $conf_file;
	my $line;

	# Verify that the iso has been unpacked
	verify_iso_unpacked();
	
	# Need to check if a honeywall.conf file exists in the unpacked iso.
	# If one does not exist, use the one on the roo.
	if( -f $iso_config_file) {
		# do nothing	
	} else {
		$iso_config_file = $orig_iso_config;	
	} 

	check_file_status($iso_config_file);

	$cmd = "sudo cat $iso_config_file 2>&1 |";

	@list = get_command_output($cmd);

	foreach $line (@list) {
		$conf_file .= $line;
		$conf_file .= "\n";
	}

	return $conf_file;
	
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

sub verify_iso_unpacked {
	# Check to make sure the iso has been unpacked.
	if(! -d $hw_vars{"HwISO_UNPACK"} ) {
		error("ERROR: The iso has not been unpacked yet. Please unpack the iso.");
	}	
}

sub get_files {
	(my $dir_name) = @_;
	my $unpack_dir = $hw_vars{"HwISO_UNPACK"} . "/customization";
	my @dir;
	$dir[0]="$unpack_dir/$dir_name";
	my %files;
	my $key;

	# Veriry iso has been unpacked
	verify_iso_unpacked();

	find sub {
			return unless -f;
			$files{$File::Find::name} = -s;
			}, @dir;

	#if(!defined %files) {
	if(keys(%files) == 0 ) {
		$files{"No files found"} = "";
	}

	return %files;

}


