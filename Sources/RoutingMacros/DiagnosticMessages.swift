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

struct MsgExtensionOnly: DiagnosticMessage {
    let diagnosticID = MessageID(domain: "MacroRouting", id: "extensionOnly")
    let severity: DiagnosticSeverity = .error
    let message = "@MacroRoutingExtension can only be attached to an extension"
}

struct MsgNamespaceMissing: DiagnosticMessage {
    let diagnosticID = MessageID(domain: "MacroRouting", id: "namespaceMissing")
    let severity: DiagnosticSeverity = .error
    let message = "@MacroRoutingExtension requires a namespace as a string literal"
}

struct MsgNamespaceError: DiagnosticMessage {
    let diagnosticID = MessageID(domain: "MacroRouting", id: "namespaceError")
    let severity: DiagnosticSeverity = .error
    let message: String
    init(name: String) {
        self.message = "Extension namespace '\(name)' must be a valid Swift identifier"
    }
}

struct MsgNamespaceReserved: DiagnosticMessage {
    let diagnosticID = MessageID(domain: "MacroRouting", id: "namespaceReserved")
    let severity: DiagnosticSeverity = .error
    let message: String
    init(name: String) {
        self.message = "Extension namespace '\(name)' is reserved"
    }
}

struct MsgNamespaceConflict: DiagnosticMessage {
    let diagnosticID = MessageID(domain: "MacroRouting", id: "namespaceConflict")
    let severity: DiagnosticSeverity = .error
    let message: String
    init(name: String) {
        self.message = "Extension namespace '\(name)' is already declared"
    }
}
