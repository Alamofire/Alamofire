![Alamofire: Elegant Networking in Swift](https://raw.githubusercontent.com/Alamofire/Alamofire/master/Resources/AlamofireLogo.png)

[![Swift](https://img.shields.io/badge/Swift-5.1_5.2_5.3_5.4-orange?style=flat-square)](https://img.shields.io/badge/Swift-5.1_5.2_5.3_5.4-Orange?style=flat-square)
[![Platforms](https://img.shields.io/badge/Platforms-macOS_iOS_tvOS_watchOS_Linux_Windows-yellowgreen?style=flat-square)](https://img.shields.io/badge/Platforms-macOS_iOS_tvOS_watchOS_Linux_Windows-Green?style=flat-square)
[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/Alamofire.svg?style=flat-square)](https://img.shields.io/cocoapods/v/Alamofire.svg)
[![Carthage Compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat-square)](https://github.com/Carthage/Carthage)
[![Swift Package Manager](https://img.shields.io/badge/Swift_Package_Manager-compatible-orange?style=flat-square)](https://img.shields.io/badge/Swift_Package_Manager-compatible-orange?style=flat-square)
[![Twitter](https://img.shields.io/badge/twitter-@AlamofireSF-blue.svg?style=flat-square)](https://twitter.com/AlamofireSF)
[![Swift Forums](https://img.shields.io/badge/Swift_Forums-Alamofire-orange?style=flat-square)](https://forums.swift.org/c/related-projects/alamofire/37)

Alamofire is an HTTP networking library written in Swift.

- [Features](#features)
- [Component Libraries](#component-libraries)
- [Requirements](#requirements)
- [Migration Guides](#migration-guides)
- [Communication](#communication)
- [Installation](#installation)
- [Usage](https://github.com/Alamofire/Alamofire/blob/master/Documentation/Usage.md#using-alamofire)
    - [**Introduction -**](https://github.com/Alamofire/Alamofire/blob/master/Documentation/Usage.md#introduction) [Making Requests](https://github.com/Alamofire/Alamofire/blob/master/Documentation/Usage.md#making-requests), [Response Handling](https://github.com/Alamofire/Alamofire/blob/master/Documentation/Usage.md#response-handling), [Response Validation](https://github.com/Alamofire/Alamofire/blob/master/Documentation/Usage.md#response-validation), [Response Caching](https://github.com/Alamofire/Alamofire/blob/master/Documentation/Usage.md#response-caching)
	- **HTTP -** [HTTP Methods](https://github.com/Alamofire/Alamofire/blob/master/Documentation/Usage.md#http-methods), [Parameters and Parameter Encoder](https://github.com/Alamofire/Alamofire/blob/master/Documentation/Usage.md##request-parameters-and-parameter-encoders), [HTTP Headers](https://github.com/Alamofire/Alamofire/blob/master/Documentation/Usage.md#http-headers), [Authentication](https://github.com/Alamofire/Alamofire/blob/master/Documentation/Usage.md#authentication)
	- **Large Data -** [Downloading Data to a File](https://github.com/Alamofire/Alamofire/blob/master/Documentation/Usage.md#downloading-data-to-a-file), [Uploading Data to a Server](https://github.com/Alamofire/Alamofire/blob/master/Documentation/Usage.md#uploading-data-to-a-server)
	- **Tools -** [Statistical Metrics](https://github.com/Alamofire/Alamofire/blob/master/Documentation/Usage.md#statistical-metrics), [cURL Command Output](https://github.com/Alamofire/Alamofire/blob/master/Documentation/Usage.md#curl-command-output)
- [Advanced Usage](https://github.com/Alamofire/Alamofire/blob/master/Documentation/AdvancedUsage.md)
	- **URL Session -** [Session Manager](https://github.com/Alamofire/Alamofire/blob/master/Documentation/AdvancedUsage.md#session), [Session Delegate](https://github.com/Alamofire/Alamofire/blob/master/Documentation/AdvancedUsage.md#sessiondelegate), [Request](https://github.com/Alamofire/Alamofire/blob/master/Documentation/AdvancedUsage.md#request)
	- **Routing -** [Routing Requests](https://github.com/Alamofire/Alamofire/blob/master/Documentation/AdvancedUsage.md#routing-requests), [Adapting and Retrying Requests](https://github.com/Alamofire/Alamofire/blob/master/Documentation/AdvancedUsage.md#adapting-and-retrying-requests-with-requestinterceptor)
	- **Model Objects -** [Custom Response Handlers](https://github.com/Alamofire/Alamofire/blob/master/Documentation/AdvancedUsage.md#customizing-response-handlers)
	- **Connection -** [Security](https://github.com/Alamofire/Alamofire/blob/master/Documentation/AdvancedUsage.md#security), [Network Reachability](https://github.com/Alamofire/Alamofire/blob/master/Documentation/AdvancedUsage.md#network-reachability)
- [Open Radars](#open-radars)
- [FAQ](#faq)
- [Credits](#credits)
- [Donations](#donations)
- [License](#license)

## Features

- [x] Chainable Request / Response Methods
- [x] Combine Support
- [x] URL / JSON Parameter Encoding
- [x] Upload File / Data / Stream / MultipartFormData
- [x] Download File using Request or Resume Data
- [x] Authentication with `URLCredential`
- [x] HTTP Response Validation
- [x] Upload and Download Progress Closures with Progress
- [x] cURL Command Output
- [x] Dynamically Adapt and Retry Requests
- [x] TLS Certificate and Public Key Pinning
- [x] Network Reachability
- [x] Comprehensive Unit and Integration Test Coverage
- [x] [Complete Documentation](https://alamofire.github.io/Alamofire)

## Component Libraries

In order to keep Alamofire focused specifically on core networking implementations, additional component libraries have been created by the [Alamofire Software Foundation](https://github.com/Alamofire/Foundation) to bring additional functionality to the Alamofire ecosystem.

- [AlamofireImage](https://github.com/Alamofire/AlamofireImage) - An image library including image response serializers, `UIImage` and `UIImageView` extensions, custom image filters, an auto-purging in-memory cache, and a priority-based image downloading system.
- [AlamofireNetworkActivityIndicator](https://github.com/Alamofire/AlamofireNetworkActivityIndicator) - Controls the visibility of the network activity indicator on iOS using Alamofire. It contains configurable delay timers to help mitigate flicker and can support `URLSession` instances not managed by Alamofire.

## Requirements

| Platform | Minimum Swift Version | Installation | Status |
| --- | --- | --- | --- |
| iOS 10.0+ / macOS 10.12+ / tvOS 10.0+ / watchOS 3.0+ | 5.1 | [CocoaPods](#cocoapods), [Carthage](#carthage), [Swift Package Manager](#swift-package-manager), [Manual](#manually) | Fully Tested |
| Linux | Latest Only | [Swift Package Manager](#swift-package-manager) | Building But Unsupported |
| Windows | Latest Only | [Swift Package Manager](#swift-package-manager) | Building But Unsupported |

#### Known Issues on Linux and Windows

Alamofire builds on Linux and Windows but there are missing features and many issues in the underlying `swift-corelibs-foundation` that prevent full functionality and may cause crashes. These include:
- `ServerTrustManager` and associated certificate functionality is unavailable, so there is no certificate pinning and no client certificate support.
- Various methods of HTTP authentication may crash, including HTTP Basic and HTTP Digest. Crashes may occur if responses contain server challenges.
- Cache control through `CachedResponseHandler` and associated APIs is unavailable, as the underlying delegate methods aren't called.
- `URLSessionTaskMetrics` are never gathered.

Due to these issues, Alamofire is unsupported on Linux and Windows. Please report any crashes to the [Swift bug reporter](https://bugs.swift.org).

## Migration Guides

- [Alamofire 5.0 Migration Guide](https://github.com/Alamofire/Alamofire/blob/master/Documentation/Alamofire%205.0%20Migration%20Guide.md)
- [Alamofire 4.0 Migration Guide](https://github.com/Alamofire/Alamofire/blob/master/Documentation/Alamofire%204.0%20Migration%20Guide.md)
- [Alamofire 3.0 Migration Guide](https://github.com/Alamofire/Alamofire/blob/master/Documentation/Alamofire%203.0%20Migration%20Guide.md)
- [Alamofire 2.0 Migration Guide](https://github.com/Alamofire/Alamofire/blob/master/Documentation/Alamofire%202.0%20Migration%20Guide.md)

## Communication
- If you **need help with making network requests** using Alamofire, use [Stack Overflow](https://stackoverflow.com/questions/tagged/alamofire) and tag `alamofire`.
- If you need to **find or understand an API**, check [our documentation](http://alamofire.github.io/Alamofire/) or [Apple's documentation for `URLSession`](https://developer.apple.com/documentation/foundation/url_loading_system), on top of which Alamofire is built.
- If you need **help with an Alamofire feature**, use [our forum on swift.org](https://forums.swift.org/c/related-projects/alamofire).
- If you'd like to **discuss Alamofire best practices**, use [our forum on swift.org](https://forums.swift.org/c/related-projects/alamofire).
- If you'd like to **discuss a feature request**, use [our forum on swift.org](https://forums.swift.org/c/related-projects/alamofire). 
- If you **found a bug**, open an issue here on GitHub and follow the guide. The more detail the better!
- If you **want to contribute**, submit a pull request!

## Installation

### CocoaPods

[CocoaPods](https://cocoapods.org) is a dependency manager for Cocoa projects. For usage and installation instructions, visit their website. To integrate Alamofire into your Xcode project using CocoaPods, specify it in your `Podfile`:

```ruby
pod 'Alamofire', '~> 5.4'
```

### Carthage

[Carthage](https://github.com/Carthage/Carthage) is a decentralized dependency manager that builds your dependencies and provides you with binary frameworks. To integrate Alamofire into your Xcode project using Carthage, specify it in your `Cartfile`:

```ogdl
github "Alamofire/Alamofire" ~> 5.4
```

### Swift Package Manager

The [Swift Package Manager](https://swift.org/package-manager/) is a tool for automating the distribution of Swift code and is integrated into the `swift` compiler. It is in early development, but Alamofire does support its use on supported platforms.

Once you have your Swift package set up, adding Alamofire as a dependency is as easy as adding it to the `dependencies` value of your `Package.swift`.

```swift
dependencies: [
    .package(url: "https://github.com/Alamofire/Alamofire.git", .upToNextMajor(from: "5.4.0"))
]
```

### Manually

If you prefer not to use any of the aforementioned dependency managers, you can integrate Alamofire into your project manually.

#### Embedded Framework

- Open up Terminal, `cd` into your top-level project directory, and run the following command "if" your project is not initialized as a git repository:

  ```bash
  $ git init
  ```

- Add Alamofire as a git [submodule](https://git-scm.com/docs/git-submodule) by running the following command:

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

- Select the top `Alamofire.framework` for iOS and the bottom one for macOS.

    > You can verify which one you selected by inspecting the build log for your project. The build target for `Alamofire` will be listed as `Alamofire iOS`, `Alamofire macOS`, `Alamofire tvOS`, or `Alamofire watchOS`.

- And that's it!

  > The `Alamofire.framework` is automagically added as a target dependency, linked framework and embedded framework in a copy files build phase which is all you need to build on the simulator and a device.

## Open Radars

The following radars have some effect on the current implementation of Alamofire.

- [`rdar://21349340`](http://www.openradar.me/radar?id=5517037090635776) - Compiler throwing warning due to toll-free bridging issue in the test case
- `rdar://26870455` - Background URL Session Configurations do not work in the simulator
- `rdar://26849668` - Some URLProtocol APIs do not properly handle `URLRequest`

## Resolved Radars

The following radars have been resolved over time after being filed against the Alamofire project.

- [`rdar://26761490`](http://www.openradar.me/radar?id=5010235949318144) - Swift string interpolation causing memory leak with common usage.
  - (Resolved): 9/1/17 in Xcode 9 beta 6.
- [`rdar://36082113`](http://openradar.appspot.com/radar?id=4942308441063424) - `URLSessionTaskMetrics` failing to link on watchOS 3.0+
  - (Resolved): Just add `CFNetwork` to your linked frameworks.
- `FB7624529` - `urlSession(_:task:didFinishCollecting:)` never called on watchOS
  - (Resolved): Metrics now collected on watchOS 7+.

## FAQ

### What's the origin of the name Alamofire?

Alamofire is named after the [Alamo Fire flower](https://aggie-horticulture.tamu.edu/wildseed/alamofire.html), a hybrid variant of the Bluebonnet, the official state flower of Texas.

## Credits

Alamofire is owned and maintained by the [Alamofire Software Foundation](http://alamofire.org). You can follow them on Twitter at [@AlamofireSF](https://twitter.com/AlamofireSF) for project updates and releases.

### Security Disclosure

If you believe you have identified a security vulnerability with Alamofire, you should report it as soon as possible via email to security@alamofire.org. Please do not post it to a public issue tracker.

## Donations

The [ASF](https://github.com/Alamofire/Foundation#members) is looking to raise money to officially stay registered as a federal non-profit organization.
Registering will allow Foundation members to gain some legal protections and also allow us to put donations to use, tax-free.
Donating to the ASF will enable us to:

- Pay our yearly legal fees to keep the non-profit in good status
- Pay for our mail servers to help us stay on top of all questions and security issues
- Potentially fund test servers to make it easier for us to test the edge cases
- Potentially fund developers to work on one of our projects full-time

The community adoption of the ASF libraries has been amazing.
We are greatly humbled by your enthusiasm around the projects and want to continue to do everything we can to move the needle forward.
With your continued support, the ASF will be able to improve its reach and also provide better legal safety for the core members.
If you use any of our libraries for work, see if your employers would be interested in donating.
Any amount you can donate today to help us reach our goal would be greatly appreciated.

[![paypal](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=W34WPEE74APJQ)

## Supporters

[MacStadium](https://macstadium.com) provides Alamofire with a free, hosted Mac mini.

![Powered by MacStadium](https://raw.githubusercontent.com/Alamofire/Alamofire/master/Resources/MacStadiumLogo.png)

## License

Alamofire is released under the MIT license. [See LICENSE](https://github.com/Alamofire/Alamofire/blob/master/LICENSE) for details.
