#!/usr/bin/python

import socket
import struct

def getIpListFromHoneypotsVariableFile(p_filename):
	"""Given a space separated list of ip addresses, create a list""" 
	l_fh = file(p_filename)
	l_list = [] 
	for l_line in l_fh:
		l_sLine = l_line.strip()

		#ignore comments
		if l_sLine.startswith('#'):
			continue
		l_toks = l_sLine.split()
		l_list.extend(l_toks)
	l_fh.close()
	return l_list

def getIpListFromFile(p_filename):
	"""Given a file with either an ip or a network address in CIDR notation per line, returns a tuple (iplist, networklist)"""
	l_fh = file(p_filename)
	l_ipList = []
	l_netList = []
	
	for l_line in l_fh:
		l_sLine = l_line.strip()

		#ignore comments
		if len(l_sLine) == 0 or l_sLine.startswith('#'):
			continue
		
		l_toks = l_sLine.split('/')
		if (len(l_toks) == 1):
			l_ipList.append(l_sLine)
		else:
			#we have a network i.e. 10.10.10.10/24
			l_netList.append(l_sLine)

	l_fh.close()

	if len(l_ipList) == 0:
		l_ipList = None
	if len(l_netList) == 0:
		l_netList = None

	return l_ipList, l_netList

def createHoneypotBpfFromList(p_hpotList):
	"""Given a list of honeypot ip addresses, creates a filter that will match any packet to or from the group of honeypots in the list.  Returns the bpf filter in the form of a string."""
	l_host = None
	if p_hpotList:
		l_hostStart = 'host ('
		l_ipList = ' or '.join(p_hpotList)
		l_host = "%s %s )" % (l_hostStart, l_ipList)
	return l_host

def createBpfFromList(p_ipList, p_networkList):
	"""Given a list of ip addresses and a list of networks, creates a filter that will match any packet to or from the ips or networks in the lists.  Returns the bpf filter in the form of a string."""
	l_host = None
	l_net = None
	l_combo = None
	
	if p_ipList:
		l_hostStart = 'host ('
		l_ipList = ' or '.join(p_ipList)
		l_host = "%s %s )" % (l_hostStart, l_ipList)

	if p_networkList:
		l_netStart = 'net ('
		l_netList = ' or '.join(p_networkList)
		l_net = "%s %s )" % (l_netStart, l_netList)

	if l_host and l_net:
		l_combo = "%s or %s" % (l_host, l_net)
	elif l_host:
		l_combo = "%s" % l_host
	elif l_net:
		l_combo = "%s" % l_net

	return l_combo

def main(p_hpotFilename, p_blackList, p_whiteList):
	"""Creates a bpf filter that matches all the honeypots in the file and excludes the ip addresses or networks in the blacklist.  The filter is printed to stdout so that shell scripts can grab it."""

	l_hpotList = getIpListFromHoneypotsVariableFile(p_hpotFilename)
	l_hpotFilter = createHoneypotBpfFromList(l_hpotList)
	l_blackListFilter = None
	l_whiteListFilter = None
	
	if (p_blackList and os.path.exists(p_blackList)):
		l_ipList, l_netList = getIpListFromFile(p_blackList)
		l_blackListFilter = createBpfFromList(l_ipList, l_netList)

	if (p_whiteList and os.path.exists(p_whiteList)):
		l_whiteIpList, l_whiteNetList = getIpListFromFile(p_whiteList)
		l_whiteListFilter = createBpfFromList(l_whiteIpList, 
                                                   l_whiteNetList)
	if l_blackListFilter and l_whiteListFilter:
		l_filter = "(%s) and not ( (%s) or (%s) )" % (l_hpotFilter, l_blackListFilter, l_whiteListFilter)
	elif l_blackListFilter:
		l_filter = "(%s) and not (%s)" % (l_hpotFilter, l_blackListFilter)

	elif l_whiteListFilter:
		l_filter = "(%s) and not (%s)" % (l_hpotFilter, l_whiteListFilter)

	else:
		l_filter = "(%s)" % (l_hpotFilter)

	print l_filter

if __name__ == "__main__":
	import os

	BLACK = "/hw/conf/HwFWBLACK"
	WHITE = "/hw/conf/HwFWWHITE"
	BW_LIST_ENABLE = "/hw/conf/HwBWLIST_ENABLE"

	NO_VALUE = "no"

	l_blackListFilename = None
	l_whiteLISTFilename = None
	l_blackWhiteListEnabled = True 

	if os.path.exists(BW_LIST_ENABLE):
        	l_bw = file(BW_LIST_ENABLE)
        	l_bw_enable_value = l_bw.readline().strip()
        	l_bw.close()

        	if l_bw_enable_value == NO_VALUE:
			l_blackWhiteListEnabled = False

	if l_blackWhiteListEnabled and os.path.exists(BLACK):
		l_b = file(BLACK)
		l_blackListFilename = l_b.readline().strip()
		l_b.close()

	if l_blackWhiteListEnabled and os.path.exists(WHITE):
		l_w = file(WHITE)
		l_whiteLISTFilename = l_w.readline().strip()
		l_b.close()
	
	main("/hw/conf/HwHPOT_PUBLIC_IP", l_blackListFilename, l_whiteLISTFilename)
