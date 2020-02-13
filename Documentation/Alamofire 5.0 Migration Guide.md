# Alamofire 5.0 Migration Guide
Alamofire 5.0 is the latest major release of Alamofire, an HTTP networking library for iOS, tvOS, macOS and watchOS written in Swift. As a major release, following Semantic Versioning conventions, 5.0 introduces API-breaking changes.

This guide is provided in order to ease the transition of existing applications using Alamofire 4.x to the latest APIs, as well as explain the design and structure of new and updated functionality. Due to the extensive nature of the changes in Alamofire 5, this guide provide a complete overview of all changes. Instead, the largest changes will be summarized and users encouraged to read Alamofire’s extensive API, Usage, and Advanced Usage documentation.

## Benefits of Upgrading
- **Rewritten Core:** Alamofire’s core architecture has been rewritten to follow a variety of best practices.
	- `DispatchQueue` usage has been updated to follow Apple’s recommended best practices. This means Alamofire will scale much better when many requests are in flight at the same time and cannot lead to queue exhaustion like previous versions could. This should improve overall performance and lower the impact of Alamofire on the app and system.
	- Areas of responsibility have been clarified among internal APIs, making it easier to implement certain features, like the new `EventMonitor` protocol and per-request SSL failure errors, among many others.
	- It was written with the benefit of the various sanitizers, especially the thread sanitizer from the very beginning, so there will be far fewer threading and other runtime issues than seen in previous versions.
- **Decodable Responses:** `responseDecodable` and the `DecodableResponseSerializer` now provide built-in support for parsing `Decodable` types from network responses using any `DataDecoder` type.
- **Encodable Parameters:** Alamofire now supports and prefers `Encodable` types as parameters, allowing fully type-safe representation of request parameters.
- **URLEncodedFormEncoder:** In addition to supporting `Encodable` parameters in general, Alamofire now includes the `URLFormEncoder`, an `Encoder` for URL form encoding. 
- **`EventMonitor` Protocol:** `EventMonitor`s allow access to Alamofire’s internal events, making it far easier to observe specific actions through a request’s lifetime. This makes logging requests very easy.
- **Async `RequestAdapter`s:** The `RequestAdatper` protocol now operates asynchronously, making it possible to add async resources to requests.
- **Per-`Request` `RequestInterceptor`s:** `RequestInterceptor`s can now be added to individual `Request`s, allowing fine-grained control for the first time.
- 

## Breaking API Changes
Most APIs have changed in Alamofire 5, so this list is not complete. While most top level `request` APIs remain the same, nearly every other type has changed in some way. 

- `SessionManager` has been renamed to `Session` and its APIs have completely changed.
- `SessionDelegate` has been rebuilt and it’s public API completely changed. The various closure overrides have been removed, with most now able to be replaced with specific Alamofire features. If there is a need for control over something the closures used to provide, feel free to open a feature request.
- `TaskDelegate` and the various `*TaskDelegate` classes have been removed. All `URLSession*Delegate` handling is now performed by `SessionDelegate`.
- `Result` has been removed. Alamofire now uses Swift’s `Result` type.
- Global `Alamofire` namespace usage, which was never really necessary, has been removed and replaced with a single `AF` reference to `Session.default`.

## New Features
- Serializers updated with more configuration options, including allowed empty response methods and codes, as well as the `DataPreprocessor` protocol, to prepare the received `Data` for serialization. 
- **`RetryPolicy`:** A `RequestRetrier` to retry requests which failed due to system errors, such as network connectivity. Configurable with custom debounce settings and defaults to an extensive set of errors to make your requests more reliable.
- **`CacheHandler`:** New protocol that provides control over whether a response is cached or not. The `Cacher` type is provided as an easy to use implementation of the protocol.
- **`RedirectHandler`:** New protocol that provides control over a request’s redirect behavior. The `Redirector` type is provided as an easy to use implementation of the protocol.

## Updated Features
