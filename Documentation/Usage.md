# Using Alamofire

--

### Introduction
Alamofire provides an elegant and composable interface to HTTP network requests. It does not implement its own HTTP networking functionality. Instead it builds on top of Apple's [URL Loading System](https://developer.apple.com/documentation/foundation/url_loading_system/) provided by the Foundation framework. At the core of the system is [`URLSession`](https://developer.apple.com/documentation/foundation/urlsession) and the [`URLSessionTask`](https://developer.apple.com/documentation/foundation/urlsessiontask) subclasses. Alamofire wraps these APIs, and many others, in an easier to use interface and provides a variety of functionality necessary for modern application development using HTTP networking. However, it's important to know where many of Alamofire's core behaviors come from, so familiarity with the URL Loading System is important. Ultimately, the networking features of Alamofire are limited by the capabilities of that system, and the behaviors and best practices should always be remembered and observed.

Additionally, networking in Alamofire (and the URL Loading System in general) is done _asynchronously_. Asynchronous programming may be a source of frustration to programmers unfamiliar with the concept, but there are [very good reasons](https://developer.apple.com/library/ios/qa/qa1693/_index.html) for doing it this way.

#### Aside: The `AF` Namespace
Previous versions of Alamofire's documentation used examples like `Alamofire.request()`. This API, while it appeared to require the `Alamofire` prefix, in fact worked fine without it. The `request` method and other functions were available globally in any file with `import Alamofire`. Starting in Alamofire 5, this functionality has been moved out of the global [namespace](https://en.wikipedia.org/wiki/Namespace) and into the `AF` enumeration, which acts as a namespace. This allows Alamofire to offer the same convenience functionality while not having to pollute the global namespace every time Alamofire is used. Similarly, types extended by Alamofire will use a `.af.` extension prefix to separate the functionality Alamofire offers from other extensions.

### Making Requests
Alamofire provides a variety of convenient methods for making HTTP requests. At the simplest level, just provide a `String` that can be converted into a `URL`:

```swift
AF.request("https://httpbin.org/get").response { (response) in
    debugPrint(response)
}
```
> All examples require `import Alamofire` somewhere in the source file.

This is actually one form of the two top-level Alamofire APIs for making requests. Its full definition looks like this:

```swift
public static func request<Parameters: Encodable>(_ url: URLConvertible,
                                                  method: HTTPMethod = .get,
                                                  parameters: Parameters? = nil,
                                                  encoder: ParameterEncoder = URLEncodedFormParameterEncoder.default,
                                                  headers: HTTPHeaders? = nil,
                                                  interceptor: RequestInterceptor? = nil) -> DataRequest
```
This method allows the composition of requests from individual components, such as the `method` and `headers`, while also allowing per-request `RequestInterceptor`s and `Encodable` parameters.

> There are additional methods that allow you to make requests using `Parameters` dictionaries. This API is no longer recommended and will eventually be deprecated and removed from Alamofire.

The second version of this API is much simpler:

```swift
public static func request(_ urlRequest: URLRequestConvertible, 
                           interceptor: RequestInterceptor? = nil) -> DataRequest
```

This method creates a `DataRequest` for any type conforming to Alamofire's `URLRequestConvertible` protocol. All of the different parameters from the previous version are encapsulated in that value, which can give rise to very powerful abstractions. This is discussed later in this documentation.

#### HTTP Methods

The `HTTPMethod` enumeration lists the HTTP methods defined in [RFC 7231 §4.3](https://tools.ietf.org/html/rfc7231#section-4.3):

```swift
public enum HTTPMethod: String {
    case connect = "CONNECT"
    case delete  = "DELETE"
    case get     = "GET"
    case head    = "HEAD"
    case options = "OPTIONS"
    case patch   = "PATCH"
    case post    = "POST"
    case put     = "PUT"
    case trace   = "TRACE"
}
```

These values can be passed as the `method` argument to the `AF.request` API:

```swift
AF.request("https://httpbin.org/get")
AF.request("https://httpbin.org/post", method: .post)
AF.request("https://httpbin.org/put", method: .put)
AF.request("https://httpbin.org/delete", method: .delete)
```

It's important to remember that the different HTTP methods may have different semantics and require different parameter encodings depending on what the server expects. For instance, passing body data in a `GET` requests can cause timeouts or other errors when communicating with servers that don't support that configuration.

Alamofire also offers an extension on `URLRequest` to bridge the `httpMethod` property that returns a `String` to an `HTTPMethod` value:

```swift
public extension URLRequest {
    /// Returns the `httpMethod` as Alamofire's `HTTPMethod` type.
    var method: HTTPMethod? {
        get { return httpMethod.flatMap(HTTPMethod.init) }
        set { httpMethod = newValue?.rawValue }
    }
}
```

If you need to use an HTTP method that Alamofire's `HTTPMethod` type doesn't support, you can still set the `String` `httpMethod` property on `URLRequest` directly.

#### Request Parameters and Parameter Encoders

Alamofire supports sending any `Encodable`-conforming type as the parameters of a request. It also provides two builtin types conforming to the `ParameterEncoder` protocol: `URLFormEndcodedParameterEncoder` and `JSONParameterEncoder`.  

```swift
struct Login: Encodable {
    let email: String
    let password: String
}
let login = Login(email: "test@test.test", password: "testPassword")
AF.request("https://httpbin.org/post",
           method: .post,
           parameters: login,
           encoder: JSONParameterEncoder.default).response { (response) in
    debugPrint(response)
}
```

### Passing Parameters

Alamofire supports passing any `Encodable` type as the parameters of a request. These parameters are then passed through a type conforming to the `ParameterEncoder` protocol and added to the `URLRequest` which is then sent over the network. Alamofire includes two `ParameterEncoder` conforming types: `JSONParameterEncoder` and `URLEncodedFormParameterEncoder `. These types cover the most common encodings used by modern services (XML encoding is left as an exercise for the reader).

```swift
struct Login: Encodable {
    let email: String
    let password: String
}

let login = Login(email: "test@test.test", password: "testPassword")

AF.request("https://httpbin.org/post",
           method: .post,
           parameters: login,
           encoder: JSONParameterEncoder.default).response { (response) in
    debugPrint(response)
}
```

#### `URLEncodedFormParameterEncoder`

The `URLEncodedFormParameterEncoder` encodes values into a url-encoded string to be set as or appended to any existing URL query or set as the HTTP body of the request. Controlling where the encoded string is set can be done by setting the `destination` of the encoding. The `URLEncodedFormParameterEncoder.Destination` enumeration has three cases:

- `.methodDependent` - Applies the encoded query string result to existing query string for `.get`, `.head` and `.delete` requests and sets it as the HTTP body for requests with any other HTTP method.
- `.queryString` - Sets or appends the encoded string to the query of the request's `URL`.
- `.httpBody` - Sets the encoded string as the HTTP body of the `URLRequest`.

The `Content-Type` HTTP header of an encoded request with HTTP body is set to `application/x-www-form-urlencoded; charset=utf-8`, if `Content-Type` is not already set.

Internally, `URLEncodedFormParameterEncoder` uses `URLEncodedFormEncoder` to perform the actual encoding from an `Encodable` type to `String`. This encoder can be used to customize the encoding for various types, including `Bool` using the `BoolEncoding`, `Array` using the `ArrayEncoding`, spaces using the `SpaceEncoding`, and `Date` using the `DateEncoding`.

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

##### Configuring the Encoding of `Array` Parameters

Since there is no published specification for how to encode collection types, by default Alamofire follows the convention of appending `[]` to the key for array values (`foo[]=1&foo[]=2`), and appending the key surrounded by square brackets for nested dictionary values (`foo[bar]=baz`).

The `URLEncodedFormEncoder.ArrayEncoding` enumeration provides the following methods for encoding `Array` parameters:

- `.brackets` - An empty set of square brackets is appended to the key for every value.
- `.noBrackets` - No brackets are appended. The key is encoded as is.

By default, Alamofire uses the `.brackets` encoding, where `foo = [1, 2]` is encoded as `foo[]=1&foo[]=2`.

Using the `.noBrackets` encoding will encode `foo = [1, 2]` as `foo=1&foo=2`.

You can create your own `URLEncodedFormParameterEncoder` and specify the desired `ArrayEncoding` in the initializer of the passed `URLEncodedFormEncoder`:

```swift
let encoder = URLEncodedFormParameterEncoder(encoder: URLEncodedFormEncoder(arrayEncoding: .noBrackets))
```

##### Configuring the Encoding of `Bool` Parameters

The `URLEncodedFormEncoder.BoolEncoding` enumeration provides the following methods for encoding `Bool` parameters:

- `.numeric` - Encode `true` as `1` and `false` as `0`.
- `.literal` - Encode `true` and `false` as string literals.

By default, Alamofire uses the `.numeric` encoding.

You can create your own `URLEncodedFormParameterEncoder` and specify the desired `BoolEncoding` in the initializer of the passed `URLEncodedFormEncoder`:

```swift
let encoder = URLEncodedFormParameterEncoder(encoder: URLEncodedFormEncoder(boolEncoding: .numeric))
```

##### Configuring the Encoding of `Date` Parameters

Given the sheer number of ways to encode a `Date` into a `String`, `DateEncoding` includes the following methods for encoding `Date` parameters:

- `.deferredToDate` - Uses `Date`'s native `Encodable` support.
- `.secondsSince1970` - Encodes `Date`s as seconds since midnight UTC on January 1, 1970. 
- `.millisecondsSince1970` - Encodes `Date`s as milliseconds since midnight UTC on January 1, 1970.
- `.iso8601` - Encodes `Date`s according to the ISO 8601 and RFC3339 standards.
- `.formatted(DateFormatter)` - Encodes `Date`s using the given `DateFormatter`.
- `.custom((Date) throws -> String)` - Encodes `Date`s using the given closure.

You can create your own `URLEncodedFormParameterEncoder` and specify the desired `DateEncoding` in the initializer of the passed `URLEncodedFormEncoder`:

```swift
let encoder = URLEncodedFormParameterEncoder(encoder: URLEncodedFormEncoder(dateEncoding: .iso8601))
```

##### Configuring the Encoding of Spaces

Older form encoders used `+` to encoded spaces and some servers still expect this encoding instead of the modern percent encoding, so Alamofire includes the following methods for encoding spaces:

- `.percentEscaped` - Encodes space characters by applying standard percent escaping. `" "` is encoded as  `"%20"`.
- `.plusReplaced` - Encodes space character by replacing them with `+`. `" "` is encoded as `"+"`.

You can create your own `URLEncodedFormParameterEncoder` and specify the desired `SpaceEncoding` in the initializer of the passed `URLEncodedFormEncoder`:

```swift
let encoder = URLEncodedFormParameterEncoder(encoder: URLEncodedFormEncoder(spaceEncoding: .plusReplaced))
```

#### `JSONParameterEncoder`

`JSONParameterEncoder` encodes `Encodable` values using Swift's `JSONEncoder` and sets the result as the `httpBody` of the `URLRequest`. The `Content-Type` HTTP header field of an encoded request is set to `application/json`.

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
encoder.keyEncodingStrategy = `.convertToSnakeCase`
let parameterEncoder = JSONParameterEncoder(encoder: encoder)
```

#### Manual Parameter Encoding of a URLRequest

The `ParameterEncoder` APIs can be used outside of making network requests.

```swift
let url = URL(string: "https://httpbin.org/get")!
var urlRequest = URLRequest(url: url)

let parameters = ["foo": "bar"]
let encodedURLRequest = try URLEncodedFormParameterEncoder.default.encode(parameters, into: urlRequest)
```

### HTTP Headers

Adding a custom HTTP header to a `Request` is supported directly in the global `request` method. This makes it easy to attach HTTP headers to a `Request` that can be constantly changing.

```swift
let headers: HTTPHeaders = [
    "Authorization": "Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==",
    "Accept": "application/json"
]

Alamofire.request("https://httpbin.org/headers", headers: headers).responseJSON { response in
    debugPrint(response)
}
```

> For HTTP headers that do not change, it is recommended to set them on the `URLSessionConfiguration` so they are automatically applied to any `URLSessionTask` created by the underlying `URLSession`. For more information, see the [Session Manager Configurations](AdvancedUsage.md#session-manager) section.

The default Alamofire `SessionManager` provides a default set of headers for every `Request`. These include:

- `Accept-Encoding`, which defaults to `gzip;q=1.0, compress;q=0.5`, per [RFC 7230 §4.2.3](https://tools.ietf.org/html/rfc7230#section-4.2.3).
- `Accept-Language`, which defaults to up to the top 6 preferred languages on the system, formatted like `en;q=1.0`, per [RFC 7231 §5.3.5](https://tools.ietf.org/html/rfc7231#section-5.3.5).
- `User-Agent`, which contains versioning information about the current app. For example: `iOS Example/1.0 (com.alamofire.iOS-Example; build:1; iOS 10.0.0) Alamofire/4.0.0`, per [RFC 7231 §5.5.3](https://tools.ietf.org/html/rfc7231#section-5.5.3).

If you need to customize these headers, a custom `URLSessionConfiguration` should be created, the `defaultHTTPHeaders` property updated and the configuration applied to a new `SessionManager` instance.

### Response Handling

Handling the `Response` of a `Request` made in Alamofire involves chaining a response handler onto the `Request`.

```swift
Alamofire.request("https://httpbin.org/get").responseJSON { response in
    print("Request: \(String(describing: response.request))")   // original url request
    print("Response: \(String(describing: response.response))") // http url response
    print("Result: \(response.result)")                         // response serialization result

    if let json = response.result.value {
        print("JSON: \(json)") // serialized json response
    }

    if let data = response.data, let utf8Text = String(data: data, encoding: .utf8) {
        print("Data: \(utf8Text)") // original server data as UTF8 string
    }
}
```

In the above example, the `responseJSON` handler is appended to the `Request` to be executed once the `Request` is complete. Rather than blocking execution to wait for a response from the server, a [callback](https://en.wikipedia.org/wiki/Callback_%28computer_programming%29) in the form of a closure is specified to handle the response once it's received. The result of a request is only available inside the scope of a response closure. Any execution contingent on the response or data received from the server must be done within a response closure.

> Networking in Alamofire is done _asynchronously_. Asynchronous programming may be a source of frustration to programmers unfamiliar with the concept, but there are [very good reasons](https://developer.apple.com/library/ios/qa/qa1693/_index.html) for doing it this way.

Alamofire contains five different response handlers by default including:

```swift
// Response Handler - Unserialized Response
func response(
    queue: DispatchQueue?,
    completionHandler: @escaping (DefaultDataResponse) -> Void)
    -> Self

// Response Data Handler - Serialized into Data
func responseData(
    queue: DispatchQueue?,
    completionHandler: @escaping (DataResponse<Data>) -> Void)
    -> Self

// Response String Handler - Serialized into String
func responseString(
    queue: DispatchQueue?,
    encoding: String.Encoding?,
    completionHandler: @escaping (DataResponse<String>) -> Void)
    -> Self

// Response JSON Handler - Serialized into Any
func responseJSON(
    queue: DispatchQueue?,
    completionHandler: @escaping (DataResponse<Any>) -> Void)
    -> Self

// Response PropertyList (plist) Handler - Serialized into Any
func responsePropertyList(
    queue: DispatchQueue?,
    completionHandler: @escaping (DataResponse<Any>) -> Void))
    -> Self
```

None of the response handlers perform any validation of the `HTTPURLResponse` it gets back from the server.

> For example, response status codes in the `400..<500` and `500..<600` ranges do NOT automatically trigger an `Error`. Alamofire uses [Response Validation](#response-validation) method chaining to achieve this.

#### Response Handler

The `response` handler does NOT evaluate any of the response data. It merely forwards on all information directly from the URL session delegate. It is the Alamofire equivalent of using `cURL` to execute a `Request`.

```swift
Alamofire.request("https://httpbin.org/get").response { response in
    print("Request: \(response.request)")
    print("Response: \(response.response)")
    print("Error: \(response.error)")

    if let data = response.data, let utf8Text = String(data: data, encoding: .utf8) {
    	print("Data: \(utf8Text)")
    }
}
```

> We strongly encourage you to leverage the other response serializers taking advantage of `Response` and `AFResult` types.

#### Response Data Handler

The `responseData` handler uses the `responseDataSerializer` (the object that serializes the server data into some other type) to extract the `Data` returned by the server. If no errors occur and `Data` is returned, the response `AFResult` will be a `.success` and the `value` will be of type `Data`.

```swift
Alamofire.request("https://httpbin.org/get").responseData { response in
    debugPrint("All Response Info: \(response)")

    if let data = response.result.value, let utf8Text = String(data: data, encoding: .utf8) {
    	print("Data: \(utf8Text)")
    }
}
```

#### Response String Handler

The `responseString` handler uses the `responseStringSerializer` to convert the `Data` returned by the server into a `String` with the specified encoding. If no errors occur and the server data is successfully serialized into a `String`, the response `AFResult` will be a `.success` and the `value` will be of type `String`.

```swift
Alamofire.request("https://httpbin.org/get").responseString { response in
    print("Success: \(response.result.isSuccess)")
    print("Response String: \(response.result.value)")
}
```

> If no encoding is specified, Alamofire will use the text encoding specified in the `HTTPURLResponse` from the server. If the text encoding cannot be determined by the server response, it defaults to `.isoLatin1`.

#### Response JSON Handler

The `responseJSON` handler uses the `responseJSONSerializer` to convert the `Data` returned by the server into an `Any` type using the specified `JSONSerialization.ReadingOptions`. If no errors occur and the server data is successfully serialized into a JSON object, the response `AFResult` will be a `.success` and the `value` will be of type `Any`.

```swift
Alamofire.request("https://httpbin.org/get").responseJSON { response in
    debugPrint(response)

    if let json = response.result.value {
        print("JSON: \(json)")
    }
}
```

> All JSON serialization is handled by the `JSONSerialization` API in the `Foundation` framework.

#### Chained Response Handlers

Response handlers can even be chained:

```swift
Alamofire.request("https://httpbin.org/get")
    .responseString { response in
        print("Response String: \(response.result.value)")
    }
    .responseJSON { response in
        print("Response JSON: \(response.result.value)")
    }
```

> It is important to note that using multiple response handlers on the same `Request` requires the server data to be serialized multiple times. Once for each response handler.

#### Response Handler Queue

Response handlers by default are executed on the main dispatch queue. However, a custom dispatch queue can be provided instead.

```swift
let utilityQueue = DispatchQueue.global(qos: .utility)

Alamofire.request("https://httpbin.org/get").responseJSON(queue: utilityQueue) { response in
    print("Executing response handler on utility queue")
}
```

### Response Validation

By default, Alamofire treats any completed request to be successful, regardless of the content of the response. Calling `validate` before a response handler causes an error to be generated if the response had an unacceptable status code or MIME type.

#### Manual Validation

```swift
Alamofire.request("https://httpbin.org/get")
    .validate(statusCode: 200..<300)
    .validate(contentType: ["application/json"])
    .responseData { response in
        switch response.result {
        case .success:
            print("Validation Successful")
        case .failure(let error):
            print(error)
        }
    }
```

#### Automatic Validation

Automatically validates status code within `200..<300` range, and that the `Content-Type` header of the response matches the `Accept` header of the request, if one is provided.

```swift
Alamofire.request("https://httpbin.org/get").validate().responseJSON { response in
    switch response.result {
    case .success:
        print("Validation Successful")
    case .failure(let error):
        print(error)
    }
}
```

### Response Caching

Response Caching is handled on the system framework level by [`URLCache`](https://developer.apple.com/reference/foundation/urlcache). It provides a composite in-memory and on-disk cache and lets you manipulate the sizes of both the in-memory and on-disk portions.

> By default, Alamofire leverages the shared `URLCache`. In order to customize it, see the [Session Manager Configurations](AdvancedUsage.md#session-manager) section.



### Authentication

Authentication is handled on the system framework level by [`URLCredential`](https://developer.apple.com/reference/foundation/nsurlcredential) and [`URLAuthenticationChallenge`](https://developer.apple.com/reference/foundation/urlauthenticationchallenge).

**Supported Authentication Schemes**

- [HTTP Basic](https://en.wikipedia.org/wiki/Basic_access_authentication)
- [HTTP Digest](https://en.wikipedia.org/wiki/Digest_access_authentication)
- [Kerberos](https://en.wikipedia.org/wiki/Kerberos_%28protocol%29)
- [NTLM](https://en.wikipedia.org/wiki/NT_LAN_Manager)

#### HTTP Basic Authentication

The `authenticate` method on a `Request` will automatically provide a `URLCredential` to a `URLAuthenticationChallenge` when appropriate:

```swift
let user = "user"
let password = "password"

Alamofire.request("https://httpbin.org/basic-auth/\(user)/\(password)")
    .authenticate(user: user, password: password)
    .responseJSON { response in
        debugPrint(response)
    }
```

Depending upon your server implementation, an `Authorization` header may also be appropriate:

```swift
let user = "user"
let password = "password"

var headers: HTTPHeaders = [:]

if let authorizationHeader = Request.authorizationHeader(user: user, password: password) {
    headers[authorizationHeader.key] = authorizationHeader.value
}

Alamofire.request("https://httpbin.org/basic-auth/user/password", headers: headers)
    .responseJSON { response in
        debugPrint(response)
    }
```

#### Authentication with URLCredential

```swift
let user = "user"
let password = "password"

let credential = URLCredential(user: user, password: password, persistence: .forSession)

Alamofire.request("https://httpbin.org/basic-auth/\(user)/\(password)")
    .authenticate(usingCredential: credential)
    .responseJSON { response in
        debugPrint(response)
    }
```

> It is important to note that when using a `URLCredential` for authentication, the underlying `URLSession` will actually end up making two requests if a challenge is issued by the server. The first request will not include the credential which "may" trigger a challenge from the server. The challenge is then received by Alamofire, the credential is appended and the request is retried by the underlying `URLSession`.

### Downloading Data to a File

Requests made in Alamofire that fetch data from a server can download the data in-memory or on-disk. The `Alamofire.request` APIs used in all the examples so far always downloads the server data in-memory. This is great for smaller payloads because it's more efficient, but really bad for larger payloads because the download could run your entire application out-of-memory. Because of this, you can also use the `Alamofire.download` APIs to download the server data to a temporary file on-disk.

> This will only work on `macOS` as is. Other platforms don't allow access to the filesystem outside of your app's sandbox. To download files on other platforms, see the [Download File Destination](#download-file-destination) section.

```swift
Alamofire.download("https://httpbin.org/image/png").responseData { response in
    if let data = response.result.value {
        let image = UIImage(data: data)
    }
}
```

> The `Alamofire.download` APIs should also be used if you need to download data while your app is in the background. For more information, please see the [Session Manager Configurations](AdvancedUsage.md#session-manager) section.

#### Download File Destination

You can also provide a `DownloadFileDestination` closure to move the file from the temporary directory to a final destination. Before the temporary file is actually moved to the `destinationURL`, the `DownloadOptions` specified in the closure will be executed. The two currently supported `DownloadOptions` are:

- `.createIntermediateDirectories` - Creates intermediate directories for the destination URL if specified.
- `.removePreviousFile` - Removes a previous file from the destination URL if specified.

```swift
let destination: DownloadRequest.DownloadFileDestination = { _, _ in
    let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let fileURL = documentsURL.appendingPathComponent("pig.png")

    return (fileURL, [.removePreviousFile, .createIntermediateDirectories])
}

Alamofire.download(urlString, to: destination).response { response in
    print(response)

    if response.error == nil, let imagePath = response.destinationURL?.path {
        let image = UIImage(contentsOfFile: imagePath)
    }
}
```

You can also use the suggested download destination API.

```swift
let destination = DownloadRequest.suggestedDownloadDestination(for: .documentDirectory)
Alamofire.download("https://httpbin.org/image/png", to: destination)
```

#### Download Progress

Many times it can be helpful to report download progress to the user. Any `DownloadRequest` can report download progress using the `downloadProgress` API.

```swift
Alamofire.download("https://httpbin.org/image/png")
    .downloadProgress { progress in
        print("Download Progress: \(progress.fractionCompleted)")
    }
    .responseData { response in
        if let data = response.result.value {
            let image = UIImage(data: data)
        }
    }
```

The `downloadProgress` API also takes a `queue` parameter which defines which `DispatchQueue` the download progress closure should be called on.

```swift
let utilityQueue = DispatchQueue.global(qos: .utility)

Alamofire.download("https://httpbin.org/image/png")
    .downloadProgress(queue: utilityQueue) { progress in
        print("Download Progress: \(progress.fractionCompleted)")
    }
    .responseData { response in
        if let data = response.result.value {
            let image = UIImage(data: data)
        }
    }
```

#### Resuming a Download

If a `DownloadRequest` is cancelled or interrupted, the underlying URL session may generate resume data for the active `DownloadRequest`. If this happens, the resume data can be re-used to restart the `DownloadRequest` where it left off. The resume data can be accessed through the download response, then reused when trying to restart the request.

> **IMPORTANT:** On some versions of all Apple platforms (iOS 10 - 10.2, macOS 10.12 - 10.12.2, tvOS 10 - 10.1, watchOS 3 - 3.1.1), `resumeData` is broken on background URL session configurations. There's an underlying bug in the `resumeData` generation logic where the data is written incorrectly and will always fail to resume the download. For more information about the bug and possible workarounds, please see this [Stack Overflow post](https://stackoverflow.com/a/39347461/1342462).

```swift
class ImageRequestor {
    private var resumeData: Data?
    private var image: UIImage?

    func fetchImage(completion: (UIImage?) -> Void) {
        guard image == nil else { completion(image) ; return }

        let destination: DownloadRequest.DownloadFileDestination = { _, _ in
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documentsURL.appendingPathComponent("pig.png")

            return (fileURL, [.removePreviousFile, .createIntermediateDirectories])
        }

        let request: DownloadRequest

        if let resumeData = resumeData {
            request = Alamofire.download(resumingWith: resumeData)
        } else {
            request = Alamofire.download("https://httpbin.org/image/png")
        }

        request.responseData { response in
            switch response.result {
            case .success(let data):
                self.image = UIImage(data: data)
            case .failure:
                self.resumeData = response.resumeData
            }
        }
    }
}
```

### Uploading Data to a Server

When sending relatively small amounts of data to a server using JSON or URL encoded parameters, the `Alamofire.request` APIs are usually sufficient. If you need to send much larger amounts of data from a file URL or an `InputStream`, then the `Alamofire.upload` APIs are what you want to use.

> The `Alamofire.upload` APIs should also be used if you need to upload data while your app is in the background. For more information, please see the [Session Manager Configurations](AdvancedUsage.md#session-manager) section.

#### Uploading Data

```swift
let imageData = UIImagePNGRepresentation(image)!

Alamofire.upload(imageData, to: "https://httpbin.org/post").responseJSON { response in
    debugPrint(response)
}
```

#### Uploading a File

```swift
let fileURL = Bundle.main.url(forResource: "video", withExtension: "mov")

Alamofire.upload(fileURL, to: "https://httpbin.org/post").responseJSON { response in
    debugPrint(response)
}
```

#### Uploading Multipart Form Data

```swift
Alamofire.upload(
    multipartFormData: { multipartFormData in
        multipartFormData.append(unicornImageURL, withName: "unicorn")
        multipartFormData.append(rainbowImageURL, withName: "rainbow")
    },
    to: "https://httpbin.org/post",
    encodingCompletion: { encodingResult in
    	switch encodingResult {
    	case .success(let upload, _, _):
            upload.responseJSON { response in
                debugPrint(response)
            }
    	case .failure(let encodingError):
    	    print(encodingError)
    	}
    }
)
```

#### Upload Progress

While your user is waiting for their upload to complete, sometimes it can be handy to show the progress of the upload to the user. Any `UploadRequest` can report both upload progress and download progress of the response data using the `uploadProgress` and `downloadProgress` APIs.

```swift
let fileURL = Bundle.main.url(forResource: "video", withExtension: "mov")

Alamofire.upload(fileURL, to: "https://httpbin.org/post")
    .uploadProgress { progress in // main queue by default
        print("Upload Progress: \(progress.fractionCompleted)")
    }
    .downloadProgress { progress in // main queue by default
        print("Download Progress: \(progress.fractionCompleted)")
    }
    .responseJSON { response in
        debugPrint(response)
    }
```

### Statistical Metrics

#### Timeline

Alamofire collects timings throughout the lifecycle of a `Request` and creates a `Timeline` object exposed as a property on all response types.

```swift
Alamofire.request("https://httpbin.org/get").responseJSON { response in
    print(response.timeline)
}
```

The above reports the following `Timeline` info:

- `Latency`: 0.428 seconds
- `Request Duration`: 0.428 seconds
- `Serialization Duration`: 0.001 seconds
- `Total Duration`: 0.429 seconds

#### URL Session Task Metrics

In iOS and tvOS 10 and macOS 10.12, Apple introduced the new [URLSessionTaskMetrics](https://developer.apple.com/reference/foundation/urlsessiontaskmetrics) APIs. The task metrics encapsulate some fantastic statistical information about the request and response execution. The API is very similar to the `Timeline`, but provides many more statistics that Alamofire doesn't have access to compute. The metrics can be accessed through any response type.

```swift
Alamofire.request("https://httpbin.org/get").responseJSON { response in
    print(response.metrics)
}
```

It's important to note that these APIs are only available on iOS and tvOS 10 and macOS 10.12. Therefore, depending on your deployment target, you may need to use these inside availability checks:

```swift
Alamofire.request("https://httpbin.org/get").responseJSON { response in
    if #available(iOS 10.0, *) {
        print(response.metrics)
    }
}
```

### cURL Command Output

Debugging platform issues can be frustrating. Thankfully, Alamofire `Request` objects conform to both the `CustomStringConvertible` and `CustomDebugStringConvertible` protocols to provide some VERY helpful debugging tools.

#### CustomStringConvertible

```swift
let request = Alamofire.request("https://httpbin.org/ip")

print(request)
// GET https://httpbin.org/ip (200)
```

#### CustomDebugStringConvertible

```swift
let request = Alamofire.request("https://httpbin.org/get", parameters: ["foo": "bar"])
debugPrint(request)
```

Outputs:

```bash
$ curl -i \
    -H "User-Agent: Alamofire/4.0.0" \
    -H "Accept-Encoding: gzip;q=1.0, compress;q=0.5" \
    -H "Accept-Language: en;q=1.0,fr;q=0.9,de;q=0.8,zh-Hans;q=0.7,zh-Hant;q=0.6,ja;q=0.5" \
    "https://httpbin.org/get?foo=bar"
```

---