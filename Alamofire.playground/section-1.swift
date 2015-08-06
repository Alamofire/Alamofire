import Alamofire
import Foundation
import XCPlayground

// Allow network requests to complete
XCPSetExecutionShouldContinueIndefinitely()

Alamofire.request(.GET, "https://httpbin.org/get", parameters: ["foo": "bar"])
         .responseString { request, response, string, _ in
             print(request)
             print(response)
             print(string)
         }
