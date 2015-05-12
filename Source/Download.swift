// Alamofire.swift
//
// Copyright (c) 2014–2015 Alamofire Software Foundation (http://alamofire.org/)
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

extension Manager {
    private enum Downloadable {
        case Request(NSURLRequest)
        case ResumeData(NSData)
    }

    private func download(downloadable: Downloadable, destination: Request.DownloadFileDestination) -> Request {
        var downloadTask: NSURLSessionDownloadTask!

        switch downloadable {
        case .Request(let request):
            dispatch_sync(queue) {
                downloadTask = self.session.downloadTaskWithRequest(request)
            }
        case .ResumeData(let resumeData):
            dispatch_sync(queue) {
                downloadTask = self.session.downloadTaskWithResumeData(resumeData)
            }
        }

        let request = Request(session: session, task: downloadTask)
        if let downloadDelegate = request.delegate as? Request.DownloadTaskDelegate {
            downloadDelegate.downloadTaskDidFinishDownloadingToURL = { session, downloadTask, URL in
                return destination(URL, downloadTask.response as! NSHTTPURLResponse)
            }
        }
        delegate[request.delegate.task] = request.delegate

        if startRequestsImmediately {
            request.resume()
        }

        return request
    }

    // MARK: Request

    /**
        Creates a download request using the shared manager instance for the specified method and URL string.

        :param: method The HTTP method.
        :param: URLString The URL string.
        :param: destination The closure used to determine the destination of the downloaded file.

        :returns: The created download request.
    */
    public func download(method: Method, _ URLString: URLStringConvertible, destination: Request.DownloadFileDestination) -> Request {
        return download(URLRequest(method, URLString), destination: destination)
    }

    /**
        Creates a request for downloading from the specified URL request.

        If `startRequestsImmediately` is `true`, the request will have `resume()` called before being returned.

        :param: URLRequest The URL request
        :param: destination The closure used to determine the destination of the downloaded file.

        :returns: The created download request.
    */
    public func download(URLRequest: URLRequestConvertible, destination: Request.DownloadFileDestination) -> Request {
        return download(.Request(URLRequest.URLRequest), destination: destination)
    }

    // MARK: Resume Data

    /**
        Creates a request for downloading from the resume data produced from a previous request cancellation.

        If `startRequestsImmediately` is `true`, the request will have `resume()` called before being returned.

        :param: resumeData The resume data. This is an opaque data blob produced by `NSURLSessionDownloadTask` when a task is cancelled. See `NSURLSession -downloadTaskWithResumeData:` for additional information.
        :param: destination The closure used to determine the destination of the downloaded file.

        :returns: The created download request.
    */
    public func download(resumeData: NSData, destination: Request.DownloadFileDestination) -> Request {
        return download(.ResumeData(resumeData), destination: destination)
    }
}

// MARK: -

extension Request {
    /**
        A closure executed once a request has successfully completed in order to determine where to move the temporary file written to during the download process. The closure takes two arguments: the temporary file URL and the URL response, and returns a single argument: the file URL where the temporary file should be moved.
    */
    public typealias DownloadFileDestination = (NSURL, NSHTTPURLResponse) -> NSURL

    /**
        Creates a download file destination closure which uses the default file manager to move the temporary file to a file URL in the first available directory with the specified search path directory and search path domain mask.

        :param: directory The search path directory. `.DocumentDirectory` by default.
        :param: domain The search path domain mask. `.UserDomainMask` by default.

        :returns: A download file destination closure.
    */
    public class func suggestedDownloadDestination(directory: NSSearchPathDirectory = .DocumentDirectory, domain: NSSearchPathDomainMask = .UserDomainMask) -> DownloadFileDestination {

        return { (temporaryURL, response) -> (NSURL) in
            if let directoryURL = NSFileManager.defaultManager().URLsForDirectory(directory, inDomains: domain)[0] as? NSURL {
                return directoryURL.URLByAppendingPathComponent(response.suggestedFilename!)
            }

            return temporaryURL
        }
    }

    // MARK: - DownloadTaskDelegate

    class DownloadTaskDelegate: TaskDelegate, NSURLSessionDownloadDelegate {
        var downloadTask: NSURLSessionDownloadTask? { return task as? NSURLSessionDownloadTask }
        var downloadProgress: ((Int64, Int64, Int64) -> Void)?

        var resumeData: NSData?
        override var data: NSData? { return resumeData }

        // MARK: - NSURLSessionDownloadDelegate

        // MARK: Override Closures

        var downloadTaskDidFinishDownloadingToURL: ((NSURLSession, NSURLSessionDownloadTask, NSURL) -> NSURL)?
        var downloadTaskDidWriteData: ((NSURLSession, NSURLSessionDownloadTask, Int64, Int64, Int64) -> Void)?
        var downloadTaskDidResumeAtOffset: ((NSURLSession, NSURLSessionDownloadTask, Int64, Int64) -> Void)?

        // MARK: Delegate Methods

        func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didFinishDownloadingToURL location: NSURL) {
            if downloadTaskDidFinishDownloadingToURL != nil {
                let destination = downloadTaskDidFinishDownloadingToURL!(session, downloadTask, location)
                var fileManagerError: NSError?

                NSFileManager.defaultManager().moveItemAtURL(location, toURL: destination, error: &fileManagerError)

                if fileManagerError != nil {
                    error = fileManagerError
                }
            }
        }

        func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
            if downloadTaskDidWriteData != nil {
                downloadTaskDidWriteData!(session, downloadTask, bytesWritten, totalBytesWritten, totalBytesExpectedToWrite)
            } else {
                progress.totalUnitCount = totalBytesExpectedToWrite
                progress.completedUnitCount = totalBytesWritten

                downloadProgress?(bytesWritten, totalBytesWritten, totalBytesExpectedToWrite)
            }
        }

        func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
            if downloadTaskDidResumeAtOffset != nil {
                downloadTaskDidResumeAtOffset!(session, downloadTask, fileOffset, expectedTotalBytes)
            } else {
                progress.totalUnitCount = expectedTotalBytes
                progress.completedUnitCount = fileOffset
            }
        }
    }
}
