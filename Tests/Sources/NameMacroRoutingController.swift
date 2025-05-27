import Hummingbird
import HummingbirdMacroRouting

@MacroRouting
struct NameMacroRoutingController {
    typealias Context = SimpleMacroRoutingRequestContext

    @GET("/welcome", name: "welcomeRoute")
    @Sendable func welcomeRouteHandler(request: Request, context: Context) async throws -> Response {
        return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(string: "Welcome!")))
    }

    @GET("/welcome2")
    @Sendable func welcomeRouteHandler2(request: Request, context: Context) async throws -> Response {
        return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(string: "Welcome 2!")))
    }

    @GET("/welcome3")
    @POST("/welcome3", name: "postWelcomeRouteHandler3")
    @Sendable func welcomeRouteHandler3(request: Request, context: Context) async throws -> Response {
        return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(string: "Welcome 3!")))
    }
}
