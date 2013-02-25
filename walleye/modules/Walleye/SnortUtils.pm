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

package Walleye::SnortUtils;

require Exporter;
our @ISA=("Exporter");


#--- we should look at restricting the list of exported funtion
#--- but this is a step in the right direction.
our @EXPORT = qw( 
	get_sid_list
	get_last_sid	
	unpack_rules_file
	create_temp_dir
	find_rules_files
	get_categories
	replace_sid
	create_snort_conf
	restart_snort
	create_snort_rules_files
	get_max_inline_sid
	get_inline_sid_list
	init_snort_inline_rules
	get_inline_categories
	process_inline_rule_file
	read_snort_inline_conf
	create_snort_inline_rules_files
	create_snort_inline_conf
	restart_snort_inline
	get_inline_no_overwrite_list
	get_snort_no_overwrite_list
	get_inline_rule_type_list
);

use diagnostics;
use strict;

use CGI::Session;
use CGI qw/:standard/;
use CGI::Carp 'fatalsToBrowser';

use Template;
use Time::Local;
use Date::Format;

use File::stat;
use File::Basename;
use File::Copy;
use File::Path;
use File::Spec;
use Getopt::Long;
use File::Temp qw(tempdir);
use File::Find;
use IO::File;

use Walleye::AdminUtils;
use Walleye::Rule;


# Returns a hash of sid numbers
sub get_sid_list {
	my %sid_list;
	my @row;
	my $count = 0;
    my $query = "select sid from snort_rules";
    ConnectToDatabase();
    SendSQL($query);

	while(MoreSQLData()) {
		++$count;
		@row = FetchSQLData();
		$sid_list{$row[0]} = $row[0];
		}

 	# Init sid list if empty
	if($count < 1 ) {
		$sid_list{"0"} = 0;
	}

    return %sid_list;

}

# Returns a hash of sid numbers for snort rules that are not
# to be overwritten during an update
sub get_snort_no_overwrite_list {
	my %sid_list;
	my @row;
	my $count = 0;
    my $query = "select sid from snort_rules where noupdate=1";
    ConnectToDatabase();
    SendSQL($query);

	while(MoreSQLData()) {
		++$count;
		@row = FetchSQLData();
		$sid_list{$row[0]} = $row[0];
		}

 	# Init sid list if empty
	if($count < 1 ) {
		$sid_list{"0"} = 0;
	}

    return %sid_list;

}


# Need to know the last sid number used so we can add
# more rules.
sub get_last_sid {
	my $query = "select max(sid) from snort_rules";
	ConnectToDatabase();
    SendSQL($query);

    my $last_sid = 1;

	my @row = FetchSQLData();

    if(!defined $row[0]) {
        return $last_sid;
    }

	return $row[0];

}

# Checks file type and unpacks file if necessary.
sub unpack_rules_file {
	my ($tmp_dir,$filename) = @_;
	my $cmd;
	my $status;
	my $file = "$tmp_dir/$filename";

	# Check if file is an individual rules file or tar or tarred and gzipped
	if($filename =~ /(\.tar\.gz$|\.tgz$)/) {
		$cmd = "tar -C $tmp_dir -xzf $file";
		$status = system("sudo $cmd");
		error("Could not run command $cmd $?") unless $status == 0;
		# Process tar file then individual rules file
	} elsif ($filename =~ /(\.tar$)/) {
		$cmd = "tar -C $tmp_dir -xf $file";
		$status = system("sudo $cmd");
		error("Could not run command $cmd $?") unless $status == 0;
		# Process tar file then individual rules file
	} elsif ($file =~ /(\.rules$)/) {
		# This is an individual rules file - do not need to expand.
	} else {
		error("Error: File needs to be a single rules file, or in a tar, tar.gz or tgz format");
		exit;
	}

}

# Create a temporary directory to store and expand files
sub create_temp_dir {
	my ($dir) = @_;
	my $tmpdir = tempdir("snortrules.XXXXXXXXXX", DIR => File::Spec->rel2abs($dir)) or die "Could not create dir";

	return $tmpdir;

}

