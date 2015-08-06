// MultipartFormDataTests.swift
//
// Copyright (c) 2014–2015 Alamofire Software Foundation (http://alamofire.org/)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Alamofire
import Foundation
import XCTest

struct EncodingCharacters {
    static let CRLF = "\r\n"
}

struct BoundaryGenerator {
    enum BoundaryType {
        case Initial, Encapsulated, Final
    }

    static func boundary(boundaryType boundaryType: BoundaryType, boundaryKey: String) -> String {
        let boundary: String

        switch boundaryType {
        case .Initial:
            boundary = "--\(boundaryKey)\(EncodingCharacters.CRLF)"
        case .Encapsulated:
            boundary = "\(EncodingCharacters.CRLF)--\(boundaryKey)\(EncodingCharacters.CRLF)"
        case .Final:
            boundary = "\(EncodingCharacters.CRLF)--\(boundaryKey)--\(EncodingCharacters.CRLF)"
        }

        return boundary
    }

    static func boundaryData(boundaryType boundaryType: BoundaryType, boundaryKey: String) -> NSData {
        return BoundaryGenerator.boundary(
            boundaryType: boundaryType,
            boundaryKey: boundaryKey
        ).dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
    }
}

private func temporaryFileURL() -> NSURL {
    let tempDirectoryURL = NSURL(fileURLWithPath: NSTemporaryDirectory())
    let directoryURL = tempDirectoryURL.URLByAppendingPathComponent("com.alamofire.test/multipart.form.data")

    let fileManager = NSFileManager.defaultManager()
    do {
        try fileManager.createDirectoryAtURL(directoryURL, withIntermediateDirectories: true, attributes: nil)
    } catch {
        // No-op - will cause tests to fail, not crash
    }

    let fileName = NSUUID().UUIDString
    let fileURL = directoryURL.URLByAppendingPathComponent(fileName)

    return fileURL
}

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
        let data1 = "Lorem ipsum dolor sit amet.".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
        let data2 = "Vim at integre alterum.".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!

        // When
        multipartFormData.appendBodyPart(data: data1, name: "data1")
        multipartFormData.appendBodyPart(data: data2, name: "data2")

        // Then
        let expectedContentLength = UInt64(data1.length + data2.length)
        XCTAssertEqual(multipartFormData.contentLength, expectedContentLength, "content length should match expected value")
    }
}

// MARK: -

class MultipartFormDataEncodingTestCase: BaseTestCase {
    let CRLF = EncodingCharacters.CRLF

    func testEncodingDataBodyPart() {
        // Given
        let multipartFormData = MultipartFormData()

        let data = "Lorem ipsum dolor sit amet.".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
        multipartFormData.appendBodyPart(data: data, name: "data")

        var encodedData: NSData?

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
                BoundaryGenerator.boundary(boundaryType: .Initial, boundaryKey: boundary) +
                "Content-Disposition: form-data; name=\"data\"\(CRLF)\(CRLF)" +
                "Lorem ipsum dolor sit amet." +
                BoundaryGenerator.boundary(boundaryType: .Final, boundaryKey: boundary)
            ).dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!

