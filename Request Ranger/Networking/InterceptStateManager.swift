import Foundation

class InterceptStateManager {
    private var isInterceptEnabled = false
    static let shared = InterceptStateManager()
    
    init(){}
    
    func shouldIntercept() -> Bool {
        return isInterceptEnabled
    }
    
    func setShouldIntercept(state: Bool) {
        isInterceptEnabled = state
    }
}