# Recursively search the directory for rules files.
sub find_rules_files {
	my($dir) = @_;
	my @dirs;
	$dirs[0]= "$dir";
	my %files;
	my $filename;
	my $key;
	my $category;
	my $filepath;

	find sub {
		return unless -f;
		$filename = $_;
		$filepath = $File::Find::name;
		if($filepath =~ /(\.rules$)/) {
			# Strip the .rules off the file name as this will be
			# used for the name of the category of the rule.
			if ($filename =~ /(.+?)\.rules/) {
      		$category = $1;
			} 
			$files{$filepath} = "$category";
		}
		}, @dirs;

	if(keys(%files) == 0 ) {
		error("Error: No rules files found");
		exit;
	}

	return %files;

}

# Returns an array of categories.
sub get_categories {
	my @row;
	my @list;
	my $count = 0;

	my $query = "select distinct category from snort_rules order by category";
	ConnectToDatabase();
    SendSQL($query);

	$list[$count++] = "All Categories";
    while(MoreSQLData()) {
    	@row = FetchSQLData();
		$list[$count++] = $row[0];
        }

        return @list;
}

# Replaces the sid number in the rule.
sub replace_sid {
	my ($sid, $rule) = @_;

	if ($rule =~ /\bsid\s*:\s*(\d+)\s*;/i) {
		$rule =~ s/\bsid\s*:\s*([0-9]*);/sid:$sid;/;
	} else {
		$rule =~ s/;/;sid:$sid;/;		
	}

    return $rule;
}


# This function will replace the previous included rules files
# with the new rules files.
sub create_snort_conf {
	my @categories = get_categories();
	my $category;
	my $tmp_file = "/tmp/snort.conf";
	#my $snort_conf = "/etc/hflowd/snort/snort.conf";
    my $snort_conf = "/etc/snort/snort.conf";
	my $line;
	my $count = 0;
	my $cmd = "mv -f $tmp_file $snort_conf";
	my $status;

	open(TMP, ">$tmp_file") or error("Could not open file $tmp_file $!");
	open(CONF, "<$snort_conf") or error("Could not open file $snort_conf $!");

	while(defined($line = <CONF>)) {
		if($line  =~ /\binclude \$RULE_PATH/i) {
			if($count == 0) {
				$count = 1;
				foreach $category (@categories) {
					if($category ne "All Categories") {
						print TMP "include \$RULE_PATH/$category.rules\n";
					}
				}
			}
			next;
		}
		print TMP "$line";
	}

	$status = system("sudo $cmd");
	error("Could not run command: $cmd $?") unless $status == 0;
	
}

sub restart_snort {
	my $cmd = "/etc/init.d/hflow-snort restart > /dev/null";
	my $status;

	$status = system("sudo $cmd");
	error("Could not run $cmd $?") unless $status == 0;
}

# Removes all snort rules files and replaces them with the enabled rules
# stored in the database.
sub create_snort_rules_files {
	my @categories = get_categories();
	my $category;
	my %rule_files;
	my $query = "select * from snort_rules where enabled=1";
	my $tmp_dir;
	my $tmp_file;
	my $key;
	my $dir = "/tmp";
	my @row;
	my $cmd;
	my $status;

	# Create temp directory
	$tmp_dir = create_temp_dir($dir);

	# Create hash of file names
	foreach $category (@categories) {
		if($category ne "All Categories") {
			$tmp_file = "$tmp_dir/$category.rules";
			$rule_files{$category} = IO::File->new(">> $tmp_file"); 
		}
	}

	ConnectToDatabase();
	SendSQL($query);

	while(MoreSQLData()) {
		@row = FetchSQLData();
		print {$rule_files{$row[1]}} "$row[2]\n";
	}

	# Remove existing snort rules files
	$cmd = "rm -rf /etc/snort/rules/*.rules";
    $status = system("sudo $cmd");
    error("Could not run command: $cmd $?") unless $status == 0;

	# Copy new rules files to /etc/snort/rules
	$cmd = "mv -f $tmp_dir/*.rules /etc/snort/rules/";
	$status = system("sudo $cmd");
    error("Could not run command: $cmd $?") unless $status == 0;

	# Remove temporary directory
	$cmd = "rm -rf $tmp_dir";
	$status = system("sudo $cmd");
    error("Could not run command: $cmd $?") unless $status == 0;

}

