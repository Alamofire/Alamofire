![Alamofire: Elegant Networking in Swift](https://raw.githubusercontent.com/Alamofire/Alamofire/assets/alamofire.png)

Alamofire is an HTTP networking library written in Swift. Think of it as [AFNetworking](https://github.com/afnetworking/afnetworking), reimagined for the conventions of this new language.

Of course, AFNetworking remains the premiere networking library available for Mac OS X and iOS, and can easily be used in Swift, just like any other Objective-C code. **AFNetworking is stable and reliable, and isn't going anywhere.** But for anyone looking for something a little more idiomatic to Swift, Alamofire may be right up your alley. (It's not a mutually-exclusive choice, either! AFNetworking & Alamofire will peacefully co-exist within the same codebase.)

> Alamofire is named after the [Alamo Fire flower](https://aggie-horticulture.tamu.edu/wildseed/alamofire.html), a hybrid variant of the Bluebonnet, the official state flower of Texas.

## Features

- Chainable Request / Response methods
- URL / JSON / plist Parameter Encoding
- Upload File / Data / Stream
- Download using Request or Resume data
- Authentication with NSURLCredential
- Progress Closure & NSProgress
- cURL Debug Output

### Planned for 1.0 Release*

_* Scheduled to coincide with Swift 1.0 release_

- 100% Unit Test Coverage
- Complete Documentation
- HTTP Response Validation
- TLS Chain Validation
- UIKit / AppKit Extensions

## Requirements

- Xcode 6 Beta 6
- iOS 7.0+ / Mac OS X 10.9+

## Installation

_The infrastructure and best practices for distributing Swift libraries is currently in flux during this beta period of the language and Xcode. In the meantime, you can simply add Alamofire as a git submodule, drag the `Alamofire.xcodeproj` file into your Xcode project, and add the framework product as a dependency for your application target. (This is how the example project is structured)_

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

```swift
enum ParameterEncoding {
    case URL
    case JSON(options: NSJSONWritingOptions)
    case PropertyList(format: NSPropertyListFormat,
                      options: NSPropertyListWriteOptions)

    func encode(request: NSURLRequest,
                parameters: [String: AnyObject]?) ->
                    (NSURLRequest, NSError?)
    { ... }
}
```

#### Manual Parameter Encoding of an NSURLRequest

```swift
let URL = NSURL(string: "http://httpbin.org/get")
var request = NSURLRequest(URL: URL)

let parameters = ["foo": "bar"]
let encoding = Alamofire.ParameterEncoding.URL
(request, _) = encoding.encode(request, parameters)
```

### POST Request with JSON Response

```swift
Alamofire.request(.POST, "http://httpbin.org/post", parameters: parameters, encoding: .JSON(options: nil))
         .responseJSON {(request, response, JSON, error) in
            println(JSON)
         }
```

#### Built-In Response Methods

- `response()`
- `responseString(encoding: NSStringEncoding)`
- `responseJSON(options: NSJSONReadingOptions)`
- `responsePropertyList(options: NSPropertyListReadOptions)`

### Uploading

#### Supported Upload Types

- File
- Data
- Stream
- Multipart (Coming Soon)

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

        return directoryURL.URLByAppendingPathComponent(pathComponent)
    }

    return temporaryURL
})
```

#### Using the Default Download Destination Closure Function

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

#### Supported Authentication Schemes

- HTTP Basic
- HTTP Digest
- Kerberos
- NTLM

#### HTTP Basic Authentication

```swift
let user = "user"
let password = "password"

Alamofire.request(.GET, "https://httpbin.org/basic-auth/\(user)/\(password)")
    .authenticate(HTTPBasic: user, password: password)
    .response {(request, response, _, error) in
        println(response)
    }
```

#### Authenticating with NSURLCredential & NSURLProtectionSpace

```swift
let user = "user"
let password = "password"

let credential = NSURLCredential(user: user, password: password, persistence: .ForSession)
let protectionSpace = NSURLProtectionSpace(host: "httpbin.org", port: 0, `protocol`: "https", realm: nil, authenticationMethod: NSURLAuthenticationMethodHTTPBasic)
```

```swift
Alamofire.request(.GET, "https://httpbin.org/basic-auth/\(user)/\(password)")
    .authenticate(usingCredential: credential, forProtectionSpace: protectionSpace)
    .response {(request, response, _, error) in
        println(response)
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

### More Complex Use Cases

Much of the functionality described above is provided as a convenience API on top of something more extensible, closer to the Foundation URL Loading System. For more complex usage, such as creating a `NSURLSession` with a custom configuration or passing `NSURLRequest` objects directly, Alamofire provides API that can accommodate that.

See the implementation of the `Alamofire.Manager` and `Alamofire.Request` classes for details on what's possible. Documentation and additional API refinement are forthcoming in future releases.

---

## Contact

Follow AFNetworking on Twitter ([@AFNetworking](https://twitter.com/AFNetworking))

### Creator

- [Mattt Thompson](http://github.com/mattt) ([@mattt](https://twitter.com/mattt))

## License

Alamofire is released under an MIT license. See LICENSE for more information.
