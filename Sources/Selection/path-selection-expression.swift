import Path

public struct PathSelectionExpression: Sendable, Codable, Equatable {
    public var path: PathExpression
    public var content: ContentSelection?

    public init(
        path: PathExpression,
        content: ContentSelection? = nil
    ) {
        self.path = path
        self.content = content
    }
}

public extension PathSelectionExpression {
    var pattern: PathPattern {
        path.pattern
    }

    var selection: PathSelection {
        PathSelection(
            pattern: path.pattern,
            content: content
        )
    }
}
