import XCPlayground
import Foundation
import Alamofire

// Allow network requests to complete
XCPSetExecutionShouldContinueIndefinitely()

Alamofire.request(.GET, "http://httpbin.org/get", parameters: ["foo": "bar"])
         .responseString { (request, response, string, error) in
            println(request)
            println(response)
            println(string)
         }