            XCTAssertEqual(encodedData, expectedData, "encoded data should match expected data")
        }
    }

    func testEncodingMultipleDataBodyParts() {
        // Given
        let multipartFormData = MultipartFormData()

        let french = "français".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
        let japanese = "日本語".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
        let emoji = "😃👍🏻🍻🎉".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!

        multipartFormData.appendBodyPart(data: french, name: "french")
        multipartFormData.appendBodyPart(data: japanese, name: "japanese", mimeType: "text/plain")
        multipartFormData.appendBodyPart(data: emoji, name: "emoji", mimeType: "text/plain")
        
        var encodedData: NSData?

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
                BoundaryGenerator.boundary(boundaryType: .Initial, boundaryKey: boundary) +
                "Content-Disposition: form-data; name=\"french\"\(CRLF)\(CRLF)" +
                "français" +
                BoundaryGenerator.boundary(boundaryType: .Encapsulated, boundaryKey: boundary) +
                "Content-Disposition: form-data; name=\"japanese\"\(CRLF)" +
                "Content-Type: text/plain\(CRLF)\(CRLF)" +
                "日本語" +
                BoundaryGenerator.boundary(boundaryType: .Encapsulated, boundaryKey: boundary) +
                "Content-Disposition: form-data; name=\"emoji\"\(CRLF)" +
                "Content-Type: text/plain\(CRLF)\(CRLF)" +
                "😃👍🏻🍻🎉" +
                BoundaryGenerator.boundary(boundaryType: .Final, boundaryKey: boundary)
            ).dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!

            XCTAssertEqual(encodedData, expectedData, "encoded data should match expected data")
        }
    }

    func testEncodingFileBodyPart() {
        // Given
        let multipartFormData = MultipartFormData()

        let unicornImageURL = URLForResource("unicorn", withExtension: "png")
        multipartFormData.appendBodyPart(fileURL: unicornImageURL, name: "unicorn")

        var encodedData: NSData?

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

            let expectedData = NSMutableData()
            expectedData.appendData(BoundaryGenerator.boundaryData(boundaryType: .Initial, boundaryKey: boundary))
            expectedData.appendData((
                "Content-Disposition: form-data; name=\"unicorn\"; filename=\"unicorn.png\"\(CRLF)" +
                "Content-Type: image/png\(CRLF)\(CRLF)"
                ).dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
            )
            expectedData.appendData(NSData(contentsOfURL: unicornImageURL)!)
            expectedData.appendData(BoundaryGenerator.boundaryData(boundaryType: .Final, boundaryKey: boundary))

            XCTAssertEqual(encodedData, expectedData, "data should match expected data")
        }
    }

    func testEncodingMultipleFileBodyParts() {
        // Given
        let multipartFormData = MultipartFormData()

        let unicornImageURL = URLForResource("unicorn", withExtension: "png")
        let rainbowImageURL = URLForResource("rainbow", withExtension: "jpg")

        multipartFormData.appendBodyPart(fileURL: unicornImageURL, name: "unicorn")
        multipartFormData.appendBodyPart(fileURL: rainbowImageURL, name: "rainbow")

        var encodedData: NSData?

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

            let expectedData = NSMutableData()
            expectedData.appendData(BoundaryGenerator.boundaryData(boundaryType: .Initial, boundaryKey: boundary))
            expectedData.appendData((
                "Content-Disposition: form-data; name=\"unicorn\"; filename=\"unicorn.png\"\(CRLF)" +
                "Content-Type: image/png\(CRLF)\(CRLF)"
                ).dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
            )
            expectedData.appendData(NSData(contentsOfURL: unicornImageURL)!)
            expectedData.appendData(BoundaryGenerator.boundaryData(boundaryType: .Encapsulated, boundaryKey: boundary))
            expectedData.appendData((
                "Content-Disposition: form-data; name=\"rainbow\"; filename=\"rainbow.jpg\"\(CRLF)" +
                "Content-Type: image/jpeg\(CRLF)\(CRLF)"
                ).dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
            )
            expectedData.appendData(NSData(contentsOfURL: rainbowImageURL)!)
            expectedData.appendData(BoundaryGenerator.boundaryData(boundaryType: .Final, boundaryKey: boundary))

            XCTAssertEqual(encodedData, expectedData, "data should match expected data")
        }
    }

    func testEncodingStreamBodyPart() {
        // Given
        let multipartFormData = MultipartFormData()

        let unicornImageURL = URLForResource("unicorn", withExtension: "png")
        let unicornDataLength = UInt64(NSData(contentsOfURL: unicornImageURL)!.length)
        let unicornStream = NSInputStream(URL: unicornImageURL)!

        multipartFormData.appendBodyPart(
            stream: unicornStream,
            length: unicornDataLength,
            name: "unicorn",
            fileName: "unicorn.png",
            mimeType: "image/png"
        )

        var encodedData: NSData?

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

            let expectedData = NSMutableData()
            expectedData.appendData(BoundaryGenerator.boundaryData(boundaryType: .Initial, boundaryKey: boundary))
            expectedData.appendData((
                "Content-Disposition: form-data; name=\"unicorn\"; filename=\"unicorn.png\"\(CRLF)" +
                "Content-Type: image/png\(CRLF)\(CRLF)"
                ).dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
            )
            expectedData.appendData(NSData(contentsOfURL: unicornImageURL)!)
            expectedData.appendData(BoundaryGenerator.boundaryData(boundaryType: .Final, boundaryKey: boundary))

            XCTAssertEqual(encodedData, expectedData, "data should match expected data")
        }
    }

    func testEncodingMultipleStreamBodyParts() {
        // Given
        let multipartFormData = MultipartFormData()

        let unicornImageURL = URLForResource("unicorn", withExtension: "png")
        let unicornDataLength = UInt64(NSData(contentsOfURL: unicornImageURL)!.length)
        let unicornStream = NSInputStream(URL: unicornImageURL)!

        let rainbowImageURL = URLForResource("rainbow", withExtension: "jpg")
        let rainbowDataLength = UInt64(NSData(contentsOfURL: rainbowImageURL)!.length)
        let rainbowStream = NSInputStream(URL: rainbowImageURL)!

        multipartFormData.appendBodyPart(
            stream: unicornStream,
            length: unicornDataLength,
            name: "unicorn",
            fileName: "unicorn.png",
            mimeType: "image/png"
        )
        multipartFormData.appendBodyPart(
            stream: rainbowStream,
            length: rainbowDataLength,
            name: "rainbow",
            fileName: "rainbow.jpg",
            mimeType: "image/jpeg"
        )

        var encodedData: NSData?

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

            let expectedData = NSMutableData()
            expectedData.appendData(BoundaryGenerator.boundaryData(boundaryType: .Initial, boundaryKey: boundary))
            expectedData.appendData((
                "Content-Disposition: form-data; name=\"unicorn\"; filename=\"unicorn.png\"\(CRLF)" +
                "Content-Type: image/png\(CRLF)\(CRLF)"
                ).dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
            )
            expectedData.appendData(NSData(contentsOfURL: unicornImageURL)!)
            expectedData.appendData(BoundaryGenerator.boundaryData(boundaryType: .Encapsulated, boundaryKey: boundary))
            expectedData.appendData((
                "Content-Disposition: form-data; name=\"rainbow\"; filename=\"rainbow.jpg\"\(CRLF)" +
                "Content-Type: image/jpeg\(CRLF)\(CRLF)"
                ).dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
            )
            expectedData.appendData(NSData(contentsOfURL: rainbowImageURL)!)
            expectedData.appendData(BoundaryGenerator.boundaryData(boundaryType: .Final, boundaryKey: boundary))

            XCTAssertEqual(encodedData, expectedData, "data should match expected data")
        }
    }

    func testEncodingMultipleBodyPartsWithVaryingTypes() {
        // Given
        let multipartFormData = MultipartFormData()

        let loremData = "Lorem ipsum.".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!

        let unicornImageURL = URLForResource("unicorn", withExtension: "png")

        let rainbowImageURL = URLForResource("rainbow", withExtension: "jpg")
        let rainbowDataLength = UInt64(NSData(contentsOfURL: rainbowImageURL)!.length)
        let rainbowStream = NSInputStream(URL: rainbowImageURL)!

        multipartFormData.appendBodyPart(data: loremData, name: "lorem")
        multipartFormData.appendBodyPart(fileURL: unicornImageURL, name: "unicorn")
        multipartFormData.appendBodyPart(
            stream: rainbowStream,
            length: rainbowDataLength,
            name: "rainbow",
            fileName: "rainbow.jpg",
            mimeType: "image/jpeg"
        )

        var encodedData: NSData?

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

            let expectedData = NSMutableData()
            expectedData.appendData(BoundaryGenerator.boundaryData(boundaryType: .Initial, boundaryKey: boundary))
            expectedData.appendData((
                "Content-Disposition: form-data; name=\"lorem\"\(CRLF)\(CRLF)"
                ).dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
            )
            expectedData.appendData(loremData)
            expectedData.appendData(BoundaryGenerator.boundaryData(boundaryType: .Encapsulated, boundaryKey: boundary))
            expectedData.appendData((
                "Content-Disposition: form-data; name=\"unicorn\"; filename=\"unicorn.png\"\(CRLF)" +
                "Content-Type: image/png\(CRLF)\(CRLF)"
                ).dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
            )
            expectedData.appendData(NSData(contentsOfURL: unicornImageURL)!)
            expectedData.appendData(BoundaryGenerator.boundaryData(boundaryType: .Encapsulated, boundaryKey: boundary))
            expectedData.appendData((
                "Content-Disposition: form-data; name=\"rainbow\"; filename=\"rainbow.jpg\"\(CRLF)" +
                "Content-Type: image/jpeg\(CRLF)\(CRLF)"
                ).dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
            )
            expectedData.appendData(NSData(contentsOfURL: rainbowImageURL)!)
            expectedData.appendData(BoundaryGenerator.boundaryData(boundaryType: .Final, boundaryKey: boundary))

            XCTAssertEqual(encodedData, expectedData, "data should match expected data")
        }
    }
}

