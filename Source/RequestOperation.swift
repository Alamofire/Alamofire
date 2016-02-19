//
//  RequestOperation.swift
//  Alamofire
//
//  Created by Catalina Turlea on 1/24/16.
//  Copyright © 2016 Alamofire. All rights reserved.
//

import Foundation

public class RequestOperation: NSOperation {
    
    private var isRequestRunning = false
    
    private var successBlock: ((response: Response<AnyObject, NSError>, json: [String: AnyObject]?) -> ())
    private var failureBlock: ((response: Response<AnyObject, NSError>) -> ())

    private var ongoingRequest: Request?
    
    public init(successBlock: ((response: Response<AnyObject, NSError>, json: [String: AnyObject]?) -> ()), failureBlock: ((response: Response<AnyObject, NSError>) -> ())) {
        self.successBlock = successBlock
        self.failureBlock = failureBlock
        
        super.init()
    }
    
    override public var executing: Bool {
        get {
            return isRequestRunning
        }
    }
    
    override public var finished: Bool {
        get {
            return !isRequestRunning
        }
    }
    
    public override func cancel() {
        super.cancel()
        ongoingRequest?.cancel()
        print("cancel")
    }
    
    override public func main() {
        isRequestRunning = true
        print("running")
        let emails = ["email":"d@t.com", "password": "r"]
        ongoingRequest = Manager.sharedInstance.request(.POST, "https://api.freeletics.com/user/v1/auth/password/login", parameters: ["login": emails], encoding: ParameterEncoding.JSON, headers: nil).responseJSON { (response) -> Void in
            
            print("Operation finished")
            print(response.request)  // original URL request
            print(response.response) // URL response
            print(response.data)     // server data
            if let json = try? NSJSONSerialization.JSONObjectWithData(response.data!, options: NSJSONReadingOptions.AllowFragments), parsed = json as? [String: AnyObject] {
                self.successBlock(response: response, json: parsed)
            } else if let error = response.result.error where error.code == -999 {
                self.failureBlock(response: response)
            }
            print(response.result.error)   // result of response serialization
//            print(response.error)   // result of response serialization
            self.isRequestRunning = false
            
            
        }
    }
    
    
}
