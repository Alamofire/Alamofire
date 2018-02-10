//
//  SoapRequestManager.swift
//  Alamofire iOS
//
//  Created by Shakeeb Mancheri on 10/02/18.
//  Copyright © 2018 Alamofire. All rights reserved.
//


class SoapRequestManager {
    
    private var methodName  : String
    private var namespace : String
    private var parameters : Parameters?
    private var soapBody : String = ""
    private var soapHeader : [String:String]?
    
    init(methodName : String,namespace: String,parameters: Parameters? = nil) {
        self.methodName = methodName
        self.namespace = namespace
        self.parameters = parameters
    }
    public func getBody() -> String {
        return soapBody
    }
    
    public func getHeaders()-> [String : String]? {
        return soapHeader
    }
    public func generateSoapRequestElements() {
        var soapString = ""
        if let parameters = parameters,parameters.count > 0 {
            var paramString : String = ""
            for (parameterkey,value) in parameters {
                paramString += getParameterSetString(parameterkey, value: String(describing: value))
            }
            soapString = "\(getStartStringWithMethod())\(paramString)\(self.endStringWithMethod())"
        }
        else {
            soapString = self.getNoParammethod()
        }
        self.soapBody = soapString
        self.soapHeader = ["SOAPAction" : "\(self.namespace)/\(self.methodName)", "Content-Type" : "text/xml; charset=utf-8", "Content-Length" : "\(soapString.count)"]
    }
    
    private func getStartStringWithMethod() -> String {
        let startString = "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<soap:Envelope xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\">\n<soap:Body>\n<GetCitiesByCountry xmlns=\"\(namespace)\">"
        return startString
    }
    private func endStringWithMethod() -> String{
        let endString = "</\(self.methodName)>\n</soap:Body>\n</soap:Envelope>"
        return endString
    }
    private func getNoParammethod() -> String {
        let startString = "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<soap:Envelope xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\">\n<soap:Body>\n<\(self.methodName) xmlns=\"http://tempuri.org/\"/>\n</soap:Body>\n</soap:Envelope>"
        return startString
    }
    private func getParameterSetString(_ parameterName : String , value: String) -> String {
        let setParamString = "<\(parameterName)>\(value)</\(parameterName)>\n"
        return setParamString
    }
}
