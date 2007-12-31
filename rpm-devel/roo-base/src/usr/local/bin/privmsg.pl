#!/usr/bin/perl

#
#############################################
#
# Copyright (C) <2005> <The Honeynet Project>
#
# This program is free software; you can redistribute it and/or modify 
# it under the terms of the GNU General Public License as published by 
# the Free Software Foundation; either version 2 of the License, or (at 
# your option) any later version.
#
# This program is distributed in the hope that it will be useful, but 
# WITHOUT ANY WARRANTY; without even the implied warranty of 
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU 
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License 
# along with this program; if not, write to the Free Software 
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 
# USA
#
#############################################

# privmsg.pl, a quick colorized IRC PRIVMSG sniffer
# Max Vision - http://whitehats.com/ 
#
# June 11 - made this mess
# June 21 - added -o HTML output
# June 23 - added -c colorized output (was default)
#           now defaults to plaintext
#
# Hi - this obviously requires tcpdump but since it is
# present by default on most free OS, this shouldn't be
# a problem.  Note that this does not in any way deal
# with fragmentation or out-of-order packets. Have fun!
# http://www.tcpdump.org/ :)
# snort support may be added later - this was a quick hack!
#
# To record traffic for later analysis you could do:
#   `tcpdump -w bungtest23 -lnx -s 1024 port 6667`
# and read it back with:
#   `privmsg.pl -r bungtest23`

use Getopt::Std;
getopts("stoacr:l:", \%args);

print "// PRIVMSG colorized irc sniffer, ".
      "Max Vision http://whitehats.com/\n"; 

if (!defined $args{s} && !defined $args{r}) {
print <<EOF;
Usage: privmsg.pl [ -s | -r tcpdumpfile ] -a { -o | -t} { -l packetlimit }
        -s               = starting sniffing now
        -r <filename>    = parse an existing tcpdump/snort file
        -l <limit>       = how many *packets* to parse; omit to do all
        -a               = strip address portion from irc nicks
        -o               = HTML output (you might want to redirect this)
        -c               = colorized output
EOF
exit;}
if (defined $args{l}) { $limit = $args{l}; } else { $limit = 9999999; }

# default plaintext settings 
$arrow="-->"; $end=""; $normal=""; $face=""; 
$hred=""; $hyel=""; $hgrn=""; $hcyn="";

# html output
if (defined $args{o}) { $arrow="--&gt;"; $end="</font>"; $normal="<br>";
 $face = ' face="courier new"';    # you can set this to whatever or ""
 $hred="<font$face color=red>";
 $hyel="<font$face color=blue>";   # hey this looks better
 $hgrn="<font$face color=black>";  # here too
 $hcyn="<font$face color=purple>"; # ditto
}

# colorized output
if (defined $args{c}) { $normal = "\033[m";
$red="\033[0;31m"; $grn="\033[0;32m"; $yel="\033[0;33m";
$blu="\033[0;34m"; $mag="\033[0;35m"; $cyn="\033[0;36m";
$wht="\033[0;37m"; $hblk="\033[1;30m"; $hred="\033[1;31m";
$hgrn="\033[1;32m"; $hyel="\033[1;33m"; $hblu="\033[1;34m";
$hmag="\033[1;35m"; $hcyn="\033[1;36m"; $hwht="\033[1;37m";
$arrow='-->'; $end="";
}

$|=1;
if (defined $args{s}) { open (STDIN,"tcpdump -lnx -s 1024 port 6667|"); }
else { open (STDIN,"tcpdump -r $args{r} -lnx -s 1024 port 6667|")
       or die "Problem opening $args{r}."; }
while (<>) {
    if (/^\S/) {
        last unless $limit--;
        while ($packet=~/(:([\w@!#~\*\-\|\[\]\^\`\'\\{}. ]*PRIVMSG.*)|PRIVMSG ).+/g)  {
            $yum = $&;
            if ($yum =~ m/^PRIVMSG/) {
              $yum =~ s/PRIVMSG (.+)/\1/g;
              ($chan) = split(/ /,$yum);
              $yum =~ s/$chan (.+)/\1/g;
              if (defined $args{o}) { $chan=~s/</&lt;/g;$chan=~s/>/&gt;/g;
                                      $yum=~s/</&lt;/g;$yum=~s/>/&gt;/g; } # got efficiency?
              print "$hred$arrow $end$hyel$chan $end$hgrn$yum$end$normal\n";
            } else {
              ($addr) = split(/ /,$yum);
              $yum =~ s/.+PRIVMSG (.+)/\1/g;
              ($chan) = split(/ /,$yum);
              $yum =~ s/$chan :(.+)/\1/g;
              if (defined $args{o}) { $chan=~s/</&lt;/g;$chan=~s/>/&gt;/g;
                                      $yum=~s/</&lt;/g;$yum=~s/>/&gt;/g; } # got efficiency?
              if (defined $args{a}) { $addr=~s/:([^!]*)!.*/\1/g; } else { $addr=~s/:(.*)/\1/g; }
              print "$hyel$chan $end$hcyn$addr $end$hgrn$yum$end$normal\n";
            }
        }
        undef $client; undef $host; undef $packet;
        ($client,$host) = /(\d+\.\d+\.\d+\.\d+).+ > (\d+\.\d+\.\d+\.\d+)/
            if /P \d+:\d+\((\d+)\)/ && $1 > 0;
    }
    next unless $client && $host;
    s/\s+//;
    s/([0-9a-f]{2})\s?/chr(hex($1))/eg;
    tr/\x1F-\x7E\r\n//cd;
    $packet .= $_;
}
