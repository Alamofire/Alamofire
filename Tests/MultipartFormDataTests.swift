//
//  MultipartFormDataTests.swift
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

import Alamofire
import Foundation
import Testing

enum EncodingCharacters {
    static let crlf = "\r\n"
}

enum BoundaryGenerator {
    enum BoundaryType {
        case initial, encapsulated, final
    }

    static func boundary(forBoundaryType boundaryType: BoundaryType, boundaryKey: String) -> String {
        switch boundaryType {
        case .initial:
            "--\(boundaryKey)\(EncodingCharacters.crlf)"
        case .encapsulated:
            "\(EncodingCharacters.crlf)--\(boundaryKey)\(EncodingCharacters.crlf)"
        case .final:
            "\(EncodingCharacters.crlf)--\(boundaryKey)--\(EncodingCharacters.crlf)"
        }
    }

    static func boundaryData(boundaryType: BoundaryType, boundaryKey: String) -> Data {
        Data(BoundaryGenerator.boundary(forBoundaryType: boundaryType,
                                        boundaryKey: boundaryKey).utf8)
    }
}

// MARK: -

@Suite
struct MultipartFormDataPropertiesTestCase {
    @Test
    func contentTypeContainsBoundary() {
        // Given
        let multipartFormData = MultipartFormData()

        // When
        let boundary = multipartFormData.boundary

        // Then
        let expectedContentType = "multipart/form-data; boundary=\(boundary)"
        #expect(multipartFormData.contentType == expectedContentType, "contentType should match expected value")
    }

    @Test
    func contentLengthMatchesTotalBodyPartSize() {
        // Given
        let multipartFormData = MultipartFormData()
        let data1 = Data("Lorem ipsum dolor sit amet.".utf8)
        let data2 = Data("Vim at integre alterum.".utf8)

        // When
        multipartFormData.append(data1, withName: "data1")
        multipartFormData.append(data2, withName: "data2")

        // Then
        let expectedContentLength = UInt64(data1.count + data2.count)
        #expect(multipartFormData.contentLength == expectedContentLength, "content length should match expected value")
    }
}

// MARK: -

@Suite
struct MultipartFormDataEncodingTestCase {
    let crlf = EncodingCharacters.crlf

    @Test
    func encodingDataBodyPart() {
        // Given
        let multipartFormData = MultipartFormData()

        let data = Data("Lorem ipsum dolor sit amet.".utf8)
        multipartFormData.append(data, withName: "data")

        var encodedData: Data?

        // When
        do {
            encodedData = try multipartFormData.encode()
        } catch {
            // No-op
        }

        // Then
        #expect(encodedData != nil, "encoded data should not be nil")

        if let encodedData {
            let boundary = multipartFormData.boundary

            let expectedString = (
                BoundaryGenerator.boundary(forBoundaryType: .initial, boundaryKey: boundary) +
                    "Content-Disposition: form-data; name=\"data\"\(crlf)\(crlf)" +
                    "Lorem ipsum dolor sit amet." +
                    BoundaryGenerator.boundary(forBoundaryType: .final, boundaryKey: boundary)
            )
            let expectedData = Data(expectedString.utf8)

            #expect(encodedData == expectedData, "encoded data should match expected data")
        }
    }

    @Test
    func encodingMultipleDataBodyParts() {
        // Given
        let multipartFormData = MultipartFormData()

        let frenchData = Data("français".utf8)
        let japaneseData = Data("日本語".utf8)
        let emojiData = Data("😃👍🏻🍻🎉".utf8)

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
        #expect(encodedData != nil, "encoded data should not be nil")

        if let encodedData {
            let boundary = multipartFormData.boundary

            let expectedString = (
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
            )
            let expectedData = Data(expectedString.utf8)

            #expect(encodedData == expectedData, "encoded data should match expected data")
        }
    }

