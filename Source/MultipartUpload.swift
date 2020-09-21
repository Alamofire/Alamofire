//
//  MultipartUpload.swift
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

import Foundation

/// Internal type which encapsulates a `MultipartFormData` upload.
final class MultipartUpload {
    lazy var result = Result { try build() }

    let isInBackgroundSession: Bool
    let multipartFormData: MultipartFormData
    let encodingMemoryThreshold: UInt64
    let request: URLRequestConvertible
    let fileManager: FileManager

    init(isInBackgroundSession: Bool,
         encodingMemoryThreshold: UInt64,
         request: URLRequestConvertible,
         multipartFormData: MultipartFormData) {
        self.isInBackgroundSession = isInBackgroundSession
        self.encodingMemoryThreshold = encodingMemoryThreshold
        self.request = request
        fileManager = multipartFormData.fileManager
        self.multipartFormData = multipartFormData
    }

    func build() throws -> (request: URLRequest, uploadable: UploadRequest.Uploadable) {
        var urlRequest = try request.asURLRequest()
        urlRequest.setValue(multipartFormData.contentType, forHTTPHeaderField: "Content-Type")

        let uploadable: UploadRequest.Uploadable
        if multipartFormData.contentLength < encodingMemoryThreshold && !isInBackgroundSession {
            let data = try multipartFormData.encode()

            uploadable = .data(data)
        } else {
            let tempDirectoryURL = fileManager.temporaryDirectory
            let directoryURL = tempDirectoryURL.appendingPathComponent("org.alamofire.manager/multipart.form.data")
            let fileName = UUID().uuidString
            let fileURL = directoryURL.appendingPathComponent(fileName)

            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)

            do {
                try multipartFormData.writeEncodedData(to: fileURL)
            } catch {
                // Cleanup after attempted write if it fails.
                try? fileManager.removeItem(at: fileURL)
                throw error
            }

            uploadable = .file(fileURL, shouldRemove: true)
        }

        return (request: urlRequest, uploadable: uploadable)
    }
}

extension MultipartUpload: UploadConvertible {
    func asURLRequest() throws -> URLRequest {
        try result.get().request
    }

    func createUploadable() throws -> UploadRequest.Uploadable {
        try result.get().uploadable
    }
}
