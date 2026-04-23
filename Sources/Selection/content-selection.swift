import Position

public struct ContentAnchorSelection: Sendable, Codable, Equatable, Hashable {
    public var text: String
    public var offset: Int
    public var count: Int

    public init(
        text: String,
        offset: Int = 0,
        count: Int = 1
    ) {
        precondition(
            !text.isEmpty,
            "Anchor text cannot be empty."
        )

        precondition(
            count > 0,
            "Anchor count must be greater than zero."
        )

        self.text = text
        self.offset = offset
        self.count = count
    }
}

public enum ContentSelection: Sendable, Codable, Equatable, Hashable {
    case lines(LineRange)
    case point(Position)
    case span(PositionSpan)
    case anchor(ContentAnchorSelection)
}

public extension ContentSelection {
    var lineRange: LineRange? {
        switch self {
        case .lines(let range):
            return range

        case .point(let position):
            return LineRange(
                uncheckedStart: position.line,
                uncheckedEnd: position.line
            )

        case .span(let span):
            return LineRange(
                uncheckedStart: span.start.line,
                uncheckedEnd: span.end.line
            )

        case .anchor:
            return nil
        }
    }
}