    @Test
    func encodingFileBodyPart() {
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
        #expect(encodedData != nil, "encoded data should not be nil")

        if let encodedData {
            let boundary = multipartFormData.boundary

            var expectedData = Data()
            expectedData.append(BoundaryGenerator.boundaryData(boundaryType: .initial, boundaryKey: boundary))
            expectedData.append(Data((
                "Content-Disposition: form-data; name=\"unicorn\"; filename=\"unicorn.png\"\(crlf)" +
                    "Content-Type: image/png\(crlf)\(crlf)"
            ).utf8))
            expectedData.append(try! Data(contentsOf: unicornImageURL))
            expectedData.append(BoundaryGenerator.boundaryData(boundaryType: .final, boundaryKey: boundary))

            #expect(encodedData == expectedData, "data should match expected data")
        }
    }

    @Test
    func encodingMultipleFileBodyParts() {
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
        #expect(encodedData != nil, "encoded data should not be nil")

        if let encodedData {
            let boundary = multipartFormData.boundary

            var expectedData = Data()
            expectedData.append(BoundaryGenerator.boundaryData(boundaryType: .initial, boundaryKey: boundary))
            expectedData.append(Data((
                "Content-Disposition: form-data; name=\"unicorn\"; filename=\"unicorn.png\"\(crlf)" +
                    "Content-Type: image/png\(crlf)\(crlf)"
            ).utf8))
            expectedData.append(try! Data(contentsOf: unicornImageURL))
            expectedData.append(BoundaryGenerator.boundaryData(boundaryType: .encapsulated, boundaryKey: boundary))
            expectedData.append(Data((
                "Content-Disposition: form-data; name=\"rainbow\"; filename=\"rainbow.jpg\"\(crlf)" +
                    "Content-Type: image/jpeg\(crlf)\(crlf)"
            ).utf8))
            expectedData.append(try! Data(contentsOf: rainbowImageURL))
            expectedData.append(BoundaryGenerator.boundaryData(boundaryType: .final, boundaryKey: boundary))

            #expect(encodedData == expectedData, "data should match expected data")
        }
    }

    @Test
    func encodingStreamBodyPart() {
        // Given
        let multipartFormData = MultipartFormData()

        let unicornImageURL = url(forResource: "unicorn", withExtension: "png")
        let unicornDataLength = UInt64((try! Data(contentsOf: unicornImageURL)).count)
        let unicornStream = InputStream(url: unicornImageURL)!

        multipartFormData.append(unicornStream,
                                 withLength: unicornDataLength,
                                 name: "unicorn",
                                 fileName: "unicorn.png",
                                 mimeType: "image/png")

        var encodedData: Data?

        // When
        do {
            encodedData = try multipartFormData.encode()
        } catch {
            // No-op
        }

        // Then
        #expect(encodedData != nil, "encoded data should not be nil")

        if let encodedData {
            let boundary = multipartFormData.boundary

            var expectedData = Data()
            expectedData.append(BoundaryGenerator.boundaryData(boundaryType: .initial, boundaryKey: boundary))
            expectedData.append(Data((
                "Content-Disposition: form-data; name=\"unicorn\"; filename=\"unicorn.png\"\(crlf)" +
                    "Content-Type: image/png\(crlf)\(crlf)"
            ).utf8))
            expectedData.append(try! Data(contentsOf: unicornImageURL))
            expectedData.append(BoundaryGenerator.boundaryData(boundaryType: .final, boundaryKey: boundary))

            #expect(encodedData == expectedData, "data should match expected data")
        }
    }

