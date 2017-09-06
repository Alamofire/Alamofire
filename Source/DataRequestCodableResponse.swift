//
//  DataRequestCodableResponse.swift
//  Alamofire
//
//  Created by Marius Landwehr on 21.08.17.
//  Copyright © 2017 Alamofire. All rights reserved.
//

import Foundation

extension DataRequest {
    
    enum DataResponseDecodableError: Error {
        case responseDataIsEmpty
    }
    
    @discardableResult
    public func responseDecodable<T: Decodable>(queue: DispatchQueue? = nil,
                                                completionHandler: @escaping (DataResponse<T>) -> Void) -> Self {
        return response(queue: queue) { response in
            
            var result: Result<T>
            defer {
                var dataResponse = DataResponse(request: response.request,
                                                response: response.response,
                                                data: response.data,
                                                result: result,
                                                timeline: response.timeline)
                completionHandler(dataResponse)
            }
            
            guard let data = response.data else {
                result = .failure(DataResponseDecodableError.responseDataIsEmpty)
                return
            }
            do {
                let codable = try JSONDecoder().decode(T.self, from: data)
                result = .success(codable)
            } catch {
                result = .failure(error)
            }
        }
    }
}
