//
//  MMRequest.swift
//  MMNetwork
//
//  Created by 小君夜麻吕 on 2025/5/12.
//

import Foundation
import UIKit
import SmartCodable
import Combine
import Alamofire

public typealias RequestModifier = @Sendable (inout URLRequest) throws -> Void
public typealias ResponseModifier = @Sendable (Data) throws -> [String: Any]

/// 请求的主机地址
public struct MMNetworkConfig {
    /// 请求URL主机地址(在发出任何请求之前都应先设置此属性)
    public static var hostAddress: String = ""
}

/// (私有)全局的请求数组，当请求发出后，就进入到这个数组里，被这个数组进行强引用
private var requestTask: [MMRequest] = [MMRequest]()

/// 请求参数的基类
open class MMRequestModel: NSObject, Encodable { public override init() { super.init() } }
/// 响应返回的基类
open class MMResponseModel: NSObject, SmartCodable { required public override init() { super.init() } }

/// HTTP请求基类
open class MMRequest {
    
    /// 初始化方法
    /// - Parameter requestParameter: 传入一个请求参数，如果没有请求参数可以为空
    public required init(requestParameter: MMRequestModel?) {
        self.requestParameter = requestParameter
    }
    
    /// ``以下标记为open访问权限的属性都支持重写``
    /// 重试机制
    open var retry: RetryResult { .doNotRetry }
    /// 请求Path
    open var requestPath: String { "" }
    /// 请求方法
    open var requestMethod: HTTPMethod { .get }
    /// 请求头
    open var requestHeader: HTTPHeaders? { nil }
    /// 超时时间
    open var requestTimeoutInterval: TimeInterval { 10 }
    /// 请求参数序列化器
    open var requestParameterEncoder: ParameterEncoder { .json }
    /// 请求参数
    open var requestParameter: MMRequestModel?
    /// 当请求发起后，用户突然切换App至后台，此时请求结果还没回来
    /// 随后某个时间点(假设2秒后)，请求结果回来了，但是App此时处于后台状态，无法处理之后的逻辑``(比如请求成功更新UI，请求失败展示错误)``
    /// Alamofire在此情景下内部会发出 ``连接中断`` 的Error
    /// 换言之，请求是成功的，但是Alamofire却报了个``连接中断`` 的Error
    /// 但是在以前OC的AFNetwork框架中就不会出现这种问题
    /// 因为AFNetwork框架帮我们在每个任务发出之前都添加了后台任务，以向系统申请最多180秒的App后台额外运行时间
    /// 使得App虽然在后台，但是网络请求回来之后依旧能走完请求回来之后的操作.
    /// 而此属性是用来设置，当App处于后台时，``某个网络请求回来`` ``到`` ``处理完此网络请求回来之后的逻辑所需的时间(比如请求成功更新UI，请求失败展示错误)``
    /// 苹果也鼓励开发者在前台时，在请求发出之前也添加后台任务，因为不知道用户什么时候就把App切换到后台了
    /// 默认三秒，三秒后，此请求会去结束掉申请的后台任务，如果App没有额外申请的后台任务，那么App才进入到``冻结在内存``的状态
    /// 此属性不能大于180秒，因为App在后台能向系统申请到的最大普通任务执行时间就是180秒
    /// (这里指的是普通任务，一些特定的后台任务比如后台导航，后台听歌，后台语音通话等功能可以一直常驻后台)
    /// 如果超过180秒，系统发现你还没停止任务，就会认为你欺骗了它，然后系统就会Kill掉App
    /// 这也是为什么明明有些App刚进入后台没几分钟，用户也没开几个App，内存也充足，但是在180秒后再打开，又要重新启动
    /// 因为系统杀死了App(os:小子，竟敢骗我)
    /// 参考资料：https://developer.apple.com/documentation/uikit/uiapplication/beginbackgroundtask(expirationhandler:)
    open var backgroundTaskHandleTimeInterval: TimeInterval { 3.0 }
    /// 请求修改器
    open var requestModifier: RequestModifier? { nil }
    /// 响应修改器
    open var responseAdapter: ResponseModifier? { nil }
    
    /// 发送请求
    /// - Returns:返回的响应模型
    public func resume<T: MMResponseModel>() -> PassthroughSubject<T?, Error> {
        self.pushTask() //强引用请求
        let subject = PassthroughSubject<T?, Error>() //创建异步发送器
        //发出请求
        AF.request(MMNetworkConfig.hostAddress + self.requestPath,
                   method: self.requestMethod,
                   parameters: self.requestParameter,
                   encoder: self.requestParameterEncoder,
                   headers: self.requestHeader,
                   interceptor: self.requestAdapter,
                   requestModifier: self.requestModifier)
        .responseData { response in
            //解析请求返回
            switch response.result {
            case .success(let data): //请求成功
                if let responseAdapter = self.responseAdapter {
                    do {
                        let dict = try responseAdapter(data)
                        let model = T.deserialize(from: dict)
                        subject.send(model)
                        subject.send(completion: .finished)
                    } catch let error {
                        subject.send(completion: .failure(error))
                    }
                }else{
                    let model = T.deserialize(from: data)
                    subject.send(model)
                    subject.send(completion: .finished)
                }
            case .failure(let error): //请求失败
                subject.send(completion: .failure(error))
            }
            self.popTask()//去掉强引用
        }
        return subject
    }
    
    /// 请求适配器
    private lazy var requestAdapter = {
        MMRequestAdapter(retry: self.retry, requestTimeoutInterval: self.requestTimeoutInterval)
    }()
    /// 本次后台任务ID
    private var bgTaskId: UIBackgroundTaskIdentifier = .invalid
}

//MARK: - background task
extension MMRequest {
    
    //添加
    private func pushTask() {
        requestTask.append(self) //进去吧你
        self.bgTaskId = UIApplication.shared.beginBackgroundTask() //开启后台任务
    }
    
    /// 移除
    private func popTask() {
        DispatchQueue.main.asyncAfter(deadline: .now() + self.backgroundTaskHandleTimeInterval) { //给返回过去的结果一些处理时间
            let bgTaskId = self.bgTaskId //创建一个临时变量给到任务ID，不然直接写下面这一句↓，self就直接GG了，怕拿不到任务ID了
            requestTask.removeAll(where: { $0.bgTaskId == self.bgTaskId }) //移除后，self正式GG，走deinit方法
            UIApplication.shared.endBackgroundTask(bgTaskId) //结束后台任务
        }
    }
}

