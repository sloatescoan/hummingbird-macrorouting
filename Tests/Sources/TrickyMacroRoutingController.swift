import Hummingbird
import HummingbirdMacroRouting

@MacroRouting
struct TrickyMacroRoutingController {
    typealias Context = SimpleMacroRoutingRequestContext

    @GET("/do")
    @Sendable func `do`(request: Request, context: Context) async throws -> Response {
        return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(string: "Logged in")))
    }

    @POST("/func/{throw}/{catch}")
    @Sendable func `func`(request: Request, context: Context) async throws -> Response {
        return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(string: "Logged out")))
    }
}
