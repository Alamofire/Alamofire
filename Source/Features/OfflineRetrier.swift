//
//  OfflineRetrier.swift
//
//  Copyright (c) 2025 Alamofire Software Foundation (http://alamofire.org/)
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

#if canImport(Network)
import Foundation
import Network

/// `RequestRetrier` which uses `NWPathMonitor` to detect when connectivity is restored to retry failed requests.
@available(macOS 10.14, iOS 12, tvOS 12, watchOS 5, visionOS 1, *)
public final class OfflineRetrier: RequestAdapter, RequestRetrier, RequestInterceptor, Sendable {
    /// Default amount of time to wait for connectivity to be restored before failure. `.seconds(5)` by default.
    public static let defaultWait: DispatchTimeInterval = .seconds(5)
    /// Default `Set<URLError.Code>` used to check for offline errors. `[.notConnectedToInternet]` by default.
    public static let defaultURLErrorOfflineCodes: Set<URLError.Code> = [
        .notConnectedToInternet
    ]
    /// Default method of detecting whether a particular `any Error` means connectivity is offline.
    public static let defaultIsOfflineError: @Sendable (_ error: any Error) -> Bool = { error in
        if let error = error.asAFError?.underlyingError {
            defaultIsOfflineError(error)
        } else if let error = error as? URLError {
            defaultURLErrorOfflineCodes.contains(error.code)
        } else {
            false
        }
    }

    private static let monitorQueue = DispatchQueue(label: "org.alamofire.offlineRetrier.monitorQueue")

    fileprivate struct State {
        let maximumWait: DispatchTimeInterval
        let isOfflineError: (_ error: any Error) -> Bool
        let monitorCreator: () -> PathMonitor

        var timeoutWorkItem: DispatchWorkItem?
        var currentMonitor: PathMonitor?
        var pendingCompletions: [@Sendable (_ retryResult: RetryResult) -> Void] = []
    }

    private let state: Protected<State>

    /// Creates an instance from the provided `NWPathMonitor`, maximum wait for connectivity, and offline error predicate.
    ///
    /// - Parameters:
    ///   - monitor:        `NWPathMonitor()` to use to detect connectivity. A new instance is created each time a
    ///                     request fails and retry may be needed.
    ///   - maximumWait:    `DispatchTimeInterval` to wait for connectivity before
    ///   - isOfflineError: Predicate closure used to determine whether a particular `any Error` indicates connectivity
    ///                     is offline. Returning `false` moves to the next retrier, if any.
    ///
    public init(monitor: @autoclosure @escaping () -> NWPathMonitor = NWPathMonitor(),
                maximumWait: DispatchTimeInterval = OfflineRetrier.defaultWait,
                isOfflineError: @escaping @Sendable (_ error: any Error) -> Bool = OfflineRetrier.defaultIsOfflineError) {
        state = Protected(State(maximumWait: maximumWait, isOfflineError: isOfflineError) { PathMonitor(monitor()) })
    }

    /// Creates an instance using an `NWPathMonitor` configured with the provided `InterfaceType`, maximum wait for
    /// connectivity, and offline error predicate.
    ///
    /// - Parameters:
    ///   - monitor:        `NWInterface.InterfaceType` used to configured the `NWPathMonitor` each time one is needed.
    ///   - maximumWait:    `DispatchTimeInterval` to wait for connectivity before
    ///   - isOfflineError: Predicate closure used to determine whether a particular `any Error` indicates connectivity
    ///                     is offline. Returning `false` moves to the next retrier, if any.
    ///
    public convenience init(requiredInterfaceType: NWInterface.InterfaceType,
                            maximumWait: DispatchTimeInterval = OfflineRetrier.defaultWait,
                            isOfflineError: @escaping @Sendable (_ error: any Error) -> Bool = OfflineRetrier.defaultIsOfflineError) {
        self.init(monitor: NWPathMonitor(requiredInterfaceType: requiredInterfaceType), maximumWait: maximumWait, isOfflineError: isOfflineError)
    }

