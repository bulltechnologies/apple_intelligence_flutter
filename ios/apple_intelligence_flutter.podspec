Pod::Spec.new do |s|
  s.name             = 'apple_intelligence_flutter'
  s.version          = '0.1.0'
  s.summary          = 'Flutter plugin that bridges to Apple Intelligence on-device models.'
  s.description      = <<-DESC
                       Provides access to Apple Intelligence foundation models from Flutter via Swift.
                       DESC
  s.homepage         = 'https://github.com/username/apple_intelligence_flutter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'apple_intelligence_flutter contributors' => 'opensource@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.swift_version    = '5.10'
  s.platform         = :ios, '26.0'
  s.dependency 'Flutter'
  s.frameworks       = 'FoundationModels'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.user_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
