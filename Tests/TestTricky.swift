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
        #expect(Controller.$Routing.do.path == "/do")

        #expect(Controller.$Routing.func.method == .post)
        #expect(Controller.$Routing.func.path == "/func/{throw}/{catch}")
        #expect(Controller.$Routing.func.resolvedPath(throw: "thrown", catch: "caught") == "/func/thrown/caught")
    }

}
