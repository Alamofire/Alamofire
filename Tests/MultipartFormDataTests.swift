//
//  MultipartFormDataTests.swift
//
//  Copyright (c) 2014-2017 Alamofire Software Foundation (http://alamofire.org/)
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

import Alamofire
import Foundation
import XCTest

struct EncodingCharacters {
    static let crlf = "\r\n"
}

struct BoundaryGenerator {
    enum BoundaryType {
        case initial, encapsulated, final
    }

    static func boundary(forBoundaryType boundaryType: BoundaryType, boundaryKey: String) -> String {
        let boundary: String

        switch boundaryType {
        case .initial:
            boundary = "--\(boundaryKey)\(EncodingCharacters.crlf)"
        case .encapsulated:
            boundary = "\(EncodingCharacters.crlf)--\(boundaryKey)\(EncodingCharacters.crlf)"
        case .final:
            boundary = "\(EncodingCharacters.crlf)--\(boundaryKey)--\(EncodingCharacters.crlf)"
        }

        return boundary
    }

    static func boundaryData(boundaryType: BoundaryType, boundaryKey: String) -> Data {
        return BoundaryGenerator.boundary(
            forBoundaryType: boundaryType,
            boundaryKey: boundaryKey
        ).data(using: .utf8, allowLossyConversion: false)!
    }
}

private func temporaryFileURL() -> URL { return BaseTestCase.testDirectoryURL.appendingPathComponent(UUID().uuidString) }

// MARK: -

class MultipartFormDataPropertiesTestCase: BaseTestCase {
    func testThatContentTypeContainsBoundary() {
        // Given
        let multipartFormData = MultipartFormData()

        // When
        let boundary = multipartFormData.boundary

        // Then
        let expectedContentType = "multipart/form-data; boundary=\(boundary)"
        XCTAssertEqual(multipartFormData.contentType, expectedContentType, "contentType should match expected value")
    }

    func testThatContentLengthMatchesTotalBodyPartSize() {
        // Given
        let multipartFormData = MultipartFormData()
        let data1 = "Lorem ipsum dolor sit amet.".data(using: .utf8, allowLossyConversion: false)!
        let data2 = "Vim at integre alterum.".data(using: .utf8, allowLossyConversion: false)!

        // When
        multipartFormData.append(data1, withName: "data1")
        multipartFormData.append(data2, withName: "data2")

        // Then
        let expectedContentLength = UInt64(data1.count + data2.count)
        XCTAssertEqual(multipartFormData.contentLength, expectedContentLength, "content length should match expected value")
    }
}

// MARK: -

class MultipartFormDataEncodingTestCase: BaseTestCase {
    let crlf = EncodingCharacters.crlf

    func testEncodingDataBodyPart() {
        // Given
        let multipartFormData = MultipartFormData()

        let data = "Lorem ipsum dolor sit amet.".data(using: .utf8, allowLossyConversion: false)!
        multipartFormData.append(data, withName: "data")

        var encodedData: Data?

        // When
        do {
            encodedData = try multipartFormData.encode()
        } catch {
            // No-op
        }

        // Then
        XCTAssertNotNil(encodedData, "encoded data should not be nil")

        if let encodedData = encodedData {
            let boundary = multipartFormData.boundary

            let expectedData = (
                BoundaryGenerator.boundary(forBoundaryType: .initial, boundaryKey: boundary) +
                "Content-Disposition: form-data; name=\"data\"\(crlf)\(crlf)" +
                "Lorem ipsum dolor sit amet." +
                BoundaryGenerator.boundary(forBoundaryType: .final, boundaryKey: boundary)
            ).data(using: .utf8, allowLossyConversion: false)!

            XCTAssertEqual(encodedData, expectedData, "encoded data should match expected data")
        }
    }