############################## Snort Inline functions ###################

# Returns a hash of sid numbers for snort-inline rules that are not
# to be overwritten during an update
sub get_inline_no_overwrite_list {
	my %sid_list;
	my @row;
	my $count = 0;
    my $query = "select sid from snort_inline_rules where noupdate=1";
    ConnectToDatabase();
    SendSQL($query);

	while(MoreSQLData()) {
		++$count;
		@row = FetchSQLData();
		$sid_list{$row[0]} = $row[0];
		}

 	# Init sid list if empty
	if($count < 1 ) {
		$sid_list{"0"} = 0;
	}

    return %sid_list;

}

# Returns a hash of sid numbers and rule types for snort-inline rules 
sub get_inline_rule_type_list {
	my %sid_list;
	my @row;
	my $count = 0;
    my $query = "select sid, type from snort_inline_rules";
    ConnectToDatabase();
    SendSQL($query);

	while(MoreSQLData()) {
		++$count;
		@row = FetchSQLData();
		$sid_list{$row[0]} = $row[1];
		}

 	# Init sid list if empty
	if($count < 1 ) {
		$sid_list{"0"} = 0;
	}

    return %sid_list;

}


# Need to know the last sid number used so we can add
# more rules.
sub get_max_inline_sid {
	my $max_sid;
	my $query = "select max(sid) from snort_inline_rules";
	ConnectToDatabase();
    SendSQL($query);

	my @row = FetchSQLData();
	
	$max_sid = $row[0];
	if($max_sid < 10000) {
		$max_sid = 10000;
	}
	return $max_sid;

}

# Returns a hash of sid numbers
sub get_inline_sid_list {
	my %sid_list;
	my @row;
	my $count = 0;
    my $query = "select sid from snort_inline_rules";
    ConnectToDatabase();
    SendSQL($query);

	while(MoreSQLData()) {
		++$count;
		@row = FetchSQLData();
		$sid_list{$row[0]} = $row[0];
	}

	# Init sid list if empty
	if($count < 1 ) {
		$sid_list{"0"} = 0;
	}

    return %sid_list;

}

# Check to see if this is the first time viewing snort_inline rules.
# If so, we need to add the rules in /etc/snort_inline to the
# database.
sub init_snort_inline_rules {
	my %rule_files;
	my $dir = "/etc/snort_inline/rules";
	my $key;
	my @row;
	my $query = "select count(sid) from snort_inline_rules";
	my $enable = "yes";
	my %enabled_rules;
	my $overwrite = "";  

	# We only want to enable the rules listed in the conf file.
	%enabled_rules = read_snort_inline_conf();

	# Check to see if we have to update the db table
	# THIS SHOULD BE REMOVED BEFORE THE NEXT ISO RELEASE
	check_for_updated_inline_table();

	ConnectToDatabase();
    SendSQL($query);
	@row = FetchSQLData();

	if($row[0] == 0) {
		%rule_files = find_rules_files($dir);

    	foreach $key (keys %rule_files) {
        	process_inline_rule_file($key, $rule_files{$key}, $enable, $overwrite);
    	}
	}
}

# THIS SHOULD BE REMOVED BEFORE THE NEXT ISO RELEASE
sub check_for_updated_inline_table {
	my @row;
	my $query = "select * from snort_inline_rules limit 1";
	my $drop_query = "drop table snort_inline_rules";
	my $create_query = "create table snort_inline_rules (";
	$create_query .= "sid int not null,";
	$create_query .= "type varchar(20),";
	$create_query .= "category varchar(50),";
	$create_query .= "rule text,";
	$create_query .= "notes text,";
	$create_query .= "msg text,";
	$create_query .= "enabled tinyint UNSIGNED NOT NULL DEFAULT 0,";
	$create_query .= "noupdate tinyint unsigned not null default 0,";
	$create_query .= "lastupdate timestamp default 'current_timestamp'";
	$create_query .= ")";

	ConnectAdminToDatabase();
	SendSQL($query);

	@row = FetchSQLData();

	my $size = scalar(@row);

	if ($size < 9) {
		SendSQL($drop_query);
		SendSQL($create_query);
	}

}

