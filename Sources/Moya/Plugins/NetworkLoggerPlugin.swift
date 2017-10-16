import Foundation
import Result

/// Logs network activity (outgoing requests and incoming responses).
/// 网络请求日志 请求日志, 响应日志
/// 不可继承
public final class NetworkLoggerPlugin: PluginType {
    /// log id
    fileprivate let loggerId = "Moya_Logger"
    /// 日期
    fileprivate let dateFormatString = "dd/MM/yyyy HH:mm:ss"
    /// 日期格式
    fileprivate let dateFormatter = DateFormatter()
    /// 分隔符
    fileprivate let separator = ", "
    /// 结尾
    fileprivate let terminator = "\n"
    /// url 结尾
    fileprivate let cURLTerminator = "\\\n"
    /// 输出
    fileprivate let output: (_ separator: String, _ terminator: String, _ items: Any...) -> Void
    /// 请求数据
    fileprivate let requestDataFormatter: ((Data) -> (String))?
    /// 响应数据 data 转化 为 特定格式的 data
    fileprivate let responseDataFormatter: ((Data) -> (Data))?

    /// If true, also logs response body data.
    /// 冗长性, 打开的话, 会打印响应体数据
    public let isVerbose: Bool
    /// 没看懂?
    public let cURL: Bool

    public init(verbose: Bool = false, cURL: Bool = false, output: ((_ separator: String, _ terminator: String, _ items: Any...) -> Void)? = nil, requestDataFormatter: ((Data) -> (String))? = nil, responseDataFormatter: ((Data) -> (Data))? = nil) {
        self.cURL = cURL
        self.isVerbose = verbose
        /// 输出格式定制
        self.output = output ?? NetworkLoggerPlugin.reversedPrint
        /// 配置请求数据闭包
        self.requestDataFormatter = requestDataFormatter
        /// 配置响应数据闭包
        self.responseDataFormatter = responseDataFormatter
    }

    /// 请求前 打印
    public func willSend(_ request: RequestType, target: TargetType) {
        if let request = request as? CustomDebugStringConvertible, cURL {
            output(separator, terminator, request.debugDescription)
            return
        }
        outputItems(logNetworkRequest(request.request as URLRequest?))
    }

    /// 网络请求 接收到 数据打印
    public func didReceive(_ result: Result<Moya.Response, MoyaError>, target: TargetType) {
        if case .success(let response) = result {
            outputItems(logNetworkResponse(response.response, data: response.data, target: target))
        } else {
            outputItems(logNetworkResponse(nil, data: nil, target: target))
        }
    }

    /// 开始打印
    fileprivate func outputItems(_ items: [String]) {
        if isVerbose {
            items.forEach { output(separator, terminator, $0) }
        } else {
            output(separator, terminator, items)
        }
    }
}

private extension NetworkLoggerPlugin {

    /// 时间, 扩展可以有变量?
    var date: String {
        dateFormatter.dateFormat = dateFormatString
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        return dateFormatter.string(from: Date())
    }

    /// 打印格式
    func format(_ loggerId: String, date: String, identifier: String, message: String) -> String {
        return "\(loggerId): [\(date)] \(identifier): \(message)"
    }

    /// 打印 request 信息
    func logNetworkRequest(_ request: URLRequest?) -> [String] {

        // 数组 string 元素
        var output = [String]()
        // 数组中添加元素
        // loggerId data identifier message
        output += [format(loggerId, date: date, identifier: "Request", message: request?.description ?? "(invalid request)")]

        // http 请求头部
        if let headers = request?.allHTTPHeaderFields {
            output += [format(loggerId, date: date, identifier: "Request Headers", message: headers.description)]
        }

        if let bodyStream = request?.httpBodyStream {
            output += [format(loggerId, date: date, identifier: "Request Body Stream", message: bodyStream.description)]
        }

        if let httpMethod = request?.httpMethod {
            output += [format(loggerId, date: date, identifier: "HTTP Request Method", message: httpMethod)]
        }

        if let body = request?.httpBody, let stringOutput = requestDataFormatter?(body) ?? String(data: body, encoding: .utf8), isVerbose {
            output += [format(loggerId, date: date, identifier: "Request Body", message: stringOutput)]
        }

        return output
    }

    /// 打印响应结果
    func logNetworkResponse(_ response: HTTPURLResponse?, data: Data?, target: TargetType) -> [String] {
        guard let response = response else {
           return [format(loggerId, date: date, identifier: "Response", message: "Received empty network response for \(target).")]
        }

        var output = [String]()

        output += [format(loggerId, date: date, identifier: "Response", message: response.description)]

        //String(data: <#T##Data#>, encoding: <#T##String.Encoding#>)
        if let data = data, let stringData = String(data: responseDataFormatter?(data) ?? data, encoding: String.Encoding.utf8), isVerbose {
            output += [stringData]
        }

        return output
    }
}

/// 输出格式定制
///fileprivate 该文件内部文件
fileprivate extension NetworkLoggerPlugin {
    static func reversedPrint(_ separator: String, terminator: String, items: Any...) {
        for item in items {
            print(item, separator: separator, terminator: terminator)
        }
    }
}
