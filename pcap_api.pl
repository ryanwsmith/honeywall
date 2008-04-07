#!/usr/bin/perl -T
# Copyright (C) 2005 The Trustees of Indiana University.  All rights reserved.
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

#----- pcap_api.pl:  Walleye's packet trace api for slow path access
#-----
#----- Version:  $Id: pcap_api.pl 5672 2008-03-24 01:43:35Z cviecco $
#-----
#----- Authors:  Edward Balas <ebalas@iu.edu>
#                Camilo Viecco <cviecco@indiana.edu>
#-----


use strict;
use 5.004;
use Socket;
use LWP::Simple qw(!head);
use CGI qw/:standard/;
use DBI;
use DBI qw(:sql_types);
use DBD::mysql;
use IO::Dir;
use File::Temp "tempfile";
use Scalar::Util qw(tainted);
use POSIX;
use Walleye::Util;
use Getopt::Std;

use sigtrap qw(die INT QUIT);


my $ENABLE_DISTRIBUTED=0;

my $pcap_dir     = "/var/log/pcap";
my $pcap_prefix  = "log";

my $pcap_api_bin = "/usr/sbin/pcap_api";
my $mergecap_bin = "/usr/sbin/mergecap";
my $rm_bin       = "/bin/rm";

##--------------------------------------------------
## usage
## prints the pcap_api help and exits
sub usage{
   print "pcap_api.pl : pcap data interface for the honeywall\n";
   print "\nUsage: pcap_api.pl [-M 1] [walleye-filter-expression] \n\n";
   print "The walleye expression filtering language is a subset of the\n ".
         "pcap filtering expression. Options include: \n\n".
         " sensor=sensor_id - the sensor id value of the honeywall of interest\n".
         " st=epoch         - start epoch of the pcap of interest\n".
         " et=epoch         - end epoch of the pcap of interest\n".
         " con_id=flow_id   - the flow_id of the walleye database flow of interest(this option overrrides all packet payload filter options)\n".
         " net=ip_address    - the ipv4 network of interest \n".
         " ip=ip_address     - the ipv4 address of interest \n".
         " sip=ip_address    - the source ipv4 address of interest \n".
         " dip=ip_address    - the destination ipv4 address of interest \n".
         " ip_proto=protocol - the number of the protocol of interest \n".
         " port=port_number  - the number of the port of interest \n".
         " sport=port_number - the number of the source port of interest \n".
         " dport=port_number - the number of the destination port of interest \n";
  exit(1);#-- if you need help.. you should not be expecting data
}


##--------------------------------------------------
## create_filter_bpf
## creates the bpf filter as an and or of the hash of arrays
## the nice thing is that its sintax can be changed rapidly

