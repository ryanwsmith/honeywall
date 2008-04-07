ver=1.2.1
pname=walleye-${ver}

dist: sum_graph.pl walleye.pl walleye.css walleye_install.sh 
	rm -rf ${pname}
	mkdir -p ${pname}/icons
	mkdir -p ${pname}/admin/templates/img

        #-----
	cp *.pl      ${pname}
	cp *.sh	     ${pname} 
	#cp AUTHORS   ${pname}
	#cp README    ${pname}
	cp walleye.* ${pname}
	
	cp admin/*.pl               ${pname}/admin
	#cp admin/*.pm              ${pname}/admin
	cp admin/templates/*.htm   ${pname}/admin/templates
	cp admin/templates/*.css   ${pname}/admin/templates
	cp admin/templates/*.jpg   ${pname}/admin/templates
	#cp admin/templates/*.png   ${pname}/admin/templates
	cp admin/templates/*.js    ${pname}/admin/templates
	cp admin/templates/*.gif   ${pname}/admin/templates
	cp admin/templates/img/*.*  ${pname}/admin/templates/img
	
	cp *.css     ${pname} 
	cp *.gif     ${pname} 
	cp *.jpg     ${pname} 
	cp *.png     ${pname} 
	#cp *.ico     ${pname}
	cp icons/*.png   ${pname}/icons

        #-----
	tar -zcvf ./${pname}.tar.gz  ${pname}
	rm -rf ${pname}


distclean:
	rm -rf ${pname}
	rm -rf ${pname}.tar.gz

