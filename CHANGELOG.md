# Change Log
All notable changes to this project will be documented in this file.
`Alamofire` adheres to [Semantic Versioning](http://semver.org/).

- `1.2.x` Releases - [1.2.0](#120) | [1.2.1](#121) | [1.2.2](#122) | [1.2.3](#123)
- `1.1.x` Releases - [1.1.0](#110) | [1.1.1](#111) | [1.1.2](#112) | [1.1.3](#113) | [1.1.4](#114) | [1.1.5](#115)
- `1.0.x` Releases - [1.0.0](#100) | [1.0.1](#101)

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
