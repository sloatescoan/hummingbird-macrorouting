import Foundation
import Hummingbird
import HummingbirdMacroRouting

// A project-defined type used with `#p` to accept a custom CustomStringConvertible type.
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
    @GET("/user/\(#p("id", UUID.self))")
    @Sendable func user(request: Request, context: Context) async throws -> Response {
        return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(
            string: "User {id} = \(context.parameters.get("id", as: String.self) ?? "nil")"
        )))
    }

    // Mixed typed parameters, plus an untyped ({tag}) one that defaults to String.
    @GET("/org/\(#p("orgId", UUID.self))/user/\(#p("userId", Int.self))/tag/{tag}")
    @Sendable func orgUser(request: Request, context: Context) async throws -> Response {
        return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(
            string: "OrgUser = "
                + "\(context.parameters.get("orgId", as: String.self) ?? "nil")/"
                + "\(context.parameters.get("userId", as: String.self) ?? "nil")/"
                + "\(context.parameters.get("tag", as: String.self) ?? "nil")"
        )))
    }

    // A project-defined CustomStringConvertible type.
    @GET("/post/\(#p("slug", Slug.self))")
    @Sendable func post(request: Request, context: Context) async throws -> Response {
        return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(
            string: "Post {slug} = \(context.parameters.get("slug", as: String.self) ?? "nil")"
        )))
    }

    // The remaining spellings of the parameter macro — all resolve to the same ParamMacro.
    @GET("/alias/param/\(#param("id", UUID.self))")
    @Sendable func aliasParam(request: Request, context: Context) async throws -> Response {
        return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(string: "aliasParam")))
    }

    @GET("/alias/hb/\(#hbParam("id", UUID.self))")
    @Sendable func aliasHbParam(request: Request, context: Context) async throws -> Response {
        return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(string: "aliasHbParam")))
    }

    @GET("/alias/explicit/\(#HummingbirdMacroRoutingParam("id", UUID.self))")
    @Sendable func aliasExplicitParam(request: Request, context: Context) async throws -> Response {
        return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(string: "aliasExplicitParam")))
    }

    // Partial / prefix-capture: {id}.jpg (a literal suffix after the parameter).
    @GET("/img/\(#p("id", UUID.self)).jpg")
    @Sendable func image(request: Request, context: Context) async throws -> Response {
        return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(string: "image")))
    }

    // Suffix-capture: a literal prefix before the parameter, file{ext}.
    @GET("/download/file\(#p("ext", String.self))")
    @Sendable func download(request: Request, context: Context) async throws -> Response {
        return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(string: "download")))
    }

    // A reserved word as the parameter name — must be backticked in the generated body.
    @GET("/kw/\(#p("default", String.self))")
    @Sendable func keyword(request: Request, context: Context) async throws -> Response {
        return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(string: "keyword")))
    }

    // A repeated parameter collapses into a single path(id:) argument filling both positions.
    @GET("/repeat/\(#p("id", UUID.self))/again/\(#p("id", UUID.self))")
    @Sendable func repeatedParam(request: Request, context: Context) async throws -> Response {
        return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(string: "repeated")))
    }

    // Loose names that Hummingbird allows — supported via backticked (raw) identifiers.
    @GET("/space/\(#p("user id", String.self))")
    @Sendable func spacedName(request: Request, context: Context) async throws -> Response {
        return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(string: "spaced")))
    }

    @GET("/dash/\(#p("user-id", String.self))")
    @Sendable func dashedName(request: Request, context: Context) async throws -> Response {
        return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(string: "dashed")))
    }
}
