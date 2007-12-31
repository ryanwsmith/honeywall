
help:
	@echo " "
	@echo " Usage:  make <rule>   where 'rule' is one of..."
	@echo " "
	@echo "---- ISO CREATION -----------------------------------------------------------------------"
	@echo " iso  ..............  Create an ISO from contents of ISO_BASE"
	@echo " check-deps  .......  Check dependencies of RPM pool in RPM_DIR"
	@echo " clean-old  ........  Remove older versions of RPMs from RPM_BASE"
	@echo " repo  .............  Create repo metadata in ISO_BASE"
	@echo " ksfcg  ............  Assemble the ks.cfg file from ks.top, ks.post and a dynamically"
	@echo "                       created RPM %{NAME} list of RPM_DIR/*.rpm and CUST_RPM_DIR/*.rpm"
	@echo " "
	@echo "---- ISO_BASE setup, RPM UPDATES, ADDITIONS, DELETIONS ----------------------------------"
#	@echo " unpack-iso  .......  Copy ISO base files from an ISO file to ISO_BASE"
#	@echo "                       Not necessary if checking out entire source from SVN"
#	@echo "                       Does NOT copy RPMs.  Use 'get-baserpms' or 'sync-rpms'"
#	@echo " get-baserpms  .....  Copy RPMs from RPM_SRC_DIR to RPM_DIR"
#	@echo "                       Handy if you get RPMs from an unpacked ISO or from a local DIR"
	@echo " sync-rpms  ........  Sync RPMs in RPM_DIR with RPMs in Honeynet Production repo"
	@echo " develrpms  ........  Build the Honeynet Project RPMs form checked out source"
	@echo " develrpms-release .  Build and Sign the Honeynet Project RPMs form checked out source"
	@echo " get-develrpms  ....  Copy Development RPMs from HPRPM_SRC_DIR to RPM_DIR"
	@echo "                       RPMs from Honeynet Project or upstream source"
##	@echo " update-baserpms  ..  Update Base RPMs using local yum.conf"
##	@echo "                       Experimental!"
##	@echo " "
##	@echo " getrpm-<name>  ....  Downloads latest RPM 'name' to RPM_DIR (hyphen required with no space)"
#	@echo " rmrpm  <name>  ....  Remove RPM <name> from RPM_DIR"
	@echo " "
	@echo "---- Housekeeping rules ----------------------------------------------------------------"
	@echo " clean  ............  Delete all ISO files and generated ks.cfg"
	@echo " develrpms-distclean  Clean out the Honeynet Project RPM build source trees"
	@echo " changelog-/<dir>/ .  Create basic changelog entrees from hard coded dirs"
	@echo "                      needs trailing slash"
	@echo " "

#$(dir)_sources := $(wildcard $(dir)/*.c)

.PHONY : iso check-deps clean-old repo kscfg build-iso 
.PHONY : sync-rpms get-isobase get-baserpms get-develrpms showdiff 
##.PHONY : clean distclean update-baserpms getrpm changelog
.PHONY : clean distclean changelog
.PHONY : develrpms develrpms-release develrpms-distclean

iso : clean-old check-deps repo kscfg build-iso 

###############################################################################
check-deps:
	@./mkiso check_deps

clean-old:
	@./mkiso clean_old

repo:
	@./mkiso create_repo

kscfg:
	@./mkiso ks_cfg

build-iso:
	@./mkiso build_iso 

###############################################################################
sync-rpms:
	@./mkiso sync_rpms

develrpms:
	@./mkiso  make_devel_rpms rpm

develrpms-release:
	@./mkiso  make_devel_rpms release

develrpms-distclean:
	@./mkiso  make_devel_rpms distclean

get-isobase:
	@./mkiso get_isobase

get-baserpms:
	@./mkiso get_baserpms

get-develrpms:
	@./mkiso get_develrpms

##getrpm-%:
##	@./mkiso get_rpm $*

#rmrpm %:
#	@./mkiso rm_rpm $*

showdiff:
	@./mkiso diff_local_repo

clean:
	@./mkiso clean

distclean:
	@./mkiso dist_clean

changelog-%:
	./mkiso changelog $*

# Experimental, uses your local system yum conf!!
##update-baserpms:
##	@./mkiso update_baserpms


