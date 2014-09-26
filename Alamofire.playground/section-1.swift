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

/*
[BUG] In Xcode 6.0.1, execution fails with the following error:

IDEPlaygroundExecution: Playground execution failed: error: Couldn't lookup symbols:
__TWPSS9Alamofire20URLStringConvertible
__TF9Alamofire7requestFTOS_6MethodPS_20URLStringConvertible_10parametersGSqGVSs10DictionarySSPSs9AnyObject___8encodingOS_17ParameterEncoding_CS_7Request
__TFO9Alamofire6Method3GETFMS0_S0_
__TIF9Alamofire7requestFTOS_6MethodPS_20URLStringConvertible_10parametersGSqGVSs10DictionarySSPSs9AnyObject___8encodingOS_17ParameterEncoding_CS_7RequestA2_
__TMaC9Alamofire7Request
__TFC9Alamofire7Request14responseStringfDS0_FFTCSo12NSURLRequestGSqCSo17NSHTTPURLResponse_GSqSS_GSqCSo7NSError__T_DS0_

If you have a proposed fix, please send a Pull Request: https://github.com/Alamofire/Alamofire/pulls
*/
