# Alamofire 5.0 Migration Guide
Alamofire 5.0 is the latest major release of Alamofire, an HTTP networking library for iOS, tvOS, macOS and watchOS written in Swift. As a major release, following Semantic Versioning conventions, 5.0 introduces API-breaking changes.

This guide is provided in order to ease the transition of existing applications using Alamofire 4.x to the latest APIs, as well as explain the design and structure of new and updated functionality. Due to the extensive nature of the changes in Alamofire 5, this guide does not provide a complete overview of all changes. Instead, the largest changes are summarized and users encouraged to read Alamofire’s extensive API, Usage, and Advanced Usage documentation.

## Benefits of Upgrading
- **Rewritten Core:** Alamofire’s core architecture has been rewritten to follow a variety of best practices.
	- `DispatchQueue` usage has been updated to follow Apple’s recommended best practices. This means Alamofire will scale much better when many requests are in flight at the same time cannot lead to queue exhaustion like previous versions could. This should improve overall performance and lower the impact of Alamofire on the app and system.
	- Areas of responsibility have been clarified among internal APIs, making it easier to implement certain features, like the new `EventMonitor` protocol and per-request SSL failure errors, among many others.
	- It was written with the benefit of the various sanitizers, especially the thread sanitizer, from the very beginning, so there will be far fewer threading and other runtime issues than seen in previous versions.
- **Decodable Responses:** `responseDecodable` and the `DecodableResponseSerializer` now provide built-in support for parsing `Decodable` types from network responses using any `DataDecoder` type.
- **Encodable Parameters:** Alamofire now supports and prefers `Encodable` types as parameters using the `ParameterEncoder` protocol, allowing fully type-safe representation of request parameters.
- **URLEncodedFormEncoder:** In addition to supporting `Encodable` parameters in general, Alamofire now includes the `URLEncodedFormEncoder`, an `Encoder` for URL form encoding. 
- **`EventMonitor` Protocol:** `EventMonitor`s allow access to Alamofire’s internal events, making it far easier to observe specific actions through a request’s lifetime. This makes logging requests very easy.
- **Async `RequestAdapter`s:** The `RequestAdapter` protocol now operates asynchronously, making it possible to add async resources to requests.
- **Per-`Request` `RequestInterceptor`s:** `RequestInterceptor`s can now be added to individual `Request`s, allowing fine-grained control for the first time.
- **`CachedResponseHandler` and `RedirectHandler` Protocols:** Easy access and control over response caching and redirect behaviors, on both a `Session` and `Request` basis.
- **`HTTPHeaders` Type:** Type safe access to common HTTP headers, with extensions to `URLRequest`, `HTTPURLResponse`, and `URLSessionConfiguration` to allow setting the headers of those types using Alamofire’s new type.
- **`RetryPolicy`:** A `RequestRetrier` with automatic support for retrying requests which failed due to a network or other system error, with customizable exponential backoff, retry limits, and other parameters.

## Breaking API Changes
Most APIs have changed in Alamofire 5, so this list is not complete. While most top level `request` APIs remain the same, nearly every other type has changed in some way. For up to date examples, see our Usage and Advanced Usage documentation.

- `SessionManager` has been renamed to `Session` and its APIs have completely changed.
- Background `URLSessionConfiguration`s are no longer supported and attempting to use one will result in a fatal runtime error. Alamofire was never designed to work in the background and its closure-based APIs cannot survive a background transition, leading to ongoing issues around background behavior. Explicit background support will be added through dedicated APIs at some point in the future.
- `SessionDelegate` has been rebuilt and it’s public API completely changed. The various closure overrides have been removed, with most now able to be replaced with specific Alamofire features. If there is a need for control over something the closures used to provide, feel free to open a feature request.
- `TaskDelegate` and the various `*TaskDelegate` classes have been removed. All `URLSession*Delegate` handling is now performed by `SessionDelegate`.
- `Result` has been removed. Alamofire now uses Swift’s `Result` type.
- Global `Alamofire` namespace usage, which was never really necessary, has been removed and replaced with a single `AF` reference to `Session.default`.
- `ServerTrustPolicyManager` has been renamed `ServerTrustManager` and now requires every evaluated request to match one of the provided hosts. This can be disabled by initializing an instance with `allHostsMustBeEvaluted: false`.
- `ServerTrustPolicy` has be separated into a protocol, `ServerTrustEvaluating`, and several conforming types. Each case of `ServerTrustPolicy` now has equivalent types:
  - `.performDefaultEvaluation` is replaced by `DefaultTrustEvaluator`.
  - `.performRevokedEvaluation` is replaced by `RevocationTrustEvaluator`.
  - `.pinCertificates` is replaced by `PinnedCertificatesTrustEvaluator`.
  - `.pinPublicKeys` is replaced by `PublicKeysTrustEvaluator`.
  - `.disableEvaluation` is replaced by `DisabledTrustEvaluator`.
  - `.customEvaluation` is replaced by either using `CompositeTrustEvalutor` to combine existing `ServerTrustEvaluating` types or by creating a new type that conforms to `ServerTrustEvaluating`.