    func testEncodingMultipleDataBodyParts() {
        // Given
        let multipartFormData = MultipartFormData()

        let frenchData = "français".data(using: .utf8, allowLossyConversion: false)!
        let japaneseData = "日本語".data(using: .utf8, allowLossyConversion: false)!
        let emojiData = "😃👍🏻🍻🎉".data(using: .utf8, allowLossyConversion: false)!

        multipartFormData.append(frenchData, withName: "french")
        multipartFormData.append(japaneseData, withName: "japanese", mimeType: "text/plain")
        multipartFormData.append(emojiData, withName: "emoji", mimeType: "text/plain")

        var encodedData: Data?

        // When
        do {
            encodedData = try multipartFormData.encode()
        } catch {
            // No-op
        }

        // Then
        XCTAssertNotNil(encodedData, "encoded data should not be nil")

        if let encodedData = encodedData {
            let boundary = multipartFormData.boundary

            let expectedData = (
                BoundaryGenerator.boundary(forBoundaryType: .initial, boundaryKey: boundary) +
                "Content-Disposition: form-data; name=\"french\"\(crlf)\(crlf)" +
                "français" +
                BoundaryGenerator.boundary(forBoundaryType: .encapsulated, boundaryKey: boundary) +
                "Content-Disposition: form-data; name=\"japanese\"\(crlf)" +
                "Content-Type: text/plain\(crlf)\(crlf)" +
                "日本語" +
                BoundaryGenerator.boundary(forBoundaryType: .encapsulated, boundaryKey: boundary) +
                "Content-Disposition: form-data; name=\"emoji\"\(crlf)" +
                "Content-Type: text/plain\(crlf)\(crlf)" +
                "😃👍🏻🍻🎉" +
                BoundaryGenerator.boundary(forBoundaryType: .final, boundaryKey: boundary)
            ).data(using: .utf8, allowLossyConversion: false)!

            XCTAssertEqual(encodedData, expectedData, "encoded data should match expected data")
        }
    }

    func testEncodingFileBodyPart() {
        // Given
        let multipartFormData = MultipartFormData()

        let unicornImageURL = url(forResource: "unicorn", withExtension: "png")
        multipartFormData.append(unicornImageURL, withName: "unicorn")

        var encodedData: Data?

        // When
        do {
            encodedData = try multipartFormData.encode()
        } catch {
            // No-op
        }

        // Then
        XCTAssertNotNil(encodedData, "encoded data should not be nil")

        if let encodedData = encodedData {
            let boundary = multipartFormData.boundary

            var expectedData = Data()
            expectedData.append(BoundaryGenerator.boundaryData(boundaryType: .initial, boundaryKey: boundary))
            expectedData.append((
                "Content-Disposition: form-data; name=\"unicorn\"; filename=\"unicorn.png\"\(crlf)" +
                "Content-Type: image/png\(crlf)\(crlf)"
                ).data(using: .utf8, allowLossyConversion: false)!
            )
            expectedData.append(try! Data(contentsOf: unicornImageURL))
            expectedData.append(BoundaryGenerator.boundaryData(boundaryType: .final, boundaryKey: boundary))

            XCTAssertEqual(encodedData, expectedData, "data should match expected data")
        }
    }

    func testEncodingMultipleFileBodyParts() {
        // Given
        let multipartFormData = MultipartFormData()

        let unicornImageURL = url(forResource: "unicorn", withExtension: "png")
        let rainbowImageURL = url(forResource: "rainbow", withExtension: "jpg")

        multipartFormData.append(unicornImageURL, withName: "unicorn")
        multipartFormData.append(rainbowImageURL, withName: "rainbow")

        var encodedData: Data?

        // When
        do {
            encodedData = try multipartFormData.encode()
        } catch {
            // No-op
        }

        // Then
        XCTAssertNotNil(encodedData, "encoded data should not be nil")

        if let encodedData = encodedData {
            let boundary = multipartFormData.boundary

            var expectedData = Data()
            expectedData.append(BoundaryGenerator.boundaryData(boundaryType: .initial, boundaryKey: boundary))
            expectedData.append((
                "Content-Disposition: form-data; name=\"unicorn\"; filename=\"unicorn.png\"\(crlf)" +
                "Content-Type: image/png\(crlf)\(crlf)"
                ).data(using: .utf8, allowLossyConversion: false)!
            )
            expectedData.append(try! Data(contentsOf: unicornImageURL))
            expectedData.append(BoundaryGenerator.boundaryData(boundaryType: .encapsulated, boundaryKey: boundary))
            expectedData.append((
                "Content-Disposition: form-data; name=\"rainbow\"; filename=\"rainbow.jpg\"\(crlf)" +
                "Content-Type: image/jpeg\(crlf)\(crlf)"
                ).data(using: .utf8, allowLossyConversion: false)!
            )
            expectedData.append(try! Data(contentsOf: rainbowImageURL))
            expectedData.append(BoundaryGenerator.boundaryData(boundaryType: .final, boundaryKey: boundary))

            XCTAssertEqual(encodedData, expectedData, "data should match expected data")
        }
    }