// MARK: -

class MultipartFormDataWriteEncodedDataToDiskTestCase: BaseTestCase {
    let CRLF = EncodingCharacters.CRLF

    func testWritingEncodedDataBodyPartToDisk() {
        // Given
        let fileURL = temporaryFileURL()
        let multipartFormData = MultipartFormData()

        let data = "Lorem ipsum dolor sit amet.".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
        multipartFormData.appendBodyPart(data: data, name: "data")

        var encodingError: NSError?

        // When
        do {
            try multipartFormData.writeEncodedDataToDisk(fileURL)
        } catch {
            encodingError = error as NSError
        }

        // Then
        XCTAssertNil(encodingError, "encoding error should be nil")

        if let fileData = NSData(contentsOfURL: fileURL) {
            let boundary = multipartFormData.boundary

            let expectedFileData = (
                BoundaryGenerator.boundary(boundaryType: .Initial, boundaryKey: boundary) +
                "Content-Disposition: form-data; name=\"data\"\(CRLF)\(CRLF)" +
                "Lorem ipsum dolor sit amet." +
                BoundaryGenerator.boundary(boundaryType: .Final, boundaryKey: boundary)
            ).dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!

            XCTAssertEqual(fileData, expectedFileData, "file data should match expected file data")
        } else {
            XCTFail("file data should not be nil")
        }
    }

