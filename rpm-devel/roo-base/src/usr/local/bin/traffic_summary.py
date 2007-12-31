#!/usr/bin/python2
########################################
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
########################################

#  traffic_summary.py
#  Summarizes network traffic from honeywall snort pcap logs
# CHANGELOG:
#    v0.17:	- Further reordered report output
#		- Moved suspicious connections below scanned ports
#    v0.16:     - Reordered report output
#		- All Connections now disabled by default, --all enables
#               - Processing only shown when -v flag is passed
#    v0.15:     - Limit reporting to TCP,UDP,ICMP
#                 Other protocols were being introduced into the pcaps which were
#                 causing parse errors.
#    v0.14:     - Updated script for new file locations based on roo's changes.
#                 NOTE: NOW INCOMPATIBLE WITH EEYORE
#    v0.13:     - Script no longer blows up when encountering ipv6 traffic
#    v0.12:     - Fixed "All Connections" section (Bad key due to reordering)
#               - Added seperation whitespace between susp. and all conn.
#    v0.11:     - Process snort_inline-fast now
#               - Renamed "anomalous flows" -> "suspicious connections"
#               - Moved suspicious connections above all remote IPs
#    v0.10:     - Added Anomalous flows section (bytes > 1k or packets > 10)
#               - Added some snort reporting
#    v0.9:      - Corrected value returned by ntoa() for input value
#                 of '255.255.255.255'.
#    v0.8:      - Reverted filename format back to pcap.$DATE
#    v0.7:      - Took out compression/decompression calls
#               - Removes .argus file before exit
#               - Changed filename format
#    v0.6:      - Workaround pythons inability to call aton on broadcast
#    v0.5:      - Adds ability to uncompress compressed log files: requires 
#                 compress_logs.py script.
#                 Now reports log directories containing no log file.
#                 Now logs progress to system log.
#    v0.4:      - Fixed bug in sort routine which caused program termination
#    v0.3:      - Separately invoke Argus and Ra to avoid premature
#                 termination of Argus due to exhaustion of queue. Argus
#                 does not return a non-zero error code on such failures,
#                 which therefore presented troubleshooting challenges.
#                 It may be advisable to increase the queue size, by
#                 re-compiling server/ArgusUtil.c with a value of per-
#                 haps 1M for ArgusMaxListLength.
#               - Change method of identifying connections, to avoid
#                 duplicate counting of connections due to Argus
#                 report of ongoing connection activity.
#               - add -d option to specify DNS servers
#    v0.2:      - Add -t option
#               - Fix bug causing incomplete report of port data
#               - Add reporting of count of records processed
#               - Add -f option
#               - Add count of inbound and outbound connections
#               - Revise command options and arguments for consisitency
#                 with related programs
#               - Drop priority, to be nice to CPUs
#
# Note the date range is asymmetric: begin is inclusive but end is exclusive.
# Thus, the argument pair 20040101 20040201 copies data from 20040101 to
# 20040131, not 20040201. This usage facilitates creating date ranges
# that encompass entire months, since it's not necessary to specify
# the ending date of the last month, which might be the 28th, 29th, 30th,
# or 31st of that month.

VERSION = "0.17"
VERSION_DATE = "2005-07-20"

import glob
import time
import calendar
import getopt
import os
import os.path
import re
import socket
import struct
import string
import sys
import syslog
import time

TOP_N = 10
SNORT_TOP_N = 10
DEBUG = 0
TMPDIR = "/var/tmp"

def report(s):
    print s
    if outfile:
        print >>outfile, s

def stdout(s):
    print s
    sys.stdout.flush()
    if outfile:
        print >>outfile, s
    syslog.syslog(s)

def stderr(s):
    print >>sys.stderr, s
    syslog.syslog(s)

def process_print(s):
    if verbose == True:
        print s
    syslog.syslog(s)

def system(cmd):
    return os.system(cmd)

def aton(ip):
    if ip == "255.255.255.255": return 2147483647
    return struct.unpack('>L', socket.inet_aton(ip))[0]

def ntoa(ip):
    return socket.inet_ntoa(struct.pack('>L', ip))

def format_ip(ip):
    newip = "%d.%d.%d.%d" % (tuple(map(int, ip.split("."))))
    return "%15s" % newip