    @Test
    func encodingMultipleStreamBodyParts() {
        // Given
        let multipartFormData = MultipartFormData()

        let unicornImageURL = url(forResource: "unicorn", withExtension: "png")
        let unicornDataLength = UInt64((try! Data(contentsOf: unicornImageURL)).count)
        let unicornStream = InputStream(url: unicornImageURL)!

        let rainbowImageURL = url(forResource: "rainbow", withExtension: "jpg")
        let rainbowDataLength = UInt64((try! Data(contentsOf: rainbowImageURL)).count)
        let rainbowStream = InputStream(url: rainbowImageURL)!

        multipartFormData.append(unicornStream,
                                 withLength: unicornDataLength,
                                 name: "unicorn",
                                 fileName: "unicorn.png",
                                 mimeType: "image/png")
        multipartFormData.append(rainbowStream,
                                 withLength: rainbowDataLength,
                                 name: "rainbow",
                                 fileName: "rainbow.jpg",
                                 mimeType: "image/jpeg")

        var encodedData: Data?

        // When
        do {
            encodedData = try multipartFormData.encode()
        } catch {
            // No-op
        }

        // Then
        #expect(encodedData != nil, "encoded data should not be nil")

        if let encodedData {
            let boundary = multipartFormData.boundary

            var expectedData = Data()
            expectedData.append(BoundaryGenerator.boundaryData(boundaryType: .initial, boundaryKey: boundary))
            expectedData.append(Data((
                "Content-Disposition: form-data; name=\"unicorn\"; filename=\"unicorn.png\"\(crlf)" +
                    "Content-Type: image/png\(crlf)\(crlf)"
            ).utf8))
            expectedData.append(try! Data(contentsOf: unicornImageURL))
            expectedData.append(BoundaryGenerator.boundaryData(boundaryType: .encapsulated, boundaryKey: boundary))
            expectedData.append(Data((
                "Content-Disposition: form-data; name=\"rainbow\"; filename=\"rainbow.jpg\"\(crlf)" +
                    "Content-Type: image/jpeg\(crlf)\(crlf)"
            ).utf8))
            expectedData.append(try! Data(contentsOf: rainbowImageURL))
            expectedData.append(BoundaryGenerator.boundaryData(boundaryType: .final, boundaryKey: boundary))

            #expect(encodedData == expectedData, "data should match expected data")
        }
    }

    @Test
    func encodingMultipleBodyPartsWithVaryingTypes() {
        // Given
        let multipartFormData = MultipartFormData()

        let loremData = Data("Lorem ipsum.".utf8)

        let unicornImageURL = url(forResource: "unicorn", withExtension: "png")

        let rainbowImageURL = url(forResource: "rainbow", withExtension: "jpg")
        let rainbowDataLength = UInt64((try! Data(contentsOf: rainbowImageURL)).count)
        let rainbowStream = InputStream(url: rainbowImageURL)!

        multipartFormData.append(loremData, withName: "lorem")
        multipartFormData.append(unicornImageURL, withName: "unicorn")
        multipartFormData.append(rainbowStream,
                                 withLength: rainbowDataLength,
                                 name: "rainbow",
                                 fileName: "rainbow.jpg",
                                 mimeType: "image/jpeg")

        var encodedData: Data?

        // When
        do {
            encodedData = try multipartFormData.encode()
        } catch {
            // No-op
        }

        // Then
        #expect(encodedData != nil, "encoded data should not be nil")

        if let encodedData {
            let boundary = multipartFormData.boundary

            var expectedData = Data()
            expectedData.append(BoundaryGenerator.boundaryData(boundaryType: .initial, boundaryKey: boundary))
            expectedData.append(Data(
                "Content-Disposition: form-data; name=\"lorem\"\(crlf)\(crlf)".utf8
            ))
            expectedData.append(loremData)
            expectedData.append(BoundaryGenerator.boundaryData(boundaryType: .encapsulated, boundaryKey: boundary))
            expectedData.append(Data((
                "Content-Disposition: form-data; name=\"unicorn\"; filename=\"unicorn.png\"\(crlf)" +
                    "Content-Type: image/png\(crlf)\(crlf)"
            ).utf8))
            expectedData.append(try! Data(contentsOf: unicornImageURL))
            expectedData.append(BoundaryGenerator.boundaryData(boundaryType: .encapsulated, boundaryKey: boundary))
            expectedData.append(Data((
                "Content-Disposition: form-data; name=\"rainbow\"; filename=\"rainbow.jpg\"\(crlf)" +
                    "Content-Type: image/jpeg\(crlf)\(crlf)"
            ).utf8))
            expectedData.append(try! Data(contentsOf: rainbowImageURL))
            expectedData.append(BoundaryGenerator.boundaryData(boundaryType: .final, boundaryKey: boundary))

            #expect(encodedData == expectedData, "data should match expected data")
        }
    }
}