    func testWritingMultipleEncodedDataBodyPartsToDisk() {
        // Given
        let fileURL = temporaryFileURL()
        let multipartFormData = MultipartFormData()

        let french = "français".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
        let japanese = "日本語".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
        let emoji = "😃👍🏻🍻🎉".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!

        multipartFormData.appendBodyPart(data: french, name: "french")
        multipartFormData.appendBodyPart(data: japanese, name: "japanese")
        multipartFormData.appendBodyPart(data: emoji, name: "emoji")

        var encodingError: NSError?

        // When
        do {
            try multipartFormData.writeEncodedDataToDisk(fileURL)
        } catch {
            encodingError = error as NSError
        }

        // Then
        XCTAssertNil(encodingError, "encoding error should be nil")

        if let fileData = NSData(contentsOfURL: fileURL) {
            let boundary = multipartFormData.boundary

            let expectedFileData = (
                BoundaryGenerator.boundary(boundaryType: .Initial, boundaryKey: boundary) +
                "Content-Disposition: form-data; name=\"french\"\(CRLF)\(CRLF)" +
                "français" +
                BoundaryGenerator.boundary(boundaryType: .Encapsulated, boundaryKey: boundary) +
                "Content-Disposition: form-data; name=\"japanese\"\(CRLF)\(CRLF)" +
                "日本語" +
                BoundaryGenerator.boundary(boundaryType: .Encapsulated, boundaryKey: boundary) +
                "Content-Disposition: form-data; name=\"emoji\"\(CRLF)\(CRLF)" +
                "😃👍🏻🍻🎉" +
                BoundaryGenerator.boundary(boundaryType: .Final, boundaryKey: boundary)
            ).dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!

            XCTAssertEqual(fileData, expectedFileData, "file data should match expected file data")
        } else {
            XCTFail("file data should not be nil")
        }
    }