def is_dns(sip, sport, dip, dport):
    if not dnslist: return False
    for ip in dnslist:
        if ip == sip and sport == 53: return True
        if ip == dip and dport == 53: return True
    return False

def sep():
    report("========================================")

def title(s):
    line = ""
    report(s)
    for n in range (0,len(s)):
        line = "%s=" % line
    report(line)

def insert_comma(n):
    buffer = ""
    comma = ""
    while n:
        buffer =  n[-3:] + comma + buffer
        n = n[:-3]
        comma = ","
    return buffer

def by_ip_count(a, b):
    x = ip_connections[a]
    y = ip_connections[b]
    if cmp(x, y): return cmp(y, x)
    return cmp(a, b)

def by_port_count(a, b):
    x = port_connections[a]
    y = port_connections[b]
    if cmp(x, y): return cmp(y, x)
    return cmp(a, b)

def by_connection_key(a, b):
    a_proto, a_sip, a_sport, a_dip, a_dport = a.split(':')
    b_proto, b_sip, b_sport, b_dip, b_dport = b.split(':')
    a_sip_n = aton(a_sip)
    a_dip_n = aton(a_dip)
    b_sip_n = aton(b_sip)
    b_dip_n = aton(b_dip)
    a_type = "???"
    b_type = "???"
    if a_sip_n < home_lo or a_sip_n > home_hi:
        # source ip is external
        if a_dip_n >= home_lo and a_dip_n <= home_hi:
            # destination ip is internal
            a_type = "IN "
    if a_dip_n < home_lo or a_dip_n > home_hi:
        # destination is external
        if a_sip_n >= home_lo and a_sip_n <= home_hi:
            # source ip is internal
            a_type = "OUT"
    if b_sip_n < home_lo or b_sip_n > home_hi:
        # source ip is external
        if b_dip_n >= home_lo and b_dip_n <= home_hi:
            # destination ip is internal
            b_type = "IN "
    if b_dip_n < home_lo or b_dip_n > home_hi:
        # destination is external
        if b_sip_n >= home_lo and b_sip_n <= home_hi:
            # source ip is internal
            b_type = "OUT"
    if cmp(a_type, b_type): return cmp(a_type, b_type)
    if cmp(a_proto, b_proto): return cmp(a_proto, b_proto)
    if cmp(a_sip_n, b_sip_n): return cmp(a_sip_n, b_sip_n)
    if cmp(int(a_sport), int(b_sport)): return cmp(int(a_sport), int(b_sport))
    if cmp(a_dip_n, b_dip_n): return cmp(a_dip_n, b_dip_n)
    return cmp(int(a_dport), int(b_dport))

def usage():
    stderr("""%s version %s(%s)
Usage: %s [flags] [ yyyymmdd [ yyyymmdd ] ]

Flags:
  -f file               Send output to file in addition to stdout
  -d dns1,dns2,...      IP addresses of DNS servers, xxx.xxx.xxx.xxx
  -t n                  Report n preceding days
  -v			Verbose output
  --all	                Enable all connections report
  --honeynet x.x.x.x/n  Use specified CIDR style network for homenet
  --help                Print usage information

The options specify the begin date (inclusive) and end date (ex-
clusive) for processing. For instance, specifying "20040701
20040704" causes the program to process three days of data: 
20040701, 20040702, and 20040703. 

Specifying neither arguments nor a -t option causes the program to
report yesterday's data. You should not specify both the -t option
and one or more arguments.

Specifying one or more DNS server IP addresses causes related traffic
to be omitted from the reports.
""" % ("traffic_summary.py", VERSION, VERSION_DATE, os.path.basename(sys.argv[0])))


############# Begin snort functions

def get_snort_current(snort_fast_filename):
    curr_file = open(snort_fast_filename, 'r')
    count = 0
    while 1:
        line = curr_file.readline()
        if not line: break
        match = SNORT_RE.match(line)
        if not match:
            print >>sys.stderr, 'Unmatched Snort alert:', line.rstrip()
            sys.exit(1)
        sid, desc = match.group('sid', 'desc')
        key = sid + '|' + desc
        curr_hash[key] = 1 + curr_hash.get(key, 0)
        count = count + 1
    curr_file.close()
    return count

