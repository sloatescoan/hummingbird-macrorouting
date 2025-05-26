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
        #expect(Controller.$Routing.bookTitle.path == "/book/:title")
    }

    @Test("Replacements")
    func testReplacements() {
        #expect(
            Controller.$Routing.bookTitle.resolvedPath(title: "cryptonomicon") == "/book/cryptonomicon"
        )
        #expect(
            Controller.$Routing.movieTitle.resolvedPath(title: "ratatouille") == "/movie/ratatouille"
        )

        #expect(
            Controller.$Routing.bookTitleYear.resolvedPath(
                title: "cryptonomicon", year: "1999"
            ) == "/book/cryptonomicon/1999"
        )
        #expect(
            Controller.$Routing.movieTitleYear.resolvedPath(
                title: "ratatouille", year: "2007"
            ) == "/movie/ratatouille/2007"
        )

        #expect(Controller.$Routing.other.path == "/other/{one}/{two}/{three}/{four}/{five}")
        #expect(
            Controller.$Routing.other.resolvedPath(
                one: "apple", two: "banana", three: "carrot",
                four: "durian", five: "eggplant" 
            ) == "/other/apple/banana/carrot/durian/eggplant"
        )

        #expect(Controller.$Routing.mixed.path == "/mixed/{one}/:two/{three}/:four/{five}")
        #expect(
            Controller.$Routing.mixed.resolvedPath(
                one: "apple", two: "banana", three: "carrot",
                four: "durian", five: "eggplant" 
            ) == "/mixed/apple/banana/carrot/durian/eggplant"
        )
    }
    
}
