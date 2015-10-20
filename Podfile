workspace 'Alamofire.xcworkspace'
xcodeproj 'Alamofire.xcodeproj'
source 'https://github.com/CocoaPods/Specs.git'
use_frameworks!

target 'Alamofire iOS', :exclusive => true do
    platform :ios, '8.0'
    pod 'Result', '0.6.0-beta.4'
end

target 'Alamofire iOS Tests', :exclusive => true do
    platform :ios, '8.0'
    pod "Alamofire-Result", :path => "./"
end

target 'iOS Example', :exclusive => true do
	xcodeproj 'iOS Example'
    platform :ios, '8.0'
    pod "Alamofire-Result", :path => "./"
end

target 'Alamofire OSX', :exclusive => true do
    platform :osx, '10.10'
    pod 'Result', '0.6.0-beta.4'
end

target 'Alamofire OSX Tests', :exclusive => true do
    platform :osx, '10.10'
    pod "Alamofire-Result", :path => "./"
end

#target 'Alamofire watchOS' do
#	platform :watchos, '2.0'
#end