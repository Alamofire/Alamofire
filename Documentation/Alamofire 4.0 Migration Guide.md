# Alamofire 4.0 Migration Guide

Alamofire 4.0 is the latest major release of Alamofire, an HTTP networking library for iOS, tvOS, macOS and watchOS written in Swift. As a major release, following Semantic Versioning conventions, 4.0 introduces API-breaking changes.

This guide is provided in order to ease the transition of existing applications using Alamofire 3.x to the latest APIs, as well as explain the design and structure of new and updated functionality.

- [Requirements](#requirements)
- [Benefits of Upgrading](#benefits-of-upgrading)
- [Breaking API Changes](#breaking-api-changes)
	- [Namespace Changes](#namespace-changes)
	- [Making Requests](#making-requests)
	- [URLStringConvertible](#urlstringconvertible)
	- [URLRequestConvertible](#urlrequestconvertible)
- [New Features](#new-features)
	- [Request Adapter](#request-adapter)
	- [Request Retrier](#request-retrier)
	- [Task Metrics](#task-metrics)
- [Updated Features](#updated-features)
	- [Errors](#errors)
	- [Parameter Encoding Protocol](#parameter-encoding-protocol)
	- [Request Subclasses](#request-subclasses)
	- [Response Validation](#response-validation)
	- [Response Serializers](#response-serializers)

## Requirements

- iOS 8.0+, macOS 10.10.0+, tvOS 9.0+ and watchOS 2.0+
- Xcode 8.1+
- Swift 3.0+

For those of you that would like to use Alamofire on macOS 10.9, please use the latest tagged 3.x release which supports both Swift 2.2 and 2.3.

## Benefits of Upgrading

- **Complete Swift 3 Compatibility:** includes the full adoption of the new [API Design Guidelines](https://swift.org/documentation/api-design-guidelines/).
- **New Error System:** uses a new `AFError` type to adhere to the new pattern proposed in [SE-0112](https://github.com/apple/swift-evolution/blob/master/proposals/0112-nserror-bridging.md).
- **New RequestAdapter Protocol:** allows inspection and adaptation of every `URLRequest` before instantiating a `Request` allowing for easy modification of properties like the `Authorization` header.
- **New RequestRetrier Protocol:** allows you to inspect and retry any failed `Request` if necessary allowing you to build custom authentication solutions (OAuth1, OAuth2, xAuth, Basic Auth, etc.) around a set of requests.
- **New Parameter Encoding Protocol:** replaces the `ParameterEncoding` enumeration allowing for easier extension and customization and also throws errors on failure instead of returning a tuple.
- **New Request Types:** include `DataRequest`, `DownloadRequest`, `UploadRequest` and `StreamRequest` that implement specialized progress, validation and serialization APIs and behaviors per `Request` type.
- **New Progress APIs:** include `downloadProgress` and `uploadProgress` APIs supporting both `Progress` and `Int64` types and called on a specified dispatch queue defaulting to `.main`.
- **Enhanced Response Validation:** now includes the `data` or `temporaryURL` and `destinationURL` allowing inline closures to parse the server data for error messages if validation failed.
- **New Download Destinations:** allow you to have full control over the move operation on the file system by disabling it, removing a previous file and creating intermediate directories.
- **New Response Types:** unify response API signatures and expose `temporaryURL` and `downloadURL` properties for downloads and the all new task metrics on newer platforms.

---

## Breaking API Changes

Alamofire 4 has fully adopted all the new Swift 3 changes and conventions, including the new [API Design Guidelines](https://swift.org/documentation/api-design-guidelines/). Because of this, almost every API in Alamofire has been modified in some way. We can't possibly document every single change, so we're going to attempt to identify the most common APIs and how they have changed to help you through those sometimes less than helpful compiler errors.

### Namespace Changes

Some of the common classes have been moved into the global namespace to make them a bit easier to work with and to make them first class types.

- `Manager` is now `SessionManager`
- `Request.TaskDelegate` is now `TaskDelegate`
- `Request.DataTaskDelegate` is now `DataTaskDelegate`
- `Request.DownloadTaskDelegate` is now `DownloadTaskDelegate`
- `Request.UploadTaskDelegate` is now `UploadTaskDelegate`

We've also reorganized the file structure and organization patterns significantly to make it easier to follow the code. We hope that this will encourage more users to get to know the internal structure and implementation of Alamofire. Knowledge is power.

### Making Requests

Since making requests is certainly the most common operation in Alamofire, here are some examples of Alamofire 3.x requests compared to their new equivalents in Alamofire 4.

#### Data Request - Simple with URL string

```swift
// Alamofire 3
Alamofire.request(.GET, urlString).response { request, response, data, error in
    print(request)
    print(response)
    print(data)
    print(error)
}

// Alamofire 4
Alamofire.request(urlString).response { response in // method defaults to `.get`
    debugPrint(response)
}
```

#### Data Request - Complex with URL string

```swift
// Alamofire 3
let parameters: [String: AnyObject] = ["foo": "bar"]

Alamofire.request(.GET, urlString, parameters: parameters, encoding: .JSON)
	.progress { bytesRead, totalBytesRead, totalBytesExpectedToRead in
		print("Bytes: \(bytesRead), Total Bytes: \(totalBytesRead), Total Bytes Expected: \(totalBytesExpectedToRead)")
	}
	.validate { request, response in
		// Custom evaluation closure (no access to server data)
	    return .success
	}
    .responseJSON { response in
		debugPrint(response)
	}

// Alamofire 4
let parameters: Parameters = ["foo": "bar"]

Alamofire.request(urlString, method: .get, parameters: parameters, encoding: JSONEncoding.default)
	.downloadProgress(queue: DispatchQueue.global(qos: .utility)) { progress in
		print("Progress: \(progress.fractionCompleted)")
	}
	.validate { request, response, data in
		// Custom evaluation closure now includes data (allows you to parse data to dig out error messages if necessary)
	    return .success
	}
    .responseJSON { response in
		debugPrint(response)
	}
```

#### Download Request - Simple with URL string

```swift
// Alamofire 3
let destination = DownloadRequest.suggestedDownloadDestination()

Alamofire.download(.GET, urlString, destination: destination).response { request, response, data, error in
	// What is fileURL...not easy to get
    print(request)
    print(response)
    print(data)
    print(error)
}

// Alamofire 4
let destination = DownloadRequest.suggestedDownloadDestination()

Alamofire.download(urlString, to: destination).response { response in // method defaults to `.get`
    print(response.request)
    print(response.response)
	print(response.temporaryURL)
	print(response.destinationURL)
    print(response.error)
}
```

#### Download Request - Simple with URL request

```swift
// Alamofire 3
let destination = DownloadRequest.suggestedDownloadDestination()

Alamofire.download(urlRequest, destination: destination).validate().responseData { response in
	// What is fileURL...not easy to get
	debugPrint(response)
}

// Alamofire 4
Alamofire.download(urlRequest, to: destination).validate().responseData { response in
	debugPrint(response)
	print(response.temporaryURL)
	print(response.destinationURL)
}
```

#### Download Request - Complex with URL string

```swift
// Alamofire 3
let fileURL: NSURL
let destination: Request.DownloadFileDestination = { _, _ in fileURL }
let parameters: [String: AnyObject] = ["foo": "bar"]

Alamofire.download(.GET, urlString, parameters: parameters, encoding: .JSON, to: destination)
	.progress { bytesRead, totalBytesRead, totalBytesExpectedToRead in
		print("Bytes: \(bytesRead), Total Bytes: \(totalBytesRead), Total Bytes Expected: \(totalBytesExpectedToRead)")
	}
	.validate { request, response in
		// Custom evaluation implementation (no access to temporary or destination URLs)
	    return .success
	}
	.responseJSON { response in
		print(fileURL) // Only accessible if captured in closure scope, not ideal
		debugPrint(response)
	}

// Alamofire 4
let fileURL: URL
let destination: DownloadRequest.DownloadFileDestination = { _, _ in 
	return (fileURL, [.createIntermediateDirectories, .removePreviousFile]) 
}
let parameters: Parameters = ["foo": "bar"]

Alamofire.download(urlString, method: .get, parameters: parameters, encoding: JSONEncoding.default, to: destination)
	.downloadProgress(queue: DispatchQueue.global(qos: .utility)) { progress in
		print("Progress: \(progress.fractionCompleted)")
	}
	.validate { request, response, temporaryURL, destinationURL in
		// Custom evaluation closure now includes file URLs (allows you to parse out error messages if necessary)
	    return .success
	}
	.responseJSON { response in
		debugPrint(response)
		print(response.temporaryURL)
		print(response.destinationURL)
	}
```

#### Upload Request - Simple with URL string

```swift
// Alamofire 3
Alamofire.upload(.POST, urlString, data: data).response { request, response, data, error in
    print(request)
    print(response)
    print(data)
    print(error)
}

// Alamofire 4
Alamofire.upload(data, to: urlString).response { response in // method defaults to `.post`
    debugPrint(response)
}
```

#### Upload Request - Simple with URL request

```swift
// Alamofire 3
Alamofire.upload(urlRequest, file: fileURL).validate().responseData { response in
	debugPrint(response)
}

// Alamofire 4
Alamofire.upload(fileURL, with: urlRequest).validate().responseData { response in
	debugPrint(response)
}
```

#### Upload Request - Complex with URL string

```swift
// Alamofire 3
Alamofire.upload(.PUT, urlString, file: fileURL)
	.progress { bytes, totalBytes, totalBytesExpected in
		// Are these for upload or for downloading the response?
		print("Bytes: \(bytesRead), Total Bytes: \(totalBytesRead), Total Bytes Expected: \(totalBytesExpectedToRead)")
	}
	.validate { request, response in
		// Custom evaluation implementation (no access to server data)
	    return .success
	}
	.responseJSON { response in
		debugPrint(response)
	}

// Alamofire 4
Alamofire.upload(fileURL, to: urlString, method: .put)
	.uploadProgress(queue: DispatchQueue.global(qos: .utility)) { progress in
		print("Upload Progress: \(progress.fractionCompleted)")
	}
	.downloadProgress { progress in // called on main queue by default
		print("Download Progress: \(progress.fractionCompleted)")
	}
	.validate { request, response, data in
		// Custom evaluation closure now includes data (allows you to parse data to dig out error messages if necessary)
	    return .success
	}
    .responseJSON { response in
		debugPrint(response)
	}
```

As you can see, there are many breaking API changes, but the common APIs still adhere to the original design goals of being able to make complex requests through a single line of code in a concise, well defined manner.

### URLStringConvertible

There are two changes to the `URLStringConvertible` protocol that are worth noting.

#### URLConvertible

The first MAJOR change worth noting on the `URLStringConvertible` is that it has been renamed to `URLConvertible`. In Alamofire 3.x, the `URLStringConvertible` was defined as:

```swift
public protocol URLStringConvertible {
    var URLString: String { get }
}
```

Now in Alamofire 4, the `URLConvertible` protocol is defined as:

```swift
public protocol URLConvertible {
    func asURL() throws -> URL
}
```

As you can see, the `URLString` property is completely gone and replaced by a new `asURL` method that throws. To explain, let's first backup.

A VERY common problem in Alamofire is that users forget to percent escape their URL strings and Alamofire will crash. Up until now, we (the Alamofire team) have taken the stance that this is how Alamofire is designed and your URLs need to conform to [RFC 2396](https://tools.ietf.org/html/rfc2396). This is certainly not ideal for the community because we all would rather have Alamofire tell us that our URL was invalid rather than having it crash.

Now, back to the new `URLConvertible` protocol. The reason Alamofire was not previously able to safely handle invalid URL strings was, in fact, due to the lack of safety on `URLStringConvertible`. It's not possible for Alamofire to know how to intelligently make an invalid URL string valid. Therefore, if the `URL` is unable to be created from the `URLConvertible`, an `AFError.invalidURL` error is thrown.

This change (along with many others) allows Alamofire to safely handle invalid URLs and report the error back in the response handlers.

#### URLRequest Conformance

The `URLRequest` no longer conforms to the `URLStringConvertible`, now `URLConvertible` protocol. This was always a bit of a stretch in the previous versions of Alamofire and wasn't really necessary. It also had a high potential to introduce ambiguity into many Alamofire APIs. Because of these reasons, `URLRequest` no longer conforms to `URLStringConvertible` (now `URLConvertible`).

What this means in code is that you can no longer do the following:

```swift
let urlRequest = URLRequest(url: URL(string: "https://httpbin.org/get")!)
let urlString = urlRequest.urlString
```

Instead, in Alamofire 4, you now have to do the following:

```swift
let urlRequest = URLRequest(url: URL(string: "https://httpbin.org/get")!)
let urlString = urlRequest.url?.absoluteString
```

> See [PR-1505](https://github.com/Alamofire/Alamofire/pull/1505) for more info.

### URLRequestConvertible

The `URLRequestConvertible` was susceptible to the same safety issues concerns as the `URLStringConvertible` in Alamofire 3.x. In Alamofire 3, the `URLRequestConvertible` was:

```swift
public protocol URLRequestConvertible {
    var URLRequest: URLRequest { get }
}
```

Now, in Alamofire 4, it is:

```swift
public protocol URLRequestConvertible {
    func asURLRequest() throws -> URLRequest
}
```

As you can see, the `URLRequest` property has been replaced by an `asURLRequest` method that throws when encountering an error generating the `URLRequest`.

The most likely place this will affect your code is in the `Router` design pattern. If you have a `Router`, it's going to have to change, but for the better! You will now implement the `asURLRequest` method instead of the property which gives you the ability to throw an error if necessary. You no longer have to force unwrap unsafe data or parameters or wrap `ParameterEncoding` in a do-catch. Any error encountered in a `Router` can now be automatically handled by Alamofire.

> See [PR-1505](https://github.com/Alamofire/Alamofire/pull/1505) for more info.

---

## New Features

### Request Adapter

The `RequestAdapter` protocol is a completely new feature in Alamofire 4. 

```swift
public protocol RequestAdapter {
    func adapt(_ urlRequest: URLRequest) throws -> URLRequest
}
```

It allows each `Request` made on a `SessionManager` to be inspected and adapted before being created. One very specific way to use an adapter is to append an `Authorization` header to requests behind a certain type of authentication.

```swift
class AccessTokenAdapter: RequestAdapter {
    private let accessToken: String

    init(accessToken: String) {
        self.accessToken = accessToken
    }

    func adapt(_ urlRequest: URLRequest) throws -> URLRequest {
        var urlRequest = urlRequest

        if urlRequest.urlString.hasPrefix("https://httpbin.org") {
            urlRequest.setValue("Bearer " + accessToken, forHTTPHeaderField: "Authorization")
        }

        return urlRequest
    }
}

let sessionManager = SessionManager()
sessionManager.adapter = AccessTokenAdapter(accessToken: "1234")

sessionManager.request("https://httpbin.org/get")
```

If an `Error` occurs during the adaptation process, it should be thrown and will be delivered in the response handler of the `Request`.

> See [PR-1450](https://github.com/Alamofire/Alamofire/pull/1450) for more info.

### Request Retrier

The `RequestRetrier` is another brand new Alamofire 4 protocol. 

```swift
public typealias RequestRetryCompletion = (_ shouldRetry: Bool, _ timeDelay: TimeInterval) -> Void

public protocol RequestRetrier {
    func should(_ manager: SessionManager, retry request: Request, with error: Error, completion: @escaping RequestRetryCompletion)
}
```

It allows a `Request` that encountered an `Error` while being executed to be retried with an optional delay if specified.

```swift
class OAuth2Handler: RequestAdapter, RequestRetrier {
    public func should(_ manager: SessionManager, retry request: Request, with error: Error, completion: RequestRetryCompletion) {
        if let response = request.task.response as? HTTPURLResponse, response.statusCode == 401 {
            completion(true, 1.0) // retry after 1 second
        } else {
            completion(false, 0.0) // don't retry
        }
    }
}

let sessionManager = SessionManager()
sessionManager.retrier = OAuth2Handler()

sessionManager.request(urlString).responseJSON { response in
    debugPrint(response)
}
```

The retrier allows you to inspect the `Request` after it has completed and run all `Validation` closures to determine whether it should be retried. When using both the `RequestAdapter` and `RequestRetrier` protocols together, you can create credential refresh systems for OAuth1, OAuth2, Basic Auth and even exponential backoff retry policies. The possibilities are endless. For more information and examples on this topic, please refer to the README.

> See [PR-1391](https://github.com/Alamofire/Alamofire/pull/1391) and [PR-1450](https://github.com/Alamofire/Alamofire/pull/1450) for more info.

### Task Metrics

In iOS and tvOS 10 and macOS 10.12, Apple introduced the new [URLSessionTaskMetrics](https://developer.apple.com/reference/foundation/urlsessiontaskmetrics) APIs. The task metrics encapsulate some fantastic statistical information about the request and response execution. The API is very similar to Alamofire's `Timeline`, but provide many more statistics that Alamofire was unable to compute. We're really excited about these APIs and have exposed them on each `Response` type meaning they couldn't be easier to use.

```swift
Alamofire.request(urlString).response { response in
	debugPrint(response.metrics)
}
```

It's important to note that these APIs are only available on iOS and tvOS 10+ and macOS 10.12+. Therefore, depending on your deployment target, you may need to use these inside availability checks:

```swift
Alamofire.request(urlString).response { response in
    if #available(iOS 10.0, *) {
		debugPrint(response.metrics)
    }
}
```

> See [PR-1492](https://github.com/Alamofire/Alamofire/pull/1492) for more info.

---

## Updated Features

Alamofire 4 contains many new features and enhancements on existing ones. This section is designed to give a brief overview of the features and demonstrate their uses. For more information on each each, please refer to the linked pull request.

### Errors

Alamofire 4 contains a completely new error system that adopts the new pattern proposed in [SE-0112](https://github.com/apple/swift-evolution/blob/master/proposals/0112-nserror-bridging.md). At the heart of the new error system is `AFError`, a new `Error` type enumeration backed by five main cases.

- `.invalidURL(url: URLConvertible)` - Returned when a `URLConvertible` type fails to create a valid `URL`.
- `.parameterEncodingFailed(reason: ParameterEncodingFailureReason)` - Returned when a parameter encoding object throws an error during the encoding process.
- `.multipartEncodingFailed(reason: MultipartEncodingFailureReason)` - Returned when some step in the multipart encoding process fails. 
- `.responseValidationFailed(reason: ResponseValidationFailureReason)` - Returned when a `validate()` call fails.
- `.responseSerializationFailed(reason: ResponseSerializationFailureReason)` - Returned when a response serializer encounters an error in the serialization process.

Each case contains a specific failure reason which is another nested enumeration with multiple cases that contain additional information about the exact type of error that occurred. What this ultimately means is that is is much easier in Alamofire to identify where an error came from and what to do about it.

```swift
Alamofire.request(urlString).responseJSON { response in
    guard case let .failure(error) = response.result else { return }

    if let error = error as? AFError {
        switch error {
        case .invalidURL(let url):
            print("Invalid URL: \(url) - \(error.localizedDescription)")
        case .parameterEncodingFailed(let reason):
            print("Parameter encoding failed: \(error.localizedDescription)")
            print("Failure Reason: \(reason)")
        case .multipartEncodingFailed(let reason):
            print("Multipart encoding failed: \(error.localizedDescription)")
            print("Failure Reason: \(reason)")
        case .responseValidationFailed(let reason):
            print("Response validation failed: \(error.localizedDescription)")
            print("Failure Reason: \(reason)")

            switch reason {
            case .dataFileNil, .dataFileReadFailed:
                print("Downloaded file could not be read")
            case .missingContentType(let acceptableContentTypes):
                print("Content Type Missing: \(acceptableContentTypes)")
            case .unacceptableContentType(let acceptableContentTypes, let responseContentType):
                print("Response content type: \(responseContentType) was unacceptable: \(acceptableContentTypes)")
            case .unacceptableStatusCode(let code):
                print("Response status code was unacceptable: \(code)")
            }
        case .responseSerializationFailed(let reason):
            print("Response serialization failed: \(error.localizedDescription)")
            print("Failure Reason: \(reason)")
        }

        print("Underlying error: \(error.underlyingError)")
    } else if let error = error as? URLError {
        print("URLError occurred: \(error)")
    } else {
        print("Unknown error: \(error)")
    }
}
```

This new design allows you to drill down into errors as deep as you may need to in order to figure out the best way to proceed. It also frees developers from the burden of having to deal with `NSError` types everywhere. By switching to our own custom `Error` type in Alamofire, we've been able to simplify the `Result` and `Response` generic types to only require a single generic parameter. This simplifies the response serialization logic.

> See [PR-1419](https://github.com/Alamofire/Alamofire/pull/1419) for more info.

### Parameter Encoding Protocol

The `ParameterEncoding` enumeration has served us well for over two years at this point. However, it had some limitations that we wanted to address in Alamofire 4.

- The `.url` case has always been a bit confusing since it selects a destination based on the HTTP method.
- The `.urlEncodedInURL` case has always been an eye sore to work around the behavior of the `.url` case.
- `.JSON` and `.PropertyList` encoding could not accept formatting or writing options.
- The `.Custom` encoding was a bit difficult for users to get the hang of.

Because of these reasons, we decided to eliminate the enumeration altogether in Alamofire 4! Now, `ParameterEncoding` is a protocol backed by three concrete `URLEncoding`, `JSONEncoding` and `PropertyList` encoding structs with a new `Parameters` typealias for creating your parameter dictionaries.

```swift
public typealias Parameters = [String: Any]

public protocol ParameterEncoding {
    func encode(_ urlRequest: URLRequestConvertible, with parameters: Parameters?) throws -> URLRequest
}
```

#### URL Encoding

The new `URLEncoding` struct contains a `Destination` enumeration supporting three types of destinations:

- `.methodDependent` - Applies encoded query string result to existing query string for `GET`, `HEAD` and `DELETE` requests and sets as the HTTP body for requests with any other HTTP method.
- `.queryString` - Sets or appends encoded query string result to existing query string.
- `.httpBody` - Sets encoded query string result as the HTTP body of the URL request.

These destinations make it much easier to control where the parameters are encoded onto the `URLRequest`. Creating requests still uses the same signature as before in regards to parameter encoding and also has the same default behavior.

```swift
let parameters: Parameters = ["foo": "bar"]

Alamofire.request(urlString, parameters: parameters) // Encoding => URLEncoding(destination: .methodDependent)
Alamofire.request(urlString, parameters: parameters, encoding: URLEncoding(destination: .queryString))
Alamofire.request(urlString, parameters: parameters, encoding: URLEncoding(destination: .httpBody))

// Static convenience properties (we'd like to encourage everyone to use this more concise form)
Alamofire.request(urlString, parameters: parameters, encoding: URLEncoding.default)
Alamofire.request(urlString, parameters: parameters, encoding: URLEncoding.queryString)
Alamofire.request(urlString, parameters: parameters, encoding: URLEncoding.httpBody)
```

#### JSON Encoding

The new `JSONEncoding` struct exposes the ability to customize the JSON writing options.

```swift
let parameters: Parameters = ["foo": "bar"]

Alamofire.request(urlString, parameters: parameters, encoding: JSONEncoding(options: []))
Alamofire.request(urlString, parameters: parameters, encoding: JSONEncoding(options: .prettyPrinted))

// Static convenience properties (we'd like to encourage everyone to use this more concise form)
Alamofire.request(urlString, parameters: parameters, encoding: JSONEncoding.default)
Alamofire.request(urlString, parameters: parameters, encoding: JSONEncoding.prettyPrinted)
```

#### Property List Encoding

The new `PropertyListEncoding` struct allows customizing the plist format and write options.

```swift
let parameters: Parameters = ["foo": "bar"]

Alamofire.request(urlString, parameters: parameters, encoding: PropertyListEncoding(format: .xml, options: 0))
Alamofire.request(urlString, parameters: parameters, encoding: PropertyListEncoding(format: .binary, options: 0))

// Static convenience properties (we'd like to encourage everyone to use this more concise form)
Alamofire.request(urlString, parameters: parameters, encoding: PropertyListEncoding.xml)
Alamofire.request(urlString, parameters: parameters, encoding: PropertyListEncoding.binary)
```

#### Custom Encoding

Creating a custom custom `ParameterEncoding` is now as simple as implementing the protocol. For more examples on how to do this, please refer to the README.

> See [PR-1465](https://github.com/Alamofire/Alamofire/pull/1465) for more info.

### Request Subclasses

In Alamofire 4, the `request`, `download`, `upload` and `stream` APIs no longer return a `Request`. Instead, they return a specific type of `Request` subclass. There were several motivating factors and community questions that led us to making this change:

- **Progress:** The behavior of the `progress` method was confusing for upload requests.
	- What does `progress` report on an upload `Request`? The progress of the upload? The progress of the response download?
	- If it reports both, how do you know if or when it switches?
- **Response Serializers:** The response serializers were designed for data and upload requests, not download or stream requests.
	- How do you access the fileURL when a download is complete?
	- What would `responseData`, `responseString` or `responseJSON` do for a download request? Stream request?

At a high level, Alamofire 4 now has four `Request` subclasses that each support their own custom chained APIs. This allows each subclass to create extensions tailored to that specific type of request.

```swift
open class Request {
    // Contains common properties, authentication and state methods as well as
    // CustomStringConvertible and CustomDebugStringConvertible conformance
}

open class DataRequest: Request {
    // Contains stream (not to be confused with StreamRequest) and download progress methods.
}

open class DownloadRequest: Request {
    // Contains download destination and options, resume data and download progress methods.
}

open class UploadRequest: DataRequest {
    // Inherits all DataRequest APIs and also contains upload progress methods.
}

open class StreamRequest: Request {
    // Only inherits Request APIs, there are no other custom APIs at this time.
}
```

By making this split, Alamofire 4 was able to create customized chaining APIs for each type of `Request`. This opened up all sorts of possibilities, but let's take a moment to focus on what this change means in terms of progress reporting and download destinations.

> See [PR-1455](https://github.com/Alamofire/Alamofire/pull/1455) for more info.

#### Download and Upload Progress

The progress reporting system for data, download and upload requests has been completely redesigned. Each request type contains progress APIs for executing a closure during each progress update by returning the underlying `Progress` instance. The closure will be called on the specified queue that defaults to main.

**Data Request Progress**

```swift
Alamofire.request(urlString)
    .downloadProgress { progress in
        // Called on main dispatch queue by default
        print("Download progress: \(progress.fractionCompleted)")
    }
    .responseJSON { response in
        debugPrint(response)
    }
```

**Download Request Progress**

```swift
Alamofire.download(urlString, to: destination)
    .downloadProgress(queue: DispatchQueue.global(qos: .utility)) { progress in
        // Called on utility dispatch queue
        print("Download progress: \(progress.fractionCompleted)")
    }
    .responseJSON { response in
        debugPrint(response)
    }
```

**Upload Request Progress**

```swift
Alamofire.upload(data, to: urlString, withMethod: .post)
    .uploadProgress { progress in
        // Called on main dispatch queue by default
        print("Upload progress: \(progress.fractionCompleted)")
    }
    .downloadProgress { progress in
        // Called on main dispatch queue by default
        print("Download progress: \(progress.fractionCompleted)")
    }
    .responseData { response in
        debugPrint(response)
    }
```

It's now easy to differentiate between upload and download progress for upload requests.

> See [PR-1455](https://github.com/Alamofire/Alamofire/pull/1455) for more info.

#### Download File Destinations

In Alamofire 3.x, successful download requests would always move the temporary file to a final destination URL provided by the `destination` closure. While this was a nice convenience, it had several limitations:

- `Forced` - The API forces you to provide a destination closure to move the file even if you have a valid use case for not moving it.
- `Limiting` - There was no way to adjust the file system prior to moving the file.
    - What if you need to delete a pre-existing file at the destination URL before moving the temporary file?
    - What if you need to create intermediate directories to the destination URL before moving the temporary file?

These limitations led to several enhancements in Alamofire 4. The first of which is the optionality of the destination closure. Now, by default, the `destination` closure is `nil` which means the file is not moved anywhere on the file system and the temporary URL is returned.

```swift
Alamofire.download(urlString).responseData { response in
    print("Temporary URL: \(response.temporaryURL)")
}
```

> We'll cover the `DownloadResponse` type in more detail in the [Response Serializers](#response-serializers) section.

#### Download Options

The other major change made was to add download options to the destination closure allowing more file system control over the move operation. To accomplish this, the `DownloadOptions` type was created and added to the `DownloadFileDestination` closure.

```swift
public typealias DownloadFileDestination = (
    _ temporaryURL: URL,
    _ response: HTTPURLResponse)
    -> (destinationURL: URL, options: DownloadOptions)
```

The two currently supported `DownloadOptions` are:

- `.createIntermediateDirectories` - Creates intermediate directories for the destination URL if specified.
- `.removePreviousFile` - Removes a previous file from the destination URL if specified.

They can then be used as follows:

```swift
let destination: DownloadRequest.DownloadFileDestination = { _, _ in 
    return (fileURL, [.removePreviousFile, .createIntermediateDirectories]) 
}

Alamofire.download(urlString, to: destination).response { response in
    debugPrint(response)
}
```

If an error occurs during the file system operations, the `error` on the `DownloadResponse` will be of type `URLError`.

> See [PR-1462](https://github.com/Alamofire/Alamofire/pull/1462) for more info.

### Response Validation

There were several opportunity areas for improving the response validation system in Alamofire 4. These areas included:

- Exposing the underlying `data` to the `Validation` closure.
- Custom validation between different `Request` subclasses types allowing `temporaryURL` and `destinationURL` to be exposed for download requests.

By creating `Request` subclasses, the validation closure typealias and request APIs were able to be tailored to each request type.

#### Data Request

The `Validation` closure exposed on the `DataRequest` (inherited by `UploadRequest`) is now as follows:

```swift
extension DataRequest {
    public typealias Validation = (URLRequest?, HTTPURLResponse, Data?) -> ValidationResult
}
```

By exposing the `Data?` property directly in the closure, you no longer have to write an extension on `Request` to access it. Now you can do something like this:

```swift
Alamofire.request(urlString)
    .validate { request, response, data in
        guard let data = data else { return .failure(customError) }

        // 1) Validate the response to make sure everything looks good
        // 2) If validation fails, you can now parse the error message out of the
        //    data if necessary and add that to your custom error if you wish.

        return .success
    }
    .response { response in
        debugPrint(response)
    }
```

#### Download Request

The `Validation` closure on the `DownloadRequest` is very similar to the `DataRequest` API, but tailored more to downloads.

```swift
extension DownloadRequest {
	public typealias Validation = (
	    _ request: URLRequest?, 
	    _ response: HTTPURLResponse, 
	    _ temporaryURL: URL?, 
	    _ destinationURL: URL?) 
	    -> ValidationResult
}
```

The `temporaryURL` and `destinationURL` parameters now allow you access the data returned by the server directly in an inline closure. This allows you to inspect the data inside the file if you've determined you need to in order to create a custom error.

```swift
Alamofire.download(urlString)
    .validate { request, response, temporaryURL, destinationURL in
        guard let fileURL = temporaryURL else { return .failure(customError) }

        do {
            let _ = try Data(contentsOf: fileURL)
            return .success
        } catch {
            return .failure(customError)
        }
    }
    .response { response in
        debugPrint(response)
    }
```

By exposing the underlying server data directly to the inline closures, error messages embedded in those responses can be parsed out inside the `Validation` closure to create a custom error including the server error message. If the payload is the same schema as used in a response serializer closure, the response serializer could be called to parse out the error message rather than duplicating the logic. For an example of how to do this, please refer to the README.

> See [PR-1461](https://github.com/Alamofire/Alamofire/pull/1461) for more info.

### Response Serializers

The response serialization system in Alamofire 3.x had several pretty severe limitations:

- Response serialization APIs could be applied to download and stream requests but resulted in undefined behavior.
	- How do you access the fileURL when a download is complete?
	- What would `responseData`, `responseString` or `responseJSON` do when chained onto a download request? A stream request?
- The `response` API returned 4 parameters instead of an encapsulating `Response` type.
	- The biggest issue here is that any change to that API could not be done in a backwards compatible manner.
	- Created confusion when switching between the serialized and unserialized APIs which led to difficult to debug compiler errors.

As you can see, there were some very strong limitations to this system in Alamofire 3.x. Therefore, in Alamofire 4, the `Request` type was first broken down into subclasses, which opened up the opportunity to create customized response serializers and APIs for specific types of requests. Before getting to far into response serializers, we should first walk through the new `Response` types.

#### Default Data Response

The `DefaultDataResponse` represents an unserialized server response. There's no Alamofire processing that happens, it just collects all the response information from the `SessionDelegate` APIs and returns it in a simple struct.

```swift
public struct DefaultDataResponse {
    public let request: URLRequest?
    public let response: HTTPURLResponse?
    public let data: Data?
    public let error: Error?
	public var metrics: URLSessionTaskMetrics? { return _metrics as? URLSessionTaskMetrics }
}
```

This is the type of response you will get back from the `DataRequest.response` API.

```swift
Alamofire.request(urlString).response { response in
    debugPrint(response)
}

Alamofire.upload(file, to: urlString).response { response in
    debugPrint(response)
}
```

#### Data Response

The generic `DataResponse` type is the same as the generic `Response` in Alamofire 3.x, but refactored and contains the new `metrics` property.

```swift
public struct DataResponse<Value> {
    public let request: URLRequest?
    public let response: HTTPURLResponse?
    public let data: Data?
    public let result: Result<Value>
    public let timeline: Timeline
	public var metrics: URLSessionTaskMetrics? { return _metrics as? URLSessionTaskMetrics }
}
```

You still have access to the same response serialization APIs as before on the `DataRequest` and `UploadRequest` types.

```swift
Alamofire.request(urlString).responseJSON { response in
    debugPrint(response)
    print(response.result.isSuccess)
}

Alamofire.upload(fileURL, to: urlString).responseData { response in
    debugPrint(response)
    print(response.result.isSuccess)
}
```

#### Default Download Response

Since downloads work differently than data and upload requests, Alamofire 4 contains custom download `Response` types tailored to their behavior. The `DefaultDownloadResponse` type represents an unserialized server response for a `DownloadRequest` that collects all the `SessionDelegate` information into a simple struct.

```swift
public struct DefaultDownloadResponse {
    public let request: URLRequest?
    public let response: HTTPURLResponse?
    public let temporaryURL: URL?
    public let destinationURL: URL?
    public let resumeData: Data?
    public let error: Error?
	public var metrics: URLSessionTaskMetrics? { return _metrics as? URLSessionTaskMetrics }
}
```

The `DefaultDownloadResponse` type is returned when using the new `DownloadRequest.response` API.

```swift
Alamofire.download(urlString).response { response in
    debugPrint(response)
    print(response.temporaryURL)
}
```

#### Download Response

The new generic `DownloadResponse` type is similar to the generic `DataResponse` type, but contains information tailored to download requests. The `DownloadResponse` type is returned when one of four new APIs exposed on the `DownloadRequest` type. These new APIs match the `DataRequest` ones, and provide the same functionality by loading the data from the underlying temporary or destination URL.

```swift
Alamofire.download(urlString, to: destination)
	.responseData { response in
    	debugPrint(response)
	}
	.responseString { response in
    	debugPrint(response)
	}
	.responseJSON { response in
    	debugPrint(response)
	}
	.responsePropertyList { response in
    	debugPrint(response)
	}
```

These new response serialization APIs make it MUCH easier to download a request to a file and serialize the response all in a single call.

#### Custom Response Serializers

If you have created your own custom response serializers, you may want to extend support across both data and download requests similar to what we've done with the Alamofire response serializers. If you do decide to do this, take a close look at how Alamofire shares the response serializer implementation between both request types by moving the implementation to the `Request`. This allowed us to DRY up our logic to avoid duplication between types.

> See [PR-1457](https://github.com/Alamofire/Alamofire/pull/1457) for more info.
