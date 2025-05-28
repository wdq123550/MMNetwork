//
//  MMResponseAdapter.swift
//  MMNetwork
//
//  Created by 小君夜麻吕 on 2025/5/28.
//  响应适配器，返回的一些公共逻辑部分可以扔这里处理

import UIKit

public protocol MMResponseAdapterProtocol {
    func handleResponse(_ data: Data) throws -> [String: Any]?
}
