import Hummingbird
import HummingbirdMacroRouting

@MacroRouting
struct PathArgumentsMacroRoutingController {
    typealias Context = SimpleMacroRoutingRequestContext

    @GET("/book/:title")
    @Sendable func bookTitle(request: Request, context: Context) async throws -> Response {
        return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(
            string: "Book :title = \(context.parameters.get("title", as: String.self) ?? "nil")"
        )))
    }
    
    @GET("/movie/{title}")
    @Sendable func movieTitle(request: Request, context: Context) async throws -> Response {
        return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(
            string: "Movie {title} = \(context.parameters.get("title", as: String.self) ?? "nil")"
        )))
    }

    @GET("/book/:title/:year")
    @Sendable func bookTitleYear(request: Request, context: Context) async throws -> Response {
        return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(
            string: "Book :title/:year = "
                + "\(context.parameters.get("title", as: String.self) ?? "nil")/"
                + "\(context.parameters.get("year", as: String.self) ?? "nil")"
        )))
    }
    
    @GET("/movie/{title}/{year}")
    @Sendable func movieTitleYear(request: Request, context: Context) async throws -> Response {
        return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(
            string: "Movie {title}/{year} = "
                + "\(context.parameters.get("title", as: String.self) ?? "nil")/"
                + "\(context.parameters.get("year", as: String.self) ?? "nil")"            
        )))
    }

    @GET("/other/{one}/{two}/{three}/{four}/{five}")
    @Sendable func other(request: Request, context: Context) async throws -> Response {
        return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(
            string: "Other {one}/{two}/{three}/{four}/{five} = "
                + "\(context.parameters.get("one", as: String.self) ?? "nil")/"
                + "\(context.parameters.get("two", as: String.self) ?? "nil")/"
                + "\(context.parameters.get("three", as: String.self) ?? "nil")/"
                + "\(context.parameters.get("four", as: String.self) ?? "nil")/"
                + "\(context.parameters.get("five", as: String.self) ?? "nil")"
        )))
    }

    @GET("/mixed/{one}/:two/{three}/:four/{five}")
    @Sendable func mixed(request: Request, context: Context) async throws -> Response {
        return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(
            string: "Mixed {one}/:two/{three}/:four/{five} = "
                + "\(context.parameters.get("one", as: String.self) ?? "nil")/"
                + "\(context.parameters.get("two", as: String.self) ?? "nil")/"
                + "\(context.parameters.get("three", as: String.self) ?? "nil")/"
                + "\(context.parameters.get("four", as: String.self) ?? "nil")/"
                + "\(context.parameters.get("five", as: String.self) ?? "nil")"
        )))
    }
}
