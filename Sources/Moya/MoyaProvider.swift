import Foundation
import Result

/// Closure to be executed when a request has completed.
/// 闭包: 当网络请求结束后, 处理请求的结果 或者错误
public typealias Completion = (_ result: Result<Moya.Response, MoyaError>) -> Void

/// Closure to be executed when progress changes.
/// 闭包: 在网络响应过程中 做一些处理
public typealias ProgressBlock = (_ progress: ProgressResponse) -> Void

/// 响应过程. 进度条等 接收响应数据的过程.
public struct ProgressResponse {
    public let response: Response?
    public let progressObject: Progress?

    public init(progress: Progress? = nil, response: Response? = nil) {
        self.progressObject = progress
        self.response = response
    }

    public var progress: Double {
        return progressObject?.fractionCompleted ?? 1.0
    }

    public var completed: Bool {
        return progress == 1.0 && response != nil
    }
}

/// 协议, 网络请求过程 方法
public protocol MoyaProviderType: class {
    associatedtype Target: TargetType

    func request(_ target: Target, callbackQueue: DispatchQueue?, progress: Moya.ProgressBlock?, completion: @escaping Moya.Completion) -> Cancellable
}

/// Request provider class. Requests should be made through this class only.
/// 所有网络请求 都是由这个类发起的
open class MoyaProvider<Target: TargetType>: MoyaProviderType {

    
    /// Closure that defines the endpoints for the provider.
    /// 闭包: Target 转 Endpoint
    public typealias EndpointClosure = (Target) -> Endpoint<Target>

    /// Closure that decides if and what request should be performed
    /// 闭包 :  处理响应结果的. 错误处理
    public typealias RequestResultClosure = (Result<URLRequest, MoyaError>) -> Void

    /// Closure that resolves an `Endpoint` into a `RequestResult`.
    /// 把 Endpoint 转 RequestResult
    public typealias RequestClosure = (Endpoint<Target>, @escaping RequestResultClosure) -> Void

    /// Closure that decides if/how a request should be stubbed.
    /// 测试数据 返回方式
    public typealias StubClosure = (Target) -> Moya.StubBehavior
    
    open let endpointClosure: EndpointClosure
    open let requestClosure: RequestClosure
    open let stubClosure: StubClosure
    open let manager: Manager

    /// A list of plugins
    /// e.g. for logging, network activity indicator or credentials
    /// 插件 类型, 如 日志打印, 网络指示器,证书
    open let plugins: [PluginType]
    /// 这个应该是 线程冲突吧
    open let trackInflights: Bool
    /// 应该是  请求冲突
    open internal(set) var inflightRequests: [Endpoint<Target>: [Moya.Completion]] = [:]

    /// Propagated to Alamofire as callback queue. If nil - the Alamofire default (as of their API in 2017 - the main queue) will be used.
    /// 传递到 Alamofire 中的 回调队列, 如果为空 则使用默认的队列
    let callbackQueue: DispatchQueue?

    /// Initializes a provider.
    public init(endpointClosure: @escaping EndpointClosure = MoyaProvider.defaultEndpointMapping,
                requestClosure: @escaping RequestClosure = MoyaProvider.defaultRequestMapping,
                stubClosure: @escaping StubClosure = MoyaProvider.neverStub,
                callbackQueue: DispatchQueue? = nil,
                manager: Manager = MoyaProvider<Target>.defaultAlamofireManager(),
                plugins: [PluginType] = [],
                trackInflights: Bool = false) {

        self.endpointClosure = endpointClosure
        self.requestClosure = requestClosure
        self.stubClosure = stubClosure
        self.manager = manager
        self.plugins = plugins
        self.trackInflights = trackInflights
        self.callbackQueue = callbackQueue
    }

    /// Returns an `Endpoint` based on the token, method, and parameters by invoking the `endpointClosure`.
    open func endpoint(_ token: Target) -> Endpoint<Target> {
        return endpointClosure(token)
    }

