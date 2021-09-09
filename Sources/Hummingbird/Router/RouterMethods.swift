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

import NIO
import NIOHTTP1

public enum HBBodyCollation {
    case collate
    case stream
}

public protocol HBRouterMethods {
    /// Add path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult func on<Output: HBResponseGenerator>(
        _ path: String,
        method: HTTPMethod,
        body: HBBodyCollation,
        use: @escaping (HBRequest) async throws -> Output
    ) -> Self

    /// add group
    func group(_ path: String) -> HBRouterGroup
}

extension HBRouterMethods {
    /// GET path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func get<Output: HBResponseGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: @escaping (HBRequest) async throws -> Output
    ) -> Self {
        return on(path, method: .GET, body: body, use: handler)
    }

    /// PUT path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func put<Output: HBResponseGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: @escaping (HBRequest) async throws -> Output
    ) -> Self {
        return on(path, method: .PUT, body: body, use: handler)
    }

    /// POST path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func post<Output: HBResponseGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: @escaping (HBRequest) async throws -> Output
    ) -> Self {
        return on(path, method: .POST, body: body, use: handler)
    }

    /// HEAD path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func head<Output: HBResponseGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: @escaping (HBRequest) async throws -> Output
    ) -> Self {
        return on(path, method: .HEAD, body: body, use: handler)
    }

    /// DELETE path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func delete<Output: HBResponseGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: @escaping (HBRequest) async throws -> Output
    ) -> Self {
        return on(path, method: .DELETE, body: body, use: handler)
    }

    /// PATCH path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func patch<Output: HBResponseGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: @escaping (HBRequest) async throws -> Output
    ) -> Self {
        return on(path, method: .PATCH, body: body, use: handler)
    }
}

extension HBRouterMethods {
    func constructResponder<Output: HBResponseGenerator>(
        body: HBBodyCollation,
        use closure: @escaping (HBRequest) async throws -> Output
    ) -> HBResponder {
        switch body {
        case .collate:
            return HBCallbackResponder { request in
                if case .byteBuffer = request.body {
                    let response = try await closure(request).patchedResponse(from: request)
                    return response
                } else {
                    let body = try await request.body.consumeBody(on: request.eventLoop)
                    request.body = .byteBuffer(body)
                    return try await closure(request).patchedResponse(from: request)
                }
            }
        case .stream:
            return HBCallbackResponder { request in
                let response = try await closure(request).patchedResponse(from: request)
                return response
            }
        }
    }
}
