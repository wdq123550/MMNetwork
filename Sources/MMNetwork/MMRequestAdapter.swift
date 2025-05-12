//
//  MMRequestAdapter.swift
//  MMNetwork
//
//  Created by 小君夜麻吕 on 2025/5/12.
//

import Foundation
import Alamofire

/// 请求适配器(发出请求之前会进来这里对请求进行额外的设置)
public final class MMRequestAdapter: RequestInterceptor, @unchecked Sendable{
    
    let retry: RetryResult //重试机制
    let requestTimeoutInterval: TimeInterval //超时时间
    
    // init
    init(retry: RetryResult, requestTimeoutInterval: TimeInterval) {
        self.retry = retry
        self.requestTimeoutInterval = requestTimeoutInterval
    }
    
    //请求适配器
    public func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, any Error>) -> Void) {
        var newRequest = urlRequest
        newRequest.timeoutInterval = self.requestTimeoutInterval //设置超时时间
        completion(.success(newRequest))
    }
    
    //请求重试器
    public func retry(_ request: Request, for session: Session, dueTo error: any Error, completion: @escaping (RetryResult) -> Void) {
        completion(self.retry) //设置重试策略
    }
}
