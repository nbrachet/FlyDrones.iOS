#!/bin/sh

# directories
SOURCE="x264-snapshot-20141218-2245-stable"
OUTPUT="x264"

TEMP_DIR="temp"
SCRATCH=`pwd`/$TEMP_DIR/"scratch-x264"
THIN=`pwd`/$TEMP_DIR/"thin-x264"

# the one included in x264 does not work; specify full path to working one
GAS_PREPROCESSOR=/usr/local/bin/gas-preprocessor.pl

if [ ! -r $SOURCE ]
then
    echo 'x264 source not found. Trying to download...'
    curl http://download.videolan.org/pub/x264/snapshots/$SOURCE.tar.bz2 | tar xj \
    || exit 1
fi

ARCHS="arm64 armv7s armv7 x86_64 i386"

CONFIGURE_FLAGS="--enable-static --enable-pic --disable-cli"

COMPILE="y"
LIPO="y"

if [ -d "$TEMP_DIR" ]
then
    rm -rf "$TEMP_DIR"
fi
mkdir -p "$TEMP_DIR"

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
	CWD=`pwd`
	for ARCH in $ARCHS
	do
		echo "building $ARCH..."
		mkdir -p "$SCRATCH/$ARCH"
		cd "$SCRATCH/$ARCH"

		if [ "$ARCH" = "i386" -o "$ARCH" = "x86_64" ]
		then
		    PLATFORM="iPhoneSimulator"
		    CPU=
		    if [ "$ARCH" = "x86_64" ]
		    then
		    	SIMULATOR="-mios-simulator-version-min=7.0"
		    	HOST=
		    else
		    	SIMULATOR="-mios-simulator-version-min=5.0"
			HOST="--host=i386-apple-darwin"
		    fi
		else
		    PLATFORM="iPhoneOS"
		    if [ $ARCH = "armv7s" ]
		    then
		    	CPU="--cpu=swift"
		    else
		    	CPU=
		    fi
		    SIMULATOR=
		    if [ $ARCH = "arm64" ]
		    then
		        HOST="--host=aarch64-apple-darwin"
		    else
		        HOST="--host=arm-apple-darwin"
		    fi
		fi

		XCRUN_SDK=`echo $PLATFORM | tr '[:upper:]' '[:lower:]'`
		CC="xcrun -sdk $XCRUN_SDK clang -Wno-error=unused-command-line-argument-hard-error-in-future -arch $ARCH"
		CFLAGS="-arch $ARCH $SIMULATOR"
		CXXFLAGS="$CFLAGS"
		LDFLAGS="$CFLAGS"

		CC=$CC $CWD/$SOURCE/configure \
		    $CONFIGURE_FLAGS \
		    $HOST \
		    $CPU \
		    --extra-cflags="$CFLAGS" \
		    --extra-ldflags="$LDFLAGS" \
		    --prefix="$THIN/$ARCH"

		mkdir extras
		ln -s $GAS_PREPROCESSOR extras

		make -j3 install
		cd $CWD
	done
fi

if [ "$LIPO" ]
then
	echo "building fat binaries..."
	mkdir -p $OUTPUT/lib
	set - $ARCHS
	CWD=`pwd`
	cd $THIN/$1/lib
	for LIB in *.a
	do
		cd $CWD
		lipo -create `find $THIN -name $LIB` -output $OUTPUT/lib/$LIB
	done

	cd $CWD
	cp -rf $THIN/$1/include $OUTPUT
fi

if [ -d "$SOURCE" ]
then
    printf '%s\n' "Removing source directory ($SOURCE)"
    rm -rf "$SOURCE"
fi

if [ -d "$TEMP_DIR" ]
then
    printf '%s\n' "Removing temp directory ($TEMP_DIR)"
    rm -rf "$TEMP_DIR"
fi

echo Done