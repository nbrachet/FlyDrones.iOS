#FlyDrones

##Building
1. Clone the project
2. ```cd FlyDrones.iOS/```
3. Run ```pod install```
    * If pod is not installed follow the instructions from [Getting Started CocoaPods](https://guides.cocoapods.org/using/getting-started.html)
        * Note: version 0.38.1 is known to have problems. To install version 0.37.2 run ```sudo gem install cocoapods -v 0.37.2```
4. Compile ffmpeg and x264 (Optional)
    * ```cd dev_resources/scripts/```
    * ```./build_libs.sh```
5. Run FlyDrones.xcworkspace in the latest version of Xcode
6. Clean project: Command-Option-Shift-K or Product->Clean

##Tested with:
* OS X Mavericks 10.9.5 and OS X Yosemite 10.10.4 (14E46)
* Xcode 6.4
* Cocoapods 0.37.2

##License
