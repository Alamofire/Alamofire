//
//  Constant.swift
//  iOS Example
//
//  Created by Larry Lo on 14/1/2024.
//  Copyright © 2024 Alamofire. All rights reserved.
//

import Foundation
import Alamofire


func formatElapsedTime(elapsedTime: TimeInterval) -> String {
    
    let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()
    
    let elapsedTimeText = numberFormatter.string(from: elapsedTime as NSNumber) ?? "???"
    
    return "Elapsed Time: \(elapsedTimeText) sec"
}

let baseURL = "https://httpbin.org"
let getURL = "\(baseURL)/get"
let postURL = " \(baseURL)/post"
let putURL = "\(baseURL)/put"
let deleteURL = "\(baseURL)/delete"
let downloadURL = "\(baseURL)/stream/1"
