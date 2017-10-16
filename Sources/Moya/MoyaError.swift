import Foundation
/// 错误枚举型
public enum MoyaError: Swift.Error {

    /// Indicates a response failed to map to an image.
    /// 映射图片失败
    case imageMapping(Response)

    /// Indicates a response failed to map to a JSON structure.
    /// 映射 json 失败
    case jsonMapping(Response)

    /// Indicates a response failed to map to a String.
    /// 映射 给 string 失败
    case stringMapping(Response)
    
    /// Indicates a response failed with an invalid HTTP status code.
    /// http 状态码 得到的错误
    case statusCode(Response)

    /// Indicates a response failed due to an underlying `Error`.
    /// 因为别的 基础错误
    case underlying(Swift.Error, Response?)

    /// Indicates that an `Endpoint` failed to map to a `URLRequest`.
    /// 映射 Endpoint 到 URLRequest 错误
    case requestMapping(String)
}

/// MoyaError 响应值
public extension MoyaError {
    /// Depending on error type, returns a `Response` object.
    var response: Moya.Response? {
        switch self {
        case .imageMapping(let response): return response
        case .jsonMapping(let response): return response
        case .stringMapping(let response): return response
        case .statusCode(let response): return response
        case .underlying(_, let response): return response
        case .requestMapping: return nil
        }
    }
}

// MARK: - Error Descriptions
/// MoyaError 的错误信息打印
extension MoyaError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .imageMapping:
            return "Failed to map data to an Image."
        case .jsonMapping:
            return "Failed to map data to JSON."
        case .stringMapping:
            return "Failed to map data to a String."
        case .statusCode:
            return "Status code didn't fall within the given range."
        case .requestMapping:
            return "Failed to map Endpoint to a URLRequest."
        case .underlying(let error, _):
            return error.localizedDescription
        }
    }
}
