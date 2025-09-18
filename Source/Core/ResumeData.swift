//
//  ResumeData.swift
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

/// Represents resume data for download requests, providing safe modification capabilities.
///
/// This type allows parsing and modifying resume data while maintaining compatibility
/// with URLSession's resume functionality.
public struct ResumeData: Sendable {
    private let rawData: Data
    private let parsedDict: [String: Any]?

    /// Errors that can occur when working with resume data.
    public enum ResumeDataError: Error, LocalizedError {
        case invalidFormat
        case parsingFailed(underlying: Error)
        case serializationFailed(underlying: Error)
        case urlModificationFailed(reason: String)

        public var errorDescription: String? {
            switch self {
            case .invalidFormat:
                return "Resume data format is invalid or unsupported"
            case .parsingFailed(let error):
                return "Failed to parse resume data: \(error.localizedDescription)"
            case .serializationFailed(let error):
                return "Failed to serialize resume data: \(error.localizedDescription)"
            case .urlModificationFailed(let reason):
                return "URL modification failed: \(reason)"
            }
        }
    }

    /// Initialize ResumeData from raw Data.
    /// - Parameter data: Raw resume data from URLSessionDownloadTask
    /// - Throws: ResumeDataError if parsing fails
    public init(from data: Data) throws {
        self.rawData = data

        // Attempt to parse as property list
        do {
            var format = PropertyListSerialization.PropertyListFormat.xml
            let plist = try PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: &format
            )
            self.parsedDict = plist as? [String: Any]

            // Validate basic structure
            guard parsedDict != nil else {
                throw ResumeDataError.invalidFormat
            }
        } catch {
            throw ResumeDataError.parsingFailed(underlying: error)
        }
    }

    /// The original raw resume data.
    public var data: Data { rawData }

    /// Detected URLs in the resume data.
    public var detectedURLs: [String] {
        guard let dict = parsedDict,
              let objects = dict["$objects"] as? [Any] else {
            return []
        }

        return objects.compactMap { obj -> String? in
            guard let str = obj as? String,
                  isValidURL(str) else { return nil }
            return str
        }
    }

    /// Creates modified resume data with updated URLs.
    /// - Parameters:
    ///   - oldURL: Specific URL to replace. If nil, all detected URLs will be replaced.
    ///   - newURL: New URL to use for replacement.
    /// - Returns: New ResumeData with modified URLs.
    /// - Throws: ResumeDataError if modification fails.
    public func modifyingURL(from oldURL: String? = nil, to newURL: String) throws -> ResumeData {
        guard let dict = parsedDict else {
            throw ResumeDataError.invalidFormat
        }

        // Validate new URL
        guard isValidURL(newURL) else {
            throw ResumeDataError.urlModificationFailed(reason: "New URL '\(newURL)' is not valid")
        }

        // Create mutable copy and modify URLs
        var mutableDict = dict
        guard var objects = mutableDict["$objects"] as? [Any] else {
            throw ResumeDataError.invalidFormat
        }

        var replacementCount = 0

        for i in 0..<objects.count {
            if let stringItem = objects[i] as? String {
                let shouldReplace: Bool
                if let targetURL = oldURL {
                    shouldReplace = stringItem == targetURL
                } else {
                    shouldReplace = isValidURL(stringItem)
                }

                if shouldReplace {
                    objects[i] = newURL
                    replacementCount += 1
                }
            }
        }

        // Validate that at least one replacement occurred
        if oldURL != nil && replacementCount == 0 {
            throw ResumeDataError.urlModificationFailed(reason: "Target URL '\(oldURL!)' not found in resume data")
        }

        mutableDict["$objects"] = objects

        // Serialize back to Data
        do {
            let newData = try PropertyListSerialization.data(
                fromPropertyList: mutableDict,
                format: .xml,
                options: 0
            )
            return try ResumeData(from: newData)
        } catch {
            throw ResumeDataError.serializationFailed(underlying: error)
        }
    }

    private func isValidURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        return url.scheme != nil
    }
}
