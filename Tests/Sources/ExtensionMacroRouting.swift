import Hummingbird
import HummingbirdMacroRouting

@MacroRouting(extensions: ["admin", "api"])
struct ExtensionMacroRoutingController {
    typealias Context = SimpleMacroRoutingRequestContext

    @GET("/main")
    @Sendable func getMain(request: Request, context: Context) async throws -> Response {
        return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(string: "Main")))
    }
}

@MacroRoutingExtension("admin")
extension ExtensionMacroRoutingController {
    @GET("/extension/{id}")
    @Sendable func getExtensionId(request: Request, context: Context) async throws -> Response {
        return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(
            string: "Extension item {id} = \(context.parameters.get("id", as: String.self) ?? "nil")"
        )))
    }
}

@MacroRoutingExtension("api")
extension ExtensionMacroRoutingController {
    @POST("/api")
    @Sendable func getApi(request: Request, context: Context) async throws -> Response {
        return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(string: "Extension logged out")))
    }
}
