//
//  ConstantPool.swift
//  Alamofire
//
//  Created by NHN on 2021/03/25.
//  Copyright © 2021 Alamofire. All rights reserved.
//

import Foundation

let ALAMOFIRE_NAME = "Alamofire"

enum Header : String{
    case Accept = "Accept"
    case Accept_Charset = "Accept-Charset"
    case Accept_Language = "Accept-Language"
    case Accept_Encoding = "Accept-Encoding"
    case Authorization = "Authorization"
    case Content_Disposition = "Content-Disposition"
    case Content_Type = "Content-Type"
    case User_Agent = "User-Agent"
}

enum Auth : String {
    case Basic = "Basic"
    case Bearer = "Bearer"
}

enum Flatform : String {
    case macOS_Catalyst = "macOS(Catalyst)"
    case iOS = "iOS"
    case watchOS = "watchOS"
    case tvOS = "tvOS"
    case macOS = "macOS"
    case Linux = "Linux"
    case Windows = "Windows"
    case Unknown = "Unknown"
}

enum Plist : String {
    case CFBundleShortVersionString = "CFBundleShortVersionString"
    case Unknown = "Unknown"
}

enum Encodings : String {
    case br = "br"
    case gzip = "gzip"
    case deflate = "deflate"
}