# Returns an array of categories.
sub get_inline_categories {
	my @row;
	my @list;
	my $count = 0;

	my $query = "select distinct category from snort_inline_rules order by category";
	ConnectToDatabase();
    SendSQL($query);

	$list[$count++] = "All Categories";
    while(MoreSQLData()) {
    	@row = FetchSQLData();
		$list[$count++] = $row[0];
        }

        return @list;
}

sub process_inline_rule_file {
	my ($filename, $category, $enable, $overwrite_type) = @_;
	my $line;
	my $msg = "";
	my $sid;
	my $multi;
	my $rule = "";
	my $conn;
	my $enable_rule = 0;
	my $type = "";
	my $enable_string = "";
	my $max_sid = get_max_inline_sid(); 
	my %sid_list = get_inline_sid_list();
	my %no_overwrite = get_inline_no_overwrite_list();
	my %rule_types = get_inline_rule_type_list();

	# Sid numbers > 10000 will be given to any new rule that has a new sid number assigned.
	if($max_sid < 10000) { $max_sid = 10000; }
	
	if($enable eq "yes") {
		$enable_rule = 1;
		$enable_string = ", enabled=1";
	}
	
	ConnectToDatabase();

	my $query = "insert into snort_inline_rules (sid,type,category,rule,msg,enabled) values(?,?,?,?,?,?)";
    my $update_query = "update snort_inline_rules set type=?, msg=?, category=?, rule=? $enable_string where sid=?";


	$conn = prepare_query($query);
    my $conn_update = prepare_query($update_query);

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
		if ($line =~ /^drop/) {
            $type = "drop";
        } elsif ($line =~ /^reject/) {
            $type = "reject";
		} elsif ($line =~ /^sdrop/) {
            $type = "sdrop";
        } elsif ($line =~ /^alert/) {
        	$type = "alert";
        } else {
			error("No rule type found in rule: $line");
		}

		# Check if sid exists, if not then put one in rule
        if ($line =~ /\bsid\s*:\s*(\d+)\s*;/i) {
            $sid = $1;

            # Make sure the max sid number is not exceeded
            if($sid >= $max_sid) {
                $max_sid = $sid + 1;
            }
		} else {
			$sid = ++$max_sid;
			$rule = replace_sid($sid, $rule);
		}

        # Checks to see if rule should be overwritten.
		if(!defined $no_overwrite{$sid} && $sid_list{$sid} == $sid) {
            # Checks to see if the rule type needs to be modified.
			if($overwrite_type eq 'no' && defined $rule_types{$sid}) {
				$rule = modify_inline_rule($rule, $rule_types{$sid});
				$type = $rule_types{$sid};
			}

            $conn_update->execute($type,$msg,$category,$rule,$sid);

		} elsif (!defined $sid_list{$sid} ) {
			$conn->execute($sid,$type,$category,$rule,$msg,$enable_rule);
		}

		# If this is a new sid number then add it to the list
		if(!defined $sid_list{$sid} ) {
			$sid_list{$sid} = $sid;
		}

	}

	close(FILE);
	Disconnect_from_db();

}

# Modifies the type of an inline rule.
sub modify_inline_rule {
	my ($rule, $type) = @_;

	my $replaced_rule;
	my $parser = Walleye::Rule->new();
	my $remove_replace = "";

	my $parsed_rule = $parser->parse_rule($rule);
	$parser->make_generic($type, $parsed_rule);

	if($type eq "alert") {
		$parser->make_replace($type, $parsed_rule);
	} 

	$replaced_rule = $parser->build_rule($parsed_rule, $remove_replace);

	return $replaced_rule;	

}

