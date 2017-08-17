//
//  SiteMaintenanceResponse.swift

import Foundation

public enum RetryAfter {
    case seconds(Int)
    case date(Date)
}

extension RetryAfter {
    var seconds: Int? {
        switch self {
        case .seconds(let value):
            return value
        default:
            return nil
        }
    }
}

extension RetryAfter {
    var date: Date? {
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

class SiteMaintenanceResponse {
    fileprivate static let httpHeaderDateFormatter : DateFormatter = HttpDateFormatter.getHttpHeaderDateFormatter()
    
    class func isSiteMaintenanceResponse(response: HTTPURLResponse) -> Bool {
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
