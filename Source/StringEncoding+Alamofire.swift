//
//  StringEncoding+Alamofire.swift
//
//  Copyright (c) 2020 Alamofire Software Foundation (http://alamofire.org/)
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

extension String.Encoding {
    /// Creates an encoding from the IANA charset name.
    ///
    /// - Notes: These mappings match those [provided by CoreFoundation](https://opensource.apple.com/source/CF/CF-476.18/CFStringUtilities.c.auto.html)
    ///
    /// - Parameter name: IANA charset name.
    init?(ianaCharsetName name: String) {
        switch name.lowercased() {
        case "utf-8":
            self = .utf8
        case "iso-8859-1":
            self = .isoLatin1
        case "unicode-1-1", "iso-10646-ucs-2", "utf-16":
            self = .utf16
        case "utf-16be":
            self = .utf16BigEndian
        case "utf-16le":
            self = .utf16LittleEndian
        case "utf-32":
            self = .utf32
        case "utf-32be":
            self = .utf32BigEndian
        case "utf-32le":
            self = .utf32LittleEndian
        default:
            return nil
        }
    }
}
