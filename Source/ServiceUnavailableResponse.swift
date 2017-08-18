//
//  ServiceUnavailableResponse.swift
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

public enum RetryAfter {
    case seconds(Int)
    case date(Date)
}

extension RetryAfter {
    var secondsValue: Int? {
        switch self {
        case .seconds(let value):
            return value
        default:
            return nil
        }
    }
}

extension RetryAfter {
    var dateValue: Date? {
        switch self {
        case .date(let value):
            return value
        default:
            return nil
        }
    }
}

fileprivate class HttpDateFormatter {
    fileprivate class func getHttpHeaderDateFormatter() -> DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, dd LLL yyyy HH:mm:ss zzz"
        return dateFormatter
    }
}

class ServiceUnavailableResponse {
    fileprivate static let httpHeaderDateFormatter : DateFormatter = HttpDateFormatter.getHttpHeaderDateFormatter()
    
    class func isServiceUnavailableResponse(response: HTTPURLResponse) -> Bool {
        return response.statusCode == 503 && getRetryAfter(allHeaderFields: response.allHeaderFields) != nil
    }
    
    class func getRetryAfter(allHeaderFields: [AnyHashable : Any]) -> RetryAfter? {
        if allHeaderFields.keys.contains("Retry-After"), let headerValue = allHeaderFields["Retry-After"] as? String {
            return getRetryAfter(headerValue: headerValue)
        }

        return nil
    }
    
    fileprivate class func getRetryAfter(headerValue: String) -> RetryAfter? {
        if let retryAfterSeconds = Int(headerValue) {
            return .seconds(retryAfterSeconds)
        }
        else if let retryDate = httpHeaderDateFormatter.date(from: headerValue) {
            return .date(retryDate)
        }
        return nil
    }
}
