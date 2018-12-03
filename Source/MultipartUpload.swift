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

open class MultipartUpload {
    /// Default memory threshold used when encoding `MultipartFormData`, in bytes.
    public static let encodingMemoryThreshold: UInt64 = 10_000_000

    lazy var result = Result { try build() }

    let isInBackgroundSession: Bool
    let multipartBuilder: (MultipartFormData) -> Void
    let encodingMemoryThreshold: UInt64
    let request: URLRequestConvertible
    let fileManager: FileManager

    init(isInBackgroundSession: Bool,
         encodingMemoryThreshold: UInt64 = MultipartUpload.encodingMemoryThreshold,
         request: URLRequestConvertible,
         fileManager: FileManager = .default,
         multipartBuilder: @escaping (MultipartFormData) -> Void) {
        self.isInBackgroundSession = isInBackgroundSession
        self.encodingMemoryThreshold = encodingMemoryThreshold
        self.request = request
        self.fileManager =  fileManager
        self.multipartBuilder = multipartBuilder
    }

    func build() throws -> (request: URLRequest, uploadable: UploadRequest.Uploadable) {
        let formData = MultipartFormData(fileManager: fileManager)
        multipartBuilder(formData)

        var urlRequest = try request.asURLRequest()
        urlRequest.setValue(formData.contentType, forHTTPHeaderField: "Content-Type")

        let uploadable: UploadRequest.Uploadable
        if formData.contentLength < encodingMemoryThreshold && !isInBackgroundSession {
            let data = try formData.encode()

            uploadable = .data(data)
        } else {
            let tempDirectoryURL = fileManager.temporaryDirectory
            let directoryURL = tempDirectoryURL.appendingPathComponent("org.alamofire.manager/multipart.form.data")
            let fileName = UUID().uuidString
            let fileURL = directoryURL.appendingPathComponent(fileName)

            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)

            do {
                try formData.writeEncodedData(to: fileURL)
            } catch {
                // Cleanup after attempted write if it fails.
                try? fileManager.removeItem(at: fileURL)
            }

            uploadable = .file(fileURL, shouldRemove: true)
        }

        return (request: urlRequest, uploadable: uploadable)
    }
}

extension MultipartUpload: UploadConvertible {
    public func asURLRequest() throws -> URLRequest {
        return try result.unwrap().request
    }

    public func createUploadable() throws -> UploadRequest.Uploadable {
        return try result.unwrap().uploadable
    }
}
