#!/usr/bin/python
# Typical usage: nice ircdump -d x.x.x.x $* --PING --PONG --NICK --MODE --nnn --NOTICE
VERSION = "0.1"
VERSION_DATE = "2004-09-18"

#  ircdump.py
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

#  Snag IRC conversations from a pcap file or interface
#
#  Authors: Bill McCarty and Patrick McCarty
#
# CHANGELOG:
#    v0.1:      - Initial Release
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.

#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.

#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

import binascii
import getopt
import os
import re
import string
import sys

sys.stderr.write("- %s %s(%s)\n" % (os.path.basename(sys.argv[0]), VERSION, VERSION_DATE))

IP = re.compile("^(\d+).(\d+).(\d+).(\d+)$")

HEX = { '0': 0, '1':1, '2':2, '3':3, '4':4, '5':5, '6':6, '7':7, '8':8, '9':9,
        'a':10, 'b':11, 'c':12, 'd':13, 'e':14, 'f':15 }

lastline = ""

def usage():

    print """
Usage: %s [-c count] [-i eth] [-d ip] [-r file] [-p port] [--PING] [--PONG] [--JOIN] [--QUIT] [--MODE] [--PART] [--KICK] [--NOTICE] [--nnn]
    """ % (sys.argv[0])


def normalize_ip(ip):

    match = IP.match(ip)
    if match == None:
        sys.stderr.write("Bad IP address: %s\n" % (ip))
        return ip
    ip = map(string.atoi, match.groups())
    return "%03d.%03d.%03d.%03d" % (ip[0], ip[1], ip[2], ip[3])

CMD = re.compile("""
    ^(:[^ ]+\ )?    # prefix
    (\w+)?          # verb
    \ ?(.*)$     # arguments
    """, re.VERBOSE)

ARG1 = re.compile("""
    ^(\#\S+)\s:    # channel
    (.*)$          # message   
    """, re.VERBOSE)

ARG2 = re.compile("""
    ^(.*)\s*       # message   
    (\#\S+)\s*$    # channel
    """, re.VERBOSE)

VERB = re.compile("""
    ^\d+$
    """, re.VERBOSE)

def interpret(ts, sip, sport, dip, dport, cmd):

    global arghash

    #print "cmd=", cmd

    match = CMD.match(cmd)
    if match == None:
        sys.stderr.write("Bad command format: %s %s\n" % (ts, cmd))
        return
    ts = ts[:-7]
    (prefix, verb, arguments) = match.groups()

#   if prefix != None:
    if prefix != None and verb != "JOIN":
        prefix = shorten_prefix(prefix)
    if verb == None:
        sys.stderr.write("Bad command format: %s %s\n" % (ts, cmd))
        return

    numeric_verb = 0
    match = VERB.match(verb)
    if match != None: numeric_verb = 1

#   sys.stdout.write("Arguments: %s\n" % arguments)
#   sys.stdout.write("Using ARG1\n")
    match = ARG1.match(arguments)
    if match:
        (channel, message) = match.groups()
    else:
#       sys.stdout.write("Using ARG2\n")
        match = ARG2.match(arguments)
        if match:
            (message, channel) = match.groups()
#           sys.stdout.write("Channel=%s, Message=%s\n" % (channel, message))
        else:
#           sys.stdout.write("All args failed\n")
            channel = ""
            message = arguments

    if arghash.has_key("--nnn") and numeric_verb == 1:
#       sys.stderr.write("skip: %s %s:%s->%s:%s %s %s->%s\n" % (
#         ts, sip, sport, dip, dport, verb, prefix, arguments))
        sys.stderr.write("skip: %s %s %s %s: %s\n" % (
          ts, channel, verb, prefix, message))
    elif not arghash.has_key("--" + verb):
#       sys.stdout.write("%s %s:%s->%s:%s %s %s->%s\n" % (
#         ts, sip, sport, dip, dport, verb, prefix, arguments))
        sys.stdout.write("%s %s %s %s: %s\n" % (
          ts, channel, verb, prefix, message))
    else:
#       sys.stderr.write("skip: %s %s:%s->%s:%s %s %s->%s\n" % (
#         ts, sip, sport, dip, dport, verb, prefix, arguments))
        sys.stderr.write("skip: %s %s %s %s: %s\n" % (
          ts, channel, verb, prefix, message))

    #if   verb == "PRIVMSG": interpret_privmsg(ts, prefix, verb, arguments)
    #elif verb == "NOTICE":  interpret_privmsg(ts, prefix, verb, arguments)


