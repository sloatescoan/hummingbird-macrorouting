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
    
}
