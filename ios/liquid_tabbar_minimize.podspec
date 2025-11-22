#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint adaptive_platform_ui.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'liquid_tabbar_minimize'
  s.version          = '0.1.0'
  s.summary          = 'iOS native tab bar with scroll-to-minimize behavior for Flutter.'
  s.description      = <<-DESC
A Flutter package providing iOS native tab bar with automatic minimize on scroll.
Supports iOS 26+ native minimize behavior and iOS 14-25 with SwiftUI TabView.
                       DESC
  s.homepage         = 'https://github.com/mesutissever/liquid_tabbar_minimize'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Mesut Issever' => 'mesutissever@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  
  # iOS 14+ minimum (SwiftUI TabView)
  s.platform = :ios, '15.0'

  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES', 
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' 
  }
  s.swift_version = '5.0'
end
