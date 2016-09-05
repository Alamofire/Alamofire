//
//  FileManager+AlamofireTests.swift
//
//  Copyright (c) 2014-2016 Alamofire Software Foundation (http://alamofire.org/)
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

extension FileManager {

    // MARK: - Common Directories

    static var documentsDirectoryPath: String {
        return NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
    }

    static var documentsDirectoryURL: URL {
        return URL(fileURLWithPath: FileManager.documentsDirectoryPath, isDirectory: true)
    }

    static var libraryDirectoryPath: String {
        return NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)[0]
    }

    static var libraryDirectoryURL: URL {
        return URL(fileURLWithPath: FileManager.libraryDirectoryPath, isDirectory: true)
    }

    static var applicationSupportDirectoryPath: String {
        return NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)[0]
    }

    static var applicationSupportDirectoryURL: URL {
        return URL(fileURLWithPath: FileManager.applicationSupportDirectoryPath, isDirectory: true)
    }

    static var cachesDirectoryPath: String {
        return NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0]
    }

    static var cachesDirectoryURL: URL {
        return URL(fileURLWithPath: FileManager.cachesDirectoryPath, isDirectory: true)
    }

    static var temporaryDirectoryPath: String {
        return NSTemporaryDirectory()
    }

    static var temporaryDirectoryURL: URL {
        return URL(fileURLWithPath: FileManager.temporaryDirectoryPath, isDirectory: true)
    }

    // MARK: - File System Modification

    @discardableResult
    static func createDirectory(atPath path: String) -> Bool {
        do {
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    static func removeItem(atPath path: String) -> Bool {
        do {
            try FileManager.default.removeItem(atPath: path)
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    static func removeAllItemsInsideDirectory(atPath path: String) -> Bool {
        let enumerator = FileManager.default.enumerator(atPath: path)
        var result = true

        while let fileName = enumerator?.nextObject() as? String {
            let success = removeItem(atPath: path + "/\(fileName)")
            if !success { result = false }
        }

        return result
    }
}