    func testWritingEncodedFileBodyPartToDisk() {
        // Given
        let fileURL = temporaryFileURL()
        let multipartFormData = MultipartFormData()

        let unicornImageURL = URLForResource("unicorn", withExtension: "png")
        multipartFormData.appendBodyPart(fileURL: unicornImageURL, name: "unicorn")

        var encodingError: NSError?

        // When
        do {
            try multipartFormData.writeEncodedDataToDisk(fileURL)
        } catch {
            encodingError = error as NSError
        }

        // Then
        XCTAssertNil(encodingError, "encoding error should be nil")

        if let fileData = NSData(contentsOfURL: fileURL) {
            let boundary = multipartFormData.boundary

            let expectedFileData = NSMutableData()
            expectedFileData.appendData(BoundaryGenerator.boundaryData(boundaryType: .Initial, boundaryKey: boundary))
            expectedFileData.appendData((
                "Content-Disposition: form-data; name=\"unicorn\"; filename=\"unicorn.png\"\(CRLF)" +
                "Content-Type: image/png\(CRLF)\(CRLF)"
                ).dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
            )
            expectedFileData.appendData(NSData(contentsOfURL: unicornImageURL)!)
            expectedFileData.appendData(BoundaryGenerator.boundaryData(boundaryType: .Final, boundaryKey: boundary))

            XCTAssertEqual(fileData, expectedFileData, "file data should match expected file data")
        } else {
            XCTFail("file data should not be nil")
        }
    }

    func testWritingMultipleEncodedFileBodyPartsToDisk() {
        // Given
        let fileURL = temporaryFileURL()
        let multipartFormData = MultipartFormData()

        let unicornImageURL = URLForResource("unicorn", withExtension: "png")
        let rainbowImageURL = URLForResource("rainbow", withExtension: "jpg")

        multipartFormData.appendBodyPart(fileURL: unicornImageURL, name: "unicorn")
        multipartFormData.appendBodyPart(fileURL: rainbowImageURL, name: "rainbow")

        var encodingError: NSError?

        // When
        do {
            try multipartFormData.writeEncodedDataToDisk(fileURL)
        } catch {
            encodingError = error as NSError
        }

        // Then
        XCTAssertNil(encodingError, "encoding error should be nil")

        if let fileData = NSData(contentsOfURL: fileURL) {
            let boundary = multipartFormData.boundary

            let expectedFileData = NSMutableData()
            expectedFileData.appendData(BoundaryGenerator.boundaryData(boundaryType: .Initial, boundaryKey: boundary))
            expectedFileData.appendData((
                "Content-Disposition: form-data; name=\"unicorn\"; filename=\"unicorn.png\"\(CRLF)" +
                "Content-Type: image/png\(CRLF)\(CRLF)"
                ).dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
            )
            expectedFileData.appendData(NSData(contentsOfURL: unicornImageURL)!)
            expectedFileData.appendData(BoundaryGenerator.boundaryData(boundaryType: .Encapsulated, boundaryKey: boundary))
            expectedFileData.appendData((
                "Content-Disposition: form-data; name=\"rainbow\"; filename=\"rainbow.jpg\"\(CRLF)" +
                "Content-Type: image/jpeg\(CRLF)\(CRLF)"
                ).dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
            )
            expectedFileData.appendData(NSData(contentsOfURL: rainbowImageURL)!)
            expectedFileData.appendData(BoundaryGenerator.boundaryData(boundaryType: .Final, boundaryKey: boundary))

            XCTAssertEqual(fileData, expectedFileData, "file data should match expected file data")
        } else {
            XCTFail("file data should not be nil")
        }
    }

    func testWritingEncodedStreamBodyPartToDisk() {
        // Given
        let fileURL = temporaryFileURL()
        let multipartFormData = MultipartFormData()

        let unicornImageURL = URLForResource("unicorn", withExtension: "png")
        let unicornDataLength = UInt64(NSData(contentsOfURL: unicornImageURL)!.length)
        let unicornStream = NSInputStream(URL: unicornImageURL)!

        multipartFormData.appendBodyPart(
            stream: unicornStream,
            length: unicornDataLength,
            name: "unicorn",
            fileName: "unicorn.png",
            mimeType: "image/png"
        )

        var encodingError: NSError?

        // When
        do {
            try multipartFormData.writeEncodedDataToDisk(fileURL)
        } catch {
            encodingError = error as NSError
        }

        // Then
        XCTAssertNil(encodingError, "encoding error should be nil")

        if let fileData = NSData(contentsOfURL: fileURL) {
            let boundary = multipartFormData.boundary

            let expectedFileData = NSMutableData()
            expectedFileData.appendData(BoundaryGenerator.boundaryData(boundaryType: .Initial, boundaryKey: boundary))
            expectedFileData.appendData((
                "Content-Disposition: form-data; name=\"unicorn\"; filename=\"unicorn.png\"\(CRLF)" +
                "Content-Type: image/png\(CRLF)\(CRLF)"
                ).dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
            )
            expectedFileData.appendData(NSData(contentsOfURL: unicornImageURL)!)
            expectedFileData.appendData(BoundaryGenerator.boundaryData(boundaryType: .Final, boundaryKey: boundary))

            XCTAssertEqual(fileData, expectedFileData, "file data should match expected file data")
        } else {
            XCTFail("file data should not be nil")
        }
    }

