![Alamofire: Elegant Networking in Swift](https://raw.githubusercontent.com/Alamofire/Alamofire/assets/alamofire.png)

[![Build Status](https://travis-ci.org/Alamofire/Alamofire.svg)](https://travis-ci.org/Alamofire/Alamofire)
[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/Alamofire.svg)](https://img.shields.io/cocoapods/v/Alamofire.svg)
[![Carthage Compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Platform](https://img.shields.io/cocoapods/p/Alamofire.svg?style=flat)](http://cocoadocs.org/docsets/Alamofire)
[![Twitter](https://img.shields.io/badge/twitter-@AlamofireSF-blue.svg?style=flat)](http://twitter.com/AlamofireSF)

Alamofire is an HTTP networking library written in Swift.

## Features

- [x] Chainable Request / Response methods
- [x] URL / JSON / plist Parameter Encoding
- [x] Upload File / Data / Stream / MultipartFormData
- [x] Download using Request or Resume data
- [x] Authentication with NSURLCredential
- [x] HTTP Response Validation
- [x] TLS Certificate and Public Key Pinning
- [x] Progress Closure & NSProgress
- [x] cURL Debug Output
- [x] Comprehensive Unit Test Coverage
- [x] [Complete Documentation](http://cocoadocs.org/docsets/Alamofire)

## Component Libraries

In order to keep Alamofire focused specifically on core networking implementations, additional component libraries have been created by the [Alamofire Software Foundation](https://github.com/Alamofire/Foundation) to bring additional functionality to the Alamofire ecosystem.

* [AlamofireImage](https://github.com/Alamofire/AlamofireImage) - An image library including image response serializers, `UIImage` and `UIImageView` extensions, custom image filters, an auto-purging in-memory cache and a priority-based image downloading system.
* [AlamofireNetworkActivityIndicator](https://github.com/Alamofire/AlamofireNetworkActivityIndicator) - Controls the visibility of the network activity indicator on iOS using Alamofire. It contains configurable delay timers to help mitigate flicker and can support `NSURLSession` instances not managed by Alamofire.

## Requirements

- iOS 8.0+ / Mac OS X 10.9+ / tvOS 9.0+ / watchOS 2.0+
- Xcode 7.2+

## Migration Guides

- [Alamofire 3.0 Migration Guide](https://github.com/Alamofire/Alamofire/blob/master/Documentation/Alamofire%203.0%20Migration%20Guide.md)
- [Alamofire 2.0 Migration Guide](https://github.com/Alamofire/Alamofire/blob/master/Documentation/Alamofire%202.0%20Migration%20Guide.md)

## Communication

- If you **need help**, use [Stack Overflow](http://stackoverflow.com/questions/tagged/alamofire). (Tag 'alamofire')
- If you'd like to **ask a general question**, use [Stack Overflow](http://stackoverflow.com/questions/tagged/alamofire).
- If you **found a bug**, open an issue.
- If you **have a feature request**, open an issue.
- If you **want to contribute**, submit a pull request.

## Installation

> **Embedded frameworks require a minimum deployment target of iOS 8 or OS X Mavericks (10.9).**
>
> Alamofire is no longer supported on iOS 7 due to the lack of support for frameworks. Without frameworks, running Travis-CI against iOS 7 would require a second duplicated test target. The separate test suite would need to import all the Swift files and the tests would need to be duplicated and re-written. This split would be too difficult to maintain to ensure the highest possible quality of the Alamofire ecosystem.

### CocoaPods

[CocoaPods](http://cocoapods.org) is a dependency manager for Cocoa projects. You can install it with the following command:

```bash
$ gem install cocoapods
```

> CocoaPods 0.39.0+ is required to build Alamofire 3.0.0+.

To integrate Alamofire into your Xcode project using CocoaPods, specify it in your `Podfile`:

```ruby
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '8.0'
use_frameworks!

pod 'Alamofire', '~> 3.0'
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
github "Alamofire/Alamofire" ~> 3.0
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

    > You can verify which one you selected by inspecting the build log for your project. The build target for `Alamofire` will be listed as either `Alamofire iOS` or `Alamofire OSX`.

- And that's it!

> The `Alamofire.framework` is automagically added as a target dependency, linked framework and embedded framework in a copy files build phase which is all you need to build on the simulator and a device.

---

## Usage

### Making a Request

```swift
import Alamofire

Alamofire.request(.GET, "https://httpbin.org/get")
```

### Response Handling

```swift
Alamofire.request(.GET, "https://httpbin.org/get", parameters: ["foo": "bar"])
         .responseJSON { response in
             print(response.request)  // original URL request
             print(response.response) // URL response
             print(response.data)     // server data
             print(response.result)   // result of response serialization

             if let JSON = response.result.value {
                 print("JSON: \(JSON)")
             }
         }
```

> Networking in Alamofire is done _asynchronously_. Asynchronous programming may be a source of frustration to programmers unfamiliar with the concept, but there are [very good reasons](https://developer.apple.com/library/ios/qa/qa1693/_index.html) for doing it this way.

> Rather than blocking execution to wait for a response from the server, a [callback](http://en.wikipedia.org/wiki/Callback_%28computer_programming%29) is specified to handle the response once it's received. The result of a request is only available inside the scope of a response handler. Any execution contingent on the response or data received from the server must be done within a handler.

### Response Serialization

**Built-in Response Methods**

- `response()`
- `responseData()`
- `responseString(encoding: NSStringEncoding)`
- `responseJSON(options: NSJSONReadingOptions)`
- `responsePropertyList(options: NSPropertyListReadOptions)`

#### Response Handler

```swift
Alamofire.request(.GET, "https://httpbin.org/get", parameters: ["foo": "bar"])
         .response { request, response, data, error in
             print(request)
             print(response)
             print(data)
             print(error)
          }
```

> The `response` serializer does NOT evaluate any of the response data. It merely forwards on all the information directly from the URL session delegate. We strongly encourage you to leverage the other response serializers taking advantage of `Response` and `Result` types.

#### Response Data Handler

```swift
Alamofire.request(.GET, "https://httpbin.org/get", parameters: ["foo": "bar"])
         .responseData { response in
             print(response.request)
             print(response.response)
             print(response.result)
          }
```

#### Response String Handler

```swift
Alamofire.request(.GET, "https://httpbin.org/get")
         .responseString { response in
             print("Success: \(response.result.isSuccess)")
             print("Response String: \(response.result.value)")
         }
```

#### Response JSON Handler

```swift
Alamofire.request(.GET, "https://httpbin.org/get")
         .responseJSON { response in
             debugPrint(response)
         }
```

#### Chained Response Handlers

Response handlers can even be chained:

```swift
Alamofire.request(.GET, "https://httpbin.org/get")
         .responseString { response in
             print("Response String: \(response.result.value)")
         }
         .responseJSON { response in
             print("Response JSON: \(response.result.value)")
         }
```

### HTTP Methods

`Alamofire.Method` lists the HTTP methods defined in [RFC 7231 §4.3](http://tools.ietf.org/html/rfc7231#section-4.3):

```swift
public enum Method: String {
    case OPTIONS, GET, HEAD, POST, PUT, PATCH, DELETE, TRACE, CONNECT
}
```

These values can be passed as the first argument of the `Alamofire.request` method:

```swift
Alamofire.request(.POST, "https://httpbin.org/post")

Alamofire.request(.PUT, "https://httpbin.org/put")

Alamofire.request(.DELETE, "https://httpbin.org/delete")
```

### Parameters

#### GET Request With URL-Encoded Parameters

```swift
Alamofire.request(.GET, "https://httpbin.org/get", parameters: ["foo": "bar"])
// https://httpbin.org/get?foo=bar
```

#### POST Request With URL-Encoded Parameters

```swift
let parameters = [
    "foo": "bar",
    "baz": ["a", 1],
    "qux": [
        "x": 1,
        "y": 2,
        "z": 3
    ]
]

Alamofire.request(.POST, "https://httpbin.org/post", parameters: parameters)
// HTTP body: foo=bar&baz[]=a&baz[]=1&qux[x]=1&qux[y]=2&qux[z]=3
```

### Parameter Encoding

Parameters can also be encoded as JSON, Property List, or any custom format, using the `ParameterEncoding` enum:

```swift
enum ParameterEncoding {
    case URL
    case URLEncodedInURL
    case JSON
    case PropertyList(format: NSPropertyListFormat, options: NSPropertyListWriteOptions)
    case Custom((URLRequestConvertible, [String: AnyObject]?) -> (NSMutableURLRequest, NSError?))

    func encode(request: NSURLRequest, parameters: [String: AnyObject]?) -> (NSURLRequest, NSError?)
    { ... }
}
```

- `URL`: A query string to be set as or appended to any existing URL query for `GET`, `HEAD`, and `DELETE` requests, or set as the body for requests with any other HTTP method. The `Content-Type` HTTP header field of an encoded request with HTTP body is set to `application/x-www-form-urlencoded`. _Since there is no published specification for how to encode collection types, Alamofire follows the convention of appending `[]` to the key for array values (`foo[]=1&foo[]=2`), and appending the key surrounded by square brackets for nested dictionary values (`foo[bar]=baz`)._
- `URLEncodedInURL`: Creates query string to be set as or appended to any existing URL query. Uses the same implementation as the `.URL` case, but always applies the encoded result to the URL.
- `JSON`: Uses `NSJSONSerialization` to create a JSON representation of the parameters object, which is set as the body of the request. The `Content-Type` HTTP header field of an encoded request is set to `application/json`.
- `PropertyList`: Uses `NSPropertyListSerialization` to create a plist representation of the parameters object, according to the associated format and write options values, which is set as the body of the request. The `Content-Type` HTTP header field of an encoded request is set to `application/x-plist`.
- `Custom`: Uses the associated closure value to construct a new request given an existing request and parameters.

#### Manual Parameter Encoding of an NSURLRequest

```swift
let URL = NSURL(string: "https://httpbin.org/get")!
var request = NSMutableURLRequest(URL: URL)

let parameters = ["foo": "bar"]
let encoding = Alamofire.ParameterEncoding.URL
(request, _) = encoding.encode(request, parameters: parameters)
```

#### POST Request with JSON-encoded Parameters

```swift
let parameters = [
    "foo": [1,2,3],
    "bar": [
        "baz": "qux"
    ]
]

Alamofire.request(.POST, "https://httpbin.org/post", parameters: parameters, encoding: .JSON)
// HTTP body: {"foo": [1, 2, 3], "bar": {"baz": "qux"}}
```

### HTTP Headers

Adding a custom HTTP header to a `Request` is supported directly in the global `request` method. This makes it easy to attach HTTP headers to a `Request` that can be constantly changing.

> For HTTP headers that do not change, it is recommended to set them on the `NSURLSessionConfiguration` so they are automatically applied to any `NSURLSessionTask` created by the underlying `NSURLSession`.

```swift
let headers = [
    "Authorization": "Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==",
    "Content-Type": "application/x-www-form-urlencoded"
]

Alamofire.request(.GET, "https://httpbin.org/get", headers: headers)
         .responseJSON { response in
             debugPrint(response)
         }
```

### Caching

Caching is handled on the system framework level by [`NSURLCache`](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Classes/NSURLCache_Class/Reference/Reference.html#//apple_ref/occ/cl/NSURLCache).

### Uploading

**Supported Upload Types**

- File
- Data
- Stream
- MultipartFormData

#### Uploading a File

```swift
let fileURL = NSBundle.mainBundle().URLForResource("Default", withExtension: "png")
Alamofire.upload(.POST, "https://httpbin.org/post", file: fileURL)
```

#### Uploading with Progress

```swift
Alamofire.upload(.POST, "https://httpbin.org/post", file: fileURL)
         .progress { bytesWritten, totalBytesWritten, totalBytesExpectedToWrite in
             print(totalBytesWritten)

             // This closure is NOT called on the main queue for performance
             // reasons. To update your ui, dispatch to the main queue.
             dispatch_async(dispatch_get_main_queue()) {
                 print("Total bytes written on main queue: \(totalBytesWritten)")
             }
         }
         .responseJSON { response in
             debugPrint(response)
         }
```

#### Uploading MultipartFormData

```swift
Alamofire.upload(
    .POST,
    "https://httpbin.org/post",
    multipartFormData: { multipartFormData in
        multipartFormData.appendBodyPart(fileURL: unicornImageURL, name: "unicorn")
        multipartFormData.appendBodyPart(fileURL: rainbowImageURL, name: "rainbow")
    },
    encodingCompletion: { encodingResult in
    	switch encodingResult {
    	case .Success(let upload, _, _):
            upload.responseJSON { response in
                debugPrint(response)
            }
    	case .Failure(let encodingError):
    	    print(encodingError)
    	}
    }
)
```

### Downloading

**Supported Download Types**

- Request
- Resume Data

#### Downloading a File

```swift
Alamofire.download(.GET, "https://httpbin.org/stream/100") { temporaryURL, response in
    let fileManager = NSFileManager.defaultManager()
    let directoryURL = fileManager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)[0]
    let pathComponent = response.suggestedFilename

    return directoryURL.URLByAppendingPathComponent(pathComponent!)
}
```

#### Using the Default Download Destination

```swift
let destination = Alamofire.Request.suggestedDownloadDestination(directory: .DocumentDirectory, domain: .UserDomainMask)
Alamofire.download(.GET, "https://httpbin.org/stream/100", destination: destination)
```

#### Downloading a File w/Progress

```swift
Alamofire.download(.GET, "https://httpbin.org/stream/100", destination: destination)
         .progress { bytesRead, totalBytesRead, totalBytesExpectedToRead in
             print(totalBytesRead)

             // This closure is NOT called on the main queue for performance
             // reasons. To update your ui, dispatch to the main queue.
             dispatch_async(dispatch_get_main_queue()) {
                 print("Total bytes read on main queue: \(totalBytesRead)")
             }
         }
         .response { _, _, _, error in
             if let error = error {
                 print("Failed with error: \(error)")
             } else {
                 print("Downloaded file successfully")
             }
         }
```

#### Accessing Resume Data for Failed Downloads

```swift
Alamofire.download(.GET, "https://httpbin.org/stream/100", destination: destination)
         .response { _, _, data, _ in
             if let
                 data = data,
                 resumeDataString = NSString(data: data, encoding: NSUTF8StringEncoding)
             {
                 print("Resume Data: \(resumeDataString)")
             } else {
                 print("Resume Data was empty")
             }
         }
```

> The `data` parameter is automatically populated with the `resumeData` if available.

```swift
let download = Alamofire.download(.GET, "https://httpbin.org/stream/100", destination: destination)
download.response { _, _, _, _ in
    if let
        resumeData = download.resumeData,
        resumeDataString = NSString(data: resumeData, encoding: NSUTF8StringEncoding)
    {
        print("Resume Data: \(resumeDataString)")
    } else {
        print("Resume Data was empty")
    }
}
```

### Authentication

Authentication is handled on the system framework level by [`NSURLCredential` and `NSURLAuthenticationChallenge`](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Classes/NSURLAuthenticationChallenge_Class/Reference/Reference.html).

**Supported Authentication Schemes**

- [HTTP Basic](http://en.wikipedia.org/wiki/Basic_access_authentication)
- [HTTP Digest](http://en.wikipedia.org/wiki/Digest_access_authentication)
- [Kerberos](http://en.wikipedia.org/wiki/Kerberos_%28protocol%29)
- [NTLM](http://en.wikipedia.org/wiki/NT_LAN_Manager)

#### HTTP Basic Authentication

The `authenticate` method on a `Request` will automatically provide an `NSURLCredential` to an `NSURLAuthenticationChallenge` when appropriate:

```swift
let user = "user"
let password = "password"

Alamofire.request(.GET, "https://httpbin.org/basic-auth/\(user)/\(password)")
         .authenticate(user: user, password: password)
         .responseJSON { response in
             debugPrint(response)
         }
```

Depending upon your server implementation, an `Authorization` header may also be appropriate:

```swift
let user = "user"
let password = "password"

let credentialData = "\(user):\(password)".dataUsingEncoding(NSUTF8StringEncoding)!
let base64Credentials = credentialData.base64EncodedStringWithOptions([])

let headers = ["Authorization": "Basic \(base64Credentials)"]

Alamofire.request(.GET, "https://httpbin.org/basic-auth/user/password", headers: headers)
         .responseJSON { response in
             debugPrint(response)
         }
```

#### Authentication with NSURLCredential

```swift
let user = "user"
let password = "password"

let credential = NSURLCredential(user: user, password: password, persistence: .ForSession)

Alamofire.request(.GET, "https://httpbin.org/basic-auth/\(user)/\(password)")
         .authenticate(usingCredential: credential)
         .responseJSON { response in
             debugPrint(response)
         }
```

### Validation

By default, Alamofire treats any completed request to be successful, regardless of the content of the response. Calling `validate` before a response handler causes an error to be generated if the response had an unacceptable status code or MIME type.

#### Manual Validation

```swift
Alamofire.request(.GET, "https://httpbin.org/get", parameters: ["foo": "bar"])
         .validate(statusCode: 200..<300)
         .validate(contentType: ["application/json"])
         .response { response in
             print(response)
         }
```

#### Automatic Validation

Automatically validates status code within `200...299` range, and that the `Content-Type` header of the response matches the `Accept` header of the request, if one is provided.

```swift
Alamofire.request(.GET, "https://httpbin.org/get", parameters: ["foo": "bar"])
         .validate()
         .responseJSON { response in
             switch response.result {
             case .Success:
                 print("Validation Successful")
             case .Failure(let error):
                 print(error)
             }
         }
```

### Timeline

Alamofire collects timings throughout the lifecycle of a `Request` and creates a `Timeline` object exposed as a property on a `Response`.

```swift
Alamofire.request(.GET, "https://httpbin.org/get", parameters: ["foo": "bar"])
         .validate()
         .responseJSON { response in
             print(response.timeline)
         }
```

The above reports the following `Timeline` info:

- `Latency`: 0.428 seconds
- `Request Duration`: 0.428 seconds
- `Serialization Duration`: 0.001 seconds
- `Total Duration`: 0.429 seconds

### Printable

```swift
let request = Alamofire.request(.GET, "https://httpbin.org/ip")

print(request)
// GET https://httpbin.org/ip (200)
```

### DebugPrintable

```swift
let request = Alamofire.request(.GET, "https://httpbin.org/get", parameters: ["foo": "bar"])

debugPrint(request)
```

#### Output (cURL)

```bash
$ curl -i \
	-H "User-Agent: Alamofire" \
	-H "Accept-Encoding: Accept-Encoding: gzip;q=1.0,compress;q=0.5" \
	-H "Accept-Language: en;q=1.0,fr;q=0.9,de;q=0.8,zh-Hans;q=0.7,zh-Hant;q=0.6,ja;q=0.5" \
	"https://httpbin.org/get?foo=bar"
```

---

## Advanced Usage

> Alamofire is built on `NSURLSession` and the Foundation URL Loading System. To make the most of
this framework, it is recommended that you be familiar with the concepts and capabilities of the underlying networking stack.

**Recommended Reading**

- [URL Loading System Programming Guide](https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/URLLoadingSystem/URLLoadingSystem.html)
- [NSURLSession Class Reference](https://developer.apple.com/library/mac/documentation/Foundation/Reference/NSURLSession_class/Introduction/Introduction.html#//apple_ref/occ/cl/NSURLSession)
- [NSURLCache Class Reference](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Classes/NSURLCache_Class/Reference/Reference.html#//apple_ref/occ/cl/NSURLCache)
- [NSURLAuthenticationChallenge Class Reference](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Classes/NSURLAuthenticationChallenge_Class/Reference/Reference.html)

### Manager

Top-level convenience methods like `Alamofire.request` use a shared instance of `Alamofire.Manager`, which is configured with the default `NSURLSessionConfiguration`.

As such, the following two statements are equivalent:

```swift
Alamofire.request(.GET, "https://httpbin.org/get")
```

```swift
let manager = Alamofire.Manager.sharedInstance
manager.request(NSURLRequest(URL: NSURL(string: "https://httpbin.org/get")!))
```

Applications can create managers for background and ephemeral sessions, as well as new managers that customize the default session configuration, such as for default headers (`HTTPAdditionalHeaders`) or timeout interval (`timeoutIntervalForRequest`).

#### Creating a Manager with Default Configuration

```swift
let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
let manager = Alamofire.Manager(configuration: configuration)
```

#### Creating a Manager with Background Configuration

```swift
let configuration = NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier("com.example.app.background")
let manager = Alamofire.Manager(configuration: configuration)
```

#### Creating a Manager with Ephemeral Configuration

```swift
let configuration = NSURLSessionConfiguration.ephemeralSessionConfiguration()
let manager = Alamofire.Manager(configuration: configuration)
```

#### Modifying Session Configuration

```swift
var defaultHeaders = Alamofire.Manager.sharedInstance.session.configuration.HTTPAdditionalHeaders ?? [:]
defaultHeaders["DNT"] = "1 (Do Not Track Enabled)"

let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
configuration.HTTPAdditionalHeaders = defaultHeaders

let manager = Alamofire.Manager(configuration: configuration)
```

> This is **not** recommended for `Authorization` or `Content-Type` headers. Instead, use `URLRequestConvertible` and `ParameterEncoding`, respectively.

### Request

The result of a `request`, `upload`, or `download` method is an instance of `Alamofire.Request`. A request is always created using a constructor method from an owning manager, and never initialized directly.

Methods like `authenticate`, `validate` and `responseData` return the caller in order to facilitate chaining.

Requests can be suspended, resumed, and cancelled:

- `suspend()`: Suspends the underlying task and dispatch queue
- `resume()`: Resumes the underlying task and dispatch queue. If the owning manager does not have `startRequestsImmediately` set to `true`, the request must call `resume()` in order to start.
- `cancel()`: Cancels the underlying task, producing an error that is passed to any registered response handlers.

### Response Serialization

#### Creating a Custom Response Serializer

Alamofire provides built-in response serialization for strings, JSON, and property lists, but others can be added in extensions on `Alamofire.Request`.

For example, here's how a response handler using [Ono](https://github.com/mattt/Ono) might be implemented:

```swift
extension Request {
    public static func XMLResponseSerializer() -> ResponseSerializer<ONOXMLDocument, NSError> {
        return ResponseSerializer { request, response, data, error in
            guard error == nil else { return .Failure(error!) }

            guard let validData = data else {
                let failureReason = "Data could not be serialized. Input data was nil."
                let error = Error.errorWithCode(.DataSerializationFailed, failureReason: failureReason)
                return .Failure(error)
            }

            do {
                let XML = try ONOXMLDocument(data: validData)
                return .Success(XML)
            } catch {
                return .Failure(error as NSError)
            }
        }
    }

    public func responseXMLDocument(completionHandler: Response<ONOXMLDocument, NSError> -> Void) -> Self {
        return response(responseSerializer: Request.XMLResponseSerializer(), completionHandler: completionHandler)
    }
}
```

#### Generic Response Object Serialization

Generics can be used to provide automatic, type-safe response object serialization.

```swift
public protocol ResponseObjectSerializable {
    init?(response: NSHTTPURLResponse, representation: AnyObject)
}

extension Request {
    public func responseObject<T: ResponseObjectSerializable>(completionHandler: Response<T, NSError> -> Void) -> Self {
        let responseSerializer = ResponseSerializer<T, NSError> { request, response, data, error in
            guard error == nil else { return .Failure(error!) }

            let JSONResponseSerializer = Request.JSONResponseSerializer(options: .AllowFragments)
            let result = JSONResponseSerializer.serializeResponse(request, response, data, error)

            switch result {
            case .Success(let value):
                if let
                    response = response,
                    responseObject = T(response: response, representation: value)
                {
                    return .Success(responseObject)
                } else {
                    let failureReason = "JSON could not be serialized into response object: \(value)"
                    let error = Error.errorWithCode(.JSONSerializationFailed, failureReason: failureReason)
                    return .Failure(error)
                }
            case .Failure(let error):
                return .Failure(error)
            }
        }

        return response(responseSerializer: responseSerializer, completionHandler: completionHandler)
    }
}
```

```swift
final class User: ResponseObjectSerializable {
    let username: String
    let name: String

    init?(response: NSHTTPURLResponse, representation: AnyObject) {
        self.username = response.URL!.lastPathComponent!
        self.name = representation.valueForKeyPath("name") as! String
    }
}
```

```swift
Alamofire.request(.GET, "https://example.com/users/mattt")
         .responseObject { (response: Response<User, NSError>) in
             debugPrint(response)
         }
```

The same approach can also be used to handle endpoints that return a representation of a collection of objects:

```swift
public protocol ResponseCollectionSerializable {
    static func collection(response response: NSHTTPURLResponse, representation: AnyObject) -> [Self]
}

extension Alamofire.Request {
    public func responseCollection<T: ResponseCollectionSerializable>(completionHandler: Response<[T], NSError> -> Void) -> Self {
        let responseSerializer = ResponseSerializer<[T], NSError> { request, response, data, error in
            guard error == nil else { return .Failure(error!) }

            let JSONSerializer = Request.JSONResponseSerializer(options: .AllowFragments)
            let result = JSONSerializer.serializeResponse(request, response, data, error)

            switch result {
            case .Success(let value):
                if let response = response {
                    return .Success(T.collection(response: response, representation: value))
                } else {
                    let failureReason = "Response collection could not be serialized due to nil response"
                    let error = Error.errorWithCode(.JSONSerializationFailed, failureReason: failureReason)
                    return .Failure(error)
                }
            case .Failure(let error):
                return .Failure(error)
            }
        }

        return response(responseSerializer: responseSerializer, completionHandler: completionHandler)
    }
}
```

```swift
final class User: ResponseObjectSerializable, ResponseCollectionSerializable {
    let username: String
    let name: String

    init?(response: NSHTTPURLResponse, representation: AnyObject) {
        self.username = response.URL!.lastPathComponent!
        self.name = representation.valueForKeyPath("name") as! String
    }

    static func collection(response response: NSHTTPURLResponse, representation: AnyObject) -> [User] {
        var users: [User] = []

        if let representation = representation as? [[String: AnyObject]] {
            for userRepresentation in representation {
                if let user = User(response: response, representation: userRepresentation) {
                    users.append(user)
                }
            }
        }

        return users
    }
}
```

```swift
Alamofire.request(.GET, "http://example.com/users")
         .responseCollection { (response: Response<[User], NSError>) in
             debugPrint(response)
         }
```

### URLStringConvertible

Types adopting the `URLStringConvertible` protocol can be used to construct URL strings, which are then used to construct URL requests. `NSString`, `NSURL`, `NSURLComponents`, and `NSURLRequest` conform to `URLStringConvertible` by default, allowing any of them to be passed as `URLString` parameters to the `request`, `upload`, and `download` methods:

```swift
let string = NSString(string: "https://httpbin.org/post")
Alamofire.request(.POST, string)

let URL = NSURL(string: string)!
Alamofire.request(.POST, URL)

let URLRequest = NSURLRequest(URL: URL)
Alamofire.request(.POST, URLRequest) // overrides `HTTPMethod` of `URLRequest`

let URLComponents = NSURLComponents(URL: URL, resolvingAgainstBaseURL: true)
Alamofire.request(.POST, URLComponents)
```

Applications interacting with web applications in a significant manner are encouraged to have custom types conform to `URLStringConvertible` as a convenient way to map domain-specific models to server resources.

#### Type-Safe Routing

```swift
extension User: URLStringConvertible {
    static let baseURLString = "http://example.com"

    var URLString: String {
        return User.baseURLString + "/users/\(username)/"
    }
}
```

```swift
let user = User(username: "mattt")
Alamofire.request(.GET, user) // http://example.com/users/mattt
```

### URLRequestConvertible

Types adopting the `URLRequestConvertible` protocol can be used to construct URL requests. `NSURLRequest` conforms to `URLRequestConvertible` by default, allowing it to be passed into `request`, `upload`, and `download` methods directly (this is the recommended way to specify custom HTTP body for individual requests):

```swift
let URL = NSURL(string: "https://httpbin.org/post")!
let mutableURLRequest = NSMutableURLRequest(URL: URL)
mutableURLRequest.HTTPMethod = "POST"

let parameters = ["foo": "bar"]

do {
    mutableURLRequest.HTTPBody = try NSJSONSerialization.dataWithJSONObject(parameters, options: NSJSONWritingOptions())
} catch {
    // No-op
}

mutableURLRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

Alamofire.request(mutableURLRequest)
```

Applications interacting with web applications in a significant manner are encouraged to have custom types conform to `URLRequestConvertible` as a way to ensure consistency of requested endpoints. Such an approach can be used to abstract away server-side inconsistencies and provide type-safe routing, as well as manage authentication credentials and other state.

#### API Parameter Abstraction

```swift
enum Router: URLRequestConvertible {
    static let baseURLString = "http://example.com"
    static let perPage = 50

    case Search(query: String, page: Int)

    // MARK: URLRequestConvertible

    var URLRequest: NSMutableURLRequest {
        let result: (path: String, parameters: [String: AnyObject]) = {
            switch self {
            case .Search(let query, let page) where page > 1:
                return ("/search", ["q": query, "offset": Router.perPage * page])
            case .Search(let query, _):
                return ("/search", ["q": query])
            }
        }()

        let URL = NSURL(string: Router.baseURLString)!
        let URLRequest = NSURLRequest(URL: URL.URLByAppendingPathComponent(result.path))
        let encoding = Alamofire.ParameterEncoding.URL

        return encoding.encode(URLRequest, parameters: result.parameters).0
    }
}
```

```swift
Alamofire.request(Router.Search(query: "foo bar", page: 1)) // ?q=foo%20bar&offset=50
```

#### CRUD & Authorization

```swift
enum Router: URLRequestConvertible {
    static let baseURLString = "http://example.com"
    static var OAuthToken: String?

    case CreateUser([String: AnyObject])
    case ReadUser(String)
    case UpdateUser(String, [String: AnyObject])
    case DestroyUser(String)

    var method: Alamofire.Method {
        switch self {
        case .CreateUser:
            return .POST
        case .ReadUser:
            return .GET
        case .UpdateUser:
            return .PUT
        case .DestroyUser:
            return .DELETE
        }
    }

    var path: String {
        switch self {
        case .CreateUser:
            return "/users"
        case .ReadUser(let username):
            return "/users/\(username)"
        case .UpdateUser(let username, _):
            return "/users/\(username)"
        case .DestroyUser(let username):
            return "/users/\(username)"
        }
    }

    // MARK: URLRequestConvertible

    var URLRequest: NSMutableURLRequest {
        let URL = NSURL(string: Router.baseURLString)!
        let mutableURLRequest = NSMutableURLRequest(URL: URL.URLByAppendingPathComponent(path))
        mutableURLRequest.HTTPMethod = method.rawValue

        if let token = Router.OAuthToken {
            mutableURLRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        switch self {
        case .CreateUser(let parameters):
            return Alamofire.ParameterEncoding.JSON.encode(mutableURLRequest, parameters: parameters).0
        case .UpdateUser(_, let parameters):
            return Alamofire.ParameterEncoding.URL.encode(mutableURLRequest, parameters: parameters).0
        default:
            return mutableURLRequest
        }
    }
}
```

```swift
Alamofire.request(Router.ReadUser("mattt")) // GET /users/mattt
```

### Security

Using a secure HTTPS connection when communicating with servers and web services is an important step in securing sensitive data. By default, Alamofire will evaluate the certificate chain provided by the server using Apple's built in validation provided by the Security framework. While this guarantees the certificate chain is valid, it does not prevent man-in-the-middle (MITM) attacks or other potential vulnerabilities. In order to mitigate MITM attacks, applications dealing with sensitive customer data or financial information should use certificate or public key pinning provided by the `ServerTrustPolicy`.

#### ServerTrustPolicy

The `ServerTrustPolicy` enumeration evaluates the server trust generally provided by an `NSURLAuthenticationChallenge` when connecting to a server over a secure HTTPS connection.

```swift
let serverTrustPolicy = ServerTrustPolicy.PinCertificates(
    certificates: ServerTrustPolicy.certificatesInBundle(),
    validateCertificateChain: true,
    validateHost: true
)
```

There are many different cases of server trust evaluation giving you complete control over the validation process:

* `PerformDefaultEvaluation`: Uses the default server trust evaluation while allowing you to control whether to validate the host provided by the challenge. 
* `PinCertificates`: Uses the pinned certificates to validate the server trust. The server trust is considered valid if one of the pinned certificates match one of the server certificates.
* `PinPublicKeys`: Uses the pinned public keys to validate the server trust. The server trust is considered valid if one of the pinned public keys match one of the server certificate public keys.
* `DisableEvaluation`: Disables all evaluation which in turn will always consider any server trust as valid.
* `CustomEvaluation`: Uses the associated closure to evaluate the validity of the server trust thus giving you complete control over the validation process. Use with caution.

#### Server Trust Policy Manager

The `ServerTrustPolicyManager` is responsible for storing an internal mapping of server trust policies to a particular host. This allows Alamofire to evaluate each host against a different server trust policy. 

```swift
let serverTrustPolicies: [String: ServerTrustPolicy] = [
    "test.example.com": .PinCertificates(
        certificates: ServerTrustPolicy.certificatesInBundle(),
        validateCertificateChain: true,
        validateHost: true
    ),
    "insecure.expired-apis.com": .DisableEvaluation
]

let manager = Manager(
    serverTrustPolicyManager: ServerTrustPolicyManager(policies: serverTrustPolicies)
)
```

> Make sure to keep a reference to the new `Manager` instance, otherwise your requests will all get cancelled when your `manager` is deallocated.

These server trust policies will result in the following behavior:

* `test.example.com` will always use certificate pinning with certificate chain and host validation enabled thus requiring the following criteria to be met to allow the TLS handshake to succeed:
  * Certificate chain MUST be valid.
  * Certificate chain MUST include one of the pinned certificates.
  * Challenge host MUST match the host in the certificate chain's leaf certificate.
* `insecure.expired-apis.com` will never evaluate the certificate chain and will always allow the TLS handshake to succeed.
* All other hosts will use the default evaluation provided by Apple.

##### Subclassing Server Trust Policy Manager

If you find yourself needing more flexible server trust policy matching behavior (i.e. wildcarded domains), then subclass the `ServerTrustPolicyManager` and override the `serverTrustPolicyForHost` method with your own custom implementation.

```swift
class CustomServerTrustPolicyManager: ServerTrustPolicyManager {
    override func serverTrustPolicyForHost(host: String) -> ServerTrustPolicy? {
        var policy: ServerTrustPolicy?

        // Implement your custom domain matching behavior...

        return policy
    }
}
```

#### Validating the Host

The `.PerformDefaultEvaluation`, `.PinCertificates` and `.PinPublicKeys` server trust policies all take a `validateHost` parameter. Setting the value to `true` will cause the server trust evaluation to verify that hostname in the certificate matches the hostname of the challenge. If they do not match, evaluation will fail. A `validateHost` value of `false` will still evaluate the full certificate chain, but will not validate the hostname of the leaf certificate.

> It is recommended that `validateHost` always be set to `true` in production environments.

#### Validating the Certificate Chain

Pinning certificates and public keys both have the option of validating the certificate chain using the `validateCertificateChain` parameter. By setting this value to `true`, the full certificate chain will be evaluated in addition to performing a byte equality check against the pinned certficates or public keys. A value of `false` will skip the certificate chain validation, but will still perform the byte equality check.

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

* **Do NOT** use Reachability to determine if a network request should be sent.
  * You should **ALWAYS** send it.
* When Reachability is restored, use the event to retry failed network requests.
  * Even though the network requests may still fail, this is a good moment to retry them.
* The network reachability status can be useful for determining why a network request may have failed.
  * If a network request fails, it is more useful to tell the user that the network request failed due to being offline rather than a more technical errror, such as "request timed out."

> It is recommended to check out [WWDC 2012 Session 706, "Networking Best Practices"](https://developer.apple.com/videos/play/wwdc2012-706/) for more info.

---

## Open Rdars

The following rdars have some affect on the current implementation of Alamofire.

* [rdar://21349340](http://www.openradar.me/radar?id=5517037090635776) - Compiler throwing warning due to toll-free bridging issue in test case

## FAQ

### What's the origin of the name Alamofire?

Alamofire is named after the [Alamo Fire flower](https://aggie-horticulture.tamu.edu/wildseed/alamofire.html), a hybrid variant of the Bluebonnet, the official state flower of Texas.

---

## Credits

Alamofire is owned and maintained by the [Alamofire Software Foundation](http://alamofire.org). You can follow them on Twitter at [@AlamofireSF](https://twitter.com/AlamofireSF) for project updates and releases.

### Security Disclosure

If you believe you have identified a security vulnerability with Alamofire, you should report it as soon as possible via email to security@alamofire.org. Please do not post it to a public issue tracker.

## License

Alamofire is released under the MIT license. See LICENSE for details.