// MARK: -

@Suite
struct MultipartFormDataWriteEncodedDataToDiskTestCase {
    private let directory = TemporaryDirectory()
    private var temporaryFileURL: URL { directory.fileURL }

    let crlf = EncodingCharacters.crlf

    @Test
    func writingEncodedDataBodyPartToDisk() {
        // Given
        let fileURL = temporaryFileURL
        let multipartFormData = MultipartFormData()

        let data = Data("Lorem ipsum dolor sit amet.".utf8)
        multipartFormData.append(data, withName: "data")

        var encodingError: (any Error)?

        // When
        do {
            try multipartFormData.writeEncodedData(to: fileURL)
        } catch {
            encodingError = error
        }

        // Then
        #expect(encodingError == nil, "encoding error should be nil")

        if let fileData = try? Data(contentsOf: fileURL) {
            let boundary = multipartFormData.boundary

            let expectedString = BoundaryGenerator.boundary(forBoundaryType: .initial, boundaryKey: boundary) +
                "Content-Disposition: form-data; name=\"data\"\(crlf)\(crlf)" +
                "Lorem ipsum dolor sit amet." +
                BoundaryGenerator.boundary(forBoundaryType: .final, boundaryKey: boundary)
            let expectedFileData = Data(expectedString.utf8)

            #expect(fileData == expectedFileData, "file data should match expected file data")
        } else {
            Issue.record("file data should not be nil")
        }
    }

    @Test
    func writingMultipleEncodedDataBodyPartsToDisk() {
        // Given
        let fileURL = temporaryFileURL
        let multipartFormData = MultipartFormData()

        let frenchData = Data("français".utf8)
        let japaneseData = Data("日本語".utf8)
        let emojiData = Data("😃👍🏻🍻🎉".utf8)

        multipartFormData.append(frenchData, withName: "french")
        multipartFormData.append(japaneseData, withName: "japanese")
        multipartFormData.append(emojiData, withName: "emoji")

        var encodingError: (any Error)?

        // When
        do {
            try multipartFormData.writeEncodedData(to: fileURL)
        } catch {
            encodingError = error
        }

        // Then
        #expect(encodingError == nil, "encoding error should be nil")

        if let fileData = try? Data(contentsOf: fileURL) {
            let boundary = multipartFormData.boundary

            let expectedString = (
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
            )
            let expectedFileData = Data(expectedString.utf8)

            #expect(fileData == expectedFileData, "file data should match expected file data")
        } else {
            Issue.record("file data should not be nil")
        }
    }

    @Test
    func writingEncodedFileBodyPartToDisk() {
        // Given
        let fileURL = temporaryFileURL
        let multipartFormData = MultipartFormData()

        let unicornImageURL = url(forResource: "unicorn", withExtension: "png")
        multipartFormData.append(unicornImageURL, withName: "unicorn")

        var encodingError: (any Error)?

        // When
        do {
            try multipartFormData.writeEncodedData(to: fileURL)
        } catch {
            encodingError = error
        }

        // Then
        #expect(encodingError == nil, "encoding error should be nil")

        if let fileData = try? Data(contentsOf: fileURL) {
            let boundary = multipartFormData.boundary

            var expectedFileData = Data()
            expectedFileData.append(BoundaryGenerator.boundaryData(boundaryType: .initial, boundaryKey: boundary))
            expectedFileData.append(Data((
                "Content-Disposition: form-data; name=\"unicorn\"; filename=\"unicorn.png\"\(crlf)" +
                    "Content-Type: image/png\(crlf)\(crlf)"
            ).utf8))
            expectedFileData.append(try! Data(contentsOf: unicornImageURL))
            expectedFileData.append(BoundaryGenerator.boundaryData(boundaryType: .final, boundaryKey: boundary))

            #expect(fileData == expectedFileData, "file data should match expected file data")
        } else {
            Issue.record("file data should not be nil")
        }
    }

