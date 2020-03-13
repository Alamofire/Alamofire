//
//  ContentView.swift
//  watchOS Example WatchKit Extension
//
//  Created by Jon Shier on 3/11/20.
//  Copyright © 2020 Alamofire. All rights reserved.
//

import Alamofire
import SwiftUI

struct ContentView: View {
    @ObservedObject var networking: Networking

    var body: some View {
        VStack {
            Button(action: { self.networking.performRequest() },
                   label: { Text("Perform Alamofire Request") })
            Text(networking.alamofireMessage)
            Button(action: { self.networking.performURLSessionRequest() },
                   label: { Text("Perform URLSession Request") })
            Text(networking.urlSessionMessage)
        }
    }
}

struct ContentViewPreviews: PreviewProvider {
    static let networking = Networking()

    static var previews: some View {
        ContentView(networking: networking)
    }
}

import Combine

final class Networking: ObservableObject {
    @Published var alamofireResult: Result<HTTPBinResponse, AFError>?
    @Published var alamofireMessage: String = "No message."
    @Published var urlSessionResult: Result<Void, Error>?
    @Published var urlSessionMessage: String = "No message."

    private let urlSession = BasicSession()
    private var storage: Set<AnyCancellable> = []

    init() {
        $alamofireResult.map {
            if case let .success(value) = $0 {
                return value.url
            } else {
                return "No message."
            }
        }
        .assign(to: \.alamofireMessage, on: self)
        .store(in: &storage)

        $urlSessionResult.map {
            if case .success = $0 {
                return "Success."
            } else {
                return "No message."
            }
        }
        .assign(to: \.urlSessionMessage, on: self)
        .store(in: &storage)
    }

    func performRequest() {
        AF.request("https://httpbin.org/get").responseDecodable(of: HTTPBinResponse.self) { response in
            self.alamofireResult = response.result
        }
    }

    func performURLSessionRequest() {
        urlSession.request { result in
            self.urlSessionResult = result
        }
    }
}

struct HTTPBinResponse: Decodable {
    let url: String
}

final class BasicSession: NSObject, URLSessionTaskDelegate {
    private lazy var session = URLSession(configuration: .default,
                                          delegate: self,
                                          delegateQueue: queue)
    private lazy var queue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1

        return queue
    }()

    private var completion: ((Result<Void, Error>) -> Void)?

    override class func responds(to aSelector: Selector!) -> Bool {
        let didRespond = super.responds(to: aSelector)
        NSLog("Class did respond to \(aSelector!): \(didRespond)")
        return didRespond
    }

    override func responds(to aSelector: Selector!) -> Bool {
        let didRespond = super.responds(to: aSelector)
        NSLog("Instance did respond to \(aSelector!): \(didRespond)")
        return didRespond
    }

    func request(_ completion: @escaping (Result<Void, Error>) -> Void) {
        self.completion = completion
        session.dataTask(with: URL(string: "https://httpbin.org/get")!).resume()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                self.completion?(.failure(error))
            } else {
                self.completion?(.success(()))
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        NSLog("Metrics gathered.")
    }
}
