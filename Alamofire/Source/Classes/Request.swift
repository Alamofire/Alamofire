// Request.swift
//
// Copyright (c) 2014 Alamofire (http://alamofire.org)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation

public class Request {
    internal let delegate: TaskDelegate
    
    private var session: NSURLSession
    private var task: NSURLSessionTask { return self.delegate.task }
    
    public var request: NSURLRequest! { return self.task.originalRequest }
    public var response: NSHTTPURLResponse! { return self.task.response as? NSHTTPURLResponse }
    public var progress: NSProgress? { return self.delegate.progress }
    
    internal init(session: NSURLSession, task: NSURLSessionTask) {
        self.session = session
        
        if task is NSURLSessionUploadTask {
            self.delegate = UploadTaskDelegate(task: task)
        } else if task is NSURLSessionDownloadTask {
            self.delegate = DownloadTaskDelegate(task: task)
        } else if task is NSURLSessionDataTask {
            self.delegate = DataTaskDelegate(task: task)
        } else {
            self.delegate = TaskDelegate(task: task)
        }
    }
    
    // MARK: Authentication
    
    public func authenticate(HTTPBasic user: String, password: String) -> Self {
        let credential = NSURLCredential(user: user, password: password, persistence: .ForSession)
        let protectionSpace = NSURLProtectionSpace(host: self.request.URL.host, port: 0, `protocol`: self.request.URL.scheme, realm: nil, authenticationMethod: NSURLAuthenticationMethodHTTPBasic)
        
        return authenticate(usingCredential: credential, forProtectionSpace: protectionSpace)
    }
    
    public func authenticate(usingCredential credential: NSURLCredential, forProtectionSpace protectionSpace: NSURLProtectionSpace) -> Self {
        self.session.configuration.URLCredentialStorage.setCredential(credential, forProtectionSpace: protectionSpace)
        
        return self
    }
    
    // MARK: Progress
    
    public func progress(closure: ((Int64, Int64, Int64) -> Void)? = nil) -> Self {
        if let uploadDelegate = self.delegate as? UploadTaskDelegate {
            uploadDelegate.uploadProgress = closure
        } else if let downloadDelegate = self.delegate as? DownloadTaskDelegate {
            downloadDelegate.downloadProgress = closure
        }
        
        return self
    }
    
    // MARK: Response
    
    public func response(completionHandler: (NSURLRequest, NSHTTPURLResponse?, AnyObject?, NSError?) -> Void) -> Self {
        return response({ (request, response, data, error) in
            return (data, error)
            }, completionHandler: completionHandler)
    }
    
    public func response(priority: Int = DISPATCH_QUEUE_PRIORITY_DEFAULT, queue: dispatch_queue_t? = nil, serializer: (NSURLRequest, NSHTTPURLResponse?, NSData?, NSError?) -> (AnyObject?, NSError?), completionHandler: (NSURLRequest, NSHTTPURLResponse?, AnyObject?, NSError?) -> Void) -> Self {
        dispatch_async(self.delegate.queue, {
            dispatch_async(dispatch_get_global_queue(priority, 0), {
                let (responseObject: AnyObject?, error: NSError?) = serializer(self.request, self.response, self.delegate.data, self.delegate.error)
                
                dispatch_async(queue ?? dispatch_get_main_queue(), {
                    completionHandler(self.request, self.response, responseObject, error)
                    })
                })
            })
        
        return self
    }
    
    public func suspend() {
        self.task.suspend()
    }
    
    public func resume() {
        self.task.resume()
    }
    
    public func cancel() {
        if let downloadDelegate = self.delegate as? DownloadTaskDelegate {
            downloadDelegate.downloadTask.cancelByProducingResumeData { (data) in
                downloadDelegate.resumeData = data
            }
        } else {
            self.task.cancel()
        }
    }
    
}

// MARK: - Download

extension Request {
    
    public class func suggestedDownloadDestination(directory: NSSearchPathDirectory = .DocumentDirectory, domain: NSSearchPathDomainMask = .UserDomainMask) -> (NSURL, NSHTTPURLResponse) -> (NSURL) {
        
        return { (temporaryURL, response) -> (NSURL) in
            if let directoryURL = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)[0] as? NSURL {
                return directoryURL.URLByAppendingPathComponent(response.suggestedFilename)
            }
            
            return temporaryURL
        }
    }
    
}

// MARK: - Printable

extension Request: Printable {
    
    public var description: String {
        var description = "\(self.request.HTTPMethod) \(self.request.URL)"
        if self.response {
            description += " (\(self.response?.statusCode))"
        }
        
        return description
    }
    
}

extension Request: DebugPrintable {
    
