// Manager.swift
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

public class Manager {
    
    public class var sharedInstance: Manager {
        struct Singleton {
            static let instance = Manager()
        }
        
        return Singleton.instance
    }
    
    public let delegate: SessionDelegate
    public let session: NSURLSession!
    public let operationQueue: NSOperationQueue = NSOperationQueue()
    
    public var automaticallyStartsRequests: Bool = true
    
    public lazy var defaultHeaders: [String: String] = {
        // Accept-Language HTTP Header; see http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.3
        let acceptEncoding: String = "gzip;q=1.0,compress;q=0.5"
        
        // Accept-Language HTTP Header; see http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.4
        let acceptLanguage: String = {
            var components: [String] = []
            for (index, languageCode) in enumerate(NSLocale.preferredLanguages() as [String]) {
                let q = 1.0 - (Double(index) * 0.1)
                components.append("\(languageCode);q=\(q)")
                if q <= 0.5 {
                    break
                }
            }
            
            return components.reduce("", {$0 == "" ? $1 : "\($0),\($1)"})
            }()
        
        // User-Agent Header; see http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.43
        let userAgent: String = {
            if let info = NSBundle.mainBundle().infoDictionary {
                let executable: AnyObject? = info[kCFBundleExecutableKey]
                let bundle: AnyObject? = info[kCFBundleIdentifierKey]
                let version: AnyObject? = info[kCFBundleVersionKey]
                let os: AnyObject? = NSProcessInfo.processInfo()?.operatingSystemVersionString
                
                var mutableUserAgent = NSMutableString(string: "\(executable!)/\(bundle!) (\(version!); OS \(os!))") as CFMutableString
                let transform = NSString(string: "Any-Latin; Latin-ASCII; [:^ASCII:] Remove") as CFString
                if CFStringTransform(mutableUserAgent, nil, transform, 0) == 1 {
                    return mutableUserAgent as NSString
                }
            }
            
            return "Alamofire"
            }()
        
        return ["Accept-Encoding": acceptEncoding,
            "Accept-Language": acceptLanguage,
            "User-Agent": userAgent]
        }()
    
    public init(configuration: NSURLSessionConfiguration! = nil) {
        self.delegate = SessionDelegate()
        self.session = NSURLSession(configuration: configuration, delegate: self.delegate, delegateQueue: self.operationQueue)
    }
    
    deinit {
        self.session.invalidateAndCancel()
    }
    
    // MARK: -
    
    public func request(request: NSURLRequest) -> Request {
        var mutableRequest: NSMutableURLRequest! = request.mutableCopy() as NSMutableURLRequest
        
        for (field, value) in self.defaultHeaders {
            if !mutableRequest.valueForHTTPHeaderField(field){
                mutableRequest.setValue(value, forHTTPHeaderField: field)
            }
        }
        
        var dataTask: NSURLSessionDataTask?
        dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            dataTask = self.session.dataTaskWithRequest(mutableRequest)
        }
        
        let request = Request(session: self.session, task: dataTask!)
        self.delegate[request.delegate.task] = request.delegate
        request.resume()
        
        return request
    }

}

// MARK: - Upload

extension Manager {
    
    private enum Uploadable {
        case Data(NSURLRequest, NSData)
        case File(NSURLRequest, NSURL)
        case Stream(NSURLRequest, NSInputStream)
    }
    
    private func upload(uploadable: Uploadable) -> Request {
        var uploadTask: NSURLSessionUploadTask!
        var stream: NSInputStream?
        
        switch uploadable {
        case .Data(let request, let data):
            uploadTask = self.session.uploadTaskWithRequest(request, fromData: data)
        case .File(let request, let fileURL):
            uploadTask = self.session.uploadTaskWithRequest(request, fromFile: fileURL)
        case .Stream(let request, var stream):
            uploadTask = self.session.uploadTaskWithStreamedRequest(request)
        }
        
        let request = Request(session: self.session, task: uploadTask)
        if stream != nil {
            request.delegate.taskNeedNewBodyStream = { _, _ in
                return stream
            }
        }
        self.delegate[request.delegate.task] = request.delegate
        
        if self.automaticallyStartsRequests {
            request.resume()
        }
        
        return request
    }
    
    // MARK: File
    
    public func upload(request: NSURLRequest, file: NSURL) -> Request {
        return upload(.File(request, file))
    }
    
    // MARK: Data
    
    public func upload(request: NSURLRequest, data: NSData) -> Request {
        return upload(.Data(request, data))
    }
    
    // MARK: Stream
    
    public func upload(request: NSURLRequest, stream: NSInputStream) -> Request {
        return upload(.Stream(request, stream))
    }
    
}

// MARK: - Download

extension Manager {
    
    private enum Downloadable {
        case Request(NSURLRequest)
        case ResumeData(NSData)
    }
    
    private func download(downloadable: Downloadable, destination: (NSURL, NSHTTPURLResponse) -> (NSURL)) -> Request {
        var downloadTask: NSURLSessionDownloadTask!
        
        switch downloadable {
        case .Request(let request):
            downloadTask = self.session.downloadTaskWithRequest(request)
        case .ResumeData(let resumeData):
            downloadTask = self.session.downloadTaskWithResumeData(resumeData)
        }
        
        let request = Request(session: self.session, task: downloadTask)
        if let downloadDelegate = request.delegate as? DownloadTaskDelegate {
            downloadDelegate.downloadTaskDidFinishDownloadingToURL = { (session, downloadTask, URL) in
                return destination(URL, downloadTask.response as NSHTTPURLResponse)
            }
        }
        self.delegate[request.delegate.task] = request.delegate
        
        if self.automaticallyStartsRequests {
            request.resume()
        }
        
        return request
    }
    
    // MARK: Request
    
    public func download(request: NSURLRequest, destination: (NSURL, NSHTTPURLResponse) -> (NSURL)) -> Request {
        return download(.Request(request), destination: destination)
    }
    
    // MARK: Resume Data
    
    public func download(resumeData: NSData, destination: (NSURL, NSHTTPURLResponse) -> (NSURL)) -> Request {
        return download(.ResumeData(resumeData), destination: destination)
    }
    
}
