import Lifecycle
import LifecycleNIOCompat
import Logging
import NIO

/// Application class.
open class Application {
    /// server lifecycle, controls initialization and shutdown of application
    public let lifecycle: ServiceLifecycle
    /// event loop group used by application
    public let eventLoopGroup: EventLoopGroup
    /// thread pool used by application
    public let threadPool: NIOThreadPool
    /// middleware applied to requests
    public let middlewares: MiddlewareGroup
    /// routes requests to requestResponders based on URI
    public var router: Router
    /// servers
    public var servers: [String: Server]
    /// Application extensions
    public var extensions: Extensions<Application>
    /// Logger
    public var logger: Logger
    /// Encoder used by router
    public var encoder: ResponseEncoder
    /// decoder used by router
    public var decoder: RequestDecoder

    var responder: RequestResponder?

    /// Initialize new Application
    public init() {
        self.lifecycle = ServiceLifecycle()
        self.logger = Logger(label: "HB")
        self.middlewares = MiddlewareGroup()
        self.router = TrieRouter()
        self.servers = [:]
        self.extensions = Extensions()
        self.encoder = NullEncoder()
        self.decoder = NullDecoder()

        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        self.threadPool = NIOThreadPool(numberOfThreads: 2)
        self.threadPool.start()

        self.lifecycle.register(
            label: "Application",
            start: .sync { self.responder = self.constructResponder() },
            shutdown: .sync(self.shutdownEventLoopGroup)
        )
    }

    /// Run application
    public func start() {
        self.lifecycle.start { error in
            if let error = error {
                self.logger.error("Failed starting HummingBird: \(error)")
            } else {
                self.logger.info("HummingBird started successfully")
            }
        }
    }

    /// wait while server is running
    public func wait() {
        self.lifecycle.wait()
    }
    
    /// Shutdown application
    public func stop() {
        self.lifecycle.shutdown()
    }

    public func addServer(_ server: Server, named: String) {
        self.servers[named] = server
        self.lifecycle.register(
            label: named,
            start: .eventLoopFuture {
                return server.start(application: self)
            },
            shutdown: .eventLoopFuture(server.stop)
        )
    }

    /// Construct the RequestResponder from the middleware group and router
    func constructResponder() -> RequestResponder {
        return self.middlewares.constructResponder(finalResponder: self.router)
    }

    /// shutdown eventloop and threadpool
    func shutdownEventLoopGroup() throws {
        try self.threadPool.syncShutdownGracefully()
        try self.eventLoopGroup.syncShutdownGracefully()
    }
}

extension Application {
    @discardableResult public func addHTTPServer(named: String? = nil, _ configuration: HTTPServer.Configuration = HTTPServer.Configuration()) -> HTTPServer {
        let server = HTTPServer(
            group: self.eventLoopGroup,
            configuration: configuration
        )
        let name = named ?? "HTTPServer \(servers.count)"
        self.addServer(server, named: name)
        return server
    }
}