    /// Creates an instance using an `NWPathMonitor` configured with the provided `InterfaceType`s, maximum wait for
    /// connectivity, and offline error predicate.
    ///
    /// - Parameters:
    ///   - monitor:        `[NWInterface.InterfaceType]` used to configured the `NWPathMonitor` each time one is needed.
    ///   - maximumWait:    `DispatchTimeInterval` to wait for connectivity before
    ///   - isOfflineError: Predicate closure used to determine whether a particular `any Error` indicates connectivity
    ///                     is offline. Returning `false` moves to the next retrier, if any.
    ///
    @available(macOS 11, iOS 14, tvOS 14, watchOS 7, visionOS 1, *)
    public convenience init(prohibitedInterfaceTypes: [NWInterface.InterfaceType],
                            maximumWait: DispatchTimeInterval = OfflineRetrier.defaultWait,
                            isOfflineError: @escaping @Sendable (_ error: any Error) -> Bool = OfflineRetrier.defaultIsOfflineError) {
        self.init(monitor: NWPathMonitor(prohibitedInterfaceTypes: prohibitedInterfaceTypes), maximumWait: maximumWait, isOfflineError: isOfflineError)
    }

    init(monitor: @autoclosure @escaping () -> PathMonitor,
         maximumWait: DispatchTimeInterval,
         isOfflineError: @escaping @Sendable (_ error: any Error) -> Bool = OfflineRetrier.defaultIsOfflineError) {
        state = Protected(State(maximumWait: maximumWait, isOfflineError: isOfflineError, monitorCreator: monitor))
    }

    deinit {
        state.write { state in
            state.cleanupMonitor()
        }
    }

    public func retry(_ request: Request,
                      for session: Session,
                      dueTo error: any Error,
                      completion: @escaping @Sendable (RetryResult) -> Void) {
        state.write { state in
            guard state.isOfflineError(error) else { completion(.doNotRetry); return }

            state.pendingCompletions.append(completion)

            guard state.currentMonitor == nil else { return }

            state.startListening { [unowned self] result in
                let retryResult: RetryResult = switch result {
                case .pathAvailable:
                    .retry
                case .timeout:
                    // Do not retry, keep original error.
                    .doNotRetry
                }

                performResult(retryResult)
            }
        }
    }

    private func performResult(_ result: RetryResult) {
        state.write { state in
            let completions = state.pendingCompletions
            state.cleanupMonitor()
            for completion in completions {
                Self.monitorQueue.async {
                    completion(result)
                }
            }
        }
    }
}

@available(macOS 10.14, iOS 12, tvOS 12, watchOS 5, visionOS 1, *)
extension OfflineRetrier.State {
    fileprivate mutating func startListening(onResult: @escaping @Sendable (_ result: PathMonitor.Result) -> Void) {
        let timeout = DispatchWorkItem {
            onResult(.timeout)
        }
        timeoutWorkItem = timeout
        OfflineRetrier.monitorQueue.asyncAfter(deadline: .now() + maximumWait, execute: timeout)

        currentMonitor = monitorCreator()
        currentMonitor?.startListening(on: OfflineRetrier.monitorQueue, onResult: onResult)
    }

    fileprivate mutating func cleanupMonitor() {
        pendingCompletions.removeAll()
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        currentMonitor?.stopListening()
        currentMonitor = nil
    }
}

@available(macOS 10.14, iOS 12, tvOS 12, watchOS 5, visionOS 1, *)
extension RequestInterceptor where Self == OfflineRetrier {
    /// Creates an instance from the provided `NWPathMonitor`, maximum wait for connectivity, and offline error predicate.
    ///
    /// - Parameters:
    ///   - monitor:        `NWPathMonitor()` to use to detect connectivity. A new instance is created each time a
    ///                     request fails and retry may be needed.
    ///   - maximumWait:    `DispatchTimeInterval` to wait for connectivity before timeout.
    ///   - isOfflineError: Predicate closure used to determine whether a paricular `any Error` indicates connectivity
    ///                     is offline. Returning `false` moves to the next retrier, if any.
    ///
    public static func offlineRetrier(
        monitor: @autoclosure @escaping () -> NWPathMonitor = NWPathMonitor(),
        maximumWait: DispatchTimeInterval = OfflineRetrier.defaultWait,
        isOfflineError: @escaping @Sendable (_ error: any Error) -> Bool = OfflineRetrier.defaultIsOfflineError
    ) -> OfflineRetrier {
        OfflineRetrier(monitor: monitor(), maximumWait: maximumWait, isOfflineError: isOfflineError)
    }