    func testEncodingStreamBodyPart() {
        // Given
        let multipartFormData = MultipartFormData()

        let unicornImageURL = url(forResource: "unicorn", withExtension: "png")
        let unicornDataLength = UInt64((try! Data(contentsOf: unicornImageURL)).count)
        let unicornStream = InputStream(url: unicornImageURL)!

        multipartFormData.append(
            unicornStream,
            withLength: unicornDataLength,
            name: "unicorn",
            fileName: "unicorn.png",
            mimeType: "image/png"
        )

        var encodedData: Data?

        // When
        do {
            encodedData = try multipartFormData.encode()
        } catch {
            // No-op
        }

        // Then
        XCTAssertNotNil(encodedData, "encoded data should not be nil")

        if let encodedData = encodedData {
            let boundary = multipartFormData.boundary

            var expectedData = Data()
            expectedData.append(BoundaryGenerator.boundaryData(boundaryType: .initial, boundaryKey: boundary))
            expectedData.append((
                "Content-Disposition: form-data; name=\"unicorn\"; filename=\"unicorn.png\"\(crlf)" +
                "Content-Type: image/png\(crlf)\(crlf)"
                ).data(using: .utf8, allowLossyConversion: false)!
            )
            expectedData.append(try! Data(contentsOf: unicornImageURL))
            expectedData.append(BoundaryGenerator.boundaryData(boundaryType: .final, boundaryKey: boundary))

            XCTAssertEqual(encodedData, expectedData, "data should match expected data")
        }
    }

    func testEncodingMultipleStreamBodyParts() {
        // Given
        let multipartFormData = MultipartFormData()

        let unicornImageURL = url(forResource: "unicorn", withExtension: "png")
        let unicornDataLength = UInt64((try! Data(contentsOf: unicornImageURL)).count)
        let unicornStream = InputStream(url: unicornImageURL)!

        let rainbowImageURL = url(forResource: "rainbow", withExtension: "jpg")
        let rainbowDataLength = UInt64((try! Data(contentsOf: rainbowImageURL)).count)
        let rainbowStream = InputStream(url: rainbowImageURL)!

        multipartFormData.append(
            unicornStream,
            withLength: unicornDataLength,
            name: "unicorn",
            fileName: "unicorn.png",
            mimeType: "image/png"
        )
        multipartFormData.append(
            rainbowStream,
            withLength: rainbowDataLength,
            name: "rainbow",
            fileName: "rainbow.jpg",
            mimeType: "image/jpeg"
        )

        var encodedData: Data?

        // When
        do {
            encodedData = try multipartFormData.encode()
        } catch {
            // No-op
        }

        // Then
        XCTAssertNotNil(encodedData, "encoded data should not be nil")

        if let encodedData = encodedData {
            let boundary = multipartFormData.boundary

            var expectedData = Data()
            expectedData.append(BoundaryGenerator.boundaryData(boundaryType: .initial, boundaryKey: boundary))
            expectedData.append((
                "Content-Disposition: form-data; name=\"unicorn\"; filename=\"unicorn.png\"\(crlf)" +
                "Content-Type: image/png\(crlf)\(crlf)"
                ).data(using: .utf8, allowLossyConversion: false)!
            )
            expectedData.append(try! Data(contentsOf: unicornImageURL))
            expectedData.append(BoundaryGenerator.boundaryData(boundaryType: .encapsulated, boundaryKey: boundary))
            expectedData.append((
                "Content-Disposition: form-data; name=\"rainbow\"; filename=\"rainbow.jpg\"\(crlf)" +
                "Content-Type: image/jpeg\(crlf)\(crlf)"
                ).data(using: .utf8, allowLossyConversion: false)!
            )
            expectedData.append(try! Data(contentsOf: rainbowImageURL))
            expectedData.append(BoundaryGenerator.boundaryData(boundaryType: .final, boundaryKey: boundary))

            XCTAssertEqual(encodedData, expectedData, "data should match expected data")
        }
    }

