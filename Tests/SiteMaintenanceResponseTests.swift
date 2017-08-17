//
//  SiteMaintenanceResponseTests.swift

import XCTest
@testable import Alamofire

class SiteMaintenanceResponseTests: XCTestCase {
    fileprivate let dummyUrl:URL = URL(string: "http://dummy")!
    
    func test_getRetryAfter_withRetryAfterHeaderSeconds_returnsFalse() {
        let expectedSeconds = 21
        let secondsHeader = ["Retry-After" : "\(expectedSeconds)"]
        
        let retryAfter = SiteMaintenanceResponse.getRetryAfter(allHeaderFields: secondsHeader)
        XCTAssertNotNil(retryAfter)
        XCTAssertNotNil(retryAfter?.seconds)
        XCTAssertEqual(retryAfter?.seconds!, expectedSeconds)
    }
    
    func test_getRetryAfter_withRetryAfterHeader24HourHTTPFormattedDate_returnsFalse() {
        let dateString = "Fri, 31 Dec 2017 23:59:59 GMT"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, dd LLL yyyy HH:mm:ss zzz"
        let expectedDate = dateFormatter.date(from: dateString)
        let httpFormattedDateHeader = ["Retry-After" : dateString]
        
        let retryAfter = SiteMaintenanceResponse.getRetryAfter(allHeaderFields: httpFormattedDateHeader)
        XCTAssertNotNil(retryAfter)
        XCTAssertNotNil(retryAfter?.date)
        XCTAssertEqual(retryAfter?.date, expectedDate)
    }
    
    func test_getRetryAfter_withInvalidHeaderValue_returnsFalse() {
        let invalidValue = "i'm invalid"
        let invalidValueHeader = ["Retry-After" : "\(invalidValue)"]
        
        let retryAfter = SiteMaintenanceResponse.getRetryAfter(allHeaderFields: invalidValueHeader)
        XCTAssertNil(retryAfter)
    }
    
    func test_isSiteMaintenanceResponse_with503AndRetryAfterHeaderSeconds_returnsFalse() {
        let response503 = HTTPURLResponse(
            url: dummyUrl,
            statusCode: 503,
            httpVersion: "HTTP/1.1",
            headerFields: ["Retry-After" : "20"]
            )!
        let isSiteMaintenanceResponse = SiteMaintenanceResponse.isSiteMaintenanceResponse(response: response503)
        XCTAssertTrue(isSiteMaintenanceResponse)
    }
    
    func test_isSiteMaintenanceResponse_with503AndRetryAfterHeader24HourHTTPFormattedDate_returnsFalse() {
        let response503 = HTTPURLResponse(
            url: dummyUrl,
            statusCode: 503,
            httpVersion: "HTTP/1.1",
            headerFields: ["Retry-After" : "Fri, 31 Dec 2017 23:59:59 GMT"]
            )!
        let isSiteMaintenanceResponse = SiteMaintenanceResponse.isSiteMaintenanceResponse(response: response503)
        XCTAssertTrue(isSiteMaintenanceResponse)
    }
    
    func test_isSiteMaintenanceResponse_with503AndNoRetryAfterHeader_returnsFalse() {
        let response503 = HTTPURLResponse(
            url: dummyUrl,
            statusCode: 503,
            httpVersion: "HTTP/1.1",
            headerFields: nil
            )!
        let isSiteMaintenanceResponse = SiteMaintenanceResponse.isSiteMaintenanceResponse(response: response503)
        XCTAssertFalse(isSiteMaintenanceResponse)
    }
    
    func test_isSiteMaintenanceResponse_with200OK_returnsFalse() {
        let response200Ok = HTTPURLResponse(
            url: dummyUrl,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!
        let isSiteMaintenanceResponse = SiteMaintenanceResponse.isSiteMaintenanceResponse(response: response200Ok)
        XCTAssertFalse(isSiteMaintenanceResponse)
    }
    
    func test_isSiteMaintenanceResponse_with200OKEmptyHeaders_returnsFalse() {
        let response200Ok = HTTPURLResponse(
            url: dummyUrl,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [:]
            )!
        let isSiteMaintenanceResponse = SiteMaintenanceResponse.isSiteMaintenanceResponse(response: response200Ok)
        XCTAssertFalse(isSiteMaintenanceResponse)
    }
    
    func test_isSiteMaintenanceResponse_with200OKAndRetryAfterHeader_returnsFalse() {
        let response200Ok = HTTPURLResponse(
            url: dummyUrl,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Retry-After" : "20"]
            )!
        let isSiteMaintenanceResponse = SiteMaintenanceResponse.isSiteMaintenanceResponse(response: response200Ok)
        XCTAssertFalse(isSiteMaintenanceResponse)
    }
    
}
