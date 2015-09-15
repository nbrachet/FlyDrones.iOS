
# Inspired from https://github.com/kewlbear/FFmpeg-iOS-build-script/blob/master/build-ffmpeg.sh

RELEASE := 2.7.2

include ../Makefile.inc

LIBS := avcodec avfilter avutil swresample avdevice avformat postproc swscale

all: include $(foreach lib,$(LIBS),lib/lib$(lib).a) lib/pkgconfig

clean:
	( cd ffmpeg-$(RELEASE) ; $(MAKE) clean )
	-rm -rf $(ARCHS)
	-rm -rf include lib

distclean: clean
	( cd ffmpeg-$(RELEASE) ; $(MAKE) distclean )

install: include $(foreach lib,$(LIBS),lib/lib$(lib).a) lib/pkgconfig
	-rm -rf $(TOP)/Librairies/ffmpeg/include $(TOP)/Librairies/ffmpeg/lib
	cp -r include $(TOP)/Libraries/ffmpeg/
	cp -r lib $(TOP)/Libraries/ffmpeg/


include:    $(firstword $(ARCHS))
	cp -r $(firstword $(ARCHS))/include include

lib:
	mkdir $@

$(foreach lib,$(LIBS),$(eval \
lib/lib$(lib).a: lib $(addsuffix /lib/lib$(lib).a,$(ARCHS)); \
    xcrun lipo -create $(addsuffix /lib/lib$(lib).a,$(ARCHS)) -output lib/lib$(lib).a \
))

lib/pkgconfig:  $(firstword $(ARCHS))
	cp -r $(firstword $(ARCHS))/$@ $@


$(ARCHS):   ffmpeg-$(RELEASE) gas-preprocessor.pl \
            ../x264/lib/libx264.a
	-rm -rf $@
	( cd ffmpeg-$(RELEASE) ; \
	    PATH=..:$(PATH) ./configure \
	        --cc='xcrun --sdk $(call sdk,$@) clang' \
	        --extra-cflags='-arch $@ $(call cpu,$@) $(call fpu,$@) $(call version_min,$@) -I../../x264/include' \
	        --extra-cxxflags='-arch $@ $(call cpu,$@) $(call fpu,$@) $(call version_min,$@) -I../../x264/include' \
	        --extra-ldflags='-arch $@ $(call cpu,$@) $(call fpu,$@) $(call version_min,$@) -L../../x264/lib' \
	        --target-os=darwin \
	        --arch=$@ \
	        $(if $(filter arm64,$@),,--cpu=$(patsubst -mcpu=%,%,$(call cpu,$@))) \
	        $(if $(filter %neon,$(call fpu,$@)),--enable-neon,) \
	        --disable-armv5te --disable-armv6 --disable-armv6t2 \
	        --enable-cross-compile \
            $(if $(DEBUG),,--disable-debug) \
	        --disable-programs \
	        --disable-doc \
	        --enable-pic \
	        --enable-asm \
	        --disable-everything \
	        --enable-gpl \
	        --enable-libx264 \
	        --enable-decoder=h264 \
	        --enable-demuxer=h264 \
	        --enable-parser=h264 \
	        --prefix=$(abspath .)/$@ && \
	    PATH=..:$(PATH) $(MAKE) && \
	    $(MAKE) install && \
	    $(MAKE) clean )
	touch $@

$(foreach arch,$(ARCHS),\
    $(foreach lib,$(LIBS),$(eval $(arch)/lib/lib$(lib).a: $(arch)))\
)

gas-preprocessor.pl:
	wget https://github.com/libav/gas-preprocessor/raw/master/gas-preprocessor.pl
	chmod a+x $@

ffmpeg-$(RELEASE): ffmpeg-$(RELEASE).tar.bz2
	tar xvjf ffmpeg-$(RELEASE).tar.bz2

ffmpeg-$(RELEASE).tar.bz2:
	wget http://www.ffmpeg.org/releases/$@
