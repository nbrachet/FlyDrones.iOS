#!/bin/bash
cd x264
./build-x264.sh
cp -r x264 ../ffmpeg
rm -rf x264
cd ../ffmpeg
./build_ffmpeg.sh
cp -r x264 ../../../Libraries 
rm -rf x264
cp -r ffmpeg ../../../Libraries
rm -rf ffmpeg