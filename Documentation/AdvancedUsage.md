- [`Session`](#session)
  - [Creating Custom `Session` Instances](#creating-custom-session-instances)
    - [Creating a `Session` With a `URLSessionConfiguration`](#creating-a-session-with-a-urlsessionconfiguration)
  - [`SessionDelegate`](#sessiondelegate)
  - [`startRequestsImmediately`](#startrequestsimmediately)
  - [A `Session`’s `DispatchQueue`s](#a-sessions-dispatchqueues)
  - [Adding a `RequestInterceptor`](#adding-a-requestinterceptor)
  - [Adding a `ServerTrustManager`](#adding-a-servertrustmanager)
  - [Adding a `RedirectHandler`](#adding-a-redirecthandler)
  - [Adding a `CachedResponseHandler`](#adding-a-cachedresponsehandler)
  - [Adding `EventMonitor`s](#adding-eventmonitors)
  - [Creating Instances From `URLSession`s](#creating-instances-from-urlsessions)
- [Requests](#requests)
  - [The Request Pipeline](#the-request-pipeline)
  - [`Request`](#request)
    - [State](#state)
    - [Progress](#progress)
    - [Handling Redirects](#handling-redirects)
    - [Customizing Caching](#customizing-caching)
    - [Credentials](#credentials)
    - [A `Request`’s `URLRequest`s](#a-requests-urlrequests)
    - [`URLSessionTask`s](#urlsessiontasks)
    - [Response](#response)
    - [`URLSessionTaskMetrics`](#urlsessiontaskmetrics)
  - [`DataRequest`](#datarequest)
    - [Additional State](#additional-state)
    - [Validation](#validation)
  - [`DataStreamRequest`](#datastreamrequest)
    - [Additional State](#additional-state-1)
    - [Validation](#validation-1)
  - [`UploadRequest`](#uploadrequest)
    - [Additional State](#additional-state-2)
  - [`DownloadRequest`](#downloadrequest)
    - [Additional State](#additional-state-3)
    - [Cancellation](#cancellation)
    - [Validation](#validation-2)
- [Adapting and Retrying Requests with `RequestInterceptor`](#adapting-and-retrying-requests-with-requestinterceptor)
  - [`RequestAdapter`](#requestadapter)
  - [`RequestRetrier`](#requestretrier)
  - [Using Multiple `RequestInterceptor`s](#using-multiple-requestinterceptors)
  - [`AuthenticationInterceptor`](#authenticationinterceptor)
  - [Compressing Request Body Data With `DeflateRequestCompressor`](#compressing-request-body-data-with-deflaterequestcompressor)
- [Security](#security)
  - [Evaluating Server Trusts with `ServerTrustManager` and `ServerTrustEvaluating`](#evaluating-server-trusts-with-servertrustmanager-and-servertrustevaluating)
    - [`ServerTrustEvaluting`](#servertrustevaluting)
    - [`ServerTrustManager`](#servertrustmanager)
      - [Subclassing `ServerTrustManager`](#subclassing-servertrustmanager)
  - [App Transport Security](#app-transport-security)
    - [Using Self-Signed Certificates with Local Networking](#using-self-signed-certificates-with-local-networking)
- [Customizing Caching and Redirect Handling](#customizing-caching-and-redirect-handling)
  - [`CachedResponseHandler`](#cachedresponsehandler)
  - [`RedirectHandler`](#redirecthandler)
- [Using `EventMonitor`s](#using-eventmonitors)
  - [Logging](#logging)
- [Making Requests](#making-requests)
  - [`URLConvertible`](#urlconvertible)
  - [`URLRequestConvertible`](#urlrequestconvertible)
  - [Routing Requests](#routing-requests)
- [Response Handling](#response-handling)
  - [Handling Responses Without Serialization](#handling-responses-without-serialization)
  - [`ResponseSerializer`](#responseserializer)
    - [`DataResponseSerializer`](#dataresponseserializer)
    - [`StringResponseSerializer`](#stringresponseserializer)
    - [`DecodableResponseSerializer`](#decodableresponseserializer)
  - [Customizing Response Handlers](#customizing-response-handlers)
    - [Response Transforms](#response-transforms)
    - [Creating a Custom Response Serializer](#creating-a-custom-response-serializer)
  - [Streaming Response Handlers](#streaming-response-handlers)
- [Using Alamofire with Combine](#using-alamofire-with-combine)
  - [`DownloadResponsePublisher`](#downloadresponsepublisher)
  - [`DataStreamPublisher`](#datastreampublisher)
- [Using Alamofire with Swift Concurrency](#using-alamofire-with-swift-concurrency)
  - [`DataRequest` and `UploadRequest` Support](#datarequest-and-uploadrequest-support)
  - [`DownloadRequest` Support](#downloadrequest-support)
  - [Automatic Cancellation](#automatic-cancellation)
  - [`DataStreamRequest` Support](#datastreamrequest-support)
  - [Value Stream Handlers](#value-stream-handlers)
- [Network Reachability](#network-reachability)

# Advanced Usage

Alamofire is built on top of `URLSession` and the Foundation URL Loading System. To make the most of this framework, it is recommended that you be familiar with the concepts and capabilities of the underlying networking stack.

**Recommended Reading**

- [URL Loading System Programming Guide](https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/URLLoadingSystem/URLLoadingSystem.html)
- [`URLSession` Class Reference](https://developer.apple.com/reference/foundation/urlsession)
- [`URLCache` Class Reference](https://developer.apple.com/reference/foundation/urlcache)
- [`URLAuthenticationChallenge` Class Reference](https://developer.apple.com/reference/foundation/urlauthenticationchallenge)

## `Session`

Alamofire’s `Session` is roughly equivalent in responsibility to the `URLSession` instance it maintains: it provides API to produce the various `Request` subclasses encapsulating different `URLSessionTask` subclasses, as well as encapsulating a variety of configuration applied to all `Request`s produced by the instance.

`Session` provides a `default` singleton instance which powers the top-level API from the `AF` enum namespace. As such, the following two statements are equivalent:

```swift
AF.request("https://httpbin.org/get")
```

```swift
let session = Session.default
session.request("https://httpbin.org/get")
```

### Creating Custom `Session` Instances

Most applications will need to customize the behavior of their `Session` instances in a variety of ways. The easiest way to accomplish this is to use the following convenience initializer and store the result in a singleton used throughout the app.

```swift
public convenience init(configuration: URLSessionConfiguration = URLSessionConfiguration.af.default,
                        delegate: SessionDelegate = SessionDelegate(),
                        rootQueue: DispatchQueue = DispatchQueue(label: "org.alamofire.session.rootQueue"),
                        startRequestsImmediately: Bool = true,
                        requestQueue: DispatchQueue? = nil,
                        serializationQueue: DispatchQueue? = nil,
                        interceptor: RequestInterceptor? = nil,
                        serverTrustManager: ServerTrustManager? = nil,
                        redirectHandler: RedirectHandler? = nil,
                        cachedResponseHandler: CachedResponseHandler? = nil,
                        eventMonitors: [EventMonitor] = [])
```

This initializer allows the customization of all fundamental `Session` behaviors.

#### Creating a `Session` With a `URLSessionConfiguration`

To customize the behavior of the underlying `URLSession`, a customized `URLSessionConfiguration` instance can be provided. Starting from the `URLSessionConfiguration.af.default` instance is recommended, as it adds the default `Accept-Encoding`, `Accept-Language`, and `User-Agent` headers provided by Alamofire, but any `URLSessionConfiguration` can be used.

```swift
let configuration = URLSessionConfiguration.af.default
configuration.allowsCellularAccess = false

let session = Session(configuration: configuration)
```

> `URLSessionConfiguration` is **not** the recommended location to set `Authorization` or `Content-Type` headers. Instead, add them to `Request`s using the provided `headers` APIs, using `ParameterEncoder`s, or a `RequestAdapter`.

> As Apple states in their [documentation](https://developer.apple.com/documentation/foundation/urlsessionconfiguration), mutating `URLSessionConfiguration` properties after the instance has been added to a `URLSession` (or, in Alamofire’s case, used to initialize a`Session`) has no effect.

### `SessionDelegate`

A `SessionDelegate` instance encapsulates all handling of the various `URLSessionDelegate` and related protocols callbacks. `SessionDelegate` also acts as the `SessionStateProvider` for every `Request` produced by Alamofire, allowing the `Request` to indirectly import state from the `Session` instance that created them. `SessionDelegate` can be customized with a specific `FileManager` instance, which will be used for any disk access, like accessing files to be uploaded by `UploadRequest`s or files downloaded by `DownloadRequest`s.

```swift
let delegate = SessionDelegate(fileManager: .default)
```

### `startRequestsImmediately`

By default, `Session` will call `resume()` on a `Request` as soon as it has added at least one response handler. Setting `startRequestsImmediately` to `false` requires that all `Request`s have `resume()` called manually.

```swift
let session = Session(startRequestsImmediately: false)
```

### A `Session`’s `DispatchQueue`s

By default, `Session` instances use a single `DispatchQueue` for all asynchronous work. This includes the `underlyingQueue` of the `URLSession`’s `delegate` `OperationQueue`, for all `URLRequest` creation, all response serialization work, and all internal `Session` and `Request` state mutation. If performance analysis shows a particular bottleneck around `URLRequest` creation or response serialization, `Session` can be provided with separate `DispatchQueue`s for each area of work.

```swift
let rootQueue = DispatchQueue(label: "com.app.session.rootQueue")
let requestQueue = DispatchQueue(label: "com.app.session.requestQueue")
let serializationQueue = DispatchQueue(label: "com.app.session.serializationQueue")

let session = Session(rootQueue: rootQueue,
                      requestQueue: requestQueue,
                      serializationQueue: serializationQueue)
```

Any custom `rootQueue` provided **MUST** be a serial queue, but `requestQueue` and `serializationQueue` can be either serial or parallel queues. Serial queues are the recommended default unless performance analysis shows work being delayed, in which case making the queues parallel may help overall performance.

### Adding a `RequestInterceptor`

Alamofire’s `RequestInterceptor` protocol (`RequestAdapter & RequestRetrier`) provides important and powerful request adaptation and retry features. It can be applied at both the `Session` and `Request` level. For more details on `RequestInterceptor` and the various implementations Alamofire includes, like `RetryPolicy`, see [below](#adapting-and-retrying-requests-with-requestinterceptor).

```swift
let policy = RetryPolicy()
let session = Session(interceptor: policy)
```

### Adding a `ServerTrustManager`

> For projects deploying to iOS 14, tvOS 14, watchOS 7, or macOS 11 or later, [Apple now provides built in pinning capabilities](https://developer.apple.com/news/?id=g9ejcf8y) configurable in your app's Info.plist. Please use that capability before implementing your own using Alamofire.

Alamofire’s `ServerTrustManager` class encapsulates mappings between domains and instances of `ServerTrustEvaluating`-conforming types, which provide the ability to customize a `Session`’s handling of TLS security. This includes the use of certificate and public key pinning as well as certificate revocation checking. For more information, see the section about the `ServerTrustManager` and `ServerTrustEvaluating`. Initializing a `ServerTrustManager` is as simple as providing a mapping between the domain and the type of evaluation to be performed:

```swift
let manager = ServerTrustManager(evaluators: ["httpbin.org": PinnedCertificatesTrustEvaluator()])
let session = Session(serverTrustManager: manager)
```

For more details on evaluating server trusts, see the detailed documentation [below](#evaluating-server-trusts-with-servertrustmanager-and-servertrustevaluating).

### Adding a `RedirectHandler`

Alamofire’s `RedirectHandler` protocol customizes the handling of HTTP redirect responses. It can be applied at both the `Session` and `Request` level. Alamofire includes the `Redirector` type which conforms to `RedirectHandler` and offers simple control over redirects. For more details on `RedirectHandler`, see the detailed documentation [below](#redirecthandler).

```swift
let redirector = Redirector(behavior: .follow)
let session = Session(redirectHandler: redirector)
```

### Adding a `CachedResponseHandler`

Alamofire’s `CachedResponseHandler` protocol customizes the caching of responses and can be applied at both the `Session` and `Request` level. Alamofire includes the `ResponseCacher` type which conforms to `CachedResponseHandler` and offers simple control over response caching. For more details, see the detailed documentation [below](#cachedresponsehandler).

```swift
let cacher = ResponseCacher(behavior: .cache)
let session = Session(cachedResponseHandler: cacher)
```

### Adding `EventMonitor`s

Alamofire’s `EventMonitor` protocol provides powerful insight into Alamofire’s internal events. It can be used to provide logging and other event-based features. `Session` accepts an array of `EventMonitor`-conforming instances at initialization time.

```swift
let monitor = ClosureEventMonitor()
monitor.requestDidCompleteTaskWithError = { (request, task, error) in
    debugPrint(request)
}
let session = Session(eventMonitors: [monitor])
```

### Operating on All Requests

Although use should be rare, `Session` provides the `withAllRequests` method to operate on all currently active `Request`s. This work is performed on the `Session`'s `rootQueue`, so it's important to keep it quick. If the work may take some time, creating a separate queue to process the `Set` of `Request`s should be used.

```swift
let session = ... // Some Session.
session.withAllRequests { requests in
    requests.forEach { $0.suspend() }
}
```

Additionally, `Session` offers a convenience method to cancel all `Request`s and call a completion handler when complete.

```swift
let session = ... // Some Session.
session.cancelAllRequests(completingOn: .main) { // completingOn uses .main by default.
    print("Cancelled all requests.")
}
```

> Note: These actions are performed asynchronously, so requests may be created or have finished by the time it's actually run, so it should not be assumed the action will be performed on a particular set of `Request`s.

### Creating Instances From `URLSession`s

In addition to the `convenience` initializer mentioned previously, `Session`s can be initialized directly from `URLSession`s. However, there are several requirements to keep in mind when using this initializer, so using the convenience initializer is recommended. These include:

- Alamofire does not support `URLSession`s configured for background use. This will lead to a runtime error when the `Session` is initialized.
- A `SessionDelegate` instance must be created and used as the `URLSession`’s `delegate`, as well as passed to the `Session` initializer.
- A custom `OperationQueue` must be passed as the `URLSession`’s `delegateQueue`. This queue must be a serial queue, it must have a backing `DispatchQueue`, and that `DispatchQueue` must be passed to the `Session` as its `rootQueue`.

```swift
let rootQueue = DispatchQueue(label: "org.alamofire.customQueue")
let queue = OperationQueue()
queue.maxConcurrentOperationCount = 1
queue.underlyingQueue = rootQueue
let delegate = SessionDelegate()
let configuration = URLSessionConfiguration.af.default
let urlSession = URLSession(configuration: configuration,
                            delegate: delegate,
                            delegateQueue: queue)
let session = Session(session: urlSession, delegate: delegate, rootQueue: rootQueue)
```

## Requests

Each request performed by Alamofire is encapsulated by particular class, `DataRequest`, `UploadRequest`, and `DownloadRequest`. Each of these classes encapsulate functionality unique to each type of request, but `DataRequest` and `DownloadRequest` inherit from a common superclass, `Request` (`UploadRequest` inherits from `DataRequest`). `Request` instances are never created directly, but are instead vended from a `Session` instance through one of the various `request` methods.

### The Request Pipeline

Once a `Request` subclass has been created with it’s initial parameters or `URLRequestConvertible` value, it is passed through the series of steps making up Alamofire’s request pipeline. For a successful request, these include:

1. Initial parameters, like HTTP method, headers, and parameters are encapsulated into an internal `URLRequestConvertible` value. If a `URLRequestConvertible` value is passed directly, that value is used unchanged.
2. `asURLRequest()` is called on the the `URLRequestConvertible` value, creating the first `URLRequest` value. This value is passed to the `Request` and stored in `requests`. If the `URLRequestConvertible` value was created from the parameters passed to a `Session` method, any provided `RequestModifier` is called when the `URLRequest` is created.
3. If there are any `Session` or `Request` `RequestAdapter`s or `RequestInterceptor`s, they’re called using the previously created `URLRequest`. The adapted `URLRequest` is then passed to the `Request` and stored in `request`s as well.
4. `Session` calls the `Request` to create the `URLSessionTask` to perform the network request based on the `URLRequest`.
5. Once the `URLSessionTask` is complete and `URLSessionTaskMetrics` have been gathered, the `Request` executes its `Validator`s.
6. Request executes any response handlers, such as `responseDecodable`, that have been appended.

At any one of these steps, a failure can be indicated through a created or received `Error` value, which is then passed to the associated `Request`. For example, aside from steps 1 and 4, all of the steps above can create an `Error` which is then passed to the response handlers or available for retry. Here are a few examples of what can or cannot fail throughout the `Request` pipeline.

1. Parameter encapsulation cannot fail.
2. Any `URLRequestConvertible` value can create an error when `asURLRequest()` is called. This allows for the initial validation of various `URLRequest` properties or the failure of parameter encoding.
3. `RequestAdapter`s can fail during adaptation, perhaps due to a missing authorization token.
4. `URLSessionTask` creation cannot fail.
5. `URLSessionTask`s can complete with errors for a variety of reasons, including network availability and cancellation. These `Error` values are passed back to the `Request`.
6. Response handlers can produce any `Error`, usually due to an invalid response or other parsing error.

Once an error is passed to the `Request`, the `Request` will attempt to run any `RequestRetrier`s associated with the `Session` or `Request`. If any `RequestRetrier`s choose to retry the `Request`, the complete pipeline is run again. `RequestRetrier`s can also produce `Error`s, which do not trigger retry.

### `Request`

Although `Request` doesn’t encapsulate any particular type of request, it contains the state and functionality common to all requests Alamofire performs. This includes:

#### State

All `Request` types include the notion of state, indicating the major events in the `Request`’s lifetime.

```swift
public enum State {
    case initialized
    case resumed
    case suspended
    case cancelled
    case finished
}
```

`Request`s start in the `.initialized` state after their creation. `Request`s can be suspended, resumed, and cancelled by calling the appropriate lifetime method.

- `resume()` resumes, or starts, a `Request`’s network traffic. If `startRequestsImmediately` is `true`, this is called automatically once a response handler has been added to the `Request`.
- `suspend()` suspends, or pauses the `Request` and its network traffic. `Request`s in this state can be resumed, but only `DownloadRequests` may be able continue transferring data. Other `Request`s will start over.
- `cancel()` cancels a `Request`. Once in this state, a `Request` cannot be resumed or suspended. When `cancel()` is called, the `Request`’s `error` property will be set with an `AFError.explicitlyCancelled` instance.
  If a `Request` is resumed and isn’t later cancelled, it will reach the `.finished` state once all response validators and response serializers have been run. However, if additional response serializers are added to the `Request` after it has reached the `.finished` state, it will transition back to the `.resumed` state and perform the network request again.

#### Progress

In order to track the progress of a request, `Request` offers a both `uploadProgress` and `downloadProgress` properties as well as closure-based `uploadProgress` and `downloadProgress` methods. Like all closure-based `Request` APIs, the progress APIs can be chained off of the `Request` with other methods. Also like the other closure-based APIs, they should be added to a request _before_ adding any response handlers, like `responseDecodable`.

```swift
AF.request(...)
    .uploadProgress { progress in
        print(progress)
    }
    .downloadProgress { progress in
        print(progress)
    }
    .responseDecodable(of: DecodableType.self) { response in
        debugPrint(response)
    }
```

Importantly, not all `Request` subclasses are able to report their progress accurately, or may have other dependencies to do so.

- For upload progress, progress can be determined in the following ways:
  - By the length of the `Data` object provided as the upload body to an `UploadRequest`.
  - By the length of a file on disk provided as the upload body of an `UploadRequest`.
  - By the value of the `Content-Length` header on the request, if it has been manually set.
- For download progress, there is a single requirement: - The server response must contain a `Content-Length` header.
  Unfortunately there may be other, undocumented requirements for progress reporting from `URLSession` which prevents accurate progress reporting.

#### Handling Redirects

Alamofire’s `RedirectHandler` protocol provides control and customization of redirect handling for `Request`. In addition to per-`Session` `RedirectHandler`s, each `Request` can be given its own `RedirectHandler` which overrides any provided by the `Session`.

```swift
let redirector = Redirector(behavior: .follow)
AF.request(...)
    .redirect(using: redirector)
    .responseDecodable(of: DecodableType.self) { response in
        debugPrint(response)
    }
```

> Note: Only one `RedirectHandler` can be set on a `Request`. Attempting to set more than one will result in a runtime exception.

#### Customizing Caching

Alamofire’s `CachedResponseHandler` protocol provides control and customization over the caching of responses. In addition to per-`Session` `CachedResponseHandler`s, each `Request` can be given its own `CachedResponseHandler` which overrides any provided by the `Session`.

```swift
let cacher = ResponseCacher(behavior: .cache)
AF.request(...)
    .cacheResponse(using: cacher)
    .responseDecodable(of: DecodableType.self) { response in
        debugPrint(response)
    }
```

> Note: Only one `CachedResponseHandler` can be set on a `Request`. Attempting to set more than one will result in a runtime exception.

#### Credentials

In order to take advantage of the automatic credential handling provided by `URLSession`, Alamofire provides per-`Request` API to allow the automatic addition of `URLCredential` instances to requests. These include both convenience API for HTTP authentication using a username and password, as well as any `URLCredential` instance.

Adding a credential to automatically reply to any HTTP authentication challenge is straightforward:

```swift
AF.request(...)
    .authenticate(username: "user@example.domain", password: "password")
    .responseDecodable(of: DecodableType.self) { response in
        debugPrint(response)
    }
```

> Note: This mechanism only supports HTTP authentication prompts. If a request requires an `Authentication` header for all requests, it should be provided directly, either as part of the `Request`, or through a `RequestInterceptor`.

Additionally, adding a raw `URLCredential` is just as easy:

```swift
let credential = URLCredential(...)
AF.request(...)
    .authenticate(using: credential)
    .responseDecodable(of: DecodableType.self) { response in
        debugPrint(response)
    }
```

#### Lifetime Values

Alamofire creates a variety of underlying values throughout the lifetime of a `Request`. Most of these are internal implementation details, but the creation of `URLRequest`s and `URLSessionTask`s are exposed to allow for direct interaction with other APIs.

##### A `Request`’s `URLRequest`s

Each network request issued by a `Request` is ultimately encapsulated in a `URLRequest` value created from the various parameters passed to one of the `Session` request methods. `Request` will keep a copy of these `URLRequest`s in its `requests` array property. These values include both the initial `URLRequest` created from the passed parameters, as well any `URLRequest`s created by `RequestInterceptor`s. That array does not, however, include the `URLRequest`s performed by the `URLSessionTask`s issued on behalf of the `Request`. To inspect those values, the `tasks` property gives access to all of the `URLSessionTasks` performed by the `Request`.

In addition to accumulating these values, every `Request` has an `onURLRequestCreation` method which calls a closure whenever a `URLRequest` is created for the `Request`. This `URLRequest` is the product of the initial parameters passed to the `Session`'s `request` method, as well as changes applied by any `RequestInterceptor`s. It will be called multiple times if the `Request` is retried and only one closure can be set at a time. `URLRequest` values cannot be modified in this closure; if you need to modify `URLRequest`s before they're issued, use a `RequestInterceptor` or compose your requests using the `URLRequestConvertible` protocol before passing them to Alamofire.

```swift
AF.request(...)
    .onURLRequestCreation { request in
        print(request)
    }
    .responseDecodable(of: DecodableType.self) { response in
        debugPrint(response)
    }
```

##### `URLSessionTask`s

In many ways, the various `Request` subclasses act as a wrapper for a `URLSessionTask` and present specific API for interacting with the different types of tasks. These tasks are made visible on the `Request` instance through the `tasks` array property. This includes both the initial task created for the `Request`, as well as any subsequent tasks created as part of the retry process, with one task per retry.

In addition to accumulating these values, every `Request` has an `onURLSessionTaskCreation` method which calls a closure whenever a `URLSessionTask` is created for the `Request`. This closure will be called multiple times if the `Request` is retried and only one closure can be set at a time. The provided `URLSessionTask` \*SHOULD **NOT\*** be used to interact with the `task`'s lifetime, which should only be done by the `Request` itself. Instead, you can use this method to provide the `Request`'s active `task` to other APIs, like `NSFileProvider`.

```swift
AF.request(...)
    .onURLSessionTaskCreation { task in
        print(task)
    }
    .responseDecodable(of: DecodableType.self) { response in
        debugPrint(response)
    }
```

#### Response

Each `Request` may have an `HTTPURLResponse` value available once the request is complete. This value is only available if the request wasn’t cancelled and didn’t fail to make the network request. Additionally, if the request is retried, only the _last_ response is available. Intermediate responses can be derived from the `URLSessionTask`s in the `tasks` property.

#### `URLSessionTaskMetrics`

Alamofire gathers `URLSessionTaskMetrics` values for every `URLSessionTask` performed for a `Request`. These values are available in the `metrics` property, with each value corresponding to the `URLSessionTask` in `tasks` at the same index.

`URLSessionTaskMetrics` are also made available on Alamofire’s various response types, like `DataResponse`. For instance:

```swift
AF.request(...)
    .responseDecodable(of: DecodableType.self) { response in {
        print(response.metrics)
    }
```

> Due to `FB7624529`, collection of `URLSessionTaskMetrics` on watchOS < 7 is currently disabled.

### `DataRequest`

`DataRequest` is a subclass of `Request` which encapsulates a `URLSessionDataTask` downloading a server response into `Data` stored in memory. Therefore, it’s important to realize that extremely large downloads may adversely affect system performance. For those types of downloads, using `DownloadRequest` to save the data to disk is recommended.

#### Additional State

`DataRequest`s have a few properties in addition to those provided by `Request`. These include `data`, which is the accumulated `Data` from the server response, and `convertible`, which is the `URLRequestConvertible` the `DataRequest` was created with, containing the original parameters creating the instance.

#### Validation

`DataRequest`s do not validate responses by default. Instead, a call to `validate()` must be added to the request in order to verify various properties are valid.

```swift
public typealias Validation = (URLRequest?, HTTPURLResponse, Data?) -> Result<Void, Error>
```

By default, adding `validate()` ensures the response status code is within the `200..<300` range and that the response’s `Content-Type` matches the request's `Accept` value. Validation can be further customized by passing a `Validation` closure:

```swift
AF.request(...)
    .validate { request, response, data in
        ...
    }
```

### `DataStreamRequest`

`DataStreamRequest` is a subclass of `Request` which encapsulates a `URLSessionDataTask` and streams `Data` from an HTTP connection over time.

#### Additional State

`DataStreamRequest` contains no additional public state.

#### Validation

`DataStreamRequest`s do not validate responses by default. Instead, a call to `validate()` must be added to the request in order to verify various properties are valid.

```swift
public typealias Validation = (_ request: URLRequest?, _ response: HTTPURLResponse) -> Result<Void, Error>
```

By default, adding `validate()` ensures the response status code is within the `200..<300` range and that the response’s `Content-Type` matches the request's `Accept` value. Validation can be further customized by passing a `Validation` closure:

```swift
AF.request(...)
    .validate { request, response in
        ...
    }
```

### `UploadRequest`

`UploadRequest` is a subclass of `DataRequest` which encapsulates a `URLSessionUploadTask`, uploading a `Data` value, file on disk, or `InputStream` to a remote server.

#### Additional State

`UploadRequest`s have a few properties in addition to those provided by `DataRequest`. These include a `FileManager` instance, used to customize access to disk when uploading a file, and `upload`, which encapsulates both the `URLRequestConvertible` value used to describe the request, as well as the `Uploadable`, which determines the type of upload being performed.

### `DownloadRequest`

`DownloadRequest` is a concrete subclass of `Request` which encapsulates a `URLSessionDownloadTask`, downloading response `Data` to disk.

#### Additional State

`DownloadRequest`s have a few properties in addition to those provided by `Request`. These include `resumeData`, the `Data` produced when cancelling a `DownloadRequest`, which may be used to resume the download later, and `fileURL`, the `URL` at which the downloaded file is available once the download completes.

#### Cancellation

In addition to supporting the `cancel()` method provided by `Request`, `DownloadRequest` includes `cancel(producingResumeData shouldProduceResumeData: Bool)`, which optionally populates the `resumeData` property when cancelled, if possible, and `cancel(byProducingResumeData completionHandler: @escaping (_ data: Data?) -> Void)`, which provides the produced resume data to the passed closure.

```swift
AF.download(...)
    .cancel { resumeData in
        ...
    }
```

#### Validation

`DownloadRequest` supports a slightly different version of validation than `DataRequest` and `UploadRequest`, due to the fact it’s data is downloaded to disk.

```swift
public typealias Validation = (_ request: URLRequest?, _ response: HTTPURLResponse, _ fileURL: URL?)
```

Instead of accessing the downloaded `Data` directly it must be accessed using the `fileURL` provided. Otherwise, the capabilities of `DownloadRequest`’s validators are the same as `DataRequest`’s.

## Adapting and Retrying Requests with `RequestInterceptor`

Alamofire’s `RequestInterceptor` protocol (composed of the `RequestAdapter` and `RequestRetrier` protocols) enables powerful per-`Session` and per-`Request` capabilities. These include authentication systems, where a common header is added to every `Request` and `Request`s are retried when authorization expires. Additionally, Alamofire includes a built in `RetryPolicy` type, which enables easy retry when requests fail due to a variety of common network errors.

### `RequestAdapter`

Alamofire’s `RequestAdapter` protocol allows each `URLRequest` that’s to be performed by a `Session` to be inspected and mutated before being issued over the network. One very common use of an adapter is to add an `Authorization` header to requests behind a certain type of authentication.

The `RequestAdapter` protocol has one required method:

```swift
func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void)
```

Its parameters include:

- `urlRequest`: The `URLRequest` initially created from the parameters or `URLRequestConvertible` value used to create the `Request`.
- `session`: The `Session` which created the `Request` for which the adapter is being called.
- `completion`: The asynchronous completion handler that _must_ be called to indicate the adapter is finished. It’s asynchronous nature enables `RequestAdapter`s to access asynchronous resources from the network or disk before the `Request` is sent over the network. The `Result` provided to the `completion` closure can either return a `.success` value with the modified `URLRequest` value, or a `.failure` value with an associated `Error` which will then be used to fail the `Request`.
  For example, adding an `Authorization` header requires modifying the `URLRequest` and then calling the completion handler.

```swift
let accessToken: String

func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
    var urlRequest = urlRequest
    urlRequest.headers.add(.authorization(bearerToken: accessToken))

    completion(.success(urlRequest))
}
```

The `RequestAdapter` also contains a second method with a default protocol extension implementation to support backwards compatibility:

```swift
func adapt(_ urlRequest: URLRequest, using state: RequestAdapterState, completion: @escaping (Result<URLRequest, Error>) -> Void)
```

This second method uses a `RequestAdapterState` type to expose additional internal state beyond the first method including:

- `requestID`: The `UUID` of the `Request` associated with the `URLRequest` to adapt.

This `requestID` is very useful when trying to map custom types associated with the original `Request` to perform custom operations inside the `RequestAdapter`.

> This second method will become the new requirement in the next MAJOR version of Alamofire.

### `RequestRetrier`

Alamofire’s `RequestRetrier` protocol allows a `Request` that encountered an `Error` while being executed to be retried. This includes `Error`s produced at any stage of Alamofire’s [request pipeline](#the-request-pipeline).

`RequestRetrier` has a single requirement.

```swift
func retry(_ request: Request, for session: Session, dueTo error: Error, completion: @escaping (RetryResult) -> Void)
```

Its parameters include:

- `request`: The `Request` which encountered an error.
- `session`: The `Session` managing the `Request`.
- `error`: The `Error` which triggered the retry attempt. Usually an `AFError`.
- `completion`: The asynchronous completion handler that _must_ be called to indicate whether the `Request` should be retried. It must be called with a `RetryResult`.

The `RetryResult` type represents the outcome of whatever logic is implemented in the `RequestRetrier`. It’s defined as:

```swift
/// Outcome of determination whether retry is necessary.
public enum RetryResult {
    /// Retry should be attempted immediately.
    case retry
    /// Retry should be attempted after the associated `TimeInterval`.
    case retryWithDelay(TimeInterval)
    /// Do not retry.
    case doNotRetry
    /// Do not retry due to the associated `Error`.
    case doNotRetryWithError(Error)
}
```

For example, Alamofire’s `RetryPolicy` type will automatically retry `Request`s that fail due to a network error of some kind, if the request is idempotent.

```swift
open func retry(_ request: Request, for session: Session, dueTo error: Error, completion: @escaping (RetryResult) -> Void) {
    if request.retryCount < retryLimit,
       let httpMethod = request.request?.method,
       retryableHTTPMethods.contains(httpMethod),
       shouldRetry(response: request.response, error: error) {
        let timeDelay = pow(Double(exponentialBackoffBase), Double(request.retryCount)) * exponentialBackoffScale
        completion(.retryWithDelay(timeDelay))
    } else {
        completion(.doNotRetry)
    }
}
```

### Using Multiple `RequestInterceptor`s

Alamofire supports the use of multiple `RequestInterceptor`s at both the `Session` and `Request` levels through the use of the `Interceptor` type. `Interceptor`s can be composed of adapter and retrier closures, a single combination of a `RequestAdapter` and `RequestRetrier`, or a combination of arrays of `RequestAdapter`s, `RequestRetrier`s, and `RequestInterceptor`s.

```swift
let adapter = // Some RequestAdapter
let retrier = // Some RequestRetrier
let interceptor = // Some RequestInterceptor

let adapterAndRetrier = Interceptor(adapter: adapter, retrier: retrier)
let composite = Interceptor(interceptors: [adapterAndRetrier, interceptor])
```

When composed of multiple `RequestAdapter`s, `Interceptor` will call each `RequestAdapter` in succession. If they all succeed, the final `URLRequest` out of the chain of `RequestAdapter`s will be used to perform the request. If one fails, adaptation stops and the `Request` fails with the error returned. Similarly, when composed of multiple `RequestRetrier`s, retries are executed in the same order as the retriers were added to the instance, until either all of them complete or one of them fails with an error.

### `AuthenticationInterceptor`

Alamofire's `AuthenticationInterceptor` class is a `RequestInterceptor` designed to handle the queueing and threading complexity involved with authenticating requests.
It leverages an injected `Authenticator` protocol that manages the lifecycle of the matching `AuthenticationCredential`.
Here is a simple example of how an `OAuthAuthenticator` class could be implemented along with an `OAuthCredential`.

**`OAuthCredential`**

```swift
struct OAuthCredential: AuthenticationCredential {
    let accessToken: String
    let refreshToken: String
    let userID: String
    let expiration: Date

    // Require refresh if within 5 minutes of expiration
    var requiresRefresh: Bool { Date(timeIntervalSinceNow: 60 * 5) > expiration }
}
```

**`OAuthAuthenticator`**

```swift
class OAuthAuthenticator: Authenticator {
    func apply(_ credential: OAuthCredential, to urlRequest: inout URLRequest) {
        urlRequest.headers.add(.authorization(bearerToken: credential.accessToken))
    }

    func refresh(_ credential: OAuthCredential,
                 for session: Session,
                 completion: @escaping (Result<OAuthCredential, Error>) -> Void) {
        // Refresh the credential using the refresh token...then call completion with the new credential.
        //
        // The new credential will automatically be stored within the `AuthenticationInterceptor`. Future requests will
        // be authenticated using the `apply(_:to:)` method using the new credential.
    }

    func didRequest(_ urlRequest: URLRequest,
                    with response: HTTPURLResponse,
                    failDueToAuthenticationError error: Error) -> Bool {
        // If authentication server CANNOT invalidate credentials, return `false`
        return false

        // If authentication server CAN invalidate credentials, then inspect the response matching against what the
        // authentication server returns as an authentication failure. This is generally a 401 along with a custom
        // header value.
        // return response.statusCode == 401
    }

    func isRequest(_ urlRequest: URLRequest, authenticatedWith credential: OAuthCredential) -> Bool {
        // If authentication server CANNOT invalidate credentials, return `true`
        return true

        // If authentication server CAN invalidate credentials, then compare the "Authorization" header value in the
        // `URLRequest` against the Bearer token generated with the access token of the `Credential`.
        // let bearerToken = HTTPHeader.authorization(bearerToken: credential.accessToken).value
        // return urlRequest.headers["Authorization"] == bearerToken
    }
}
```

**Usage**

```swift
// Generally load from keychain if it exists
let credential = OAuthCredential(accessToken: "a0",
                                 refreshToken: "r0",
                                 userID: "u0",
                                 expiration: Date(timeIntervalSinceNow: 60 * 60))

// Create the interceptor
let authenticator = OAuthAuthenticator()
let interceptor = AuthenticationInterceptor(authenticator: authenticator,
                                            credential: credential)

// Execute requests with the interceptor
let session = Session()
let urlRequest = URLRequest(url: URL(string: "https://api.example.com/example/user")!)
session.request(urlRequest, interceptor: interceptor)
```

### Compressing Request Body Data With `DeflateRequestCompressor`

When sending requests with very large bodies, such as large JSON objects (hundreds of KB or more, but not data that's already compressed, like images), it may be beneficial for performance and the user's data usage to compress outgoing request bodies. The `DeflateRequestCompressor` `RequestInterceptor` can be used to perform such compression using the `deflate` `Content-Encoding`.

Adding a compressor to a `Request` can be done like any other `RequestInterceptor`:

```swift
session.request(..., interceptor: .deflateCompressor)
```

If there are other uses of the `Content-Encoding` header in the request pipeline, it may be necessary to customize `DeflateRequestCompressor`'s behavior when it encounters a request that already has such a header. In that case you can provide a `DuplicateHeaderBehavior` value to determine what should happen. By default `DeflateRequestCompressor` will produce a `DuplicateHeaderError` that will fail the request.

```swift
/// Type that determines the action taken when the `URLRequest` already has a `Content-Encoding` header.
public enum DuplicateHeaderBehavior {
    /// Throws a `DuplicateHeaderError`. The default.
    case error
    /// Replaces the existing header value with `deflate`.
    case replace
    /// Silently skips compression when the header exists.
    case skip
}
```

This value can be provided when creating a compressor:

```swift
session.request(..., interceptor: .deflateCompressor(duplicateHeaderBehavior: .replace))
```

Adding a compressor is only suggested for requests which are known to produce large body data, but the compressor can also be added `Session` instances directly. In that case the `shouldCompressBodyData` closure should be used to determine whether or not to apply compression. This would usually be based on the overall size of the body data.

```swift
let compressor = DeflateRequestCompressor { bodyData in
  bodyData.count > 100 * 1024 // Only compress when bodyData exceeds 100KB.
}

let session = Session(..., interceptor: compressor)
```

The most beneficial compression limit will be determined by the user's network capacity (if users are usually on 5G or wifi, request compression is less valuable) and typical device (audiences with older devices may be more impacted by compression), so testing should be done to determine whether compression is valuable and what the limit should be.

## Security

Using a secure HTTPS connection when communicating with servers and web services is an important step in securing sensitive data. By default, Alamofire receives the same automatic TLS certificate and certificate chain validation as `URLSession`. While this guarantees the certificate chain is valid, it does not prevent man-in-the-middle (MITM) attacks or other potential vulnerabilities. In order to mitigate MITM attacks, applications dealing with sensitive customer data or financial information should use certificate or public key pinning provided by Alamofire’s `ServerTrustEvaluating` protocol.

### Evaluating Server Trusts with `ServerTrustManager` and `ServerTrustEvaluating`

#### `ServerTrustEvaluating`

The `ServerTrustEvaluating` protocol provides a way to perform any sort of server trust evaluation. It has a single requirement:

```swift
func evaluate(_ trust: SecTrust, forHost host: String) throws
```

This method provides the [`SecTrust`](https://developer.apple.com/documentation/security/certificate_key_and_trust_services/trust) value and host `String` received from the underlying `URLSession` and provides the opportunity to perform various evaluations.

Alamofire includes many different types of trust evaluators, providing composable control over the evaluation process:

- `DefaultTrustEvaluator`: Uses the default server trust evaluation while allowing you to control whether to validate the host provided by the challenge.
- `RevocationTrustEvaluator`: Checks the status of the received certificate to ensure it hasn’t been revoked. This isn’t usually performed on every request due to the network request overhead it entails.
- `PinnedCertificatesTrustEvaluator`: Uses the provided certificates to validate the server trust. The server trust is considered valid if one of the pinned certificates match one of the server certificates. This evaluator can also accept self-signed certificates.
- `PublicKeysTrustEvaluator`: Uses the provided public keys to validate the server trust. The server trust is considered valid if one of the pinned public keys match one of the server certificate public keys.
- `CompositeTrustEvaluator`: Evaluates an array of `ServerTrustEvaluating` values, only succeeding if all of them are successful. This type can be used to combine, for example, the `RevocationTrustEvaluator` and the `PinnedCertificatesTrustEvaluator`.
- `DisabledTrustEvaluator`: This evaluator should only be used in debug scenarios as it disables all evaluation which in turn will always consider any server trust as valid. This evaluator should **never** be used in production environments!

#### `ServerTrustManager`

The `ServerTrustManager` is responsible for storing an internal mapping of `ServerTrustEvaluating` values to a particular host. This allows Alamofire to evaluate each host with different evaluators.

```swift
let evaluators: [String: ServerTrustEvaluating] = [
    // By default, certificates included in the app bundle are pinned automatically.
    "cert.example.com": PinnedCertificatesTrustEvaluator(),
    // By default, public keys from certificates included in the app bundle are used automatically.
    "keys.example.com": PublicKeysTrustEvaluator(),
]

let manager = ServerTrustManager(evaluators: evaluators)
```

This `ServerTrustManager` will have the following behaviors:

- `cert.example.com` will always use certificate pinning with default and host validation enabled , thus requiring the following criteria to be met in order to allow the TLS handshake to succeed:
  - Certificate chain _must_ be valid.
  - Certificate chain _must_ include one of the pinned certificates.
  - Challenge host _must_ match the host in the certificate chain's leaf certificate.
- `keys.example.com` will always use public key pinning with default and host validation enabled, thus requiring the following criteria to be met in order to allow the TLS handshake to succeed:
  - Certificate chain _must_ be valid.
  - Certificate chain _must_ include one of the pinned public keys.
  - Challenge host _must_ match the host in the certificate chain's leaf certificate.
- Requests to other hosts will produce an error, as `ServerTrustManager` requires all hosts to be evaluated by default.

##### Subclassing `ServerTrustManager`

If you find yourself needing more flexible server trust policy matching behavior (i.e. wildcard domains), then subclass the `ServerTrustManager` and override the `serverTrustEvaluator(forHost:)` method with your own custom implementation.

```swift
final class CustomServerTrustManager: ServerTrustManager {
    override func serverTrustEvaluator(forHost host: String) -> ServerTrustEvaluating? {
        var policy: ServerTrustPolicy?

        // Implement your custom domain matching behavior...

        return policy
    }
}
```

### App Transport Security

With the addition of App Transport Security (ATS) in iOS 9, it is possible that using a custom `ServerTrustManager` with several `ServerTrustEvaluating` objects will have no effect. If you continuously see `CFNetwork SSLHandshake failed (-9806)` errors, you have probably run into this problem. Apple's ATS system overrides the entire challenge system unless you configure the ATS settings in your app's plist to disable enough of it to allow your app to evaluate the server trust. If you run into this problem (high probability with self-signed certificates), you can work around this issue by adding [`NSAppTransportSecurity` overrides](https://developer.apple.com/documentation/bundleresources/information_property_list/nsapptransportsecurity) to your `Info.plist`. You can use the `nscurl` tool’s `--ats-diagnostics` option to perform a series of tests against a host to see which ATS overrides might be required.

#### Using Self-Signed Certificates with Local Networking

If you are attempting to connect to a server running on your localhost, and you are using self-signed certificates, you will need to add the following to your `Info.plist`.

```xml
<dict>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsLocalNetworking</key>
        <true/>
    </dict>
</dict>
```

According to [Apple documentation](https://developer.apple.com/library/content/documentation/General/Reference/InfoPlistKeyReference/Articles/CocoaKeys.html#//apple_ref/doc/uid/TP40009251-SW35), setting `NSAllowsLocalNetworking` to `YES` allows loading local resources without disabling ATS for the rest of your app.

## Customizing Caching and Redirect Handling

`URLSession` allows the customization of caching and redirect behaviors using `URLSessionDataDelegate` and `URLSessionTaskDelegate` methods. Alamofire surfaces these customization points as the `CachedResponseHandler` and `RedirectHandler` protocols.

### `CachedResponseHandler`

The `CachedResponseHandler` protocol allows control over the caching of HTTP responses into the `URLCache` instance associated with the `Session` making a request. The protocol has a single requirement:

```swift
func dataTask(_ task: URLSessionDataTask,
              willCacheResponse response: CachedURLResponse,
              completion: @escaping (CachedURLResponse?) -> Void)
```

As can be seen in the method signature, this control only applies to `Request`s that use an underlying `URLSessionDataTask` for network transfers, which include `DataRequest`s and `UploadRequest`s (since `URLSessionUploadTask` is a subclass of `URLSessionDataTask`). The conditions under which a response will be considered for caching are extensive, so it’s best to review the documentation of the `URLSessionDataDelegate` method [`urlSession(_:dataTask:willCacheResponse:completionHandler:)`](https://developer.apple.com/documentation/foundation/urlsessiondatadelegate/1411612-urlsession). Once a response is considered for caching, there are variety of valuable manipulations that can be made:

- Prevent caching the response altogether by returning a `nil` `CachedURLResponse`.
- Modify the `CachedURLResponse`’s `storagePolicy` to change where the cached value should live.
- Modify the underlying `URLResponse` directly, adding or removing values.
- Modify the `Data` associated with the response, if any.

Alamofire includes the `ResponseCacher` type which conforms to `CachedResponseHandler`, making it easy to cache, not cache, or modify a response. `ResponseCacher` takes a `Behavior` value to control the caching behavior.

```swift
public enum Behavior {
    /// Stores the cached response in the cache.
    case cache
    /// Prevents the cached response from being stored in the cache.
    case doNotCache
    /// Modifies the cached response before storing it in the cache.
    case modify((URLSessionDataTask, CachedURLResponse) -> CachedURLResponse?)
}
```

`ResponseCacher` can be used on both a `Session` and `Request` basis, as outlined above.

### `RedirectHandler`

The `RedirectHandler` protocol allows control over the redirect behavior of particular `Request`s. It has a single requirement:

```swift
func task(_ task: URLSessionTask,
          willBeRedirectedTo request: URLRequest,
          for response: HTTPURLResponse,
          completion: @escaping (URLRequest?) -> Void)
```

This method provides an opportunity to modify the redirected `URLRequest` or pass `nil` to disable the redirect entirely. Alamofire provides the `Redirector`type which conforms to `RedirectHandler`, making it easy to follow, not follow, or modify a redirected request. `Redirector` takes a `Behavior` value to control the redirect behavior.

```swift
public enum Behavior {
    /// Follow the redirect as defined in the response.
    case follow
    /// Do not follow the redirect defined in the response.
    case doNotFollow
    /// Modify the redirect request defined in the response.
    case modify((URLSessionTask, URLRequest, HTTPURLResponse) -> URLRequest?)
}
```

`Redirector` can be used on both a `Session` and `Request` basis, as outlined above.

## Using `EventMonitor`s

The `EventMonitor` protocol allows the observation and inspection of a large number of internal Alamofire events. These include all `URLSessionDelegate`, `URLSessionTaskDelegate`, and `URLSessionDownloadDelegate` methods implemented by Alamofire as well as a large number of internal `Request` events. In addition to these events, which by default are an empty method that does no work, the `EventMonitor` protocol also requires a `DispatchQueue` on which all the events are dispatched in order to maintain performance. This `DispatchQueue` defaults to `.main`, but dedicated serial queues are recommended for any custom conforming types.

### Logging

Perhaps the biggest use of the `EventMonitor` protocol is to implement the logging of relevant events. A simple implementation may look something like this:

```swift
final class Logger: EventMonitor {
    let queue = DispatchQueue(label: ...)

    // Event called when any type of Request is resumed.
    func requestDidResume(_ request: Request) {
        print("Resuming: \(request)")
    }

    // Event called whenever a DataRequest has parsed a response.
    func request<Value>(_ request: DataRequest, didParseResponse response: DataResponse<Value, AFError>) {
        debugPrint("Finished: \(response)")
    }
}
```

This `Logger` type can be added to a `Session` in the same way demonstrated above:

```swift
let logger = Logger()
let session = Session(eventMonitors: [logger])
```

## Making Requests

As a framework, Alamofire has two main goals:

1. To enable the easy implementation of network requests for prototypes and tools
2. To serve as the generic foundation of app networking

It accomplishes these goals through the use of powerful abstractions, providing useful defaults, and included implementations of common tasks. However, once use of Alamofire has gone beyond a few requests, it’s necessary to move beyond the high level, default implementations into behavior customized for particular applications. Alamofire provides the `URLConvertible` and `URLRequestConvertible` protocols to help with this customization.

### `URLConvertible`

Types adopting the `URLConvertible` protocol can be used to construct URLs, which are then used to construct URL requests internally. `String`, `URL`, and `URLComponents` conform to `URLConvertible` by default, allowing any of them to be passed as `url` parameters to the `request`, `upload`, and `download` methods:

```swift
let urlString = "https://httpbin.org/get"
AF.request(urlString)

let url = URL(string: urlString)!
AF.request(url)

let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)!
AF.request(urlComponents)
```

Applications interacting with web applications in a significant manner are encouraged to have custom types conform to `URLConvertible` as a convenient way to map domain-specific models to server resources.

### `URLRequestConvertible`

Types adopting the `URLRequestConvertible` protocol can be used to construct `URLRequest`s. `URLRequest` conforms to `URLRequestConvertible` by default, allowing it to be passed into `request`, `upload`, and `download` methods directly. Alamofire uses `URLRequestConvertible` as the foundation of all requests flowing through the request pipeline. Using `URLRequest`s directly is the recommended way to customize `URLRequest` creation outside of the `ParameterEncoder`s that Alamofire provides.

```swift
let url = URL(string: "https://httpbin.org/post")!
var urlRequest = URLRequest(url: url)
urlRequest.method = .post

let parameters = ["foo": "bar"]

do {
    urlRequest.httpBody = try JSONEncoder().encode(parameters)
} catch {
    // Handle error.
}

urlRequest.headers.add(.contentType("application/json"))

AF.request(urlRequest)
```

Applications interacting with web applications in a significant manner are encouraged to have custom types conform to `URLRequestConvertible` as a way to ensure consistency of requested endpoints. Such an approach can be used to abstract away server-side inconsistencies and provide type-safe routing, as well as manage other state.

### Routing Requests

As apps grow in size, it's important to adopt common patterns as you build out your network stack. An important part of that design is how to route your requests. The Alamofire `URLConvertible` and `URLRequestConvertible` protocols along with the `Router` design pattern are here to help.

A “router” is a type that defines “routes”, or the components of a request. These components can include the parts of a `URLRequest`, the parameters required to make a request, as well as various per-request Alamofire settings. A simple router could look something like this:

```swift
enum Router: URLRequestConvertible {
    case get, post

    var baseURL: URL {
        return URL(string: "https://httpbin.org")!
    }

    var method: HTTPMethod {
        switch self {
        case .get: return .get
        case .post: return .post
        }
    }

    var path: String {
        switch self {
        case .get: return "get"
        case .post: return "post"
        }
    }

    func asURLRequest() throws -> URLRequest {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.method = method

        return request
    }
}

AF.request(Router.get)
```

More complex routers may include the parameters of a request. With Alamofire’s `ParameterEncoder` protocol and included encoders, any `Encodable` type can be used as parameters:

```swift
enum Router: URLRequestConvertible {
    case get([String: String]), post([String: String])

    var baseURL: URL {
        return URL(string: "https://httpbin.org")!
    }

    var method: HTTPMethod {
        switch self {
        case .get: return .get
        case .post: return .post
        }
    }

    var path: String {
        switch self {
        case .get: return "get"
        case .post: return "post"
        }
    }

    func asURLRequest() throws -> URLRequest {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.method = method

        switch self {
        case let .get(parameters):
            request = try URLEncodedFormParameterEncoder().encode(parameters, into: request)
        case let .post(parameters):
            request = try JSONParameterEncoder().encode(parameters, into: request)
        }

        return request
    }
}
```

Routers can be expanded for any number of endpoints with any number of configurable properties, but once a certain level of complexity has been reached, separating one big router into smaller routers for parts of an API should be considered.

## Response Handling

Alamofire provides response handling through various `response` methods and the `ResponseSerializer` protocol.

### Handling Responses Without Serialization

Both `DataRequest` and `DownloadRequest` offer methods that allow response handling without invoking any `ResponseSerializer` at all. This is most important for `DownloadRequest`s where loading large files into memory may not be possible.

```swift
// DataRequest
func response(queue: DispatchQueue = .main, completionHandler: @escaping (AFDataResponse<Data?>) -> Void) -> Self

// DownloadRequest
func response(queue: DispatchQueue = .main, completionHandler: @escaping (AFDownloadResponse<URL?>) -> Void) -> Self
```

As with all response handlers, all serialization work (in this case none) is performed on an internal queue and the completion handler called on the `queue` passed to the method. This means that it’s not necessary to dispatch back to the `main` queue by default. However, if there is to be any significant work performed in the completion handler, passing a custom queue to the response methods is recommended, with a dispatch back to `main` in the handler itself if necessary.

### `ResponseSerializer`

The `ResponseSerializer` protocol is composed of the `DataResponseSerializerProtocol` and `DownloadResponseSerializerProtocol` protocols. The combined version of `ResponseSerializer` looks like this:

```swift
public protocol ResponseSerializer: DataResponseSerializerProtocol & DownloadResponseSerializerProtocol {
    /// The type of serialized object to be created.
    associatedtype SerializedObject

    /// `DataPreprocessor` used to prepare incoming `Data` for serialization.
    var dataPreprocessor: DataPreprocessor { get }
    /// `HTTPMethod`s for which empty response bodies are considered appropriate.
    var emptyRequestMethods: Set<HTTPMethod> { get }
    /// HTTP response codes for which empty response bodies are considered appropriate.
    var emptyResponseCodes: Set<Int> { get }

    func serialize(request: URLRequest?, response: HTTPURLResponse?, data: Data?, error: Error?) throws -> SerializedObject
    func serializeDownload(request: URLRequest?,
                           response: HTTPURLResponse?,
                           fileURL: URL?,
                           error: Error?) throws -> SerializedObject
}
```

By default, the `serializeDownload` method is implemented by reading the downloaded `Data` from disk and calling `serialize` with it. Therefore, it may be more appropriate to implement custom handling for large downloads using `DownloadRequest`’s `response(queue:completionHandler:)` method mentioned above.

`ResponseSerializer` provides various default implementations for the `dataPreprocessor`, `emptyResponseMethods`, and `emptyResponseCodes` which can be customized in conforming types, like various `ResponseSerializer`s included with Alamofire.

All `ResponseSerializer` usage flows through methods on `DataRequest` and `DownloadRequest`:

```swift
// DataRequest
func response<Serializer: DataResponseSerializerProtocol>(
    queue: DispatchQueue = .main,
    responseSerializer: Serializer,
    completionHandler: @escaping (AFDataResponse<Serializer.SerializedObject>) -> Void) -> Self

// DownloadRequest
func response<Serializer: DownloadResponseSerializerProtocol>(
    queue: DispatchQueue = .main,
    responseSerializer: Serializer,
    completionHandler: @escaping (AFDownloadResponse<Serializer.SerializedObject>) -> Void) -> Self
```

Alamofire includes a few common responses handlers, including:

- `responseData(queue:completionHandler)`: Validates and preprocesses the response `Data` using `DataResponseSerializer`.
- `responseString(queue:encoding:completionHandler:)`: Parses the response `Data` as a `String` using the provided `String.Encoding`.
- `responseDecodable(of:queue:decoder:completionHandler:)`: Parses the response `Data` into the provided or inferred `Decodable` type using the provided `DataDecoder`. Uses `JSONDecoder` by default. Recommend method for JSON and generic response parsing.

#### `DataResponseSerializer`

Calling `responseData(queue:completionHandler:)` on `DataRequest` or `DownloadRequest` uses a `DataResponseSerializer` to validate that `Data` has been returned appropriately (no empty responses unless allowed by the `emptyResponseMethods` and `emptyResponseCodes`) and passes that `Data` through the `dataPreprocessor`. This response handler is useful for customized `Data` handling but isn’t usually necessary.

#### `StringResponseSerializer`

Calling `responseString(queue:encoding:completionHandler)` on `DataRequest` or `DownloadRequest` uses a `StringResponseSerializer` to validate that `Data` has been returned appropriately (no empty responses unless allowed by the `emptyResponseMethods` and `emptyResponseCodes`) and passes that `Data` through the `dataPreprocessor`. The preprocessed `Data` is then used to initialize a `String` using the `String.Encoding` parsed from the `HTTPURLResponse`.

#### `DecodableResponseSerializer`

Calling `responseDecodable(of:queue:decoder:completionHandler)` on `DataRequest` or `DownloadRequest` uses a `DecodableResponseSerializer`to validate that `Data` has been returned appropriately (no empty responses unless allowed by the `emptyResponseMethods` and `emptyResponseCodes`) and passes that `Data` through the `dataPreprocessor`. The preprocessed `Data` is then passed through the provided `DataDecoder` and parsed into the provided or inferred `Decodable` type.

### Customizing Response Handlers

In addition to the flexible `ResponseSerializer`s included with Alamofire, there are additional ways to customize response handling.

#### Response Transforms

Using an existing `ResponseSerializer` and then transforming the output is one of the simplest ways of customizing response handlers. Both `DataResponse` and `DownloadResponse` have `map`, `tryMap`, `mapError`, and `tryMapError` methods that can transform responses while preserving the metadata associated with the response. For example, extracting a property from a `Decodable` response can be achieved using `map`, while also preserving any previous parsing errors.

```swift
AF.request(...).responseDecodable(of: DecodableType.self) { response in
    let propertyResponse = response.map { $0.someProperty }

    debugPrint(propertyResponse)
}
```

Transforms that throw errors can also be used with `tryMap`, perhaps to perform validation:

```swift
AF.request(..).responseDecodable(of: DecodableType.self) { response in
    let propertyResponse = response.tryMap { try $0.someProperty.validated() }

    debugPrint(propertyResponse)
}
```

#### Creating a Custom Response Serializer

When Alamofire’s provided `ResponseSerializer`s or response transforms aren’t flexible enough, or the amount of customization is extensive, creating a `ResponseSerializer` is a good way to encapsulate that logic. There are usually two parts to integrating a custom `ResponseSerializer`: creating the conforming type and extending the relevant `Request` type(s) to make it convenient to use. For example, if a server returned a specially encoded `String`, perhaps values separated by commas, the `ResponseSerializer` for such a format could look something like this:

```swift
struct CommaDelimitedSerializer: ResponseSerializer {
    func serialize(request: URLRequest?, response: HTTPURLResponse?, data: Data?, error: Error?) throws -> [String] {
        // Call the existing StringResponseSerializer to get many behaviors automatically.
        let string = try StringResponseSerializer().serialize(request: request,
                                                              response: response,
                                                              data: data,
                                                              error: error)

        return Array(string.split(separator: ","))
    }
}
```

Note that the `SerializedObject` `associatedtype` requirement is met by the return type of the `serialize` method. In more complex serializers, this return type itself can be generic, allowing the serialization of generic types, as seen by the `DecodableResponseSerializer`.

To make the `CommaDelimitedSerializer` more useful, additional behaviors could be added, like allowing the customization of empty HTTP methods and response codes by passing them through to the underlying `StringResponseSerializer`.

### Streaming Response Handlers

`DataStreamRequest` uses its own unique response handler type to process incoming `Data` as part of a stream. In addition to the provided handlers, custom serialization can be performed through the use of the `DataStreamSerializer` protocol.

```swift
public protocol DataStreamSerializer {
    /// Type produced from the serialized `Data`.
    associatedtype SerializedObject

    /// Serializes incoming `Data` into a `SerializedObject` value.
    ///
    /// - Parameter data: `Data` to be serialized.
    ///
    /// - Throws: Any error produced during serialization.
    func serialize(_ data: Data) throws -> SerializedObject
}
```

Any custom `DataStreamSerializer` can be used to process streaming `Data` by using the `responseStream` method:

```swift
AF.streamRequest(...).responseStream(using: CustomSerializer()) { stream in
    // Process stream.
}
```

Alamofire includes `DecodableStreamSerializer`, a `DataStreamSerializer` which can parse `Decodable` types from incoming `Data`. It can be customized with both a `DataDecoder` instance and a `DataPreprocessor` and used through the `responseStreamDecodable` method:

```swift
AF.streamRequest(...).responseDecodable(of: DecodableType.self) { stream in
    // Process stream.
}
```

Or by using it directly in the previously mentioned `streamResponse` method:

```swift
AF.streamRequest(...).responseStream(using: DecodableStreamSerializer<DecodableType>(decoder: JSONDecoder())) { stream in
    // Process stream.
}
```

## Using Alamofire with Combine

On systems supporting the Combine framework, Alamofire offers the ability to publish responses using a custom `Publisher` type. These publishers work much like Alamofire's response handlers. They are chained onto requests and, like response handlers, should come after other API like `validate()`. For example:

```swift
AF.request(...).publishDecodable(type: DecodableType.self)
```

This code produces a `DataResponsePublisher<DecodableType>` value which will publish a `DataResponse<DecodableType, AFError>` value. Like all Alamofire `Publisher`s, `DataResponsePublisher` is fully lazy, meaning that will only add the response handler and `resume` the request once a downstream `Subscriber` has made demand for values. It only provides one value and cannot be retried.

> To properly handle retry when using Alamofire's `Publisher`s, use Alamofire's built in retry mechanisms, as explained [above](#adapting-and-retrying-requests-with-requestinterceptor).

Additionally, `DataResponsePublisher` provides the ability to transform the outgoing `DataResponse<Success, Failure>` into a `Result<Success, Failure>` value or a `Success` value with `Failure` error. For example:

```swift
let publisher = AF.request(...).publishDecodable(type: DecodableType.self)
let resultPublisher = publisher.result() // Provides an AnyPublisher<Result<DecodableType, AFError>, Never>.
let valuePublisher = publisher.value() // Provides an AnyPublisher<DecodableType, AFError>.
```

As with any `Publisher`, `DataResponsePublisher` can be used with various Combine APIs, allow Alamofire to support easy simultaneous requests for the first time.

```swift
// All usage of cancellable Combine API must have its token stored to maintain the subscription.
var tokens: Set<AnyCancellable> = []

...

let first = AF.request(...).publishDecodable(type: First.self)
let second = AF.request(...).publishDecodable(type: Second.self)
let both = Publishers.CombineLatest(first, second)
both.sink { first, second in // DataResponse<First, AFError>, DataResponse<Second, AFError>
    debugPrint(first)
    debugPrint(second)
}
.store(in: &tokens)
```

Sequential requests are also possible:

```swift
// All usage of cancellable Combine API must have its token stored to maintain the subscription.
var tokens: Set<AnyCancellable> = []

...

AF.request(...)
    .publishDecodable(type: First.self)
    .value()
    .flatMap {
        AF.request(...) // Use First value to create second request.
            .publishDecodable(type: Second.self)
    }
    .sink { second in // DataResponse<Second, AFError>
        debugPrint(second)
    }
    .store(in: &tokens)
```

Once subscribed, this chain of transformations will make the first request and then create a publisher for a second, finishing when the second request has finished.

> As with all Combine usage, care must be taken to ensure that subscriptions are not cancelled early by maintaining the lifetime of the `AnyCancellable` tokens returned by functions like `sink`. If a request is cancelled prematurely, the response's error will be set to `AFError.explicitlyCancelled`.

#### `DownloadResponsePublisher`

Alamofire also offers a `Publisher` for `DownloadRequest`s, `DownloadResponsePublisher`. Its behavior and capabilities are the same as `DataResponsePublisher`.

Like most `DownloadRequest`'s response handlers, `DownloadResponsePublisher` reads `Data` from disk to perform serialization, which can impact system performance if reading a large amount of `Data`. It's recommended you use `publishUnserialized()` to receive just the `URL?` that the file was downloaded to and perform your own read from disk for large files.

#### `DataStreamPublisher`

`DataStreamPublisher` is a `Publisher` for `DataStreamRequest`s. Like `DataStreamRequest` itself, and unlike Alamofire's other `Publisher`s, `DataStreamPublisher` can return multiple values serialized from `Data` received from the network, as well as a final completion event. For more information on how `DataStreamRequest` works, please see our [detailed usage documentation](https://github.com/Alamofire/Alamofire/blob/master/Documentation/Usage.md#streaming-data-from-a-server).

## Using Alamofire with Swift Concurrency

Swift's concurrency features, released in Swift 5.5, provide fundamental asynchronous building blocks in the language, including `async`-`await` syntax, `Task`s, and actors. Alamofire provides extensions allowing the use of common Alamofire APIs with Swift's concurrency features.

> Alamofire's concurrency support requires Swift 5.6.0 or Xcode 13.3.1 due to bugs with older Swift 5.5 compilers and Xcode versions. These examples also include the use of static protocol values added in Alamofire 5.5 for Swift 5.5.

### `DataRequest` and `UploadRequest` Support

Alamofire's concurrency support works by vending various `*Task` types, like `DataTask`, `DownloadTask`, and `DataStreamTask`. These types work similarly to Alamofire's existing response handlers and convert the standard completion handlers into `async` properties which can be `await`ed. For example, `DataRequest` (and `UploadRequest`, which inherits from `DataRequest`) can provide a `DataTask` used to `await` any of the asynchronous values:

```swift
let value = try await AF.request(...).serializingDecodable(TestResponse.self).value
```

This code synchronously produces a `DataTask<TestResponse>` value which can be used to `await` any part of the resulting `DataResponse<TestResponse, AFError>`. Each `DataTask` can be used to `await` any of these properties as many times as needed. For example:

```swift
let dataTask = AF.request(...).serializingDecodable(TestResponse.self)
// Later...
let response = await dataTask.response // Returns full DataResponse<TestResponse, AFError>
// Elsewhere...
let result = await dataTask.result // Returns Result<TestResponse, AFError>
// And...
let value = try await dataTask.value // Returns the TestResponse or throws the AFError as an Error
```

Similarly, and like Alamofire's existing closure and publisher-based response handlers, each request can produce multiple tasks that perform the same or different serializations.

```swift
let request = AF.request(...)
// Later...
let stringResponse = await request.serializingString().response
// Elsewhere...
let decodableResponse = await request.serializingDecodable(TestResponse.self).response
```

Finally, like all Swift Concurrency APIs, these `await`able properties can be used to `await` multiple requests issued in parallel. For example:

```swift
async let first = AF.request(...).serializingDecodable(TestResponse.self).response
async let second = AF.request(...).serializingString().response
async let third = AF.request(...).serializingData().response

// Later...

// Produces (DataResponse<TestResponse, AFError>, DataResponse<String, AFError>,  DataResponse<Data, AFError>)
// when all requests are complete.
let responses = await (first, second, third)
```

Alamofire's concurrency APIs can also be used with other builtin concurrency constructs like `Task` and `TaskGroup`.

### `DownloadRequest` Support

Like `DataRequest`, `DownloadRequest` vends its own `DownloadTask` value which can be used to `await` the completion of the request. Like the existing response handlers, the `DownloadTask` will read the downloaded `Data` from disk, so if the `Data` is very large it's best to simply get the `URL` and read the `Data` in a way that won't read it all into memory at once.

```swift
let url = try await AF.download(...).serializingURL().value
```

### Automatic Cancellation

By default, `DataTask` and `DownloadTask` values do not cancel the underlying request when an enclosing concurrent context is cancelled. This means that request will complete even if the enclosing context is explicitly cancelled. For example:

```swift
let request = AF.request(...) // Creates the DataRequest.
let task = Task { // Produces a `Task<DataResponse<TestResponse, AFError>, Never> value.
    await request.serializingDecodable(TestResponse.self).response
}

// Later...

task.cancel() // task is cancelled, but the DataRequest created inside it is not.
print(task.isCancelled) // true
print(request.isCancelled) // false
```

If automatic cancellation is desired, it can be configured when creating the `DataTask` or `DownloadTask`. For example:

```swift
let request = AF.request(...) // Creates the DataRequest.
let task = Task { // Produces a `Task<DataResponse<TestResponse, AFError>, Never> value.
    await request.serializingDecodable(TestResponse.self, automaticallyCancelling: true).response
}

// Later...

task.cancel() // task is cancelled.
print(task.isCancelled) // true
print(request.isCancelled) // true
```

This automatic cancellation only takes affect when one of the asynchronous properties is `await`ed.

### `DataStreamRequest` Support

`DataStreamRequest`, unlike the other request types, does not read a single value and complete. Instead, it continuously streams `Data` from the server to be processed through a handler. With Swift Concurrency, this callback API has been replaced with `StreamOf` values vended by `DataStreamTask`. `StreamOf` conforms to `AsyncSequence`, allowing the use of `for await` syntax to observe values as they're received by the stream. Unlike `DataTask` and `DownloadTask`, `DataStreamTask` doesn't vend asynchronous properties itself. Instead, it vends the streams that can be observed.

```swift
let streamTask = AF.dataStreamRequest(...).streamTask()

// Later...

for await data in streamTask.streamingData() {
    // Streams Stream<Data, Never> values. a.k.a StreamOf<DataStreamRequest.Stream<Data, Never>>
}
```

This loop only ends when the `DataStreamRequest` completes, either through the server closing the connection or the `DataStreamRequest` being cancelled. If the loop is ended early by `break`ing out of it, the `DataStreamRequest` is canceled and no further values can be received. If the use of multiple observers without automatically cancellation is desired, you can pass `false` for the `automaticallyCancelling` parameter.

```swift
let streamTask = AF.dataStreamRequest(...).streamTask()

// Later...

for await data in streamTask.streamingData(automaticallyCancelling: false) {
    // Streams Stream<Data, Never> values. a.k.a StreamOf<DataStreamRequest.Stream<Data, Never>>
    if condition { break } // Stream ends but underlying `DataStreamRequest` is not cancelled and keeps receiving data.
}
```

One observer setting `automaticallyCancelling` to `false` does not affect other from the same `DataStreamRequest`, so if any other observer exits the request will still be cancelled.

### Value Stream Handlers

Alamofire provides various handlers for internal values which are produced asynchronously, such as `Progress` values, `URLRequest`s and `URLSessionTask`s, as well as cURL descriptions of the request each time a new request is issued. Alamofire's concurrency support now exposes these handlers as `StreamOf` values that can be used to asynchronously observe the received values. For instance, if you wanted to print each cURL description produced by a request:

```swift
let request = AF.request(...)

// Later...

for await description in request.cURLDescriptions() {
    print(description)
}
```

## Network Reachability

The `NetworkReachabilityManager` listens for changes in the reachability of hosts and addresses for both Cellular and WiFi network interfaces.

```swift
let manager = NetworkReachabilityManager(host: "www.apple.com")

manager?.startListening { status in
    print("Network Status Changed: \(status)")
}
```

> Make sure to remember to retain the `manager` in the above example, or no status changes will be reported.
> Also, do not include the scheme in the `host` string or reachability won't function correctly.

There are some important things to remember when using network reachability to determine what to do next.

- **DO NOT** use Reachability to determine if a network request should be sent.
  - You should **ALWAYS** send it.
- When reachability is restored, use the event to retry failed network requests.
  - Even though the network requests may still fail, this is a good moment to retry them.
- The network reachability status can be useful for determining why a network request may have failed.
  - If a network request fails, it is more useful to tell the user that the network request failed due to being offline rather than a more technical error, such as "request timed out."

Alternatively, using a `RequestRetrier`, like the built in `RetryPolicy`, instead of reachability updates to retry requests which failed to a network failure will likely be simpler and more reliable. By default, `RetryPolicy` will retry idempotent requests on a variety of error conditions, including an offline network connection.
