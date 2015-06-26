#!/bin/sh

#Create by Sergey Galagan
#Builds the x264 lib for armv7, armv7s and arm64
#After successful building combines the three libs into one universal lib
#

#Lib install dir.
DEST=install

#Directory where libs will be copyed
DESTINATION_LIBS_DIR=../../../ffmpeg

#Path for develop tools
DEVELOP_PATH=`xcode-select -print-path`
DEVICE_SDK_PATH=$DEVELOP_PATH/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk

#Archs
ARCHS="armv7 armv7s arm64"

#Clone x264
git clone git://git.videolan.org/x264.git x264_sources

mkdir x264_sources/$DEST
cd x264_sources

export CC=`xcodebuild -find clang`

for ARCH in $ARCHS; do
    
    echo "\nBuilding $ARCH ......"

    ./configure \
    --host=arm-apple-darwin \
    --sysroot=$DEVICE_SDK_PATH \
    --prefix=$DEST/$ARCH \
    --extra-cflags="-arch $ARCH" \
    --extra-ldflags="-L$DEVICE_SDK_PATH/usr/lib/system -arch $ARCH" \
    --enable-pic \
    --enable-static \
    --disable-asm

    make && make install && make clean

    echo "Installed: $DEST/$ARCH"

done

echo "\nCreating universal library ......"
BUILD_LIBS="libx264.a"
OUTPUT_DIR="x264"

cd install
mkdir $OUTPUT_DIR
mkdir $OUTPUT_DIR/lib
mkdir $OUTPUT_DIR/include


LIPO_CREATE=""

for ARCH in $ARCHS; do
    LIPO_CREATE="$LIPO_CREATE $ARCH/lib/$BUILD_LIBS "
done

lipo -create $LIPO_CREATE -output $OUTPUT_DIR/lib/$BUILD_LIBS
cp -f $ARCH/include/*.* $OUTPUT_DIR/include/

echo "************************************************************"
lipo -i $OUTPUT_DIR/lib/$BUILD_LIBS
echo "************************************************************"

cp -R $OUTPUT_DIR $DESTINATION_LIBS_DIR

echo "COMPLETED"