    func testEncodingMultipleBodyPartsWithVaryingTypes() {
        // Given
        let multipartFormData = MultipartFormData()

        let loremData = "Lorem ipsum.".data(using: .utf8, allowLossyConversion: false)!

        let unicornImageURL = url(forResource: "unicorn", withExtension: "png")

        let rainbowImageURL = url(forResource: "rainbow", withExtension: "jpg")
        let rainbowDataLength = UInt64((try! Data(contentsOf: rainbowImageURL)).count)
        let rainbowStream = InputStream(url: rainbowImageURL)!

        multipartFormData.append(loremData, withName: "lorem")
        multipartFormData.append(unicornImageURL, withName: "unicorn")
        multipartFormData.append(
            rainbowStream,
            withLength: rainbowDataLength,
            name: "rainbow",
            fileName: "rainbow.jpg",
            mimeType: "image/jpeg"
        )

        var encodedData: Data?

        // When
        do {
            encodedData = try multipartFormData.encode()
        } catch {
            // No-op
        }

        // Then
        XCTAssertNotNil(encodedData, "encoded data should not be nil")

        if let encodedData = encodedData {
            let boundary = multipartFormData.boundary

            var expectedData = Data()
            expectedData.append(BoundaryGenerator.boundaryData(boundaryType: .initial, boundaryKey: boundary))
            expectedData.append((
                "Content-Disposition: form-data; name=\"lorem\"\(crlf)\(crlf)"
                ).data(using: .utf8, allowLossyConversion: false)!
            )
            expectedData.append(loremData)
            expectedData.append(BoundaryGenerator.boundaryData(boundaryType: .encapsulated, boundaryKey: boundary))
            expectedData.append((
                "Content-Disposition: form-data; name=\"unicorn\"; filename=\"unicorn.png\"\(crlf)" +
                "Content-Type: image/png\(crlf)\(crlf)"
                ).data(using: .utf8, allowLossyConversion: false)!
            )
            expectedData.append(try! Data(contentsOf: unicornImageURL))
            expectedData.append(BoundaryGenerator.boundaryData(boundaryType: .encapsulated, boundaryKey: boundary))
            expectedData.append((
                "Content-Disposition: form-data; name=\"rainbow\"; filename=\"rainbow.jpg\"\(crlf)" +
                "Content-Type: image/jpeg\(crlf)\(crlf)"
                ).data(using: .utf8, allowLossyConversion: false)!
            )
            expectedData.append(try! Data(contentsOf: rainbowImageURL))
            expectedData.append(BoundaryGenerator.boundaryData(boundaryType: .final, boundaryKey: boundary))

            XCTAssertEqual(encodedData, expectedData, "data should match expected data")
        }
    }
}

// MARK: -

class MultipartFormDataWriteEncodedDataToDiskTestCase: BaseTestCase {
    let crlf = EncodingCharacters.crlf

    func testWritingEncodedDataBodyPartToDisk() {
        // Given
        let fileURL = temporaryFileURL()
        let multipartFormData = MultipartFormData()

        let data = "Lorem ipsum dolor sit amet.".data(using: .utf8, allowLossyConversion: false)!
        multipartFormData.append(data, withName: "data")

        var encodingError: Error?

        // When
        do {
            try multipartFormData.writeEncodedData(to: fileURL)
        } catch {
            encodingError = error
        }

        // Then
        XCTAssertNil(encodingError, "encoding error should be nil")

        if let fileData = try? Data(contentsOf: fileURL) {
            let boundary = multipartFormData.boundary

            let expectedFileData = (
                BoundaryGenerator.boundary(forBoundaryType: .initial, boundaryKey: boundary) +
                "Content-Disposition: form-data; name=\"data\"\(crlf)\(crlf)" +
                "Lorem ipsum dolor sit amet." +
                BoundaryGenerator.boundary(forBoundaryType: .final, boundaryKey: boundary)
            ).data(using: .utf8, allowLossyConversion: false)!

            XCTAssertEqual(fileData, expectedFileData, "file data should match expected file data")
        } else {
            XCTFail("file data should not be nil")
        }
    }

