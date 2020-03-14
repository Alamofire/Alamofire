//
//  Networking.swift
//  watchOS Example WatchKit Extension
//
//  Created by Jon Shier on 3/14/20.
//  Copyright © 2020 Alamofire. All rights reserved.
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
