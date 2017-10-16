import Foundation
import Result

/// A Moya Plugin receives callbacks to perform side effects wherever a request is sent or received.
///
/// for example, a plugin may be used to
///     - log network requests
///     - hide and show a network activity indicator
///     - inject additional information into a request


//Authentication插件 (CredentialsPlugin.swift)。 HTTP认证的插件。
//Logging插件(NetworkLoggerPlugin.swift)。在调试是，输入网络请求的调试信息到控制台
//Network Activity Indicator插件（NetworkActivityPlugin.swift）。可以用这个插件来显示网络菊花


public protocol PluginType {
    /// Called to modify a request before sending
    func prepare(_ request: URLRequest, target: TargetType) -> URLRequest

    /// Called immediately before a request is sent over the network (or stubbed).
    func willSend(_ request: RequestType, target: TargetType)

    /// Called after a response has been received, but before the MoyaProvider has invoked its completion handler.
    func didReceive(_ result: Result<Moya.Response, MoyaError>, target: TargetType)

    /// Called to modify a result before completion
    func process(_ result: Result<Moya.Response, MoyaError>, target: TargetType) -> Result<Moya.Response, MoyaError>
}


// 协议的默认实现
public extension PluginType {
    func prepare(_ request: URLRequest, target: TargetType) -> URLRequest { return request }
    func willSend(_ request: RequestType, target: TargetType) { }
    func didReceive(_ result: Result<Moya.Response, MoyaError>, target: TargetType) { }
    func process(_ result: Result<Moya.Response, MoyaError>, target: TargetType) -> Result<Moya.Response, MoyaError> { return result }
}

/// Request type used by `willSend` plugin function.
/// 请求前的 配置
public protocol RequestType {

    // Note:
    //
    // We use this protocol instead of the Alamofire request to avoid leaking that abstraction.
    // A plugin should not know about Alamofire at all.
    
    /// 使用这个协议去避免对外泄露 Alamofire
    /// 插件 并不知道 Alamofire 的存在
    /// Retrieve an `NSURLRequest` representation.
    var request: URLRequest? { get }

    /// Authenticates the request with a username and password.
    /// 用户名和密码验证
    func authenticate(user: String, password: String, persistence: URLCredential.Persistence) -> Self

    /// Authenticates the request with an `NSURLCredential` instance.
    /// 证书验证
    func authenticate(usingCredential credential: URLCredential) -> Self
}