sub create_filter_bpf{
   #gets a filter hash and creates the appropiate tcp_dump filter
   my %fhash= @_;
   my $bpf_filter="";
   my $ip_addr;  
   my $a_size;
   my $i;
   my $fname;
   my $new_filter="";

   #next hash defines the allowed parameters and the prefix for 
   #them in the bpf
   my %known_filter_types=(
			  
			   "ip"       => "host ",
			   "net"      => "net ",

			   "sip"      => "src host ",
			   "dip"      => "dst host ",

			   "snet"     => "src net ",
			   "dnet"     => "dst net ",

			   
			   "ip_proto" => "ip proto ",

			   "port"     => "port ",
			   "sport"    => "src port ",
			   "dport"    => "dst port ",
			   
			   );

   my %known_filter_checks=(
			  
			   "ip"       => '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}',
			   "net"      => '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\/\d{1,2}',

			   "sip"      => '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}',
			   "dip"      => '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}',

			   "snet"     => '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\/\d{1,2}',
			   "dnet"     => '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\/\d{1,2}',

			   
			   "ip_proto" => '\d+',

			   "port"     => '\d+',
			   "sport"    => '\d+',
			   "dport"    => '\d+',
			   );
   
   #new section loop trough hash...
   for $fname (keys %known_filter_types){
       if(defined @{$fhash{$fname}}){
	   $a_size= scalar @{$fhash{$fname}};
	   if ($a_size>0)
	   {
	       $bpf_filter.="("; 
       #print("asize= $a_size\n");
       for($i=0;$i<$a_size-1;$i++){
	   $bpf_filter.=$known_filter_types{$fname};
	   #----- sanity check
	   if(!($fhash{$fname}[$i] =~ /^($known_filter_checks{$fname}$)$/)){
	       die "bogus input: $fname = ". $1." \n";
	   } 
	   $bpf_filter.=$1." or ";
       }                                                                         
       $bpf_filter.=$known_filter_types{$fname};
       #----- sanity check
       if(!($fhash{$fname}[$i] =~ /^($known_filter_checks{$fname})$/)){
	   die "bogus input: $fname = ". $1." \n";
       } 
       $bpf_filter.=$1.") and ";
   }
} #end if defined

}




#instead of a quad chop will use regular expressions...
#but hold the elimination until after noise removal to do it only once
$new_filter=$bpf_filter; 

#there is a caveat when using not tcp or udp
#there is no concept of port so I need to remove them from the filter
#It is clearer here as a regular exp than to add logic to the nice loop above
if(not (($new_filter =~/ip proto 6/) || ($new_filter=~/ip proto 17/))){
#now remove src and dst
$new_filter =~ s/\(\s*dst\s+port\s+\d+\s+or\s+dst\s+port\s+\d+\s*\)//g;
$new_filter =~ s/\(\s*src\s+port\s+\d+\s+or\s+src\s+port\s+\d+\s*\)//g;
$new_filter =~ s/\(\s*src\s+port\s+\d+\s*\)//g;
$new_filter =~ s/\(\s*dst\s+port\s+\d+\s*\)//g;
$new_filter =~ s/\(\s*port\s+\d+\s*\)//g;
}

#remove duplicated 'and'
$new_filter =~ s/and\s+(and\s+)*/and /g;

#remove trailing 'and' if found.. (more elegant that the quad chop)
$new_filter =~ s/and\s*$//;

#restore the filter...
$bpf_filter=$new_filter;

#warn("filt=$bpf_filter \n");
   return $bpf_filter;
}

