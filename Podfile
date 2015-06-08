pod 'CocoaAsyncSocket'
pod 'ParseCrashReporting'
pod 'SWRevealViewController'
pod 'MBProgressHUD'

post_install do |installer|
  installer.project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['CLANG_CXX_LANGUAGE_STANDARD'] = 'c++0x'
      config.build_settings['CLANG_CXX_LIBRARY'] = 'libc++'
    end
  end
end