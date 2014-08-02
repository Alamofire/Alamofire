// DataTaskDelegate.swift
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

internal class DataTaskDelegate: TaskDelegate {
    
    var dataTask: NSURLSessionDataTask! { return self.task as NSURLSessionDataTask }
    
    private var mutableData: NSMutableData
    override var data: NSData! {
        return self.mutableData
    }
    
    var dataTaskDidReceiveResponse: ((NSURLSession!, NSURLSessionDataTask!, NSURLResponse!) -> (NSURLSessionResponseDisposition))?
    var dataTaskDidBecomeDownloadTask: ((NSURLSession!, NSURLSessionDataTask!) -> Void)?
    var dataTaskDidReceiveData: ((NSURLSession!, NSURLSessionDataTask!, NSData!) -> Void)?
    var dataTaskWillCacheResponse: ((NSURLSession!, NSURLSessionDataTask!, NSCachedURLResponse!) -> (NSCachedURLResponse))?
    
    init(task: NSURLSessionTask) {
        self.mutableData = NSMutableData()
        super.init(task: task)
    }
    
}

// MARK: NSURLSessionDataDelegate

extension DataTaskDelegate: NSURLSessionDataDelegate {

    func URLSession(session: NSURLSession!, dataTask: NSURLSessionDataTask!, didReceiveResponse response: NSURLResponse!, completionHandler: ((NSURLSessionResponseDisposition) -> Void)!) {
        var disposition: NSURLSessionResponseDisposition = .Allow
        
        if self.dataTaskDidReceiveResponse {
            disposition = self.dataTaskDidReceiveResponse!(session, dataTask, response)
        }
        
        completionHandler(disposition)
    }
    
    func URLSession(session: NSURLSession!, dataTask: NSURLSessionDataTask!, didBecomeDownloadTask downloadTask: NSURLSessionDownloadTask!) {
        self.dataTaskDidBecomeDownloadTask?(session, dataTask)
    }
    
    func URLSession(session: NSURLSession!, dataTask: NSURLSessionDataTask!, didReceiveData data: NSData!) {
        self.dataTaskDidReceiveData?(session, dataTask, data)
        
        self.mutableData.appendData(data)
    }
    
    func URLSession(session: NSURLSession!, dataTask: NSURLSessionDataTask!, willCacheResponse proposedResponse: NSCachedURLResponse!, completionHandler: ((NSCachedURLResponse!) -> Void)!) {
        var cachedResponse = proposedResponse
        
        if self.dataTaskWillCacheResponse {
            cachedResponse = self.dataTaskWillCacheResponse!(session, dataTask, proposedResponse)
        }
        
        completionHandler(cachedResponse)
    }
    
}

