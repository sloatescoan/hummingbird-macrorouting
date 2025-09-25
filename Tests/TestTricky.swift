import Testing
import Hummingbird
import HummingbirdMacroRouting
import HummingbirdTesting

@Suite("Tricky Macro Routing Tests")
struct MacroRoutingTestTricky {
    typealias Context = SimpleMacroRoutingRequestContext
    typealias Controller = TrickyMacroRoutingController

    @Test("Reserved Words Structure")
    func testStructure() {
        #expect(Controller.$Routing.do.method == .get)
        #expect(Controller.$Routing.do.prefixedPath == "/do")
        #expect(Controller.$Routing.do.path == "/do")

        #expect(Controller.$Routing.func.method == .post)
        #expect(Controller.$Routing.func.prefixedPath == "/func/{throw}/{catch}")
        // the tricky part here is the keywords
        #expect(Controller.$Routing.func.path(throw: "thrown", catch: "caught") == "/func/thrown/caught")
    }

}