# Need to read the conf file to see what rules need to be enabled
# Returns a hash containing the included rules files.
sub read_snort_inline_conf {
	my $snort_conf = "/etc/snort_inline/snort_inline.conf";
	my $line;
	my $rule_path;
	my $rule;
	my %conf;
	my $rule_file;

	open(CONF, "<$snort_conf") or error("Could not open file $snort_conf $!");

	while(defined($line = <CONF>)) {
		if ($line =~ /^var\s* RULE_PATH\s*(.*)\s*/i) {
            $rule_path = $1;

        }


		if($line  =~ /^include\s* \$RULE_PATH\/(.+?)\.rules/i) {
			$rule = $1;
			$rule_file = "$rule_path/$rule.rules";
			$conf{$rule_file} = $rule_file;
		}
	}
	
	return %conf;

}

# Removes all snort rules files and replaces them with the enabled rules
# stored in the database.
sub create_snort_inline_rules_files {
	my @categories = get_inline_categories();
	my $category;
	my %rule_files;
	my $query = "select * from snort_inline_rules where enabled=1";
	my $tmp_dir;
	my $tmp_file;
	my $key;
	my $dir = "/tmp";
	my @row;
	my $cmd;
	my $status;

	# Create temp directory
	$tmp_dir = create_temp_dir($dir);

	# Create hash of file names
	foreach $category (@categories) {
		if($category ne "All Categories") {
			$tmp_file = "$tmp_dir/$category.rules";
			$rule_files{$category} = IO::File->new(">> $tmp_file"); 
		}
	}

	ConnectToDatabase();
	SendSQL($query);

	while(MoreSQLData()) {
		@row = FetchSQLData();
		print {$rule_files{$row[2]}} "$row[3]\n";
	}

	# Remove existing snort rules files
	$cmd = "rm -rf /etc/snort_inline/rules/*.rules";
    $status = system("sudo $cmd");
    error("Could not run command: $cmd $?") unless $status == 0;

	# Copy new rules files to /etc/snort_inline/rules
	$cmd = "mv -f $tmp_dir/*.rules /etc/snort_inline/rules/";
	$status = system("sudo $cmd");
    error("Could not run command: $cmd $?") unless $status == 0;

	# Need to copy the config files to the rules directory
	#$cmd = "cp --reply=yes /etc/snort_inline/rules/*.config /etc/snort_inline/rules/.";
	#$status = system("sudo $cmd");
    #error("Could not run command: $cmd $?") unless $status == 0;

	# Remove temporary directory
	$cmd = "rm -rf $tmp_dir";
	$status = system("sudo $cmd");
    error("Could not run command: $cmd $?") unless $status == 0;

}

# This function will replace the previous included rules files
# with the new rules files.
sub create_snort_inline_conf {
	my @categories = get_inline_categories();
	my $category;
	my $tmp_file = "/tmp/snort_inline.conf";
	my $snort_conf = "/etc/snort_inline/snort_inline.conf";
	my $line;
	my $count = 0;
	my $cmd = "mv -f $tmp_file $snort_conf";
	my $status;

	open(TMP, ">$tmp_file") or error("Could not open file $tmp_file $!");
	open(CONF, "<$snort_conf") or error("Could not open file $snort_conf $!");

	while(defined($line = <CONF>)) {
		if($line =~ /^var RULE_PATH/) {
			print TMP "var RULE_PATH /etc/snort_inline/rules\n";
			next;
		}
		if($line  =~ /^include \$RULE_PATH\/.+?rules/i) {
			if($count == 0) {
				$count = 1;
				foreach $category (@categories) {
					if($category ne "All Categories") {
						print TMP "include \$RULE_PATH/$category.rules\n";
					}
				}
			}
			next;
		}
		print TMP "$line";
	}

	$status = system("sudo $cmd");
	error("Could not run command: $cmd $?") unless $status == 0;
	
}

sub restart_snort_inline {
	my $cmd = "/etc/init.d/hflow-snort_inline restart > /dev/null";
	my $status;

	$status = system("sudo $cmd");
	error("Could not run $cmd $?") unless $status == 0;
}


