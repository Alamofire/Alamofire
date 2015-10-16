Pod::Spec.new do |s|
  s.name = 'Alamofire-Result'
  s.version = '3.0.0-karumi'
  s.license = 'MIT'
  s.summary = 'Result<Elegant> HTTP Networking in Swift'
  s.homepage = 'https://github.com/Karumi/Alamofire-Result'
  s.social_media_url = 'http://twitter.com/goKarumi'
  s.authors = { 'Alamofire Software Foundation' => 'info@alamofire.org',
                'Karumi'                        => 'hello@karumi.com' }
  s.source = { :git => 'https://github.com/Karumi/Alamofire-Result.git', :tag => s.version }

  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.10'
  s.watchos.deployment_target = '2.0'

  s.dependency 'Result', '~> 0.6.0-beta.4'
  
  s.source_files = 'Source/*.swift'

  s.requires_arc = true
end
