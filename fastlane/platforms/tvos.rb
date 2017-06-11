platform :tvos do

  desc "Runs all the tvOS tests"
  lane :test do
    scan(
      scheme: 'Alamofire tvOS',
      workspace: 'Alamofire.xcworkspace'
    )
  end
  
end