    func testWritingMultipleEncodedDataBodyPartsToDisk() {
        // Given
        let fileURL = temporaryFileURL()
        let multipartFormData = MultipartFormData()

        let frenchData = "français".data(using: .utf8, allowLossyConversion: false)!
        let japaneseData = "日本語".data(using: .utf8, allowLossyConversion: false)!
        let emojiData = "😃👍🏻🍻🎉".data(using: .utf8, allowLossyConversion: false)!

        multipartFormData.append(frenchData, withName: "french")
        multipartFormData.append(japaneseData, withName: "japanese")
        multipartFormData.append(emojiData, withName: "emoji")

        var encodingError: Error?

        // When
        do {
            try multipartFormData.writeEncodedData(to: fileURL)
        } catch {
            encodingError = error
        }

        // Then
        XCTAssertNil(encodingError, "encoding error should be nil")

        if let fileData = try? Data(contentsOf: fileURL) {
            let boundary = multipartFormData.boundary

            let expectedFileData = (
                BoundaryGenerator.boundary(forBoundaryType: .initial, boundaryKey: boundary) +
                "Content-Disposition: form-data; name=\"french\"\(crlf)\(crlf)" +
                "français" +
                BoundaryGenerator.boundary(forBoundaryType: .encapsulated, boundaryKey: boundary) +
                "Content-Disposition: form-data; name=\"japanese\"\(crlf)\(crlf)" +
                "日本語" +
                BoundaryGenerator.boundary(forBoundaryType: .encapsulated, boundaryKey: boundary) +
                "Content-Disposition: form-data; name=\"emoji\"\(crlf)\(crlf)" +
                "😃👍🏻🍻🎉" +
                BoundaryGenerator.boundary(forBoundaryType: .final, boundaryKey: boundary)
            ).data(using: .utf8, allowLossyConversion: false)!

            XCTAssertEqual(fileData, expectedFileData, "file data should match expected file data")
        } else {
            XCTFail("file data should not be nil")
        }
    }

    func testWritingEncodedFileBodyPartToDisk() {
        // Given
        let fileURL = temporaryFileURL()
        let multipartFormData = MultipartFormData()

        let unicornImageURL = url(forResource: "unicorn", withExtension: "png")
        multipartFormData.append(unicornImageURL, withName: "unicorn")

        var encodingError: Error?

        // When
        do {
            try multipartFormData.writeEncodedData(to: fileURL)
        } catch {
            encodingError = error
        }

        // Then
        XCTAssertNil(encodingError, "encoding error should be nil")

        if let fileData = try? Data(contentsOf: fileURL) {
            let boundary = multipartFormData.boundary

            var expectedFileData = Data()
            expectedFileData.append(BoundaryGenerator.boundaryData(boundaryType: .initial, boundaryKey: boundary))
            expectedFileData.append((
                "Content-Disposition: form-data; name=\"unicorn\"; filename=\"unicorn.png\"\(crlf)" +
                "Content-Type: image/png\(crlf)\(crlf)"
                ).data(using: .utf8, allowLossyConversion: false)!
            )
            expectedFileData.append(try! Data(contentsOf: unicornImageURL))
            expectedFileData.append(BoundaryGenerator.boundaryData(boundaryType: .final, boundaryKey: boundary))

            XCTAssertEqual(fileData, expectedFileData, "file data should match expected file data")
        } else {
            XCTFail("file data should not be nil")
        }
    }

    func testWritingMultipleEncodedFileBodyPartsToDisk() {
        // Given
        let fileURL = temporaryFileURL()
        let multipartFormData = MultipartFormData()

        let unicornImageURL = url(forResource: "unicorn", withExtension: "png")
        let rainbowImageURL = url(forResource: "rainbow", withExtension: "jpg")

        multipartFormData.append(unicornImageURL, withName: "unicorn")
        multipartFormData.append(rainbowImageURL, withName: "rainbow")

        var encodingError: Error?

        // When
        do {
            try multipartFormData.writeEncodedData(to: fileURL)
        } catch {
            encodingError = error
        }

        // Then
        XCTAssertNil(encodingError, "encoding error should be nil")

        if let fileData = try? Data(contentsOf: fileURL) {
            let boundary = multipartFormData.boundary

            var expectedFileData = Data()
            expectedFileData.append(BoundaryGenerator.boundaryData(boundaryType: .initial, boundaryKey: boundary))
            expectedFileData.append((
                "Content-Disposition: form-data; name=\"unicorn\"; filename=\"unicorn.png\"\(crlf)" +
                "Content-Type: image/png\(crlf)\(crlf)"
                ).data(using: .utf8, allowLossyConversion: false)!
            )
            expectedFileData.append(try! Data(contentsOf: unicornImageURL))
            expectedFileData.append(BoundaryGenerator.boundaryData(boundaryType: .encapsulated, boundaryKey: boundary))
            expectedFileData.append((
                "Content-Disposition: form-data; name=\"rainbow\"; filename=\"rainbow.jpg\"\(crlf)" +
                "Content-Type: image/jpeg\(crlf)\(crlf)"
                ).data(using: .utf8, allowLossyConversion: false)!
            )
            expectedFileData.append(try! Data(contentsOf: rainbowImageURL))
            expectedFileData.append(BoundaryGenerator.boundaryData(boundaryType: .final, boundaryKey: boundary))

            XCTAssertEqual(fileData, expectedFileData, "file data should match expected file data")
        } else {
            XCTFail("file data should not be nil")
        }
    }

