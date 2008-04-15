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
my $sess_cookie = cookie(CGISESSID => $session->id);

#	Print header to create cookie
#	This is a hack and will be removed once it is decided
#	where the user will be sent after logging in.
#
#    print header( -TYPE => 'text/html',
#		  -EXPIRES => 'now',
#		  -cookie=>$sess_cookie
#		  );

# Check to see if the Honeywall has been configured
#check_honeywall_init();
my $tab = "sysAdminNav";
my @status = get_status();
my $title = $status[0];
if ($title eq "Documentation") {
   $tab = "docs";
}

display_header_page($session, $tab);
display_status();
display_footer_page();


sub get_status {

	my @status;

	my $action = "";

	if(defined param("act")) {
		$action = param("act");
	}

	
	@status = get_documentation();
	return @status;

}

sub display_status {
	my $list;
	my $title;
	my %pcap_files;
	my $file;

	my @status = get_status();
	my $act;

	$title = $status[0];
	$list = $status[1];

	if ($title eq "Documentation") {
		%pcap_files = get_document_files();
		$act = "16";
		$file = $status[2];
	}
	
	my $tt = Template->new( );
	
	my $input = 'templates/docs.htm';
	my $vars  = {
		health_table=>  Walleye::Admin::gen_honeywall_health(),
	       	file => $list,
	       	title => $title,
		   	pcap => \%pcap_files,
		   	act => $act,
			fileSelected => $file,		   
	};
	
	$tt->process($input, $vars)
	    || die $tt->error( );
}

sub get_document_files {
	my @dir;
	$dir[0]="/hw/docs";
	my %files;
	my $key;

	find sub {
			return unless -f;
			#$files{$File::Find::name} = $_;
			$files{$_} = ""
			}, @dir;

	#if(!defined %files) {
	if(keys(%files) == 0 ) {
		$files{"No documentation found"} = "";
	}

	return %files;

}

sub get_documentation {
	my @list;
	my $title = "Documentation";
	my @title_status;
	my $dir = "/hw/docs";
	my $file_name = param("file");
	my $file;
	
	if (defined $file_name && param("file") ne "No documents found") {
		$file = $dir . "/" . $file_name;
	}
	
	if(defined $file || $file ne "") {
		my $cmd = "sudo cat $file 2>&1 |";
		@list = get_command_output($cmd);	
	}

	$title_status[0] = $title;
	$title_status[1] = \@list;
	$title_status[2] = $file_name;

	return @title_status;


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
