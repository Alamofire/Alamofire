//
//  SessionManager.swift
//
//  Copyright (c) 2014-2016 Alamofire Software Foundation (http://alamofire.org/)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation

/// Responsible for creating and managing `Request` objects, as well as their underlying `NSURLSession`.
public class SessionManager {

    // MARK: - Helper Types

    /// Defines whether the `MultipartFormData` encoding was successful and contains result of the encoding as
    /// associated values.
    ///
    /// - Success: Represents a successful `MultipartFormData` encoding and contains the new `Request` along with
    ///            streaming information.
    /// - Failure: Used to represent a failure in the `MultipartFormData` encoding and also contains the encoding
    ///            error.
    public enum MultipartFormDataEncodingResult {
        case success(request: Request, streamingFromDisk: Bool, streamFileURL: URL?)
        case failure(Error)
    }

    private enum Downloadable {
        case request(URLRequest)
        case resumeData(Data)
    }

    private enum Uploadable {
        case data(URLRequest, Data)
        case file(URLRequest, URL)
        case stream(URLRequest, InputStream)
    }

    private enum Streamable {
        case stream(String, Int)
        case netService(NetService)
    }

    // MARK: - Properties

    /// A default instance of `SessionManager`, used by top-level Alamofire request methods, and suitable for use
    /// directly for any ad hoc requests.
    public static let `default`: SessionManager = {
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = SessionManager.defaultHTTPHeaders

        return SessionManager(configuration: configuration)
    }()

    /// Creates default values for the "Accept-Encoding", "Accept-Language" and "User-Agent" headers.
    public static let defaultHTTPHeaders: [String: String] = {
        // Accept-Encoding HTTP Header; see https://tools.ietf.org/html/rfc7230#section-4.2.3
        let acceptEncoding: String = "gzip;q=1.0, compress;q=0.5"

        // Accept-Language HTTP Header; see https://tools.ietf.org/html/rfc7231#section-5.3.5
        let acceptLanguage = Locale.preferredLanguages.prefix(6).enumerated().map { index, languageCode in
            let quality = 1.0 - (Double(index) * 0.1)
            return "\(languageCode);q=\(quality)"
        }.joined(separator: ", ")

        // User-Agent Header; see https://tools.ietf.org/html/rfc7231#section-5.5.3
        let userAgent: String = {
            if let info = Bundle.main.infoDictionary {
                let executable = info[kCFBundleExecutableKey as String] as? String ?? "Unknown"
                let bundle = info[kCFBundleIdentifierKey as String] as? String ?? "Unknown"
                let version = info[kCFBundleVersionKey as String] as? String ?? "Unknown"

                let osNameVersion: String = {
                    let version = ProcessInfo.processInfo.operatingSystemVersion
                    let versionString = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"

                    let osName: String = {
                        #if os(iOS)
                            return "iOS"
                        #elseif os(watchOS)
                            return "watchOS"
                        #elseif os(tvOS)
                            return "tvOS"
                        #elseif os(OSX)
                            return "OS X"
                        #elseif os(Linux)
                            return "Linux"
                        #else
                            return "Unknown"
                        #endif
                    }()

                    return "\(osName) \(versionString)"
                }()

                return "\(executable)/\(bundle) (\(version); \(osNameVersion))"
            }

            return "Alamofire"
        }()

        return [
            "Accept-Encoding": acceptEncoding,
            "Accept-Language": acceptLanguage,
            "User-Agent": userAgent
        ]
    }()

    /// Default memory threshold used when encoding `MultipartFormData`.
    public static let multipartFormDataEncodingMemoryThreshold: UInt64 = 10 * 1024 * 1024

    /// The underlying session.
    public let session: URLSession

    /// The session delegate handling all the task and session delegate callbacks.
    public let delegate: SessionDelegate

    /// Whether to start requests immediately after being constructed. `true` by default.
    public var startRequestsImmediately: Bool = true