    func testWritingEncodedStreamBodyPartToDisk() {
        // Given
        let fileURL = temporaryFileURL()
        let multipartFormData = MultipartFormData()

        let unicornImageURL = url(forResource: "unicorn", withExtension: "png")
        let unicornDataLength = UInt64((try! Data(contentsOf: unicornImageURL)).count)
        let unicornStream = InputStream(url: unicornImageURL)!

        multipartFormData.append(
            unicornStream,
            withLength: unicornDataLength,
            name: "unicorn",
            fileName: "unicorn.png",
            mimeType: "image/png"
        )

        var encodingError: Error?

        // When
        do {
            try multipartFormData.writeEncodedData(to: fileURL)
        } catch {
            encodingError = error
        }

        // Then
        XCTAssertNil(encodingError, "encoding error should be nil")

        if let fileData = try? Data(contentsOf: fileURL) {
            let boundary = multipartFormData.boundary

            var expectedFileData = Data()
            expectedFileData.append(BoundaryGenerator.boundaryData(boundaryType: .initial, boundaryKey: boundary))
            expectedFileData.append((
                "Content-Disposition: form-data; name=\"unicorn\"; filename=\"unicorn.png\"\(crlf)" +
                "Content-Type: image/png\(crlf)\(crlf)"
                ).data(using: .utf8, allowLossyConversion: false)!
            )
            expectedFileData.append(try! Data(contentsOf: unicornImageURL))
            expectedFileData.append(BoundaryGenerator.boundaryData(boundaryType: .final, boundaryKey: boundary))

            XCTAssertEqual(fileData, expectedFileData, "file data should match expected file data")
        } else {
            XCTFail("file data should not be nil")
        }
    }

    func testWritingMultipleEncodedStreamBodyPartsToDisk() {
        // Given
        let fileURL = temporaryFileURL()
        let multipartFormData = MultipartFormData()

        let unicornImageURL = url(forResource: "unicorn", withExtension: "png")
        let unicornDataLength = UInt64((try! Data(contentsOf: unicornImageURL)).count)
        let unicornStream = InputStream(url: unicornImageURL)!

        let rainbowImageURL = url(forResource: "rainbow", withExtension: "jpg")
        let rainbowDataLength = UInt64((try! Data(contentsOf: rainbowImageURL)).count)
        let rainbowStream = InputStream(url: rainbowImageURL)!

        multipartFormData.append(
            unicornStream,
            withLength: unicornDataLength,
            name: "unicorn",
            fileName: "unicorn.png",
            mimeType: "image/png"
        )
        multipartFormData.append(
            rainbowStream,
            withLength: rainbowDataLength,
            name: "rainbow",
            fileName: "rainbow.jpg",
            mimeType: "image/jpeg"
        )


        var encodingError: Error?

        // When
        do {
            try multipartFormData.writeEncodedData(to: fileURL)
        } catch {
            encodingError = error
        }

        // Then
        XCTAssertNil(encodingError, "encoding error should be nil")

        if let fileData = try? Data(contentsOf: fileURL) {
            let boundary = multipartFormData.boundary

            var expectedFileData = Data()
            expectedFileData.append(BoundaryGenerator.boundaryData(boundaryType: .initial, boundaryKey: boundary))
            expectedFileData.append((
                "Content-Disposition: form-data; name=\"unicorn\"; filename=\"unicorn.png\"\(crlf)" +
                "Content-Type: image/png\(crlf)\(crlf)"
                ).data(using: .utf8, allowLossyConversion: false)!
            )
            expectedFileData.append(try! Data(contentsOf: unicornImageURL))
            expectedFileData.append(BoundaryGenerator.boundaryData(boundaryType: .encapsulated, boundaryKey: boundary))
            expectedFileData.append((
                "Content-Disposition: form-data; name=\"rainbow\"; filename=\"rainbow.jpg\"\(crlf)" +
                "Content-Type: image/jpeg\(crlf)\(crlf)"
                ).data(using: .utf8, allowLossyConversion: false)!
            )
            expectedFileData.append(try! Data(contentsOf: rainbowImageURL))
            expectedFileData.append(BoundaryGenerator.boundaryData(boundaryType: .final, boundaryKey: boundary))

            XCTAssertEqual(fileData, expectedFileData, "file data should match expected file data")
        } else {
            XCTFail("file data should not be nil")
        }
    }

