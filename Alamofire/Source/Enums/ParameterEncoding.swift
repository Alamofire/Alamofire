// ParameterEncoding.swift
//
// Copyright (c) 2014 Alamofire (http://alamofire.org)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation

public enum ParameterEncoding {
    
    case URL
    case JSON(options: NSJSONWritingOptions)
    case PropertyList(format: NSPropertyListFormat, options: NSPropertyListWriteOptions)
    
    public func encode(request: NSURLRequest, parameters: [String: AnyObject]?) -> (NSURLRequest, NSError?) {
        if parameters == nil {
            return (request, nil)
        }
        
        var mutableRequest: NSMutableURLRequest! = request.mutableCopy() as NSMutableURLRequest
        var error: NSError? = nil
        
        switch self {
        case .URL:
            func query(parameters: [String: AnyObject]) -> String! {
                func queryComponents(key: String, value: AnyObject) -> [(String, String)] {
                    func dictionaryQueryComponents(key: String, dictionary: [String: AnyObject]) -> [(String, String)] {
                        var components: [(String, String)] = []
                        for (nestedKey, value) in dictionary {
                            components += queryComponents("\(key)[\(nestedKey)]", value)
                        }
                        
                        return components
                    }
                    
                    func arrayQueryComponents(key: String, array: [AnyObject]) -> [(String, String)] {
                        var components: [(String, String)] = []
                        for value in array {
                            components += queryComponents("\(key)[]", value)
                        }
                        
                        return components
                    }
                    
                    var components: [(String, String)] = []
                    if let dictionary = value as? [String: AnyObject] {
                        components += dictionaryQueryComponents(key, dictionary)
                    } else if let array = value as? [AnyObject] {
                        components += arrayQueryComponents(key, array)
                    } else {
                        let tuple = (key, "\(value)")
                        components.append(tuple)
                    }
                    
                    return components
                }
                
                var components: [(String, String)] = []
                for key in sorted(Array(parameters.keys), <) {
                    let value: AnyObject! = parameters[key]
                    components += queryComponents(key, value)
                }
                
                return join("&", components.map{"\($0)=\($1)"} as [String])
            }
            
            func encodesParametersInURL(method: Method) -> Bool {
                switch method {
                case .GET, .HEAD, .DELETE:
                    return true
                default:
                    return false
                }
            }
            
            if encodesParametersInURL(Method.fromRaw(request.HTTPMethod)!) {
                let URLComponents = NSURLComponents(URL: mutableRequest.URL, resolvingAgainstBaseURL: false)
                URLComponents.query = (URLComponents.query ? URLComponents.query + "&" : "") + query(parameters!)
                mutableRequest.URL = URLComponents.URL
            } else {
                if !mutableRequest.valueForHTTPHeaderField("Content-Type") {
                    mutableRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                }
                
                mutableRequest.HTTPBody = query(parameters!).dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
            }
            
        case .JSON(let options):
            let data = NSJSONSerialization.dataWithJSONObject(parameters, options: options, error: &error)
            
            if data != nil {
                let charset = CFStringConvertEncodingToIANACharSetName(CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding))
                mutableRequest.setValue("application/json; charset=\(charset)", forHTTPHeaderField: "Content-Type")
                mutableRequest.HTTPBody = data
            }
        case .PropertyList(let (format, options)):
            let data = NSPropertyListSerialization.dataWithPropertyList(parameters, format: format, options: options, error: &error)
            
            if data != nil {
                let charset = CFStringConvertEncodingToIANACharSetName(CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
                mutableRequest.setValue("application/x-plist; charset=\(charset)", forHTTPHeaderField: "Content-Type")
                mutableRequest.HTTPBody = data
            }
        }
        
        return (mutableRequest, error)
    }
    
}
