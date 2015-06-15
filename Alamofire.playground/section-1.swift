import XCPlayground
import Foundation
import Alamofire

// Allow network requests to complete
XCPSetExecutionShouldContinueIndefinitely()

Alamofire.request(.GET, URLString: "http://httpbin.org/get", parameters: ["foo": "bar"])
         .responseString { (request, response, string, error) in
            print(request)
            print(response)
            print(string)
         }