def gen_snort_report():
    retstr = ''
    keys = curr_hash.keys()
    keys.sort(lambda x,y: cmp(curr_hash[y], curr_hash[x]))
    sids = 0
    alerts = 0
    for key in keys:
        sids += 1
        alerts += curr_hash[key]
    report("")
    stdout("Total Snort SIDs:     %d" % (sids))
    stdout("Total Snort Alerts:   %d" % (alerts))
    report("")

    if (len(curr_hash)>SNORT_TOP_N):
        sep()
        title("Top %d Snort Alerts" % SNORT_TOP_N)
        report("")
        report("Count  SID    Alert Description")
        report("-----  ------ ---------------------------------")
        sids = 0
        for key in keys:
#            if sids == 0:
#                sep()
            sid, desc = key.split('|')
            if sids <= SNORT_TOP_N:
                report("%5d  %-5s  %s" % (curr_hash[key], sid, desc))
            sids += 1
        if sids == 0:
            report("Nothing to report")
        report("")

    sep()
    title("All Snort Alerts")
    report("")
    report("Count  SID    Alert Description")
    report("-----  ------ ---------------------------------")

    keys.sort(lambda x, y: cmp(int(x.split('|')[0]), int(y.split('|')[0])))
    sids = 0
    for key in keys:
        sid, desc = key.split('|')
        report("%5d  %-5s  %s" % (curr_hash[key], sid, desc))
        sids += 1
    if sids == 0:
        report("Nothing to report")
    return 0

############# End snort functions

begin_date  = None
end_date    = None
num_days    = None
home_net    = None
outfile     = None
outfilename = None
dnslist     = None
verbose	    = False
doall	    = False
files_found = 0

LOG_PATH = "/var/log"
PCAP_PATH = "/var/log/pcap"
SNORT_PATH = "/var/log/snort"
SNORT_INLINE_PATH = "/var/log/snort_inline"
#FILE_GLOB = "pcap.????????.??????????"
FILE_GLOB = "log"

# compress log program
#CLOG = "compress_logs.py %s*"

# uncompress log program
#UCLOG = "compress_logs.py -u %s*"

#10/20-00:47:04.016610  [**] [1:2351:8] NETBIOS DCERPC ISystemActivator path overflow attempt little endian [**] [Classification : Attempted Administrator Privilege Gain] [Priority: 1] {TCP} 80.132.165.141:51488 -> 199.107.97.131:135
#10/20-00:47:04.167536  [**] [111:2:1] (spp_stream4) possible EVASIVE RST detection [**] {TCP} 80.132.165.141:51488 -> 199.107.9 7.131:135 
#10/20-00:50:25.642396  [**] [1:469:3] ICMP PING NMAP [**] [Classification: Attempted Information Leak] [Priority: 2] {ICMP} 81.  226.218.113 -> 199.107.97.131 

SNORT_RE = re.compile('^(?P<timestamp>\S+)\s+\[\*\*\]\s+\[\d+:(?P<sid>\d+):(?P<rev>\d+)\] (?P<desc>.*) \[\*\*\].*$')

ips         = { }
ports       = { }
connections = { }
curr_hash   = { }

# Log activity
syslog.openlog("traffic-summary",0,syslog.LOG_ERR)

# Be kind to CPUs
os.nice(10)

