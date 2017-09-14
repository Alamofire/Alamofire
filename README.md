![Alamofire: Elegant Networking in Swift](https://raw.githubusercontent.com/Alamofire/Alamofire/master/alamofire.png)

[![Build Status](https://travis-ci.org/Alamofire/Alamofire.svg?branch=master)](https://travis-ci.org/Alamofire/Alamofire)
[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/Alamofire.svg)](https://img.shields.io/cocoapods/v/Alamofire.svg)
[![Carthage Compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Platform](https://img.shields.io/cocoapods/p/Alamofire.svg?style=flat)](https://alamofire.github.io/Alamofire)
[![Twitter](https://img.shields.io/badge/twitter-@AlamofireSF-blue.svg?style=flat)](http://twitter.com/AlamofireSF)
[![Gitter](https://badges.gitter.im/Alamofire/Alamofire.svg)](https://gitter.im/Alamofire/Alamofire?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge)

Alamofire is an HTTP networking library written in Swift.

- [Features](#features)
- [Component Libraries](#component-libraries)
- [Requirements](#requirements)
- [Migration Guides](#migration-guides)
- [Communication](#communication)
- [Installation](#installation)
- [Usage](USAGE.md/#usage)
    - **Intro -** [Making a Request](USAGE.md/#making-a-request), [Response Handling](USAGE.md/#response-handling), [Response Validation](USAGE.md/#response-validation), [Response Caching](USAGE.md/#response-caching)
	- **HTTP -** [HTTP Methods](USAGE.md/#http-methods), [Parameter Encoding](USAGE.md/#parameter-encoding), [HTTP Headers](USAGE.md/#http-headers), [Authentication](USAGE.md/#authentication)
	- **Large Data -** [Downloading Data to a File](USAGE.md/#downloading-data-to-a-file), [Uploading Data to a Server](USAGE.md/#uploading-data-to-a-server)
	- **Tools -** [Statistical Metrics](USAGE.md/#statistical-metrics), [cURL Command Output](USAGE.md/#curl-command-output)
- [Advanced Usage](ADVANCED-USAGE.md/#advanced-usage)
	- **URL Session -** [Session Manager](ADVANCED-USAGE.md/#session-manager), [Session Delegate](ADVANCED-USAGE.md/#session-delegate), [Request](ADVANCED-USAGE.md/#request)
	- **Routing -** [Routing Requests](ADVANCED-USAGE.md/#routing-requests), [Adapting and Retrying Requests](ADVANCED-USAGE.md/#adapting-and-retrying-requests)
	- **Model Objects -** [Custom Response Serialization](ADVANCED-USAGE.md/#custom-response-serialization)
	- **Connection -** [Security](ADVANCED-USAGE.md/#security), [Network Reachability](ADVANCED-USAGE.md/#network-reachability)
- [Open Radars](OPEN-RADARS.md/#open-radars)
- [FAQ](FAQ.md/#faq)
- [Credits](CREDITS.md/#credits)
- [Donations](DONATIONS.md/#donations)
- [License](LICENSE.md/#license)

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
- [x] [Complete Documentation](https://alamofire.github.io/Alamofire)

## Component Libraries

In order to keep Alamofire focused specifically on core networking implementations, additional component libraries have been created by the [Alamofire Software Foundation](https://github.com/Alamofire/Foundation) to bring additional functionality to the Alamofire ecosystem.

- [AlamofireImage](https://github.com/Alamofire/AlamofireImage) - An image library including image response serializers, `UIImage` and `UIImageView` extensions, custom image filters, an auto-purging in-memory cache and a priority-based image downloading system.
- [AlamofireNetworkActivityIndicator](https://github.com/Alamofire/AlamofireNetworkActivityIndicator) - Controls the visibility of the network activity indicator on iOS using Alamofire. It contains configurable delay timers to help mitigate flicker and can support `URLSession` instances not managed by Alamofire.

## Requirements

- iOS 8.0+ / macOS 10.10+ / tvOS 9.0+ / watchOS 2.0+
- Xcode 8.3+
- Swift 3.1+

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

> CocoaPods 1.1+ is required to build Alamofire 4.0+.

To integrate Alamofire into your Xcode project using CocoaPods, specify it in your `Podfile`:

```ruby
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '10.0'
use_frameworks!

target '<Your Target Name>' do
    pod 'Alamofire', '~> 4.5'
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
github "Alamofire/Alamofire" ~> 4.5
```

Run `carthage update` to build the framework and drag the built `Alamofire.framework` into your Xcode project.

### Swift Package Manager

The [Swift Package Manager](https://swift.org/package-manager/) is a tool for automating the distribution of Swift code and is integrated into the `swift` compiler. It is in early development, but Alamofire does support its use on supported platforms. 

Once you have your Swift package set up, adding Alamofire as a dependency is as easy as adding it to the `dependencies` value of your `Package.swift`.

```swift
dependencies: [
    .Package(url: "https://github.com/Alamofire/Alamofire.git", majorVersion: 4)
]
```

### Manually

If you prefer not to use any of the aforementioned dependency managers, you can integrate Alamofire into your project manually.

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