##------------------------------------------------------
## file selector.. 
## receives the hash and creates an array with the names
## of the files that need to go to mergecap
sub file_selector{
    my %fhash= @_;
    
    my $pcap_directory  = $pcap_dir;
    my $file_prefix     = $pcap_prefix;
    my $start_time      = $fhash{start_time}[0];
    my $end_time        = $fhash{end_time}[0];
    my $dirlist;
    my @file;
    my @total_file;
    my $line;
    my $filename;
    my @sensor_dir;
    
    #----------error check...
    #recover from easy errors
    if (not defined $start_time){
	$start_time=0;
    }
    if( not defined $end_time){
	$end_time= 4000000000;
    }
    #bail out on unrecoverable errors
    if (not defined $pcap_directory | not defined $file_prefix){
	die "filter cannot run without directory or prefix information ";
    }
    

    
    my $pcap_dir  = new IO::Dir("$pcap_directory");
    my $start_dir;
    my $start_name;
    my $log_file;
    my $log_name;
    my $temp_name;
    my $sensor;
    my $last_dir_time=0;
    my $last_dir_count=100;
    my $file_count=0;

    if (defined $fhash{sensor}){
	print STDERR "sensor='$fhash{sensor}[0]'\n";
        #verify existence of directory
	foreach $sensor (@{$fhash{sensor}}){
	   if ($sensor =~/(\d+)/){
              $sensor=$1;
              $filename=$pcap_directory."/sensor_".$sensor;
              print STDERR "sens_dir= $filename\n";
              push(@sensor_dir,$filename);
           }
        }

	
    }
    else{
	#warn  "sensor not defined (OK)\n";
        #get all sensor data dirs..
	#push(@sensor_dir,$pcap_directory);
        my $pcap_dir2  = new IO::Dir("$pcap_directory");
        if (tainted($pcap_dir2)){ warn "pcapdir2 =$pcap_dir2 tainted!!";};
	#if (tainted($pcap_)){ warn "pcapdir2 =$pcap_dir2 tainted!!";};
        if (not defined ($pcap_dir2)){ warn "pcapdir2 not defined pcapdirec=$pcap_directory!!";};

	while (defined ($filename = $pcap_dir2->read)){
            if($filename =~ /^sensor_(\d+)$/){
		$filename="sensor_".$1;
                if (tainted($filename)){ warn "filename =$filename tainted!!";};

		$filename=$pcap_directory."/".$filename;
		#push(@sensor_dir,$filename);
		#print STDERR "(OK)extra dir= $filename\n";

                #if (tainted($filename)){ warn "filename =$filename tainted!!";};
		push(@sensor_dir,$filename); 
            }
        }
        #if no sensors... add root dir
        if (0==(scalar @sensor_dir)){
            push(@sensor_dir,$pcap_directory);
        }
    }
    ###while we decide will make this thing go to one..
    #@sensor_dir[0]="$pcap_directory";    

    foreach $pcap_directory (@sensor_dir){
        $pcap_dir=new IO::Dir("$pcap_directory");
	if (not defined $pcap_dir){
	  next;
        }
        my @dir_arr;
        while(defined($start_name = $pcap_dir->read)){
            if($start_name =~/^(\d+)$/){
	       $start_name = $1;
               push(@dir_arr,$start_name);
            }else{
              next;
            }       
        }
        foreach $start_name (sort @dir_arr){
           
	    #----- if the dir was created after the point in time that our flow stopped
	    #----- then this is not a directory we care about;
	    #next if($start_name > $end_time);
 
            #warn "in dir_find start_time=$start_time start_name=$start_name last_dir=$last_dir_time\n";
            ###-------
            # test for deletion of od files
            if (($start_name>$start_time) and ($last_dir_time<$start_time)){
            #if($start_name>$start_time){
                #warn "transition place. scalfile=".scalar@file."last_dir_count=$last_dir_count ldt=$last_dir_time st=$start_time\n";
                #die;
                #delete all but the last contents
                @file=reverse(@file);
                while(scalar(@file)>$last_dir_count){
                     pop(@file);
                }
               #warn "transition place. scalfile=".scalar@file."last_dir_count=$last_dir_count\n";
               #print(@file);
               #print("\n\n");
            }
            ####----
            $last_dir_time=$start_name;
            #----- if the dir was created after the point in time that our flow stopped
            #----- then this is not a directory we care about;
            next if($start_name > $end_time);



	    $start_dir = new IO::Dir("$pcap_directory/$start_name");
 
            $file_count=0;	
	    while(defined($log_name = $start_dir->read)){
                #check for correct name in file
	        if($log_name =~ /^(log\d*?)$/){
	          $log_name = $1;
	        }else{
	          next;
                }


	        #---- whoah its really bad to use creation time of the logs
	        #---- cause if they are moved we will have troubles.

	        $filename = "$pcap_directory/$start_name/$log_name";

	        #--- if the last time the file was modified was before the
	        #--- start of the flow dont bother looking
	        next if((stat($filename))[9]  < $start_time);
               
                #-- if size is 0 do not add to list as would generate error
                next if((stat($filename))[7]  == 0);

	        push(@file,$filename);
	        $file_count+=1;

	    }
            if ($file_count>0) {$last_dir_count=$file_count};
            #$last_dir_time=$start_name;	
        }
        while(scalar(@file)>0){
               push(@total_file, pop(@file));
              }


    }#end for each pcapdir

    return @total_file;
}

