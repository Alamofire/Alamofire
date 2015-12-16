# Alamofire 2.0 Migration Guide

Alamofire 2.0 is the latest major release of Alamofire, an HTTP networking library for iOS, Mac OS X and watchOS written in Swift. As a major release, following Semantic Versioning conventions, 2.0 introduces several API-breaking changes that one should be aware of.

This guide is provided in order to ease the transition of existing applications using Alamofire 1.x to the latest APIs, as well as explain the design and structure of new and changed functionality.

## New Requirements

Alamofire 2.0 officially supports iOS 8+, Mac OS X 10.9+, Xcode 7 and Swift 2.0. If you'd like to use Alamofire in a project targeting iOS 7 and Swift 1.x, use the latest tagged 1.x release.

---

## Breaking API Changes

### Swift 2.0

The biggest change between Alamofire 1.x and Alamofire 2.0 is Swift 2.0. Swift 2 brought many new features to take advantage of such as error handling, protocol extensions and availability checking. Other new features such as `guard` and `defer` do not affect the public APIs, but allowed us to create much cleaner implementations of the same logic. All of the source files, test logic and example code has been updated to reflect the latest Swift 2.0 paradigms.

> It is not possible to use Alamofire 2.0 without Swift 2.0.

### Response Serializers

The most significant logic change made to Alamofire 2.0 is its new response serialization system leveraging `Result` types. Previously in Alamofire 1.x, each response serializer used the same completion handler signature:

```swift
public func response(completionHandler: (NSURLRequest, NSHTTPURLResponse?, AnyObject?, NSError?) -> Void) -> Self {
    return response(serializer: Request.responseDataSerializer(), completionHandler: completionHandler)
}
```

Alamofire 2.0 has redesigned the entire response serialization process to make it much easier to access the original server data without serialization, or serialize the response into a non-optional `Result` type defining whether the `Request` was successful.

#### No Response Serialization

The first `response` serializer is non-generic and does not process the server data in any way. It merely forwards on the accumulated information from the `NSURLSessionDelegate` callbacks.

```swift
public func response(
	queue queue: dispatch_queue_t? = nil,
	completionHandler: (NSURLRequest?, NSHTTPURLResponse?, NSData?, ErrorType?) -> Void)
	-> Self
{
	delegate.queue.addOperationWithBlock {
		dispatch_async(queue ?? dispatch_get_main_queue()) {
			completionHandler(self.request, self.response, self.delegate.data, self.delegate.error)
		}
	}

	return self
}
```

Another important note of this change is the return type of `data` is now an `NSData` type. You no longer need to cast the `data` parameter from an `AnyObject?` to an `NSData?`.

#### Generic Response Serializers

The second, more powerful response serializer leverages generics along with a `Result` type to eliminate the case of the dreaded double optional.

```swift
public func response<T: ResponseSerializer, V where T.SerializedObject == V>(
    queue queue: dispatch_queue_t? = nil,
    responseSerializer: T,
    completionHandler: (NSURLRequest?, NSHTTPURLResponse?, Result<V>) -> Void)
    -> Self
{
    delegate.queue.addOperationWithBlock {
        let result: Result<T.SerializedObject> = {
            if let error = self.delegate.error {
                return .Failure(self.delegate.data, error)
            } else {
                return responseSerializer.serializeResponse(self.request, self.response, self.delegate.data)
            }
        }()

        dispatch_async(queue ?? dispatch_get_main_queue()) {
            completionHandler(self.request, self.response, result)
        }
    }

    return self
}
```

##### Response Data

```swift
Alamofire.request(.GET, "http://httpbin.org/get")
         .responseData { _, _, result in
             print("Success: \(result.isSuccess)")
             print("Response: \(result)")
         }
```

##### Response String

```swift
Alamofire.request(.GET, "http://httpbin.org/get")
         .responseString { _, _, result in
             print("Success: \(result.isSuccess)")
             print("Response String: \(result.value)")
         }
```

##### Response JSON