    @Test
    func writingMultipleEncodedFileBodyPartsToDisk() {
        // Given
        let fileURL = temporaryFileURL
        let multipartFormData = MultipartFormData()

        let unicornImageURL = url(forResource: "unicorn", withExtension: "png")
        let rainbowImageURL = url(forResource: "rainbow", withExtension: "jpg")

        multipartFormData.append(unicornImageURL, withName: "unicorn")
        multipartFormData.append(rainbowImageURL, withName: "rainbow")

        var encodingError: (any Error)?

        // When
        do {
            try multipartFormData.writeEncodedData(to: fileURL)
        } catch {
            encodingError = error
        }

        // Then
        #expect(encodingError == nil, "encoding error should be nil")

        if let fileData = try? Data(contentsOf: fileURL) {
            let boundary = multipartFormData.boundary

            var expectedFileData = Data()
            expectedFileData.append(BoundaryGenerator.boundaryData(boundaryType: .initial, boundaryKey: boundary))
            expectedFileData.append(Data((
                "Content-Disposition: form-data; name=\"unicorn\"; filename=\"unicorn.png\"\(crlf)" +
                    "Content-Type: image/png\(crlf)\(crlf)"
            ).utf8))
            expectedFileData.append(try! Data(contentsOf: unicornImageURL))
            expectedFileData.append(BoundaryGenerator.boundaryData(boundaryType: .encapsulated, boundaryKey: boundary))
            expectedFileData.append(Data((
                "Content-Disposition: form-data; name=\"rainbow\"; filename=\"rainbow.jpg\"\(crlf)" +
                    "Content-Type: image/jpeg\(crlf)\(crlf)"
            ).utf8))
            expectedFileData.append(try! Data(contentsOf: rainbowImageURL))
            expectedFileData.append(BoundaryGenerator.boundaryData(boundaryType: .final, boundaryKey: boundary))

            #expect(fileData == expectedFileData, "file data should match expected file data")
        } else {
            Issue.record("file data should not be nil")
        }
    }

    @Test
    func writingEncodedStreamBodyPartToDiskRespectingBodyLength() {
        // Given
        let destinationFileURL = temporaryFileURL
        let multipartFormData = MultipartFormData()

        let unicornImageURL = url(forResource: "unicorn", withExtension: "png")
        let unicornImageData = try! Data(contentsOf: unicornImageURL)
        let unicornDataLength = unicornImageData.count

        // Write only PART of the file
        let expectedFileStreamUploadLength = UInt64(unicornDataLength / 2)
        multipartFormData.append(InputStream(url: unicornImageURL)!,
                                 withLength: expectedFileStreamUploadLength,
                                 name: "unicorn",
                                 fileName: "unicorn.png",
                                 mimeType: "image/png")

        var encodingError: (any Error)?

        // When
        do {
            try multipartFormData.writeEncodedData(to: destinationFileURL)
        } catch {
            encodingError = error
        }

        // Then
        #expect(encodingError == nil, "encoding error should be nil")

        if let destinationFileData = try? Data(contentsOf: destinationFileURL) {
            let boundary = multipartFormData.boundary

            var expectedFileData = Data()
            expectedFileData.append(BoundaryGenerator.boundaryData(boundaryType: .initial, boundaryKey: boundary))
            expectedFileData.append(Data((
                "Content-Disposition: form-data; name=\"unicorn\"; filename=\"unicorn.png\"\(crlf)" +
                    "Content-Type: image/png\(crlf)\(crlf)"
            ).utf8))
            expectedFileData.append(unicornImageData.prefix(Int(expectedFileStreamUploadLength)))
            expectedFileData.append(BoundaryGenerator.boundaryData(boundaryType: .final, boundaryKey: boundary))

            #expect(destinationFileData == expectedFileData, "file data should match expected file data")
        } else {
            Issue.record("file data should not be nil")
        }
    }

