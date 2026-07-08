import Hummingbird
import HummingbirdMacroRouting

@MacroRouting(prefix: "/api")
struct InterpolatedMacroRoutingController {
    typealias Context = SimpleMacroRoutingRequestContext

    // A nested static member: visible in the static context where `$Routing`
    // lives (name lookup walks outward through the enclosing type), so a
    // passed-through interpolation of it resolves cleanly — and nesting keeps it
    // out of the module namespace. Still referred to as `\(API.version)`.
    enum API {
        static let version = "v2"
    }

    // Literal interpolation: must pass through (evaluate to "1"), not truncate.
    @GET("/build/\(1)")
    @Sendable func build(request: Request, context: Context) async throws -> Response {
        return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(string: "build")))
    }

    // Static-member pass-through, no captured arguments.
    @GET("/\(API.version)/status")
    @Sendable func status(request: Request, context: Context) async throws -> Response {
        return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(string: "status")))
    }

    // Static-member pass-through *and* a captured path argument in the same route.
    @GET("/\(API.version)/logs/{userId}")
    @Sendable func logs(request: Request, context: Context) async throws -> Response {
        return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(
            string: "logs \(context.parameters.get("userId", as: String.self) ?? "nil")"
        )))
    }
}
