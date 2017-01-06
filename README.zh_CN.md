![Alamofire: Elegant Networking in Swift](https://raw.githubusercontent.com/Alamofire/Alamofire/assets/alamofire.png)

[![Build Status](https://travis-ci.org/Alamofire/Alamofire.svg?branch=master)](https://travis-ci.org/Alamofire/Alamofire)
[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/Alamofire.svg)](https://img.shields.io/cocoapods/v/Alamofire.svg)
[![Carthage Compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Platform](https://img.shields.io/cocoapods/p/Alamofire.svg?style=flat)](http://cocoadocs.org/docsets/Alamofire)
[![Twitter](https://img.shields.io/badge/twitter-@AlamofireSF-blue.svg?style=flat)](http://twitter.com/AlamofireSF)

##[English](README.md)

Alamofire 是 Swift 语言编写的 HTTP 网络库。

- 特性
- 组件
- 使用环境
- 移植指南
- 安装
- 使用
    - **简介 -** 发起请求, 响应回调, 响应验证, 缓存响应
  - **HTTP -** HTTP 方法, 参数编码, HTTP Headers, 认证
  - **大量数据 -** 下载数据到文件中, 上传数据到服务器
    - [高级用法]
  - **URL Session -** 会话管理, 会话代理, 请求
  - **Routing -** 路由请求, [Adapting and Retrying Requests](#adapting-and-retrying-requests)
  - **模型对象 -** 自定义响应序列化器
  - **Connection -** [Security](#security), [Network Reachability](#network-reachability)

## 特性

- 链式的请求/响应方法调用
- URL / JSON / plist 参数编码
- 上传 File / Data / Stream / MultipartFormData
- 通过 Request 或者 Resume Data 下载文件
- Authentication with URLCredential
- HTTP 响应验证
- 上传下载的进度闭包
- cURL Command Output
- Dynamically Adapt and Retry Requests
- TLS Certificate and Public Key Pinning
- Network Reachability
- Comprehensive Unit and Integration Test Coverage

## 组件

为了让 Alamofire 集中于核心网络操作的实现，[Alamofire Software Foundation](https://github.com/Alamofire/Foundation) 采用组件的形式为 Alamofire 添加额外的功能。

- [AlamofireImage](https://github.com/Alamofire/AlamofireImage) - 一个包含图片响应序列化, `UIImage` 和 `UIImageView` 的扩展，自定义图片过滤器，自动清理的内存缓存，基于优先级的图片下载的图片库。
- [AlamofireNetworkActivityIndicator](https://github.com/Alamofire/AlamofireNetworkActivityIndicator) - 控制网络活动指示器的显示。允许用户配置延迟时间来延缓活动指示器的显示，同时也支持独立创建的 `URLSession` 实例对象。

## Requirements

- iOS 8.0+ / macOS 10.10+ / tvOS 9.0+ / watchOS 2.0+
- Xcode 8.1+
- Swift 3.0+

## 移植指南

- [Alamofire 4.0 Migration Guide](https://github.com/Alamofire/Alamofire/blob/master/Documentation/Alamofire%204.0%20Migration%20Guide.md)
- [Alamofire 3.0 Migration Guide](https://github.com/Alamofire/Alamofire/blob/master/Documentation/Alamofire%203.0%20Migration%20Guide.md)
- [Alamofire 2.0 Migration Guide](https://github.com/Alamofire/Alamofire/blob/master/Documentation/Alamofire%202.0%20Migration%20Guide.md)

##安装

### Cocoapods

[CocoaPods](http://cocoapods.org) 是一款 Cocoa 项目的依赖库管理工具。使用下面命令安装 cocoapods：

```bash
$ gem install cocoapods
```

> 编译 Alamofire 4.0.0+ 需要 1.1.0 以上版本的 cocoapods

在 `Podfile` 中进行声明来集成 Alamofire：

```ruby
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '10.0'
use_frameworks!

target '<Your Target Name>' do
    pod 'Alamofire', '~> 4.0'
end
```

然后运行下面的命令进行安装：

```bash
$ pod install
```

### Carthage

[Carthage](https://github.com/Carthage/Carthage) 是一款编译管理依赖库的工具，可提供编译好的 frameworks。

通过 [Homebrew](http://brew.sh/) 使用一下命令安装 Carthage：

```bash
$ brew update
$ brew install carthage
```

在 `Cartfile` 中进行声明来集成 Alamofire：

```ogdl
github "Alamofire/Alamofire" ~> 4.0
```

运行 `carthage update` 命令进行编译，并把编译好的 `Alamofire.framework` 拖拽到你的 Xcode 项目中。

## 使用

### 发起请求

```swift
import Alamofire

Alamofire.request("https://httpbin.org/get")
```

### 处理响应

处理请求的响应只需在 `Request` 后面加上处理响应的回调。

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

上面的例子中，`responseJSON` 回调拼接在 `Request` 后面，一旦网络请求完成便会执行该 `responseJSON`。这里没有阻塞线程来等待响应，而是采用了闭包形式的[回调](http://en.wikipedia.org/wiki/Callback_%28computer_programming%29)来异步接受响应。请求的结果只能在响应的闭包中进行处理。对响应或从服务器接收到的数据只能在响应闭包中处理。

> Alamofire 中网络请求是异步处理的。对异步编程相关的概念不太熟悉的话会让人一头雾水，但有太多的[理由](https://developer.apple.com/library/ios/qa/qa1693/_index.html)让我们采用异步编程。

Alamofire 默认包含五种响应回调：

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

这些回调都没有对 `HTTPURLResponse` 进行验证。

> 比如，`400..499` 和 `500..599` 之间的响应状态码不会自动触发 `Error`。Alamofire 采用 [Response Validation](#response-validation) 的链式方法来进行验证。

#### Response 回调

`response` 不对响应数据进行任何处理，直接把 URL session 代理中的数据交给后面的流程，与使用 `cURL` 执行请求效果一样。


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

强烈建议使用其他响应序列化器将数据变为更易使用的 `Response` 和 `Result` 类型

#### Response Data 回调

`responseData` 回调使用 `responseDataSerializer` (该对象用于将从服务器接收的数据序列化为其他类型) 处理服务器端返回的 `Data`。如果没有错误就返回 `Data`，response 的 `Result` 会被设置为 `.success` `value` 会被设置为 `Data` 类型。

```swift
Alamofire.request("https://httpbin.org/get").responseData { response in
    debugPrint("All Response Info: \(response)")

    if let data = response.result.value, let utf8Text = String(data: data, encoding: .utf8) {
      print("Data: \(utf8Text)")
    }
}
```

#### Response String 回调

`responseString` 回调使用 `responseStringSerializer` 根据指定的编码方式将从服务器接收到的 `Data` 转换为 `String` 类型。如果没有错误并且数据被成功序列化为 `String`，则 response 的 `Result` 会被设置为 `.success`，`value` 会被设置为 `String` 类型。

```swift
Alamofire.request("https://httpbin.org/get").responseString { response in
    print("Success: \(response.result.isSuccess)")
    print("Response String: \(response.result.value)")
}
```

> 如果未指定编码方式，Alamofire 会根据从服务器端接收到的 `HTTPURLResponse` 中的编码方式进行编码。如果响应中也未指定编码方式，默认使用 `.isoLatin1` 编码方式

#### Response JSON 回调

`responseJSON` 使用 `responseJSONSerializer` 根据指定的 `JSONSerialization.ReadingOptions` 将从服务器接收到的数据 `Data` 转换为 `Any` 类型。如果没有错误并且接收到的数据成功的序列化为 JSON 对象，则 response 的 `Result` 会被设置为 `.success` 并且 `value` 会被设置为 `Any` 类型。

```swift
Alamofire.request("https://httpbin.org/get").responseJSON { response in
    debugPrint(response)

    if let json = response.result.value {
        print("JSON: \(json)")
    }
}
```

> JSON 的序列化由 `Foundation` 框架中的 `JSONSerialization` 接口完成。

#### 链式响应回调

响应回调也可以链式调用：

```swift
Alamofire.request("https://httpbin.org/get")
    .responseString { response in
        print("Response String: \(response.result.value)")
    }
    .responseJSON { response in
        print("Response JSON: \(response.result.value)")
    }
```

> 注意：对同一个请求使用多个响应回调需要服务器对数据进行多次序列化，每次序列化针对一个响应回调。

#### 响应回调的操作队列

响应回调默认是在主派发队列中执行。然而可以为响应回调指定自定义的操作队列。

```swift
let utilityQueue = DispatchQueue.global(qos: .utility)

Alamofire.request("https://httpbin.org/get").responseJSON(queue: utilityQueue) { response in
    print("Executing response handler on utility queue")
}
```

### 响应验证

默认情况下 Alamofire 会忽略响应内容是否正确，只要请求完成就标志着成功。在响应回调调用之前调用 `validata` 时，若响应中有错误的网络状态码或错误的 MIME 格式的数据则会抛出错误。

#### 手动验证


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

#### 自动验证

自动验证会验证 `200...299` 之间的状态码并验证响应数据的 `Content-Type` 是否和请求头的指定的 `Accept` 类型是否匹配。

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

### 缓存响应

响应的缓存操作由系统级框架 [`URLCache`](https://developer.apple.com/reference/foundation/urlcache) 完成。其同时提供了内存，硬盘两种缓存方式并且用户可以设置可缓存的大小。

> Alamofire 默认会使用共享的 `URLCache`。查看 [Session Manager Configurations](#session-manager) 进行自定义。

### HTTP Methods

`HTTPMethod` 枚举出了 [RFC 7231 §4.3](http://tools.ietf.org/html/rfc7231#section-4.3) 中定义的 HTTP 方法：

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

可以为 `Alamofire.request` 接口的 `method` 参数设置这些值：

```swift
Alamofire.request("https://httpbin.org/get") // method defaults to `.get`

Alamofire.request("https://httpbin.org/post", method: .post)
Alamofire.request("https://httpbin.org/put", method: .put)
Alamofire.request("https://httpbin.org/delete", method: .delete)
```

> `Alamofire.request` 的 method 参数默认是 `.get`。

### 参数编码

Alamofire 默认提供了三种参数编码方式，包括 `URL`,`JSON`,`PropertyList`。同时也支持遵循了 `ParameterEncoding` 协议的编码方式。

#### URL 编码

`URLEncoding` 编码方式创建了 url 编码的查询字符串并将其拼接到存在的请求字符串后或者设置为 URL 请求的 HTTP body。对于编码后的查询字符串，是直接使用，拼接还是设置为 HTTP body 取决于编码的 `Destination`。`Destination` 包含三种方式：

- `.methodDependent` - 若请求方式是 `GET`,`HEAD`,`DELETE`,则将编码的查询字符串与存在的查询字符串进行拼接，对于其他请求方式则设置为请求的 HTTP body。
- `.queryString` - 将编码的查询字符串与存在的查询字符串进行拼接。
- `.httpBody` - 设置为请求的 HTTP body。

请求头中的 `Content-Type` 字段被设置为 `application/x-www-form-urlencoded; charset=utf-8。URL 编码中并没有规定集合类型该如何进行编码。我们约定，对数组类型将 `[]` 拼接到 key 后面(`foo[]=1&foo[]=2`)，对字典类型将中括号包围的 key 拼接在请求的键后(`foo[bar]=baz`)。

###### 获取使用 URL 编码参数的请求

```swift
let parameters: Parameters = ["foo": "bar"]

// All three of these calls are equivalent
Alamofire.request("https://httpbin.org/get", parameters: parameters) // encoding defaults to `URLEncoding.default`
Alamofire.request("https://httpbin.org/get", parameters: parameters, encoding: URLEncoding.default)
Alamofire.request("https://httpbin.org/get", parameters: parameters, encoding: URLEncoding(destination: .methodDependent))

// https://httpbin.org/get?foo=bar
```

##### 发起使用 URL 编码参数的请求

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

#### JSON 编码

`JSONEncoding` 的编码方式创建了 JSON 格式的请求参数，并设置为请求的 HTTP body。HTTP 请求头的 `Content-Type` 字段设置为 `applicatioin/json`。

##### 发起使用 JSON 编码参数的请求

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

#### 自定义编码

当 Alamofire 提供的参数编码方式不能满足需求时，可以创建自定义的编码方式。下面是一个自定义的 `JSONStringEncoding` 编码方式的例子，该方式将 string 数组的 JSON 对象编码到 `Request` 中。

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

#### 下载数据到文件中

Alamofire 从服务器接收到的数据保存在缓存或硬盘上。到目前为止所有例子中使用 `Alamofire.request` 接口获取的数据都保存在缓存中。对于小数据这是很高效的，但对于较大的数据量可能会耗尽缓存。因此需要使用 `Alamofire.download` 接口将数据保存在硬盘的临时文件中。

```swift
Alamofire.download("https://httpbin.org/image/png").responseData { response in
  if let data = response.result.value {
      let image = UIImage(data: data)
  }
}
```

> 当需要在后台下载数据时也应该使用 `Alamofire.download` 接口。更多信息请查看 [Session Manager Configurations](#session-manager) 章节

#### 下载路径

你可以提供一个 `DownloadFileDestination` 闭包用于把临时文件移动到指定的路径下。在移动临时文件前会先执行闭包中指定的 `DownloadOptioins`。当前支持的两种 `DownloadOptions` 分别是：

- `.createIntermediateDirectories` - 为指定的路径创建完整的路径
- `.removePreviousFile` - 移除目标路径下存在的文件

```swift
let destination: DownloadRequest.DownloadFileDestination = { _, _ in
  let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
  let fileURL = documentsURL.appendPathComponent("pig.png")

    return (fileURL, [.removePreviousFile, .createIntermediateDirectories])
}

Alamofire.download(urlString, to: destination).response { response in
    print(response)

  if response.error == nil, let imagePath = response.destinationURL?.path {
      let image = UIImage(contentsOfFile: imagePath)
  }
}
```

也可以使用推荐下载路径 API。

```swift
let destination = DownloadRequest.suggestedDownloadDestination(directory: .documentDirectory)
Alamofire.download("https://httpbin.org/image/png", to: destination)
```

#### 下载进度

在下载时能够报告下载进度是非常有用的。任何 `DownloadRequest` 请求可以通过 `downloadProgress` 接口报告下载进度。

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

也可以为 `downloadProgress` 接口指定下载进度闭包执行的派发队列。

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

#### 唤醒下载

如果一个 `DownloadRequest` 请求取消或中断了，URL 会话可能会为该请求生成恢复数据，该恢复数据可用于 `DownloadRequest` 请求从中断的地方恢复下载。恢复数据可以从下载响应中获取，然后用于恢复下载。


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

### 上传数据到服务器

上传少量的数据到服务器可以采用 JSON 或者 URL 编码参数的方式进行，这时 `Alamofire.request` 接口通常很高效。当需要上传的数据较大，比如文件或者 `InputStream`，这时需要使用 `Alamofire.upload` 接口。

> 当需要在后台上传数据时也应该使用 `Alamofire.upload`，更多信息请查看 [Session Manager Configurations](#session-manager) 章节。

#### 上传数据

```swift
let imageData = UIPNGRepresentation(image)!

Alamofire.upload(imageData, to: "https://httpbin.org/post").responseJSON { response in
    debugPrint(response)
}
```

#### 上传文件

```swift
let fileURL = Bundle.main.url(forResource: "video", withExtension: "mov")

Alamofire.upload(fileURL, to: "https://httpbin.org/post").responseJSON { response in
    debugPrint(response)
}
```

#### 上传多格式表单数据


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

#### 上传进度

当用户在上传时能够显示上传进度是非常友好的。任何 `UploadRequest` 请求都能通过 `uploadProgress` 和 `doanloadProgress` 接口报告上传进度和下载进度。


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

## 高级用法

Alamofire 建立在 `URLSession` 和 URL 加载系统上。为了更好的使用该框架，强烈建议要非常熟悉底层网络栈的相关概念

**推荐阅读**

- [URL 加载系统编程指南](https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/URLLoadingSystem/URLLoadingSystem.html)
- [URLSession Class Reference](https://developer.apple.com/reference/foundation/nsurlsession)
- [URLCache Class Reference](https://developer.apple.com/reference/foundation/urlcache)
- [URLAuthenticationChallenge Class Reference](https://developer.apple.com/reference/foundation/urlauthenticationchallenge)

### 请求

`request`,`download`,`upload`,`stream` 等方法的返回值  `DataRequest`, `DownloadRequest`, `UploadRequest` 和 `StreamRequest` 均是继承于 `Request`。所有的 `Request` 实例都是由自己的会话管理对象创建，并且不会直接初始化。

每个子类都有一些特殊的方法比如 `authenticate`, `validate`, `responseJSON` 和 `uploadProgress`，这些方法均返回调用者以便可以进行链式调用。

请求可以被挂起，恢复，取消：

- `suspend()`: 挂起底层任务和派发队列。
- `resume()`: 恢复任务和派发队列。如果会话管理对象没有设置 `startRequestsImmediately` 为 `true`，那么请求需要调用 `resume()` 才能开始。
- `cancel()`: 取消任务，产生错误信息并将错误信息传递到响应回调。

### 路由请求

随着 App 变得复杂，使用通用模式创建你自己的网络栈就变得非常重要了。其中一个重要的设计就是如何路由你的请求。遵循 `URLConvertible` 和 `URLRequestConvertible` 协议的 `Router` 就变得非常有用。

#### URLConvertible

遵循 `URLConvertible` 协议的类可以用来构造 URLs，然后将 URLs 用来构造 URL 请求。`String`, `URL`, 和 `URLComponents` 都遵循了 `URLConvertible` 协议，这三个类的对象均可以作为 `url` 参数传递给 `request`, `upload`, 和 `download` 方法:

```swift
let urlString = "https://httpbin.org/post"
Alamofire.request(urlString, method: .post)

let url = URL(string: urlString)!
Alamofire.request(url, method: .post)

let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)
Alamofire.request(.post, URLComponents)
```
##### API 抽象参数


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

* * * 