sub recursive_mergefile{
    #gets directory name and numfiles in dir
    #returns directory_name

    my $source_pcap_directory = shift;
    my $number_files_in_dir =shift;
    my $mergecap_limit=50;

    #if $number of files<mercap limit
    #     return 
    #else
    #  create subdir
    #  create files in subdir()
    #  delete old subdir files
    #  call recurive merge in the new subdir
    #  
    if ($number_files_in_dir<$mergecap_limit){
        ## actually might do some work before!!
        ##
	##return $source_pcap_directory;

       my $start_dir = new IO::Dir("$source_pcap_directory");
       my $file_list='';
       my $filename;
       while(defined($filename = $start_dir->read)){
            if($filename =~/^(\d+)$/){
               $filename = $1;
               $file_list.="$source_pcap_directory"."/".$filename." ";
            }else{
              next;
            }
       }
       
       0== system("$mergecap_bin -w - $file_list")  or die "'mergecap failed: $mergecap_bin -w - $file_list'\n";


       return $source_pcap_directory;
    }
    else{
       my $tmpdir = File::Temp::tempdir(DIR=>"/var/www/html/walleye/images/",CLEANUP=>1);
       #my $tmpdir = File::Temp::tempdir(DIR=>"/var/www/html/walleye/images/");

       my $num_new_files=1;
       my $start_dir = new IO::Dir("$source_pcap_directory");

       my $current_files=0;
       my $file_list='';
       my $outfilename;
       my $filename;

       while(defined($filename = $start_dir->read)){
            if($filename =~/^(\d+)$/){
               $filename = $1;
            }else{
              next;
            }
           if ($current_files+1<$mergecap_limit){
		$file_list .=$source_pcap_directory."/".$filename." ";
                $current_files++;
           }
           else
           {
             $outfilename=$tmpdir."/".$num_new_files;
             if(tainted($outfilename)){warn "outfilename $outfilename tainted";}
             if(tainted($file_list)){warn "file_list $file_list tainted";}

             0== system("$mergecap_bin -w $outfilename $file_list")  or die "'mergecap failed: $mergecap_bin -w $outfilename $file_list'\n";

             $num_new_files++;
             #setup conditions for iteration
             $current_files=1;
             $file_list=$source_pcap_directory."/".$filename." ";
           }
       }
       #--process last list!!!
       if($current_files>0){
            $outfilename=$tmpdir."/".$num_new_files;
            0== system("$mergecap_bin -w $outfilename $file_list")  or die "'mergecap failed: $mergecap_bin -w $outfilename $file_list'\n";
       }
       
       #empty old subdir
       my $remove_command="/bin/rm -rf $source_pcap_directory"."/* ";
       #warn("$remove_command");
       system("$remove_command");
       #call recursive
       return recursive_mergefile($tmpdir,$num_new_files);

    }
   
}

#combines the previous two subs and uses system to connect
#mergecap and capfil

sub create_pcap{
    my $nomime = shift;
    my %filter_hash= @_;
    my $start_time=$filter_hash{start_time}[0];
    my $end_time  =$filter_hash{end_time}[0];
    my @file;
    my $filter;
    my $filename;
    my $file_list;
    my $outfilename="new_file";

    my $x=0;
    #----------error check...
    #recover from easy errors
    if (not defined $start_time){
     $start_time=0;
      }
    if( not defined $end_time){
      $end_time= 4000000000;
    }


    $filter=create_filter_bpf(%filter_hash);
    @file=file_selector(%filter_hash);
    for $filename (@file){
      $file_list.=$filename." ";
    }
   
    $ENV{"PATH"} = ""; 

    #--- might be nice to make file name based on filter text someday
    my $dlname .= time().".pcap";

    if($nomime){
      #--- dont print the mime header if nomime is set
    }else{
      print header(
             	-TYPE => 'application/x-pcap',
                -EXPIRES => 'now',
                -ATTACHMENT => $dlname
                );
    }	

    if(scalar(@file) == 0){
        #-------There are no selected files
        ###
        warn ("No files found by the selector");
        die;
    }
    #check for empty files!!!
 
    if(scalar(@file) == 1){
	#---- flow is within one pcap file

	if(tainted($file[0])){
		warn "$file[0] tainted\n";
	}
	if(tainted($start_time)){warn "$start_time tainted";}
	if(tainted($end_time)){warn "$end_time tainted";}
    	if(tainted($filter)){warn "$filter tainted";}

        #die "test camilo just one\n";	

	system("$pcap_api_bin -r $file[0] -s $start_time -e $end_time -w - -f '$filter'  ");
    }else{
	#--- we have multiple files we will need to merge
	#next line creates the temp dir and instructs perl to erase everything when we are done
	my $tmpdir = File::Temp::tempdir(DIR=>"/var/www/html/walleye/images/",CLEANUP=>1);
	$x = 0;
	$file_list = "";
	#---- grep each file
	foreach (@file){
	    $filename = $tmpdir."/".$x++;
	    $file_list .= $filename." ";
 
            #next is for debugging
            #warn "$filename \n";
	    
	    if(tainted($filename)){warn "$filename tainted\n";}
	    if(tainted($_)){warn "$_ tainted";}
	    if(tainted($start_time)){warn "$start_time tainted";}
	    if(tainted($end_time)){warn "$end_time tainted";}
	    if(tainted($filter)){warn "$filter tainted";}

	    0== system("$pcap_api_bin -r $_ -s $start_time -e $end_time -w $filename  -f '$filter' ")
             or die "pcap_api_bin failed :  $pcap_api_bin -r $_ -s $start_time -e $end_time -w $filename  -f '$filter' ";
	}
        #die "camilo test die";

	#--- merge files
        my $mergecap_limit=80;
        if (scalar(@file)<$mergecap_limit){
	  #there is some weirdness with mergecap, depending on what version you got
	  #output to stdout is either - or '', newer versions use -
	  0== system("$mergecap_bin -w - $file_list")  or die "'mergecap failed: $mergecap_bin -w - $file_list'\n"; 
        }
        else{
          #group by smaller.. then collapse the other.. Not the best cure.. but better than what we have now..
          #warn "to large, bailing out";
          my $newdir=recursive_mergefile($tmpdir,$x);
          #warn("$newdir\n");
          #die;
        }

	#no need to erase now... left here for test purposes only..
	#system("rm -rf $tmpdir");

    }
    
}

