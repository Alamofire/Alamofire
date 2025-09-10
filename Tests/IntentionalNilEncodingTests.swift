//
//  IntentionalNilEncodingTests.swift
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

final class IntentionalNilEncodingTests: BaseTestCase {
    // MARK: - Test Helper Structures

    struct TestStruct: Encodable {
        let encodeNil: String? = nil
        let encodeIfPresentNil: String? = nil
        let hasValue: String? = "test"

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            // Test encode nil behavior
            try container.encode(encodeNil, forKey: .encodeNil)
            // Test encodeIfPresent nil behavior
            try container.encodeIfPresent(encodeIfPresentNil, forKey: .encodeIfPresentNil)
            // Test value encoding
            try container.encodeIfPresent(hasValue, forKey: .hasValue)
        }

        enum CodingKeys: String, CodingKey {
            case encodeNil = "encode"
            case encodeIfPresentNil = "encodeIfPresent"
            case hasValue = "value"
        }
    }


    // MARK: - Intentional Only Strategy Tests

    func testIntentionalOnlyStrategy() throws {
        // Given
        let encoder = URLEncodedFormEncoder(alphabetizeKeyValuePairs: false, nilEncoding: .intentionalOnly)

        // When
        let result: String = try encoder.encode(TestStruct())

        // Then
        XCTAssertEqual(result, "encode=null&value=test")
    }

    func testIntentionalOnlyOnlyEncode() throws {
        // Given
        struct OnlyEncodeTest: Encodable {
            func encode(to encoder: any Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(nil as String?, forKey: .test)
            }
            enum CodingKeys: String, CodingKey { case test = "encode" }
        }
        let encoder = URLEncodedFormEncoder(alphabetizeKeyValuePairs: false, nilEncoding: .intentionalOnly)

        // When
        let result: String = try encoder.encode(OnlyEncodeTest())

        // Then
        XCTAssertEqual(result, "encode=null")
    }

    func testIntentionalOnlyOnlyEncodeIfPresent() throws {
        // Given
        struct OnlyEncodeIfPresentTest: Encodable {
            let nilValue: String? = nil
            func encode(to encoder: any Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encodeIfPresent(nilValue, forKey: .test)
            }
            enum CodingKeys: String, CodingKey { case test = "encodeIfPresent" }
        }
        let encoder = URLEncodedFormEncoder(alphabetizeKeyValuePairs: false, nilEncoding: .intentionalOnly)

        // When
        let result: String = try encoder.encode(OnlyEncodeIfPresentTest())

        // Then
        XCTAssertEqual(result, "")
    }

    // MARK: - Custom Dual Strategy Tests

    func testCustomDualStrategy() throws {
        // Given
        let customStrategy = URLEncodedFormEncoder.NilEncoding(
            encode: { "NULL" },
            encodeIfPresent: { "EMPTY" }
        )
        let encoder = URLEncodedFormEncoder(alphabetizeKeyValuePairs: false, nilEncoding: customStrategy)

        // When
        let result: String = try encoder.encode(TestStruct())

        // Then
        XCTAssertEqual(result, "encode=NULL&encodeIfPresent=EMPTY&value=test")
    }

    func testCustomLegacyStrategy() throws {
        // Given
        let legacyStrategy = URLEncodedFormEncoder.NilEncoding { "custom_null" }
        let encoder = URLEncodedFormEncoder(alphabetizeKeyValuePairs: false, nilEncoding: legacyStrategy)

        // When
        let result: String = try encoder.encode(TestStruct())

        // Then
        XCTAssertEqual(result, "encode=custom_null&encodeIfPresent=custom_null&value=test")
    }

    // MARK: - Array Nil Elements Tests

    func testArrayWithNilElements() throws {
        // Given
        struct ArrayTest: Encodable {
            let values: [String?] = ["a", nil, "b"]
        }
        let encoder = URLEncodedFormEncoder(alphabetizeKeyValuePairs: false, nilEncoding: .intentionalOnly)

        // When
        let result: String = try encoder.encode(ArrayTest())

        // Then
        let decodedResult = result.removingPercentEncoding ?? result
        XCTAssertEqual(decodedResult, "values[]=a&values[]=null&values[]=b")
    }

    func testArrayWithAllNils() throws {
        // Given
        struct ArrayTest: Encodable {
            let nils: [String?] = [nil, nil]
        }
        let encoder = URLEncodedFormEncoder(alphabetizeKeyValuePairs: false, nilEncoding: .intentionalOnly)

        // When
        let result: String = try encoder.encode(ArrayTest())

        // Then
        let decodedResult = result.removingPercentEncoding ?? result
        XCTAssertEqual(decodedResult, "nils[]=null&nils[]=null")
    }

    // MARK: - Mixed Scenarios Tests

    func testComplexMixedScenarios() throws {
        // Given
        struct ComplexStruct: Encodable {
            let regularValue: String = "normal"
            let encodeNil: String? = nil
            let encodeIfPresentNil: String? = nil
            let hasValue: String? = "exists"
            let array: [String?] = ["value", nil]

            func encode(to encoder: any Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(regularValue, forKey: .regularValue)
                try container.encodeNil(forKey: .encodeNil)
                try container.encodeIfPresent(encodeIfPresentNil, forKey: .encodeIfPresentNil)
                try container.encodeIfPresent(hasValue, forKey: .hasValue)
                try container.encode(array, forKey: .array)
            }

            enum CodingKeys: String, CodingKey {
                case regularValue, encodeNil, encodeIfPresentNil, hasValue, array
            }
        }
        let encoder = URLEncodedFormEncoder(alphabetizeKeyValuePairs: false, nilEncoding: .intentionalOnly)

        // When
        let result: String = try encoder.encode(ComplexStruct())

        // Then
        let decodedResult = result.removingPercentEncoding ?? result
        XCTAssertEqual(decodedResult, "regularValue=normal&encodeNil=null&hasValue=exists&array[]=value&array[]=null")
    }

    // MARK: - Edge Cases

    func testEmptyObjectWithEncodeIfPresentNils() throws {
        // Given
        struct EmptyStruct: Encodable {
            let nil1: String? = nil
            let nil2: String? = nil

            func encode(to encoder: any Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encodeIfPresent(nil1, forKey: .nil1)
                try container.encodeIfPresent(nil2, forKey: .nil2)
            }

            enum CodingKeys: String, CodingKey {
                case nil1, nil2
            }
        }
        let encoder = URLEncodedFormEncoder(alphabetizeKeyValuePairs: false, nilEncoding: .intentionalOnly)

        // When
        let result: String = try encoder.encode(EmptyStruct())

        // Then
        XCTAssertEqual(result, "")
    }

    func testSingleValueContainerWithNil() throws {
        // Given
        struct SingleValue: Encodable {
            func encode(to encoder: any Encoder) throws {
                var container = encoder.singleValueContainer()
                try container.encodeNil()
            }
        }
        let encoder = URLEncodedFormEncoder(alphabetizeKeyValuePairs: false, nilEncoding: .intentionalOnly)

        // When & Then
        XCTAssertThrowsError(try encoder.encode(SingleValue()) as String) { error in
            if let afError = error as? URLEncodedFormEncoder.Error {
                switch afError {
                case .invalidRootObject:
                    break // Expected error for non-keyed root object
                }
            }
        }
    }
}
