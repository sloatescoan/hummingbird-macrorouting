import Foundation
import Testing
import Hummingbird
import HummingbirdMacroRouting
import HummingbirdTesting

@Suite("Path Arguments Macro Routing Tests")
struct MacroRoutingTestPathArguments {
    typealias Context = SimpleMacroRoutingRequestContext
    typealias Controller = PathArgumentsMacroRoutingController

    @Test("Static Structure")
    func testStructureStatic() {
        #expect(Controller.$Routing.bookTitle.method == .get)
        #expect(Controller.$Routing.bookTitle.rawPath == "/book/:title")
    }

    @Test("Replacements")
    func testReplacements() {
        #expect(
            Controller.$Routing.bookTitle.path(title: "cryptonomicon") == "/book/cryptonomicon"
        )
        #expect(
            Controller.$Routing.movieTitle.path(title: "ratatouille") == "/movie/ratatouille"
        )

        #expect(
            Controller.$Routing.bookTitleYear.path(
                title: "cryptonomicon", year: "1999"
            ) == "/book/cryptonomicon/1999"
        )
        #expect(
            Controller.$Routing.movieTitleYear.path(
                title: "ratatouille", year: "2007"
            ) == "/movie/ratatouille/2007"
        )

        #expect(Controller.$Routing.other.rawPath == "/other/{one}/{two}/{three}/{four}/{five}")
        #expect(
            Controller.$Routing.other.path(
                one: "apple", two: "banana", three: "carrot",
                four: "durian", five: "eggplant" 
            ) == "/other/apple/banana/carrot/durian/eggplant"
        )

        #expect(Controller.$Routing.mixed.rawPath == "/mixed/{one}/:two/{three}/:four/{five}")
        #expect(
            Controller.$Routing.mixed.path(
                one: "apple", two: "banana", three: "carrot",
                four: "durian", five: "eggplant"
            ) == "/mixed/apple/banana/carrot/durian/eggplant"
        )
    }

    @Test("Typed Parameters")
    func testTypedParameters() {
        // Single UUID parameter — interpolation matches .uuidString.
        let id = UUID(uuidString: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")!
        #expect(
            Controller.$Routing.user.path(id: id) == "/user/E621E1F8-C36C-495A-93FC-0C247A3E6E5F"
        )

        // Mixed types: UUID + Int, with an untyped (String) parameter defaulting through.
        #expect(
            Controller.$Routing.orgUser.path(orgId: id, userId: 42, tag: "featured")
                == "/org/E621E1F8-C36C-495A-93FC-0C247A3E6E5F/user/42/tag/featured"
        )

        // Project-defined CustomStringConvertible type.
        #expect(
            Controller.$Routing.post.path(slug: Slug(value: "Hello-World")) == "/post/hello-world"
        )
    }

    @Test("Parameter Macro Aliases")
    func testParameterMacroAliases() {
        // All four spellings resolve to the same ParamMacro and produce a typed path(id: UUID).
        let id = UUID(uuidString: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")!
        #expect(Controller.$Routing.aliasParam.path(id: id) == "/alias/param/E621E1F8-C36C-495A-93FC-0C247A3E6E5F")
        #expect(Controller.$Routing.aliasHbParam.path(id: id) == "/alias/hb/E621E1F8-C36C-495A-93FC-0C247A3E6E5F")
        #expect(Controller.$Routing.aliasExplicitParam.path(id: id) == "/alias/explicit/E621E1F8-C36C-495A-93FC-0C247A3E6E5F")
    }

}