    @Test
    func writingEncodedStreamBodyPartToDisk() {
        // Given
        let fileURL = temporaryFileURL
        let multipartFormData = MultipartFormData()

        let unicornImageURL = url(forResource: "unicorn", withExtension: "png")
        let unicornDataLength = UInt64((try! Data(contentsOf: unicornImageURL)).count)
        let unicornStream = InputStream(url: unicornImageURL)!

        multipartFormData.append(unicornStream,
                                 withLength: unicornDataLength,
                                 name: "unicorn",
                                 fileName: "unicorn.png",
                                 mimeType: "image/png")

        var encodingError: (any Error)?

        // When
        do {
            try multipartFormData.writeEncodedData(to: fileURL)
        } catch {
            encodingError = error
        }

        // Then
        #expect(encodingError == nil, "encoding error should be nil")

        if let fileData = try? Data(contentsOf: fileURL) {
            let boundary = multipartFormData.boundary

            var expectedFileData = Data()
            expectedFileData.append(BoundaryGenerator.boundaryData(boundaryType: .initial, boundaryKey: boundary))
            expectedFileData.append(Data((
                "Content-Disposition: form-data; name=\"unicorn\"; filename=\"unicorn.png\"\(crlf)" +
                    "Content-Type: image/png\(crlf)\(crlf)"
            ).utf8))
            expectedFileData.append(try! Data(contentsOf: unicornImageURL))
            expectedFileData.append(BoundaryGenerator.boundaryData(boundaryType: .final, boundaryKey: boundary))

            #expect(fileData == expectedFileData, "file data should match expected file data")
        } else {
            Issue.record("file data should not be nil")
        }
    }

    @Test
    func writingMultipleEncodedStreamBodyPartsToDisk() {
        // Given
        let fileURL = temporaryFileURL
        let multipartFormData = MultipartFormData()

        let unicornImageURL = url(forResource: "unicorn", withExtension: "png")
        let unicornDataLength = UInt64((try! Data(contentsOf: unicornImageURL)).count)
        let unicornStream = InputStream(url: unicornImageURL)!

        let rainbowImageURL = url(forResource: "rainbow", withExtension: "jpg")
        let rainbowDataLength = UInt64((try! Data(contentsOf: rainbowImageURL)).count)
        let rainbowStream = InputStream(url: rainbowImageURL)!

        multipartFormData.append(unicornStream,
                                 withLength: unicornDataLength,
                                 name: "unicorn",
                                 fileName: "unicorn.png",
                                 mimeType: "image/png")
        multipartFormData.append(rainbowStream,
                                 withLength: rainbowDataLength,
                                 name: "rainbow",
                                 fileName: "rainbow.jpg",
                                 mimeType: "image/jpeg")

        var encodingError: (any Error)?

        // When
        do {
            try multipartFormData.writeEncodedData(to: fileURL)
        } catch {
            encodingError = error
        }

        // Then
        #expect(encodingError == nil, "encoding error should be nil")

        if let fileData = try? Data(contentsOf: fileURL) {
            let boundary = multipartFormData.boundary

            var expectedFileData = Data()
            expectedFileData.append(BoundaryGenerator.boundaryData(boundaryType: .initial, boundaryKey: boundary))
            expectedFileData.append(Data((
                "Content-Disposition: form-data; name=\"unicorn\"; filename=\"unicorn.png\"\(crlf)" +
                    "Content-Type: image/png\(crlf)\(crlf)"
            ).utf8))
            expectedFileData.append(try! Data(contentsOf: unicornImageURL))
            expectedFileData.append(BoundaryGenerator.boundaryData(boundaryType: .encapsulated, boundaryKey: boundary))
            expectedFileData.append(Data((
                "Content-Disposition: form-data; name=\"rainbow\"; filename=\"rainbow.jpg\"\(crlf)" +
                    "Content-Type: image/jpeg\(crlf)\(crlf)"
            ).utf8))
            expectedFileData.append(try! Data(contentsOf: rainbowImageURL))
            expectedFileData.append(BoundaryGenerator.boundaryData(boundaryType: .final, boundaryKey: boundary))

            #expect(fileData == expectedFileData, "file data should match expected file data")
        } else {
            Issue.record("file data should not be nil")
        }
    }

