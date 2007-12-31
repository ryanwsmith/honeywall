# RPM name
NAME = tcpdstat-uw
# Spec file name
SPEC = $(NAME).spec
# RPM Version
VER = $(shell rpm -q --qf "%{VERSION}\n" --specfile $(SPEC) | uniq)
# RPM Release
REL = $(shell rpm -q --qf "%{RELEASE}\n" --specfile $(SPEC)| uniq)
# Figure out arch
ARCH = $(shell rpm -q --qf "%{ARCH}\n" --specfile $(SPEC) | uniq)
BUILD_DIR = ${PWD}/rpmbuild
# Set all RPM build dirs to "."
RPMB_FLAGS = --define "_topdir ${PWD}" \
	     --define "_specdir ${PWD}" \
	     --define "_sourcedir ${PWD}" \
	     --define "_srcrpmdir ${PWD}" \
	     --define "_rpmdir ${BUILD_DIR}" \
	     --define "_builddir ${BUILD_DIR}"
# RPM filename
RPM=$(NAME)-$(VER)-$(REL).$(ARCH).rpm
# The complete SOURCE RPM filename, so we can 'move/clean' it 
SRPM=$(NAME)-$(VER)-$(REL).src.rpm
# Tarbal filename
TARBALL=$(NAME).tar

###############################################################################
rpm: $(RPM)

srpm: $(SRPM)

release: rpm srpm
	rpm --addsign $(RPM) $(SRPM)

$(RPM): $(BUILD_DIR) $(SPEC) $(TARBALL)
	rpmbuild -bb $(RPMB_FLAGS) $(SPEC)
	mv $(BUILD_DIR)/$(ARCH)/$(RPM) .
	
$(SRPM): $(BUILD_DIR) $(SPEC) $(TARBALL)
	rpmbuild -bs $(RPMB_FLAGS) $(SPEC)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

clean:
	rm -f $(RPM)
	rm -f $(SRPM)

distclean:
	rm -f $(NAME)-*.rpm
	if [ "$(BUILD_DIR)" != / -a -d "$(BUILD_DIR)" ]; then \
		rm -rf $(BUILD_DIR); \
	fi

