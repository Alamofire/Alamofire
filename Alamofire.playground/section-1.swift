import Alamofire
import Foundation
import XCPlayground

// Allow network requests to complete
XCPlaygroundPage.currentPage.needsIndefiniteExecution = true

Alamofire.request(.GET, "https://httpbin.org/get", parameters: ["foo": "bar"])
    .responseJSON { response in
        debugPrint(response)
    }
