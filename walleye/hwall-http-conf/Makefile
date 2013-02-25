ver=1.2.1
pname=hwall-http-conf-${ver}

pkg:  httpd.conf hwall-http-conf.spec
	rm -rf ${pname}
	mkdir -p ${pname}/

        #-----
	cp httpd.conf ${pname} 
	cp hwall-http-conf.spec ${pname}
	cp Makefile ${pname}

        #-----
	tar -zcvf ./${pname}.tar.gz  ${pname}

	#-----
	rm -rf ${pname}

rpm: 
	mkdir -p /tmp/rpm/SOURCES	
	cp  ./${pname}.tar.gz /tmp/rpm/SOURCES
	#rpmbuild -bb --sign walleye.spec 
