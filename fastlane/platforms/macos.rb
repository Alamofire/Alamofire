platform :mac do

  desc "Runs all the macOS tests"
  lane :test do
    scan(
      scheme: 'Alamofire macOS',
      workspace: 'Alamofire.xcworkspace'
    )
  end
  
end
