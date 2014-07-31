# Alamofire
*Elegant Networking in Swift*

---

## Usage

### GET Request

```swift
Alamofire.request(.GET, "http://httpbin.org/get")
```

#### With Parameters

```swift
Alamofire.request(.GET,
                  "http://httpbin.org/get",
                  parameters: ["foo": "bar"])
```

#### With Response Handling

```swift
Alamofire.request(.GET,
                  "http://httpbin.org/get",
                  parameters: ["foo": "bar"])
         .response { (request, response, data, error) in
                     println(request)
                     println(response)
                     println(error)
                   }
```

#### With Response String Handling

```swift
Alamofire.request(.GET,
                  "http://httpbin.org/get",
                  parameters: ["foo": "bar"])
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

Alamofire.request(.POST,
                  "http://httpbin.org/post",
                  parameters: parameters)
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
Alamofire.request(.POST,
                  "http://httpbin.org/post",
                  parameters: parameters,
                  encoding: .JSON(options: nil))
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

Alamofire.upload(.POST,
                 "http://httpbin.org/post",
                 file: fileURL)
```

#### Uploading w/Progress

```swift
Alamofire.upload(.POST,
                 "http://httpbin.org/post",
                 file: fileURL)
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
Alamofire.download(.GET,
                  "http://httpbin.org/stream/100",
                  destination: { (temporaryURL, response) in
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
let destination =
    Alamofire.Request.suggestedDownloadDestination(directory: .DocumentDirectory,
                                                   domain: .UserDomainMask)

Alamofire.download(.GET,
                   "http://httpbin.org/stream/100",
                   destination: destination)

#### Downloading a File w/Progress

```swift
Alamofire.download(.GET,
                   "http://httpbin.org/stream/100",
                   destination: destination)
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

let credential = NSURLCredential(user: user,
                                 password: password,
                                 persistence: .ForSession)
let protectionSpace = NSURLProtectionSpace(host: "httpbin.org",
                                           port: 0,
                                           `protocol`: "https",
                                           realm: nil, authenticationMethod: NSURLAuthenticationMethodHTTPBasic)
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
let request = Alamofire.request(.GET,
                                "http://httpbin.org/get",
                                parameters: ["foo": "bar"])

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

### typealias

```swift
typealias AF = Alamofire
```

```swift
AF.request(.GET, "http://httpbin.org/ip")
```

---

## Contact

Follow AFNetworking on Twitter ([@AFNetworking](https://twitter.com/AFNetworking))

### Creator

- [Mattt Thompson](http://github.com/mattt) ([@mattt](https://twitter.com/mattt))

## License

Alamofire is released under an MIT license. See LICENSE for more information.
