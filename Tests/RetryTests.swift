//
//  RetryTests.swift
//  Alamofire
//
//  Created by Brian King on 3/10/16.
//  Copyright © 2016 Alamofire. All rights reserved.
//

import Foundation

@testable import Alamofire
import Foundation
import XCTest

class RetryTestCase: BaseTestCase {

    func testBasicContinue() {
        let URLString = "https://httpbin.org/status/200"
        let expectation = expectationWithDescription("check can continue request")

        // When
        Alamofire.request(.GET, URLString)
            .checkForRetry() { request, completion in
                completion(.Continue)
            }
            .response { _, _, _, _ in
                expectation.fulfill()
        }

        waitForExpectationsWithTimeout(timeout, handler: nil)
    }

    func testRetry401() {
        let expectation = expectationWithDescription("request should return 404 status code")
        var responseCount = 0
        // When
        Alamofire.request(.GET, "https://httpbin.org/status/401")
            .checkForRetry() { request, completion in
                if request.response?.statusCode == 401 {
                    completion(.Retry(request: Alamofire.request(.GET, "https://httpbin.org/status/200")))
                }
                else {
                    completion(.Continue)
                }
            }
            .response { _, _, _, _ in
                responseCount += 1
                expectation.fulfill()
        }

        waitForExpectationsWithTimeout(timeout, handler: nil)
        XCTAssertEqual(responseCount, 1)
    }

}