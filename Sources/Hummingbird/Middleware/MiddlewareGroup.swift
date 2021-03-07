import NIO

/// Group of middleware that can be used to create a responder chain. Each middleware calls the next one
public class HBMiddlewareGroup {
    var middlewares: [HBMiddleware]

    public init() {
        self.middlewares = []
    }

    /// Add middleware to group
    public func add(_ middleware: HBMiddleware) {
        self.middlewares.append(middleware)
    }

    /// Construct responder chain from this middleware group
    /// - Parameter finalResponder: The responder the last middleware calls
    /// - Returns: Responder chain
    public func constructResponder(finalResponder: HBResponder, runPrePostProcess: Bool = true) -> HBRootResponder {
        var currentResponser = finalResponder
        for i in (0..<self.middlewares.count).reversed() {
            let responder = MiddlewareResponder(middleware: middlewares[i], next: currentResponser)
            currentResponser = responder
        }
        return HBRootResponder(middlewares: middlewares, firstResponder: currentResponser, runPrePostProcess: runPrePostProcess)
    }
}

public struct HBRootResponder: HBResponder {
    var preProcessMiddlewares: [HBPreProcessMiddleware]
    var postProcessMiddlewares: [HBPostProcessMiddleware]
    var firstResponder: HBResponder
    var runPrePostProcess: Bool

    init(middlewares: [HBMiddleware], firstResponder: HBResponder, runPrePostProcess: Bool = true) {
        self.preProcessMiddlewares = middlewares.compactMap { $0 as? HBPreProcessMiddleware }
        self.postProcessMiddlewares = middlewares.reversed().compactMap { $0 as? HBPostProcessMiddleware }
        self.firstResponder = firstResponder
        self.runPrePostProcess = runPrePostProcess
    }

    public func respond(to request: HBRequest) -> EventLoopFuture<HBResponse> {
        if runPrePostProcess {
            for middleware in preProcessMiddlewares {
                if let response = middleware.preProcess(request: request) {
                    return request.success(response)
                }
            }
            if postProcessMiddlewares.count > 0 {
                return firstResponder.respond(to: request).map { response in
                    for middleware in postProcessMiddlewares {
                        middleware.postProcess(response: response, for: request)
                    }
                    return response
                }
            } else {
                return firstResponder.respond(to: request)
            }
        } else {
            return firstResponder.respond(to: request)
        }
    }

    func preProcess(request: HBRequest) -> HBResponse? {
        for middleware in preProcessMiddlewares {
            if let response = middleware.preProcess(request: request) {
                return response
            }
        }
        return nil
    }

    func postProcess(response: HBResponse, for request: HBRequest) {
        for middleware in postProcessMiddlewares {
            middleware.postProcess(response: response, for: request)
        }
    }
}
