#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'xmoney_ios'
  s.version          = '0.0.1'
  s.summary          = 'iOS implementation of the xMoney Flutter SDK.'
  s.homepage         = 'https://xmoney.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'xMoney' => 'support@xmoney.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'xmoney_ios/Sources/xmoney_ios/**/*'
  s.dependency 'Flutter'
  s.dependency 'XMoneyPaymentSheet', '1.0.1'
  s.platform = :ios, '15.0'
  s.swift_version = '5.9'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
