/// Protocol to define the opaque type returned from a request
/// 是否可以取消 (取消网络请求)
public protocol Cancellable {
    var isCancelled: Bool { get }
    func cancel()
}

/// 取消能力 (封装) 为什么要再封装一层. 为什么不直接使用 SimpleCancellable
internal class CancellableWrapper: Cancellable {
    
    /// 这个是真正的取消对象
    internal var innerCancellable: Cancellable = SimpleCancellable()
    /// 不能再外部修改 这个变量. 只能通过 方法 - `cancel`
    var isCancelled: Bool { return innerCancellable.isCancelled }

    internal func cancel() {
        innerCancellable.cancel()
    }
}

internal class SimpleCancellable: Cancellable {
    // 初始 阶段 取消状态: 不能取消
    var isCancelled = false
    // 取消操作
    func cancel() {
        // 可取消
        isCancelled = true
    }
}
