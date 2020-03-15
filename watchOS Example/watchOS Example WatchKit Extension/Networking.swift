//
//  Networking.swift
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

import Alamofire
import Combine

final class Networking: ObservableObject {
    @Published var result: Result<HTTPBinResponse, AFError>?
    @Published var message = "No response."

    private var storage: Set<AnyCancellable> = []

    init() {
        $result
            .compactMap { $0 }
            .map {
                if case .success = $0 {
                    return "Successful!"
                } else {
                    return "Failed!"
                }
            }
            .assign(to: \.message, on: self)
            .store(in: &storage)
    }

    func performRequest() {
        AF.request("https://httpbin.org/get").responseDecodable(of: HTTPBinResponse.self) { response in
            self.result = response.result
        }
    }
}

struct HTTPBinResponse: Decodable {
    let url: String
}
