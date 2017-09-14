![Alamofire: Elegant Networking in Swift](https://raw.githubusercontent.com/Alamofire/Alamofire/master/alamofire.png)

[![Build Status](https://travis-ci.org/Alamofire/Alamofire.svg?branch=master)](https://travis-ci.org/Alamofire/Alamofire)
[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/Alamofire.svg)](https://img.shields.io/cocoapods/v/Alamofire.svg)
[![Carthage Compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Platform](https://img.shields.io/cocoapods/p/Alamofire.svg?style=flat)](https://alamofire.github.io/Alamofire)
[![Twitter](https://img.shields.io/badge/twitter-@AlamofireSF-blue.svg?style=flat)](http://twitter.com/AlamofireSF)
[![Gitter](https://badges.gitter.im/Alamofire/Alamofire.svg)](https://gitter.im/Alamofire/Alamofire?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge)

- [Features](README.md/#features)
- [Component Libraries](README.md/#component-libraries)
- [Requirements](README.md/#requirements)
- [Migration Guides](README.md/#migration-guides)
- [Communication](README.md/#communication)
- [Installation](README.md/#installation)
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
- [Credits](#credits)
- [Donations](DONATIONS.md/#donations)
- [License](LICENSE.md/#license)

## Credits

Alamofire is owned and maintained by the [Alamofire Software Foundation](http://alamofire.org). You can follow them on Twitter at [@AlamofireSF](https://twitter.com/AlamofireSF) for project updates and releases.

### Security Disclosure

If you believe you have identified a security vulnerability with Alamofire, you should report it as soon as possible via email to security@alamofire.org. Please do not post it to a public issue tracker.