try:
    opts, args = getopt.getopt(sys.argv[1:], "d:f:t:v", ["honeynet=", "help", "all"])
    for opt, value in opts:
        if opt == "-d":
            dnslist = value
        elif opt == "-f":
            outfilename = value
        elif opt == "-t":
            num_days = int(value)
        elif opt == "--help":
            sys.exit(1)
	elif opt == "-v":
	    verbose = True
        elif opt == "--honeynet":
            home_net = value
        elif opt == "--all":
            doall = True

    if len(args) > 2:
        raise RuntimeError("Incorrect number of arguments")
    if num_days and len(args) > 0:
        raise RuntimeError("Option -t conflicts with arguments")
    if num_days:
        now = time.gmtime()
        begin_date = time.gmtime(time.mktime(now) - num_days * 24*60*60)
        end_date   = time.gmtime(time.mktime(now))
    else:
        if len(args) == 0:
            begin_date = time.gmtime(time.time() - 24*60*60)
            end_date   = time.gmtime(time.time())
        if len(args) >= 1:
            yyyy = int(args[0][0:4])
            mm   = int(args[0][4:6])
            dd   = int(args[0][6:8])
            begin_date = time.mktime( [yyyy, mm, dd, 0, 0, 0, 0, 0, -1] )
            end_date   = begin_date + 24*60*60
            begin_date = time.gmtime(begin_date)
            end_date   = time.gmtime(end_date)
        if len(args) == 2:
            yyyy = int(args[1][0:4])
            mm   = int(args[1][4:6])
            dd   = int(args[1][6:8])
            end_date  = time.mktime( [yyyy, mm, dd, 0, 0, 0, 0, 0, -1] )
            end_date   = time.gmtime(end_date)

        num_days   = int((time.mktime(end_date) - time.mktime(begin_date)) / 24 / 60 / 60)

    if home_net == None:
        stderr("--honeynet is required")
        sys.exit(1)

    if dnslist:
        dnslist = dnslist.split(",")
        for ip in dnslist:
            match = re.compile("^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$")
            if not match:
                stderr("DNS list consists of a comma-separated list of IP addresses")
                sys.exit(1)

except:
    usage()
    sys.exit(1)

try:
    net, mask = home_net.split("/")
    mask = int(mask)
    home_lo = aton(net)
    home_hi = home_lo 
    if mask < 32:
        home_hi += pow(2, (32 - mask)) -1
    if DEBUG: stdout("home_lo= %s  home_hi=%s" % (ntoa(home_lo), ntoa(home_hi)))
except:
    stderr("--honeynet takes form x.x.x.x/n")
    usage()
    sys.exit(1) 

try:
    if outfilename:
        outfile = open(outfilename, "w")
except:
    stderr("Can't open output file %s" % outfilename)
    sys.exit(1)

stdout("- %s %s(%s)" % (os.path.basename(sys.argv[0]), VERSION, VERSION_DATE))
stdout("")
stdout("Report Settings:")
stdout("   - Honeynet:       %s" % (home_net))
stdout("   - Starting Date:  %s (inclusive)" % (time.strftime("%Y%m%d", begin_date)))
stdout("   - Ending Date:    %s (exclusive)" % (time.strftime("%Y%m%d", end_date  )))
stdout("   - Number of days: %s" % (num_days))
if outfilename:
    stdout("   - Output file:    %s" % (outfilename))
stdout("")

trecords = 0
srecords = 0

begin_stamp = (calendar.timegm(begin_date))
end_stamp   = (calendar.timegm(end_date))

