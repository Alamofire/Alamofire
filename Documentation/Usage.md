* [Introduction](#introduction)
    - [Aside: The `AF` Namespace](#aside-the-af-namespace-and-reference)
* [Making Requests](#making-requests)
  + [HTTP Methods](#http-methods)
  + [Request Parameters and Parameter Encoders](#request-parameters-and-parameter-encoders)
    - [`URLEncodedFormParameterEncoder`](#urlencodedformparameterencoder)
      * [GET Request With URL-Encoded Parameters](#get-request-with-url-encoded-parameters)
      * [POST Request With URL-Encoded Parameters](#post-request-with-url-encoded-parameters)
      * [Configuring the Sorting of Encoded Parameters](#configuring-the-sorting-of-encoded-parameters)
      * [Configuring the Encoding of `Array` Parameters](#configuring-the-encoding-of-array-parameters)
      * [Configuring the Encoding of `Bool` Parameters](#configuring-the-encoding-of-bool-parameters)
      * [Configuring the Encoding of `Data` Parameters](#configuring-the-encoding-of-data-parameters)
      * [Configuring the Encoding of `Date` Parameters](#configuring-the-encoding-of-date-parameters)
      * [Configuring the Encoding of Coding Keys](#configuring-the-encoding-of-coding-keys)
      * [Configuring the Encoding of Spaces](#configuring-the-encoding-of-spaces)
    - [`JSONParameterEncoder`](#jsonparameterencoder)
      * [POST Request with JSON-Encoded Parameters](#post-request-with-json-encoded-parameters)
      * [Configuring a Custom `JSONEncoder`](#configuring-a-custom-jsonencoder)
      * [Manual Parameter Encoding of a `URLRequest`](#manual-parameter-encoding-of-a-urlrequest)
  + [HTTP Headers](#http-headers)
  + [Response Validation](#response-validation)
    - [Automatic Validation](#automatic-validation)
    - [Manual Validation](#manual-validation)
  + [Response Handling](#response-handling)
    - [Response Handler](#response-handler)
    - [Response Data Handler](#response-data-handler)
    - [Response String Handler](#response-string-handler)
    - [Response `Decodable` Handler](#response-decodable-handler)
    - [Chained Response Handlers](#chained-response-handlers)
    - [Response Handler Queue](#response-handler-queue)
  + [Response Caching](#response-caching)
  + [Authentication](#authentication)
    - [HTTP Basic Authentication](#http-basic-authentication)
    - [Authentication with `URLCredential`](#authentication-with-urlcredential)
    - [Manual Authentication](#manual-authentication)
  + [Downloading Data to a File](#downloading-data-to-a-file)
    - [Download File Destination](#download-file-destination)
    - [Download Progress](#download-progress)
    - [Canceling and Resuming a Download](#canceling-and-resuming-a-download)
  + [Uploading Data to a Server](#uploading-data-to-a-server)
    - [Uploading Data](#uploading-data)
    - [Uploading a File](#uploading-a-file)
    - [Uploading Multipart Form Data](#uploading-multipart-form-data)
    - [Upload Progress](#upload-progress)
  + [Streaming Data from a Server](#streaming-data-from-a-server)
    - [Streaming `Data`](#streaming-data)
    - [Streaming `String`s](#streaming-strings)
    - [Streaming `Decodable` Values](#streaming-decodable-values)
    - [Producing an `InputStream`](#producing-an-inputstream)
  + [Statistical Metrics](#statistical-metrics)
    - [`URLSessionTaskMetrics`](#urlsessiontaskmetrics)
  + [cURL Command Output](#curl-command-output)

# Using Alamofire

## Introduction
Alamofire provides an elegant and composable interface to HTTP network requests. It does not implement its own HTTP networking functionality. Instead it builds on top of Apple's [URL Loading System](https://developer.apple.com/documentation/foundation/url_loading_system/) provided by the Foundation framework. At the core of the system is [`URLSession`](https://developer.apple.com/documentation/foundation/urlsession) and the [`URLSessionTask`](https://developer.apple.com/documentation/foundation/urlsessiontask) subclasses. Alamofire wraps these APIs, and many others, in an easier to use interface and provides a variety of functionality necessary for modern application development using HTTP networking. However, it's important to know where many of Alamofire's core behaviors come from, so familiarity with the URL Loading System is important. Ultimately, the networking features of Alamofire are limited by the capabilities of that system, and the behaviors and best practices should always be remembered and observed.

Additionally, networking in Alamofire (and the URL Loading System in general) is done _asynchronously_. Asynchronous programming may be a source of frustration to programmers unfamiliar with the concept, but there are [very good reasons](https://developer.apple.com/library/ios/qa/qa1693/_index.html) for doing it this way.

#### Aside: The `AF` Namespace and Reference
Previous versions of Alamofire's documentation used examples like `Alamofire.request()`. This API, while it appeared to require the `Alamofire` prefix, in fact worked fine without it. The `request` method and other functions were available globally in any file with `import Alamofire`. Starting in Alamofire 5, this functionality has been removed and instead the `AF` global is a reference to `Session.default`. This allows Alamofire to offer the same convenience functionality while not having to pollute the global namespace every time Alamofire is used and not having to duplicate the `Session` API globally. Similarly, types extended by Alamofire will use an `af` property extension to separate the functionality Alamofire adds from other extensions.

## Making Requests
Alamofire provides a variety of convenience methods for making HTTP requests. At the simplest, just provide a `String` that can be converted into a `URL`:

```swift
AF.request("https://httpbin.org/get").response { response in
    debugPrint(response)
}
```

> All examples require `import Alamofire` somewhere in the source file.

> For examples of use with Swift's `async`-`await` syntax, see our [Advanced Usage](https://github.com/Alamofire/Alamofire/blob/master/Documentation/AdvancedUsage.md#using-alamofire-with-swift-concurrency) documentation.

This is actually one form of the two top-level APIs on Alamofire's `Session` type for making requests. Its full definition looks like this:

```swift
open func request<Parameters: Encodable>(_ convertible: URLConvertible,
                                         method: HTTPMethod = .get,
                                         parameters: Parameters? = nil,
                                         encoder: ParameterEncoder = URLEncodedFormParameterEncoder.default,
                                         headers: HTTPHeaders? = nil,
                                         interceptor: RequestInterceptor? = nil) -> DataRequest
```
This method creates a `DataRequest` while allowing the composition of requests from individual components, such as the `method` and `headers`, while also allowing per-request `RequestInterceptor`s and `Encodable` parameters.

> There are additional methods that allow you to make requests using `Parameters` dictionaries and `ParameterEncoding` types. This API is no longer recommended and will eventually be deprecated and removed from Alamofire.

The second version of this API is much simpler:

```swift
open func request(_ urlRequest: URLRequestConvertible, 
                  interceptor: RequestInterceptor? = nil) -> DataRequest
```

This method creates a `DataRequest` for any type conforming to Alamofire's `URLRequestConvertible` protocol. All of the different parameters from the previous version are encapsulated in that value, which can give rise to very powerful abstractions. This is discussed in our [Advanced Usage](https://github.com/Alamofire/Alamofire/blob/master/Documentation/AdvancedUsage.md) documentation.

### HTTP Methods

The `HTTPMethod` type lists the HTTP methods defined in [RFC 7231 §4.3](https://tools.ietf.org/html/rfc7231#section-4.3):

```swift
public struct HTTPMethod: RawRepresentable, Equatable, Hashable {
    public static let connect = HTTPMethod(rawValue: "CONNECT")
    public static let delete = HTTPMethod(rawValue: "DELETE")
    public static let get = HTTPMethod(rawValue: "GET")
    public static let head = HTTPMethod(rawValue: "HEAD")
    public static let options = HTTPMethod(rawValue: "OPTIONS")
    public static let patch = HTTPMethod(rawValue: "PATCH")
    public static let post = HTTPMethod(rawValue: "POST")
    public static let put = HTTPMethod(rawValue: "PUT")
    public static let query = HTTPMethod(rawValue: "QUERY")
    public static let trace = HTTPMethod(rawValue: "TRACE")

    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}
```

These values can be passed as the `method` argument to the `AF.request` API:

```swift
AF.request("https://httpbin.org/get")
AF.request("https://httpbin.org/post", method: .post)
AF.request("https://httpbin.org/put", method: .put)
AF.request("https://httpbin.org/delete", method: .delete)
```

It's important to remember that the different HTTP methods may have different semantics and require different parameter encodings depending on what the server expects. For instance, passing body data in a `GET` request is not supported by `URLSession` or Alamofire and will return an error.

Alamofire also offers an extension on `URLRequest` to bridge the `httpMethod` property that returns a `String` to an `HTTPMethod` value:

```swift
extension URLRequest {
    /// Returns the `httpMethod` as Alamofire's `HTTPMethod` type.
    public var method: HTTPMethod? {
        get { httpMethod.flatMap(HTTPMethod.init) }
        set { httpMethod = newValue?.rawValue }
    }
}
```

If you need to use an HTTP method that Alamofire's `HTTPMethod` type doesn't support, you can extend the type to add your custom values:

```swift
extension HTTPMethod {
    static let custom = HTTPMethod(rawValue: "CUSTOM")
}

AF.request("https://httpbin.org/headers", method: .custom)
```

### Setting Other `URLRequest` Properties

Alamofire's request creation methods offer the most common parameters for customization but sometimes those just aren't enough. The `URLRequest`s created from the passed values can be modified by using a `RequestModifier` closure when creating requests. For example, to set the `URLRequest`'s `timeoutInterval` to 5 seconds, modify the request in the closure.

```swift
AF.request("https://httpbin.org/get", requestModifier: { $0.timeoutInterval = 5 }).response(...)
```

`RequestModifier`s also work with trailing closure syntax.

```swift
AF.request("https://httpbin.org/get") { urlRequest in
    urlRequest.timeoutInterval = 5
    urlRequest.allowsConstrainedNetworkAccess = false
}
.response(...)
```

`RequestModifier`s only apply to request created using methods taking a `URL` and other individual components, not to values created directly from `URLRequestConvertible` values, as those values should be able to set all parameters themselves. Additionally, adoption of `URLRequestConvertible` is recommended once *most* requests start needing to be modified during creation. You can read more in our [Advanced Usage documentation](https://github.com/Alamofire/Alamofire/blob/master/Documentation/AdvancedUsage.md#making-requests).

### Request Parameters and Parameter Encoders

Alamofire supports passing any `Encodable` type as the parameters of a request. These parameters are then passed through a type conforming to the `ParameterEncoder` protocol and added to the `URLRequest` which is then sent over the network. Alamofire includes two `ParameterEncoder` conforming types: `JSONParameterEncoder` and `URLEncodedFormParameterEncoder`. These types cover the most common encodings used by modern services (XML encoding is left as an exercise for the reader).

```swift
struct Login: Encodable {
    let email: String
    let password: String
}

let login = Login(email: "test@test.test", password: "testPassword")

AF.request("https://httpbin.org/post",
           method: .post,
           parameters: login,
           encoder: JSONParameterEncoder.default).response { response in
    debugPrint(response)
}
```

#### `URLEncodedFormParameterEncoder`

The `URLEncodedFormParameterEncoder` encodes values into a url-encoded string to be set as or appended to any existing URL query string or set as the HTTP body of the request. Controlling where the encoded string is set can be done by setting the `destination` of the encoding. The `URLEncodedFormParameterEncoder.Destination` enumeration has three cases:

- `.methodDependent` - Applies the encoded query string result to existing query string for `.get`, `.head` and `.delete` requests and sets it as the HTTP body for requests with any other HTTP method.
- `.queryString` - Sets or appends the encoded string to the query of the request's `URL`.
- `.httpBody` - Sets the encoded string as the HTTP body of the `URLRequest`.

The `Content-Type` HTTP header of an encoded request with HTTP body is set to `application/x-www-form-urlencoded; charset=utf-8`, if `Content-Type` is not already set.

Internally, `URLEncodedFormParameterEncoder` uses `URLEncodedFormEncoder` to perform the actual encoding from an `Encodable` type to a URL encoded form `String`. This encoder can be used to customize the encoding for various types, including `Array` using the `ArrayEncoding`, `Bool` using the `BoolEncoding`, `Data` using the `DataEncoding`, `Date` using the `DateEncoding`, coding keys using the `KeyEncoding`, and spaces using the `SpaceEncoding`.

##### GET Request With URL-Encoded Parameters

```swift
let parameters = ["foo": "bar"]

// All three of these calls are equivalent
AF.request("https://httpbin.org/get", parameters: parameters) // encoding defaults to `URLEncoding.default`
AF.request("https://httpbin.org/get", parameters: parameters, encoder: URLEncodedFormParameterEncoder.default)
AF.request("https://httpbin.org/get", parameters: parameters, encoder: URLEncodedFormParameterEncoder(destination: .methodDependent))

// https://httpbin.org/get?foo=bar
```

##### POST Request With URL-Encoded Parameters

```swift
let parameters: [String: [String]] = [
    "foo": ["bar"],
    "baz": ["a", "b"],
    "qux": ["x", "y", "z"]
]

// All three of these calls are equivalent
AF.request("https://httpbin.org/post", method: .post, parameters: parameters)
AF.request("https://httpbin.org/post", method: .post, parameters: parameters, encoder: URLEncodedFormParameterEncoder.default)
AF.request("https://httpbin.org/post", method: .post, parameters: parameters, encoder: URLEncodedFormParameterEncoder(destination: .httpBody))

// HTTP body: "qux[]=x&qux[]=y&qux[]=z&baz[]=a&baz[]=b&foo[]=bar"
```

#### Configuring the Sorting of Encoded Values

Since Swift 4.2, the hashing algorithm used by Swift's `Dictionary` type produces a random internal ordering at runtime which differs between app launches. This can cause encoded parameters to change order, which may have an impact on caching and other behaviors. By default `URLEncodedFormEncoder` will sort its encoded key-value pairs. While this produces constant output for all `Encodable` types, it may not match the actual encoding order implemented by the type. You can set `alphabetizeKeyValuePairs` to `false` to return to implementation order, though that will also have the randomized `Dictionary` order as well.

You can create your own `URLEncodedFormParameterEncoder` and specify the desired `alphabetizeKeyValuePairs` in the initializer of the passed `URLEncodedFormEncoder`:

```swift
let encoder = URLEncodedFormParameterEncoder(encoder: URLEncodedFormEncoder(alphabetizeKeyValuePairs: false))
```

##### Configuring the Encoding of `Array` Parameters

Since there is no published specification for how to encode collection types, by default Alamofire follows the convention of appending `[]` to the key for array values (`foo[]=1&foo[]=2`), and appending the key surrounded by square brackets for nested dictionary values (`foo[bar]=baz`).

The `URLEncodedFormEncoder.ArrayEncoding` enumeration provides the following methods for encoding `Array` parameters:

- `.brackets` - An empty set of square brackets is appended to the key for every value. This is the default case.
- `.noBrackets` - No brackets are appended. The key is encoded as is.

By default, Alamofire uses the `.brackets` encoding, where `foo = [1, 2]` is encoded as `foo[]=1&foo[]=2`.

Using the `.noBrackets` encoding will encode `foo = [1, 2]` as `foo=1&foo=2`.

You can create your own `URLEncodedFormParameterEncoder` and specify the desired `ArrayEncoding` in the initializer of the passed `URLEncodedFormEncoder`:

```swift
let encoder = URLEncodedFormParameterEncoder(encoder: URLEncodedFormEncoder(arrayEncoding: .noBrackets))
```

##### Configuring the Encoding of `Bool` Parameters

The `URLEncodedFormEncoder.BoolEncoding` enumeration provides the following methods for encoding `Bool` parameters:

- `.numeric` - Encode `true` as `1` and `false` as `0`. This is the default case.
- `.literal` - Encode `true` and `false` as string literals.

By default, Alamofire uses the `.numeric` encoding.

You can create your own `URLEncodedFormParameterEncoder` and specify the desired `BoolEncoding` in the initializer of the passed `URLEncodedFormEncoder`:

```swift
let encoder = URLEncodedFormParameterEncoder(encoder: URLEncodedFormEncoder(boolEncoding: .numeric))
```

##### Configuring the Encoding of `Data` Parameters

`DataEncoding` includes the following methods for encoding `Data` parameters:

- `.deferredToData` - Uses `Data`'s native `Encodable` support.
- `.base64` - Encodes `Data` as a Base 64 encoded `String`. This is the default case.
- `.custom((Data) -> throws -> String)` - Encodes `Data` using the given closure.

You can create your own `URLEncodedFormParameterEncoder` and specify the desired `DataEncoding` in the initializer of the passed `URLEncodedFormEncoder`:

```swift
let encoder = URLEncodedFormParameterEncoder(encoder: URLEncodedFormEncoder(dataEncoding: .base64))
```

##### Configuring the Encoding of `Date` Parameters

Given the sheer number of ways to encode a `Date` into a `String`, `DateEncoding` includes the following methods for encoding `Date` parameters:

- `.deferredToDate` - Uses `Date`'s native `Encodable` support. This is the default case.
- `.secondsSince1970` - Encodes `Date`s as seconds since midnight UTC on January 1, 1970. 
- `.millisecondsSince1970` - Encodes `Date`s as milliseconds since midnight UTC on January 1, 1970.
- `.iso8601` - Encodes `Date`s according to the ISO 8601 and RFC3339 standards.
- `.formatted(DateFormatter)` - Encodes `Date`s using the given `DateFormatter`.
- `.custom((Date) throws -> String)` - Encodes `Date`s using the given closure.

You can create your own `URLEncodedFormParameterEncoder` and specify the desired `DateEncoding` in the initializer of the passed `URLEncodedFormEncoder`:

```swift
let encoder = URLEncodedFormParameterEncoder(encoder: URLEncodedFormEncoder(dateEncoding: .iso8601))
```

##### Configuring the Encoding of Coding Keys

Due to the variety of parameter key styles, `KeyEncoding` provides the following methods to customize key encoding from keys in `lowerCamelCase`:

- `.useDefaultKeys` - Uses the keys specified by each type. This is the default case.
- `.convertToSnakeCase` - Converts keys to snake case: `oneTwoThree` becomes `one_two_three`.
- `.convertToKebabCase` - Converts keys to kebab case: `oneTwoThree` becomes `one-two-three`.
- `.capitalized` - Capitalizes the first letter only, a.k.a `UpperCamelCase`: `oneTwoThree` becomes `OneTwoThree`.
- `.uppercased` - Uppercases all letters: `oneTwoThree` becomes `ONETWOTHREE`.
- `.lowercased` - Lowercases all letters: `oneTwoThree` becomes `onetwothree`.
- `.custom((String) -> String)` - Encodes keys using the given closure.

You can create your own `URLEncodedFormParameterEncoder` and specify the desired `KeyEncoding` in the initializer of the passed `URLEncodedFormEncoder`:

```swift
let encoder = URLEncodedFormParameterEncoder(encoder: URLEncodedFormEncoder(keyEncoding: .convertToSnakeCase))
```

##### Configuring the Encoding of Spaces

Older form encoders used `+` to encode spaces and some servers still expect this encoding instead of the modern percent encoding, so Alamofire includes the following methods for encoding spaces:

- `.percentEscaped` - Encodes space characters by applying standard percent escaping. `" "` is encoded as  `"%20"`. This is the default case.
- `.plusReplaced` - Encodes space characters by replacing them with `+`. `" "` is encoded as `"+"`.

You can create your own `URLEncodedFormParameterEncoder` and specify the desired `SpaceEncoding` in the initializer of the passed `URLEncodedFormEncoder`:

```swift
let encoder = URLEncodedFormParameterEncoder(encoder: URLEncodedFormEncoder(spaceEncoding: .plusReplaced))
```

#### `JSONParameterEncoder`

`JSONParameterEncoder` encodes `Encodable` values using Swift's `JSONEncoder` and sets the result as the `httpBody` of the `URLRequest`. The `Content-Type` HTTP header field of an encoded request is set to `application/json` if not already set.

##### POST Request with JSON-Encoded Parameters

```swift
let parameters: [String: [String]] = [
    "foo": ["bar"],
    "baz": ["a", "b"],
    "qux": ["x", "y", "z"]
]

AF.request("https://httpbin.org/post", method: .post, parameters: parameters, encoder: JSONParameterEncoder.default)
AF.request("https://httpbin.org/post", method: .post, parameters: parameters, encoder: JSONParameterEncoder.prettyPrinted)
AF.request("https://httpbin.org/post", method: .post, parameters: parameters, encoder: JSONParameterEncoder.sortedKeys)

// HTTP body: {"baz":["a","b"],"foo":["bar"],"qux":["x","y","z"]}
```

##### Configuring a Custom `JSONEncoder`

You can customize the behavior of `JSONParameterEncoder` by passing it a `JSONEncoder` instance configured to your needs:

```swift
let encoder = JSONEncoder()
encoder.dateEncoding = .iso8601
encoder.keyEncodingStrategy = .convertToSnakeCase
let parameterEncoder = JSONParameterEncoder(encoder: encoder)
```

##### Manual Parameter Encoding of a `URLRequest`

The `ParameterEncoder` APIs can also be used outside of Alamofire by encoding parameters directly in `URLRequest`s.

```swift
let url = URL(string: "https://httpbin.org/get")!
var urlRequest = URLRequest(url: url)

let parameters = ["foo": "bar"]
let encodedURLRequest = try URLEncodedFormParameterEncoder.default.encode(parameters, 
                                                                          into: urlRequest)
```

### HTTP Headers

Alamofire includes its own `HTTPHeaders` type, an order-preserving and case-insensitive representation of HTTP header name / value pairs. The `HTTPHeader` types encapsulate a single name / value pair and provides a variety of static values for common headers.

Adding custom `HTTPHeaders` to a `Request` is as simple as passing a value to one of the `request` methods:

```swift
let headers: HTTPHeaders = [
    "Authorization": "Basic VXNlcm5hbWU6UGFzc3dvcmQ=",
    "Accept": "application/json"
]

AF.request("https://httpbin.org/headers", headers: headers).responseDecodable(of: DecodableType.self) { response in
    debugPrint(response)
}
```

`HTTPHeaders` can also be constructed from an array of `HTTPHeader` values:

```swift
let headers: HTTPHeaders = [
    .authorization(username: "Username", password: "Password"),
    .accept("application/json")
]

AF.request("https://httpbin.org/headers", headers: headers).responseDecodable(of: DecodableType.self) { response in
    debugPrint(response)
}
```

> For HTTP headers that do not change, it is recommended to set them on the `URLSessionConfiguration` so they are automatically applied to any `URLSessionTask` created by the underlying `URLSession`. For more information, see the [Session Configurations](https://github.com/Alamofire/Alamofire/blob/master/Documentation/AdvancedUsage.md#creating-a-session-with-a-urlsessionconfiguration) section.

The default Alamofire `Session` provides a default set of headers for every `Request`. These include:

- `Accept-Encoding`, which defaults to `br;q=1.0, gzip;q=0.8, deflate;q=0.6`, per [RFC 7230 §4.2.3](https://tools.ietf.org/html/rfc7230#section-4.2.3).
- `Accept-Language`, which defaults to up to the top 6 preferred languages on the system, formatted like `en;q=1.0`, per [RFC 7231 §5.3.5](https://tools.ietf.org/html/rfc7231#section-5.3.5).
- `User-Agent`, which contains versioning information about the current app. For example: `iOS Example/1.0 (com.alamofire.iOS-Example; build:1; iOS 13.0.0) Alamofire/5.0.0`, per [RFC 7231 §5.5.3](https://tools.ietf.org/html/rfc7231#section-5.5.3).

If you need to customize these headers, a custom `URLSessionConfiguration` should be created, the `headers` property updated, and the configuration applied to a new `Session` instance. Use `URLSessionConfiguration.af.default` to customize your configuration while keeping Alamofire's default headers.

### Response Validation

By default, Alamofire treats any completed request to be successful, regardless of the content of the response. Calling `validate()` before a response handler causes an error to be generated if the response had an unacceptable status code or MIME type.

#### Automatic Validation

The `validate()` API automatically validates that status codes are within the `200..<300` range, and that the `Content-Type` header of the response matches the `Accept` header of the request, if one is provided.

```swift
AF.request("https://httpbin.org/get").validate().responseData { response in
    debugPrint(response)
}
```

#### Manual Validation

```swift
AF.request("https://httpbin.org/get")
    .validate(statusCode: 200..<300)
    .validate(contentType: ["application/json"])
    .responseData { response in
        switch response.result {
        case .success:
            print("Validation Successful")
        case let .failure(error):
            print(error)
        }
    }
```

### Response Handling

Alamofire's `DataRequest` and `DownloadRequest` both have a corresponding response type: `DataResponse<Success, Failure: Error>` and `DownloadResponse<Success, Failure: Error>`. Both of these are composed of two generics: the serialized type and the error type. By default, all response values will produce the `AFError` error type (i.e. `DataResponse<Success, AFError>`). Alamofire uses the simpler `AFDataResponse<Success>` and `AFDownloadResponse<Success>`, in its public API, which always have `AFError` error types. `UploadRequest`, a subclass of `DataRequest`, uses the same `DataResponse` type.

Handling the `DataResponse` of a `DataRequest` or `UploadRequest` made in Alamofire involves chaining a response handler like `responseDecodable` onto the `DataRequest`:

```swift
AF.request("https://httpbin.org/get").responseDecodable(of: DecodableType.self) { response in
    debugPrint(response)
}
```

In the above example, the `responseDecodable` handler is added to the `DataRequest` to be executed once the `DataRequest` is complete. The closure passed to the handler receives the `DataResponse<DecodableType, AFError>` value produced by the `DecodableResponseSerializer` from the `URLRequest`, `HTTPURLResponse`, `Data`, and `Error` produced by the request.

Rather than blocking execution to wait for a response from the server, this closure is added as a [callback](https://en.wikipedia.org/wiki/Callback_%28computer_programming%29) to handle the response once it's received. The result of a request is only available inside the scope of a response closure. Any execution contingent on the response or data received from the server must be done within a response closure.

> Networking in Alamofire is done _asynchronously_. Asynchronous programming may be a source of frustration to programmers unfamiliar with the concept, but there are [very good reasons](https://developer.apple.com/library/ios/qa/qa1693/_index.html) for doing it this way.

Alamofire contains five different data response handlers by default, including:

```swift
// Response Handler - Unserialized Response
func response(queue: DispatchQueue = .main, 
              completionHandler: @escaping (AFDataResponse<Data?>) -> Void) -> Self

// Response Serializer Handler - Serialize using the passed Serializer
func response<Serializer: DataResponseSerializerProtocol>(queue: DispatchQueue = .main,
                                                          responseSerializer: Serializer,
                                                          completionHandler: @escaping (AFDataResponse<Serializer.SerializedObject>) -> Void) -> Self

// Response Data Handler - Serialized into Data
func responseData(queue: DispatchQueue = .main,
                  dataPreprocessor: DataPreprocessor = DataResponseSerializer.defaultDataPreprocessor,
                  emptyResponseCodes: Set<Int> = DataResponseSerializer.defaultEmptyResponseCodes,
                  emptyRequestMethods: Set<HTTPMethod> = DataResponseSerializer.defaultEmptyRequestMethods,
                  completionHandler: @escaping (AFDataResponse<Data>) -> Void) -> Self

// Response String Handler - Serialized into String
func responseString(queue: DispatchQueue = .main,
                    dataPreprocessor: DataPreprocessor = StringResponseSerializer.defaultDataPreprocessor,
                    encoding: String.Encoding? = nil,
                    emptyResponseCodes: Set<Int> = StringResponseSerializer.defaultEmptyResponseCodes,
                    emptyRequestMethods: Set<HTTPMethod> = StringResponseSerializer.defaultEmptyRequestMethods,
                    completionHandler: @escaping (AFDataResponse<String>) -> Void) -> Self

// Response Decodable Handler - Serialized into Decodable Type
func responseDecodable<T: Decodable>(of type: T.Type = T.self,
                                     queue: DispatchQueue = .main,
                                     dataPreprocessor: DataPreprocessor = DecodableResponseSerializer<T>.defaultDataPreprocessor,
                                     decoder: DataDecoder = JSONDecoder(),
                                     emptyResponseCodes: Set<Int> = DecodableResponseSerializer<T>.defaultEmptyResponseCodes,
                                     emptyRequestMethods: Set<HTTPMethod> = DecodableResponseSerializer<T>.defaultEmptyRequestMethods,
                                     completionHandler: @escaping (AFDataResponse<T>) -> Void) -> Self
```

None of the response handlers perform any validation of the `HTTPURLResponse` it gets back from the server.

> For example, response status codes in the `400..<500` and `500..<600` ranges do NOT automatically trigger an `Error`. Alamofire uses [Response Validation](#response-validation) method chaining to achieve this.

#### Response Handler

The `response` handler does NOT evaluate any of the response data. It merely forwards on all information directly from the `URLSessionDelegate`. It is the Alamofire equivalent of using `cURL` to execute a `Request`.

```swift
AF.request("https://httpbin.org/get").response { response in
    debugPrint("Response: \(response)")
}
```

> We strongly encourage you to leverage the other response serializers taking advantage of `Response` and `Result` types.

#### Response Data Handler

The `responseData` handler uses a `DataResponseSerializer` to extract and validate the `Data` returned by the server. If no errors occur and `Data` is returned, the response `Result` will be a `.success` and the `value` will be the `Data` returned from the server.

```swift
AF.request("https://httpbin.org/get").responseData { response in
    debugPrint("Response: \(response)")
}
```

#### Response String Handler

The `responseString` handler uses a `StringResponseSerializer` to convert the `Data` returned by the server into a `String` with the specified encoding. If no errors occur and the server data is successfully serialized into a `String`, the response `Result` will be a `.success` and the `value` will be of type `String`.

```swift
AF.request("https://httpbin.org/get").responseString { response in
    debugPrint("Response: \(response)")
}
```

> If no encoding is specified, Alamofire will use the text encoding specified in the `HTTPURLResponse` from the server. If the text encoding cannot be determined by the server response, it defaults to `.isoLatin1`.

#### Response `Decodable` Handler

The `responseDecodable` handler uses a `DecodableResponseSerializer` to convert the `Data` returned by the server into the passed `Decodable` type using the specified `DataDecoder` (a protocol abstraction for `Decoder`s which can decode from `Data`). If no errors occur and the server data is successfully decoded into a `Decodable` type, the response `Result` will be a `.success` and the `value` will be of the passed type.

```swift
struct DecodableType: Decodable { let url: String }

AF.request("https://httpbin.org/get").responseDecodable(of: DecodableType.self) { response in
    debugPrint("Response: \(response)")
}
```

#### Chained Response Handlers

Response handlers can also be chained:

```swift
Alamofire.request("https://httpbin.org/get")
    .responseString { response in
        print("Response String: \(response.value)")
    }
    .responseDecodable(of: DecodableType.self) { response in
        print("Response DecodableType: \(response.value)")
    }
```

> It is important to note that using multiple response handlers on the same `Request` requires the server data to be serialized multiple times, once for each response handler. Using multiple response handlers on the same `Request` should generally be avoided as best practice, especially in production environments. They should only be used for debugging or in circumstances where there is no better option.

#### Response Handler Queue

Closures passed to response handlers are executed on the `.main` queue by default, but a specific `DispatchQueue` can be passed on which to execute the closure. Actual serialization work (conversion of `Data` to some other type) is always executed in the background on either the `rootQueue` or the `serializationQueue`, if one was provided, of the `Session` issuing the request.

```swift
let utilityQueue = DispatchQueue.global(qos: .utility)

AF.request("https://httpbin.org/get").responseDecodable(of: DecodableType.self, queue: utilityQueue) { response in
    print("This closure is executed on utilityQueue.")
    debugPrint(response)
}
```

### Response Caching

Response caching is handled on the system framework level by [`URLCache`](https://developer.apple.com/reference/foundation/urlcache). It provides a composite in-memory and on-disk cache and lets you manipulate the sizes of both the in-memory and on-disk portions.

> By default, Alamofire leverages the `URLCache.shared` instance. In order to customize the `URLCache` instance used, see the [Session Configuration](AdvancedUsage.md#session-manager) section.

### Authentication

Authentication is handled on the system framework level by [`URLCredential`](https://developer.apple.com/reference/foundation/nsurlcredential) and [`URLAuthenticationChallenge`](https://developer.apple.com/reference/foundation/urlauthenticationchallenge).

> These authentication APIs are for servers which prompt for authorization, not general use with APIs which require an `Authenticate`  or equivalent header.

**Supported Authentication Schemes**

- [HTTP Basic](https://en.wikipedia.org/wiki/Basic_access_authentication)
- [HTTP Digest](https://en.wikipedia.org/wiki/Digest_access_authentication)
- [Kerberos](https://en.wikipedia.org/wiki/Kerberos_%28protocol%29)
- [NTLM](https://en.wikipedia.org/wiki/NT_LAN_Manager)

#### HTTP Basic Authentication

The `authenticate` method on a `Request` will automatically provide a `URLCredential` when challenged with a `URLAuthenticationChallenge` when appropriate:

```swift
let user = "user"
let password = "password"

AF.request("https://httpbin.org/basic-auth/\(user)/\(password)")
    .authenticate(username: user, password: password)
    .responseDecodable(of: DecodableType.self) { response in
        debugPrint(response)
    }
```

#### Authentication with `URLCredential`

```swift
let user = "user"
let password = "password"

let credential = URLCredential(user: user, password: password, persistence: .forSession)

AF.request("https://httpbin.org/basic-auth/\(user)/\(password)")
    .authenticate(with: credential)
    .responseDecodable(of: DecodableType.self) { response in
        debugPrint(response)
    }
```

> It is important to note that when using a `URLCredential` for authentication, the underlying `URLSession` will actually end up making two requests if a challenge is issued by the server. The first request will not include the credential which "may" trigger a challenge from the server. The challenge is then received by Alamofire, the credential is appended and the request is retried by the underlying `URLSession`.

#### Manual Authentication

If you are communicating with an API that always requires an `Authenticate` or similar header without prompting, it can be added manually:

```swift
let user = "user"
let password = "password"

let headers: HTTPHeaders = [.authorization(username: user, password: password)]

AF.request("https://httpbin.org/basic-auth/user/password", headers: headers)
    .responseDecodable(of: DecodableType.self) { response in
        debugPrint(response)
    }
```

However, headers that must be part of all requests are often better handled as part of a custom [`URLSessionConfiguration`](AdvancedUsage.md#session-manager), or by using a [`RequestAdapter`](AdvancedUsage.md#request-adapter).

### Downloading Data to a File

In addition to fetching data into memory, Alamofire also provides the `Session.download`, `DownloadRequest`, and `DownloadResponse<Success, Failure: Error>` APIs to facilitate downloading to disk. While downloading into memory works great for small payloads like most JSON API responses, fetching larger assets like images and videos should be downloaded to disk to avoid memory issues with your application.

```swift
AF.download("https://httpbin.org/image/png").responseURL { response in
    // Read file from provided file URL.
}
```

In addition to having the same response handlers that `DataRequest` does, `DownloadRequest` also includes `responseURL`. Unlike the other response handlers, this handler just returns the `URL` containing the location of the downloaded data and does not read the `Data` from disk.

Other response handlers, like `responseDecodable`, involve reading the response `Data` from disk. This may involve reading large amounts of data into memory, so it's important to keep that in mind when using those handlers for downloads.

#### Download File Destination

All downloaded data is initially stored in the system temporary directory. It will eventually be deleted by the system at some point in the future, so if it's something that needs to live longer, it's important to move the file somewhere else.

You can provide a `Destination` closure to move the file from the temporary directory to a final destination. Before the temporary file is actually moved to the `destinationURL`, the `Options` specified in the closure will be executed. The two currently supported `Options` are:

- `.createIntermediateDirectories` - Creates intermediate directories for the destination URL if specified.
- `.removePreviousFile` - Removes a previous file from the destination URL if specified.

```swift
let destination: DownloadRequest.Destination = { _, _ in
    let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let fileURL = documentsURL.appendingPathComponent("image.png")

    return (fileURL, [.removePreviousFile, .createIntermediateDirectories])
}

AF.download("https://httpbin.org/image/png", to: destination).response { response in
    debugPrint(response)

    if response.error == nil, let imagePath = response.fileURL?.path {
        let image = UIImage(contentsOfFile: imagePath)
    }
}
```

You can also use the suggested download destination API:

```swift
let destination = DownloadRequest.suggestedDownloadDestination(for: .documentDirectory)

AF.download("https://httpbin.org/image/png", to: destination)
```

#### Download Progress

Many times it can be helpful to report download progress to the user. Any `DownloadRequest` can report download progress using the `downloadProgress` API.

```swift
AF.download("https://httpbin.org/image/png")
    .downloadProgress { progress in
        print("Download Progress: \(progress.fractionCompleted)")
    }
    .responseData { response in
        if let data = response.value {
            let image = UIImage(data: data)
        }
    }
```

> The progress reporting APIs for `URLSession`, and therefore Alamofire, only work if the server properly returns a `Content-Length` header that can be used to calculate the progress. Without that header, progress will stay at `0.0` until the download completes, at which point the progress will jump to `1.0`.

The `downloadProgress` API can also take a `queue` parameter which defines which `DispatchQueue` the download progress closure should be called on.

```swift
let progressQueue = DispatchQueue(label: "com.alamofire.progressQueue", qos: .utility)

AF.download("https://httpbin.org/image/png")
    .downloadProgress(queue: progressQueue) { progress in
        print("Download Progress: \(progress.fractionCompleted)")
    }
    .responseData { response in
        if let data = response.value {
            let image = UIImage(data: data)
        }
    }
```

#### Canceling and Resuming a Download

In addition to the `cancel()` API that all `Request` classes have, `DownloadRequest`s can also produce resume data, which can be used to later resume a download. There are two forms of this API: `cancel(producingResumeData: Bool)`, which allows control over whether resume data is produced, but only makes it available on the `DownloadResponse`; and `cancel(byProducingResumeData: (_ resumeData: Data?) -> Void)`, which performs the same actions but makes the resume data available in the completion handler.

If a `DownloadRequest` is canceled or interrupted, the underlying `URLSessionDownloadTask` *may* generate resume data. If this happens, the resume data can be re-used to restart the `DownloadRequest` where it left off. 

> **IMPORTANT:** On some versions of all Apple platforms (iOS 10 - 10.2, macOS 10.12 - 10.12.2, tvOS 10 - 10.1, watchOS 3 - 3.1.1), `resumeData` is broken on background `URLSessionConfiguration`s. There's an underlying bug in the `resumeData` generation logic where the data is written incorrectly and will always fail to resume the download. For more information about the bug and possible workarounds, please see this [Stack Overflow post](https://stackoverflow.com/a/39347461/1342462).

```swift
var resumeData: Data!

let download = AF.download("https://httpbin.org/image/png").responseData { response in
    if let data = response.value {
        let image = UIImage(data: data)
    }
}

// download.cancel(producingResumeData: true) // Makes resumeData available in response only.
download.cancel { data in
    resumeData = data
}

AF.download(resumingWith: resumeData).responseData { response in
    if let data = response.value {
        let image = UIImage(data: data)
    }
}
```

### Uploading Data to a Server

When sending relatively small amounts of data to a server using JSON or URL encoded parameters, the `request()` APIs are usually sufficient. If you need to send much larger amounts of data from `Data` in memory, a file `URL`, or an `InputStream`, then the `upload()` APIs are what you want to use.

#### Uploading Data

```swift
let data = Data("data".utf8)

AF.upload(data, to: "https://httpbin.org/post").responseDecodable(of: DecodableType.self) { response in
    debugPrint(response)
}
```

#### Uploading a File

```swift
let fileURL = Bundle.main.url(forResource: "video", withExtension: "mov")

AF.upload(fileURL, to: "https://httpbin.org/post").responseDecodable(of: DecodableType.self) { response in
    debugPrint(response)
}
```

#### Uploading Multipart Form Data

```swift
AF.upload(multipartFormData: { multipartFormData in
    multipartFormData.append(Data("one".utf8), withName: "one")
    multipartFormData.append(Data("two".utf8), withName: "two")
}, to: "https://httpbin.org/post")
    .responseDecodable(of: DecodableType.self) { response in
        debugPrint(response)
    }
```

#### Upload Progress

While your user is waiting for their upload to complete, sometimes it can be handy to show the progress of the upload to the user. Any `UploadRequest` can report both upload progress of the upload and download progress of the response data download using the `uploadProgress` and `downloadProgress` APIs.

```swift
let fileURL = Bundle.main.url(forResource: "video", withExtension: "mov")

AF.upload(fileURL, to: "https://httpbin.org/post")
    .uploadProgress { progress in
        print("Upload Progress: \(progress.fractionCompleted)")
    }
    .downloadProgress { progress in
        print("Download Progress: \(progress.fractionCompleted)")
    }
    .responseDecodable(of: DecodableType.self) { response in
        debugPrint(response)
    }
```

### Streaming Data from a Server

Large downloads or long lasting server connections which receive data over time may be better served by streaming rather than accumulating `Data` as it arrives. Alamofire offers the `DataStreamRequest` type and associated APIs to handle this usage. Although it offers much of the same API as other `Request`s, there are several key differences. Most notably, `DataStreamRequest` never accumulates `Data` in memory or saves it to disk. Instead, added `responseStream` closures are repeatedly called as `Data` arrives. The same closures are called again when the connection has completed or received an error.

Every `Handler` closure captures a `Stream` value, which contains both the `Event` being processed as well as a `CancellationToken`, which can be used to cancel the request.

```swift
public struct Stream<Success, Failure: Error> {
    /// Latest `Event` from the stream.
    public let event: Event<Success, Failure>
    /// Token used to cancel the stream.
    public let token: CancellationToken
    /// Cancel the ongoing stream by canceling the underlying `DataStreamRequest`.
    public func cancel() {
        token.cancel()
    }
}
```

An `Event` is an `enum` representing two possible stream states.

```swift
public enum Event<Success, Failure: Error> {
    /// Output produced every time the instance receives additional `Data`. The associated value contains the
    /// `Result` of processing the incoming `Data`.
    case stream(Result<Success, Failure>)
    /// Output produced when the instance has completed, whether due to stream end, cancellation, or an error.
    /// Associated `Completion` value contains the final state.
    case complete(Completion)
}
```

When complete, the `Completion` value will contain the state of the `DataStreamRequest` when the stream ended.

```swift
public struct Completion {
    /// Last `URLRequest` issued by the instance.
    public let request: URLRequest?
    /// Last `HTTPURLResponse` received by the instance.
    public let response: HTTPURLResponse?
    /// Last `URLSessionTaskMetrics` produced for the instance.
    public let metrics: URLSessionTaskMetrics?
    /// `AFError` produced for the instance, if any.
    public let error: AFError?
}
```

#### Streaming `Data`

Streaming `Data` from a server can be accomplished like other Alamofire requests, but with a `Handler` closure added.

```swift
func responseStream(on queue: DispatchQueue = .main, stream: @escaping Handler<Data, Never>) -> Self
```

The provided `queue` is where the `Handler` closure will be called.

```swift
AF.streamRequest(...).responseStream { stream in
    switch stream.event {
    case let .stream(result):
        switch result {
        case let .success(data):
            print(data)
        }
    case let .complete(completion):
        print(completion)
    }
}
```

> Handling the `.failure` case of the `Result` in the example above is unnecessary, as receiving `Data` can never fail.

#### Streaming `String`s

Like `Data` streaming, `String`s can be streamed by adding a `Handler`.

```swift
func responseStreamString(on queue: DispatchQueue = .main,
                          stream: @escaping StreamHandler<String, Never>) -> Self
```

`String` values are decoded as `UTF8` and the decoding cannot fail.

```swift
AF.streamRequest(...).responseStreamString { stream in
    switch stream.event {
    case let .stream(result):
        switch result {
        case let .success(string):
            print(string)
        }
    case let .complete(completion):
        print(completion)
    }
}
```

#### Streaming `Decodable` Values

Incoming stream `Data` values can be turned into any `Decodable` value using `responseStreamDecodable`.

```swift
func responseStreamDecodable<T: Decodable>(of type: T.Type = T.self,
                                           on queue: DispatchQueue = .main,
                                           using decoder: DataDecoder = JSONDecoder(),
                                           preprocessor: DataPreprocessor = PassthroughPreprocessor(),
                                           stream: @escaping Handler<T, AFError>) -> Self
```

Decoding failures do not end the stream, but instead produce an `AFError` in the `Result` of the `Output`.

```swift
AF.streamRequest(...).responseStreamDecodable(of: SomeType.self) { stream in
    switch stream.event {
    case let .stream(result):
        switch result {
        case let .success(value):
            print(value)
        case let .failure(error):
            print(error)
        }
    case let .complete(completion):
        print(completion)
    }
}
```

#### Producing an `InputStream`

In addition to handling incoming `Data` using `StreamHandler` closures, `DataStreamRequest` can produce an `InputStream` value which can be used to read bytes as they arrive.

```swift
func asInputStream(bufferSize: Int = 1024) -> InputStream
```

`InputStream`s produced in this manner must have `open()` called before reading can start, or be passed to an API that opens the stream automatically. Once returned from this method, it's the caller's responsibility to keep the `InputStream` value alive and to call `close()` after reading is complete.

```swift
let inputStream = AF.streamRequest(...)
    .responseStream { output in
        ...
    }
    .asInputStream()
```

#### Cancellation

`DataStreamRequest`s can be cancelled in four ways. First, like all other Alamofire `Request`s, `DataStreamRequest` can have `cancel()` called, canceling the underlying task and completing the stream.

```swift
let request = AF.streamRequest(...).responseStream(...)
...
request.cancel()
```

Second, `DataStreamRequest`s can be cancelled automatically when their `DataStreamSerializer` encounters and error. This behavior is disabled by default and can be enabled by passing the `automaticallyCancelOnStreamError` parameter when creating the request.

```swift
AF.streamRequest(..., automaticallyCancelOnStreamError: true).responseStream(...)
```

Third, `DataStreamRequest`s will be cancelled if an error is thrown out of the `Handler` closure. This error is then stored on the request and is available in the `Completion` value.

```swift
AF.streamRequest(...).responseStream { stream in
    // Process stream.
    throw SomeError() // Cancels request.
}
```

Finally, `DataStreamRequest`s can be cancelled by using the `Stream` value's `cancel()` method. 

```swift
AF.streamRequest(...).responseStream { stream in 
    // Decide to cancel request.
    stream.cancel()
}
```

### Statistical Metrics

#### `URLSessionTaskMetrics`

Alamofire gathers `URLSessionTaskMetrics` for every `Request`. `URLSessionTaskMetrics` encapsulate some fantastic statistical information about the underlying network connection and request and response timing.

```swift
AF.request("https://httpbin.org/get").responseDecodable(of: DecodableType.self) { response in
    print(response.metrics)
}
```

> Due to `FB7624529`, collection of `URLSessionTaskMetrics` on watchOS is currently disabled.

### cURL Command Output

Debugging platform issues can be frustrating. Thankfully, Alamofire's `Request` type can produce the equivalent cURL command for easy debugging. Due to the asynchronous nature of Alamofire's `Request` creation, this API has both synchronous and asynchronous versions. To get the cURL command as soon as possible, you can chain the `cURLDescription` onto a request:

```swift
AF.request("https://httpbin.org/get")
    .cURLDescription { description in
        print(description)
    }
    .responseDecodable(of: DecodableType.self) { response in
        debugPrint(response.metrics)
    }
```

This should produce:

```bash
$ curl -v \
-X GET \
-H "Accept-Language: en;q=1.0" \
-H "Accept-Encoding: br;q=1.0, gzip;q=0.9, deflate;q=0.8" \
-H "User-Agent: Demo/1.0 (com.demo.Demo; build:1; iOS 15.0.0) Alamofire/1.0" \
"https://httpbin.org/get"
```