sub hflow_lookup_flow{
    #----- what do we do about flows that dont really have a sense of port?

    my $sensor = shift;
    my $con_id = shift;

    my %results;

    #my $query = "select start_sec, end_sec, ip_proto, src_ip, src_port, dst_ip, dst_port from argus where sensor_id = ? and argus_id = ?";
    my $query = "select src_start_sec, GREATEST(src_end_sec,dst_end_sec), ip_proto, src_ip, src_port, dst_ip, dst_port,src_icmp_packets,dst_icmp_packets from flow where sensor_id = ? and flow_id = ?";


    my $sql = $Walleye::Util::dbh->prepare($query);

    $sql->execute($sensor,$con_id) or die;

    my $ref = $sql->fetchrow_arrayref();

    $results{"start_time"}[0] = $$ref[0];
    $results{"end_time"}[0]   = $$ref[1];
    $results{"ip_proto"}[0]   = $$ref[2];
    $results{"sip"}[0]        = inet_ntoa(pack('N',$$ref[3]));
    $results{"sip"}[1]        = inet_ntoa(pack('N',$$ref[5]));
    $results{"sport"}[0]      = $$ref[4];
    $results{"sport"}[1]      = $$ref[6];

    $results{"dip"}[0]        = inet_ntoa(pack('N',$$ref[5]));
    $results{"dip"}[1]        = inet_ntoa(pack('N',$$ref[3]));
    $results{"dport"}[0]      = $$ref[6];
    $results{"dport"}[1]      = $$ref[4];

    return %results;
}

sub is_sensor_remote{
	my $sensor_id = shift;
	my $was_remote=0;

	my $access_location=0;	

        if ($ENABLE_DISTRIBUTED !=1){
	    return 0;
        }

	my $query= "SELECT access_via from sensor where sensor_id=$sensor_id";
	my $sql = $Walleye::Util::dbh->prepare($query);
	
	$sql->execute() or die "Cannot find access_location";

	my @row= $sql->fetchrow_array();
	#die ;
	
	$access_location=$row[0];

	if ($access_location!=0){
		$was_remote=1;
	}
	#print STDERR  "was remote $was_remote ";
	return $was_remote;	
}

sub do_remote_sensor_connection($$$){
	my ($nomime,$sensor_id,$con_id) =@_;
	my $response_code;
        my $login;
        my $passwd;
	my $url;
	my @row;
	my $location;

	#use LWP::Simple qw(!head);


        my $query= "SELECT access_via,login,passwd from sensor where sensor_id=$sensor_id";
        my $sql = $Walleye::Util::dbh->prepare($query);

        $sql->execute() or die "Cannot find access_location";

        if(@row= $sql->fetchrow_array()){

           $location=$row[0];
	   $login=$row[1];
	   $passwd=$row[2];

           $url  ="https://".inet_ntoa(pack('N',$location))."/pcap_api.pl?";
	   $url .="&sensor=$sensor_id&con_id=$con_id";
	   $url .="&userName=".$login."&password=".$passwd;
	   if($nomime){
     	    #--- dont print the mime header if nomime is set
   		 }
	   else{
     		 print header(
                -TYPE => 'application/x-pcap',
                -EXPIRES => 'now',
                -ATTACHMENT => 'requested.pcap'
                );
	    }


	   $response_code =LWP::Simple::getprint($url);
	   #print STDERR "URL= $url\n";
	   die "Couldn't get $url \n" unless ($response_code==RC_OK);   
	}
	else{
	   die "Could not find any sensor,error?"
	}
	
}

