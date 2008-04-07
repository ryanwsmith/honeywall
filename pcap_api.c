// (C) 2005 The Trustees of Indiana University.  All rights reserved.
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA
//


/**********************************************************************
* $Id: pcap_api.c 4432 2006-09-19 18:51:53Z cviecco $ 
* Author: Camilo Viecco (with parts from Martin Casado)
*
* Description: 
*  a filter with time contraints, will open a file or a live interface
* apply the appropiate filter wich includes time limitations.
* it assumes the incomingdata has its datapackets in nondecrasing time
*
* To compile:
*  gcc -o filcap filcap.c -lpcap 
*
* tested on RH Linux WS 3
**********************************************************************/

#include <pcap.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netinet/if_ether.h> 
#include <net/ethernet.h>
#include <netinet/ether.h> 
#include <netinet/ip.h> 
#include <pcap.h>
#include <unistd.h>

// and define some globals........
//i know it is ugly... but is the easiest way to pass state to the pcap callback
pcap_dumper_t *dumper;
unsigned int stime=0;
unsigned int etime=2098465317;

//---------------------
int usage(){
  fprintf(stderr,"pcap api: A small program for time based pcap filtering.\n"
                "\n Usage: pcap_api (-i device |-r file) [-s epoch] [-e epoch]\n"
                 "               [-w file] [-f bpf_expr] \n"
                 "  -i device   - listen on this device \n"
                 "  -r file     - read data from this pcap_file \n"
                 "  -w file     - write output to this file (defaults to stdout)\n"
                 "  -s epoch    - select packets on or after this epoch value\n"
                 "  -e epoch    - select packets before this epoch value\n"
                 "  -f bpf_expr - filter the pcap input using this bpf expression\n"
     );
  exit(1);
  return 0; //line never reached
}


//----------------------------------------------------------------------------------
// now we begin the functions...


void my_callback(u_char *args,const struct pcap_pkthdr* pkthdr,const u_char*
        packet)
{
  static unsigned int numpackets;
 
  //if(pkthdr->ts.tv_sec>=stime)
  //   pcap_dump((u_char *)dumper,pkthdr,packet);   
  if(pkthdr->ts.tv_sec>etime){
    //last iteration close all
    //fprintf(stderr,"packets_processed=%d \n time_s=%d time_ns=%d\n",numpackets,
    //pkthdr->ts.tv_sec,pkthdr->ts.tv_usec);
    exit(0);
  }
  if(pkthdr->ts.tv_sec>=stime)
     pcap_dump((u_char *)dumper,pkthdr,packet);


  numpackets++;
}


int main(int argc,char **argv)
{ 
    char *dev; 
    char errbuf[PCAP_ERRBUF_SIZE];
    pcap_t* descr;
    struct bpf_program fp;      /* hold compiled program     */
    bpf_u_int32 maskp;          /* subnet mask               */
    bpf_u_int32 netp;           /* ip                        */
    u_char* args = NULL;
    char use_file=0;
    int32_t r;
    char *infilename = NULL;
    char *outfilename =NULL;
    char *filter_string=NULL;
    long long llstime, lletime;

    /* Options must be passed in as a string because I am lazy */
  
    //parse options
    while ((r = getopt(argc, argv, "f:r:w:s:e:h")) != -1){
      switch(r){
        case 'r':infilename=optarg;
	         use_file=1;
	         break;
        case 'w': outfilename=optarg; break;
        case 'f': filter_string=optarg; break;
      case 's': llstime=atoll(optarg);stime=llstime; break;
      case 'e': lletime=atoll(optarg);etime=lletime;break;
      case 'h': usage();exit(1);
        }
    }
    //fprintf(stderr,"stime=%u etime=%u\n",stime,etime);

    if(1!=use_file){   //open live anyiface
        /* grab a device to peak into... */
        dev = pcap_lookupdev(errbuf);
        if(dev == NULL)
        { printf("%s\n",errbuf); exit(1); }

        /* ask pcap for the network address and mask of the device */
        pcap_lookupnet(dev,&netp,&maskp,errbuf);


        /* open device for reading. NOTE: defaulting to
        * promiscuous mode*/
        descr = pcap_open_live(dev,BUFSIZ,1,-1,errbuf);
        if(descr == NULL)
        { printf("pcap_open_live(): %s\n",errbuf); exit(1); }
    }
    else{
       //we open the filename.....
        descr=pcap_open_offline(infilename, errbuf);
        if(descr == NULL)
        { printf("pcap_open_offline(): %s\n",errbuf); exit(1); }
    }

    //process the filter if present
     if(filter_string!=NULL)
    {
        /* Lets try and compile the program.. non-optimized */
        if(pcap_compile(descr,&fp,filter_string,0,netp) == -1)
        { fprintf(stderr,"Error calling pcap_compile\n"); exit(1); }

        /* set the compiled program as the filter */
        if(pcap_setfilter(descr,&fp) == -1)
        { fprintf(stderr,"Error setting filter\n"); exit(1); }
    }

    //open file for output.. if not defined open stdout
     if(outfilename!=NULL){
        dumper=pcap_dump_open(descr,outfilename);
        if (dumper==NULL){
	  fprintf(stderr,"Error opening outfile\n");
          exit(1);
        }
     }else{ //use stdout for output
          dumper=pcap_dump_open(descr,"-");
        if (dumper==NULL){
	  fprintf(stderr,"Error opening outfile\n");
          exit(1);
        } 
     }

    /* ... and loop */ 
    pcap_loop(descr,-1,my_callback,args);

    //fprintf(stdout,"\nfinished\n");
    return 0;
}

 