dir_set = "%s/*" % (PCAP_PATH)
for dir in glob.glob(dir_set):
    if (int(os.path.basename(dir)) < begin_stamp):
       #stdout("Dir [%s] < [%s]: continuing." % (dir,begin_stamp))
       continue
    if (int(os.path.basename(dir)) >= end_stamp):
       #stdout("Dir [%s] >= [%s]: continuing." % (dir,end_stamp))
       continue

    process_print("Processing directory: %s" % (dir))
    file_set = "%s/%s" % (dir, FILE_GLOB)
    files_found = 0
    for file in glob.glob(file_set):
        frecords = 0
        process_print("    * Processing file: %s" % (file))
        if (os.path.getsize(file) <= 24):
		process_print("       - File size: %s bytes (empty pcap.. not processing)" % insert_comma(str(os.path.getsize(file))))
		process_print("")
                continue
        else:
		process_print("       - File size: %s bytes" % insert_comma(str(os.path.getsize(file))))
        files_found += 1
        try:
            if os.path.exists("%s.argus" % (file)):
                os.unlink("%s.argus" % (file))
            errno = os.system("argus -F /etc/argus_summary.conf -r %s -w %s.argus 1>/dev/null 2>/dev/null" %(file, file))
            if errno:
                raise RuntimeError, errno >> 8
            argusFields = "lasttime proto saddr dir daddr spkts dpkts sbytes dbytes status"
            pipe = os.popen("ra -Acnn -s %s -r %s.argus" %(argusFields, file))
        except:
            stderr("Argus or Ra execution error, ensure that the program files are in the PATH")
            sys.exit(1)
        while 1:
            #15 Feb 04 17:36:54 tcp 4.10.237.49.1063 -> 4.23.21.197.135 1 0 0 0 TIM

            line = pipe.readline()
            if not line: break
            frecords += 1
            trecords += 1
            #if trecords > 100: break
            words = line.split()
            proto  = words[4]
            #if proto in ["arp", "llc", "man", "ipv6"]: continue
            if proto in ["tcp", "udp", "icmp"]:
		    source = words[5]
		    flow   = words[6]
		    dest   = words[7]
		    packets = [int(words[8]), int(words[9])]
		    bytes   = [int(words[10]), int(words[11])]
		    status  = words[12]
		    source = source.split(".")
		    try:
			sip = "%s.%s.%s.%s" % (source[0], source[1], source[2], source[3])
		    except:
			stdout("Error: Unable to split source IP address!")
			stdout(line)
			sys.exit(1)
		    try:
			sport = int(source[4])
		    except:
			sport = 0
		    dest = dest.split(".")
		    dip = "%s.%s.%s.%s" % (dest[0], dest[1], dest[2], dest[3])
		    try:
			dport = int(dest[4])
		    except:
			dport = 0
		    if is_dns(sip, sport, dip, dport): continue
		    sip_n = aton(sip)
		    dip_n = aton(dip)
		    
		    if sip_n < home_lo or sip_n > home_hi:
			# source ip is external
			if ips.has_key(sip_n):
			    ips[sip_n][0] += packets[0] + packets[1]
			    ips[sip_n][1] += bytes[0]   + bytes[1]
			else:
			    ips[sip_n] =  [packets[0] + packets[1],
					   bytes[0]   + bytes[1]]

		    if dip_n < home_lo or dip_n > home_hi:
			# destination ip is external
			if ips.has_key(dip_n):
			    ips[dip_n][0] += packets[0] + packets[1]
			    ips[dip_n][1] += bytes[0]   + bytes[1]
			else:
			    ips[dip_n] =  [packets[0] + packets[1],
					   bytes[0]   + bytes[1]]

		    if dip_n >= home_lo and dip_n <= home_hi:
			# destination ip is internal
			if sip_n < home_lo or sip_n > home_hi:
			    # source ip is external
			    portkey = "%4s/%05d" % (proto, int(dport))
			    if ports.has_key(portkey):
				ports[portkey][0] += packets[0] + packets[1]
				ports[portkey][1] += bytes[0]   + bytes[1]  
			    else:
				ports[portkey] =  [packets[0] + packets[1],
						   bytes[0]   + bytes[1]]

		    key = ":".join( [proto, sip, str(sport), dip, str(dport)] )
		    if connections.has_key(key):
			pin, pout, bin, bout = connections[key]
		    else: 
			pin = pout = bin = bout = 0
		    pin  += packets[0]
		    pout += packets[1]
		    bin  += bytes[0]
		    bout += bytes[1]
		    connections[key] = (pin, pout, bin, bout)

        pipe.close()
        process_print("       - Records processed: %s" % insert_comma(str(frecords)))
        process_print("")

### Snort stuff
for n in range(0, num_days):
    today = time.gmtime(time.mktime(begin_date) + n * 24 * 60 * 60)
    file_dir = time.strftime("%Y%m%d", today)
    abs_dir = "%s/%s" % (SNORT_PATH, file_dir)
    abs2_dir = "%s/%s" % (SNORT_INLINE_PATH, file_dir)
    process_print("Processing directory: %s" % (abs_dir))
    file = "%s/snort_fast" % (abs_dir)
    if os.path.exists(file):
        process_print("    * Processing snort_fast alert file: %s" % (file))
        process_print("       - File size: %s bytes" % insert_comma(str(os.path.getsize(file))))
        count = get_snort_current(file)
        srecords = srecords + count
        process_print("       - Records processed: %s" % insert_comma(str(count)))
        process_print("")
    else:
        process_print("    * Processing snort_fast file: %s" % (file))
        process_print("       - File not found. Not processing.")
        process_print("")

    file = "%s/snort_inline-fast" % (abs2_dir)
    if os.path.exists(file):
        process_print("    * Processing snort_inline alert file: %s" % (file))
        process_print("       - File size: %s bytes" % insert_comma(str(os.path.getsize(file))))
        count = get_snort_current(file)
        srecords = srecords + count
        process_print("       - Records processed: %s" % insert_comma(str(count)))
        process_print("")
    else:
        process_print("    * Processing snort_inline alert file: %s" % (file))
        process_print("       - File not found. Not processing.")
        process_print("")

