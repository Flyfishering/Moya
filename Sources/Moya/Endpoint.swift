import Foundation

/// Used for stubbing responses.
/// 应该是测试用的吧
public enum EndpointSampleResponse {

    /// The network returned a response, including status code and data.
    case networkResponse(Int, Data)

    /// The network returned response which can be fully customized.
    case response(HTTPURLResponse, Data)

    /// The network failed to send the request, or failed to retrieve a response (eg a timeout).
    case networkError(NSError)
}

/// Class for reifying a target of the `Target` enum unto a concrete `Endpoint`.
/// 把Target 转化为 Endpoint
open class Endpoint<Target> {
    /// 枚举类型 用来做测试响应数据
    public typealias SampleResponseClosure = () -> EndpointSampleResponse
    /// url
    open let url: String
    /// 枚举类型 用来做测试响应数据
    open let sampleResponseClosure: SampleResponseClosure
    // http 方法
    open let method: Moya.Method
    // 网络任务
    open let task: Task
    open let httpHeaderFields: [String: String]?

    /// Main initializer for `Endpoint`.
    public init(url: String,
                sampleResponseClosure: @escaping SampleResponseClosure,
                method: Moya.Method = Moya.Method.get,
                task: Task = .requestPlain,
                httpHeaderFields: [String: String]? = nil) {

        self.url = url
        self.sampleResponseClosure = sampleResponseClosure
        self.method = method
        self.task = task
        self.httpHeaderFields = httpHeaderFields
    }

    /// Convenience method for creating a new `Endpoint` with the same properties as the receiver, but with added HTTP header fields.
    //  添加新的 httpHeaderFields
    open func adding(newHTTPHeaderFields: [String: String]) -> Endpoint<Target> {
        return Endpoint(url: url, sampleResponseClosure: sampleResponseClosure, method: method, task: task, httpHeaderFields: add(httpHeaderFields: newHTTPHeaderFields))
    }

    /// Convenience method for creating a new `Endpoint` with the same properties as the receiver, but with replaced `task` parameter.
    /// 替换网络任务 task
    open func replacing(task: Task) -> Endpoint<Target> {
        return Endpoint(url: url, sampleResponseClosure: sampleResponseClosure, method: method, task: task, httpHeaderFields: httpHeaderFields)
    }

    //  添加新的 httpHeaderFields
    fileprivate func add(httpHeaderFields headers: [String: String]?) -> [String: String]? {
        /// 当新的 httpHeaderFields 为空, 返回旧的 self.httpHeaderFields
        guard let unwrappedHeaders = headers, unwrappedHeaders.isEmpty == false else {
            return self.httpHeaderFields
        }

        ///
        var newHTTPHeaderFields = self.httpHeaderFields ?? [:]
        unwrappedHeaders.forEach { key, value in
            // 这种写法 可以给字典添加 key-value
            newHTTPHeaderFields[key] = value
        }
        return newHTTPHeaderFields
    }
}

/// Extension for converting an `Endpoint` into an optional `URLRequest`.
/// 转化 Endpoint 为  URLRequest
extension Endpoint {
    
    /// Returns the `Endpoint` converted to a `URLRequest` if valid. Returns `nil` otherwise.
    /// 转化 Endpoint 为  URLRequest, 如果是非法的Endpoint 返回nil
    public var urlRequest: URLRequest? {
       
        guard let requestURL = Foundation.URL(string: url) else { return nil }

        var request = URLRequest(url: requestURL)
        request.httpMethod = method.rawValue
        request.allHTTPHeaderFields = httpHeaderFields

        switch task {
        case .requestPlain, .uploadFile, .uploadMultipart, .downloadDestination:
            return request
        case .requestData(let data):
            request.httpBody = data
            return request
        case let .requestParameters(parameters, parameterEncoding):
            return try? parameterEncoding.encode(request, with: parameters)
        case let .uploadCompositeMultipart(_, urlParameters):
            return try? URLEncoding(destination: .queryString).encode(request, with: urlParameters)
        case let .downloadParameters(parameters, parameterEncoding, _):
            return try? parameterEncoding.encode(request, with: parameters)
        case let .requestCompositeData(bodyData: bodyData, urlParameters: urlParameters):
            request.httpBody = bodyData
            return try? URLEncoding(destination: .queryString).encode(request, with: urlParameters)
        case let .requestCompositeParameters(bodyParameters: bodyParameters, bodyEncoding: bodyParameterEncoding, urlParameters: urlParameters):
            if bodyParameterEncoding is URLEncoding { fatalError("URLEncoding is disallowed as bodyEncoding.") }
            guard let bodyfulRequest = try? bodyParameterEncoding.encode(request, with: bodyParameters) else { return nil }
            return try? URLEncoding(destination: .queryString).encode(bodyfulRequest, with: urlParameters)
        }
    }
}

/// Required for using `Endpoint` as a key type in a `Dictionary`.
extension Endpoint: Equatable, Hashable {
    /// 哈希值
    public var hashValue: Int {
        return urlRequest?.hashValue ?? url.hashValue
    }

    /// 定义 方法 ==
    public static func == <T>(lhs: Endpoint<T>, rhs: Endpoint<T>) -> Bool {
        if lhs.urlRequest != nil, rhs.urlRequest == nil { return false }
        if lhs.urlRequest == nil, rhs.urlRequest != nil { return false }
        if lhs.urlRequest == nil, rhs.urlRequest == nil { return lhs.hashValue == rhs.hashValue }
        return (lhs.urlRequest == rhs.urlRequest)
    }
}