    /// The background completion handler closure provided by the UIApplicationDelegate
    /// `application:handleEventsForBackgroundURLSession:completionHandler:` method. By setting the background
    /// completion handler, the SessionDelegate `sessionDidFinishEventsForBackgroundURLSession` closure implementation
    /// will automatically call the handler.
    ///
    /// If you need to handle your own events before the handler is called, then you need to override the
    /// SessionDelegate `sessionDidFinishEventsForBackgroundURLSession` and manually call the handler when finished.
    ///
    /// `nil` by default.
    public var backgroundCompletionHandler: (() -> Void)?

    let queue = DispatchQueue(label: "Alamofire Session Manager Queue")

    // MARK: - Lifecycle

    /// Initializes the `SessionManager` instance with the specified configuration, delegate and server trust policy.
    ///
    /// - parameter configuration:            The configuration used to construct the managed session.
    ///                                       `NSURLSessionConfiguration.defaultSessionConfiguration()` by default.
    /// - parameter delegate:                 The delegate used when initializing the session. `SessionDelegate()` by
    ///                                       default.
    /// - parameter serverTrustPolicyManager: The server trust policy manager to use for evaluating all server trust
    ///                                       challenges. `nil` by default.
    ///
    /// - returns: The new `SessionManager` instance.
    public init(
        configuration: URLSessionConfiguration = URLSessionConfiguration.default,
        delegate: SessionDelegate = SessionDelegate(),
        serverTrustPolicyManager: ServerTrustPolicyManager? = nil)
    {
        self.delegate = delegate
        self.session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)