- `DataResponse` and `DownloadResponse` are now both doubly generic to both the response type as well as the error type. By default all Alamofire APIs return a `AF` prefixed response type, which defaults the `Error` type to `AFError`.
- Alamofire now returns `AFError` for all of its APIs, wrapping any underlying system or custom APIs in `AFError` instances.
- `HTTPMethod` is now a `struct` and not an `enum` and can be expanded to provide custom methods.
- `HTTPHeaders` and other types are now native Swift types rather than `typealias`es, so care must be taken when passing them to Obj-C bridged collections.
- `AFError` now has several new cases, so switching over it exhaustively will have to be updated.
- `Notification`s provided by Alamofire have had their keys renamed. You can now subscribe to:
  - `Request.didResumeNotification` and `Request.didResumeTaskNotification` to be notified when `Request`s and their `URLSessionTask`s have `resume()` called.
  - `Request.didSuspendNotification` and `Request.didSuspendTaskNotification` to be notified when `Request`s and their `URLSessionTask`s have `suspend()` called.
  - `Request.didCancelNotification` and `Request.didCancelTaskNotification` to be notified when `Request`s and their `URLSessionTask`s have `cancel()` called.
  - `Request.didFinishNotification` and `Request.didCompleteTaskNotification` to be notified when `Request`s have `finish()` called and when `URLSessionTask`s trigger the `didComplete` delegate method.
- `MultipartFormData`’s API has changed and the top level `upload` methods to create and upload `MultipartFormData` have been updated to match other request APIs, so it’s not longer necessary to deal with the `Result` of the multipart encoding.
- `NetworkReachabilityManager` has been refactored for greater reliability and simplicity. Instead of setting an update closure and then starting the listener, the closure is provided to the `startListening` method.
- `Request` and its various subclasses have been rewritten and the public API completely changed. Please see the documentation for an exhaustive list of the current functionality.
- `Timeline` and Alamofire’s previous `URLSessionTaskMetrics` handling have been replaced with native support for `URLSessionTaskMetrics`, which nows provides all timing information for Alamofire’s requests.
- cURL representations of `Request`s have been removed from the `debugDescription`, which is now useful for debug output, to a `cURLDescription` method which provides completion handler based access to the cURL command.
- `DefaultDataResponse` and `DefaultDownloadResponse` have been removed. All `response` methods now return the normal `DataResponse` or `DownloadResponse` types.
- Requirements for the `DataResponseSerializerProtocol` and `DownloadResponseSerializer` protocol have been changed from a property, `serializeResponse`, to a function, `serializeResponse`. This function can return a serialized value or throw an error, no longer requiring a `Result` return value. The new `ResponseSerializer` protocol combines the two previous protocols to simplify implementation.
- `RequestAdapter` has been updated to have an asynchronous requirement, allowing for access to async resources during request adaptation.

## New Features
- Alamofire now vends its extensions of Swift and Foundation types through an `af` namespace.
- Serializers updated with more configuration options, including allowed empty response methods and codes, as well as the `DataPreprocessor` protocol, to prepare the received `Data` for serialization.
- **`RetryPolicy`:** A `RequestRetrier` to retry requests which failed due to system errors, such as network connectivity. Configurable with custom debounce settings and defaults to an extensive set of errors to make your requests more reliable.
- **`CachedResponseHandler `:** New protocol that provides control over whether a response is cached or not. The `ResponseCacher` type is provided as an easy to use implementation of the protocol.
- **`RedirectHandler`:** New protocol that provides control over a request’s redirect behavior. The `Redirector` type is provided as an easy to use implementation of the protocol.
- **`ParameterEncoder`:** New protocol that provides support for encoding `Encodable` values into `URLRequest`s. `JSONParameterEncoder` and `URLEncodedFormParameterEncoder` are included with Alamofire.
- **`URLEncodedFormEncoder`:** An `Encoder` that produced `URLEncodedForm` strings.
