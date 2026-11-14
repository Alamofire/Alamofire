//
//  AuthenticationTests.swift
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
import Testing

@Suite(.storesInstances)
struct BasicAuthenticationTestCase {
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func httpBasicAuthenticationFailsWithInvalidCredentials() async {
        // Given
        let session = stored(Session.independent())
        let endpoint = Endpoint.basicAuth()
        let completion = Completion("\(endpoint.url) 401")

        let response = Capture<DataResponse<Data?, AFError>?>()

        // When
        session.request(endpoint)
            .authenticate(username: "invalid", password: "credentials")
            .response { resp in
                response.value = resp
                completion.complete()
            }

        await completion.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.response?.statusCode == 401)
        #expect(response.data == nil)
        #expect(response.error == nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func httpBasicAuthenticationWithValidCredentials() async {
        // Given
        let session = stored(Session.independent())
        let user = "user1", password = "password"
        let endpoint = Endpoint.basicAuth(forUser: user, password: password)
        let completion = Completion("\(endpoint.url) 200")

        let response = Capture<DataResponse<Data?, AFError>?>()

        // When
        session.request(endpoint)
            .authenticate(username: user, password: password)
            .response { resp in
                response.value = resp
                completion.complete()
            }

        await completion.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.response?.statusCode == 200)
        #expect(response.data != nil)
        #expect(response.error == nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func httpBasicAuthenticationWithStoredCredentials() async {
        // Given
        let credentialStorage = URLCredentialStorage.independent()
        let configuration = URLSessionConfiguration.af.default
        configuration.urlCredentialStorage = credentialStorage
        let session = stored(Session.independent(configuration: configuration))
        let user = "user2", password = "password"
        let endpoint = Endpoint.basicAuth(forUser: user, password: password)
        let completion = Completion("\(endpoint.url) 200")

        let response = Capture<DataResponse<Data?, AFError>?>()

        // When
        let credential = URLCredential(user: user, password: password, persistence: .forSession)
        credentialStorage.setDefaultCredential(credential,
                                               for: .init(host: endpoint.host.rawValue,
                                                          port: endpoint.port,
                                                          protocol: endpoint.scheme.rawValue,
                                                          realm: endpoint.host.rawValue,
                                                          authenticationMethod: NSURLAuthenticationMethodHTTPBasic))

        session.request(endpoint)
            .response { resp in
                response.value = resp
                completion.complete()
            }

        await completion.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.response?.statusCode == 200)
        #expect(response.data != nil)
        #expect(response.error == nil)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func hiddenHTTPBasicAuthentication() async {
        // Given
        let session = stored(Session.independent())
        let endpoint = Endpoint.hiddenBasicAuth()
        let completion = Completion("\(endpoint.url) 200")

        let response = Capture<DataResponse<Data?, AFError>?>()

        // When
        session.request(endpoint)
            .response { resp in
                response.value = resp
                completion.complete()
            }

        await completion.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.response?.statusCode == 200)
        #expect(response.data != nil)
        #expect(response.error == nil)
    }
}

// MARK: -

@Suite(.storesInstances)
struct HTTPDigestAuthenticationTestCase {
    @Test(.disabled("Disabled due to HTTPBin flakiness."))
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func httpDigestAuthenticationWithInvalidCredentials() async {
        // Given
        let session = stored(Session.independent())
        let endpoint = Endpoint.digestAuth()
        let completion = Completion("\(endpoint.url) 401")

        let response = Capture<DataResponse<Data?, AFError>?>()

        // When
        session.request(endpoint)
            .authenticate(username: "invalid", password: "credentials")
            .response { resp in
                response.value = resp
                completion.complete()
            }

        await completion.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.response?.statusCode == 401)
        #expect(response.data == nil)
        #expect(response.error == nil)
    }

    @Test(.disabled("Disabled due to HTTPBin flakiness."))
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func httpDigestAuthenticationWithValidCredentials() async {
        // Given
        let session = stored(Session.independent())
        let user = "user", password = "password"
        let endpoint = Endpoint.digestAuth(forUser: user, password: password)
        let completion = Completion("\(endpoint.url) 200")

        let response = Capture<DataResponse<Data?, AFError>?>()

        // When
        session.request(endpoint)
            .authenticate(username: user, password: password)
            .response { resp in
                response.value = resp
                completion.complete()
            }

        await completion.wait()

        // Then
        #expect(response.request != nil)
        #expect(response.response != nil)
        #expect(response.response?.statusCode == 200)
        #expect(response.data != nil)
        #expect(response.error == nil)
    }
}