        commonInit(serverTrustPolicyManager: serverTrustPolicyManager)
    }

    /// Initializes the `SessionManager` instance with the specified session, delegate and server trust policy.
    ///
    /// - parameter session:                  The URL session.
    /// - parameter delegate:                 The delegate of the URL session. Must equal the URL session's delegate.
    /// - parameter serverTrustPolicyManager: The server trust policy manager to use for evaluating all server trust
    ///                                       challenges. `nil` by default.
    ///
    /// - returns: The new `SessionManager` instance if the URL session's delegate matches the delegate parameter.
    public init?(
        session: URLSession,
        delegate: SessionDelegate,
        serverTrustPolicyManager: ServerTrustPolicyManager? = nil)
    {
        guard delegate === session.delegate else { return nil }

        self.delegate = delegate
        self.session = session

        commonInit(serverTrustPolicyManager: serverTrustPolicyManager)
    }

    private func commonInit(serverTrustPolicyManager: ServerTrustPolicyManager?) {
        session.serverTrustPolicyManager = serverTrustPolicyManager

        delegate.sessionDidFinishEventsForBackgroundURLSession = { [weak self] session in
            guard let strongSelf = self else { return }
            DispatchQueue.main.async { strongSelf.backgroundCompletionHandler?() }
        }
    }

    deinit {
        session.invalidateAndCancel()
    }

    // MARK: - Data Request

    /// Creates a data request for the specified method, URL string, parameters, parameter encoding and headers.
    ///
    /// - parameter method:     The HTTP method.
    /// - parameter urlString:  The URL string.
    /// - parameter parameters: The parameters. `nil` by default.
    /// - parameter encoding:   The parameter encoding. `.URL` by default.
    /// - parameter headers:    The HTTP headers. `nil` by default.
    ///
    /// - returns: The created data request.
    @discardableResult
    public func dataRequest(
        method: Method,
        urlString: URLStringConvertible,
        parameters: [String: AnyObject]? = nil,
        encoding: ParameterEncoding = .url,
        headers: [String: String]? = nil)
        -> Request
    {
        let urlRequest = URLRequest(method: method, urlString: urlString, headers: headers)
        let encodedURLRequest = encoding.encode(urlRequest, parameters: parameters).0

        return dataRequest(urlRequest: encodedURLRequest)
    }

    /// Creates a data request for the specified URL request.
    ///
    /// If `startRequestsImmediately` is `true`, the request will have `resume()` called before being returned.
    ///
    /// - parameter urlRequest: The URL request
    ///
    /// - returns: The created data request.
    public func dataRequest(urlRequest: URLRequestConvertible) -> Request {
        var dataTask: URLSessionDataTask!
        queue.sync { dataTask = self.session.dataTask(with: urlRequest.urlRequest) }

        let request = Request(session: session, task: dataTask)
        delegate[request.delegate.task] = request.delegate

        if startRequestsImmediately {
            request.resume()
        }

        return request
    }

    // MARK: - Download Request

    // MARK: URL Request

    /// Creates a download request for the specified method, URL string, parameters, parameter encoding, headers
    /// and destination.
    ///
    /// If `startRequestsImmediately` is `true`, the request will have `resume()` called before being returned.
    ///
    /// - parameter method:      The HTTP method.
    /// - parameter urlString:   The URL string.
    /// - parameter parameters:  The parameters. `nil` by default.
    /// - parameter encoding:    The parameter encoding. `.URL` by default.
    /// - parameter headers:     The HTTP headers. `nil` by default.
    /// - parameter destination: The closure used to determine the destination of the downloaded file.
    ///
    /// - returns: The created download request.
    @discardableResult
    public func downloadRequest(
        method: Method,
        urlString: URLStringConvertible,
        parameters: [String: AnyObject]? = nil,
        encoding: ParameterEncoding = .url,
        headers: [String: String]? = nil,
        destination: Request.DownloadFileDestination)
        -> Request
    {
        let urlRequest = URLRequest(method: method, urlString: urlString, headers: headers)
        let encodedURLRequest = encoding.encode(urlRequest, parameters: parameters).0

        return downloadRequest(urlRequest: encodedURLRequest, destination: destination)
    }

    /// Creates a request for downloading from the specified URL request.
    ///
    /// If `startRequestsImmediately` is `true`, the request will have `resume()` called before being returned.
    ///
    /// - parameter urlRequest:  The URL request
    /// - parameter destination: The closure used to determine the destination of the downloaded file.
    ///
    /// - returns: The created download request.
    @discardableResult
    public func downloadRequest(
        urlRequest: URLRequestConvertible,
        destination: Request.DownloadFileDestination)
        -> Request
    {
        return downloadRequest(downloadable: .request(urlRequest.urlRequest), destination: destination)
    }

    // MARK: Resume Data

    /// Creates a request for downloading from the resume data produced from a previous request cancellation.
    ///
    /// If `startRequestsImmediately` is `true`, the request will have `resume()` called before being returned.
    ///
    /// - parameter resumeData:  The resume data. This is an opaque data blob produced by `NSURLSessionDownloadTask`
    ///                          when a task is cancelled. See `NSURLSession -downloadTaskWithResumeData:` for
    ///                          additional information.
    /// - parameter destination: The closure used to determine the destination of the downloaded file.
    ///
    /// - returns: The created download request.
    @discardableResult
    public func downloadRequest(resumeData data: Data, destination: Request.DownloadFileDestination) -> Request {
        return downloadRequest(downloadable: .resumeData(data), destination: destination)
    }

    // MARK: Private - Download Implementation

    private func downloadRequest(downloadable: Downloadable, destination: Request.DownloadFileDestination) -> Request {
        var downloadTask: URLSessionDownloadTask!

        switch downloadable {
        case .request(let request):
            queue.sync {
                downloadTask = self.session.downloadTask(with: request)
            }
        case .resumeData(let resumeData):
            queue.sync {
                downloadTask = self.session.downloadTask(withResumeData: resumeData)
            }
        }

        let request = Request(session: session, task: downloadTask)

        if let downloadDelegate = request.delegate as? DownloadTaskDelegate {
            downloadDelegate.downloadTaskDidFinishDownloadingToURL = { session, downloadTask, URL in
                return destination(URL, downloadTask.response as! HTTPURLResponse)
            }
        }

        delegate[request.delegate.task] = request.delegate

        if startRequestsImmediately {
            request.resume()
        }

        return request
    }

    // MARK: - Upload Request

    // MARK: File

    /// Creates a request for uploading a file to the specified URL request.
    ///
    /// If `startRequestsImmediately` is `true`, the request will have `resume()` called before being returned.
    ///
    /// - parameter method:    The HTTP method.
    /// - parameter urlString: The URL string.
    /// - parameter headers:   The HTTP headers. `nil` by default.
    /// - parameter file:      The file to upload
    ///
    /// - returns: The created upload request.
    @discardableResult
    public func uploadRequest(
        method: Method,
        urlString: URLStringConvertible,
        headers: [String: String]? = nil,
        file: URL)
        -> Request
    {
        let urlRequest = URLRequest(method: method, urlString: urlString, headers: headers)
        return uploadRequest(urlRequest: urlRequest, file: file)
    }

    /// Creates a request for uploading a file to the specified URL request.
    ///
    /// If `startRequestsImmediately` is `true`, the request will have `resume()` called before being returned.
    ///
    /// - parameter urlRequest: The URL request
    /// - parameter file:       The file to upload
    ///
    /// - returns: The created upload request.
    @discardableResult
    public func uploadRequest(urlRequest: URLRequestConvertible, file: URL) -> Request {
        return uploadRequest(uploadable: .file(urlRequest.urlRequest as URLRequest, file))
    }

    // MARK: Data

    /// Creates a request for uploading data to the specified URL request.
    ///
    /// If `startRequestsImmediately` is `true`, the request will have `resume()` called before being returned.
    ///
    /// - parameter method:    The HTTP method.
    /// - parameter URLString: The URL string.
    /// - parameter headers:   The HTTP headers. `nil` by default.
    /// - parameter data:      The data to upload
    ///
    /// - returns: The created upload request.
    @discardableResult
    public func uploadRequest(
        method: Method,
        urlString: URLStringConvertible,
        headers: [String: String]? = nil,
        data: Data)
        -> Request
    {
        let urlRequest = URLRequest(method: method, urlString: urlString, headers: headers)
        return uploadRequest(urlRequest: urlRequest, data: data)
    }

    /// Creates a request for uploading data to the specified URL request.
    ///
    /// If `startRequestsImmediately` is `true`, the request will have `resume()` called before being returned.
    ///
    /// - parameter urlRequest: The URL request.
    /// - parameter data:       The data to upload.
    ///
    /// - returns: The created upload request.
    @discardableResult
    public func uploadRequest(urlRequest: URLRequestConvertible, data: Data) -> Request {
        return uploadRequest(uploadable: .data(urlRequest.urlRequest as URLRequest, data))
    }

    // MARK: InputStream

    /// Creates a request for uploading a stream to the specified URL request.
    ///
    /// If `startRequestsImmediately` is `true`, the request will have `resume()` called before being returned.
    ///
    /// - parameter method:    The HTTP method.
    /// - parameter urlString: The URL string.
    /// - parameter headers:   The HTTP headers. `nil` by default.
    /// - parameter stream:    The stream to upload.
    ///
    /// - returns: The created upload request.
    @discardableResult
    public func uploadRequest(
        method: Method,
        urlString: URLStringConvertible,
        headers: [String: String]? = nil,
        stream: InputStream)
        -> Request
    {
        let urlRequest = URLRequest(method: method, urlString: urlString, headers: headers)
        return uploadRequest(urlRequest: urlRequest, stream: stream)
    }

    /// Creates a request for uploading a stream to the specified URL request.
    ///
    /// If `startRequestsImmediately` is `true`, the request will have `resume()` called before being returned.
    ///
    /// - parameter URLRequest: The URL request.
    /// - parameter stream:     The stream to upload.
    ///
    /// - returns: The created upload request.
    @discardableResult
    public func uploadRequest(urlRequest: URLRequestConvertible, stream: InputStream) -> Request {
        return uploadRequest(uploadable: .stream(urlRequest.urlRequest as URLRequest, stream))
    }

    // MARK: MultipartFormData

    /// Encodes the `MultipartFormData` and creates a request to upload the result to the specified URL request.
    ///
    /// It is important to understand the memory implications of uploading `MultipartFormData`. If the cummulative
    /// payload is small, encoding the data in-memory and directly uploading to a server is the by far the most
    /// efficient approach. However, if the payload is too large, encoding the data in-memory could cause your app to
    /// be terminated. Larger payloads must first be written to disk using input and output streams to keep the memory
    /// footprint low, then the data can be uploaded as a stream from the resulting file. Streaming from disk MUST be
    /// used for larger payloads such as video content.
    ///
    /// The `encodingMemoryThreshold` parameter allows Alamofire to automatically determine whether to encode in-memory
    /// or stream from disk. If the content length of the `MultipartFormData` is below the `encodingMemoryThreshold`,
    /// encoding takes place in-memory. If the content length exceeds the threshold, the data is streamed to disk
    /// during the encoding process. Then the result is uploaded as data or as a stream depending on which encoding
    /// technique was used.
    ///
    /// If `startRequestsImmediately` is `true`, the request will have `resume()` called before being returned.
    ///
    /// - parameter method:                  The HTTP method.
    /// - parameter urlString:               The URL string.
    /// - parameter headers:                 The HTTP headers. `nil` by default.
    /// - parameter multipartFormData:       The closure used to append body parts to the `MultipartFormData`.
    /// - parameter encodingMemoryThreshold: The encoding memory threshold in bytes.
    ///                                      `multipartFormDataEncodingMemoryThreshold` by default.
    /// - parameter encodingCompletion:      The closure called when the `MultipartFormData` encoding is complete.
    public func uploadRequest(
        method: Method,
        urlString: URLStringConvertible,
        headers: [String: String]? = nil,
        multipartFormData: (MultipartFormData) -> Void,
        encodingMemoryThreshold: UInt64 = SessionManager.multipartFormDataEncodingMemoryThreshold,
        encodingCompletion: ((MultipartFormDataEncodingResult) -> Void)?)
    {
        let urlRequest = URLRequest(method: method, urlString: urlString, headers: headers)

        return uploadRequest(
            urlRequest: urlRequest,
            multipartFormData: multipartFormData,
            encodingMemoryThreshold: encodingMemoryThreshold,
            encodingCompletion: encodingCompletion
        )
    }

    /// Encodes the `MultipartFormData` and creates a request to upload the result to the specified URL request.
    ///
    /// It is important to understand the memory implications of uploading `MultipartFormData`. If the cummulative
    /// payload is small, encoding the data in-memory and directly uploading to a server is the by far the most
    /// efficient approach. However, if the payload is too large, encoding the data in-memory could cause your app to
    /// be terminated. Larger payloads must first be written to disk using input and output streams to keep the memory
    /// footprint low, then the data can be uploaded as a stream from the resulting file. Streaming from disk MUST be
    /// used for larger payloads such as video content.
    ///
    /// The `encodingMemoryThreshold` parameter allows Alamofire to automatically determine whether to encode in-memory
    /// or stream from disk. If the content length of the `MultipartFormData` is below the `encodingMemoryThreshold`,
    /// encoding takes place in-memory. If the content length exceeds the threshold, the data is streamed to disk
    /// during the encoding process. Then the result is uploaded as data or as a stream depending on which encoding
    /// technique was used.
    ///
    /// If `startRequestsImmediately` is `true`, the request will have `resume()` called before being returned.
    ///
    /// - parameter urlRequest:              The URL request.
    /// - parameter multipartFormData:       The closure used to append body parts to the `MultipartFormData`.
    /// - parameter encodingMemoryThreshold: The encoding memory threshold in bytes.
    ///                                      `multipartFormDataEncodingMemoryThreshold` by default.
    /// - parameter encodingCompletion:      The closure called when the `MultipartFormData` encoding is complete.
    public func uploadRequest(
        urlRequest: URLRequestConvertible,
        multipartFormData: (MultipartFormData) -> Void,
        encodingMemoryThreshold: UInt64 = SessionManager.multipartFormDataEncodingMemoryThreshold,
        encodingCompletion: ((MultipartFormDataEncodingResult) -> Void)?)
    {
        DispatchQueue.global(qos: .utility).async {
            let formData = MultipartFormData()
            multipartFormData(formData)

            var urlRequestWithContentType = urlRequest.urlRequest
            urlRequestWithContentType.setValue(formData.contentType, forHTTPHeaderField: "Content-Type")

            let isBackgroundSession = self.session.configuration.identifier != nil

            if formData.contentLength < encodingMemoryThreshold && !isBackgroundSession {
                do {
                    let data = try formData.encode()

                    let encodingResult = MultipartFormDataEncodingResult.success(
                        request: self.uploadRequest(urlRequest: urlRequestWithContentType, data: data),
                        streamingFromDisk: false,
                        streamFileURL: nil
                    )

                    DispatchQueue.main.async { encodingCompletion?(encodingResult) }
                } catch {
                    DispatchQueue.main.async { encodingCompletion?(.failure(error as NSError)) }
                }
            } else {
                let fileManager = FileManager.default
                let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
                let directoryURL = tempDirectoryURL.appendingPathComponent("org.alamofire.manager/multipart.form.data")
                let fileName = UUID().uuidString
                let fileURL = directoryURL.appendingPathComponent(fileName)

                do {
                    try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
                    try formData.writeEncodedDataToDisk(fileURL)

                    DispatchQueue.main.async {
                        let encodingResult = MultipartFormDataEncodingResult.success(
                            request: self.uploadRequest(urlRequest: urlRequestWithContentType, file: fileURL),
                            streamingFromDisk: true,
                            streamFileURL: fileURL
                        )
                        encodingCompletion?(encodingResult)
                    }
                } catch {
                    DispatchQueue.main.async { encodingCompletion?(.failure(error as NSError)) }
                }
            }
        }
    }

    // MARK: Private - Upload Implementation

    private func uploadRequest(uploadable: Uploadable) -> Request {
        var uploadTask: URLSessionUploadTask!
        var HTTPBodyStream: InputStream?

        switch uploadable {
        case .data(let request, let data):
            queue.sync {
                uploadTask = self.session.uploadTask(with: request, from: data)
            }
        case .file(let request, let fileURL):
            queue.sync {
                uploadTask = self.session.uploadTask(with: request, fromFile: fileURL)
            }
        case .stream(let request, let stream):
            queue.sync {
                uploadTask = self.session.uploadTask(withStreamedRequest: request)
            }

            HTTPBodyStream = stream
        }

        let request = Request(session: session, task: uploadTask)

        if HTTPBodyStream != nil {
            request.delegate.taskNeedNewBodyStream = { _, _ in
                return HTTPBodyStream
            }
        }

        delegate[request.delegate.task] = request.delegate

        if startRequestsImmediately {
            request.resume()
        }

        return request
    }

