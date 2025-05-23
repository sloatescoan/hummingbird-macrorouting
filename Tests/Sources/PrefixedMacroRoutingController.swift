import Hummingbird
import HummingbirdMacroRouting

@MacroRouting(prefix: "/api")
struct PrefixedMacroRoutingController {
    typealias Context = SimpleMacroRoutingRequestContext

    @GET("/auth")
    @Sendable func auth(request: Request, context: Context) async throws -> Response {
        return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(string: "Authed")))
    }

    @GET("/deauth")
    @Sendable func deauth(request: Request, context: Context) async throws -> Response {
        return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(string: "Deauthed")))
    }

    @GET("/deauth/:id")
    @Sendable func deauthId(request: Request, context: Context) async throws -> Response {
        return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(string: "Deauthed")))
    }
}
