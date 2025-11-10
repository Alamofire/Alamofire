//
//  DownloadTests+ResumeData.swift
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
import XCTest

// MARK: - DownloadRequest ResumeData Extensions

extension DownloadTests {

    func testDownloadWithModifiedResumeData() {
        // Given
        let originalURL = "https://httpbin.org/bytes/1024"
        let newURL = "https://httpbin.org/bytes/2048"
        let expectation = expectation(description: "Download with modified resume data should work")

        var finalResponse: DownloadResponse<URL?, AFError>?

        // When
        // 1. Start and cancel original download to get resume data
        let originalRequest = AF.download(originalURL)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            originalRequest.cancel(byProducingStructuredResumeData: { result in
                switch result {
                case .success(let resumeData):
                    guard let resumeData = resumeData else {
                        expectation.fulfill()
                        return
                    }

                    // 2. Modify the URL in resume data
                    do {
                        let modifiedResumeData = try resumeData.modifyingURL(from: nil, to: newURL)

                        // 3. Resume with modified data
                        AF.download(resumingWith: modifiedResumeData.data)
                            .response { response in
                                finalResponse = response
                                expectation.fulfill()
                            }
                    } catch {
                        XCTFail("URL modification failed: \(error)")
                        expectation.fulfill()
                    }

                case .failure(let error):
                    XCTFail("Cancel failed: \(error)")
                    expectation.fulfill()
                }
            })
        }

        waitForExpectations(timeout: timeout)

        // Then
        if let response = finalResponse {
            XCTAssertNil(response.error)
            XCTAssertNotNil(response.fileURL)
            if let url = response.request?.url?.absoluteString {
                XCTAssertTrue(url.contains("2048"), "Should use modified URL")
            }
        }
    }

    func testBackwardCompatibilityWithRawResumeData() {
        // Given
        let endpoint = Endpoint.download(1024)
        let expectation = expectation(description: "Raw resume data should still work")

        var rawResumeData: Data?
        var finalResponse: DownloadResponse<URL?, AFError>?

        // When
        // 1. Get raw resume data using traditional method
        let originalRequest = AF.download(endpoint)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            originalRequest.cancel { resumeDataOrNil in
                rawResumeData = resumeDataOrNil

                // 2. Resume using raw data (backward compatibility)
                if let resumeData = rawResumeData {
                    AF.download(resumingWith: resumeData)
                        .response { response in
                            finalResponse = response
                            expectation.fulfill()
                        }
                } else {
                    expectation.fulfill()
                }
            }
        }

        waitForExpectations(timeout: timeout)

        // Then
        if let response = finalResponse {
            XCTAssertNil(response.error)
            XCTAssertNotNil(response.fileURL)
        }
    }
}

// MARK: - Structured vs Traditional Cancel Comparison

final class StructuredVsTraditionalCancelTests: BaseTestCase {

    @MainActor
    func testStructuredCancelVsTraditionalCancel() {
        // Given
        let endpoint = Endpoint.download(2048)
        let structuredExpectation = expectation(description: "Structured cancel should work")
        let traditionalExpectation = expectation(description: "Traditional cancel should work")

        var structuredResult: Result<ResumeData?, ResumeData.ResumeDataError>?
        var traditionalResumeData: Data?

        // When
        // Test structured cancel
        let request1 = AF.download(endpoint)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            request1.cancel(byProducingStructuredResumeData: { result in
                structuredResult = result
                structuredExpectation.fulfill()
            })
        }

        // Test traditional cancel
        let request2 = AF.download(endpoint)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            request2.cancel { resumeData in
                traditionalResumeData = resumeData
                traditionalExpectation.fulfill()
            }
        }

        waitForExpectations(timeout: timeout)

        // Then
        // Both methods should provide resume data
        switch structuredResult {
        case .success(let resumeData):
            if let resumeData = resumeData {
                XCTAssertGreaterThan(resumeData.data.count, 0)
                XCTAssertFalse(resumeData.detectedURLs.isEmpty)
            }
        case .failure(let error):
            XCTFail("Structured cancel should not fail: \(error)")
        case .none:
            XCTFail("Structured cancel should provide result")
        }

        if let traditionalData = traditionalResumeData {
            XCTAssertGreaterThan(traditionalData.count, 0)

            // Verify structured version can parse traditional resume data
            do {
                let structuredFromTraditional = try ResumeData(from: traditionalData)
                XCTAssertEqual(structuredFromTraditional.data, traditionalData)
            } catch {
                XCTFail("Should be able to create ResumeData from traditional data: \(error)")
            }
        }
    }
}
