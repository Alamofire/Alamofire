# Alamofire 3.0 Migration Guide

Alamofire 3.0 is the latest major release of Alamofire, an HTTP networking library for iOS, Mac OS X and watchOS written in Swift. As a major release, following Semantic Versioning conventions, 3.0 introduces several API-breaking changes that one should be aware of.

This guide is provided in order to ease the transition of existing applications using Alamofire 2.x to the latest APIs, as well as explain the design and structure of new and changed functionality.

## Requirements

Alamofire 3.0 officially supports iOS 8+, Mac OS X 10.9+, watchOS 2.0, Xcode 7 and Swift 2.0. If you'd like to use Alamofire in a project targeting iOS 7 and Swift 1.x, use the latest tagged 1.x release.

## Reasons for Bumping to 3.0

The [Alamofire Software Foundation](https://github.com/Alamofire/Foundation) (ASF) tries to do everything possible to avoid MAJOR version bumps. We realize the challenges involved with migrating large projects from one MAJOR version to another. With that said, we also want to make sure we're always producing the highest quality APIs and features possible. 

After releasing Alamofire 2.0, it became clear that the response serialization system still had some room for improvement. After much debate, we decided to strictly follow semver and move forward with all the core logic changes becoming Alamofire 3.0. We've also made some fairly significant changes that should give us more flexibility moving forward to help avoid the need for MAJOR version bumps to maintain backwards compatibility.

## Benefits of Upgrading

The benefits of upgrading can be summarized as follows:

* No more casting a response serializer `error` from an `ErrorType` to an `NSError`.
* Original server data is now ALWAYS returned in all response serializers regardless of whether the result was a `.Success` or `.Failure`.
* Custom response serializers are now ALWAYS called regardless of whether an `error` occurred.
* Custom response serializers are now passed in the `error` allowing you to switch between different parsing schemes if necessary.
* Custom response serializers can now wrap up any Alamofire `NSError` into a `CustomError` type of your choosing.
* `Manager` initialization can now accept custom `NSURLSession` or `SessionDelegate` objects using dependency injection.

---

## Breaking API Changes

Alamofire 3.0 contains some breaking API changes to the foundational classes supporting the response serialization system. It is important to understand how these changes affect the common usage patterns.

### Result Type

The `Result` type was introduced in Alamofire 2.0 as a single generic parameter with the following signature:

```swift
public enum Result<Value> {
    case Success(Value)
    case Failure(NSData?, ErrorType)
}
```

While this was a significant improvement on the behavior of Alamofire 1.0, there was still room for improvement. By defining the `.Failure` case to take an `ErrorType`, all consumers needed to cast the `ErrorType` to some concrete object such as an `NSError` before being able to interact with it. This was certainly not ideal. Additionally, by only allowing the `NSData?` from the server to be appended in a `.Failure` case, it was not possible to access the original server data in a `.Success` case.

In Alamofire 3.0, the `Result` type has been redesigned to be a double generic type that does not store the `NSData?` in the `.Failure` case.

```swift
public enum Result<Value, Error: ErrorType> {
    case Success(Value)
    case Failure(Error)
}
```

These changes allow Alamofire to return the original server data in both cases. It also removes the requirement of having to cast the `ErrorType` when working with the `.Failure` case error object.

### Response

In order to avoid constantly having to change the response serializer completion closure signatures, Alamofire 3.0 introduces a `Response` struct. All response serializers (with the exception of `response`) return a generic `Response` struct.

```swift
public struct Response<Value, Error: ErrorType> {
    /// The URL request sent to the server.
    public let request: NSURLRequest?

    /// The server's response to the URL request.
    public let response: NSHTTPURLResponse?

    /// The data returned by the server.
    public let data: NSData?

    /// The result of response serialization.
    public let result: Result<Value, Error>
}
```

This unifies the signature of all response serializer completion closures by only needing to specify a single parameter rather than three or four. If another major release of Alamofire needs to modify the signature, thankfully the number of parameters in all response serializers will NOT need to change. Given the fact that the Swift compiler can present some fairly misleading compiler errors when the arguments are not correct, this should help alleviate some painful updates between MAJOR version bumps of Alamofire.

### Response Serializers

The biggest change in Alamofire 3.0 are the response serializers. They are now powered by the new `Response` struct and updated `Result` type. These two generic classes make it VERY easy to interact with the response serializers in a consistent, type-safe manner.

```swift
Alamofire.request(.GET, "http://httpbin.org/get", parameters: ["foo": "bar"])
         .responseJSON { response in
         	 debugPrint(response)     // prints detailed description of all response properties

             print(response.request)  // original URL request
             print(response.response) // URL response
             print(response.data)     // server data
             print(response.result)   // result of response serialization

             if let JSON = response.result.value {
                 print("JSON: \(JSON)")
             }
         }
```

Besides the single response parameter in the completion closure, the other major callouts are that the original server data is always available whether the `Result` was a `.Success` or `.Failure`. Additionally, both the `value` and `error` of the `Result` type are strongly typed objects thanks to the power of generics. All default response serializer errors will be an `NSError` type. Custom response serializers can specify any custom `ErrorType`.

#### Response Serializer Type

For those wishing to create custom response serializer types, you'll need to familiarize yourself with the new `ResponseSerializerType` protocol and generic `ResponseSerializer` struct. 

```swift
public protocol ResponseSerializerType {
    /// The type of serialized object to be created by this `ResponseSerializerType`.
    typealias SerializedObject

    /// The type of error to be created by this `ResponseSerializer` if serialization fails.
    typealias ErrorObject: ErrorType

    /**
        A closure used by response handlers that takes a request, response, data and error and returns a result.
    */
    var serializeResponse: (NSURLRequest?, NSHTTPURLResponse?, NSData?, NSError?) -> Result<SerializedObject, ErrorObject> { get }
}
```

All the possible information about the `Request` is now passed into the `serializeResponse` closure. In Alamofire 3.0, the `serializeResponse` closure is ALWAYS called whether an error occurred or not. This is for several reasons.

1. Passing the error into the response serializer allows the implementation to switch parsing schemes based on what error occurred. For example, some APIs will return different payload schemas when certain errors occur. The new design allows you to switch on the error type and use different parsing logic.
2. Any error produced by Alamofire will always be an `NSError`. If your custom response serializer returns `CustomError` types, then the `NSError` returned by Alamofire must be converted into a `CustomError` type. This makes it MUCH easier to wrap Alamofire errors in your own `CustomError` type objects.
    > This is also required for all the generics logic to work properly.

### Validation Result

The `ValidationResult` enumeration in Alamofire 3.0 has been updated to take an `NSError` in the `.Failure` case. The reasoning for this change is that all Alamofire errors generated need to be `NSError` types. If not, it introduces the need to cast all error objects coming from Alamofire at the response serializer level.

```swift
public enum ValidationResult {
    case Success
    case Failure(NSError)
}
```

> If you are extending the `Request` type in any way that can produce an error, that error always needs to be of type `NSError`. If you'd like to wrap the error into a `CustomError` type, it should be wrapped in a custom response serializer implementation.

---

## New Features

### Dependency Injection

Alamofire 3.0 leverages [dependency injection](https://en.wikipedia.org/wiki/Dependency_injection) to allow some powerful new customizations to take place for the URL session and delegate.

#### Session Delegate

In previous versions of Alamofire, the `SessionDelegate` was automatically created by the `Manager` instance. While this is convenient, it can be problematic for background sessions. One may need to hook up the task override closures before instantiating the URL session. Otherwise the URL session delegate could be called before the task override closures are able to be set.

In Alamofire 3.0, the `Manager` initializer adds the ability to provide a custom `SessionDelegate` object with the task override closures already set using dependency injection. This greatly increases the flexibility of Alamofire in regards to background sessions.

```swift
public init(
    configuration: NSURLSessionConfiguration = NSURLSessionConfiguration.defaultSessionConfiguration(),
    delegate: SessionDelegate = SessionDelegate(),
    serverTrustPolicyManager: ServerTrustPolicyManager? = nil)
{
    self.delegate = delegate
    self.session = NSURLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)

    commonInit(serverTrustPolicyManager: serverTrustPolicyManager)
}
```

#### URL Session 

Alamofire 3.0 also adds the ability to use dependency injection to provide a custom `NSURLSession` to the `Manager` instance. This provides complete control over the URL session initialization if you need it allowing `NSURLSession` subclasses for various kinds of testing and DVR implementations.

```swift
public init?(
    session: NSURLSession,
    delegate: SessionDelegate,
    serverTrustPolicyManager: ServerTrustPolicyManager? = nil)
{
    self.delegate = delegate
    self.session = session

    guard delegate === session.delegate else { return nil }

    commonInit(serverTrustPolicyManager: serverTrustPolicyManager)
}
```

> We're very excited to see what the community comes up with given these new possibilities with Alamofire 3.0.
