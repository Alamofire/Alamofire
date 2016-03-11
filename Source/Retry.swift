//
//  Retry.swift
//  Alamofire
//
//  Created by Brian King on 3/10/16.
//  Copyright © 2016 Alamofire. All rights reserved.
//

import Foundation

extension Request {

    /**
     Copy the response chain from the cancelled request and add them to the current request.

     - parameter request: The request to copy the response chain from

     - returns: The request.
     */
    public func copyResponseChainFromRequest(request: Request) -> Self {
        for responseHandler in request.delegate.responseHandlers {
            response(responseHandler)
        }
        return self
    }

    public enum Action {
        case Continue
        case Retry(request: Request)
    }

    public typealias RetryCheck = (currentRequest: Request, completion:Action -> Void) -> Void

    public func checkForRetry(retryCheck: RetryCheck) -> Self {
        response() { (request: Request) -> Void in
            request.delegate.queue.suspended = true
            retryCheck(currentRequest: request, completion: { action in
                switch action {
                case .Continue:
                    request.delegate.queue.suspended = false
                case let .Retry(newRequest):
                    newRequest.copyResponseChainFromRequest(request)
                    request.cancel()
                }
            })
        }
        return self
    }
}