    private func cURLRepresentation() -> String {
        var components: [String] = ["$ curl -i"]
        
        let URL = self.request.URL!
        
        if self.request.HTTPMethod != "GET" {
            components.append("-X \(self.request.HTTPMethod)")
        }
        
        if let credentialStorage = self.session.configuration.URLCredentialStorage {
            let protectionSpace = NSURLProtectionSpace(host: URL.host, port: URL.port ? URL.port : 0, `protocol`: URL.scheme, realm: URL.host, authenticationMethod: NSURLAuthenticationMethodHTTPBasic)
            if let credentials = credentialStorage.credentialsForProtectionSpace(protectionSpace)?.values.array {
                if !credentials.isEmpty {
                    if let credential = credentials[0] as? NSURLCredential {
                        components.append("-u \(credential.user):\(credential.password)")
                    }
                }
            }
        }
        
        if let cookieStorage = self.session.configuration.HTTPCookieStorage {
            if let cookies = cookieStorage.cookiesForURL(URL) as? [NSHTTPCookie] {
                if !cookies.isEmpty {
                    let string = cookies.reduce(""){ $0 + "\($1.name)=\($1.value);" }
                    components.append("-b \"\(string.substringToIndex(string.endIndex.predecessor()))\"")
                }
            }
        }
        
        for (field, value) in self.request.allHTTPHeaderFields {
            switch field {
            case "Cookie":
                continue
            default:
                components.append("-H \"\(field): \(value)\"")
            }
        }
        
        if let HTTPBody = self.request.HTTPBody {
            components.append("-d \"\(NSString(data: HTTPBody, encoding: NSUTF8StringEncoding))\"")
        }
        
        // TODO: -T arguments for files
        
        components.append("\"\(URL.absoluteString)\"")
        
        return join(" \\\n\t", components)
    }
    
    public var debugDescription: String {
        return self.cURLRepresentation()
    }
    
}

// MARK: - Response Serializers

// MARK: String

extension Request {
    
    public class func stringResponseSerializer(encoding: NSStringEncoding = NSUTF8StringEncoding) -> (NSURLRequest, NSHTTPURLResponse?, NSData?, NSError?) -> (AnyObject?, NSError?) {
        return { (_, _, data, error) in
            let string = NSString(data: data, encoding: encoding)
            return (string, error)
        }
    }
    
    public func responseString(completionHandler: (NSURLRequest, NSHTTPURLResponse?, String?, NSError?) -> Void) -> Self {
        return responseString(completionHandler: completionHandler)
    }
    
    public func responseString(encoding: NSStringEncoding = NSUTF8StringEncoding, completionHandler: (NSURLRequest, NSHTTPURLResponse?, String?, NSError?) -> Void) -> Self  {
        return response(serializer: Request.stringResponseSerializer(encoding: encoding), completionHandler: { request, response, string, error in
            completionHandler(request, response, string as? String, error)
            })
    }
    
}

// MARK: JSON

extension Request {
    
    public class func JSONResponseSerializer(options: NSJSONReadingOptions = .AllowFragments) -> (NSURLRequest, NSHTTPURLResponse?, NSData?, NSError?) -> (AnyObject?, NSError?) {
        return { (request, response, data, error) in
            var serializationError: NSError?
            let JSON: AnyObject! = NSJSONSerialization.JSONObjectWithData(data, options: options, error: &serializationError)
            return (JSON, serializationError)
        }
    }
    
    public func responseJSON(completionHandler: (NSURLRequest, NSHTTPURLResponse?, AnyObject?, NSError?) -> Void) -> Self {
        return responseJSON(completionHandler: completionHandler)
    }
    
    public func responseJSON(options: NSJSONReadingOptions = .AllowFragments, completionHandler: (NSURLRequest, NSHTTPURLResponse?, AnyObject?, NSError?) -> Void) -> Self {
        return response(serializer: Request.JSONResponseSerializer(options: options), completionHandler: { (request, response, JSON, error) in
            completionHandler(request, response, JSON, error)
            })
    }
    
}

// MARK: Property List

extension Request {
    
    public class func propertyListResponseSerializer(options: NSPropertyListReadOptions = 0) -> (NSURLRequest, NSHTTPURLResponse?, NSData?, NSError?) -> (AnyObject?, NSError?) {
        return { (request, response, data, error) in
            var propertyListSerializationError: NSError?
            let plist: AnyObject! = NSPropertyListSerialization.propertyListWithData(data, options: options, format: nil, error: &propertyListSerializationError)
            
            return (plist, propertyListSerializationError)
        }
    }
    
    public func responsePropertyList(completionHandler: (NSURLRequest, NSHTTPURLResponse?, AnyObject?, NSError?) -> Void) -> Self {
        return responsePropertyList(completionHandler: completionHandler)
    }
    
    public func responsePropertyList(options: NSPropertyListReadOptions = 0, completionHandler: (NSURLRequest, NSHTTPURLResponse?, AnyObject?, NSError?) -> Void) -> Self {
        return response(serializer: Request.propertyListResponseSerializer(options: options), completionHandler: { (request, response, plist, error) in
            completionHandler(request, response, plist, error)
            })
    }
    
}
