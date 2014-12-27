Pod::Spec.new do |s|
  s.name         = "Alamofire"
  s.version      = "1.1.2"
  s.summary      = "Elegant HTTP Networking in Swift"
  s.homepage     = "https://github.com/Alamofire/Alamofire"
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { 'Mattt Thompson' => 'm@mattt.me' }
  s.source       = { :git => "https://github.com/Alamofire/Alamofire.git", :tag => s.version }

  s.ios.deployment_target = '7.0'
  s.osx.deployment_target = "10.9"
  s.requires_arc = true

  s.source_files  = "Source/*.swift"
end