def shorten_prefix(prefix):

    end  = len(prefix)
    bang = string.find(prefix, "!")
    if bang >= 0 and bang < end: end = bang
    at   = string.find(prefix, "@")
    if at  >= 0 and  at   < end: end = at

    return prefix[1:end]    

#def interpret_privmsg(ts, prefix, verb, arguments):
#
#    global lastline
#
#    if prefix != None: 
#        prefix = shorten_prefix(prefix)
#        line = "%s %s %s -> %s" % (ts, verb, prefix, arguments)
#    else:
#        line = "%s %s %s" % (ts, verb, arguments)
#    if line != lastline:
#        print line
#        lastline = line
#    return


if __name__ == "__main__":

    global arghash

    sys.stdout = os.fdopen(1, "w", 1)
    sys.stderr = os.fdopen(2, "w", 1)

    headline = re.compile("""
    ^
    (\d\d:\d\d:\d\d.\d\d\d\d\d\d)\s+        # ts, hh:mm:ss.ssssss
    \w+\s+                                  # protocol
    (\d+\.\d+\.\d+\.\d+)\.                  # source IP
    (\d+)\s+>\s+                            # source port
    (\d+\.\d+\.\d+\.\d+)\.                  # destination IP
    (\d+):                                  # destination port
    """, re.VERBOSE)

    bodyline = re.compile("""
    ^\s*
    0x(\w{4}):                             # offset (hex)
    \s+(.{39}).*$                          # hex contents
    """, re.VERBOSE)


    try:
        args, tail = getopt.getopt(sys.argv[1:], "c:d:i:p:r:",
          [ "PING", "PONG", "NICK", "JOIN", "QUIT", "MODE", "PART", "KICK", "NOTICE", "nnn" ])
    except:
        usage()
        sys.exit(1)

    arghash = { "-c":"0",
                "-d":"localhost",
                "-p":"6667" }

    for arg in args:
        key, value = arg
        arghash[key] = value
    #print "arghash=", arghash

    count = arghash["-c"]
    dip   = arghash["-d"]
    port  = arghash["-p"]

    if count == "0": count = ""
    else:            count = "-c %s" % (count)

    if arghash.has_key("-i"):
        cmd = "tcpdump -lnnX -s 1514 -i %s %s host %s and port %s" % (arghash["-i"], count, dip, port)
    elif arghash.has_key("-r"):
        cmd = "tcpdump -lnnX -s 1514 -r %s %s host %s and port %s" % (arghash["-r"], count, dip, port)
    else:  
        cmd = "tcpdump -lnnX -s 1514 -i eth0 %s host %s and port %s" % (count, dip, port)

    #print "cmd=", cmd
    pipe = os.popen(cmd, "r")
    line = pipe.readline()
    while line:

        #print line[:-1]
        match = headline.match(line)
        (ts, sip, sport, dip, dport) = match.groups()
        sip = normalize_ip(sip)
        dip = normalize_ip(dip)

        buffer = ""
        line = pipe.readline()

        while line:

            if not line:
                #print "head no match"
                break
            #print line[:-1]

            match = bodyline.match(line)
            if match == None:
                #print "body no match"
                break

            (offset, data) = match.groups()
            data = string.split(data, " ")
            data = string.join(data, "")
            #print "offset=", offset, "data=", data
            
            for i in range(0, len(data), 2):
                c1 = data[i]
                c2 = data[i+1]
                buffer = buffer + chr(HEX[c1] * 16 + HEX[c2])

            line = pipe.readline()

        byte = ord(buffer[0])
        ihl = 4 * (byte & 0x0f);

        offset = ord(buffer[ihl + 12])
        #print "ihl=", ihl, "offset=", offset
        offset = offset / 16
        #print "ihl=", ihl, "offset=", offset 
        offset = 4 * offset + ihl
        #print "ihl=", ihl, "offset=", offset, 
        #irccmd = buffer[offset:]
        buffer = buffer[offset:]
        irccmd = ""
        for c in buffer:
            if ord(c) >= ord(" ") or c == "\n": irccmd = irccmd + c
        irccmd = string.replace(irccmd,"\x00", "")
        irccmd = string.strip(irccmd)
        irccmds = string.split(irccmd, "\n")
        #print "irccmds=", irccmds
        for irccmd in irccmds:
            irccmd = string.strip(irccmd)
            if (len(irccmd) > 0):
                #print "DEBUG %s %s:%s->%s:%s %s" % (ts, sip, sport, dip, dport, irccmd)
                #print "%s %s->%s %s" % (ts[:-7], sip, dip, irccmd)
                interpret(ts, sip, sport, dip, dport, irccmd)

    pipe.close()

    sys.exit(0)