    @Test
    func writingMultipleEncodedBodyPartsWithVaryingTypesToDisk() {
        // Given
        let fileURL = temporaryFileURL
        let multipartFormData = MultipartFormData()

        let loremData = Data("Lorem ipsum.".utf8)

        let unicornImageURL = url(forResource: "unicorn", withExtension: "png")

        let rainbowImageURL = url(forResource: "rainbow", withExtension: "jpg")
        let rainbowDataLength = UInt64((try! Data(contentsOf: rainbowImageURL)).count)
        let rainbowStream = InputStream(url: rainbowImageURL)!

        multipartFormData.append(loremData, withName: "lorem")
        multipartFormData.append(unicornImageURL, withName: "unicorn")
        multipartFormData.append(rainbowStream,
                                 withLength: rainbowDataLength,
                                 name: "rainbow",
                                 fileName: "rainbow.jpg",
                                 mimeType: "image/jpeg")

        var encodingError: (any Error)?

        // When
        do {
            try multipartFormData.writeEncodedData(to: fileURL)
        } catch {
            encodingError = error
        }

        // Then
        #expect(encodingError == nil, "encoding error should be nil")

        if let fileData = try? Data(contentsOf: fileURL) {
            let boundary = multipartFormData.boundary

            var expectedFileData = Data()
            expectedFileData.append(BoundaryGenerator.boundaryData(boundaryType: .initial, boundaryKey: boundary))
            expectedFileData.append(Data(
                "Content-Disposition: form-data; name=\"lorem\"\(crlf)\(crlf)".utf8
            ))
            expectedFileData.append(loremData)
            expectedFileData.append(BoundaryGenerator.boundaryData(boundaryType: .encapsulated, boundaryKey: boundary))
            expectedFileData.append(Data((
                "Content-Disposition: form-data; name=\"unicorn\"; filename=\"unicorn.png\"\(crlf)" +
                    "Content-Type: image/png\(crlf)\(crlf)"
            ).utf8))
            expectedFileData.append(try! Data(contentsOf: unicornImageURL))
            expectedFileData.append(BoundaryGenerator.boundaryData(boundaryType: .encapsulated, boundaryKey: boundary))
            expectedFileData.append(Data((
                "Content-Disposition: form-data; name=\"rainbow\"; filename=\"rainbow.jpg\"\(crlf)" +
                    "Content-Type: image/jpeg\(crlf)\(crlf)"
            ).utf8))
            expectedFileData.append(try! Data(contentsOf: rainbowImageURL))
            expectedFileData.append(BoundaryGenerator.boundaryData(boundaryType: .final, boundaryKey: boundary))

            #expect(fileData == expectedFileData, "file data should match expected file data")
        } else {
            Issue.record("file data should not be nil")
        }
    }
}

// MARK: -

@Suite
struct MultipartFormDataFailureTestCase {
    private let directory = TemporaryDirectory()
    private var temporaryFileURL: URL { directory.fileURL }

    @Test
    func appendingFileBodyPartWithInvalidLastPathComponentReturnsError() {
        // Given
        let fileURL = NSURL(string: "")! as URL
        let multipartFormData = MultipartFormData()
        multipartFormData.append(fileURL, withName: "empty_data")

        var encodingError: (any Error)?

        // When
        do {
            _ = try multipartFormData.encode()
        } catch {
            encodingError = error
        }

        // Then
        #expect(encodingError != nil, "encoding error should not be nil")

        #expect(encodingError?.asAFError?.isBodyPartFilenameInvalid == true)
        #expect(encodingError?.asAFError?.url == fileURL)
    }

