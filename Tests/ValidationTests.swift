//
//  ValidationTests.swift
//
//  Copyright (c) 2014-2018 Alamofire Software Foundation (http://alamofire.org/)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

@testable import Alamofire
import Foundation
import Testing

@Suite(.storesInstances)
struct StatusCodeValidationTestCase {
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func validationForRequestWithAcceptableStatusCodeResponseSucceeds() async {
        // Given
        let session = stored(Session.independent())
        let endpoint = Endpoint.status(200)

        let expectation1 = Completion("request should return 200 status code")
        let expectation2 = Completion("download should return 200 status code")

        let requestError = Capture<AFError?>()
        let downloadError = Capture<AFError?>()

        // When
        session.request(endpoint)
            .validate(statusCode: 200..<300)
            .response { resp in
                requestError.value = resp.error
                expectation1.complete()
            }

        session.download(endpoint)
            .validate(statusCode: 200..<300)
            .response { resp in
                downloadError.value = resp.error
                expectation2.complete()
            }

        await wait(for: [expectation1, expectation2])

        // Then
        #expect(requestError.value == nil)
        #expect(downloadError.value == nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func validationForRequestWithUnacceptableStatusCodeResponseFails() async {
        // Given
        let session = stored(Session.independent())
        let endpoint = Endpoint.status(404)

        let expectation1 = Completion("request should return 404 status code")
        let expectation2 = Completion("download should return 404 status code")

        let requestError = Capture<AFError?>()
        let downloadError = Capture<AFError?>()

        // When
        session.request(endpoint)
            .validate(statusCode: [200])
            .response { resp in
                requestError.value = resp.error
                expectation1.complete()
            }

        session.download(endpoint)
            .validate(statusCode: [200])
            .response { resp in
                downloadError.value = resp.error
                expectation2.complete()
            }

        await wait(for: [expectation1, expectation2])

        // Then
        #expect(requestError.value != nil)
        #expect(downloadError.value != nil)

        for error in [requestError.value, downloadError.value] {
            #expect(error?.isUnacceptableStatusCode == true)
            #expect(error?.responseCode == 404)
        }
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func validationForRequestWithNoAcceptableStatusCodesFails() async {
        // Given
        let session = stored(Session.independent())
        let endpoint = Endpoint.status(201)

        let expectation1 = Completion("request should return 201 status code")
        let expectation2 = Completion("download should return 201 status code")

        let requestError = Capture<AFError?>()
        let downloadError = Capture<AFError?>()

        // When
        session.request(endpoint)
            .validate(statusCode: [])
            .response { resp in
                requestError.value = resp.error
                expectation1.complete()
            }

        session.download(endpoint)
            .validate(statusCode: [])
            .response { resp in
                downloadError.value = resp.error
                expectation2.complete()
            }

        await wait(for: [expectation1, expectation2])

        // Then
        #expect(requestError.value != nil)
        #expect(downloadError.value != nil)

        for error in [requestError.value, downloadError.value] {
            #expect(error?.isUnacceptableStatusCode == true)
            #expect(error?.responseCode == 201)
        }
    }
}

// MARK: -

@Suite(.storesInstances)
struct ContentTypeValidationTestCase {
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func validationForRequestWithAcceptableContentTypeResponseSucceeds() async {
        // Given
        let session = stored(Session.independent())
        let endpoint = Endpoint.ip

        let expectation1 = Completion("request should succeed and return ip")
        let expectation2 = Completion("download should succeed and return ip")

        let requestError = Capture<AFError?>()
        let downloadError = Capture<AFError?>()

        // When
        session.request(endpoint)
            .validate(contentType: ["application/json"])
            .validate(contentType: ["application/json; charset=utf-8"])
            .validate(contentType: ["application/json; q=0.8; charset=utf-8"])
            .response { resp in
                requestError.value = resp.error
                expectation1.complete()
            }

        session.download(endpoint)
            .validate(contentType: ["application/json"])
            .validate(contentType: ["application/json; charset=utf-8"])
            .validate(contentType: ["application/json; q=0.8; charset=utf-8"])
            .response { resp in
                downloadError.value = resp.error
                expectation2.complete()
            }

        await wait(for: [expectation1, expectation2])

        // Then
        #expect(requestError.value == nil)
        #expect(downloadError.value == nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func validationForRequestWithAcceptableWildcardContentTypeResponseSucceeds() async {
        // Given
        let session = stored(Session.independent())
        let endpoint = Endpoint.ip

        let expectation1 = Completion("request should succeed and return ip")
        let expectation2 = Completion("download should succeed and return ip")

        let requestError = Capture<AFError?>()
        let downloadError = Capture<AFError?>()

        // When
        session.request(endpoint)
            .validate(contentType: ["*/*"])
            .validate(contentType: ["application/*"])
            .validate(contentType: ["*/json"])
            .response { resp in
                requestError.value = resp.error
                expectation1.complete()
            }

        session.download(endpoint)
            .validate(contentType: ["*/*"])
            .validate(contentType: ["application/*"])
            .validate(contentType: ["*/json"])
            .response { resp in
                downloadError.value = resp.error
                expectation2.complete()
            }

        await wait(for: [expectation1, expectation2])

        // Then
        #expect(requestError.value == nil)
        #expect(downloadError.value == nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func validationForRequestWithUnacceptableContentTypeResponseFails() async {
        // Given
        let session = stored(Session.independent())
        let endpoint = Endpoint.xml

        let expectation1 = Completion("request should succeed and return xml")
        let expectation2 = Completion("download should succeed and return xml")

        let requestError = Capture<AFError?>()
        let downloadError = Capture<AFError?>()

        // When
        session.request(endpoint)
            .validate(contentType: ["application/octet-stream"])
            .response { resp in
                requestError.value = resp.error
                expectation1.complete()
            }

        session.download(endpoint)
            .validate(contentType: ["application/octet-stream"])
            .response { resp in
                downloadError.value = resp.error
                expectation2.complete()
            }

        await wait(for: [expectation1, expectation2])

        // Then
        #expect(requestError.value != nil)
        #expect(downloadError.value != nil)

        for error in [requestError.value, downloadError.value] {
            #expect(error?.isUnacceptableContentType == true)
            #expect(error?.responseContentType == "application/xml")
            #expect(error?.acceptableContentTypes?.first == "application/octet-stream")
        }
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func contentTypeValidationFailureSortsPossibleContentTypes() async {
        // Given
        let session = stored(Session.independent())
        let endpoint = Endpoint.xml

        let requestDidCompleteExpectation = Completion("request should succeed and return xml")
        let downloadDidCompleteExpectation = Completion("download should succeed and return xml")

        let requestError = Capture<AFError?>()
        let downloadError = Capture<AFError?>()

        let acceptableContentTypes = [ // Sorted in a random order, not alphabetically
            "application/octet-stream",
            "image/gif",
            "image/x-xbitmap",
            "image/tiff",
            "image/jpg",
            "image/x-bmp",
            "image/jpeg",
            "image/x-icon",
            "image/jp2",
            "image/png",
            "image/ico",
            "image/bmp",
            "image/x-ms-bmp",
            "image/x-win-bitmap"
        ]

        // When
        session.request(endpoint)
            .validate(contentType: acceptableContentTypes)
            .response { resp in
                requestError.value = resp.error
                requestDidCompleteExpectation.complete()
            }

        session.download(endpoint)
            .validate(contentType: acceptableContentTypes)
            .response { resp in
                downloadError.value = resp.error
                downloadDidCompleteExpectation.complete()
            }

        await wait(for: [requestDidCompleteExpectation, downloadDidCompleteExpectation])

        // Then
        #expect(requestError.value != nil)
        #expect(downloadError.value != nil)

        let expectedAcceptableContentTypes = [ // Sorted in a specific order, alphabetically
            "application/octet-stream",
            "image/bmp",
            "image/gif",
            "image/ico",
            "image/jp2",
            "image/jpeg",
            "image/jpg",
            "image/png",
            "image/tiff",
            "image/x-bmp",
            "image/x-icon",
            "image/x-ms-bmp",
            "image/x-win-bitmap",
            "image/x-xbitmap"
        ]

        for error in [requestError.value, downloadError.value] {
            #expect(error?.isUnacceptableContentType == true)
            #expect(error?.responseContentType == "application/xml")
            #expect(error?.acceptableContentTypes == expectedAcceptableContentTypes)
        }
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func validationForRequestWithNoAcceptableContentTypeResponseFails() async {
        // Given
        let session = stored(Session.independent())
        let endpoint = Endpoint.xml

        let expectation1 = Completion("request should succeed and return xml")
        let expectation2 = Completion("download should succeed and return xml")

        let requestError = Capture<AFError?>()
        let downloadError = Capture<AFError?>()

        // When
        session.request(endpoint)
            .validate(contentType: [])
            .response { resp in
                requestError.value = resp.error
                expectation1.complete()
            }

        session.download(endpoint)
            .validate(contentType: [])
            .response { resp in
                downloadError.value = resp.error
                expectation2.complete()
            }

        await wait(for: [expectation1, expectation2])

        // Then
        #expect(requestError.value != nil)
        #expect(downloadError.value != nil)

        for error in [requestError.value, downloadError.value] {
            #expect(error?.isUnacceptableContentType == true)
            #expect(error?.responseContentType == "application/xml")
            #expect(error?.acceptableContentTypes?.isEmpty == true)
        }
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func validationForRequestWithNoAcceptableContentTypeResponseSucceedsWhenNoDataIsReturned() async {
        // Given
        let session = stored(Session.independent())
        let endpoint = Endpoint.status(204)

        let expectation1 = Completion("request should succeed and return no data")
        let expectation2 = Completion("download should succeed and return no data")

        let requestError = Capture<AFError?>()
        let downloadError = Capture<AFError?>()

        // When
        session.request(endpoint)
            .validate(contentType: [])
            .response { resp in
                requestError.value = resp.error
                expectation1.complete()
            }

        session.download(endpoint)
            .validate(contentType: [])
            .response { resp in
                downloadError.value = resp.error
                expectation2.complete()
            }

        await wait(for: [expectation1, expectation2])

        // Then
        #expect(requestError.value == nil)
        #expect(downloadError.value == nil)
    }
}

// MARK: -

@Suite(.storesInstances)
struct MultipleValidationTestCase {
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func validationForRequestWithAcceptableStatusCodeAndContentTypeResponseSucceeds() async {
        // Given
        let session = stored(Session.independent())
        let endpoint = Endpoint.ip

        let expectation1 = Completion("request should succeed and return ip")
        let expectation2 = Completion("request should succeed and return ip")

        let requestError = Capture<AFError?>()
        let downloadError = Capture<AFError?>()

        // When
        session.request(endpoint)
            .validate(statusCode: 200..<300)
            .validate(contentType: ["application/json"])
            .response { resp in
                requestError.value = resp.error
                expectation1.complete()
            }

        session.download(endpoint)
            .validate(statusCode: 200..<300)
            .validate(contentType: ["application/json"])
            .response { resp in
                downloadError.value = resp.error
                expectation2.complete()
            }

        await wait(for: [expectation1, expectation2])

        // Then
        #expect(requestError.value == nil)
        #expect(downloadError.value == nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func validationForRequestWithUnacceptableStatusCodeAndContentTypeResponseFailsWithStatusCodeError() async {
        // Given
        let session = stored(Session.independent())
        let endpoint = Endpoint.xml

        let expectation1 = Completion("request should succeed and return xml")
        let expectation2 = Completion("download should succeed and return xml")

        let requestError = Capture<AFError?>()
        let downloadError = Capture<AFError?>()

        // When
        session.request(endpoint)
            .validate(statusCode: 400..<600)
            .validate(contentType: ["application/octet-stream"])
            .response { resp in
                requestError.value = resp.error
                expectation1.complete()
            }

        session.download(endpoint)
            .validate(statusCode: 400..<600)
            .validate(contentType: ["application/octet-stream"])
            .response { resp in
                downloadError.value = resp.error
                expectation2.complete()
            }

        await wait(for: [expectation1, expectation2])

        // Then
        #expect(requestError.value != nil)
        #expect(downloadError.value != nil)

        for error in [requestError.value, downloadError.value] {
            #expect(error?.isUnacceptableStatusCode == true)
            #expect(error?.responseCode == 200)
        }
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func validationForRequestWithUnacceptableStatusCodeAndContentTypeResponseFailsWithContentTypeError() async {
        // Given
        let session = stored(Session.independent())
        let endpoint = Endpoint.xml

        let expectation1 = Completion("request should succeed and return xml")
        let expectation2 = Completion("download should succeed and return xml")

        let requestError = Capture<AFError?>()
        let downloadError = Capture<AFError?>()

        // When
        session.request(endpoint)
            .validate(contentType: ["application/octet-stream"])
            .validate(statusCode: 400..<600)
            .response { resp in
                requestError.value = resp.error
                expectation1.complete()
            }

        session.download(endpoint)
            .validate(contentType: ["application/octet-stream"])
            .validate(statusCode: 400..<600)
            .response { resp in
                downloadError.value = resp.error
                expectation2.complete()
            }

        await wait(for: [expectation1, expectation2])

        // Then
        #expect(requestError.value != nil)
        #expect(downloadError.value != nil)

        for error in [requestError.value, downloadError.value] {
            #expect(error?.isUnacceptableContentType == true)
            #expect(error?.responseContentType == "application/xml")
            #expect(error?.acceptableContentTypes?.first == "application/octet-stream")
        }
    }
}

// MARK: -

@Suite(.storesInstances)
struct AutomaticValidationTestCase {
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func validationForRequestWithAcceptableStatusCodeAndContentTypeResponseSucceeds() async {
        // Given
        let session = stored(Session.independent())
        let urlRequest = Endpoint.ip.modifying(\.headers, to: [.accept("application/json")])

        let expectation1 = Completion("request should succeed and return ip")
        let expectation2 = Completion("download should succeed and return ip")

        let requestError = Capture<AFError?>()
        let downloadError = Capture<AFError?>()

        // When
        session.request(urlRequest).validate().response { resp in
            requestError.value = resp.error
            expectation1.complete()
        }

        session.download(urlRequest).validate().response { resp in
            downloadError.value = resp.error
            expectation2.complete()
        }

        await wait(for: [expectation1, expectation2])

        // Then
        #expect(requestError.value == nil)
        #expect(downloadError.value == nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func validationForRequestWithUnacceptableStatusCodeResponseFails() async {
        // Given
        let session = stored(Session.independent())
        let request = Endpoint.status(404)

        let expectation1 = Completion("request should return 404 status code")
        let expectation2 = Completion("download should return 404 status code")

        let requestError = Capture<AFError?>()
        let downloadError = Capture<AFError?>()

        // When
        session.request(request)
            .validate()
            .response { resp in
                requestError.value = resp.error
                expectation1.complete()
            }

        session.download(request)
            .validate()
            .response { resp in
                downloadError.value = resp.error
                expectation2.complete()
            }

        await wait(for: [expectation1, expectation2])

        // Then
        #expect(requestError.value != nil)
        #expect(downloadError.value != nil)

        for error in [requestError.value, downloadError.value] {
            #expect(error?.isUnacceptableStatusCode == true)
            #expect(error?.responseCode == 404)
        }
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func validationForRequestWithAcceptableWildcardContentTypeResponseSucceeds() async {
        // Given
        let session = stored(Session.independent())
        let urlRequest = Endpoint.ip.modifying(\.headers, to: [.accept("application/*")])

        let expectation1 = Completion("request should succeed and return ip")
        let expectation2 = Completion("download should succeed and return ip")

        let requestError = Capture<AFError?>()
        let downloadError = Capture<AFError?>()

        // When
        session.request(urlRequest).validate().response { resp in
            requestError.value = resp.error
            expectation1.complete()
        }

        session.download(urlRequest).validate().response { resp in
            downloadError.value = resp.error
            expectation2.complete()
        }

        await wait(for: [expectation1, expectation2])

        // Then
        #expect(requestError.value == nil)
        #expect(downloadError.value == nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func validationForRequestWithAcceptableComplexContentTypeResponseSucceeds() async {
        // Given
        let session = stored(Session.independent())
        var urlRequest = Endpoint.xml.urlRequest

        let headerValue = "text/xml, application/xml, application/xhtml+xml, text/html;q=0.9, text/plain;q=0.8,*/*;q=0.5"
        urlRequest.headers["Accept"] = headerValue

        let expectation1 = Completion("request should succeed and return xml")
        let expectation2 = Completion("request should succeed and return xml")

        let requestError = Capture<AFError?>()
        let downloadError = Capture<AFError?>()

        // When
        session.request(urlRequest).validate().response { resp in
            requestError.value = resp.error
            expectation1.complete()
        }

        session.download(urlRequest).validate().response { resp in
            downloadError.value = resp.error
            expectation2.complete()
        }

        await wait(for: [expectation1, expectation2])

        // Then
        #expect(requestError.value == nil)
        #expect(downloadError.value == nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func validationForRequestWithUnacceptableContentTypeResponseFails() async {
        // Given
        let session = stored(Session.independent())
        let urlRequest = Endpoint.xml.modifying(\.headers, to: [.accept("application/json")])

        let expectation1 = Completion("request should succeed and return xml")
        let expectation2 = Completion("download should succeed and return xml")

        let requestError = Capture<AFError?>()
        let downloadError = Capture<AFError?>()

        // When
        session.request(urlRequest).validate().response { resp in
            requestError.value = resp.error
            expectation1.complete()
        }

        session.download(urlRequest).validate().response { resp in
            downloadError.value = resp.error
            expectation2.complete()
        }

        await wait(for: [expectation1, expectation2])

        // Then
        #expect(requestError.value != nil)
        #expect(downloadError.value != nil)

        for error in [requestError.value, downloadError.value] {
            #expect(error?.isUnacceptableContentType == true)
            #expect(error?.responseContentType == "application/xml")
            #expect(error?.acceptableContentTypes?.first == "application/json")
        }
    }
}

// MARK: -

private enum ValidationError: Error {
    case missingData, missingFile, fileReadFailed
}

extension DataRequest {
    func validateDataExists() -> Self {
        validate { _, _, data in
            guard data != nil else { return .failure(ValidationError.missingData) }
            return .success(())
        }
    }

    func validate(with error: any Error) -> Self {
        validate { _, _, _ in .failure(error) }
    }
}

extension DownloadRequest {
    func validateDataExists() -> Self {
        validate { [unowned self] _, _, _ in
            guard let validFileURL = fileURL else { return .failure(ValidationError.missingFile) }

            do {
                _ = try Data(contentsOf: validFileURL)
                return .success(())
            } catch {
                return .failure(ValidationError.fileReadFailed)
            }
        }
    }

    func validate(with error: any Error) -> Self {
        validate { _, _, _ in .failure(error) }
    }
}

// MARK: -

@Suite(.storesInstances)
struct CustomValidationTestCase {
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func customValidationClosureHasAccessToServerResponseData() async {
        // Given
        let session = stored(Session.independent())
        let endpoint = Endpoint()

        let expectation1 = Completion("request should return 200 status code")
        let expectation2 = Completion("download should return 200 status code")

        let requestError = Capture<AFError?>()
        let downloadError = Capture<AFError?>()

        // When
        session.request(endpoint)
            .validate { _, _, data in
                guard data != nil else { return .failure(ValidationError.missingData) }
                return .success(())
            }
            .response { resp in
                requestError.value = resp.error
                expectation1.complete()
            }

        session.download(endpoint)
            .validate { _, _, fileURL in
                guard let fileURL else { return .failure(ValidationError.missingFile) }

                do {
                    _ = try Data(contentsOf: fileURL)
                    return .success(())
                } catch {
                    return .failure(ValidationError.fileReadFailed)
                }
            }
            .response { resp in
                downloadError.value = resp.error
                expectation2.complete()
            }

        await wait(for: [expectation1, expectation2])

        // Then
        #expect(requestError.value == nil)
        #expect(downloadError.value == nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func customValidationCanThrowCustomError() async {
        // Given
        let session = stored(Session.independent())
        let endpoint = Endpoint()

        let expectation1 = Completion("request should return 200 status code")
        let expectation2 = Completion("download should return 200 status code")

        let requestError = Capture<AFError?>()
        let downloadError = Capture<AFError?>()

        // When
        session.request(endpoint)
            .validate { _, _, _ in .failure(ValidationError.missingData) }
            .validate { _, _, _ in .failure(ValidationError.missingFile) } // should be ignored
            .response { resp in
                requestError.value = resp.error
                expectation1.complete()
            }

        session.download(endpoint)
            .validate { _, _, _ in .failure(ValidationError.missingFile) }
            .validate { _, _, _ in .failure(ValidationError.fileReadFailed) } // should be ignored
            .response { resp in
                downloadError.value = resp.error
                expectation2.complete()
            }

        await wait(for: [expectation1, expectation2])

        // Then
        #expect(requestError.asAFError?.underlyingError as? ValidationError == .missingData)
        #expect(downloadError.asAFError?.underlyingError as? ValidationError == .missingFile)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func validationExtensionHasAccessToServerResponseData() async {
        // Given
        let session = stored(Session.independent())
        let endpoint = Endpoint()

        let expectation1 = Completion("request should return 200 status code")
        let expectation2 = Completion("download should return 200 status code")

        let requestError = Capture<AFError?>()
        let downloadError = Capture<AFError?>()

        // When
        session.request(endpoint)
            .validateDataExists()
            .response { resp in
                requestError.value = resp.error
                expectation1.complete()
            }

        session.download(endpoint)
            .validateDataExists()
            .response { resp in
                downloadError.value = resp.error
                expectation2.complete()
            }

        await wait(for: [expectation1, expectation2])

        // Then
        #expect(requestError.value == nil)
        #expect(downloadError.value == nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func validationExtensionCanThrowCustomError() async {
        // Given
        let session = stored(Session.independent())
        let endpoint = Endpoint()

        let expectation1 = Completion("request should return 200 status code")
        let expectation2 = Completion("download should return 200 status code")

        let requestError = Capture<AFError?>()
        let downloadError = Capture<AFError?>()

        // When
        session.request(endpoint)
            .validate(with: ValidationError.missingData)
            .validate(with: ValidationError.missingFile) // should be ignored
            .response { resp in
                requestError.value = resp.error
                expectation1.complete()
            }

        session.download(endpoint)
            .validate(with: ValidationError.missingFile)
            .validate(with: ValidationError.fileReadFailed) // should be ignored
            .response { resp in
                downloadError.value = resp.error
                expectation2.complete()
            }

        await wait(for: [expectation1, expectation2])

        // Then
        #expect(requestError.asAFError?.underlyingError as? ValidationError == .missingData)
        #expect(downloadError.asAFError?.underlyingError as? ValidationError == .missingFile)
    }
}
