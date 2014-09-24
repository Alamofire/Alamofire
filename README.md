![Alamofire: Elegant Networking in Swift](https://raw.githubusercontent.com/Alamofire/Alamofire/assets/alamofire.png)

Alamofire is an HTTP networking library written in Swift. Think of it as [AFNetworking](https://github.com/afnetworking/afnetworking), reimagined for the conventions of this new language.

Of course, AFNetworking remains the premiere networking library available for Mac OS X and iOS, and can easily be used in Swift, just like any other Objective-C code. **AFNetworking is stable and reliable, and isn't going anywhere.** But for anyone looking for something a little more idiomatic to Swift, Alamofire may be right up your alley. (It's not a mutually-exclusive choice, either! AFNetworking & Alamofire will peacefully co-exist within the same codebase.)

> Alamofire is named after the [Alamo Fire flower](https://aggie-horticulture.tamu.edu/wildseed/alamofire.html), a hybrid variant of the Bluebonnet, the official state flower of Texas.

## Features

- [x] Chainable Request / Response methods
- [x] URL / JSON / plist Parameter Encoding
- [x] Upload File / Data / Stream
- [x] Download using Request or Resume data
- [x] Authentication with NSURLCredential
- [x] HTTP Response Validation
- [x] Progress Closure & NSProgress
- [x] cURL Debug Output
- [x] Comprehensive Unit Test Coverage
- [x] Complete Documentation

## Requirements

- iOS 7.0+ / Mac OS X 10.9+
- Xcode 6.0

> For Xcode 6.1, use [the `xcode-6.1` branch](https://github.com/Alamofire/Alamofire/tree/xcode-6.1).

## Installation

_The infrastructure and best practices for distributing Swift libraries is currently in flux... which is to say, the current installation process kinda sucks._

1. Add Alamofire as a submodule by opening the Terminal, `cd`-ing into your top-level project directory, and entering the command `git submodule add https://github.com/Alamofire/Alamofire.git`
2. Open the `Alamofire` folder, and drag `Alamofire.xcodeproj` into the file navigator of your Xcode project.
3. In Xcode, navigate to the target configuration window by clicking on the blue project icon, and selecting the application target under the "Targets" heading in the sidebar.
4. In the tab bar at the top of that window, open the "Build Phases" panel.
5. Expand the "Link Binary with Libraries" group, and add `Alamofire.framework`.
6. Click on the `+` button at the top left of the panel and select "New Copy Files Phase". Rename this new phase to "Copy Frameworks", set the "Destination" to "Frameworks", and add `Alamofire.framework`.

---

## Usage

### GET Request

```swift
Alamofire.request(.GET, "http://httpbin.org/get")
```

#### With Parameters

```swift
Alamofire.request(.GET, "http://httpbin.org/get", parameters: ["foo": "bar"])
```

#### With Response Handling

```swift
Alamofire.request(.GET, "http://httpbin.org/get", parameters: ["foo": "bar"])
         .response { (request, response, data, error) in
                     println(request)
                     println(response)
                     println(error)
                   }
```

#### With Response String Handling

```swift
Alamofire.request(.GET, "http://httpbin.org/get", parameters: ["foo": "bar"])
         .responseString { (request, response, string, error) in
                  println(string)
         }
```

### HTTP Methods

The `Alamofire.Method` `enum` lists the HTTP methods defined in RFC 2616 §9:

```swift
public enum Method: String {
    case OPTIONS = "OPTIONS"
    case GET = "GET"
    case HEAD = "HEAD"
    case POST = "POST"
    case PUT = "PUT"
    case PATCH = "PATCH"
    case DELETE = "DELETE"
    case TRACE = "TRACE"
    case CONNECT = "CONNECT"
}
```

These values can be passed as the first argument of the `Alamofire.request` method:

```swift
Alamofire.request(.POST, "http://httpbin.org/post")

Alamofire.request(.PUT, "http://httpbin.org/put")

Alamofire.request(.DELETE, "http://httpbin.org/delete")
```

### POST Request

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

Alamofire.request(.POST, "http://httpbin.org/post", parameters: parameters)
```

This sends the following HTTP Body:

```
foo=bar&baz[]=a&baz[]=1&qux[x]=1&qux[y]=2&qux[z]=3
```

Alamofire has built-in support for encoding parameters as URL query / URI form encoded, JSON, and Property List, using the `Alamofire.ParameterEncoding` `enum`:

### Parameter Encoding

Used to specify the way in which a set of parameters are applied to a URL request.

```swift
enum ParameterEncoding {
    case URL
    case JSON
    case PropertyList(format: NSPropertyListFormat,
                      options: NSPropertyListWriteOptions)

    func encode(request: NSURLRequest,
                parameters: [String: AnyObject]?) ->
                    (NSURLRequest, NSError?)
    { ... }
}
```

- `URL`: A query string to be set as or appended to any existing URL query for `GET`, `HEAD`, and `DELETE` requests, or set as the body for requests with any other HTTP method. The `Content-Type` HTTP header field of an encoded request with HTTP body is set to `application/x-www-form-urlencoded`. Since there is no published specification for how to encode collection types, the convention of appending `[]` to the key for array values (`foo[]=1&foo[]=2`), and appending the key surrounded by square brackets for nested dictionary values (`foo[bar]=baz`).
- `JSON`: Uses `NSJSONSerialization` to create a JSON representation of the parameters object, which is set as the body of the request. The `Content-Type` HTTP header field of an encoded request is set to `application/json`.
- `PropertyList`: Uses `NSPropertyListSerialization` to create a plist representation of the parameters object, according to the associated format and write options values, which is set as the body of the request. The `Content-Type` HTTP header field of an encoded request is set to `application/x-plist`.
- `Custom`: Uses the associated closure value to construct a new request given an existing request and parameters.

#### Manual Parameter Encoding of an NSURLRequest

```swift
let URL = NSURL(string: "http://httpbin.org/get")
var request = NSURLRequest(URL: URL)

let parameters = ["foo": "bar"]
let encoding = Alamofire.ParameterEncoding.URL
(request, _) = encoding.encode(request, parameters)
```

### Response Serialization

**Built-in Response Methods**

- `response()`
- `responseString(encoding: NSStringEncoding)`
- `responseJSON(options: NSJSONReadingOptions)`
- `responsePropertyList(options: NSPropertyListReadOptions)`

#### POST Request with JSON Response

```swift
Alamofire.request(.POST, "http://httpbin.org/post", parameters: parameters, encoding: .JSON)
         .responseJSON {(request, response, JSON, error) in
            println(JSON)
         }
```

### Caching

Caching is handled on the system framework level by [`NSURLCache`](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Classes/NSURLCache_Class/Reference/Reference.html#//apple_ref/occ/cl/NSURLCache).

### Uploading

#### Supported Upload Types

- File
- Data
- Stream

#### Uploading a File

```swift
let fileURL = NSBundle.mainBundle()
                      .URLForResource("Default",
                                      withExtension: "png")

Alamofire.upload(.POST, "http://httpbin.org/post", file: fileURL)
```

#### Uploading w/Progress

```swift
Alamofire.upload(.POST, "http://httpbin.org/post", file: fileURL)
         .progress { (bytesWritten, totalBytesWritten, totalBytesExpectedToWrite) in
             println(totalBytesWritten)
         }
         .responseJSON { (request, response, JSON, error) in
             println(JSON)
         }
```

### Downloading

#### Supported Download Types

- Request
- Resume Data

#### Downloading a File

```swift
Alamofire.download(.GET, "http://httpbin.org/stream/100", destination: { (temporaryURL, response) in
    if let directoryURL = NSFileManager.defaultManager()
                          .URLsForDirectory(.DocumentDirectory,
                                            inDomains: .UserDomainMask)[0]
                          as? NSURL {
        let pathComponent = response.suggestedFilename

        return directoryURL.URLByAppendingPathComponent(pathComponent!)
    }

    return temporaryURL
})
```

#### Using the Default Download Destination

```swift
let destination = Alamofire.Request.suggestedDownloadDestination(directory: .DocumentDirectory, domain: .UserDomainMask)

Alamofire.download(.GET, "http://httpbin.org/stream/100", destination: destination)
```

#### Downloading a File w/Progress

```swift
Alamofire.download(.GET, "http://httpbin.org/stream/100", destination: destination)
         .progress { (bytesRead, totalBytesRead, totalBytesExpectedToRead) in
             println(totalBytesRead)
         }
         .response { (request, response, _, error) in
             println(response)
         }
```

### Authentication

**Supported Authentication Schemes**

- [HTTP Basic](http://en.wikipedia.org/wiki/Basic_access_authentication)
- [HTTP Digest](http://en.wikipedia.org/wiki/Digest_access_authentication)
- [Kerberos](http://en.wikipedia.org/wiki/Kerberos_%28protocol%29)
- [NTLM](http://en.wikipedia.org/wiki/NT_LAN_Manager)

#### HTTP Basic Authentication

```swift
let user = "user"
let password = "password"

Alamofire.request(.GET, "https://httpbin.org/basic-auth/\(user)/\(password)")
         .authenticate(user: user, password: password)
         .response {(request, response, _, error) in
             println(response)
         }
```

#### Authenticating with NSURLCredential

```swift
let user = "user"
let password = "password"

let credential = NSURLCredential(user: user, password: password, persistence: .ForSession)
```

```swift
Alamofire.request(.GET, "https://httpbin.org/basic-auth/\(user)/\(password)")
         .authenticate(usingCredential: credential)
         .response {(request, response, _, error) in
             println(response)
         }
```

### Validation

#### Manual Validation

```swift
Alamofire.request(.GET, "http://httpbin.org/get", parameters: ["foo": "bar"])
         .validate(statusCode: 200..<300)
         .validate(contentType: ["application/json"])
         .response { (_, _, _, error) in
                  println(error)
         }
```

#### Automatic Validation

Automatically validates status code within `200...299` range, and that the `Content-Type` header of the response matches the `Accept` header of the request, if one is provided.

```swift
Alamofire.request(.GET, "http://httpbin.org/get", parameters: ["foo": "bar"])
         .validate()
         .response { (_, _, _, error) in
                  println(error)
         }
```

### Printable

```swift
let request = Alamofire.request(.GET, "http://httpbin.org/ip")

println(request)
// GET http://httpbin.org/ip (200)
```

### DebugPrintable

```swift
let request = Alamofire.request(.GET, "http://httpbin.org/get", parameters: ["foo": "bar"])

debugPrintln(request)
```

#### Output (cURL)

```
$ curl -i \
	-H "User-Agent: Alamofire" \
	-H "Accept-Encoding: Accept-Encoding: gzip;q=1.0,compress;q=0.5" \
	-H "Accept-Language: en;q=1.0,fr;q=0.9,de;q=0.8,zh-Hans;q=0.7,zh-Hant;q=0.6,ja;q=0.5" \
	"http://httpbin.org/get?foo=bar"
```

---

## Advanced Usage

> Alamofire is built on `NSURLSession` and the Foundation URL Loading System. To make the most of
this framework, it is _strongly_ recommended that you are familiar with the concepts and capabilities of the underlying networking stack.

**Recommended Reading**

- [URL Loading System Programming Guide](https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/URLLoadingSystem/URLLoadingSystem.html)
- [NSURLSession Class Reference](https://developer.apple.com/library/mac/documentation/Foundation/Reference/NSURLSession_class/Introduction/Introduction.html#//apple_ref/occ/cl/NSURLSession)
- [NSURLCache Class Reference](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Classes/NSURLCache_Class/Reference/Reference.html#//apple_ref/occ/cl/NSURLCache)
- [NSURLAuthenticationChallenge Class Reference](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Classes/NSURLAuthenticationChallenge_Class/Reference/Reference.html)

### Manager

Top-level convenience methods like `Alamofire.request` use a shared instance of `Alamofire.Manager`, which is configured with the default `NSURLSessionConfiguration`.

As such, the following two statements are equivalent:

```swift
Alamofire.request(.GET, "http://httpbin.org/get")
```

```swift
let manager = Alamofire.Manager.sharedInstance
manager.request(NSURLRequest(URL: NSURL(string: "http://httpbin.org/get")))
```

Applications can create managers for background and ephemeral sessions, as well as new managers that customize properties of the default session configuration, such as default headers (`HTTPAdditionalHeaders`) or timeout interval (`timeoutIntervalForRequest`).

#### Creating a Manager with Default Configuration

```swift
let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
let manager = Alamofire.Manager(configuration: configuration)
```

#### Creating a Manager with Background Configuration

```swift
let configuration = NSURLSessionConfiguration.backgroundSessionConfiguration("com.example.app")
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

Methods like `authenticate`, `validate`, and `response` return the caller in order to facilitate chaining.

Requests can be suspended, resumed, and cancelled:

- `suspend()`: Suspends the underlying task and dispatch queue
- `resume()`: Resumes the underlying task and dispatch queue. If the owning manager does not have `startRequestsImmediately` set to `true`, the request must call `resume()` in order to start.
- `cancel()`: Cancels the underlying task, producing an error that is passed to any registered response handlers.

### URLStringConvertible

Types adopting the `URLStringConvertible` can be used to construct URL strings, which are then used to construct URL requests. Top-level convenience methods taking a `URLStringConvertible` argument are provided to allow for type-safe routing behavior.

Applications interacting with web applications in a significant manner are encouraged to adopt either `URLStringConvertible` or `URLRequestConvertible` as a way to ensure consistency of requested endpoints.

#### Type-Safe Routing

```swift
enum Router: URLStringConvertible {
    static let baseURLString = "http://example.com"

    case Root
    case User(String)
    case Post(Int, Int, String)

    // MARK: URLStringConvertible

    var URLString: String {
        let path: String = {
            switch self {
            case .Root:
                return "/"
            case .User(let username):
                return "/users/\(username)"
            case .Post(let year, let month, let title):
                let slug = title.stringByReplacingOccurrencesOfString(" ", withString: "-").lowercaseString
                return "/\(year)/\(month)/\(slug)"
            }
        }()

        return Router.baseURLString + path
    }
}
```

```swift
Alamofire.request(.GET, Router.User("mattt"))
```

### URLRequestConvertible

Types adopting the `URLRequestConvertible` can be used to construct URL requests. Like `URLStringConvertible`, this is recommended for applications with any significant interactions between client and server.

Top-level and instance methods on `Manager` taking `URLRequestConvertible` arguments are provided as a way to provide type-safe routing. Such an approach can be used to abstract away server-side inconsistencies, as well as manage authentication credentials and other state.

#### API Parameter Abstraction

```swift
enum Router: URLRequestConvertible {
    static let baseURLString = "http://example.com"
    static let perPage = 50

    case Search(query: String, page: Int)

    // MARK: URLRequestConvertible

    var URLRequest: NSURLRequest {
        let (path: String, parameters: [String: AnyObject]?) = {
            switch self {
            case .Search(let query, let page) where page > 1:
                return ("/search", ["q": query, "offset": Router.perPage * page])
            case .Search(let query, _):
                return ("/search", ["q": query])
            }
        }()

        let URL = NSURL(string: Router.baseURLString)
        let URLRequest = NSURLRequest(URL: URL.URLByAppendingPathComponent(path))
        let encoding = Alamofire.ParameterEncoding.URL

        return encoding.encode(URLRequest, parameters: parameters).0
    }
}
```

```swift
Alamofire.request(Router.Search(query: "foo bar", page: 1)) // ?q=foo+bar&offset=50
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

    var URLRequest: NSURLRequest {
        let URL = NSURL(string: Router.baseURLString)
        let mutableURLRequest = NSMutableURLRequest(URL: URL.URLByAppendingPathComponent(path))
        mutableURLRequest.HTTPMethod = method.toRaw()

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

* * *

## Contact

Follow AFNetworking on Twitter ([@AFNetworking](https://twitter.com/AFNetworking))

### Creator

- [Mattt Thompson](http://github.com/mattt) ([@mattt](https://twitter.com/mattt))

## License

Alamofire is released under an MIT license. See LICENSE for more information.