### end snort stuff

    if files_found <= 0:
        stdout("Warning: No files found in directory.")
        stderr("Warning: No files found in directory %s" % (file_dir))
#    os.system(CLOG % (file_dir))

    if os.path.exists("%s.argus" % (file)):
        os.unlink("%s.argus" % (file))

inbound  = { "count": 0,
             "pin":   0,
             "pout":  0,
             "bin":   0,
             "bout":  0,
           }
outbound = { "count": 0,
             "pin":   0,
             "pout":  0,
             "bin":   0,
             "bout":  0,
           }

stdout("")
stdout("Total pcap records processed: %s" % insert_comma(str(trecords)))
stdout("Total snort records processed: %s" % insert_comma(str(srecords)))
stdout("")
sep()
title("Summary")
stdout("")
stdout("Remote IP Count:      %s" % insert_comma(str(len(ips))))
stdout("Ports Scanned:        %s" % insert_comma(str(len(ports))))
stdout("")

keys = connections.keys()
for key in keys:
    proto, sip, sport, dip, dport = key.split(':')
    pin, pout, bin, bout = connections[key]
    if proto == 'tcp' or proto == 'udp':
        sip = aton(sip)
        dip = aton(dip)
        if sip >= home_lo and sip <= home_hi:
            # source ip is internal
            if dip < home_lo or dip > home_hi:
                # destination ip is external
                    outbound["count"] += 1
                    outbound["pin"  ] += pin  
                    outbound["pout" ] += pout
                    outbound["bin"  ] += bin  
                    outbound["bout" ] += bout  
        else:
            # source is external
            if dip >= home_lo and dip <= home_hi:
                # destination ip is internal
                    inbound["count"] += 1
                    inbound["pin"  ] += pin  
                    inbound["pout" ] += pout
                    inbound["bin"  ] += bin  
                    inbound["bout" ] += bout  

report("Connection           Packets    Packets    Bytes      Bytes")
report("Type          Count  In         Out        In         Out")
report("--------  ---------  ---------  ---------  ---------  ---------")
report("Inbound   %9d  %9d  %9d  %9d  %9d" % (
  inbound['count'], 
  inbound['pin'], 
  inbound['pout'], 
  inbound['bin'], 
  inbound['bout'])) 
report("Outbound  %9d  %9d  %9d  %9d  %9d" % (
  outbound['count'], 
  outbound['pout'], 
  outbound['pout'], 
  outbound['bout'], 
  outbound['bout']))

ip_connections = { }
for key in connections.keys():
    proto, sip, sport, dip, dport = key.split(':')
    sip = aton(sip)
    if sip < home_lo or sip > home_hi:
        # source ip is external
        ip_connections[sip] = ip_connections.get(sip, 0) + 1
    dip = aton(dip)
    if dip < home_lo or dip > home_hi:
        # destination is external
        ip_connections[dip] = ip_connections.get(dip, 0) + 1

if (len(curr_hash)>0):
    gen_snort_report()

report("")
sep()
title("Top %s Remote IPs:" % (TOP_N))
if len(ips) <= 0:
    report(" Nothing to report")
else:
    report("")
    report(" Remote IP        Packets    Bytes      Conns")
    report(" ---------------  ---------  ---------  ---------")
    keys = ips.keys()
    keys.sort(by_ip_count)
    n = 0
    for ip in keys:
        n += 1
        if n > TOP_N: break
        report(" %s  %9d  %9d  %9d" % (format_ip(ntoa(ip)), ips[ip][0], ips[ip][1], ip_connections[ip]))
report("")


port_connections = { }
for key in connections.keys():
    proto, sip, sport, dip, dport = key.split(':')
    dip = aton(dip)
    if dip >= home_lo and dip <= home_hi:
        # destination ip is internal
        portkey = "%4s/%05d" % (proto, int(dport))
        port_connections[portkey] = port_connections.get(portkey,0) + 1
    