```swift
Alamofire.request(.GET, "http://httpbin.org/get")
         .responseJSON { _, _, result in
             print(result)
             debugPrint(result)
         }
```

#### Result Types

The `Result` enumeration was added to handle the case of the double optional return type. Previously, the return value and error were both optionals. Checking if one was `nil` did not ensure the other was also not `nil`. This case has been blogged about many times and can be solved by a `Result` type. Alamofire 2.0 brings a `Result` type to the response serializers to make it much easier to handle success and failure cases.

```swift
public enum Result<Value> {
    case Success(Value)
    case Failure(NSData?, ErrorType)
}
```

There are also many other convenience computed properties to make accessing the data inside easy. The `Result` type also conforms to the `CustomStringConvertible` and `CustomDebugStringConvertible` protocols to make it easier to debug.

#### Error Types

While Alamofire still only generates `NSError` objects, all `Result` types have been converted to store `ErrorType` objects to allow custom response serializer implementations to use any `ErrorType` they wish. This also includes the `ValidationResult` and `MultipartFormDataEncodingResult` types as well.

### URLRequestConvertible

In order to make it easier to deal with non-common scenarios, the `URLRequestConvertible` protocol now returns an `NSMutableURLRequest`. Alamofire 2.0 makes it much easier to customize the URL request after is has been encoded. This should only affect a small amount of users.

```swift
public protocol URLRequestConvertible {
    var URLRequest: NSMutableURLRequest { get }
}
```

### Multipart Form Data

Encoding `MultipartFormData` previous returned an `EncodingResult` to encapsulate any possible errors that occurred during encoding. Alamofire 2.0 uses the new Swift 2.0 error handling instead making it easier to use. This change is mostly encapsulated internally and should only affect a very small subset of users.

---

## Updated ACLs and New Features

### Parameter Encoding

#### ACL Updates

The `ParameterEncoding` enumeration implementation was previously hidden behind `internal` and `private` ACLs. Alamofire 2.0 opens up the `queryComponents` and `escape` methods to make it much easier to implement `.Custom` cases.

#### Encoding in the URL

In the previous versions of Alamofire, `.URL` encoding would automatically append the query string to either the URL or HTTP body depending on which HTTP method was set in the `NSURLRequest`. While this satisfies the majority of common use cases, it made it quite difficult to append query string parameter to a URL for HTTP methods such as `PUT` and `POST`. In Alamofire 2.0, we've added a second URL encoding case, `.URLEncodedInURL`, that always appends the query string to the URL regardless of HTTP method.

### Server Trust Policies

In Alamofire 1.x, the `ServerTrustPolicyManager` methods were internal making it impossible to implement any custom domain matching behavior. Alamofire 2.0 opens up the internals with a `public` ACL allowing more flexible server trust policy matching behavior (i.e. wildcarded domains) through subclassing.

```swift
class CustomServerTrustPolicyManager: ServerTrustPolicyManager {
    override func serverTrustPolicyForHost(host: String) -> ServerTrustPolicy? {
        var policy: ServerTrustPolicy?

        // Implement your custom domain matching behavior...

        return policy
    }
}
```

### Download Requests

The global and `Manager` download APIs now support `parameters` and `encoding` parameters to better support dynamic payloads used in background sessions. Constructing a `download` request is now the same as constructing a `data` request with the addition of a `destination` parameter.

```swift
public func download(
    method: Method,
    _ URLString: URLStringConvertible,
    parameters: [String: AnyObject]? = nil,
    encoding: ParameterEncoding = .URL,
    headers: [String: String]? = nil,
    destination: Request.DownloadFileDestination)
    -> Request
{
    return Manager.sharedInstance.download(
        method,
        URLString,
        parameters: parameters,
        encoding: encoding,
        headers: headers,
        destination: destination
    )
}
```

### Stream Tasks

Alamofire 2.0 adds support for creating `NSURLSessionStreamTask` tasks for iOS 9 and OS X 10.11. It also extends the `SessionDelegate` to support all the new `NSURLSessionStreamDelegate` APIs.