    /// Designated request-making method. Returns a `Cancellable` token to cancel the request later.
    @discardableResult /// 忽略返回值
    
    open func request(_ target: Target,
                      callbackQueue: DispatchQueue? = .none,
                      progress: ProgressBlock? = .none,
                      completion: @escaping Completion) -> Cancellable {

        let callbackQueue = callbackQueue ?? self.callbackQueue
        return requestNormal(target, callbackQueue: callbackQueue, progress: progress, completion: completion)
    }

    /// When overriding this method, take care to `notifyPluginsOfImpendingStub` and to perform the stub using the `createStubFunction` method.
    /// Note: this was previously in an extension, however it must be in the original class declaration to allow subclasses to override.
    @discardableResult
    open func stubRequest(_ target: Target, request: URLRequest, callbackQueue: DispatchQueue?, completion: @escaping Moya.Completion, endpoint: Endpoint<Target>, stubBehavior: Moya.StubBehavior) -> CancellableToken {
        let callbackQueue = callbackQueue ?? self.callbackQueue
        let cancellableToken = CancellableToken { }
        notifyPluginsOfImpendingStub(for: request, target: target)
        let plugins = self.plugins
        let stub: () -> Void = createStubFunction(cancellableToken, forTarget: target, withCompletion: completion, endpoint: endpoint, plugins: plugins, request: request)
        switch stubBehavior {
        case .immediate:
            switch callbackQueue {
            case .none:
                stub()
            case .some(let callbackQueue):
                callbackQueue.async(execute: stub)
            }
        case .delayed(let delay):
            let killTimeOffset = Int64(CDouble(delay) * CDouble(NSEC_PER_SEC))
            let killTime = DispatchTime.now() + Double(killTimeOffset) / Double(NSEC_PER_SEC)
            (callbackQueue ?? DispatchQueue.main).asyncAfter(deadline: killTime) {
                stub()
            }
        case .never:
            fatalError("Method called to stub request when stubbing is disabled.")
        }

        return cancellableToken
    }
}

/// Mark: Stubbing

/// Controls how stub responses are returned.
/// 控制测试数据 (响应数据) 是如何返回的
public enum StubBehavior {

    /// Do not stub.
    /// 不适用 测试数据
    case never

    /// Return a response immediately.
    /// 立刻返回
    case immediate

    /// Return a response after a delay.
    /// 延迟返回
    case delayed(seconds: TimeInterval)
}

public extension MoyaProvider {

    // Swift won't let us put the StubBehavior enum inside the provider class, so we'll
    // at least add some class functions to allow easy access to common stubbing closures.

    public final class func neverStub(_: Target) -> Moya.StubBehavior {
        return .never
    }

    public final class func immediatelyStub(_: Target) -> Moya.StubBehavior {
        return .immediate
    }

    public final class func delayedStub(_ seconds: TimeInterval) -> (Target) -> Moya.StubBehavior {
        return { _ in return .delayed(seconds: seconds) }
    }
}

/// 将 respoonse 转化为 result 
public func convertResponseToResult(_ response: HTTPURLResponse?, request: URLRequest?, data: Data?, error: Swift.Error?) ->
    Result<Moya.Response, MoyaError> {
        switch (response, data, error) {
        case let (.some(response), data, .none):
            let response = Moya.Response(statusCode: response.statusCode, data: data ?? Data(), request: request, response: response)
            return .success(response)
        case let (.some(response), _, .some(error)):
            let response = Moya.Response(statusCode: response.statusCode, data: data ?? Data(), request: request, response: response)
            let error = MoyaError.underlying(error, response)
            return .failure(error)
        case let (_, _, .some(error)):
            let error = MoyaError.underlying(error, nil)
            return .failure(error)
        default:
            let error = MoyaError.underlying(NSError(domain: NSURLErrorDomain, code: NSURLErrorUnknown, userInfo: nil), nil)
            return .failure(error)
        }
}