    func testWritingMultipleEncodedBodyPartsWithVaryingTypesToDisk() {
        // Given
        let fileURL = temporaryFileURL()
        let multipartFormData = MultipartFormData()

        let loremData = "Lorem ipsum.".data(using: .utf8, allowLossyConversion: false)!

        let unicornImageURL = url(forResource: "unicorn", withExtension: "png")

        let rainbowImageURL = url(forResource: "rainbow", withExtension: "jpg")
        let rainbowDataLength = UInt64((try! Data(contentsOf: rainbowImageURL)).count)
        let rainbowStream = InputStream(url: rainbowImageURL)!

        multipartFormData.append(loremData, withName: "lorem")
        multipartFormData.append(unicornImageURL, withName: "unicorn")
        multipartFormData.append(
            rainbowStream,
            withLength: rainbowDataLength,
            name: "rainbow",
            fileName: "rainbow.jpg",
            mimeType: "image/jpeg"
        )

        var encodingError: Error?

        // When
        do {
            try multipartFormData.writeEncodedData(to: fileURL)
        } catch {
            encodingError = error
        }

        // Then
        XCTAssertNil(encodingError, "encoding error should be nil")

        if let fileData = try? Data(contentsOf: fileURL) {
            let boundary = multipartFormData.boundary

            var expectedFileData = Data()
            expectedFileData.append(BoundaryGenerator.boundaryData(boundaryType: .initial, boundaryKey: boundary))
            expectedFileData.append((
                "Content-Disposition: form-data; name=\"lorem\"\(crlf)\(crlf)"
                ).data(using: .utf8, allowLossyConversion: false)!
            )
            expectedFileData.append(loremData)
            expectedFileData.append(BoundaryGenerator.boundaryData(boundaryType: .encapsulated, boundaryKey: boundary))
            expectedFileData.append((
                "Content-Disposition: form-data; name=\"unicorn\"; filename=\"unicorn.png\"\(crlf)" +
                "Content-Type: image/png\(crlf)\(crlf)"
                ).data(using: .utf8, allowLossyConversion: false)!
            )
            expectedFileData.append(try! Data(contentsOf: unicornImageURL))
            expectedFileData.append(BoundaryGenerator.boundaryData(boundaryType: .encapsulated, boundaryKey: boundary))
            expectedFileData.append((
                "Content-Disposition: form-data; name=\"rainbow\"; filename=\"rainbow.jpg\"\(crlf)" +
                "Content-Type: image/jpeg\(crlf)\(crlf)"
                ).data(using: .utf8, allowLossyConversion: false)!
            )
            expectedFileData.append(try! Data(contentsOf: rainbowImageURL))
            expectedFileData.append(BoundaryGenerator.boundaryData(boundaryType: .final, boundaryKey: boundary))

            XCTAssertEqual(fileData, expectedFileData, "file data should match expected file data")
        } else {
            XCTFail("file data should not be nil")
        }
    }
}

// MARK: -

class MultipartFormDataFailureTestCase: BaseTestCase {
    func testThatAppendingFileBodyPartWithInvalidLastPathComponentReturnsError() {
        // Given
        let fileURL = NSURL(string: "")! as URL
        let multipartFormData = MultipartFormData()
        multipartFormData.append(fileURL, withName: "empty_data")

        var encodingError: Error?

        // When
        do {
            _ = try multipartFormData.encode()
        } catch {
            encodingError = error
        }

        // Then
        XCTAssertNotNil(encodingError, "encoding error should not be nil")

        if let error = encodingError as? AFError {
            XCTAssertTrue(error.isBodyPartFilenameInvalid)

            let expectedFailureReason = "The URL provided does not have a valid filename: \(fileURL)"
            XCTAssertEqual(error.localizedDescription, expectedFailureReason, "failure reason does not match expected value")
        } else {
            XCTFail("Error should be AFError.")
        }
    }