sub main {
   my %filter_hash;
   my %opt;


  my $nomime;

  getopts("hM",\%opt);

  if (defined $opt{h}){
    usage();
    exit(1);
  }

  if($opt{M}){

    $nomime = 1;
  }
#----- check the user (Begin Fix Bug 453)
   else{
     my $session = Walleye::Login::validate_user();
     my $role    = $session->param("role");
     my $sess_cookie = cookie(CGISESSID => $session->id);
  } 
#----- (End Fix Bug 453)
   
   Walleye::Util::setup(1,0,0);
  
   my $cgi = new CGI;

   #----- db tie in -----
   my $sensor;
   my $con_id;

   if(defined($cgi->param('sensor')) && $cgi->param('sensor') =~ /^(\d+)$/){
	$sensor = $1;
        #$filter_hash{"sensor"}[0] = $sensor ;
        @{$filter_hash{"sensor"}} = $cgi->param('sensor');

   }
   if(defined($cgi->param('con_id')) && $cgi->param('con_id') =~ /^(\d+)$/){
        $con_id = $1;
   }

   #if remoste sensor & con_id is given...
  

   if(defined($sensor) && defined($con_id)){
     #check if sensor is remote:
     if (is_sensor_remote($sensor) == 1){
		#create remote
		do_remote_sensor_connection($nomime,$sensor,$con_id);
		#die "tried to execute remote connection";
     }
     else{
       	create_pcap($nomime,hflow_lookup_flow($sensor,$con_id));
     }
     return;
	
   }
   if ($con_id){
	#means an error... return empty (need to find better way to mark the error..);
        return;
   }

   

   #--- start and stop need to be untainted
   if(defined($cgi->param('st')) && $cgi->param('st') =~/^(\d+)$/){   
       
       $filter_hash{"start_time"}[0] = $1;
   }

   if(defined($cgi->param('et')) && $cgi->param('et') =~/^(\d+)$/){   
       $filter_hash{"end_time"}[0] = $1 ;
   }


   #--- random lookup checks are done in create_filter_bpf
   if($cgi->param('ip') && $cgi->param('ip') ne "undef"){   
       @{$filter_hash{"ip"}} = $cgi->param('ip');
   }

   if($cgi->param('sip') && $cgi->param('sip') ne "undef"){
       @{$filter_hash{"sip"}} = $cgi->param('sip');
   }

   if($cgi->param('dip') && $cgi->param('dip') ne "undef"){
       @{$filter_hash{"dip"}} = $cgi->param('dip');	
   }

   if($cgi->param('net') && $cgi->param('net') ne "undef"){
       @{$filter_hash{"net"}} = $cgi->param('net');
   }

   if($cgi->param('snet')  && $cgi->param('snet') ne "undef"){
        @{$filter_hash{"snet"}} = $cgi->param('snet') ;
   }

   if($cgi->param('dnet') && $cgi->param('dnet') ne "undef"){
       @{$filter_hash{"dnet"}} = $cgi->param('dnet');
   }

   if($cgi->param('ip_proto') && $cgi->param('ip_proto') ne "undef"){
       @{$filter_hash{"ip_proto"}} = $cgi->param('ip_proto');
   }

   if($cgi->param('port') && $cgi->param('port') ne "undef"){
       @{$filter_hash{"port"}} = $cgi->param('port');
   }
   
   if($cgi->param('sport') && $cgi->param('sport') ne "undef"){
       @{$filter_hash{"sport"}} = $cgi->param('sport');
   }

   if($cgi->param('dport') && $cgi->param('dport') ne "undef"){
       @{$filter_hash{"dport"}} = $cgi->param('dport');
   } 

   
  
   create_pcap($nomime,%filter_hash);

}

main();
