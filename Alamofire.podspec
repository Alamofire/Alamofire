Pod::Spec.new do |s|
  s.name = 'Alamofire'
  s.version = '1.1.3'
  s.license = 'MIT'
  s.summary = 'Elegant HTTP Networking in Swift'
  s.homepage = 'https://github.com/Alamofire/Alamofire'
  s.social_media_url = 'http://twitter.com/mattt'
  s.authors = { 'Mattt Thompson' => 'm@mattt.me' }
  s.source = { :git => 'https://github.com/Alamofire/Alamofire.git', :tag => '1.1.3' }

  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.9'

  s.source_files = 'Source/*.swift'
end