#if !os(watchOS)

    // MARK: - Stream Request

    // MARK: Hostname and Port

    /// Creates a stream request for bidirectional streaming with the given hostname and port.
    ///
    /// - parameter hostName: The hostname of the server to connect to.
    /// - parameter port:     The port of the server to connect to.
    ///
    /// - returns: The created stream request.
    @discardableResult
    public func streamRequest(hostName: String, port: Int) -> Request {
        return streamRequest(streamable: .stream(hostName, port))
    }

    // MARK: NetService

    /// Creates a request for bidirectional streaming with the given `NSNetService`.
    ///
    /// - parameter netService: The net service used to identify the endpoint.
    ///
    /// - returns: The created stream request.
    @discardableResult
    public func streamRequest(netService: NetService) -> Request {
        return streamRequest(streamable: .netService(netService))
    }

    // MARK: Private - Stream Implementation

    private func streamRequest(streamable: Streamable) -> Request {
        var streamTask: URLSessionStreamTask!

        switch streamable {
        case .stream(let hostName, let port):
            queue.sync {
                streamTask = self.session.streamTask(withHostName: hostName, port: port)
            }
        case .netService(let netService):
            queue.sync {
                streamTask = self.session.streamTask(with: netService)
            }
        }

        let request = Request(session: session, task: streamTask)

        delegate[request.delegate.task] = request.delegate

        if startRequestsImmediately {
            request.resume()
        }

        return request
    }

#endif
}
