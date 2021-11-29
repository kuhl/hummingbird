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

import Logging
import NIO

/// Errors generated by Connection Pool
public enum HBConnectionPoolError: Error {
    case poolClosed
}

/// Protocol describing a single connection
public protocol HBConnection: AnyObject {
    /// Create a new connection
    /// - Parameters:
    ///     - eventLoop: EventLoop to use when creating new connection
    ///     - logger: Logger used for logging
    /// - Returns: Returns new connection
    static func make(on eventLoop: EventLoop, logger: Logger) -> EventLoopFuture<Self>

    /// Close connection.
    ///
    /// This should not be called directly. Instead connection should be closed via `HBConnectionPool.release`
    /// - Parameters:
    ///     - logger: Logger used for logging
    /// - Returns: Returns when closed
    func close(logger: Logger) -> EventLoopFuture<Void>

    /// Is connection closed
    var isClosed: Bool { get }
}

/// Connection Pool
public final class HBConnectionPool<Connection: HBConnection> {
    /// Connection Pool close state
    enum CloseState: Equatable {
        case open
        case closing(EventLoopFuture<Void>)
        case closed
    }

    /// EventLoop connections are attached to
    public let eventLoop: EventLoop
    /// Maximum number of connections allowed
    public let maxConnections: Int
    /// Current number of connections
    public var numConnections: Int
    /// Is connection pool closed or closing
    public var isClosed: Bool { self.closeState != .open }

    /// Connections available
    var availableQueue: CircularBuffer<Connection>
    /// Promises waiting for a connection
    var waitingQueue: CircularBuffer<EventLoopPromise<Connection>>
    var closeState: CloseState

    /// Create `HBConnectionPool`
    /// - Parameters:
    ///   - maxConnections: Maximum number of connections allowed
    ///   - eventLoop: EventLoop connection pool is attached to
    public init(
        maxConnections: Int,
        eventLoop: EventLoop
    ) {
        self.eventLoop = eventLoop
        self.availableQueue = .init(initialCapacity: maxConnections)
        self.waitingQueue = .init()
        self.maxConnections = maxConnections
        self.numConnections = 0
        self.closeState = .open
    }

    deinit {
        precondition(self.closeState != .open, "HBConnectionPool.close() should be called before destroying connection pool")
    }

    /// Request a connection
    /// - Parameter logger: Logger used for logging
    /// - Returns: Returns a connection when available
    public func request(logger: Logger) -> EventLoopFuture<Connection> {
        if self.eventLoop.inEventLoop {
            return self._request(logger: logger)
        } else {
            return self.eventLoop.flatSubmit { self._request(logger: logger) }
        }
    }

    /// Release a connection back onto the pool
    /// - Parameters:
    ///   - connection: connection to release
    ///   - logger: Logger used for logging
    public func release(connection: Connection, logger: Logger) {
        if self.eventLoop.inEventLoop {
            self._release(connection: connection, logger: logger)
        } else {
            return self.eventLoop.execute { self._release(connection: connection, logger: logger) }
        }
    }

    /// Close connection pool
    /// - Parameter logger: Logger used for logging
    /// - Returns: Returns when close is complete
    public func close(logger: Logger) -> EventLoopFuture<Void> {
        if self.eventLoop.inEventLoop {
            return self._close(logger: logger)
        } else {
            return self.eventLoop.flatSubmit { self._close(logger: logger) }
        }
    }

    private func _request(logger: Logger) -> EventLoopFuture<Connection> {
        guard !self.isClosed else {
            return self.eventLoop.makeFailedFuture(HBConnectionPoolError.poolClosed)
        }
        while let connection = availableQueue.popFirst() {
            if connection.isClosed {
                logger.trace("Prune connection: \(Connection.self)")
                self.numConnections -= 1
            } else {
                return self.eventLoop.makeSucceededFuture(connection)
            }
        }

        if self.numConnections < self.maxConnections {
            self.numConnections += 1
            logger.trace("Make connection: \(Connection.self)")
            return Connection.make(on: self.eventLoop, logger: logger)
        } else {
            let promise = self.eventLoop.makePromise(of: Connection.self)
            self.waitingQueue.append(promise)
            return promise.futureResult
        }
    }

    private func _release(connection: Connection, logger: Logger) {
        switch self.closeState {
        case .open:
            if let waitingPromise = self.waitingQueue.popFirst() {
                waitingPromise.succeed(connection)
            }
            self.availableQueue.append(connection)

        case .closed, .closing:
            _ = connection.close(logger: logger)
        }
    }

    private func _close(logger: Logger) -> EventLoopFuture<Void> {
        switch self.closeState {
        case .open:
            logger.debug("Closing \(Self.self)")
            // remove waiting connections
            while let waiting = waitingQueue.popFirst() {
                waiting.fail(HBConnectionPoolError.poolClosed)
            }

            // close available connections
            let closeFutures: [EventLoopFuture<Void>] = self.availableQueue.map { $0.close(logger: logger) }
            let future = EventLoopFuture.andAllSucceed(closeFutures, on: self.eventLoop)

            // empty available queue
            self.availableQueue.removeAll()
            self.numConnections = 0
            self.closeState = .closing(future)

            return future.map { self.closeState = .closed }

        case .closing(let future):
            return future

        case .closed:
            return self.eventLoop.makeSucceededVoidFuture()
        }
    }
}
