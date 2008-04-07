ver=1.1-10
pname=walleye-${ver}

pkg: sum_graph.pl walleye.pl walleye.css walleye_install.sh httpd.conf
	rm -rf ${pname}
	mkdir -p ${pname}/icons
	mkdir -p ${pname}/modules/Walleye
	mkdir -p ${pname}/admin/templates/img

        #-----
	cp httpd.conf ${pname} 
	cp init.d/walleye-httpd ${pname} 
	cp *.pl      ${pname} 
	cp modules/Walleye/*.pm ${pname}/modules/Walleye 
	
	cp admin/*.pl               ${pname}/admin
	#cp admin/*.pm              ${pname}/admin
	cp admin/templates/*.htm   ${pname}/admin/templates
	cp admin/templates/*.css   ${pname}/admin/templates
	cp admin/templates/*.jpg   ${pname}/admin/templates
	cp admin/templates/*.png   ${pname}/admin/templates
	cp admin/templates/*.js    ${pname}/admin/templates
	cp admin/templates/*.gif   ${pname}/admin/templates
	cp admin/templates/img/*.*  ${pname}/admin/templates/img
	
	cp *.css     ${pname} 
	cp *.gif     ${pname} 
	cp *.jpg     ${pname} 
	cp *.png     ${pname} 
	cp *.ico     ${pname}
	cp icons/*.png   ${pname}/icons

        #-----
	tar -zcvf ./${pname}.tar.gz  ${pname}

rpm: 
	mkdir -p /tmp/rpm/SOURCES	
	cp  ./${pname}.tar.gz /tmp/rpm/SOURCES
	rpmbuild -bb --sign walleye.spec 
