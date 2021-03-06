import Foundation

/// These functions are default mappings to `MoyaProvider`'s properties: endpoints, requests, manager, etc.
public extension MoyaProvider {
    
    // 类方法, 不可继承
    // 使用 Target  配置 Endpoint
    public final class func defaultEndpointMapping(for target: Target) -> Endpoint<Target> {
        return Endpoint(
            url: URL(target: target).absoluteString,
            sampleResponseClosure: { .networkResponse(200, target.sampleData) },
            method: target.method,
            task: target.task,
            httpHeaderFields: target.headers
        )
    }

    public final class func defaultRequestMapping(for endpoint: Endpoint<Target>, closure: RequestResultClosure) {
        if let urlRequest = endpoint.urlRequest {
            closure(.success(urlRequest))
            //(Result<URLRequest, MoyaError>) -> Void
        } else {
            closure(.failure(MoyaError.requestMapping(endpoint.url)))
        }
    }

    public final class func defaultAlamofireManager() -> Manager {
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = Manager.defaultHTTPHeaders

        let manager = Manager(configuration: configuration)
        manager.startRequestsImmediately = false
        return manager
    }
}
