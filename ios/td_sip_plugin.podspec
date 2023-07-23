#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint td_sip_plugin.podspec' to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'td_sip_plugin'
  s.version          = '0.0.1'
  s.summary          = 'A Flutter plugin for sip belong Trudian.'
  s.description      = <<-DESC
A Flutter plugin for sip belong Trudian.
                       DESC
  s.homepage         = 'http://open.trudian.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Jeason' => '1691665955@qq.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.dependency 'TDSip','1.0.5'
  s.dependency 'linphone-sdk'
  s.platform = :ios, '11.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'}
  s.swift_version = '5.0'
end
