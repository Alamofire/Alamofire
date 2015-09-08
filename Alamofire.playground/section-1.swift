import Alamofire
import Foundation
import XCPlayground

// Allow network requests to complete
XCPSetExecutionShouldContinueIndefinitely()

Alamofire.request(.GET, "https://httpbin.org/get", parameters: ["foo": "bar"])
    .responseString { request, response, result in
        print(request)
        print(response)
        debugPrint(result)
    }