    func testThatAppendingFileBodyPartThatIsNotFileURLReturnsError() {
        // Given
        let fileURL = URL(string: "https://example.com/image.jpg")!
        let multipartFormData = MultipartFormData()
        multipartFormData.append(fileURL, withName: "empty_data")

        var encodingError: Error?

        // When
        do {
            _ = try multipartFormData.encode()
        } catch {
            encodingError = error
        }

        // Then
        XCTAssertNotNil(encodingError, "encoding error should not be nil")

        if let error = encodingError as? AFError {
            XCTAssertTrue(error.isBodyPartURLInvalid)

            let expectedFailureReason = "The URL provided is not a file URL: \(fileURL)"
            XCTAssertEqual(error.localizedDescription, expectedFailureReason, "error failure reason does not match expected value")
        } else {
            XCTFail("Error should be AFError.")
        }
    }

    func testThatAppendingFileBodyPartThatIsNotReachableReturnsError() {
        // Given
        let filePath = (NSTemporaryDirectory() as NSString).appendingPathComponent("does_not_exist.jpg")
        let fileURL = URL(fileURLWithPath: filePath)
        let multipartFormData = MultipartFormData()
        multipartFormData.append(fileURL, withName: "empty_data")

        var encodingError: Error?

        // When
        do {
            _ = try multipartFormData.encode()
        } catch {
            encodingError = error
        }

        // Then
        XCTAssertNotNil(encodingError, "encoding error should not be nil")

        if let error = encodingError as? AFError {
            XCTAssertTrue(error.isBodyPartFileNotReachableWithError)
        } else {
            XCTFail("Error should be AFError.")
        }
    }

    func testThatAppendingFileBodyPartThatIsDirectoryReturnsError() {
        // Given
        let directoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let multipartFormData = MultipartFormData()
        multipartFormData.append(directoryURL, withName: "empty_data", fileName: "empty", mimeType: "application/octet")

        var encodingError: Error?

        // When
        do {
            _ = try multipartFormData.encode()
        } catch {
            encodingError = error
        }

        // Then
        XCTAssertNotNil(encodingError, "encoding error should not be nil")

        if let error = encodingError as? AFError {
            XCTAssertTrue(error.isBodyPartFileIsDirectory)

            let expectedFailureReason = "The URL provided is a directory: \(directoryURL)"
            XCTAssertEqual(error.localizedDescription, expectedFailureReason, "error failure reason does not match expected value")
        } else {
            XCTFail("Error should be AFError.")
        }
    }

    func testThatWritingEncodedDataToExistingFileURLFails() {
        // Given
        let fileURL = temporaryFileURL()

        var writerError: Error?

        do {
            try "dummy data".write(to: fileURL, atomically: true, encoding: String.Encoding.utf8)
        } catch {
            writerError = error
        }

        let multipartFormData = MultipartFormData()
        let data = "Lorem ipsum dolor sit amet.".data(using: .utf8, allowLossyConversion: false)!
        multipartFormData.append(data, withName: "data")

        var encodingError: Error?

        // When
        do {
            try multipartFormData.writeEncodedData(to: fileURL)
        } catch {
            encodingError = error
        }

        // Then
        XCTAssertNil(writerError, "writer error should be nil")
        XCTAssertNotNil(encodingError, "encoding error should not be nil")

        if let encodingError = encodingError as? AFError {
            XCTAssertTrue(encodingError.isOutputStreamFileAlreadyExists)
        }
    }

    func testThatWritingEncodedDataToBadURLFails() {
        // Given
        let fileURL = URL(string: "/this/is/not/a/valid/url")!

        let multipartFormData = MultipartFormData()
        let data = "Lorem ipsum dolor sit amet.".data(using: .utf8, allowLossyConversion: false)!
        multipartFormData.append(data, withName: "data")

        var encodingError: Error?

        // When
        do {
            try multipartFormData.writeEncodedData(to: fileURL)
        } catch {
            encodingError = error
        }

        // Then
        XCTAssertNotNil(encodingError, "encoding error should not be nil")

        if let encodingError = encodingError as? AFError {
            XCTAssertTrue(encodingError.isOutputStreamURLInvalid)
        }
    }
}
