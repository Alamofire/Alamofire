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
let session = Session.af.default
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
To customize the behavior of the underlying `URLSesion`, a customized `URLSessionConfiguration` instance can be provided. Starting from the `URLSession.af.default` instance is recommended, as it adds the default `Accept-Encoding`, `Accept-Language`, and `User-Agent` headers provided by Alamofire, but any `URLSessionConfiguration` can be used.

```swift
let configuration = URLSessionConfiguration.af.default
configuration.allowsCellularAccess = false

let session = Session(configuration: configuration)
```

> `URLSessionConfiguration` is **not** the recommended location to set `Authorization` or `Content-Type` headers. Instead, add them to `Request`s using the provided `headers` APIs, using `ParameterEncoder`s, or a `RequestAdapter`.

> As Apple states in their [documentation](https://developer.apple.com/documentation/foundation/urlsessionconfiguration), mutating `URLSessionConfiguration` properties after the instance has been added to a `URLSession` (or, in Alamofire’s case, used to initialize a`Session`) has no effect.

### `SessionDelegate`
A `SessionDelegate` instance encapsulates all handling of the various `URLSessionDelegate` and related protocols callbacks. `SessionDelegate` also acts as the `SessionStateDelegate` for every `Request` produced by Alamofire, allow the `Request` to indirectly important state from the `Session` instance that produced them. `SessionDelegate` can be customized with a specific `FileManager` instance, which will be used for any disk access, like accessing file’s to be uploaded by `UploadRequest`s or files downloaded by `DownloadRequest`s.

```swift
let delelgate = SessionDelegate(fileManager: .default)
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
Alamofire’s `RequestInterceptor` protocol (`RequestAdapter & RequestRetrier`) provides important and powerful request adaptation and retry features. It can be applied at both the `Session` and `Request` level. For more details on `RequestInterceptor` and the various implementations Alamofire includes, like `RetryPolicy`, see [below](#requestinterceptor).

```swift
let policy = RetryPolicy()
let session = Session(interceptor: policy) 
```

### Adding a `ServerTrustManager`
Alamofire’s `ServerTrustManager` class encapsulates mappings between domains and instances of `ServerTrustEvaluating`-conforming types, which provide the ability to customize a `Session`’s handling of TLS security. This includes the use of certificate and public key pinning as well as certificate revocation checking. For more information, see the section about the `ServerTrustManager` and `ServerTrustEvaluating`. Initializing a `ServerTrustManger` is as simple as providing a mapping between the domain and the type of evaluation to be performed:

```swift
let manager = ServerTrustManager(evaluators: ["httpbin.org": PinnedCertificatesTrustEvaluator()])
let session = Session(serverTrustManager: manager)
```

### Adding a `RedirectHandler`
Alamofire’s `RedirectHandler` protocol customizes the handling of HTTP redirect responses. It can be applied at both the `Session` and `Request` level. Alamofire includes the `Redirector` type which conforms to `RedirectHandler` and offers simple control over redirects. For more details on `RedirectHandler`, see the detailed documentation below. 

```swift
let redirector = Redirector(behavior: .follow)
let session = Session(redirectHandler: redirector)
```

### Adding a `CachedResponseHandler`
Alamofire’s `CachedResponseHandler` protocol customizes the caching of responses and can be applied at both the `Session` and `Request` level. Alamofire includes the `ResponseCacher` type which conforms to `CachedResponseHandler` and offers simple control over response caching. For more details, see the detailed documentation below. Link.

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

### Creating Instances From `URLSession`s
In addition to the `convenience` initializer mentioned previously, `Session`s can be initialized directly from `URLSession`s. However, there are several requirements to keep in mind when using this initializer, so using the convenience initializer is recommended. These include:
* Alamofire does not support `URLSession`s configured for background use. This will lead to a runtime error when the `Session` is initialized.
* A `SessionDelegate` instance must be created and used as the `URLSession`’s `delegate`, as well as passed to the `Session` initializer.
* A custom `OperationQueue` must be passed as the `URLSession`’s `delegateQueue`. This queue must be a serial queue, it must have a backing `DispatchQueue`, and that `DispatchQueue` must be passed to the `Session` as its `rootQueue`.

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
Once a `Request` subclass has been created with it’s initial parameters or `URLRequestConvertible` value, it is pass through the series of steps making up Alamofire’s request pipeline. For a successful request, these include:

1. Initial parameters, like HTTP method, headers, and parameters, are encapsulated into an internal `URLRequestConvertible` value. If a `URLRequestConvertible` value is passed directly, that value is used unchanged.
2. `asURLRequest()` is called on the the `URLRequestConvertible` value, creating the first `URLRequest` value. This value is passed to the `Request` and stored in `requests`.
3. If there are any `Session` or `Request` `RequestAdapter`s or `RequestInterceptor`s, they’re called using the previously created `URLRequest`. The adapted `URLRequest` is then passed to the `Request` and stored in `request`s as well.
4. `Session` calls the `Request` to create the `URLSessionTask` to perform the network request based on the `URLRequest`.
5. Once the `URLSessionTask` is complete and has gathered `URLSessionTaskMetrics`, the `Request` executes its `Validator`s. 
6. Request executes any response handlers, such as `responseDecodable`, that have been appended.

At any one of these steps, a failure can be indicated through a created or received `Error` value, which is then passed to the associated `Request`. For example, aside from steps 1 and 4, all of the steps above can create an `Error` which is then passed to the response handlers or available for retry.

1. Parameter encapsulation cannot fail.
2. Any `URLRequestConvertible` value can create an error when `asURLRequest()` is called. This allows for the initial validation of various `URLRequest` properties or the failure of parameter encoding.
3. `RequestAdapter`s can fail during adaptation, perhaps due to a missing authorization token.
4. `URLSessionTask` creation cannot fail.
5. `URLSessionTask`s can complete with errors for a variety of reasons, including network availability and cancellation. These `Error` values are passed back to the `Request`.
6. Response handlers can produce any `Error`, usually due to an invalid response or other parsing error.

Once an error is passed to the `Request`, the `Request` will attempt to run any `RequestRetrier`s associated with the `Sesion` or `Request`. If any `RequestRetrier`s choose to retry the `Request`, the complete pipeline is run again. `RequestRetrier`s can also produce `Error`s, which do not trigger retry.

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
In order to track the progress of a request, `Request` offers a both  `uploadProgress` and `downloadProgress` properties as well as closure-based `uploadProgress` and `downloadProgress` methods. Like all closure-based `Request` APIs, the progress APIs can be chained off of the `Request` with other methods. Also like the other closure-based APIs, they should be added to a request *before* calling any response handler, like `responseDecodable`.

```swift
AF.request(...)
    .uploadProgress { progress in
        print(progress)
    }
    .downloadProgress { progress in
        print(progress)
    }
    .responseDecodable(of: SomeType.self) { response in
        debugPrint(response)
    }
```
 
Importantly, not all `Request` subclasses are able to report their progress accurately, or may have other dependencies to do so.
- For upload progress, progress can be determined in the following ways:
	- By the length of the `Data` object provided as the upload body to an `UploadRequest`.
	- By the length of a file on disk provided as the upload body of an `UploadRequest`.
	- By the value of the `Content-Length` header on the request, if it has been manually set.
- For download progress, there is a single requirement:
	- The server response must contain a `Content-Length` header.
Unfortunately there may be other, undocumented requirements for progress reporting from `URLSession` which prevents accurate progress reporting.

#### Handling Redirects
Alamofire’s `RedirectHandler` protocol provides control and customization of redirect handling for `Request`. In addition to per-`Session` `RedirectHandler`s, each `Request` can be given its own `RedirectHandler` which overrides any provided by the `Session`. 

```swift
let redirector = Redirector(behavior: .follow)
AF.request(...)
    .redirect(using: redirector)
    .responseDecodable(of: SomeType.self) { response in 
        debugPrint(response)
    }
```

> Note: Only one `RedirectHandler` can be set on a `Request`. Attempting to set more than one will result in a runtime exception.

#### Customizing Caching
Alamofire’s `CachedResponseHandler` protocol provides control and customization over the caching of responses. In addition to per-`Session` `CachedResponseHandler`s, each `Request` can be given its own `CachedResponseHandler` which overrides any provided by the `Session`.

```swift
let cacher = Cacher(behavior: .cache)
AF.request(...)
    .cacheResponse(using: cacher)
    .responseDecodable(of: SomeType.self) { response in 
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
    .responseDecodable(of: SomeType.self) { response in 
        debugPrint(response)
    }
```
> Note: This mechanism only supports HTTP authentication prompts. If a request requires an `Authentication` header for all requests, it should be provided directly, either as part of the `Request`, or through a `RequestInterceptor`.

Additionally, adding a raw `URLCredential` is just as easy:
```swift
let credential = URLCredential(...)
AF.request(...)
    .authenticate(using: credential)
    .responseDecodable(of: SomeType.self) { response in 
        debugPrint(response)
    }
```

#### A `Request`’s `URLRequest`s
Each network request issued by a `Request` is ultimately encapsulated in a `URLRequest` value created from the various parameters passed to one of the `Session` request methods. `Request` will keep a copy of these `URLRequest`s in its `requests` array property. These values include both the initial `URLRequest` created from the passed parameters, as well any `URLRequest`s created by `RequestInterceptor`s. That array does not, however, include the `URLRequest`s performed by the `URLSessionTask`s issued on behalf of the `Request`. To inspect those values, the `tasks` property gives access to all of the `URLSessionTasks` performed by the `Request`.

#### `URLSessionTask`s
In many ways the various `Request` subclasses act as a wrapper for a `URLSessionTask`, presenting particular API for interacting with particular types of tasks. These tasks are made visible on the `Request` instance through the `tasks` array property. This includes both the initial task created for the `Request`, as well as any subsequent tasks created as part of the retry process, with one task per retry.

#### Response
Each `Request` may have an `HTTPURLResponse` value available once the request is complete. This value is only available if the request wasn’t cancelled and didn’t fail to make the network request. Additionally, if the request is retried, only the *last* response is available. Intermediate responses can be derived from the `URLSessionTask`s in the `tasks` property.

#### `URLSessionTaskMetrics`
Alamofire gathers `URLSessionTaskMetrics` values for every `URLSessionTask` performed for a `Request`. These values are available in the `metrics` property, with each value corresponding to the `URLSessionTask` in `tasks` at the same index.

`URLSessionTaskMetrics` are also made available on Alamofire’s various response types, like `DataResponse`. For instance:
```swift
AF.request(...)
    .responseDecodable(of: SomeType.self) { response in {
        print(response.metrics)
    }
```

### `DataRequest`
`DataRequest` is a concrete subclass of `Request` which encapsulates a `URLSessionDataTask` downloading a server response into `Data` stored in memory. Therefore, it’s important to realize that extremely large downloads may adversely affect system performance. For those types of downloads, using `DownloadRequest` to save the data to disk is recommended.

#### Additional State
`DataRequest`s have a few properties in addition to those provided by `Request`. These include `data`, which is the accumulated `Data` from the server response, and `convertible`, which is the `URLRequestConvertible` the `DataRequest` was created with, containing the original parameters creating the instance.

#### Validation
`DataRequest`s do not validate responses by default. Instead, a call to `validate()` must be added to the in order to verify various properties are valid. 

```swift
public typealias Validation = (URLRequest?, HTTPURLResponse, Data?) -> Result<Void, Error>
```

By default, adding `validate()` ensures the response status code is within the `200..<300` range and that the response’s `Content-Type` matches the request `Accept` value. Validation can be further customized by passing a `Validation` closure:

```swift
AF.request(...)
    .validate { request, response, data in
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
Alamofire’s `RequestInterceptor` protocol (composed of the `RequestAdapter` and `RequestRetrier` protocol) enables powerful per-`Session` and per-`Request` capabilities, enabling a variety of features. These include authentication systems, where a common header is added to every `Request` and `Request`s are retried when authorization expires. Additionally, Alamofire includes a built in `RetryPolicy` type, which enables easy retry when requests fail due to a variety of common network errors.

### `RequestAdapter`
Alamofire’s  `RequestAdapter` protocol allows each `URLRequest` that’s to be performed by a `Session` to be inspected and adapted before being issued over the network. One very common use of an adapter is to add an `Authorization` header to requests behind a certain type of authentication.

The `RequestAdapter` protocol has a single requirement: 

```swift
func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void)
```

Its parameters include:
- `urlRequest`: The `URLRequest` initially created from the parameters or `URLRequestConvertible` value used to create the `Request`
- `session`: The `Session` which created the `Request` for which the adapter is being called.
- `completion`: The asynchronous completion handler that *must* be called to indicate the adapter is finished. It’s asynchronous nature enables `RequestAdapter`s to access asynchronous resources from the network or disk before the `Request` is sent over the network. The `Result` provided to the `completion` closure can either return a `.success` value with the modified `URLRequest` value, or a `.failure` value with an associated `Error` which will then be used to fail the `Request`.
For example, adding an `Authorization` header requires modifying the `URLRequest` and then calling the completion handler.

```swift
let accessToken: String

func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
    var urlRequest = urlRequest
    urlRequest.headers.add(.authorization(bearer: accessToken))

    completion(.success(urlRequest))
}
```

### `RequestRetrier`
Alamofire’s `RequestRetrier` protocol allows a `Request` that encountered an `Error` while being executed to be retried. This includes `Error`s produced at any stage of Alamofire’s [request pipeline](#the-request-pipeline).

`RequestRetrier` has a single requirement.

```swift
func retry(_ request: Request, for session: Session, dueTo error: Error, completion: @escaping (RetryResult) -> Void)
```

Its parameters include:
- `request`: The `Request` which is being retried.
- `session`: The `Session` which is managing the `Request` being retried.
- `error`: The `Error` which triggered the retry attempt. Usually an `AFError`.
- `completion`: The asynchronous completion handler that *must* be called to indicate the retry is finished. It must be called with a `RetryResult`.
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

## Security
Using a secure HTTPS connection when communicating with servers and web services is an important step in securing sensitive data. By default, Alamofire receives the same automatic TLS certificate and certificate chain validation as `URLSession`. While this guarantees the certificate chain is valid, it does not prevent man-in-the-middle (MITM) attacks or other potential vulnerabilities. In order to mitigate MITM attacks, applications dealing with sensitive customer data or financial information should use certificate or public key pinning provided by Alamofire’s `ServerTrustEvaluating` protocol.

### Evaluating Server Trusts with `ServerTrustManager` and `ServerTrustEvaluating`

#### `ServerTrustEvaluting`
The `ServerTrustEvaluting` protocol provides a way to perform any sort of server trust evaluation. It has a single requirement:

```swift
func evaluate(_ trust: SecTrust, forHost host: String) throws
```

This method provides the [`SecTrust`](https://developer.apple.com/documentation/security/certificate_key_and_trust_services/trust) value and host `String` received from the underlying `URLSession` and provides the opportunity to perform various evaluations.

Alamofire many different types of trust evolution, providing composable and complete control over the evaluation process:
* `DefaultTrustEvaluator`: Uses the default server trust evaluation while allowing you to control whether to validate the host provided by the challenge.
* `RevocationTrustEvaluator`: Checks the status of the received certificate to ensure it hasn’t been revoked. This isn’t performed on every request due to the network request overhead it entails.
* `PinnedCertificatesTrustEvaluator`: Uses the pinned certificates to validate the server trust. The server trust is considered valid if one of the pinned certificates match one of the server certificates. This evaluator can also accept self-signed certificates.
* `PublicKeysTrustEvaluator`: Uses the pinned public keys to validate the server trust. The server trust is considered valid if one of the pinned public keys match one of the server certificate public keys.
* `CompositeTrustEvaluator`: Evaluates an array of `ServerTrustEvaluating` values, only succeeding if all of them are successful. This type can be used to combine, for example, the `RevocationTrustEvaluator` and the `PinnedCertificatesTrustEvaluator`.
* `DisabledEvaluator`: This evaluator should only be used in debug scenarios as it disables all evaluation which in turn will always consider any server trust as valid. This evaluator should **never** be used in production environments!

#### `ServerTrustManager`
The `ServerTrustManager` is responsible for storing an internal mapping of `ServerTrustEvaluating` values to a particular host. This allows Alamofire to evaluate each host with different evaluators. 

```swift
let evaluators: [String: ServerTrustEvaluating] = [
    // By default, certificates included in the app bundle are pinned automatically.
    "cert.example.com": PinnedCertificatesTrustEvalutor(),
    // By default, public keys from certificates included in the app bundle are used automatically.
    "keys.example.com": PublicKeysTrustEvalutor(),
]

let manager = ServerTrustManager(evaluators: serverTrustPolicies)
```

This `ServerTrustManager` will have the following behaviors:
- `cert.example.com` will always use certificate pinning with default and host validation enabled , thus requiring the following criteria to be met in order to allow the TLS handshake to succeed:
	   - Certificate chain *must* be valid.
	- Certificate chain *must* include one of the pinned certificates.
	- Challenge host *must* match the host in the certificate chain's leaf certificate.
- `keys.example.com` will always use public key pinning with default and host validation enabled, thus requiring the following criteria to be met in order to allow the TLS handshake to succeed:
	- Certificate chain *must* be valid.
	- Leaf certificates *must* include one of the pinned public keys.
	- Challenge host *must* match the host in the certificate chain's leaf certificate.
- All other hosts will use the default evaluation provided by Apple.

##### Subclassing Server Trust Policy Manager
If you find yourself needing more flexible server trust policy matching behavior (i.e. wildcarded domains), then subclass the `ServerTrustManager` and override the `serverTrustEvaluator(forHost:)` method with your own custom implementation.

```swift
class CustomServerTrustPolicyManager: ServerTrustPolicyManager {
    override func serverTrustEvaluator(forHost:) -> ServerTrustEvaluating? {
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

According to [Apple documentation](https://developer.apple.com/library/content/documentation/General/Reference/InfoPlistKeyReference/Articles/CocoaKeys.html#//apple_ref/doc/uid/TP40009251-SW35), setting `NSAllowsLocalNetworking` to `YES` allows loading of local resources without disabling ATS for the rest of your app.

### Network Reachability
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
- **Do *NOT*** use Reachability to determine if a network request should be sent.
	- You should **ALWAYS** send it.
- When reachability is restored, use the event to retry failed network requests.
	- Even though the network requests may still fail, this is a good moment to retry them.
- The network reachability status can be useful for determining why a network request may have failed.
	- If a network request fails, it is more useful to tell the user that the network request failed due to being offline rather than a more technical error, such as "request timed out."

Alternatively, using a `RequestRetrier`, like the built in `RetryPolicy`, instead of reachability updates, to retry requests which failed to a network failure, will likely be simpler and more reliable. By default, `RetryPolicy` will retry idempotent requests on a variety of error conditions, include an offline network connection.

## Making Requests

### Routing Requests

As apps grow in size, it's important to adopt common patterns as you build out your network stack. An important part of that design is how to route your requests. The Alamofire `URLConvertible` and `URLRequestConvertible` protocols along with the `Router` design pattern are here to help.

#### URLConvertible

Types adopting the `URLConvertible` protocol can be used to construct URLs, which are then used to construct URL requests internally. `String`, `URL`, and `URLComponents` conform to `URLConvertible` by default, allowing any of them to be passed as `url` parameters to the `request`, `upload`, and `download` methods:

```swift
let urlString = "https://httpbin.org/post"
Alamofire.request(urlString, method: .post)

let url = URL(string: urlString)!
Alamofire.request(url, method: .post)

let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)!
Alamofire.request(urlComponents, method: .post)
```

Applications interacting with web applications in a significant manner are encouraged to have custom types conform to `URLConvertible` as a convenient way to map domain-specific models to server resources.

##### Type-Safe Routing

```swift
extension User: URLConvertible {
    static let baseURLString = "https://example.com"

    func asURL() throws -> URL {
    	let urlString = User.baseURLString + "/users/\(username)/"
        return try urlString.asURL()
    }
}
```

```swift
let user = User(username: "mattt")
Alamofire.request(user) // https://example.com/users/mattt
```

#### `URLRequestConvertible`
Types adopting the `URLRequestConvertible` protocol can be used to construct URL requests. `URLRequest` conforms to `URLRequestConvertible` by default, allowing it to be passed into `request`, `upload`, and `download` methods directly (this is the recommended way to specify custom HTTP body for individual requests):

```swift
let url = URL(string: "https://httpbin.org/post")!
var urlRequest = URLRequest(url: url)
urlRequest.httpMethod = "POST"

let parameters = ["foo": "bar"]

do {
    urlRequest.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: [])
} catch {
    // No-op
}

urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

Alamofire.request(urlRequest)
```

Applications interacting with web applications in a significant manner are encouraged to have custom types conform to `URLRequestConvertible` as a way to ensure consistency of requested endpoints. Such an approach can be used to abstract away server-side inconsistencies and provide type-safe routing, as well as manage authentication credentials and other state.

##### API Parameter Abstraction

```swift
enum Router: URLRequestConvertible {
    case search(query: String, page: Int)

    static let baseURLString = "https://example.com"
    static let perPage = 50

    // MARK: URLRequestConvertible

    func asURLRequest() throws -> URLRequest {
        let result: (path: String, parameters: Parameters) = {
            switch self {
            case let .search(query, page) where page > 0:
                return ("/search", ["q": query, "offset": Router.perPage * page])
            case let .search(query, _):
                return ("/search", ["q": query])
            }
        }()

        let url = try Router.baseURLString.asURL()
        let urlRequest = URLRequest(url: url.appendingPathComponent(result.path))

        return try URLEncoding.default.encode(urlRequest, with: result.parameters)
    }
}
```

```swift
Alamofire.request(Router.search(query: "foo bar", page: 1)) // https://example.com/search?q=foo%20bar&offset=50
```

##### CRUD & Authorization

```swift
import Alamofire

enum Router: URLRequestConvertible {
    case createUser(parameters: Parameters)
    case readUser(username: String)
    case updateUser(username: String, parameters: Parameters)
    case destroyUser(username: String)

    static let baseURLString = "https://example.com"

    var method: HTTPMethod {
        switch self {
        case .createUser:
            return .post
        case .readUser:
            return .get
        case .updateUser:
            return .put
        case .destroyUser:
            return .delete
        }
    }

    var path: String {
        switch self {
        case .createUser:
            return "/users"
        case .readUser(let username):
            return "/users/\(username)"
        case .updateUser(let username, _):
            return "/users/\(username)"
        case .destroyUser(let username):
            return "/users/\(username)"
        }
    }

    // MARK: URLRequestConvertible

    func asURLRequest() throws -> URLRequest {
    	let url = try Router.baseURLString.asURL()

        var urlRequest = URLRequest(url: url.appendingPathComponent(path))
        urlRequest.httpMethod = method.rawValue

        switch self {
        case .createUser(let parameters):
            urlRequest = try URLEncoding.default.encode(urlRequest, with: parameters)
        case .updateUser(_, let parameters):
            urlRequest = try URLEncoding.default.encode(urlRequest, with: parameters)
        default:
            break
        }

        return urlRequest
    }
}
```

```swift
Alamofire.request(Router.readUser("mattt")) // GET https://example.com/users/mattt
```

## Response Handling

### Response Transforms

### Custom Response Serializers

### Custom Response Serialization

Alamofire provides built-in response serialization for data, strings, JSON, and property lists:

```swift
Alamofire.request(...).responseData { (resp: DataResponse<Data>) in ... }
Alamofire.request(...).responseString { (resp: DataResponse<String>) in ... }
Alamofire.request(...).responseJSON { (resp: DataResponse<Any>) in ... }
Alamofire.request(...).responsePropertyList { (resp: DataResponse<Any>) in ... }
```

Those responses wrap deserialized *values* (Data, String, Any) or *errors* (network, validation errors), as well as *meta-data* (URL request, HTTP headers, status code, [metrics](#statistical-metrics), ...).

You have several ways to customize all of those response elements:

- [Response Mapping](#response-mapping)
- [Handling Errors](#handling-errors)
- [Creating a Custom Response Serializer](#creating-a-custom-response-serializer)
- [Generic Response Object Serialization](#generic-response-object-serialization)

#### Response Mapping

Response mapping is the simplest way to produce customized responses. It transforms the value of a response, while preserving eventual errors and meta-data. For example, you can turn a json response `DataResponse<Any>` into a response that holds an application model, such as `DataResponse<User>`. You perform response mapping with the `DataResponse.map` method:

```swift
Alamofire.request("https://example.com/users/mattt").responseJSON { (response: DataResponse<Any>) in
    let userResponse = response.map { json in
        // We assume an existing User(json: Any) initializer
        return User(json: json)
    }

    // Process userResponse, of type DataResponse<User>:
    if let user = userResponse.value {
        print("User: { username: \(user.username), name: \(user.name) }")
    }
}
```

When the transformation may throw an error, use `flatMap` instead:

```swift
Alamofire.request("https://example.com/users/mattt").responseJSON { response in
    let userResponse = response.flatMap { json in
        try User(json: json)
    }
}
```

Response mapping is a good fit for your custom completion handlers:

```swift
@discardableResult
func loadUser(completionHandler: @escaping (DataResponse<User>) -> Void) -> Alamofire.DataRequest {
    return Alamofire.request("https://example.com/users/mattt").responseJSON { response in
        let userResponse = response.flatMap { json in
            try User(json: json)
        }

        completionHandler(userResponse)
    }
}

loadUser { response in
    if let user = response.value {
        print("User: { username: \(user.username), name: \(user.name) }")
    }
}
```

When the map/flatMap closure may process a big amount of data, make sure you execute it outside of the main thread:

```swift
@discardableResult
func loadUser(completionHandler: @escaping (DataResponse<User>) -> Void) -> Alamofire.DataRequest {
    let utilityQueue = DispatchQueue.global(qos: .utility)

    return Alamofire.request("https://example.com/users/mattt").responseJSON(queue: utilityQueue) { response in
        let userResponse = response.flatMap { json in
            try User(json: json)
        }

        DispatchQueue.main.async {
            completionHandler(userResponse)
        }
    }
}
```

`map` and `flatMap` are also available for [download responses](#downloading-data-to-a-file).

#### Handling Errors

Before implementing custom response serializers or object serialization methods, it's important to consider how to handle any errors that may occur. There are two basic options: passing existing errors along unmodified, to be dealt with at response time; or, wrapping all errors in an `Error` type specific to your app.

For example, here's a simple `BackendError` enum which will be used in later examples:

```swift
enum BackendError: Error {
    case network(error: Error) // Capture any underlying Error from the URLSession API
    case dataSerialization(error: Error)
    case jsonSerialization(error: Error)
    case xmlSerialization(error: Error)
    case objectSerialization(reason: String)
}
```

#### Creating a Custom Response Serializer

Alamofire provides built-in response serialization for strings, JSON, and property lists, but others can be added in extensions on `Alamofire.DataRequest` and / or `Alamofire.DownloadRequest`.

For example, here's how a response handler using [Ono](https://github.com/mattt/Ono) might be implemented:

```swift
extension DataRequest {
    static func xmlResponseSerializer() -> DataResponseSerializer<ONOXMLDocument> {
        return DataResponseSerializer { request, response, data, error in
            // Pass through any underlying URLSession error to the .network case.
            guard error == nil else { return .failure(BackendError.network(error: error!)) }

            // Use Alamofire's existing data serializer to extract the data, passing the error as nil, as it has
            // already been handled.
            let result = Request.serializeResponseData(response: response, data: data, error: nil)

            guard case let .success(validData) = result else {
                return .failure(BackendError.dataSerialization(error: result.error! as! AFError))
            }

            do {
                let xml = try ONOXMLDocument(data: validData)
                return .success(xml)
            } catch {
                return .failure(BackendError.xmlSerialization(error: error))
            }
        }
    }

    @discardableResult
    func responseXMLDocument(
        queue: DispatchQueue? = nil,
        completionHandler: @escaping (DataResponse<ONOXMLDocument>) -> Void)
        -> Self
    {
        return response(
            queue: queue,
            responseSerializer: DataRequest.xmlResponseSerializer(),
            completionHandler: completionHandler
        )
    }
}
```