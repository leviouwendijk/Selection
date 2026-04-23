import Path

public struct PathSelection: Sendable, Codable, Equatable {
    public var pattern: PathPattern
    public var content: ContentSelection?

    public init(
        pattern: PathPattern,
        content: ContentSelection? = nil
    ) {
        self.pattern = pattern
        self.content = content
    }
}

public extension PathSelection {
    init(
        _ parts: [PathPatternComponent],
        terminalHint: PathTerminalHint = .unspecified,
        content: ContentSelection? = nil
    ) {
        self.init(
            pattern: PathPattern(
                parts,
                terminalHint: terminalHint
            ),
            content: content
        )
    }

    init(
        _ parts: PathPatternComponent...,
        terminalHint: PathTerminalHint = .unspecified,
        content: ContentSelection? = nil
    ) {
        self.init(
            parts,
            terminalHint: terminalHint,
            content: content
        )
    }

    init(
        interpreting raw: [String],
        terminalHint: PathTerminalHint = .unspecified,
        content: ContentSelection? = nil
    ) {
        self.init(
            pattern: PathPattern(
                interpreting: raw,
                terminalHint: terminalHint
            ),
            content: content
        )
    }

    init(
        interpreting raw: String...,
        terminalHint: PathTerminalHint = .unspecified,
        content: ContentSelection? = nil
    ) {
        self.init(
            interpreting: raw,
            terminalHint: terminalHint,
            content: content
        )
    }
}
