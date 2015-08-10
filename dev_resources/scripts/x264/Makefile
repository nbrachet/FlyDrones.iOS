
# Inspired from https://github.com/kewlbear/x264-ios/blob/master/build-x264.sh

SNAPSHOT := x264-snapshot-20150806-2245-stable

include ../Makefile.inc

all: include lib/libx264.a lib/pkgconfig

clean:
	( cd $(SNAPSHOT) ; $(MAKE) clean )
	-rm -rf $(ARCHS)
	-rm -rf include lib

distclean: clean
	( cd $(SNAPSHOT) ; $(MAKE) distclean )

install: include lib/libx264.a lib/pkgconfig
	-rm -rf $(TOP)/Librairies/x264/include $(TOP)/Librairies/x264/lib
	cp -r include $(TOP)/Libraries/x264/
	cp -r lib $(TOP)/Libraries/x264/


include:    $(firstword $(ARCHS))
	cp -r $(firstword $(ARCHS))/include include

lib:
	mkdir $@

lib/libx264.a:  lib $(addsuffix /lib/libx264.a,$(ARCHS))
	xcrun lipo -create $(addsuffix /lib/libx264.a,$(ARCHS)) -output $@

lib/pkgconfig:  $(firstword $(ARCHS))
	cp -r $(firstword $(ARCHS))/$@ $@


$(ARCHS):  $(SNAPSHOT)
	-rm -rf $@
	( cd $(SNAPSHOT) ; \
	    CC='xcrun --sdk $(call sdk,$@) clang' \
	    CFLAGS='-arch $@ $(call cpu,$@) $(call fpu,$@) $(call version_min,$@)' \
	$(if $(filter x86_64 i386,$@),,\
	    ASFLAGS='-arch $@ $(call cpu,$@) $(call fpu,$@)' \
	) \
	        ./configure \
	            $(call host,$@) \
	            --enable-pic \
	            --enable-static \
                $(if $(DEBUG),--enable-debug,) \
	            --disable-gpl \
	            --disable-cli \
	            --prefix=$(abspath .)/$@ && \
	    $(MAKE) && \
	    $(MAKE) install && \
	    $(MAKE) clean )
	touch $@

$(foreach arch,$(ARCHS),$(eval $(arch)/lib/libx264.a: $(arch)))

$(SNAPSHOT): $(SNAPSHOT).tar.bz2
	tar xvjf $(SNAPSHOT).tar.bz2

$(SNAPSHOT).tar.bz2:
	wget http://download.videolan.org/pub/x264/snapshots/$(SNAPSHOT).tar.bz2
