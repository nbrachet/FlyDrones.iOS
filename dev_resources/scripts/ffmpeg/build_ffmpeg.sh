e#!/bin/sh

#Create by Sergey Galagan
#Builds the ffmpeg libs with support x264 encoder for
#the next architectures armv7, armv7s and arm64
#After successful building combines libs into one universal lib
#

# directories
SOURCE="ffmpeg-2.7.1"
OUTPUT="ffmpeg"

TEMP_DIR="temp"
SCRATCH=`pwd`/$TEMP_DIR/"scratch-ffmpeg"
THIN=`pwd`/$TEMP_DIR/"thin-ffmpeg"

# absolute path to x264 library
X264=`pwd`/"x264"

#FDK_AAC=`pwd`/fdk-aac/fdk-aac-ios

CONFIGURE_FLAGS="--enable-cross-compile --disable-debug --disable-programs --disable-doc --enable-pic --enable-asm"

if [ "$X264" ]
then
    CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-gpl --enable-libx264 --enable-decoder=h264 --enable-demuxer=h264 --enable-parser=h264"
fi

if [ "$FDK_AAC" ]
then
    CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-libfdk-aac"
fi

# avresample
#CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-avresample"

ARCHS="arm64 armv7s armv7 x86_64 i386"

COMPILE="y"
LIPO="y"
DEPLOYMENT_TARGET="6.0"

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
    if [ ! `which yasm` ]
    then
        echo 'Yasm not found'
        if [ ! `which brew` ]
        then
            echo 'Homebrew not found. Trying to install...'
            ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" \
            || exit 1
        fi
        echo 'Trying to install Yasm...'
        brew install yasm || exit 1
    fi

    if [ ! `which gas-preprocessor.pl` ]
    then
        echo 'gas-preprocessor.pl not found. Trying to install...'
        (curl -L https://github.com/libav/gas-preprocessor/raw/master/gas-preprocessor.pl \
        -o /usr/local/bin/gas-preprocessor.pl \
        && chmod +x /usr/local/bin/gas-preprocessor.pl) \
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
    echo "building $ARCH..."
    mkdir -p "$SCRATCH/$ARCH"
    cd "$SCRATCH/$ARCH"

    CFLAGS="-arch $ARCH"
    if [ "$ARCH" = "i386" -o "$ARCH" = "x86_64" ]
    then
        PLATFORM="iPhoneSimulator"
        CFLAGS="$CFLAGS -mios-simulator-version-min=$DEPLOYMENT_TARGET"
    else
        PLATFORM="iPhoneOS"
        CFLAGS="$CFLAGS -mios-version-min=$DEPLOYMENT_TARGET -mfpu=neon"
        if [ "$ARCH" = "arm64" ]
        then
            EXPORT="GASPP_FIX_XCODE5=1"
        fi
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
    if [ "$FDK_AAC" ]
    then
        CFLAGS="$CFLAGS -I$FDK_AAC/include"
        LDFLAGS="$LDFLAGS -L$FDK_AAC/lib"
    fi

    TMPDIR=${TMPDIR/%\/} $CWD/$SOURCE/configure \
    --target-os=darwin \
    --arch=$ARCH \
    --cc="$CC" \
    $CONFIGURE_FLAGS \
    --extra-cflags="$CFLAGS" \
    --extra-cxxflags="$CXXFLAGS" \
    --extra-ldflags="$LDFLAGS" \
    --prefix="$THIN/$ARCH" \
    || exit 1

    make -j3 install $EXPORT || exit 1
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
        echo lipo -create `find $THIN -name $LIB` -output $OUTPUT/lib/$LIB 1>&2
        lipo -create `find $THIN -name $LIB` -output $OUTPUT/lib/$LIB || exit 1
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