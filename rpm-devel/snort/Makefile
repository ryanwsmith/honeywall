#$Id: $
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

# RPM name
NAME = snort
# Spec file name
SPEC = $(NAME).spec
# RPM Version from spec
VER = $(shell rpm -q --qf "%{VERSION}\n" --specfile $(SPEC) | uniq)
# RPM Release from spec
REL = $(shell rpm -q --qf "%{RELEASE}\n" --specfile $(SPEC) | uniq)
# Arch from spec
ARCH = $(shell rpm -q --qf "%{ARCH}\n" --specfile $(SPEC) | uniq)
# Where we will build
BUILD_DIR = ${PWD}/rpmbuild
# Set all RPM build dirs to "."
RPMB_FLAGS = --define "_topdir ${PWD}" --define "_specdir ${PWD}" \
	     --define "_sourcedir ${PWD}" --define "_srcrpmdir ${PWD}" \
	     --define "_rpmdir ${BUILD_DIR}" --define "_builddir ${BUILD_DIR}" 
# RPM filename
RPM=$(NAME)-$(VER)-$(REL).$(ARCH).rpm
# SOURCE RPM filename
SRPM=$(NAME)-$(VER)-$(REL).src.rpm
# Tarbal filename
TARBALL=$(NAME)-$(VER).tar.gz

###############################################################################
rpm: $(RPM)

srpm: $(SRPM)

release: $(RPM) $(SRPM) sign

$(RPM): $(BUILD_DIR) $(SPEC) $(TARBALL) 
	rpmbuild -bb --with inline $(RPMB_FLAGS) $(SPEC)
	mv $(BUILD_DIR)/$(ARCH)/$(RPM) .

$(SRPM): $(BUILD_DIR) $(SPEC) $(TARBALL)
	rpmbuild -bs --with inline $(RPMB_FLAGS) $(SPEC)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

sign: $(RPM) $(SRPM)
	rpm --define "_signature gpg" --define "_gpg_name roo@honeynet.org" --addsign $(RPM) $(SRPM)

clean:
	rm -f $(RPM) 
	rm -f $(SRPM)

distclean:
	rm -f $(NAME)-*.rpm
	if [ "$(BUILD_DIR)" != / -a -d "$(BUILD_DIR)" ]; then \
		rm -rf $(BUILD_DIR); \
	fi



