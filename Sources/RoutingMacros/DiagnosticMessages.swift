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

struct MsgParamNameError: DiagnosticMessage {
    let diagnosticID = MessageID(domain: "MacroRouting", id: "paramNameError")
    let severity: DiagnosticSeverity = .error
    let message: String
    init(name: String) {
        self.message = "The parameter name '\(name)' must be a valid Swift identifier (it becomes both a path placeholder and a path(…) argument label)"
    }
}

struct MsgParamTypeConflict: DiagnosticMessage {
    let diagnosticID = MessageID(domain: "MacroRouting", id: "paramTypeConflict")
    let severity: DiagnosticSeverity = .error
    let message: String
    init(name: String, existing: String, new: String) {
        self.message = "Path parameter '\(name)' is declared with conflicting types ('\(existing)' and '\(new)'); repeated parameters collapse into a single path(…) argument and must agree on their type"
    }
}
