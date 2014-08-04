// DownloadTaskDelegate.swift
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

internal class DownloadTaskDelegate: TaskDelegate {
    
    var downloadTask: NSURLSessionDownloadTask! { return self.task as NSURLSessionDownloadTask }
    var downloadProgress: ((Int64, Int64, Int64) -> Void)?
    
    var resumeData: NSData!
    override var data: NSData! { return self.resumeData }
    
    var downloadTaskDidFinishDownloadingToURL: ((NSURLSession!, NSURLSessionDownloadTask!, NSURL) -> (NSURL))?
    var downloadTaskDidWriteData: ((NSURLSession!, NSURLSessionDownloadTask!, Int64, Int64, Int64) -> Void)?
    var downloadTaskDidResumeAtOffset: ((NSURLSession!, NSURLSessionDownloadTask!, Int64, Int64) -> Void)?
    
    required init(task: NSURLSessionTask) {
        super.init(task: task)
    }
    
}

// MARK: NSURLSessionDownloadDelegate

extension DownloadTaskDelegate: NSURLSessionDownloadDelegate {

    func URLSession(session: NSURLSession!, downloadTask: NSURLSessionDownloadTask!, didFinishDownloadingToURL location: NSURL!) {
        if self.downloadTaskDidFinishDownloadingToURL != nil {
            let destination = self.downloadTaskDidFinishDownloadingToURL!(session, downloadTask, location)
            var fileManagerError: NSError?
            
            NSFileManager.defaultManager().moveItemAtURL(location, toURL: destination, error: &fileManagerError)
            // TODO: NSNotification on failure
        }
    }
    
    func URLSession(session: NSURLSession!, downloadTask: NSURLSessionDownloadTask!, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        self.downloadTaskDidWriteData?(session, downloadTask, bytesWritten, totalBytesWritten, totalBytesExpectedToWrite)
        
        self.downloadProgress?(bytesWritten, totalBytesWritten, totalBytesExpectedToWrite)
        
        self.progress.totalUnitCount = totalBytesExpectedToWrite
        self.progress.completedUnitCount = totalBytesWritten
    }
    
    func URLSession(session: NSURLSession!, downloadTask: NSURLSessionDownloadTask!, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        self.downloadTaskDidResumeAtOffset?(session, downloadTask, fileOffset, expectedTotalBytes)
        
        self.progress.totalUnitCount = expectedTotalBytes
        self.progress.completedUnitCount = fileOffset
    }
}
