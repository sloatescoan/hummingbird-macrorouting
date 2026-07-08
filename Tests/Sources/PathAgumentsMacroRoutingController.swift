import Foundation
import Hummingbird
import HummingbirdMacroRouting

// A project-defined type used in `conform:` to accept custom CustomStringConvertible
struct Slug: CustomStringConvertible {
    let value: String
    var description: String { value.lowercased() }
}

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

    // A single typed parameter (UUID from Foundation).
    @GET("/user/{id}", conform: ["id": UUID.self])
    @Sendable func user(request: Request, context: Context) async throws -> Response {
        return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(
            string: "User {id} = \(context.parameters.get("id", as: String.self) ?? "nil")"
        )))
    }

    // Mixed typed parameters, plus an untyped one that defaults to String.
    @GET("/org/{orgId}/user/{userId}/tag/{tag}", conform: ["orgId": UUID.self, "userId": Int.self])
    @Sendable func orgUser(request: Request, context: Context) async throws -> Response {
        return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(
            string: "OrgUser = "
                + "\(context.parameters.get("orgId", as: String.self) ?? "nil")/"
                + "\(context.parameters.get("userId", as: String.self) ?? "nil")/"
                + "\(context.parameters.get("tag", as: String.self) ?? "nil")"
        )))
    }

    // A project-defined CustomStringConvertible type.
    @GET("/post/{slug}", conform: ["slug": Slug.self])
    @Sendable func post(request: Request, context: Context) async throws -> Response {
        return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(
            string: "Post {slug} = \(context.parameters.get("slug", as: String.self) ?? "nil")"
        )))
    }
}
