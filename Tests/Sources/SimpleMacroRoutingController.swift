import Hummingbird
import HummingbirdMacroRouting

@MacroRouting
struct SimpleMacroRoutingController {
    typealias Context = SimpleMacroRoutingRequestContext

    @GET("/login")
    @Sendable func logIn(request: Request, context: Context) async throws -> Response {
        return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(string: "Logged in")))
    }

    @POST("/logout")
    @Sendable func logOutHandler(request: Request, context: Context) async throws -> Response {
        return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(string: "Logged out")))
    }
}
