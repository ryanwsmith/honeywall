ver=1.0-1
pname=walleye-config-hw-${ver}

dist:
	rm -rf pkg
	mkdir pkg
	mkdir -p pkg/${pname}
	mkdir -p pkg/${pname}/init.d
	cp walleye-httpd.conf pkg/${pname}
	cp init.d/walleye-httpd pkg/${pname}/init.d

	tar -zcvf ./${pname}.tar.gz -C ./pkg/ .

rpm:  ${pname}.tar.gz
	cp ${pname}.tar.gz ${HOME}/rpm/SOURCES
#	cp ${pname}.tar.gz /usr/src/redhat/SOURCES
	rpmbuild -bb --sign walleye-config-hw.spec
