//
//  URLSessionConfiguration.swift
//  Alamofire
//
//  Created by Jon Shier on 5/22/18.
//  Copyright © 2018 Alamofire. All rights reserved.
//

import Foundation

extension URLSessionConfiguration {
    public static var alamofireDefault: URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = HTTPHeaders.defaultHTTPHeaders

        return configuration
    }
}