    /// Creates an instance using an `NWPathMonitor` configured with the provided `InterfaceType`, maximum wait for
    /// connectivity, and offline error predicate.
    ///
    /// - Parameters:
    ///   - monitor:        `NWInterface.InterfaceType` used to configured the `NWPathMonitor` each time one is needed.
    ///   - maximumWait:    `DispatchTimeInterval` to wait for connectivity before timeout.
    ///   - isOfflineError: Predicate closure used to determine whether a paricular `any Error` indicates connectivity
    ///                     is offline. Returning `false` moves to the next retrier, if any.
    ///
    public static func offlineRetrier(
        requiredInterfaceType: NWInterface.InterfaceType,
        maximumWait: DispatchTimeInterval = OfflineRetrier.defaultWait,
        isOfflineError: @escaping @Sendable (_ error: any Error) -> Bool = OfflineRetrier.defaultIsOfflineError
    ) -> OfflineRetrier {
        OfflineRetrier(requiredInterfaceType: requiredInterfaceType, maximumWait: maximumWait, isOfflineError: isOfflineError)
    }

    /// Creates an instance using an `NWPathMonitor` configured with the provided `InterfaceType`s, maximum wait for
    /// connectivity, and offline error predicate.
    ///
    /// - Parameters:
    ///   - monitor:        `[NWInterface.InterfaceType]` used to configured the `NWPathMonitor` each time one is needed.
    ///   - maximumWait:    `DispatchTimeInterval` to wait for connectivity before timeout.
    ///   - isOfflineError: Predicate closure used to determine whether a paricular `any Error` indicates connectivity
    ///                     is offline. Returning `false` moves to the next retrier, if any.
    ///
    @available(macOS 11, iOS 14, tvOS 14, watchOS 7, visionOS 1, *)
    public static func offlineRetrier(
        prohibitedInterfaceTypes: [NWInterface.InterfaceType],
        maximumWait: DispatchTimeInterval = OfflineRetrier.defaultWait,
        isOfflineError: @escaping @Sendable (_ error: any Error) -> Bool = OfflineRetrier.defaultIsOfflineError
    ) -> OfflineRetrier {
        OfflineRetrier(prohibitedInterfaceTypes: prohibitedInterfaceTypes, maximumWait: maximumWait, isOfflineError: isOfflineError)
    }

    static func offlineRetrier(
        monitor: @autoclosure @escaping () -> PathMonitor,
        maximumWait: DispatchTimeInterval
    ) -> OfflineRetrier {
        OfflineRetrier(monitor: monitor(), maximumWait: maximumWait)
    }
}

/// Internal abstraction for starting and stopping a path monitor. Used for testing.
@available(macOS 10.14, iOS 12, tvOS 12, watchOS 5, visionOS 1, *)
struct PathMonitor {
    enum Result {
        case pathAvailable, timeout
    }

    /// Starts the listener's work. Ensure work is properly cancellable in `stop()` in case of cancellation
    var start: (_ queue: DispatchQueue, _ onResult: @escaping @Sendable (_ result: Result) -> Void) -> Void
    /// Stops the listener. Ensure ongoing work is cancelled.
    var stop: () -> Void

    func startListening(on queue: DispatchQueue, onResult: @escaping @Sendable (_ result: Result) -> Void) {
        start(queue, onResult)
    }

    func stopListening() {
        stop()
    }
}

@available(macOS 10.14, iOS 12, tvOS 12, watchOS 5, visionOS 1, *)
extension PathMonitor {
    init(_ pathMonitor: NWPathMonitor) {
        start = { queue, onResult in
            pathMonitor.pathUpdateHandler = { path in
                if path.status != .unsatisfied {
                    onResult(.pathAvailable)
                }
            }
            pathMonitor.start(queue: queue)
        }

        stop = {
            pathMonitor.cancel()
            pathMonitor.pathUpdateHandler = nil
        }
    }
}
#endif
