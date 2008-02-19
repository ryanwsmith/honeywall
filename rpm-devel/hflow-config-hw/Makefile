ver=1.0-0
pname=hflow-config-hw-${ver}

dist:
	rm -rf pkg
	mkdir pkg
	mkdir -p pkg/${pname}
	mkdir -p pkg/${pname}/init.d
	cp my.cnf        pkg/${pname}
	cp createBpfFilter.py pkg/${pname}
	cp hflow-config-hw.schema pkg/${pname}
	cp init.d/hw-mysqld pkg/${pname}/init.d
	cp init.d/hw-p0f   pkg/${pname}/init.d
	cp init.d/hw-pcap  pkg/${pname}/init.d
	cp init.d/hw-snort_inline pkg/${pname}/init.d

	tar -zcvf ./${pname}.tar.gz -C ./pkg/ .

rpm:  ${pname}.tar.gz
	cp ${pname}.tar.gz ${HOME}/rpm/SOURCES
#	cp ${pname}.tar.gz /usr/src/redhat/SOURCES
	rpmbuild -bb --sign hflow-config-hw.spec
