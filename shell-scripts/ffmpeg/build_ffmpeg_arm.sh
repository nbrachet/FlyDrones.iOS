#!/bin/sh

#Create by Sergey Galagan
#Builds the ffmpeg libs with support x264 encoder for
#the next architectures armv7, armv7s and arm64
#After successful building combines libs into one universal lib
#

#Directories
SOURCE="ffmpeg-2.5.3"
UNIVERSAL_DIR="universal_ffmpeg_x264_libs"
SCRATCH="scratch"
OUTPUT=`pwd`/"output"

#Path to x264 library
X264=`pwd`/universal_x264_lib

#Archs
ARCHS="armv7 armv7s arm64"

CONFIGURE_FLAGS="--enable-cross-compile --disable-debug --disable-programs --disable-doc --enable-pic"

if [ "$X264" ]
then
	CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-gpl --enable-libx264 --enable-decoder=h264 --enable-demuxer=h264 --enable-parser=h264"
fi

COMPILE="y"
LIPO="y"

DEPLOYMENT_TARGET="7.0"

if [ "$*" ]
then
	if [ "$*" = "lipo" ]
	then
		# skip compile
		COMPILE=
	else
		ARCHS="$*"
		if [ $# -eq 1 ]
		then
			# skip lipo
			LIPO=
		fi
	fi
fi

if [ "$COMPILE" ]
then
	if [ ! `which yasm` ]
	then
		echo 'Yasm not found'
		if [ ! `which brew` ]
		then
			echo 'Homebrew not found. Trying to install...'
			ruby -e "$(curl -fsSL https://raw.github.com/Homebrew/homebrew/go/install)" \
				|| exit 1
		fi
		echo 'Trying to install Yasm...'
		brew install yasm || exit 1
	fi

	if [  `which gas-preprocessor.pl` ]
	then
		echo 'gas-preprocessor.pl not found. Trying to install...'
		(curl -L https://github.com/libav/gas-preprocessor/raw/master/gas-preprocessor.pl \
			  -o /usr/local/bin/gas-preprocessor.pl && chmod +x /usr/local/bin/gas-preprocessor.pl) \
			  || exit 1
	fi

	if [ ! -r $SOURCE ]
	then
		echo 'FFmpeg source not found. Trying to download...'
		curl http://www.ffmpeg.org/releases/$SOURCE.tar.bz2 | tar xj \
			|| exit 1
	fi

	CWD=`pwd`
	for ARCH in $ARCHS
	do
		echo "Building $ARCH..."
		mkdir -p "$SCRATCH/$ARCH"
		cd "$SCRATCH/$ARCH"

		CFLAGS="-arch $ARCH"
        PLATFORM="iPhoneOS"
        CFLAGS="$CFLAGS -mios-version-min=$DEPLOYMENT_TARGET"

        if [ "$ARCH" = "arm64" ]
        then
            EXPORT="GASPP_FIX_XCODE5=1"
        fi

    XCRUN_SDK=`echo $PLATFORM | tr '[:upper:]' '[:lower:]'`
    CC="xcrun -sdk $XCRUN_SDK clang"
    CXXFLAGS="$CFLAGS"
    LDFLAGS="$CFLAGS"

    if [ "$X264" ]
    then
        CFLAGS="$CFLAGS -I$X264/include"
        LDFLAGS="$LDFLAGS -L$X264/lib"
    fi

    TMPDIR=${TMPDIR/%\/} $CWD/$SOURCE/configure \
        --target-os=darwin \
        --arch=$ARCH \
        --cc="$CC" \
        $CONFIGURE_FLAGS \
        --extra-cflags="$CFLAGS" \
        --extra-cxxflags="$CXXFLAGS" \
        --extra-ldflags="$LDFLAGS" \
        --prefix="$OUTPUT/$ARCH" \
    || exit 1

    make -j3 install $EXPORT || exit 1
    cd $CWD
done
fi

if [ "$LIPO" ]
then
	echo "Building universal libs..."
	mkdir -p $UNIVERSAL_DIR/lib
	set - $ARCHS
	CWD=`pwd`
	cd $OUTPUT/$1/lib
	for LIB in *.a
	do
		cd $CWD
		echo lipo -create `find $OUTPUT -name $LIB` -output $UNIVERSAL_DIR/lib/$LIB 1>&2
		lipo -create `find $OUTPUT -name $LIB` -output $UNIVERSAL_DIR/lib/$LIB || exit 1
	done

	cd $CWD
	cp -rf $OUTPUT/$1/include $UNIVERSAL_DIR
fi

echo Done
