![Alamofire: Elegant Networking in Swift](https://raw.githubusercontent.com/Alamofire/Alamofire/assets/alamofire.png)

[![Build Status](https://travis-ci.org/Alamofire/Alamofire.svg?branch=master)](https://travis-ci.org/Alamofire/Alamofire)
[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/Alamofire.svg)](https://img.shields.io/cocoapods/v/Alamofire.svg)
[![Carthage Compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Platform](https://img.shields.io/cocoapods/p/Alamofire.svg?style=flat)](http://cocoadocs.org/docsets/Alamofire)
[![Twitter](https://img.shields.io/badge/twitter-@AlamofireSF-blue.svg?style=flat)](http://twitter.com/AlamofireSF)

Alamofire is an HTTP networking library written in Swift.

- [Features](#features)
- [Component Libraries](#component-libraries)
- [Requirements](#requirements)
- [Migration Guides](#migration-guides)
- [Communication](#communication)
- [Installation](#installation)
- [Usage](#usage)
    - **Intro -** [Making a Request](#making-a-request), [Response Handling](#response-handling), [Response Validation](#response-validation), [Response Caching](#response-caching)
	- **HTTP -** [HTTP Methods](#http-methods), [Parameter Encoding](#parameter-encoding), [HTTP Headers](#http-headers), [Authentication](#authentication)
	- **Large Data -** [Downloading Data to a File](#downloading-data-to-a-file), [Uploading Data to a Server](#uploading-data-to-a-server)
	- **Tools -** [Statistical Metrics](#statistical-metrics), [cURL Command Output](#curl-command-output)
- [Advanced Usage](#advanced-usage)
	- **URL Session -** [Session Manager](#session-manager), [Session Delegate](#session-delegate), [Request](#request)
	- **Routing -** [Routing Requests](#routing-requests), [Adapting and Retrying Requests](#adapting-and-retrying-requests)
	- **Model Objects -** [Custom Response Serialization](#custom-response-serialization)
	- **Connection -** [Security](#security), [Network Reachability](#network-reachability)
- [Open Radars](#open-radars)
- [FAQ](#faq)
- [Credits](#credits)
- [Donations](#donations)
- [License](#license)

## Features

- [x] Chainable Request / Response Methods
- [x] URL / JSON / plist Parameter Encoding
- [x] Upload File / Data / Stream / MultipartFormData
- [x] Download File using Request or Resume Data
- [x] Authentication with URLCredential
- [x] HTTP Response Validation
- [x] Upload and Download Progress Closures with Progress
- [x] cURL Command Output
- [x] Dynamically Adapt and Retry Requests
- [x] TLS Certificate and Public Key Pinning
- [x] Network Reachability
- [x] Comprehensive Unit and Integration Test Coverage
- [x] [Complete Documentation](http://cocoadocs.org/docsets/Alamofire)

## Component Libraries

In order to keep Alamofire focused specifically on core networking implementations, additional component libraries have been created by the [Alamofire Software Foundation](https://github.com/Alamofire/Foundation) to bring additional functionality to the Alamofire ecosystem.

- [AlamofireImage](https://github.com/Alamofire/AlamofireImage) - An image library including image response serializers, `UIImage` and `UIImageView` extensions, custom image filters, an auto-purging in-memory cache and a priority-based image downloading system.
- [AlamofireNetworkActivityIndicator](https://github.com/Alamofire/AlamofireNetworkActivityIndicator) - Controls the visibility of the network activity indicator on iOS using Alamofire. It contains configurable delay timers to help mitigate flicker and can support `URLSession` instances not managed by Alamofire.

## Requirements

- iOS 9.0+ / macOS 10.11+ / tvOS 9.0+ / watchOS 2.0+
- Xcode 8.0+
- Swift 3.0+

## Migration Guides

- [Alamofire 4.0 Migration Guide](https://github.com/Alamofire/Alamofire/blob/master/Documentation/Alamofire%204.0%20Migration%20Guide.md)
- [Alamofire 3.0 Migration Guide](https://github.com/Alamofire/Alamofire/blob/master/Documentation/Alamofire%203.0%20Migration%20Guide.md)
- [Alamofire 2.0 Migration Guide](https://github.com/Alamofire/Alamofire/blob/master/Documentation/Alamofire%202.0%20Migration%20Guide.md)

## Communication

- If you **need help**, use [Stack Overflow](http://stackoverflow.com/questions/tagged/alamofire). (Tag 'alamofire')
- If you'd like to **ask a general question**, use [Stack Overflow](http://stackoverflow.com/questions/tagged/alamofire).
- If you **found a bug**, open an issue.
- If you **have a feature request**, open an issue.
- If you **want to contribute**, submit a pull request.

## Installation

### CocoaPods

[CocoaPods](http://cocoapods.org) is a dependency manager for Cocoa projects. You can install it with the following command:

```bash
$ gem install cocoapods
```

> CocoaPods 1.1.0+ is required to build Alamofire 4.0.0+.

To integrate Alamofire into your Xcode project using CocoaPods, specify it in your `Podfile`:

```ruby
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '10.0'
use_frameworks!

target '<Your Target Name>' do
    pod 'Alamofire', '~> 4.0'
end
```

Then, run the following command:

```bash
$ pod install
```

### Carthage

[Carthage](https://github.com/Carthage/Carthage) is a decentralized dependency manager that builds your dependencies and provides you with binary frameworks.

You can install Carthage with [Homebrew](http://brew.sh/) using the following command:

```bash
$ brew update
$ brew install carthage
```

To integrate Alamofire into your Xcode project using Carthage, specify it in your `Cartfile`:

```ogdl
github "Alamofire/Alamofire" ~> 4.0
```

Run `carthage update` to build the framework and drag the built `Alamofire.framework` into your Xcode project.

### Manually

If you prefer not to use either of the aforementioned dependency managers, you can integrate Alamofire into your project manually.

#### Embedded Framework

- Open up Terminal, `cd` into your top-level project directory, and run the following command "if" your project is not initialized as a git repository:

```bash
$ git init
```

- Add Alamofire as a git [submodule](http://git-scm.com/docs/git-submodule) by running the following command:

```bash
$ git submodule add https://github.com/Alamofire/Alamofire.git
```

- Open the new `Alamofire` folder, and drag the `Alamofire.xcodeproj` into the Project Navigator of your application's Xcode project.

    > It should appear nested underneath your application's blue project icon. Whether it is above or below all the other Xcode groups does not matter.

- Select the `Alamofire.xcodeproj` in the Project Navigator and verify the deployment target matches that of your application target.
- Next, select your application project in the Project Navigator (blue project icon) to navigate to the target configuration window and select the application target under the "Targets" heading in the sidebar.
- In the tab bar at the top of that window, open the "General" panel.
- Click on the `+` button under the "Embedded Binaries" section.
- You will see two different `Alamofire.xcodeproj` folders each with two different versions of the `Alamofire.framework` nested inside a `Products` folder.

    > It does not matter which `Products` folder you choose from, but it does matter whether you choose the top or bottom `Alamofire.framework`.

- Select the top `Alamofire.framework` for iOS and the bottom one for OS X.

    > You can verify which one you selected by inspecting the build log for your project. The build target for `Alamofire` will be listed as either `Alamofire iOS`, `Alamofire macOS`, `Alamofire tvOS` or `Alamofire watchOS`.

- And that's it!

> The `Alamofire.framework` is automagically added as a target dependency, linked framework and embedded framework in a copy files build phase which is all you need to build on the simulator and a device.

---

## Usage

### Making a Request

```swift
import Alamofire

Alamofire.request("https://httpbin.org/get")
```

### Response Handling

Handling the `Response` of a `Request` made in Alamofire involves chaining a response handler onto the `Request`.

```swift
Alamofire.request("https://httpbin.org/get").responseJSON { response in
    print(response.request)  // original URL request
    print(response.response) // HTTP URL response
    print(response.data)     // server data
    print(response.result)   // result of response serialization

    if let JSON = response.result.value {
        print("JSON: \(JSON)")
    }
}
```

In the above example, the `responseJSON` handler is appended to the `Request` to be executed once the `Request` is complete. Rather than blocking execution to wait for a response from the server, a [callback](http://en.wikipedia.org/wiki/Callback_%28computer_programming%29) in the form of a closure is specified to handle the response once it's received. The result of a request is only available inside the scope of a response closure. Any execution contingent on the response or data received from the server must be done within a response closure.

> Networking in Alamofire is done _asynchronously_. Asynchronous programming may be a source of frustration to programmers unfamiliar with the concept, but there are [very good reasons](https://developer.apple.com/library/ios/qa/qa1693/_index.html) for doing it this way.

Alamofire contains five different response handlers by default including:

```swift
// Response Handler - Unserialized Response
func response(
    queue: DispatchQueue?,
    completionHandler: @escaping (DefaultDownloadResponse) -> Void)
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

> For example, response status codes in the `400..<499` and `500..<599` ranges do NOT automatically trigger an `Error`. Alamofire uses [Response Validation](#response-validation) method chaining to achieve this.

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

> We strongly encourage you to leverage the other response serializers taking advantage of `Response` and `Result` types.

#### Response Data Handler

The `responseData` handler uses the `responseDataSerializer` (the object that serializes the server data into some other type) to extract the `Data` returned by the server. If no errors occur and `Data` is returned, the response `Result` will be a `.success` and the `value` will be of type `Data`.

```swift
Alamofire.request("https://httpbin.org/get").responseData { response in
    debugPrint("All Response Info: \(response)")

    if let data = response.result.value, let utf8Text = String(data: data, encoding: .utf8) {
    	print("Data: \(utf8Text)")
    }
}
```

#### Response String Handler

The `responseString` handler uses the `responseStringSerializer` to convert the `Data` returned by the server into a `String` with the specified encoding. If no errors occur and the server data is successfully serialized into a `String`, the response `Result` will be a `.success` and the `value` will be of type `String`.

```swift
Alamofire.request("https://httpbin.org/get").responseString { response in
    print("Success: \(response.result.isSuccess)")
    print("Response String: \(response.result.value)")
}
```

> If no encoding is specified, Alamofire will use the text encoding specified in the `HTTPURLResponse` from the server. If the text encoding cannot be determined by the server response, it defaults to `.isoLatin1`.

#### Response JSON Handler

The `responseJSON` handler uses the `responseJSONSerializer` to convert the `Data` returned by the server into an `Any` type using the specified `JSONSerialization.ReadingOptions`. If no errors occur and the server data is successfully serialized into a JSON object, the response `Result` will be a `.success` and the `value` will be of type `Any`.

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

Automatically validates status code within `200...299` range, and that the `Content-Type` header of the response matches the `Accept` header of the request, if one is provided.

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

> By default, Alamofire leverages the shared `URLCache`. In order to customize it, see the [Session Manager Configurations](#session-manager) section.

### HTTP Methods

The `HTTPMethod` enumeration lists the HTTP methods defined in [RFC 7231 §4.3](http://tools.ietf.org/html/rfc7231#section-4.3):

```swift
public enum HTTPMethod: String {
    case options = "OPTIONS"
    case get     = "GET"
    case head    = "HEAD"
    case post    = "POST"
    case put     = "PUT"
    case patch   = "PATCH"
    case delete  = "DELETE"
    case trace   = "TRACE"
    case connect = "CONNECT"
}
```

These values can be passed as the `method` argument to the `Alamofire.request` API:

```swift
Alamofire.request("https://httpbin.org/get") // method defaults to `.get`

Alamofire.request("https://httpbin.org/post", method: .post)
Alamofire.request("https://httpbin.org/put", method: .put)
Alamofire.request("https://httpbin.org/delete", method: .delete)
```

> The `Alamofire.request` method parameter defaults to `.get`.

### Parameter Encoding

Alamofire supports three types of parameter encoding including: `URL`, `JSON` and `PropertyList`. It can also support any custom encoding that conforms to the `ParameterEncoding` protocol.

#### URL Encoding

The `URLEncoding` type creates a url-encoded query string to be set as or appended to any existing URL query string or set as the HTTP body of the URL request. Whether the query string is set or appended to any existing URL query string or set as the HTTP body depends on the `Destination` of the encoding. The `Destination` enumeration has three cases:

- `.methodDependent` - Applies encoded query string result to existing query string for `GET`, `HEAD` and `DELETE` requests and sets as the HTTP body for requests with any other HTTP method.
- `.queryString` - Sets or appends encoded query string result to existing query string.
- `.httpBody` - Sets encoded query string result as the HTTP body of the URL request.

The `Content-Type` HTTP header field of an encoded request with HTTP body is set to `application/x-www-form-urlencoded; charset=utf-8`. Since there is no published specification for how to encode collection types, the convention of appending `[]` to the key for array values (`foo[]=1&foo[]=2`), and appending the key surrounded by square brackets for nested dictionary values (`foo[bar]=baz`).

##### GET Request With URL-Encoded Parameters

```swift
let parameters: Parameters = ["foo": "bar"]

// All three of these calls are equivalent
Alamofire.request("https://httpbin.org/get", parameters: parameters) // encoding defaults to `URLEncoding.default`
Alamofire.request("https://httpbin.org/get", parameters: parameters, encoding: URLEncoding.default)
Alamofire.request("https://httpbin.org/get", parameters: parameters, encoding: URLEncoding(destination: .methodDependent))

// https://httpbin.org/get?foo=bar
```

##### POST Request With URL-Encoded Parameters

```swift
let parameters: Parameters = [
    "foo": "bar",
    "baz": ["a", 1],
    "qux": [
        "x": 1,
        "y": 2,
        "z": 3
    ]
]

// All three of these calls are equivalent
Alamofire.request("https://httpbin.org/post", parameters: parameters)
Alamofire.request("https://httpbin.org/post", parameters: parameters, encoding: URLEncoding.default)
Alamofire.request("https://httpbin.org/post", parameters: parameters, encoding: URLEncoding.httpBody)

// HTTP body: foo=bar&baz[]=a&baz[]=1&qux[x]=1&qux[y]=2&qux[z]=3
```

#### JSON Encoding

The `JSONEncoding` type creates a JSON representation of the parameters object, which is set as the HTTP body of the request. The `Content-Type` HTTP header field of an encoded request is set to `application/json`.

##### POST Request with JSON-Encoded Parameters

```swift
let parameters: Parameters = [
    "foo": [1,2,3],
    "bar": [
        "baz": "qux"
    ]
]

// Both calls are equivalent
Alamofire.request("https://httpbin.org/post", method: .post, parameters: parameters, encoding: JSONEncoding.default)
Alamofire.request("https://httpbin.org/post", method: .post, parameters: parameters, encoding: JSONEncoding(options: []))

// HTTP body: {"foo": [1, 2, 3], "bar": {"baz": "qux"}}
```

#### Property List Encoding

The `PropertyListEncoding` uses `PropertyListSerialization` to create a plist representation of the parameters object, according to the associated format and write options values, which is set as the body of the request. The `Content-Type` HTTP header field of an encoded request is set to `application/x-plist`.

#### Custom Encoding

In the event that the provided `ParameterEncoding` types do not meet your needs, you can create your own custom encoding. Here's a quick example of how you could build a custom `JSONStringArrayEncoding` type to encode a JSON string array onto a `Request`.

```swift
struct JSONStringArrayEncoding: ParameterEncoding {
	private let array: [String]

    init(array: [String]) {
        self.array = array
    }

    func encode(_ urlRequest: URLRequestConvertible, with parameters: Parameters?) throws -> URLRequest {
        var urlRequest = urlRequest.urlRequest

        let data = try JSONSerialization.data(withJSONObject: array, options: [])

        if urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        urlRequest.httpBody = data

        return urlRequest
    }
}
```

#### Manual Parameter Encoding of a URLRequest

The `ParameterEncoding` APIs can be used outside of making network requests.

```swift
let url = URL(string: "https://httpbin.org/get")!
var urlRequest = URLRequest(url: url)

let parameters: Parameters = ["foo": "bar"]
let encodedURLRequest = try URLEncoding.queryString.encode(urlRequest, with: parameters)
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

> For HTTP headers that do not change, it is recommended to set them on the `URLSessionConfiguration` so they are automatically applied to any `URLSessionTask` created by the underlying `URLSession`. For more information, see the [Session Manager Configurations](#session-manager) section.

The default Alamofire `SessionManager` provides a default set of headers for every `Request`. These include:

- `Accept-Encoding`, which defaults to `gzip;q=1.0, compress;q=0.5`, per [RFC 7230 §4.2.3](https://tools.ietf.org/html/rfc7230#section-4.2.3).
- `Accept-Language`, which defaults to up to the top 6 preferred languages on the system, formatted like `en;q=1.0`, per [RFC 7231 §5.3.5](https://tools.ietf.org/html/rfc7231#section-5.3.5).
- `User-Agent`, which contains versioning information about the current app. For example: `iOS Example/1.0 (com.alamofire.iOS-Example; build:1; iOS 10.0.0) Alamofire/4.0.0`, per [RFC 7231 §5.5.3](https://tools.ietf.org/html/rfc7231#section-5.5.3).

If you need to customize these headers, a custom `URLSessionManagerConfiguration` should be created, the `defaultHTTPHeaders` property updated and the configuration applied to a new `SessionManager` instance.

### Authentication

Authentication is handled on the system framework level by [`URLCredential`](https://developer.apple.com/reference/foundation/nsurlcredential) and [`URLAuthenticationChallenge`](https://developer.apple.com/reference/foundation/urlauthenticationchallenge).

**Supported Authentication Schemes**

- [HTTP Basic](http://en.wikipedia.org/wiki/Basic_access_authentication)
- [HTTP Digest](http://en.wikipedia.org/wiki/Digest_access_authentication)
- [Kerberos](http://en.wikipedia.org/wiki/Kerberos_%28protocol%29)
- [NTLM](http://en.wikipedia.org/wiki/NT_LAN_Manager)

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

```swift
Alamofire.download("https://httpbin.org/image/png").responseData { response in
	if let data = response.result.value {
	    let image = UIImage(data: data)
	}
}
```

> The `Alamofire.download` APIs should also be used if you need to download data while your app is in the background. For more information, please see the [Session Manager Configurations](#session-manager) section.

#### Download File Destination

You can also provide a `DownloadFileDestination` closure to move the file from the temporary directory to a final destination. Before the temporary file is actually moved to the `destinationURL`, the `DownloadOptions` specified in the closure will be executed. The two currently supported `DownloadOptions` are:

- `.createIntermediateDirectories` - Creates intermediate directories for the destination URL if specified.
- `.removePreviousFile` - Removes a previous file from the destination URL if specified.

```swift
let destination: DownloadRequest.DownloadFileDestination = { _, _ in
	let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
	let fileURL = documentsURL.appendPathComponent("pig.png")

    return (fileURL, [.removePreviousFile, .createIntermediateDirectories])
}

Alamofire.download(urlString, to: destination).response { response in
    print(response)

	if response.result.isSuccess, let imagePath = response.destinationURL?.path {
	    let image = UIImage(contentsOfFile: imagePath)
	}
}
```

You can also use the suggested download destination API.

```swift
let destination = DownloadRequest.suggestedDownloadDestination(directory: .documentDirectory)
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

> **IMPORTANT:** On the latest release of all the Apple platforms (iOS 10, macOS 10.12, tvOS 10, watchOS 3), `resumeData` is broken on background URL session configurations. There's an underlying bug in the `resumeData` generation logic where the data is written incorrectly and will always fail to resume the download. For more information about the bug and possible workarounds, please see this Stack Overflow [post](http://stackoverflow.com/a/39347461/1342462).

```swift
class ImageRequestor {
	private var resumeData: Data?
	private var image: UIImage?

    func fetchImage(completion: (UIImage?) -> Void) {
    	guard image == nil else { completion(image) ; return }

		let destination: DownloadRequest.DownloadFileDestination = { _, _ in
			let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
			let fileURL = documentsURL.appendPathComponent("pig.png")

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

> The `Alamofire.upload` APIs should also be used if you need to upload data while your app is in the background. For more information, please see the [Session Manager Configurations](#session-manager) section.

#### Uploading Data

```swift
let imageData = UIPNGRepresentation(image)!

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
    if #available(iOS 10.0. *) {
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

## Advanced Usage

Alamofire is built on `URLSession` and the Foundation URL Loading System. To make the most of this framework, it is recommended that you be familiar with the concepts and capabilities of the underlying networking stack.

**Recommended Reading**

- [URL Loading System Programming Guide](https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/URLLoadingSystem/URLLoadingSystem.html)
- [URLSession Class Reference](https://developer.apple.com/reference/foundation/nsurlsession)
- [URLCache Class Reference](https://developer.apple.com/reference/foundation/urlcache)
- [URLAuthenticationChallenge Class Reference](https://developer.apple.com/reference/foundation/urlauthenticationchallenge)

### Session Manager

Top-level convenience methods like `Alamofire.request` use a default instance of `Alamofire.SessionManager`, which is configured with the default `URLSessionConfiguration`.

As such, the following two statements are equivalent:

```swift
Alamofire.request("https://httpbin.org/get")
```

```swift
let sessionManager = Alamofire.SessionManager.default
sessionManager.request("https://httpbin.org/get")
```

Applications can create session managers for background and ephemeral sessions, as well as new managers that customize the default session configuration, such as for default headers (`httpAdditionalHeaders`) or timeout interval (`timeoutIntervalForRequest`).

#### Creating a Session Manager with Default Configuration

```swift
let configuration = URLSessionConfiguration.default
let sessionManager = Alamofire.SessionManager(configuration: configuration)
```

#### Creating a Session Manager with Background Configuration

```swift
let configuration = URLSessionConfiguration.background(withIdentifier: "com.example.app.background")
let sessionManager = Alamofire.SessionManager(configuration: configuration)
```

#### Creating a Session Manager with Ephemeral Configuration

```swift
let configuration = URLSessionConfiguration.ephemeral
let sessionManager = Alamofire.SessionManager(configuration: configuration)
```

#### Modifying the Session Configuration

```swift
var defaultHeaders = Alamofire.SessionManager.default.defaultHTTPHeaders
defaultHeaders["DNT"] = "1 (Do Not Track Enabled)"

let configuration = URLSessionConfiguration.default
configuration.httpAdditionalHeaders = defaultHeaders

let sessionManager = Alamofire.SessionManager(configuration: configuration)
```

> This is **not** recommended for `Authorization` or `Content-Type` headers. Instead, use the `headers` parameter in the top-level `Alamofire.request` APIs, `URLRequestConvertible` and `ParameterEncoding`, respectively.

### Session Delegate

By default, an Alamofire `SessionManager` instance creates a `SessionDelegate` object to handle all the various types of delegate callbacks that are generated by the underlying `URLSession`. The implementations of each delegate method handle the most common use cases for these types of calls abstracting the complexity away from the top-level APIs. However, advanced users may find the need to override the default functionality for various reasons.

#### Override Closures

The first way to customize the `SessionDelegate` behavior is through the use of the override closures. Each closure gives you the ability to override the implementation of the matching `SessionDelegate` API, yet still use the default implementation for all other APIs. This makes it easy to customize subsets of the delegate functionality. Here are a few examples of some of the override closures available:

```swift
/// Overrides default behavior for URLSessionDelegate method `urlSession(_:didReceive:completionHandler:)`.
open var sessionDidReceiveChallenge: ((URLSession, URLAuthenticationChallenge) -> (URLSession.AuthChallengeDisposition, URLCredential?))?

/// Overrides default behavior for URLSessionDelegate method `urlSessionDidFinishEvents(forBackgroundURLSession:)`.
open var sessionDidFinishEventsForBackgroundURLSession: ((URLSession) -> Void)?

/// Overrides default behavior for URLSessionTaskDelegate method `urlSession(_:task:willPerformHTTPRedirection:newRequest:completionHandler:)`.
open var taskWillPerformHTTPRedirection: ((URLSession, URLSessionTask, HTTPURLResponse, URLRequest) -> URLRequest?)?

/// Overrides default behavior for URLSessionDataDelegate method `urlSession(_:dataTask:willCacheResponse:completionHandler:)`.
open var dataTaskWillCacheResponse: ((URLSession, URLSessionDataTask, CachedURLResponse) -> CachedURLResponse?)?
```

The following is a short example of how to use the `taskWillPerformHTTPRedirection` to avoid following redirects to any `apple.com` domains.

```swift
let sessionManager = Alamofire.SessionManager(configuration: URLSessionConfiguration.default)
let delegate: Alamofire.SessionDelegate = sessionManager.delegate

delegate.taskWillPerformHTTPRedirection = { session, task, response, request in
    var finalRequest = request

    if
        let originalRequest = task.originalRequest,
        let urlString = originalRequest.url?.urlString,
        urlString.contains("apple.com")
    {
        finalRequest = originalRequest
    }

    return finalRequest
}
```

#### Subclassing

Another way to override the default implementation of the `SessionDelegate` is to subclass it. Subclassing allows you completely customize the behavior of the API or to create a proxy for the API and still use the default implementation. Creating a proxy allows you to log events, emit notifications, provide pre and post hook implementations, etc. Here's a quick example of subclassing the `SessionDelegate` and logging a message when a redirect occurs.

```swift
class LoggingSessionDelegate: SessionDelegate {
    override func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void)
    {
        print("URLSession will perform HTTP redirection to request: \(request)")

        super.urlSession(
            session,
            task: task,
            willPerformHTTPRedirection: response,
            newRequest: request,
            completionHandler: completionHandler
        )
    }
}
```

Generally speaking, either the default implementation or the override closures should provide the necessary functionality required. Subclassing should only be used as a last resort.

> It is important to keep in mind that the `subdelegates` are initialized and destroyed in the default implementation. Be careful when subclassing to not introduce memory leaks.

### Request

The result of a `request`, `download`, `upload` or `stream` methods are a `DataRequest`, `DownloadRequest`, `UploadRequest` and `StreamRequest` which all inherit from `Request`. All `Request` instances are always created by an owning session manager, and never initialized directly.

Each subclass has specialized methods such as `authenticate`, `validate`, `responseJSON` and `uploadProgress` that each return the caller instance in order to facilitate method chaining.

Requests can be suspended, resumed and cancelled:

- `suspend()`: Suspends the underlying task and dispatch queue.
- `resume()`: Resumes the underlying task and dispatch queue. If the owning manager does not have `startRequestsImmediately` set to `true`, the request must call `resume()` in order to start.
- `cancel()`: Cancels the underlying task, producing an error that is passed to any registered response handlers.

### Routing Requests

As apps grow in size, it's important to adopt common patterns as you build out your network stack. An important part of that design is how to route your requests. The Alamofire `URLConvertible` and `URLRequestConvertible` protocols along with the `Router` design pattern are here to help.

#### URLConvertible

Types adopting the `URLConvertible` protocol can be used to construct URLs, which are then used to construct URL requests internally. `String`, `URL`, and `URLComponents` conform to `URLConvertible` by default, allowing any of them to be passed as `url` parameters to the `request`, `upload`, and `download` methods:

```swift
let urlString = "https://httpbin.org/post"
Alamofire.request(urlString, method: .post)

let url = URL(string: urlString)!
Alamofire.request(url, method: .post)

let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)
Alamofire.request(.post, URLComponents)
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

#### URLRequestConvertible

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
Alamofire.request(Router.search(query: "foo bar", page: 1)) // ?q=foo%20bar&offset=50
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
Alamofire.request(Router.readUser("mattt")) // GET /users/mattt
```

### Adapting and Retrying Requests

Most web services these days are behind some sort of authentication system. One of the more common ones today is OAuth. This generally involves generating an access token authorizing your application or user to call the various supported web services. While creating these initial access tokens can be laborsome, it can be even more complicated when your access token expires and you need to fetch a new one. There are many thread-safety issues that need to be considered.

The `RequestAdapter` and `RequestRetrier` protocols were created to make it much easier to create a thread-safe authentication system for a specific set of web services.

#### RequestAdapter

The `RequestAdapter` protocol allows each `Request` made on a `SessionManager` to be inspected and adapted before being created. One very specific way to use an adapter is to append an `Authorization` header to requests behind a certain type of authentication.

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
```

```swift
let sessionManager = SessionManager()
sessionManager.adapter = AccessTokenAdapter(accessToken: "1234")

sessionManager.request("https://httpbin.org/get")
```

#### RequestRetrier

The `RequestRetrier` protocol allows a `Request` that encountered an `Error` while being executed to be retried. When using both the `RequestAdapter` and `RequestRetrier` protocols together, you can create credential refresh systems for OAuth1, OAuth2, Basic Auth and even exponential backoff retry policies. The possibilities are endless. Here's an example of how you could implement a refresh flow for OAuth2 access tokens.

> **DISCLAIMER:** This is **NOT** a global `OAuth2` solution. It is merely an example demonstrating how one could use the `RequestAdapter` in conjunction with the `RequestRetrier` to create a thread-safe refresh system.

> To reiterate, **do NOT copy** this sample code and drop it into a production application. This is merely an example. Each authentication system must be tailored to a particular platform and authentication type.

```swift
class OAuth2Handler: RequestAdapter, RequestRetrier {
    private typealias RefreshCompletion = (_ succeeded: Bool, _ accessToken: String?, _ refreshToken: String?) -> Void

    private let sessionManager: SessionManager = {
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = SessionManager.defaultHTTPHeaders

        return SessionManager(configuration: configuration)
    }()

    private let lock = NSLock()

    private var clientID: String
    private var baseURLString: String
    private var accessToken: String
    private var refreshToken: String

    private var isRefreshing = false
    private var requestsToRetry: [RequestRetryCompletion] = []

    // MARK: - Initialization

    public init(clientID: String, baseURLString: String, accessToken: String, refreshToken: String) {
        self.clientID = clientID
        self.baseURLString = baseURLString
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }

    // MARK: - RequestAdapter

    func adapt(_ urlRequest: URLRequest) throws -> URLRequest {
        if let url = urlRequest.url, url.urlString.hasPrefix(baseURLString) {
            var urlRequest = urlRequest
            urlRequest.setValue("Bearer " + accessToken, forHTTPHeaderField: "Authorization")
            return urlRequest
        }

        return urlRequest
    }

    // MARK: - RequestRetrier

    func should(_ manager: SessionManager, retry request: Request, with error: Error, completion: @escaping RequestRetryCompletion) {
        lock.lock() ; defer { lock.unlock() }

        if let response = request.task.response as? HTTPURLResponse, response.statusCode == 401 {
            requestsToRetry.append(completion)

            if !isRefreshing {
                refreshTokens { [weak self] succeeded, accessToken, refreshToken in
                    guard let strongSelf = self else { return }

                    strongSelf.lock.lock() ; defer { strongSelf.lock.unlock() }

                    if let accessToken = accessToken, let refreshToken = refreshToken {
                        strongSelf.accessToken = accessToken
                        strongSelf.refreshToken = refreshToken
                    }

                    strongSelf.requestsToRetry.forEach { $0(succeeded, 0.0) }
                    strongSelf.requestsToRetry.removeAll()
                }
            }
        } else {
            completion(false, 0.0)
        }
    }

    // MARK: - Private - Refresh Tokens

    private func refreshTokens(completion: @escaping RefreshCompletion) {
        guard !isRefreshing else { return }

        isRefreshing = true

        let urlString = "\(baseURLString)/oauth2/token"

        let parameters: [String: Any] = [
            "access_token": accessToken,
            "refresh_token": refreshToken,
            "client_id": clientID,
            "grant_type": "refresh_token"
        ]

        sessionManager.request(urlString, method: .post, parameters: parameters, encoding: JSONEncoding.default)
            .responseJSON { [weak self] response in
                guard let strongSelf = self else { return }

                if let json = response.result.value as? [String: String] {
                    completion(true, json["access_token"], json["refresh_token"])
                } else {
                    completion(false, nil, nil)
                }

                strongSelf.isRefreshing = false
            }
    }
}
```

```swift
let baseURLString = "https://some.domain-behind-oauth2.com"

let oauthHandler = OAuth2Handler(
    clientID: "12345678",
    baseURLString: baseURLString,
    accessToken: "abcd1234",
    refreshToken: "ef56789a"
)

let sessionManager = SessionManager()
sessionManager.adapter = oauthHandler
sessionManager.retrier = oauthHandler

let urlString = "\(baseURLString)/some/endpoint"

sessionManager.request(urlString).validate().responseJSON { response in
    debugPrint(response)
}
```

Once the `OAuth2Handler` is applied as both the `adapter` and `retrier` for the `SessionManager`, it will handle an invalid access token error by automatically refreshing the access token and retrying all failed requests in the same order they failed.

> If you needed them to execute in the same order they were created, you could sort them by their task identifiers.

The example above only checks for a `401` response code which is not nearly robust enough, but does demonstrate how one could check for an invalid access token error. In a production application, one would want to check the `realm` and most likely the `www-authenticate` header response although it depends on the OAuth2 implementation.

Another important note is that this authentication system could be shared between multiple session managers. For example, you may need to use both a `default` and `ephemeral` session configuration for the same set of web services. The example above allows the same `oauthHandler` instance to be shared across multiple session managers to manage the single refresh flow.

### Custom Response Serialization

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

#### Generic Response Object Serialization

Generics can be used to provide automatic, type-safe response object serialization.

```swift
protocol ResponseObjectSerializable {
    init?(response: HTTPURLResponse, representation: Any)
}

extension DataRequest {
    func responseObject<T: ResponseObjectSerializable>(
        queue: DispatchQueue? = nil,
        completionHandler: @escaping (DataResponse<T>) -> Void)
        -> Self
    {
        let responseSerializer = DataResponseSerializer<T> { request, response, data, error in
            guard error == nil else { return .failure(BackendError.network(error: error!)) }

            let jsonResponseSerializer = DataRequest.jsonResponseSerializer(options: .allowFragments)
            let result = jsonResponseSerializer.serializeResponse(request, response, data, nil)

            guard case let .success(jsonObject) = result else {
                return .failure(BackendError.jsonSerialization(error: result.error!))
            }

            guard let response = response, let responseObject = T(response: response, representation: jsonObject) else {
                return .failure(BackendError.objectSerialization(reason: "JSON could not be serialized: \(jsonObject)"))
            }

            return .success(responseObject)
        }

        return response(queue: queue, responseSerializer: responseSerializer, completionHandler: completionHandler)
    }
}
```

```swift
struct User: ResponseObjectSerializable, CustomStringConvertible {
    let username: String
    let name: String

    var description: String {
        return "User: { username: \(username), name: \(name) }"
    }

    init?(response: HTTPURLResponse, representation: Any) {
        guard
            let username = response.url?.lastPathComponent,
            let representation = representation as? [String: Any],
            let name = representation["name"] as? String
        else { return nil }

        self.username = username
        self.name = name
    }
}
```

```swift
Alamofire.request("https://example.com/users/mattt").responseObject { (response: DataResponse<User>) in
    debugPrint(response)

    if let user = response.result.value {
        print("User: { username: \(user.username), name: \(user.name) }")
    }
}
```

The same approach can also be used to handle endpoints that return a representation of a collection of objects:

```swift
protocol ResponseCollectionSerializable {
    static func collection(from response: HTTPURLResponse, withRepresentation representation: Any) -> [Self]
}

extension ResponseCollectionSerializable where Self: ResponseObjectSerializable {
    static func collection(from response: HTTPURLResponse, withRepresentation representation: Any) -> [Self] {
        var collection: [Self] = []

        if let representation = representation as? [[String: Any]] {
            for itemRepresentation in representation {
                if let item = Self(response: response, representation: itemRepresentation) {
                    collection.append(item)
                }
            }
        }

        return collection
    }
}
```

```swift
extension DataRequest {
    @discardableResult
    func responseCollection<T: ResponseCollectionSerializable>(
        queue: DispatchQueue? = nil,
        completionHandler: @escaping (DataResponse<[T]>) -> Void) -> Self
    {
        let responseSerializer = DataResponseSerializer<[T]> { request, response, data, error in
            guard error == nil else { return .failure(BackendError.network(error: error!)) }

            let jsonSerializer = DataRequest.jsonResponseSerializer(options: .allowFragments)
            let result = jsonSerializer.serializeResponse(request, response, data, nil)

            guard case let .success(jsonObject) = result else {
                return .failure(BackendError.jsonSerialization(error: result.error!))
            }

            guard let response = response else {
                let reason = "Response collection could not be serialized due to nil response."
                return .failure(BackendError.objectSerialization(reason: reason))
            }

            return .success(T.collection(from: response, withRepresentation: jsonObject))
        }

        return response(responseSerializer: responseSerializer, completionHandler: completionHandler)
    }
}
```

```swift
struct User: ResponseObjectSerializable, ResponseCollectionSerializable, CustomStringConvertible {
    let username: String
    let name: String

    var description: String {
        return "User: { username: \(username), name: \(name) }"
    }

    init?(response: HTTPURLResponse, representation: Any) {
        guard
            let username = response.url?.lastPathComponent,
            let representation = representation as? [String: Any],
            let name = representation["name"] as? String
        else { return nil }

        self.username = username
        self.name = name
    }
}
```

```swift
Alamofire.request("https://example.com/users").responseCollection { (response: DataResponse<[User]>) in
    debugPrint(response)

    if let users = response.result.value {
        users.forEach { print("- \($0)") }
    }
}
```

### Security

Using a secure HTTPS connection when communicating with servers and web services is an important step in securing sensitive data. By default, Alamofire will evaluate the certificate chain provided by the server using Apple's built in validation provided by the Security framework. While this guarantees the certificate chain is valid, it does not prevent man-in-the-middle (MITM) attacks or other potential vulnerabilities. In order to mitigate MITM attacks, applications dealing with sensitive customer data or financial information should use certificate or public key pinning provided by the `ServerTrustPolicy`.

#### ServerTrustPolicy

The `ServerTrustPolicy` enumeration evaluates the server trust generally provided by an `URLAuthenticationChallenge` when connecting to a server over a secure HTTPS connection.

```swift
let serverTrustPolicy = ServerTrustPolicy.pinCertificates(
    certificates: ServerTrustPolicy.certificatesInBundle(),
    validateCertificateChain: true,
    validateHost: true
)
```

There are many different cases of server trust evaluation giving you complete control over the validation process:

* `performDefaultEvaluation`: Uses the default server trust evaluation while allowing you to control whether to validate the host provided by the challenge.
* `pinCertificates`: Uses the pinned certificates to validate the server trust. The server trust is considered valid if one of the pinned certificates match one of the server certificates.
* `pinPublicKeys`: Uses the pinned public keys to validate the server trust. The server trust is considered valid if one of the pinned public keys match one of the server certificate public keys.
* `disableEvaluation`: Disables all evaluation which in turn will always consider any server trust as valid.
* `customEvaluation`: Uses the associated closure to evaluate the validity of the server trust thus giving you complete control over the validation process. Use with caution.

#### Server Trust Policy Manager

The `ServerTrustPolicyManager` is responsible for storing an internal mapping of server trust policies to a particular host. This allows Alamofire to evaluate each host against a different server trust policy.

```swift
let serverTrustPolicies: [String: ServerTrustPolicy] = [
    "test.example.com": .pinCertificates(
        certificates: ServerTrustPolicy.certificatesInBundle(),
        validateCertificateChain: true,
        validateHost: true
    ),
    "insecure.expired-apis.com": .disableEvaluation
]

let sessionManager = SessionManager(
    serverTrustPolicyManager: ServerTrustPolicyManager(policies: serverTrustPolicies)
)
```

> Make sure to keep a reference to the new `SessionManager` instance, otherwise your requests will all get cancelled when your `sessionManager` is deallocated.

These server trust policies will result in the following behavior:

- `test.example.com` will always use certificate pinning with certificate chain and host validation enabled thus requiring the following criteria to be met to allow the TLS handshake to succeed:
	- Certificate chain MUST be valid.
	- Certificate chain MUST include one of the pinned certificates.
	- Challenge host MUST match the host in the certificate chain's leaf certificate.
- `insecure.expired-apis.com` will never evaluate the certificate chain and will always allow the TLS handshake to succeed.
- All other hosts will use the default evaluation provided by Apple.

##### Subclassing Server Trust Policy Manager

If you find yourself needing more flexible server trust policy matching behavior (i.e. wildcarded domains), then subclass the `ServerTrustPolicyManager` and override the `serverTrustPolicyForHost` method with your own custom implementation.

```swift
class CustomServerTrustPolicyManager: ServerTrustPolicyManager {
    override func serverTrustPolicy(forHost host: String) -> ServerTrustPolicy? {
        var policy: ServerTrustPolicy?

        // Implement your custom domain matching behavior...

        return policy
    }
}
```

#### Validating the Host

The `.performDefaultEvaluation`, `.pinCertificates` and `.pinPublicKeys` server trust policies all take a `validateHost` parameter. Setting the value to `true` will cause the server trust evaluation to verify that hostname in the certificate matches the hostname of the challenge. If they do not match, evaluation will fail. A `validateHost` value of `false` will still evaluate the full certificate chain, but will not validate the hostname of the leaf certificate.

> It is recommended that `validateHost` always be set to `true` in production environments.

#### Validating the Certificate Chain

Pinning certificates and public keys both have the option of validating the certificate chain using the `validateCertificateChain` parameter. By setting this value to `true`, the full certificate chain will be evaluated in addition to performing a byte equality check against the pinned certificates or public keys. A value of `false` will skip the certificate chain validation, but will still perform the byte equality check.

There are several cases where it may make sense to disable certificate chain validation. The most common use cases for disabling validation are self-signed and expired certificates. The evaluation would always fail in both of these cases, but the byte equality check will still ensure you are receiving the certificate you expect from the server.

> It is recommended that `validateCertificateChain` always be set to `true` in production environments.

#### App Transport Security

With the addition of App Transport Security (ATS) in iOS 9, it is possible that using a custom `ServerTrustPolicyManager` with several `ServerTrustPolicy` objects will have no effect. If you continuously see `CFNetwork SSLHandshake failed (-9806)` errors, you have probably run into this problem. Apple's ATS system overrides the entire challenge system unless you configure the ATS settings in your app's plist to disable enough of it to allow your app to evaluate the server trust.

If you run into this problem (high probability with self-signed certificates), you can work around this issue by adding the following to your `Info.plist`.

```xml
<dict>
	<key>NSAppTransportSecurity</key>
	<dict>
		<key>NSExceptionDomains</key>
		<dict>
			<key>example.com</key>
			<dict>
				<key>NSExceptionAllowsInsecureHTTPLoads</key>
				<true/>
				<key>NSExceptionRequiresForwardSecrecy</key>
				<false/>
				<key>NSIncludesSubdomains</key>
				<true/>
				<!-- Optional: Specify minimum TLS version -->
				<key>NSTemporaryExceptionMinimumTLSVersion</key>
				<string>TLSv1.2</string>
			</dict>
		</dict>
	</dict>
</dict>
```

Whether you need to set the `NSExceptionRequiresForwardSecrecy` to `NO` depends on whether your TLS connection is using an allowed cipher suite. In certain cases, it will need to be set to `NO`. The `NSExceptionAllowsInsecureHTTPLoads` MUST be set to `YES` in order to allow the `SessionDelegate` to receive challenge callbacks. Once the challenge callbacks are being called, the `ServerTrustPolicyManager` will take over the server trust evaluation. You may also need to specify the `NSTemporaryExceptionMinimumTLSVersion` if you're trying to connect to a host that only supports TLS versions less than `1.2`.

> It is recommended to always use valid certificates in production environments.

### Network Reachability

The `NetworkReachabilityManager` listens for reachability changes of hosts and addresses for both WWAN and WiFi network interfaces.

```swift
let manager = NetworkReachabilityManager(host: "www.apple.com")

manager?.listener = { status in
    print("Network Status Changed: \(status)")
}

manager?.startListening()
```

> Make sure to remember to retain the `manager` in the above example, or no status changes will be reported.

There are some important things to remember when using network reachability to determine what to do next.

- **Do NOT** use Reachability to determine if a network request should be sent.
    - You should **ALWAYS** send it.
- When Reachability is restored, use the event to retry failed network requests.
    - Even though the network requests may still fail, this is a good moment to retry them.
- The network reachability status can be useful for determining why a network request may have failed.
    - If a network request fails, it is more useful to tell the user that the network request failed due to being offline rather than a more technical error, such as "request timed out."

> It is recommended to check out [WWDC 2012 Session 706, "Networking Best Practices"](https://developer.apple.com/videos/play/wwdc2012-706/) for more info.

---

## Open Radars

The following radars have some effect on the current implementation of Alamofire.

- [`rdar://21349340`](http://www.openradar.me/radar?id=5517037090635776) - Compiler throwing warning due to toll-free bridging issue in test case
- [`rdar://26761490`](http://www.openradar.me/radar?id=5010235949318144) - Swift string interpolation causing memory leak with common usage
- `rdar://26870455` - Background URL Session Configurations do not work in the simulator
- `rdar://26849668` - Some URLProtocol APIs do not properly handle `URLRequest`

## FAQ

### What's the origin of the name Alamofire?

Alamofire is named after the [Alamo Fire flower](https://aggie-horticulture.tamu.edu/wildseed/alamofire.html), a hybrid variant of the Bluebonnet, the official state flower of Texas.

### What logic belongs in a Router vs. a Request Adapter?

Simple, static data such as paths, parameters and common headers belong in the `Router`. Dynamic data such as an `Authorization` header whose value can changed based on an authentication system belongs in a `RequestAdapter`.

The reason the dynamic data MUST be placed into the `RequestAdapter` is to support retry operations. When a `Request` is retried, the original request is not rebuilt meaning the `Router` will not be called again. The `RequestAdapter` is called again allowing the dynamic data to be updated on the original request before retrying the `Request`.

---

## Credits

Alamofire is owned and maintained by the [Alamofire Software Foundation](http://alamofire.org). You can follow them on Twitter at [@AlamofireSF](https://twitter.com/AlamofireSF) for project updates and releases.

### Security Disclosure

If you believe you have identified a security vulnerability with Alamofire, you should report it as soon as possible via email to security@alamofire.org. Please do not post it to a public issue tracker.

## Donations

The [ASF](https://github.com/Alamofire/Foundation#members) is looking to raise money to officially register as a federal non-profit organization. Registering will allow us members to gain some legal protections and also allow us to put donations to use, tax free. Donating to the ASF will enable us to:

- Pay our legal fees to register as a federal non-profit organization
- Pay our yearly legal fees to keep the non-profit in good status
- Pay for our mail servers to help us stay on top of all questions and security issues
- Potentially fund test servers to make it easier for us to test the edge cases
- Potentially fund developers to work on one of our projects full-time

The community adoption of the ASF libraries has been amazing. We are greatly humbled by your enthusiasm around the projects, and want to continue to do everything we can to move the needle forward. With your continued support, the ASF will be able to improve its reach and also provide better legal safety for the core members. If you use any of our libraries for work, see if your employers would be interested in donating. Our initial goal is to raise $1000 to get all our legal ducks in a row and kickstart this campaign. Any amount you can donate today to help us reach our goal would be greatly appreciated.

<a href='https://pledgie.com/campaigns/31474'><img alt='Click here to lend your support to: Alamofire Software Foundation and make a donation at pledgie.com !' src='https://pledgie.com/campaigns/31474.png?skin_name=chrome' border='0' ></a>

## License

Alamofire is released under the MIT license. See LICENSE for details.
