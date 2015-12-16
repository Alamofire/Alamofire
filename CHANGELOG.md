# Change Log
All notable changes to this project will be documented in this file.
`Alamofire` adheres to [Semantic Versioning](http://semver.org/).

#### 3.x Releases
- `3.1.x` Releases - [3.1.0](#310) | [3.1.1](#311) | [3.1.2](#312) | [3.1.3](#313)
- `3.0.x` Releases - [3.0.0](#300) | [3.0.1](#301)
- `3.0.0` Betas - [3.0.0-beta.1](#300-beta1) | [3.0.0-beta.2](#300-beta2) | [3.0.0-beta.3](#300-beta3)

#### 2.x Releases
- `2.0.x` Releases - [2.0.0](#200) | [2.0.1](#201) | [2.0.2](#202)
- `2.0.0` Betas - [2.0.0-beta.1](#200-beta1) | [2.0.0-beta.2](#200-beta2) | [2.0.0-beta.3](#200-beta3) | [2.0.0-beta.4](#200-beta4)

#### 1.x Releases
- `1.3.x` Releases - [1.3.0](#130) | [1.3.1](#131)
- `1.2.x` Releases - [1.2.0](#120) | [1.2.1](#121) | [1.2.2](#122) | [1.2.3](#123)
- `1.1.x` Releases - [1.1.0](#110) | [1.1.1](#111) | [1.1.2](#112) | [1.1.3](#113) | [1.1.4](#114) | [1.1.5](#115)
- `1.0.x` Releases - [1.0.0](#100) | [1.0.1](#101)

---

## [3.1.3](https://github.com/Alamofire/Alamofire/releases/tag/3.1.3)
Released on 2015-11-22. All issues associated with this milestone can be found using this
[filter](https://github.com/Alamofire/Alamofire/issues?utf8=✓&q=milestone%3A3.1.3).

#### Added
- Custom `Info.plist` for tvOS setting the `UIRequiredDeviceCapabilities` to `arm64`.
  - Added by [Simon Støvring](https://github.com/simonbs) in Pull Request
  [#913](https://github.com/Alamofire/Alamofire/pull/913).

#### Updated
- All code samples in the README to use `https` instead of `http`.
  - Updated by [Tomonobu Sato](https://github.com/tmnb) in Pull Request
  [#912](https://github.com/Alamofire/Alamofire/pull/912).

## [3.1.2](https://github.com/Alamofire/Alamofire/releases/tag/3.1.2)
Released on 2015-11-06. All issues associated with this milestone can be found using this
[filter](https://github.com/Alamofire/Alamofire/issues?utf8=✓&q=milestone%3A3.1.2).

#### Updated
- Code signing on iOS simulator builds to not sign simulator builds.
  - Updated by [John Heaton](https://github.com/JRHeaton) in Pull Request
  [#903](https://github.com/Alamofire/Alamofire/pull/903).
- Code signing on watchOS and tvOS simulators builds to not sign simulator builds.
  - Updated by [Christian Noon](https://github.com/cnoon).

## [3.1.1](https://github.com/Alamofire/Alamofire/releases/tag/3.1.1)
Released on 2015-10-31. All issues associated with this milestone can be found using this
[filter](https://github.com/Alamofire/Alamofire/issues?utf8=✓&q=milestone%3A3.1.1).

#### Added
- Support for 204 response status codes in the response serializers.
  - Added by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#889](https://github.com/Alamofire/Alamofire/pull/889).
- ATS section to the README explaining how to configure the settings.
  - Added by [Christian Noon](https://github.com/cnoon) in regards to Issue
  [#876](https://github.com/Alamofire/Alamofire/issues/876).

#### Updated
- Several unnecessary uses of `NSString` with `String`.
  - Updated by [Nicholas Maccharoli](https://github.com/Nirma) in Pull Request
  [#885](https://github.com/Alamofire/Alamofire/pull/885).
- Content type validation to always succeeds when server data is `nil` or zero length.
  - Updated by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#890](https://github.com/Alamofire/Alamofire/pull/890).

#### Removed
- The mention of rdar://22307360 from the README since Xcode 7.1 has been released.
  - Removed by [Elvis Nuñez](https://github.com/3lvis) in Pull Request
  [#891](https://github.com/Alamofire/Alamofire/pull/891).
- An unnecessary availability check now that Xcode 7.1 is out of beta.
  - Removed by [Christian Noon](https://github.com/cnoon).
- The playground from the project due to instability reasons.
  - Removed by [Christian Noon](https://github.com/cnoon).
- The data length checks in the `responseData` and `responseString` serializers.
  - Removed by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#889](https://github.com/Alamofire/Alamofire/pull/889).

## [3.1.0](https://github.com/Alamofire/Alamofire/releases/tag/3.1.0)
Released on 2015-10-22. All issues associated with this milestone can be found using this
[filter](https://github.com/Alamofire/Alamofire/issues?utf8=✓&q=milestone%3A3.1.0).

#### Added
- New tvOS framework and test targets to the project.
  - Added by [Bob Scarano](https://github.com/bscarano) in Pull Request
  [#767](https://github.com/Alamofire/Alamofire/pull/767).
- The tvOS deployment target to the podspec.
  - Added by [Christian Noon](https://github.com/cnoon).
- The `BITCODE_GENERATION_MODE` user defined setting to tvOS framework target.
  - Added by [Christian Noon](https://github.com/cnoon).

#### Updated
- The README to include tvOS and bumped the required version of Xcode.
  - Updated by [Christian Noon](https://github.com/cnoon).
- The default tvOS and watchOS deployment targets in the Xcode project.
  - Updated by [Christian Noon](https://github.com/cnoon).
- The `APPLICATION_EXTENSION_API_ONLY` enabled flag to `YES` in the tvOS framework target.
  - Updated by [James Barrow](https://github.com/Baza207) in Pull Request
  [#771](https://github.com/Alamofire/Alamofire/pull/771).
- The Travis-CI yaml file to run watchOS and tvOS builds and tests on xcode7.1 osx_image.
  - Updated by [Christian Noon](https://github.com/cnoon).

---

## [3.0.1](https://github.com/Alamofire/Alamofire/releases/tag/3.0.1)
Released on 2015-10-19. All issues associated with this milestone can be found using this
[filter](https://github.com/Alamofire/Alamofire/issues?utf8=✓&q=milestone%3A3.0.1).

#### Added
- Tests around content type validation with accept parameters.
  - Added by [Christian Noon](https://github.com/cnoon).

#### Fixed
- Content type validation issue where parameter parsing on `;` was incorrect.
  - Fixed by [Christian Noon](https://github.com/cnoon).

## [3.0.0](https://github.com/Alamofire/Alamofire/releases/tag/3.0.0)
Released on 2015-10-10. All issues associated with this milestone can be found using this
[filter](https://github.com/Alamofire/Alamofire/issues?utf8=✓&q=milestone%3A3.0.0).

#### Updated
- `Downloading a File` code sample in the README to compile against Swift 2.0.
  - Updated by [Screon](https://github.com/Screon) in Pull Request
  [#827](https://github.com/Alamofire/Alamofire/pull/827).
- Download code samples in the README to use `response` serializer.
  - Updated by [Christian Noon](https://github.com/cnoon).
- CocoaPods and Carthage installation instructions for 3.0.
  - Updated by [Christian Noon](https://github.com/cnoon).
- Carthage description and installation instructions in the README.
  - Updated by [Ashton Williams](https://github.com/Ashton-W) in Pull Request
  [#843](https://github.com/Alamofire/Alamofire/pull/843).
- URL encoding internals to leverage the dictionary keys lazy evaluation.
  - Updated by [Christian Noon](https://github.com/cnoon).

#### Fixed
- Small typo in the Alamofire 3.0 Migration Guide `Response` section.
  - Fixed by [neugartf](https://github.com/neugartf) in Pull Request
  [#826](https://github.com/Alamofire/Alamofire/pull/826).
- User defined `BITCODE_GENERATION_MODE` setting for Carthage builds.
  - Fixed by [Christian Noon](https://github.com/cnoon) in regards to Issue
  [#835](https://github.com/Alamofire/Alamofire/issues/835).

---

## [3.0.0-beta.3](https://github.com/Alamofire/Alamofire/releases/tag/3.0.0-beta.3)
Released on 2015-09-27. All issues associated with this milestone can be found using this
[filter](https://github.com/Alamofire/Alamofire/issues?utf8=✓&q=milestone%3A3.0.0-beta.3).

#### Updated
- The `Response` initializer to have a `public` ACL instead of `internal`.
  - Updated by [Christian Noon](https://github.com/cnoon).

## [3.0.0-beta.2](https://github.com/Alamofire/Alamofire/releases/tag/3.0.0-beta.2)
Released on 2015-09-26. All issues associated with this milestone can be found using this
[filter](https://github.com/Alamofire/Alamofire/issues?utf8=✓&q=milestone%3A3.0.0-beta.2).

#### Added
- Tests around the header behavior for redirected requests.
  - Added by [Christian Noon](https://github.com/cnoon) in regards to Issue
  [#798](https://github.com/Alamofire/Alamofire/issues/798).
- A migration guide for Alamofire 3.0 documenting all API changes.
  - Added by [Christian Noon](https://github.com/cnoon).

#### Updated
- `Response` initializer to have `internal` ACL.
  - Updated by [Christian Noon](https://github.com/cnoon).
- All sample code in the README to conform to the Alamofire 3.0 APIs.
  - Updated by [Christian Noon](https://github.com/cnoon).
- URL percent escaping to only batch on OS's where required improving
overall performance.
  - Updated by [Christian Noon](https://github.com/cnoon).
- Basic auth example in the README to compile on Swift 2.0.
  - Updated by [David F. Muir V](https://github.com/dfmuir) in Pull Request
  [#810](https://github.com/Alamofire/Alamofire/issues/810).

#### Fixed
- Compiler errors in the playground due to the new response serializer APIs.
  - Fixed by [Christian Noon](https://github.com/cnoon).

## [3.0.0-beta.1](https://github.com/Alamofire/Alamofire/releases/tag/3.0.0-beta.1)
Released on 2015-09-21. All issues associated with this milestone can be found using this
[filter](https://github.com/Alamofire/Alamofire/issues?utf8=✓&q=milestone%3A3.0.0-beta.1).

#### Added
- A new `Response` struct to simplify response serialization.
  - Added by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#792](https://github.com/Alamofire/Alamofire/pull/792).
- A new initializer to the `Manager` allowing dependency injection of the
underlying `NSURLSession`.
  - Added by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#795](https://github.com/Alamofire/Alamofire/pull/795).
- Tests around the new `Manager` initialization methods.

#### Updated
- Result type to take two generic parameters (`Value` and `Error`) where `Error`
conforms to `ErrorType`.
  - Updated by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#791](https://github.com/Alamofire/Alamofire/pull/791).
- All response serializers to now return the original server data as `NSData?`.
  - Updated by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#791](https://github.com/Alamofire/Alamofire/pull/791).
- The `TaskDelegate` to store an error as an `NSError` instead of `ErrorType`.
  - Updated by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#791](https://github.com/Alamofire/Alamofire/pull/791).
- The `ValidationResult` failure case to require an `NSError` instead of `ErrorType`.
  - Updated by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#791](https://github.com/Alamofire/Alamofire/pull/791).
- All tests around response serialization and `Result` type usage.
  - Updated by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#791](https://github.com/Alamofire/Alamofire/pull/791).
- All response serializers to use the new `Response` type.
  - Updated by [Christian Noon](https://github.com/cnoon) in Pull Request  - 
  [#792](https://github.com/Alamofire/Alamofire/pull/792).
- The designated initializer for a `Manager` to accept a `SessionDelegate` parameter
allowing dependency injection for better background session support.
  - Updated by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#795](https://github.com/Alamofire/Alamofire/pull/795).

---

## [2.0.2](https://github.com/Alamofire/Alamofire/releases/tag/2.0.2)
Released on 2015-09-20. All issues associated with this milestone can be found using this
[filter](https://github.com/Alamofire/Alamofire/issues?utf8=✓&q=milestone%3A2.0.2).

#### Updated
- The Embedded Framework documentation to include `git init` info.
  - Updated by [Christian Noon](https://github.com/cnoon) in regards to Issue
  [#782](https://github.com/Alamofire/Alamofire/issues/782).

#### Fixed
- Alamofire iOS framework target by adding Alamofire iOS Tests as Target Dependency.
  - Fixed by [Nicky Gerritsen](https://github.com/nickygerritsen) in Pull Request
  [#780](https://github.com/Alamofire/Alamofire/pull/780).
- Percent encoding issue for long Chinese strings using URL parameter encoding.
  - Fixed by [Christian Noon](https://github.com/cnoon) in regards to Issue
  [#206](https://github.com/Alamofire/Alamofire/issues/206).

## [2.0.1](https://github.com/Alamofire/Alamofire/releases/tag/2.0.1)
Released on 2015-09-16. All issues associated with this milestone can be found using this 
[filter](https://github.com/Alamofire/Alamofire/issues?utf8=✓&q=milestone%3A2.0.1).

#### Updated
- The CocoaPods installation instructions in the README.
  - Updated by [Christian Noon](https://github.com/cnoon).
- The Carthage installation instructions in the README.
  - Updated by [Gustavo Barbosa](https://github.com/barbosa) in Pull Request
  [#759](https://github.com/Alamofire/Alamofire/pull/759).

#### Fixed
- The link to the 2.0 migration guide in the README.
  - Fixed by [Dwight Watson](https://github.com/dwightwatson) in Pull Request
  [#750](https://github.com/Alamofire/Alamofire/pull/750).
- Issue where NTLM authentication credentials were not used for authentication challenges.
  - Fixed by [Christian Noon](https://github.com/cnoon) in regards to Issue
  [#721](https://github.com/Alamofire/Alamofire/pull/721).

## [2.0.0](https://github.com/Alamofire/Alamofire/releases/tag/2.0.0)
Released on 2015-09-09. All issues associated with this milestone can be found using this 
[filter](https://github.com/Alamofire/Alamofire/issues?utf8=✓&q=milestone%3A2.0.0).

#### Added
- A new `URLEncodedInURL` case to the `ParameterEncoding` for encoding in the URL.
  - Added by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#742](https://github.com/Alamofire/Alamofire/pull/742).

---

## [2.0.0-beta.4](https://github.com/Alamofire/Alamofire/releases/tag/2.0.0-beta.4)
Released on 2015-09-06. All issues associated with this milestone can be found using this 
[filter](https://github.com/Alamofire/Alamofire/issues?utf8=✓&q=milestone%3A2.0.0-beta.4).

#### Added
- The `parameters` and `encoding` parameters to download APIs.
  - Added by [Christian Noon](https://github.com/cnoon) in regards to Issue
  [#719](https://github.com/Alamofire/Alamofire/issues/719).
- Section to the README about wildcard domain matching with server trust policies.
  - Added by [Sai](https://github.com/sai-prasanna) in Pull Request
  [#718](https://github.com/Alamofire/Alamofire/pull/718).
- A UTF-8 charset to Content-Type header for a URL encoded body.
  - Added by [Cheolhee Han](https://github.com/cheolhee) in Pull Request
  [#731](https://github.com/Alamofire/Alamofire/pull/731).
- Tests around posting unicode parameters with URL encoding.
  - Added by [Christian Noon](https://github.com/cnoon) in regards to Pull Request
  [#731](https://github.com/Alamofire/Alamofire/pull/731).
- Tests for uploading base 64 encoded image data inside JSON.
  - Added by [Christian Noon](https://github.com/cnoon) in regards to Issue
  [#738](https://github.com/Alamofire/Alamofire/issues/738).
- An Alamofire 2.0 migration guide document to the new Documentation folder.
  - Added by [Christian Noon](https://github.com/cnoon).
- A Migration Guides section to the README with link to 2.0 guide.
  - Added by [Christian Noon](https://github.com/cnoon).

#### Updated
- Response serialization to prevent unnecessary call to response serializer.
  - Updated by [Julien Ducret](https://github.com/brocoo) in Pull Request
  [#716](https://github.com/Alamofire/Alamofire/pull/716).
- Travis-CI yaml file to support iOS 9, OSX 10.11 and Xcode 7.
  - Updated by [Christian Noon](https://github.com/cnoon).
- Result types to store an `ErrorType` instead of `NSError`.
  - Updated by [Christian Noon](https://github.com/cnoon) in regards to Issue
  [#732](https://github.com/Alamofire/Alamofire/issues/732).
- Docstrings on the download method to be more accurate.
  - Updated by [Christian Noon](https://github.com/cnoon).
- The README to require Xcode 7 beta 6.
  - Updated by [Christian Noon](https://github.com/cnoon).
- The background session section of the README to use non-deprecated API.
  - Updated by [David F. Muir V](https://github.com/dfmuir) in Pull Request
  [#724](https://github.com/Alamofire/Alamofire/pull/724).
- The playground to use the `Result` type.
  - Updated by [Jonas Schmid](https://github.com/jschmid) in Pull Request
  [#726](https://github.com/Alamofire/Alamofire/pull/726).
- Updated progress code samples in the README to show how to call onto the main queue.
  - Updated by [Christian Noon](https://github.com/cnoon).

#### Removed
- The AFNetworking sections from the FAQ in the README.
  - Removed by [Christian Noon](https://github.com/cnoon).

#### Fixed
- Issue on Windows where the wildcarded cert name in the test suite included asterisk.
  - Fixed by [Christian Noon](https://github.com/cnoon) in regards to Issue
  [#723](https://github.com/Alamofire/Alamofire/issues/723).
- Crash when multipart form data was uploaded from in-memory data on background session.
  - Fixed by [Christian Noon](https://github.com/cnoon) in regards to Issue
  [#740](https://github.com/Alamofire/Alamofire/issues/740).
- Issue where the background session completion handler was not called on the main queue.
  - Fixed by [Christian Noon](https://github.com/cnoon) in regards to Issue
  [#728](https://github.com/Alamofire/Alamofire/issues/728).

## [2.0.0-beta.3](https://github.com/Alamofire/Alamofire/releases/tag/2.0.0-beta.3)
Released on 2015-08-25.

#### Removed
- The override for `NSMutableURLRequest` for the `URLRequestConvertible` protocol
conformance that could cause unwanted URL request referencing.
  - Removed by [Christian Noon](https://github.com/cnoon).

## [2.0.0-beta.2](https://github.com/Alamofire/Alamofire/releases/tag/2.0.0-beta.2)
Released on 2015-08-24. All issues associated with this milestone can be found using this 
[filter](https://github.com/Alamofire/Alamofire/issues?utf8=✓&q=milestone%3A2.0.0-beta.2).

#### Added
- Host and certificate chain validation section to the README.
  - Added by [Christian Noon](https://github.com/cnoon).
- Tests verifying configuration headers are sent with all configuration types.
  - Added by [Christian Noon](https://github.com/cnoon) in regards to Issue
  [#692](https://github.com/Alamofire/Alamofire/issues/692).
- New rdar to the list in the README about the #available check issue.
  - Added by [Christian Noon](https://github.com/cnoon).
- Override for `NSMutableURLRequest` for the `URLRequestConvertible` protocol.
  - Added by [Christian Noon](https://github.com/cnoon).

#### Updated
- The README to note that CocoaPods 0.38.2 is required.
  - Updated by [Christian Noon](https://github.com/cnoon) in regards to Issue
  [#682](https://github.com/Alamofire/Alamofire/issues/682).
- The README to include note about keeping a reference to the `Manager`.
  - Updated by [Christian Noon](https://github.com/cnoon) in regards to Issue
  [#681](https://github.com/Alamofire/Alamofire/issues/681).
- Server trust host validation over to use SSL policy evaluation.
  - Updated by [Christian Noon](https://github.com/cnoon).
- The documentation for the `URLRequestConvertible` section in the README.
  - Updated by [Christian Noon](https://github.com/cnoon).
- The `ServerTrustPolicyManager` to be more flexible by using `public` ACL.
  - Updated by [Jan Riehn](https://github.com/jriehn) in Pull Request
  [#696](https://github.com/Alamofire/Alamofire/pull/696).
- The `ServerTrustPolicyManager` policies property to use `public` ACL and
added docstrings.
  - Updated by [Christian Noon](https://github.com/cnoon).
- The Ono response serializer example for Swift 2.0 in the README.
  - Updated by [Christian Noon](https://github.com/cnoon) in regards to Issue
  [#700](https://github.com/Alamofire/Alamofire/issues/700).
- `Result` failure case to store an `ErrorType` instead of `NSError`.
  - Updated by [Christian Noon](https://github.com/cnoon) in regards to Issue
  [#703](https://github.com/Alamofire/Alamofire/issues/703).
- All source code to compile with Xcode 7 beta 6.
  - Updated by [Michael Gray](https://github.com/mishagray) in Pull Request
  [#707](https://github.com/Alamofire/Alamofire/pull/707).

#### Removed
- The `required` declaration on the `Manager` init method.
  - Removed by [Christian Noon](https://github.com/cnoon) in regards to Issue
  [#672](https://github.com/Alamofire/Alamofire/issues/672).

#### Fixed
- Issue where the `TaskDelegate` operation queue would leak if the task was
never started.
  - Fixed by [Christian Noon](https://github.com/cnoon).
- Compiler issue on OS X target when creating background configurations
in the test suite.
  - Fixed by [Christian Noon](https://github.com/cnoon) in regards to Issue
  [#693](https://github.com/Alamofire/Alamofire/issues/693).

## [2.0.0-beta.1](https://github.com/Alamofire/Alamofire/releases/tag/2.0.0-beta.1)
Released on 2015-08-10. All issues associated with this milestone can be found using this 
[filter](https://github.com/Alamofire/Alamofire/issues?utf8=✓&q=milestone%3A2.0.0-beta.1).

#### Added
- A `watchOS` deployment target to the podspec.
  - Added by [Kyle Fuller](https://github.com/kylef) in Pull Request
  [#574](https://github.com/Alamofire/Alamofire/pull/574).
- Full screen support in the iOS Example App.
  - Added by [Corinne Krych](https://github.com/corinnekrych) in Pull Request
  [#612](https://github.com/Alamofire/Alamofire/pull/612).
- Temporary workaround for `SecCertificate` array compiler crash.
  - Added by [Robert Rasmussen](https://github.com/robrasmussen) in Issue
  [#610](https://github.com/Alamofire/Alamofire/issues/610).
- `Result` and `Error` types to refactor response validation and serialization.
  - Added by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#627](https://github.com/Alamofire/Alamofire/pull/627).
- Tests around response data, string and json serialization result behavior.
  - Added by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#627](https://github.com/Alamofire/Alamofire/pull/627).
- `CustomStringConvertible` and `CustomDebugStringConvertible` conformance
to the `Result` enumeration.
  - Added by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#648](https://github.com/Alamofire/Alamofire/pull/648).
- A Resume Data section to the README inside the Downloads section.
  - Added by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#648](https://github.com/Alamofire/Alamofire/pull/648).
- A `watchOS` framework target to the project.
  - Added by [Tobias Ottenweller](https://github.com/tomco) in Pull Request
  [#616](https://github.com/Alamofire/Alamofire/pull/616).
- `Result` tests pushing code coverage for `Result` enum to 100%.
  - Added by [Christian Noon](https://github.com/cnoon).
- Tests around all response serializer usage.
  - Added by [Christian Noon](https://github.com/cnoon).
- Public docstrings for all public `SessionDelegate` methods.
  - Added by [Christian Noon](https://github.com/cnoon).
- A section to the README that calls out all open rdars affecting Alamofire.
  - Added by [Christian Noon](https://github.com/cnoon).
- Test for wildcard validation that contains response with nil MIME type.
  - Added by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#662](https://github.com/Alamofire/Alamofire/pull/662).
- Support for stream tasks in iOS 9+ and OSX 10.11+.
  - Added by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#659](https://github.com/Alamofire/Alamofire/pull/659).

#### Updated
- All logic to compile against Swift 2.0.
  - Updated by [Christian Noon](https://github.com/cnoon).
- All logic to use the latest Swift 2.0 conventions.
  - Updated by [Christian Noon](https://github.com/cnoon).
- All public docstrings to the latest Swift 2.0 syntax.
  - Updated by [Christian Noon](https://github.com/cnoon).
- `URLRequestConvertible` to return an `NSMutableURLRequest`.
  - Updated by [Christian Noon](https://github.com/cnoon).
- All HTTP requests to HTTPS to better align with ATS.
  - Updated by [Christian Noon](https://github.com/cnoon).
- The `escape` method in `ParameterEncoding` to use non-deprecated methods.
  - Updated by [Christian Noon](https://github.com/cnoon).
- All source code and docstrings to fit roughly within 120 characters.
  - Updated by [Christian Noon](https://github.com/cnoon).
- The `MultipartFormData` encoding to leverage Swift 2.0 error handling.
  - Updated by [Christian Noon](https://github.com/cnoon).
- All README code samples to match the latest Swift 2.0 API changes.
  - Updated by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#648](https://github.com/Alamofire/Alamofire/pull/648).
- All frameworks to enable code coverage generation.
  - Updated by [Christian Noon](https://github.com/cnoon).
- All frameworks to set the enable testability flag to YES for release builds.
  - Updated by [Christian Noon](https://github.com/cnoon) in regard to Issue
  [#652](https://github.com/Alamofire/Alamofire/issues/652).
- `ParameterEncoding` to leverage guard for parameters to increase safety.
  - Updated by [Christian Noon](https://github.com/cnoon).
- iOS Example App to use optional bind around response to safely extract headers.
  - Updated by [John Pope](https://github.com/johndpope) in Pull Request
  [#665](https://github.com/Alamofire/Alamofire/pull/665).
- The `queryComponents` and `escape` methods in `ParameterEncoding` to `public` to
better support `.Custom` encoding.
  - Updated by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#660](https://github.com/Alamofire/Alamofire/pull/660).
- The static error convenience functions to a public ACL.
  - Updated by [Christian Noon](https://github.com/cnoon) in regards to Issue
  [#668](https://github.com/Alamofire/Alamofire/issues/668).

#### Removed
- Explicit string values in `ParameterEncoding` since they are now implied.
  - Removed by [Christian Noon](https://github.com/cnoon).
- An OSX cookie check in the `CustomDebugStringConvertible` conformance of a `Request`.
  - Removed by [Christian Noon](https://github.com/cnoon).

#### Fixed
- Issue in automatic validation tests where mutable URL request was not used.
  - Fixed by [Christian Noon](https://github.com/cnoon).
- Potential crash cases in Validation MIME type logic exposed by chaining.
  - Fixed by [Christian Noon](https://github.com/cnoon).
- Compiler issue in the iOS Example App around `Result` type usage.
  - Fixed by [Jan Kase](https://github.com/jankase) in Pull Request
  [#639](https://github.com/Alamofire/Alamofire/pull/639).
- The error code in the custom response serializers section of the README.
  - Fixed by [Christian Noon](https://github.com/cnoon).

---

## [1.3.1](https://github.com/Alamofire/Alamofire/releases/tag/1.3.1)
Released on 2015-08-10. All issues associated with this milestone can be found using this 
[filter](https://github.com/Alamofire/Alamofire/issues?utf8=✓&q=milestone%3A1.3.1).

#### Fixed
- Issue where a completed task was not released by the `SessionDelegate` if the
task override closure was set.
  - Fixed by [Christian Noon](https://github.com/cnoon) in regards to Issue
  [#622](https://github.com/Alamofire/Alamofire/issues/622).

## [1.3.0](https://github.com/Alamofire/Alamofire/releases/tag/1.3.0)
Released on 2015-07-24. All issues associated with this milestone can be found using this 
[filter](https://github.com/Alamofire/Alamofire/issues?utf8=✓&q=milestone%3A1.3.0).

#### Added
- Test case around `NSURLProtocol` checking header passthrough behaviors.
  - Added by [Christian Noon](https://github.com/cnoon) in regards to Issue
  [#473](https://github.com/Alamofire/Alamofire/issues/473).
- Stream method on `Request` to receive data incrementally from data responses.
  - Added by [Peter Sobot](https://github.com/psobot) in Pull Request
  [#512](https://github.com/Alamofire/Alamofire/pull/512).
- Example to the README demonstrating how to use the `responseCollection` serializer.
  - Added by [Josh Brown](https://github.com/joshuatbrown) in Pull Request
  [#532](https://github.com/Alamofire/Alamofire/pull/532).
- Link to the README to the CocoaDocs documentation for Alamofire.
  - Added by [Robert](https://github.com/rojotek) in Pull Request
  [#541](https://github.com/Alamofire/Alamofire/pull/541).
- Support for uploading `MultipartFormData` in-memory and streaming from disk.
  - Added by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#539](https://github.com/Alamofire/Alamofire/pull/539).
- Tests for uploading `MultipartFormData` with complete code coverage.
  - Added by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#539](https://github.com/Alamofire/Alamofire/pull/539).
- The iOS 8.4 simulator to the Travis CI builds by switching to the Xcode 6.4 build.
  - Added by [Syo Ikeda](https://github.com/ikesyo) in Pull Request
  [#568](https://github.com/Alamofire/Alamofire/pull/568).
- Tests for the custom header support with complete code coverage.
  - Added by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#586](https://github.com/Alamofire/Alamofire/pull/586).
- Section to the README about new HTTP header support in the global functions.
  - Added by [Christian Noon](https://github.com/cnoon).
- Basic auth `Authorization` header example to the README.
  - Added by [Christian Noon](https://github.com/cnoon).
- TLS certificate and public key pinning support through the `ServerTrustPolicy`.
  - Added by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#581](https://github.com/Alamofire/Alamofire/pull/581).
- Tests for TLS certificate and public key pinning with complete code coverage.
  - Added by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#581](https://github.com/Alamofire/Alamofire/pull/581).
- Security section to the README detailing various server trust policies.
  - Added by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#581](https://github.com/Alamofire/Alamofire/pull/581).
- The `resumeData` property to `Request` to expose outside data response serializer.
  - Added by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#595](https://github.com/Alamofire/Alamofire/pull/595).
- Download request sample to iOS example app.
  - Added by [Kengo Yokoyama](https://github.com/kentya6) in Pull Request
  [#579](https://github.com/Alamofire/Alamofire/pull/579).

#### Updated
- The INFOPLIST_FILE Xcode project setting to be a relative path.
  - Updated by [Christian Noon](https://github.com/cnoon).
- Exposed persistence parameter for basic auth credentials.
  - Updated by [Christian Noon](https://github.com/cnoon) in regard to Issue
  [#537](https://github.com/Alamofire/Alamofire/issues/537).
- The Travis CI builds to run a full `pod lib lint` pass on the source.
  - Updated by [Kyle Fuller](https://github.com/kylef) in Pull Request
  [#542](https://github.com/Alamofire/Alamofire/pull/542).
- All cases of force unwrapping with optional binding and where clause when applicable.
  - Updated by [Syo Ikeda](https://github.com/ikesyo) in Pull Request
  [#557](https://github.com/Alamofire/Alamofire/pull/557).
- The `ParameterEncoding` encode return tuple to return a mutable URL request.
  - Updated by [Petr Korolev](https://github.com/skywinder) in Pull Request
  [#478](https://github.com/Alamofire/Alamofire/pull/478).
- The `URLRequest` convenience method to return a mutable `NSURLRequest`.
  - Updated by [Christian Noon](https://github.com/cnoon).
- The `request` / `download` / `upload` methods to support custom headers.
  - Updated by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#586](https://github.com/Alamofire/Alamofire/pull/586).
- The global `request` / `download` / `upload` method external parameters convention.
  - Updated by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#586](https://github.com/Alamofire/Alamofire/pull/586).
- Response serialization to use generics and a `ResponseSerializer` protocol.
  - Updated by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#593](https://github.com/Alamofire/Alamofire/pull/593).
- Download task delegate to store resume data for a failed download if available.
  - Updated by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#595](https://github.com/Alamofire/Alamofire/pull/595).
- The `TaskDelegate.queue` to public to allow custom request extension operations.
  - Updated by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#590](https://github.com/Alamofire/Alamofire/pull/590).
- The README code samples for Advanced Response Serialization.
  - Updated by [Christian Noon](https://github.com/cnoon).

#### Removed
- An unnecessary `NSURLSessionConfiguration` type declaration that can be inferred.
  - Removed by [Avismara](https://github.com/avismarahl) in Pull Request
  [#576](https://github.com/Alamofire/Alamofire/pull/576).
- Unnecessary `respondsToSelector` overrides for `SessionDelegate` methods.
  - Removed by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#590](https://github.com/Alamofire/Alamofire/pull/590).
- Unnecessary calls to `self` throughout source, test and example logic.
  - Removed by [Christian Noon](https://github.com/cnoon).

#### Fixed
- Random test suite basic auth failures by clearing credentials in `setUp` method.
  - Fixed by [Christian Noon](https://github.com/cnoon).
- Error where wildcard was failing due to missing response MIME type.
  - Fixed by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#598](https://github.com/Alamofire/Alamofire/pull/598).
- Typo in the basic auth headers example code in the README.
  - Fixed by [蒲公英の生活](https://github.com/fewspider) in Pull Request
  [#605](https://github.com/Alamofire/Alamofire/pull/605).
- Issue where the example app was printing elapsed time in optional form.
  - Fixed by [Christian Noon](https://github.com/cnoon).

#### Upgrade Notes
There are a couple changes in the 1.3.0 release that are not fully backwards
compatible and need to be called out.

* The global `request` / `download` / `upload` external parameter naming conventions
were not consistent nor did they match the `Manager` equivalents. By making them
consistent across the board, this introduced the possibility that you "may" need to
make slight modifications to your global function calls.
* In order to support generic response serializers, the lowest level
`Request.response` method had to be converted to a generic method leveraging the new
`ResponseSerializer` protocol. This has many advantages, the most obvious being that
the `response` convenience method now returns an `NSData?` optional instead of an
`AnyObject?` optional. Nice!

  > Please note that every effort is taken to maintain proper semantic versioning. In
these two rare cases, it was deemed to be in the best interest of the community to
slightly break semantic versioning to unify naming conventions as well as expose a
much more powerful form of response serialization.

  > If you have any issues, please don't hesitate to reach out through
[GitHub](https://github.com/Alamofire/Alamofire/issues) or
[Twitter](https://twitter.com/AlamofireSF).

---

## [1.2.3](https://github.com/Alamofire/Alamofire/releases/tag/1.2.3)
Released on 2015-06-12. All issues associated with this milestone can be found using this 
[filter](https://github.com/Alamofire/Alamofire/issues?utf8=✓&q=milestone%3A1.2.3).

#### Added
- Tests for data task progress closure and NSProgress updates.
  - Added by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#494](https://github.com/Alamofire/Alamofire/pull/494).
- More robust tests around download and upload progress.
  - Added by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#494](https://github.com/Alamofire/Alamofire/pull/494).
- More robust redirect tests around default behavior and task override closures.
  - Added by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#507](https://github.com/Alamofire/Alamofire/pull/507).
- The "[" and "]" to the legal escape characters and added more documentation.
  - Added by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#504](https://github.com/Alamofire/Alamofire/pull/504).
- Percent escaping tests around reserved / unreserved / illegal characters.
  - Added by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#504](https://github.com/Alamofire/Alamofire/pull/504).
- Tests for various Cache-Control headers with different request cache policies.
  - Added by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#505](https://github.com/Alamofire/Alamofire/pull/505).
- Link to Carthage in the README.
  - Added by [Josh Brown](https://github.com/joshuatbrown) in Pull Request
  [#520](https://github.com/Alamofire/Alamofire/pull/520).

#### Updated
- iOS 7 instructions to cover multiple Swift files in the README.
  - Updated by [Sébastien Michoy](https://github.com/SebastienMichoy) in regards
  to Issue [#479](https://github.com/Alamofire/Alamofire/pull/479).
- All tests to follow the Given / When / Then structure.
  - Updated by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#489](https://github.com/Alamofire/Alamofire/pull/489).
- All tests to be crash safe.
  - Updated by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#489](https://github.com/Alamofire/Alamofire/pull/489).
- The OS X tests so that they are all passing again.
  - Updated by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#489](https://github.com/Alamofire/Alamofire/pull/489).
- Re-enabled Travis-CI tests for both iOS and Mac OS X.
  - Updated by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#506](https://github.com/Alamofire/Alamofire/pull/506).
- Travis-CI test suite to run all tests in both debug and release.
  - Updated by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#506](https://github.com/Alamofire/Alamofire/pull/506).
- Travis-CI test suite to run all tests on iOS 8.1, 8.2 and 8.3 as well as Mac OS X 10.10.
  - Updated by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#506](https://github.com/Alamofire/Alamofire/pull/506).
- Travis-CI test suite to run `pod lib lint` against the latest version of CocoaPods.
  - Updated by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#506](https://github.com/Alamofire/Alamofire/pull/506).

#### Fixed
- Random deinitialization test failure by handling task state race condition.
  - Fixed by [Christian Noon](https://github.com/cnoon).
- Typo in the API Parameter Abstraction in the README.
  - Fixed by [Josh Brown](https://github.com/joshuatbrown) in Pull Request
  [#500](https://github.com/Alamofire/Alamofire/pull/500).
- Cookies are now only applied in the DebugPrintable API when appropriate.
  - Fixed by [Alex Plescan](https://github.com/alexpls) in Pull Request
  [#516](https://github.com/Alamofire/Alamofire/pull/516).

## [1.2.2](https://github.com/Alamofire/Alamofire/releases/tag/1.2.2)
Released on 2015-05-13. All issues associated with this milestone can be found using this 
[filter](https://github.com/Alamofire/Alamofire/issues?utf8=✓&q=milestone%3A1.2.2).

#### Added
- Contributing Guidelines document to the project.
  - Added by [Mattt Thompson](https://github.com/mattt).
- Documentation to the `URLStringConvertible` protocol around RFC specs.
  - Added by [Mattt Thompson](https://github.com/mattt) in regards to Issue
  [#464](https://github.com/Alamofire/Alamofire/pull/464).
- The `Carthage/Build` ignore flag to the `.gitignore` file.
  - Added by [Tomáš Slíž](https://github.com/tomassliz) in Pull Request
  [#451](https://github.com/Alamofire/Alamofire/pull/451).
- The `.DS_Store` ignore flag to the `.gitignore` file.
  - Added by [Christian Noon](https://github.com/cnoon).
- Response status code asserts for redirect tests.
  - Added by [Christian Noon](https://github.com/cnoon).
- A CHANGELOG to the project documenting each official release.
  - Added by [Christian Noon](https://github.com/cnoon).

#### Updated
- `SessionDelegate` override closure properties to match the method signatures.
  - Updated by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#456](https://github.com/Alamofire/Alamofire/pull/456).
- Documentation for the `Printable` protocol on `Request` to reference output stream
rather than the specific `OutputStreamType`.
  - Updated by [Mattt Thompson](https://github.com/mattt).
- Deployment targets to iOS 8.0 and OS X 10.9 for the respective frameworks.
  - Updated by [Christian Noon](https://github.com/cnoon).
- `SessionDelegate` willPerformHTTPRedirection method to accept optional return type
from override closure.
  - Updated by [Chungsub Kim](https://github.com/subicura) in Pull Request
  [#469](https://github.com/Alamofire/Alamofire/pull/469).
- Embedded Framework and Source File documentation in the README.
  - Updated by [Christian Noon](https://github.com/cnoon) in regards to Issue
  [#427](https://github.com/Alamofire/Alamofire/pull/427).
- Alamofire source to be split into multiple core files and feature files.
  - Updated by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#471](https://github.com/Alamofire/Alamofire/pull/471).
- `TaskDelegate` override closure signatures and delegate method implementations.
  - Updated by [Christian Noon](https://github.com/cnoon).

#### Removed
- Travis-CI build status from the README until Xcode 6.3 is supported.
  - Removed by [Mattt Thompson](https://github.com/mattt).
- Unnecessary parentheses from closure parameters and typealiases.
  - Removed by [Christian Noon](https://github.com/cnoon).

#### Fixed
- `SessionDelegate` override closure documentation.
  - Fixed by [Siemen Sikkema](https://github.com/siemensikkema) in Pull Request
  [#448](https://github.com/Alamofire/Alamofire/pull/448).
- Some inaccurate documentation on several of the public `SessionDelegate` closures.
  - Fixed by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#456](https://github.com/Alamofire/Alamofire/pull/456).
- A deinit race condition where the task delegate queue could fail to `dispatch_release`.
  - Fixed by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#379](https://github.com/Alamofire/Alamofire/pull/379).
- `TaskDelegate` to only set `qualityOfService` for `NSOperationQueue` on iOS 8+.
  - Fixed by [Christian Noon](https://github.com/cnoon) in regards to Issue
  [#472](https://github.com/Alamofire/Alamofire/pull/472).
- Expectation order issue in the redirect tests.
  - Fixed by [Christian Noon](https://github.com/cnoon).
- `DataTaskDelegate` behavior ensuring `NSProgress` values and `progress` override
closures are always updated and executed.
  - Fixed by [Christian Noon](https://github.com/cnoon) in regards to Issue
  [#407](https://github.com/Alamofire/Alamofire/pull/407).

## [1.2.1](https://github.com/Alamofire/Alamofire/releases/tag/1.2.1)
Released on 2015-04-21.

#### Added
- Redirect tests for the `SessionDelegate`.
  - Added by [Jonathan Hersh](https://github.com/jhersh) in Pull Request
  [#424](https://github.com/Alamofire/Alamofire/pull/424).
- TLS evaluation test case.
  - Added by [Mattt Thompson](https://github.com/mattt).
- Additional guards to ensure unique task identifiers for upload and download tasks.
  - Added by [Mattt Thompson](https://github.com/mattt) in regards to Issue
  [#393](https://github.com/Alamofire/Alamofire/pull/393).

#### Updated
- Required Xcode version to Xcode to 6.3 in the README.
  - Updated by [Mattt Thompson](https://github.com/mattt).
- SSL validation to use default system validation by default.
  - Updated by [Michael Thole](https://github.com/mthole) in Pull Request
  [#394](https://github.com/Alamofire/Alamofire/pull/394).

## [1.2.0](https://github.com/Alamofire/Alamofire/releases/tag/1.2.0)
Released on 2015-04-09.

#### Added
- New `testURLParameterEncodeStringWithSlashKeyStringWithQuestionMarkValueParameter`
test.
  - Added by [Mattt Thompson](https://github.com/mattt) in regards to Issue
  [#370](https://github.com/Alamofire/Alamofire/pull/370).
- New `backgroundCompletionHandler` property to the `Manager` called when the 
session background tasks finish.
  - Added by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#317](https://github.com/Alamofire/Alamofire/pull/317).

#### Updated
- `Request` computed property `progress` to no longer be an optional type.
  - Updated by [Pitiphong Phongpattranont](https://github.com/pitiphong-p) in
  Pull Request
  [#404](https://github.com/Alamofire/Alamofire/pull/404).
- All logic to Swift 1.2.
  - Updated by [Aron Cedercrantz](https://github.com/rastersize) and
  [Mattt Thompson](https://github.com/mattt).
- The `responseString` serializer to respect server provided character encoding with
overrideable configuration, default string response serialization to ISO-8859-1, as
per the HTTP/1.1 specification.
  - Updated by [Kyle Fuller](https://github.com/kylef) and
  [Mattt Thompson](https://github.com/mattt) in Pull Request
  [#359](https://github.com/Alamofire/Alamofire/pull/359) which also resolved Issue
  [#358](https://github.com/Alamofire/Alamofire/pull/358).
- `SessionDelegate` methods to first call the override closures if set.
  - Updated by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#317](https://github.com/Alamofire/Alamofire/pull/317).
- `SessionDelegate` and all override closures to a public ACL allowing for customization.
  - Updated by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#317](https://github.com/Alamofire/Alamofire/pull/317).
- `SessionDelegate` class to `final`.
  - Updated by [Mattt Thompson](https://github.com/mattt).  
- `SessionDelegate` header documentation for method override properties.
  - Updated by [Mattt Thompson](https://github.com/mattt).  
- Xcode project to set `APPLICATION_EXTENSION_API_ONLY` to `YES` for OS X target.
  - Updated by [Mattt Thompson](https://github.com/mattt).

#### Removed
- Ambiguous response serializer methods that collided with default parameters.
  - Removed by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#408](https://github.com/Alamofire/Alamofire/pull/408).
- `SessionDelegate` initializer and replaced with default property value.
  - Removed by [Mattt Thompson](https://github.com/mattt).

#### Fixed
- Async tests where asserts were potentially not being run by by moving
`expectation.fullfill()` to end of closures.
  - Fixed by [Nate Cook](https://github.com/natecook1000) in Pull Request
  [#420](https://github.com/Alamofire/Alamofire/pull/420).
- Small grammatical error in the ParameterEncoding section of the README.
  - Fixed by [Aaron Brager](https://github.com/getaaron) in Pull Request
  [#416](https://github.com/Alamofire/Alamofire/pull/416).
- Typo in a download test comment.
  - Fixed by [Aaron Brager](https://github.com/getaaron) in Pull Request
  [#413](https://github.com/Alamofire/Alamofire/pull/413).
- Signature mismatch in the `dataTaskDidBecomeDownloadTask` override closure.
  - Fixed by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#317](https://github.com/Alamofire/Alamofire/pull/317).
- Issue in the `SessionDelegate` where the `DataTaskDelegate` was not being called.
  - Fixed by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#317](https://github.com/Alamofire/Alamofire/pull/317).

---

## [1.1.5](https://github.com/Alamofire/Alamofire/releases/tag/1.1.5)
Released on 2015-03-26.

#### Added
- Convenience upload functions to the `Manager`.
  - Added by [Olivier Bohrer](https://github.com/obohrer) in Pull Request
  [#334](https://github.com/Alamofire/Alamofire/pull/334).
- Info to the README about Swift 1.2 support.
  - Added by [Mattt Thompson](https://github.com/mattt).

#### Updated
- All request / upload / download methods on `Manager` to match the top-level functions.
  - Updated by [Mattt Thompson](https://github.com/mattt).
- The `testDownloadRequest` to no longer remove the downloaded file.
  - Updated by [Mattt Thompson](https://github.com/mattt).
- Ono XML response serializer example in the README.
  - Updated by [Mattt Thompson](https://github.com/mattt).
- Travis-CI settings to only build the master branch.
  - Updated by [Mattt Thompson](https://github.com/mattt).  
- Code signing identities for the frameworks and targets to better support Carthage.
  - Updated by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#400](https://github.com/Alamofire/Alamofire/pull/400).
- iOS deployment target to iOS 8.0 for iOS target and tests.
  - Updated by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#401](https://github.com/Alamofire/Alamofire/pull/401).
- Legal characters to be escaped according to RFC 3986 Section 3.4.
  - Updated by [Stephane Lizeray](https://github.com/slizeray) in Pull Request
  [#370](https://github.com/Alamofire/Alamofire/pull/370).

#### Fixed
- Travis-CI scheme issue, added podspec linting and added ENV variables.
  - Fixed by [Jonathan Hersh](https://github.com/jhersh) in Pull Request
  [#351](https://github.com/Alamofire/Alamofire/pull/351).
- Code sample in the README in the Manual Parameter Encoding section.
  - Fixed by [Petr Korolev](https://github.com/skywinder) in Pull Request
  [#381](https://github.com/Alamofire/Alamofire/pull/381).

## [1.1.4](https://github.com/Alamofire/Alamofire/releases/tag/1.1.4)
Released on 2015-01-30.

#### Added
- Podspec argument `requires_arc` to the podspec file.
  - Added by [Mattt Thompson](https://github.com/mattt).
- Support for Travis-CI for automated testing purposes.
  - Added by [Kyle Fuller](https://github.com/kylef) in Pull Request
  [#279](https://github.com/Alamofire/Alamofire/pull/279).

#### Updated
- Installation instructions in the README to include CocoaPods, Carthage and
Embedded Frameworks.
  - Updated by [Mattt Thompson](https://github.com/mattt).
- Travis-CI to use Xcode 6.1.1.
  - Updated by [Mattt Thompson](https://github.com/mattt).
- The `download` method on `Manager` to use `Request.DownloadFileDestination` typealias.
  - Updated by [Alexander Strakovich](https://github.com/astrabot) in Pull Request
  [#318](https://github.com/Alamofire/Alamofire/pull/318).
- `RequestTests` to no longer delete all cookies in default session configuration.
  - Updated by [Mattt Thompson](https://github.com/mattt).
- Travis-CI yaml file to only build the active architecture.
  - Updated by [Mattt Thompson](https://github.com/mattt).
- Deployment targets to iOS 7.0 and Mac OS X 10.9.
  - Updated by [Mattt Thompson](https://github.com/mattt).

#### Removed
- The `tearDown` method in the `AlamofireDownloadResponseTestCase`.
  - Removed by [Mattt Thompson](https://github.com/mattt).

#### Fixed
- Small formatting issue in the CocoaPods Podfile example in the README.
  - Fixed by [rborkow](https://github.com/rborkow) in Pull Request
  [#313](https://github.com/Alamofire/Alamofire/pull/313).
- Several issues with the iOS and OSX targets in the Xcode project.
  - Fixed by [Mattt Thompson](https://github.com/mattt).
- The `testDownloadRequest` in `DownloadTests` by adding `.json` file extension.
  - Fixed by [Martin Kavalar](https://github.com/mk) in Pull Request
  [#302](https://github.com/Alamofire/Alamofire/pull/302).
- The `AlamofireRequestDebugDescriptionTestCase` on OSX.
  - Fixed by [Mattt Thompson](https://github.com/mattt).
- Spec validation error with CocoaPods 0.36.0.beta-1 by disabling -b flags in `cURL`
debug on OSX.
  - Fixed by [Mattt Thompson](https://github.com/mattt).
- Travis-CI build issue by adding suppport for an `iOS Example` scheme. 
  - Fixed by [Yasuharu Ozaki](https://github.com/yasuoza) in Pull Request
  [#322](https://github.com/Alamofire/Alamofire/pull/322).

## [1.1.3](https://github.com/Alamofire/Alamofire/releases/tag/1.1.3)
Released on 2015-01-09.

#### Added
- Podspec file to support CocoaPods deployment.
  - Added by [Marius Rackwitz](https://github.com/mrackwitz) in Pull Request
  [#218](https://github.com/Alamofire/Alamofire/pull/218).
- Shared scheme to support Carthage deployments.
  - Added by [Yosuke Ishikawa](https://github.com/ishkawa) in Pull Request
  [#228](https://github.com/Alamofire/Alamofire/pull/228).
- New target for Alamofire OSX framework.
  - Added by [Martin Kavalar](https://github.com/mk) in Pull Request
  [#293](https://github.com/Alamofire/Alamofire/pull/293).

#### Updated
- Upload and Download progress state to be updated before calling progress closure.
  - Updated by [Alexander Strakovich](https://github.com/astrabot) in Pull Request
  [#278](https://github.com/Alamofire/Alamofire/pull/278).

#### Fixed
- Some casting code logic in the Generic Response Object Serialization example in
the README.
  - Fixed by [Philip Heinser](https://github.com/philipheinser) in Pull Request
  [#258](https://github.com/Alamofire/Alamofire/pull/258).
- Indentation formatting of the `responseString` parameter documentation.
  - Fixed by [Ah.Miao](https://github.com/mrahmiao) in Pull Request
  [#291](https://github.com/Alamofire/Alamofire/pull/291).

## [1.1.2](https://github.com/Alamofire/Alamofire/releases/tag/1.1.2)
Released on 2014-12-21.

#### Added
- POST request JSON response test.
  - Added by [Mattt Thompson](https://github.com/mattt).

#### Updated
- The response object example to use a failable initializer in the README.
  - Updated by [Mattt Thompson](https://github.com/mattt) in regards to Issue
  [#230](https://github.com/Alamofire/Alamofire/pull/230).
- Router example in the README by removing extraneous force unwrap.
  - Updated by [Arnaud Mesureur](https://github.com/nsarno) in Pull Request
  [#247](https://github.com/Alamofire/Alamofire/pull/247).
- Xcode project `APPLICATION_EXTENSION_API_ONLY` flag to `YES`.
  - Updated by [Michael Latta](https://github.com/technomage) in Pull Request
  [#273](https://github.com/Alamofire/Alamofire/pull/273).
- Default HTTP header creation by moving it into a public class method.
  - Updated by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#261](https://github.com/Alamofire/Alamofire/pull/261).

#### Fixed
- Upload stream method to set `HTTPBodyStream` for streamed request.
  - Fixed by [Florent Vilmart](https://github.com/flovilmart) and
  [Mattt Thompson](https://github.com/mattt) in Pull Request
  [#241](https://github.com/Alamofire/Alamofire/pull/241).
- ParameterEncoding to compose percent-encoded query strings from
percent-encoded components.
  - Fixed by [Oleh Sannikov](https://github.com/sunnycows) in Pull Request
  [#249](https://github.com/Alamofire/Alamofire/pull/249).
- Serialization handling of NSData with 0 bytes.
  - Fixed by [Mike Owens](https://github.com/mowens) in Pull Request
  [#254](https://github.com/Alamofire/Alamofire/pull/254).
- Issue where `suggestedDownloadDestination` parameters were being ignored.
  - Fixed by [Christian Noon](https://github.com/cnoon) in Pull Request
  [#257](https://github.com/Alamofire/Alamofire/pull/257).
- Crash caused by `Manager` deinitialization and added documentation.
  - Fixed by [Mattt Thompson](https://github.com/mattt) in regards to Issue
  [#269](https://github.com/Alamofire/Alamofire/pull/269).

## [1.1.1](https://github.com/Alamofire/Alamofire/releases/tag/1.1.1)
Released on 2014-11-20.

#### Updated
- Dispatch-based synchronized access to subdelegates.
  - Updated by [Mattt Thompson](https://github.com/mattt) in regards to Pull Request
  [#175](https://github.com/Alamofire/Alamofire/pull/175).
- iOS 7 instructions in the README.
  - Updated by [Mattt Thompson](https://github.com/mattt).
- CRUD example in the README to work on Xcode 6.1.
  - Updated by [John Beynon](https://github.com/johnbeynon) in Pull Request
  [#187](https://github.com/Alamofire/Alamofire/pull/187).
- The `cURL` example annotation in the README to pick up `bash` syntax highlighting.
  - Updated by [Samuel E. Giddins](https://github.com/segiddins) in Pull Request
  [#208](https://github.com/Alamofire/Alamofire/pull/208).

#### Fixed
- Out-of-memory exception by replacing `stringByAddingPercentEncodingWithAllowedCharacters`
with `CFURLCreateStringByAddingPercentEscapes`.
  - Fixed by [Mattt Thompson](https://github.com/mattt) in regards to Issue
  [#206](https://github.com/Alamofire/Alamofire/pull/206).
- Several issues in the README examples where an NSURL initializer needs to be unwrapped.
  - Fixed by [Mattt Thompson](https://github.com/mattt) in regards to Pull Request
  [#213](https://github.com/Alamofire/Alamofire/pull/213).
- Possible exception when force unwrapping optional header properties.
  - Fixed by [Mattt Thompson](https://github.com/mattt).
- Optional cookie entry in `cURL` output.
  - Fixed by [Mattt Thompson](https://github.com/mattt) in regards to Issue
  [#226](https://github.com/Alamofire/Alamofire/pull/226).
- Optional `textLabel` property on cells in the example app.
  - Fixed by [Mattt Thompson](https://github.com/mattt).

## [1.1.0](https://github.com/Alamofire/Alamofire/releases/tag/1.1.0)
Released on 2014-10-20.

#### Updated
- Project to support Swift 1.1 and Xcode 6.1.
  - Updated by [Aral Balkan](https://github.com/aral),
    [Ross Kimes](https://github.com/rosskimes),
    [Orta Therox](https://github.com/orta),
    [Nico du Plessis](https://github.com/nduplessis)
    and [Mattt Thompson](https://github.com/mattt).

---

## [1.0.1](https://github.com/Alamofire/Alamofire/releases/tag/1.0.1)
Released on 2014-10-20.

#### Added
- Tests for upload and download with progress.
  - Added by [Mattt Thompson](https://github.com/mattt).
- Test for question marks in url encoded query.
  - Added by [Mattt Thompson](https://github.com/mattt).
- The `NSURLSessionConfiguration` headers to `cURL` representation.
  - Added by [Matthias Ryne Cheow](https://github.com/rynecheow) in Pull Request
  [#140](https://github.com/Alamofire/Alamofire/pull/140).
- Parameter encoding tests for key/value pairs containing spaces.
  - Added by [Mattt Thompson](https://github.com/mattt).
- Percent character encoding for the `+` character.
  - Added by [Niels van Hoorn](https://github.com/nvh) in Pull Request
  [#167](https://github.com/Alamofire/Alamofire/pull/167).
- Escaping for quotes to support JSON in `cURL` commands.
  - Added by [John Gibb](https://github.com/johngibb) in Pull Request
  [#178](https://github.com/Alamofire/Alamofire/pull/178).
- The `request` method to the `Manager` bringing it more inline with the top-level methods.
  - Added by Brian Smith.

#### Fixed
- Parameter encoding of ampersands and escaping of characters.
  - Fixed by [Mattt Thompson](https://github.com/mattt) in regards to Issues
  [#146](https://github.com/Alamofire/Alamofire/pull/146) and
  [#162](https://github.com/Alamofire/Alamofire/pull/162).
- Parameter encoding of `HTTPBody` from occurring twice.
  - Fixed by Yuri in Pull Request
  [#153](https://github.com/Alamofire/Alamofire/pull/153).
- Extraneous dispatch to background by using weak reference for delegate in response.
  - Fixed by [Mattt Thompson](https://github.com/mattt).
- Response handler threading issue by adding a `subdelegateQueue` to the `SessionDelegate`.
  - Fixed by [Essan Parto](https://github.com/parto) in Pull Request
  [#171](https://github.com/Alamofire/Alamofire/pull/171).
- Challenge issue where basic auth credentials were not being unwrapped. 
  - Fixed by [Mattt Thompson](https://github.com/mattt).

## [1.0.0](https://github.com/Alamofire/Alamofire/releases/tag/1.0.0)
Released on 2014-09-25.

#### Added
- Initial release of Alamofire.
  - Added by [Mattt Thompson](https://github.com/mattt).