    @Test
    func appendingFileBodyPartThatIsNotFileURLReturnsError() {
        // Given
        let fileURL = URL(string: "https://example.com/image.jpg")!
        let multipartFormData = MultipartFormData()
        multipartFormData.append(fileURL, withName: "empty_data")

        var encodingError: (any Error)?

        // When
        do {
            _ = try multipartFormData.encode()
        } catch {
            encodingError = error
        }

        // Then
        #expect(encodingError != nil, "encoding error should not be nil")
        #expect(encodingError?.asAFError?.isBodyPartURLInvalid == true)
        #expect(encodingError?.asAFError?.url == fileURL)
    }

    @Test
    func appendingFileBodyPartThatIsNotReachableReturnsError() {
        // Given
        let filePath = (NSTemporaryDirectory() as NSString).appendingPathComponent("does_not_exist.jpg")
        let fileURL = URL(fileURLWithPath: filePath)
        let multipartFormData = MultipartFormData()
        multipartFormData.append(fileURL, withName: "empty_data")

        var encodingError: (any Error)?

        // When
        do {
            _ = try multipartFormData.encode()
        } catch {
            encodingError = error
        }

        // Then
        #expect(encodingError != nil, "encoding error should not be nil")

        #expect(encodingError?.asAFError?.isBodyPartFileNotReachableWithError == true)
        #expect(encodingError?.asAFError?.url == fileURL)
    }

    @Test
    func appendingFileBodyPartThatIsDirectoryReturnsError() {
        // Given
        let directoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let multipartFormData = MultipartFormData()
        multipartFormData.append(directoryURL, withName: "empty_data", fileName: "empty", mimeType: "application/octet")

        var encodingError: (any Error)?

        // When
        do {
            _ = try multipartFormData.encode()
        } catch {
            encodingError = error
        }

        // Then
        #expect(encodingError != nil, "encoding error should not be nil")
        #expect(encodingError?.asAFError?.isBodyPartFileIsDirectory == true)
        #expect(encodingError?.asAFError?.url == directoryURL)
    }

    @Test
    func writingEncodedDataToExistingFileURLFails() {
        // Given
        let fileURL = temporaryFileURL

        var writerError: (any Error)?

        do {
            try "dummy data".write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            writerError = error
        }

        let multipartFormData = MultipartFormData()
        let data = Data("Lorem ipsum dolor sit amet.".utf8)
        multipartFormData.append(data, withName: "data")

        var encodingError: (any Error)?

        // When
        do {
            try multipartFormData.writeEncodedData(to: fileURL)
        } catch {
            encodingError = error
        }

        // Then
        #expect(writerError == nil, "writer error should be nil")
        #expect(encodingError != nil, "encoding error should not be nil")
        #expect(encodingError?.asAFError?.isOutputStreamFileAlreadyExists == true)
    }

    @Test
    func writingEncodedDataToBadURLFails() {
        // Given
        let fileURL = URL(string: "/this/is/not/a/valid/url")!

        let multipartFormData = MultipartFormData()
        let data = Data("Lorem ipsum dolor sit amet.".utf8)
        multipartFormData.append(data, withName: "data")

        var encodingError: (any Error)?

        // When
        do {
            try multipartFormData.writeEncodedData(to: fileURL)
        } catch {
            encodingError = error
        }

        // Then
        #expect(encodingError != nil, "encoding error should not be nil")
        #expect(encodingError?.asAFError?.isOutputStreamURLInvalid == true)
    }

    @Test
    func streamBodyPartHasUnexpectedLength() {
        // Given
        let multipartFormData = MultipartFormData()
        let data = Data("Lorem ipsum dolor sit amet.".utf8)
        multipartFormData.append(data, withName: "data")
        var firstError: (any Error)?
        var secondError: (any Error)?

        // When
        do {
            _ = try multipartFormData.encode()
        } catch {
            firstError = error
        }

        do {
            _ = try multipartFormData.encode()
        } catch {
            secondError = error
        }

        #expect(firstError == nil, "firstError should be nil")
        #expect(secondError != nil, "secondError should not be nil")
        #expect(secondError?.asAFError?.isInputStreamReadFailed == true)
        #expect(secondError?.asAFError?.underlyingError is AFError.UnexpectedInputStreamLength)
    }
}
