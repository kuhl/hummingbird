//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2021 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

/// Object for handling requests.
///
/// Instead of passing a closure to the router you can provide an object it should try and
/// create before handling the request. This allows you to separate the extraction of data
/// from the request and the processing of the request. For example
/// ```
/// struct UpdateReminder: HBRouteHandler {
///     struct Request: Codable {
///         let description: String
///         let date: Date
///     }
///     let update: Request
///     let id: String
///
///     init(from request: HBRequest) throws {
///         self.update = try request.decode(as: Request.self)
///         self.id = try request.parameters.require("id")
///     }
///     func handle(request: HBRequest) -> EventLoopFuture<HTTPResponseStatus> {
///         let reminder = Reminder(id: id, update: update)
///         return reminder.update(on: request.db)
///             .map { _ in .ok }
///     }
/// }
/// ```
public protocol HBRouteHandler {
    associatedtype _Output
    init(from: HBRequest) throws
    func handle(request: HBRequest) async throws -> _Output
}

extension HBRouterMethods {
    /// Add path for `HBRouteHandler` that returns a value conforming to `HBResponseGenerator`
    @discardableResult public func on<Handler: HBRouteHandler, _Output: HBResponseGenerator>(
        _ path: String,
        method: HTTPMethod,
        body: HBBodyCollation = .collate,
        use handlerType: Handler.Type
    ) -> Self where Handler._Output == _Output {
        return self.on(path, method: method, body: body) { request -> _Output in
            let handler = try Handler(from: request)
            return try await handler.handle(request: request)
        }
    }

    /// GET path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func get<Handler: HBRouteHandler, _Output: HBResponseGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: Handler.Type
    ) -> Self where Handler._Output == _Output {
        return self.on(path, method: .GET, body: body, use: handler)
    }

    /// PUT path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func put<Handler: HBRouteHandler, _Output: HBResponseGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: Handler.Type
    ) -> Self where Handler._Output == _Output {
        return self.on(path, method: .PUT, body: body, use: handler)
    }

    /// POST path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func post<Handler: HBRouteHandler, _Output: HBResponseGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: Handler.Type
    ) -> Self where Handler._Output == _Output {
        return self.on(path, method: .POST, body: body, use: handler)
    }

    /// HEAD path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func head<Handler: HBRouteHandler, _Output: HBResponseGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: Handler.Type
    ) -> Self where Handler._Output == _Output {
        return self.on(path, method: .HEAD, body: body, use: handler)
    }

    /// DELETE path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func delete<Handler: HBRouteHandler, _Output: HBResponseGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: Handler.Type
    ) -> Self where Handler._Output == _Output {
        return self.on(path, method: .DELETE, body: body, use: handler)
    }

    /// PATCH path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func patch<Handler: HBRouteHandler, _Output: HBResponseGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: Handler.Type
    ) -> Self where Handler._Output == _Output {
        return self.on(path, method: .PATCH, body: body, use: handler)
    }
}