    func testWritingMultipleEncodedStreamBodyPartsToDisk() {
        // Given
        let fileURL = temporaryFileURL()
        let multipartFormData = MultipartFormData()

        let unicornImageURL = URLForResource("unicorn", withExtension: "png")
        let unicornDataLength = UInt64(NSData(contentsOfURL: unicornImageURL)!.length)
        let unicornStream = NSInputStream(URL: unicornImageURL)!

        let rainbowImageURL = URLForResource("rainbow", withExtension: "jpg")
        let rainbowDataLength = UInt64(NSData(contentsOfURL: rainbowImageURL)!.length)
        let rainbowStream = NSInputStream(URL: rainbowImageURL)!

        multipartFormData.appendBodyPart(
            stream: unicornStream,
            length: unicornDataLength,
            name: "unicorn",
            fileName: "unicorn.png",
            mimeType: "image/png"
        )
        multipartFormData.appendBodyPart(
            stream: rainbowStream,
            length: rainbowDataLength,
            name: "rainbow",
            fileName: "rainbow.jpg",
            mimeType: "image/jpeg"
        )


        var encodingError: NSError?

        // When
        do {
            try multipartFormData.writeEncodedDataToDisk(fileURL)
        } catch {
            encodingError = error as NSError
        }

        // Then
        XCTAssertNil(encodingError, "encoding error should be nil")

        if let fileData = NSData(contentsOfURL: fileURL) {
            let boundary = multipartFormData.boundary

            let expectedFileData = NSMutableData()
            expectedFileData.appendData(BoundaryGenerator.boundaryData(boundaryType: .Initial, boundaryKey: boundary))
            expectedFileData.appendData((
                "Content-Disposition: form-data; name=\"unicorn\"; filename=\"unicorn.png\"\(CRLF)" +
                "Content-Type: image/png\(CRLF)\(CRLF)"
                ).dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
            )
            expectedFileData.appendData(NSData(contentsOfURL: unicornImageURL)!)
            expectedFileData.appendData(BoundaryGenerator.boundaryData(boundaryType: .Encapsulated, boundaryKey: boundary))
            expectedFileData.appendData((
                "Content-Disposition: form-data; name=\"rainbow\"; filename=\"rainbow.jpg\"\(CRLF)" +
                "Content-Type: image/jpeg\(CRLF)\(CRLF)"
                ).dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
            )
            expectedFileData.appendData(NSData(contentsOfURL: rainbowImageURL)!)
            expectedFileData.appendData(BoundaryGenerator.boundaryData(boundaryType: .Final, boundaryKey: boundary))

            XCTAssertEqual(fileData, expectedFileData, "file data should match expected file data")
        } else {
            XCTFail("file data should not be nil")
        }
    }