sep()
title("Top %s Scanned Ports:" % (TOP_N))

if len(ports) <= 0:
    report(" Nothing to report")
else:
    report("")
    report(" Port       Packets    Bytes      Conns")
    report(" ---------  ---------  ---------  ---------")
    keys = ports.keys()
    keys.sort(by_port_count)
    n = 0
    for portkey in keys:
        n += 1
        if n > TOP_N: break
        proto, port = portkey.split("/")
        report("%s/%-5d  %9d  %9d  %9d" % (proto, int(port), ports[portkey][0], ports[portkey][1], port_connections[portkey]))
report("")

sep()
title("All Scanned Ports:")
if len(ports) <= 0:
    report(" Nothing to report")
else:
    report("")
    report(" Port       Packets    Bytes      Conns")
    report(" ---------  ---------  ---------  ---------")
    keys = ports.keys()
    keys.sort()
    for portkey in keys:
        proto, port = portkey.split("/")
        report("%s/%-5d  %9d  %9d  %9d" % (proto, int(port), ports[portkey][0], ports[portkey][1], port_connections[portkey]))

# sort the keys
keys = connections.keys()
keys.sort(by_connection_key)

report("")
sep()
title("Suspicious Connections:")
if len(connections) <= 0:
    report("Nothing to report")
else:
    report("")
    report("                                                            Packets    Packets    Bytes      Bytes")
    report("Type  Pro   Client                   Server                 In         Out        In         Out")
    report("----  ----  ---------------------    ---------------------  ---------  ---------  ---------  ---------")
for key in keys:
    proto, sip, sport, dip, dport = key.split(':')
    pin, pout, bin, bout = connections[key]
    type = "OTH"
    sip_n = aton(sip)
    dip_n = aton(dip)
    if sip_n < home_lo or sip_n > home_hi:
        # source ip is external
        if dip_n >= home_lo and dip_n <= home_hi:
            # destination ip is internal
            type = "IN "
    if dip_n < home_lo or dip_n > home_hi:
        # destination is external
        if sip_n >= home_lo and sip_n <= home_hi:
            # source ip is internal
            type = "OUT"
    if (pin > 10) or (pout > 10) or (bin > 1024) or (bout > 1024):
        report(" %3s  %4s  %15s:%-5s -> %15s:%-5s  %9d  %9d  %9d  %9d" % (type, proto, sip, sport, dip, dport, pin, pout, bin, bout))



if doall == True:
	report("")
	sep()
	title("All Remote IPs:")
	if len(ips) <= 0:
	    report(" Nothing to report")
	else:
	    report("")
	    report(" Remote IP        Packets    Bytes      Conns")
	    report(" ---------------  ---------  ---------  ---------")
	    keys = ips.keys()
	    keys.sort()
	    for ip in keys:
		report(" %s  %9d  %9d  %9d" % (format_ip(ntoa(ip)), ips[ip][0], ips[ip][1], ip_connections[ip]))
	report("")


	# sort the keys
	keys = connections.keys()
	keys.sort(by_connection_key)

	sep()
	title("All Connections:")
	if len(connections) <= 0:
	    report("Nothing to report")
	else:
	    report("")
	    report("                                                            Packets    Packets    Bytes      Bytes")
	    report("Type  Pro   Client                   Server                 In         Out        In         Out")
	    report("----  ----  ---------------------    ---------------------  ---------  ---------  ---------  ---------")
	for key in keys:
	    proto, sip, sport, dip, dport = key.split(':')
	    pin, pout, bin, bout = connections[key]
	    type = "OTH"
	    sip_n = aton(sip)
	    dip_n = aton(dip)
	    if sip_n < home_lo or sip_n > home_hi:
		# source ip is external
		if dip_n >= home_lo and dip_n <= home_hi:
		    # destination ip is internal
		    type = "IN "
	    if dip_n < home_lo or dip_n > home_hi:
		# destination is external
		if sip_n >= home_lo and sip_n <= home_hi:
		    # source ip is internal
		    type = "OUT"
	    report(" %3s  %4s  %15s:%5s -> %15s:%5s  %9d  %9d  %9d  %9d" % (type, proto, sip, sport, dip, dport, pin, pout, bin, bout))

if outfile:
    outfile.close()

sys.exit(0)
