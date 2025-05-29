//
//  MMCompositeEncoding.swift
//  MMNetwork
//
//  Created by 小君夜麻吕 on 2025/5/29.
//

import Foundation
import Alamofire

// 混合编码
public struct MMCompositeEncoding: ParameterEncoding {
    let urlParameters: Parameters
    let bodyData: Data
    public init(urlParameters: Parameters, bodyData: Data) {
        self.urlParameters = urlParameters
        self.bodyData = bodyData
    }
    public func encode(_ urlRequest: URLRequestConvertible, with parameters: Parameters?) throws -> URLRequest {
        var request = try URLEncoding().encode(urlRequest, with: urlParameters)
        request.httpBody = bodyData
        return request
    }
}