    func testWritingMultipleEncodedBodyPartsWithVaryingTypesToDisk() {
        // Given
        let fileURL = temporaryFileURL()
        let multipartFormData = MultipartFormData()

        let loremData = "Lorem ipsum.".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!

        let unicornImageURL = URLForResource("unicorn", withExtension: "png")

        let rainbowImageURL = URLForResource("rainbow", withExtension: "jpg")
        let rainbowDataLength = UInt64(NSData(contentsOfURL: rainbowImageURL)!.length)
        let rainbowStream = NSInputStream(URL: rainbowImageURL)!

        multipartFormData.appendBodyPart(data: loremData, name: "lorem")
        multipartFormData.appendBodyPart(fileURL: unicornImageURL, name: "unicorn")
        multipartFormData.appendBodyPart(
            stream: rainbowStream,
            length: rainbowDataLength,
            name: "rainbow",
            fileName: "rainbow.jpg",
            mimeType: "image/jpeg"
        )

        var encodingError: NSError?

        // When
        do {
            try multipartFormData.writeEncodedDataToDisk(fileURL)
        } catch {
            encodingError = error as NSError
        }

        // Then
        XCTAssertNil(encodingError, "encoding error should be nil")

        if let fileData = NSData(contentsOfURL: fileURL) {
            let boundary = multipartFormData.boundary

            let expectedFileData = NSMutableData()
            expectedFileData.appendData(BoundaryGenerator.boundaryData(boundaryType: .Initial, boundaryKey: boundary))
            expectedFileData.appendData((
                "Content-Disposition: form-data; name=\"lorem\"\(CRLF)\(CRLF)"
                ).dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
            )
            expectedFileData.appendData(loremData)
            expectedFileData.appendData(BoundaryGenerator.boundaryData(boundaryType: .Encapsulated, boundaryKey: boundary))
            expectedFileData.appendData((
                "Content-Disposition: form-data; name=\"unicorn\"; filename=\"unicorn.png\"\(CRLF)" +
                "Content-Type: image/png\(CRLF)\(CRLF)"
                ).dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
            )
            expectedFileData.appendData(NSData(contentsOfURL: unicornImageURL)!)
            expectedFileData.appendData(BoundaryGenerator.boundaryData(boundaryType: .Encapsulated, boundaryKey: boundary))
            expectedFileData.appendData((
                "Content-Disposition: form-data; name=\"rainbow\"; filename=\"rainbow.jpg\"\(CRLF)" +
                "Content-Type: image/jpeg\(CRLF)\(CRLF)"
                ).dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
            )
            expectedFileData.appendData(NSData(contentsOfURL: rainbowImageURL)!)
            expectedFileData.appendData(BoundaryGenerator.boundaryData(boundaryType: .Final, boundaryKey: boundary))

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
        let fileURL = NSURL(string: "")!
        let multipartFormData = MultipartFormData()
        multipartFormData.appendBodyPart(fileURL: fileURL, name: "empty_data")

        var encodingError: NSError?

        // When
        do {
            try multipartFormData.encode()
        } catch {
            encodingError = error as NSError
        }

        // Then
        XCTAssertNotNil(encodingError, "encoding error should not be nil")

        if let error = encodingError {
            XCTAssertEqual(error.domain, "com.alamofire.error", "error domain does not match expected value")
            XCTAssertEqual(error.code, NSURLErrorBadURL, "error code does not match expected value")

            if let failureReason = error.userInfo[NSLocalizedFailureReasonErrorKey] as? String {
                let expectedFailureReason = "Failed to extract the fileName of the provided URL: \(fileURL)"
                XCTAssertEqual(failureReason, expectedFailureReason, "failure reason does not match expected value")
            } else {
                XCTFail("failure reason should not be nil")
            }
        }
    }

    func testThatAppendingFileBodyPartThatIsNotFileURLReturnsError() {
        // Given
        let fileURL = NSURL(string: "https://example.com/image.jpg")!
        let multipartFormData = MultipartFormData()
        multipartFormData.appendBodyPart(fileURL: fileURL, name: "empty_data")

        var encodingError: NSError?

        // When
        do {
            try multipartFormData.encode()
        } catch {
            encodingError = error as NSError
        }

        // Then
        XCTAssertNotNil(encodingError, "encoding error should not be nil")

        if let error = encodingError {
            XCTAssertEqual(error.domain, "com.alamofire.error", "error domain does not match expected value")
            XCTAssertEqual(error.code, NSURLErrorBadURL, "error code does not match expected value")

            if let failureReason = error.userInfo[NSLocalizedFailureReasonErrorKey] as? String {
                let expectedFailureReason = "The file URL does not point to a file URL: \(fileURL)"
                XCTAssertEqual(failureReason, expectedFailureReason, "error failure reason does not match expected value")
            } else {
                XCTFail("failure reason should not be nil")
            }
        }
    }

    func testThatAppendingFileBodyPartThatIsNotReachableReturnsError() {
        // Given
        let filePath = (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent("does_not_exist.jpg")
        let fileURL = NSURL(fileURLWithPath: filePath)
        let multipartFormData = MultipartFormData()
        multipartFormData.appendBodyPart(fileURL: fileURL, name: "empty_data")

        var encodingError: NSError?

        // When
        do {
            try multipartFormData.encode()
        } catch {
            encodingError = error as NSError
        }

        // Then
        XCTAssertNotNil(encodingError, "encoding error should not be nil")

        if let error = encodingError {
            XCTAssertEqual(error.domain, "com.alamofire.error", "error domain does not match expected value")
            XCTAssertEqual(error.code, NSURLErrorBadURL, "error code does not match expected value")

            if let failureReason = error.userInfo[NSLocalizedFailureReasonErrorKey] as? String {
                let expectedFailureReason = "The file URL is not reachable: \(fileURL)"
                XCTAssertEqual(failureReason, expectedFailureReason, "error failure reason does not match expected value")
            } else {
                XCTFail("failure reason should not be nil")
            }
        }
    }

    func testThatAppendingFileBodyPartThatIsDirectoryReturnsError() {
        // Given
        let directoryURL = NSURL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let multipartFormData = MultipartFormData()
        multipartFormData.appendBodyPart(fileURL: directoryURL, name: "empty_data")

        var encodingError: NSError?

        // When
        do {
            try multipartFormData.encode()
        } catch {
            encodingError = error as NSError
        }

        // Then
        XCTAssertNotNil(encodingError, "encoding error should not be nil")

        if let error = encodingError {
            XCTAssertEqual(error.domain, "com.alamofire.error", "error domain does not match expected value")
            XCTAssertEqual(error.code, NSURLErrorBadURL, "error code does not match expected value")

            if let failureReason = error.userInfo[NSLocalizedFailureReasonErrorKey] as? String {
                let expectedFailureReason = "The file URL is a directory, not a file: \(directoryURL)"
                XCTAssertEqual(failureReason, expectedFailureReason, "error failure reason does not match expected value")
            } else {
                XCTFail("failure reason should not be nil")
            }
        }
    }

    func testThatWritingEncodedDataToExistingFileURLFails() {
        // Given
        let fileURL = temporaryFileURL()

        var writerError: NSError?

        do {
            try "dummy data".writeToURL(fileURL, atomically: true, encoding: NSUTF8StringEncoding)
        } catch {
            writerError = error as NSError
        }

        let multipartFormData = MultipartFormData()
        let data = "Lorem ipsum dolor sit amet.".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
        multipartFormData.appendBodyPart(data: data, name: "data")

        var encodingError: NSError?

        // When
        do {
            try multipartFormData.writeEncodedDataToDisk(fileURL)
        } catch {
            encodingError = error as NSError
        }

        // Then
        XCTAssertNil(writerError, "writer error should be nil")
        XCTAssertNotNil(encodingError, "encoding error should not be nil")

        if let encodingError = encodingError {
            XCTAssertEqual(encodingError.domain, "com.alamofire.error", "encoding error domain does not match expected value")
            XCTAssertEqual(encodingError.code, NSURLErrorBadURL, "encoding error code does not match expected value")
        }
    }

    func testThatWritingEncodedDataToBadURLFails() {
        // Given
        let fileURL = NSURL(string: "/this/is/not/a/valid/url")!

        let multipartFormData = MultipartFormData()
        let data = "Lorem ipsum dolor sit amet.".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
        multipartFormData.appendBodyPart(data: data, name: "data")

        var encodingError: NSError?

        // When
        do {
            try multipartFormData.writeEncodedDataToDisk(fileURL)
        } catch {
            encodingError = error as NSError
        }

        // Then
        XCTAssertNotNil(encodingError, "encoding error should not be nil")

        if let encodingError = encodingError {
            XCTAssertEqual(encodingError.domain, "com.alamofire.error", "encoding error domain does not match expected value")
            XCTAssertEqual(encodingError.code, NSURLErrorBadURL, "encoding error code does not match expected value")
        }
    }
}
