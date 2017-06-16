platform :ios do

  desc "Runs all the iOS tests"
  lane :test do
    scan(
      scheme: 'Alamofire iOS',
      workspace: 'Alamofire.xcworkspace'
    )
  end

end
