//
//  MMNetworkMonitor.swift
//  MMNetwork
//
//  Created by 小君夜麻吕 on 2025/5/12.
//

///  本类是网络检测系统，底层依赖于 ``Network``中的 ``NWPathMonitor``进行检测
///  ``NWPathMonitor``不仅仅考虑了当前网络状态(wifi/蜂窝网络)，还综合考虑了网络权限

import Foundation
import Network
import Combine
public final class MMNetworkMonitor {
    
    //MARK: - public
    public static let shared = MMNetworkMonitor() //使用单例
    public let networkStatusSubject = PassthroughSubject<NWPath.Status, Never>() //订阅这个subject去监听网络变化，订阅的返回在主线程
    //开启监听
    public func startMonitor() {
        self.monitor.start(queue: .main)
    }
    
    //MARK: - private
    private let monitor = NWPathMonitor()
    private let _networkStatusSubject = PassthroughSubject<NWPath.Status, Never>() //内部去重专用
    private var cancellabel = Set<AnyCancellable>()
    private init() {
        self.privateDuplicates()
    }
    //内部防抖
    private func privateDuplicates() {
        self._networkStatusSubject
            .removeDuplicates() //去重
            .eraseToAnyPublisher()
            .sink { status in
                self.networkStatusSubject.send(status)
            }
            .store(in: &self.cancellabel)
        
        self.monitor.pathUpdateHandler = {newPath in
            self._networkStatusSubject.send(newPath.status)
        }
    }
}

