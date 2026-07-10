import SwiftDiagnostics

struct MsgMalformed: DiagnosticMessage {
    let diagnosticID = MessageID(domain: "MacroRouting", id: "malformed")
    let severity: DiagnosticSeverity = .error
    let message = "Malformed @VERB macro placement"
}

struct MsgNameConflict: DiagnosticMessage {
    let diagnosticID = MessageID(domain: "MacroRouting", id: "nameConflict")
    let severity: DiagnosticSeverity = .error
    let message: String
    init(name: String) {
        self.message = "Route named '\(name)' is already defined"
    }
}

struct MsgNameError: DiagnosticMessage {
    let diagnosticID = MessageID(domain: "MacroRouting", id: "nameError")
    let severity: DiagnosticSeverity = .error
    let message: String
    init(name: String) {
        self.message = "The name associated with this route ('\(name)') must be a valid Swift identifier"
    }
}
