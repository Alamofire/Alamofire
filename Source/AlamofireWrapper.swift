//
//  AlamofireWrapper.swift
//  Alamofire
//
//  Created by Catalina Turlea on 2/4/16.
//  Copyright © 2016 Alamofire. All rights reserved.
//

import Foundation

@objc public enum RequestMethod: NSInteger {
    case OPTIONS = 0, GET, HEAD, POST, PUT, PATCH, DELETE, TRACE, CONNECT
}

@objc public enum RequestParameterEncoding: NSInteger {
    case URL, URLEncodedInURL, JSON
}

public class BodyPart: NSObject {
    var data: NSData
    var name: String
    var fileName: String?
    var mimeType: String?
    
    init(data: NSData, name: String) {
        self.data = data
        self.name = name
        super.init()
    }
}

public class AlamofireWrapper: NSObject {
    
    // MARK: - Request Methods
    
    /**
    Creates a request using the shared manager instance for the specified method, URL string, parameters, and
    parameter encoding.
    
    - parameter method:     The HTTP method.
    - parameter URLString:  The URL string.
    - parameter parameters: The parameters. `nil` by default.
    - parameter encoding:   The parameter encoding. `.URL` by default.
    - parameter headers:    The HTTP headers. `nil` by default.
    - parameter success:    Block to be called in case of successful execution of the request.
    - parameter failure:    Block to be called in case of errors during the execution of the request.
    */
    
    public class func request(
        method: RequestMethod,
        URLString: String,
        parameters: [String: NSObject]? = nil,
        encoding: RequestParameterEncoding = .URL,
        headers: [String: String]?,
        success: (request: NSURLRequest?, response: NSHTTPURLResponse?, json: [NSObject: AnyObject]?) -> (),
        failure: (request: NSURLRequest?, response: NSHTTPURLResponse?, error: NSError?) -> ()) {
            
        let method = translateMethod(method)
        let encoding = translateEncoding(encoding)
        
        let request = Alamofire.request(method, URLString, parameters: parameters, encoding: encoding, headers: headers)
        request.responseJSON { (response) -> Void in
            parseResponse(response, success: success, failure: failure)
        }
    }
    
    // MARK: - Upload Methods
    
    // MARK: MultipartFormData
    
    /**
    Creates an upload request using the shared manager instance for the specified method and URL string.
    
    - parameter method:                  The HTTP method.
    - parameter URLString:               The URL string.
    - parameter headers:                 The HTTP headers. `nil` by default.
    - parameter multipartFormData:       The closure used to append body parts to the `MultipartFormData`.
    - parameter success:                 Block to be called in case of successful execution of the request.
    - parameter failure:                 Block to be called in case of errors during the execution of the request.
    */
    public class func upload(
        method: RequestMethod,
        _ URLString: String,
        headers: [String: String]? = nil,
        multipartFormData: (Void -> [BodyPart]),
        success: ((request: NSURLRequest?, response: NSHTTPURLResponse?, json: [NSObject: AnyObject]?) -> ()),
        failure: ((request: NSURLRequest?, response: NSHTTPURLResponse?, error: NSError?) -> ())) {
            let method = translateMethod(method)
            
            Manager.sharedInstance.upload(method, URLString, headers: headers, multipartFormData: { (formData) -> Void in
                let bodyParts = multipartFormData()
                for part in bodyParts {
                    if let fileName = part.fileName, mimeType = part.mimeType {
                        formData.appendBodyPart(data: part.data, name: part.name, fileName: fileName, mimeType: mimeType)
                    } else {
                        formData.appendBodyPart(data: part.data, name: part.name)
                    }
                    
                }
                
                }) { (result) -> Void in
                    switch result {
                    case .Success(let uploadRequest, _, _):
                        uploadRequest.responseData({ (response) -> Void in
                            parseResponse(response, success: success, failure: failure)
                        })
                    case .Failure(_):
                        failure(request: nil, response: nil, error: NSError(domain: "Encoding error", code: 0, userInfo: nil))
                    }
            }
    }
    
    private class func translateMethod(method: RequestMethod) -> Alamofire.Method {
        switch(method) {
        case .GET:
            return .GET
        case .POST:
            return .POST
        case .DELETE:
            return .DELETE
        case .HEAD:
            return .HEAD
        case .PUT:
            return .PUT
        case .PATCH:
            return .PATCH
        case .TRACE:
            return .TRACE
        case .CONNECT:
            return .CONNECT
        case .OPTIONS:
            return .OPTIONS
        }
    }
    
    private class func translateEncoding(encoding: RequestParameterEncoding) -> Alamofire.ParameterEncoding {
        switch (encoding) {
        case .JSON:
            return .JSON
        case .URLEncodedInURL:
            return .URLEncodedInURL
        case .URL:
            return .URL
        }
    }
    
    private class func parseResponse(response: Response<NSData, NSError>, success: (request: NSURLRequest?, response: NSHTTPURLResponse?, json: [NSObject: AnyObject]?) -> (),
        failure: (request: NSURLRequest?, response: NSHTTPURLResponse?, error: NSError?) -> ()) {
            switch (response.result) {
            case .Success(let data):
                if let json = try? NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments), parsed = json as? [NSObject: AnyObject] {
                    success(request: response.request, response: response.response, json: parsed)
                } else {
                    success(request: response.request, response: response.response, json: [NSObject: AnyObject]())
                }
            case .Failure(let error):
                failure(request: response.request, response: response.response, error: error)
            }
    }
    
    private class func parseResponse(response: Response<AnyObject, NSError>, success: (request: NSURLRequest?, response: NSHTTPURLResponse?, json: [NSObject: AnyObject]?) -> (),
        failure: (request: NSURLRequest?, response: NSHTTPURLResponse?, error: NSError?) -> ()) {
            switch (response.result) {
            case .Success(let json):
                if let json = json as? [NSObject: AnyObject] {
                    success(request: response.request, response: response.response, json: json)
                } else {
                    success(request: response.request, response: response.response, json: [NSObject: AnyObject]())
                }
            case .Failure(let error):
                failure(request: response.request, response: response.response, error: error)
            }
    }
}
