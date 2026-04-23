import Foundation
import Parsing
import Position
import Path
import PathParsing
import Selection

public struct PathSelectionExpressionParser: Parser, Sendable {
    public typealias Output = PathSelectionExpression

    public init() {}

    public func parse(
        _ cursor: Cursor
    ) -> ParseResult<PathSelectionExpression> {
        var cur = cursor
        let start = cur.mark()

        do {
            let output = try Self.parseSelectionExpression(&cur)
            PathParsingCore.consumeTrailingTrivia(&cur)

            return .success(
                output,
                cur
            )
        } catch let error as PathParsingError {
            return .failure(
                Diagnostic(
                    error.localizedDescription,
                    range: cur.range(from: start)
                )
            )
        } catch {
            return .failure(
                Diagnostic(
                    "Path selection expression parse failed: \(error.localizedDescription)",
                    range: cur.range(from: start)
                )
            )
        }
    }

    public static func parse(
        _ input: String
    ) throws -> PathSelectionExpression {
        var cur = Cursor(input)
        let output = try parseSelectionExpression(&cur)

        PathParsingCore.consumeTrailingTrivia(&cur)

        if cur.peek() != nil {
            let mark = cur.mark()

            throw PathParsingError.unexpectedTrailingInput(
                String(cur.slice(from: mark)),
                location: PathParsingCore.loc(
                    in: input,
                    offset: cur.offset
                )
            )
        }

        return output
    }
}

private extension PathSelectionExpressionParser {
    static func parseSelectionExpression(
        _ cursor: inout Cursor
    ) throws -> PathSelectionExpression {
        let input = cursor.input
        let token = try PathParsingCore.readPathToken(
            &cursor,
            allowQuotedSelectionSuffix: true
        )

        guard !token.raw.isEmpty else {
            throw PathParsingError.empty(
                location: PathParsingCore.loc(
                    in: input,
                    offset: token.startOffset
                )
            )
        }

        let pathPart: String
        let content: ContentSelection?

        if token.wasQuoted,
           let suffix = token.quotedSelectionSuffix,
           let suffixOffset = token.quotedSelectionOffset
        {
            pathPart = token.raw
            content = try parseContentSelection(
                suffix,
                input: input,
                offset: suffixOffset
            )
        } else {
            let split = try splitTrailingSelection(
                from: token.raw,
                input: input,
                baseOffset: token.startOffset
            )

            pathPart = split.pathPart
            content = split.content
        }

        let path = try PathExpressionParser.parse(pathPart)

        return PathSelectionExpression(
            path: path,
            content: content
        )
    }

    static func splitTrailingSelection(
        from raw: String,
        input: String,
        baseOffset: Int
    ) throws -> (pathPart: String, content: ContentSelection?) {
        guard raw.hasSuffix("]"),
              let open = raw.lastIndex(of: "["),
              open < raw.index(before: raw.endIndex) else {
            return (raw, nil)
        }

        let innerStart = raw.index(after: open)
        let innerEnd = raw.index(before: raw.endIndex)
        let inner = String(raw[innerStart..<innerEnd])

        if let selection = try parseContentSelectionIfPresent(
            inner,
            input: input,
            offset: baseOffset + raw.distance(from: raw.startIndex, to: innerStart)
        ) {
            let prefix = String(raw[..<open])

            return (
                prefix.isEmpty ? "." : prefix,
                selection
            )
        }

        return (raw, nil)
    }

    static func parseContentSelectionIfPresent(
        _ raw: String,
        input: String,
        offset: Int
    ) throws -> ContentSelection? {
        let looksLikeSelection =
            raw.contains("..")
            || raw.contains(":")

        guard looksLikeSelection else {
            return nil
        }

        return try parseContentSelection(
            "[" + raw + "]",
            input: input,
            offset: max(0, offset - 1)
        )
    }

    static func parseContentSelection(
        _ raw: String,
        input: String,
        offset: Int
    ) throws -> ContentSelection {
        guard raw.first == "[", raw.last == "]" else {
            throw PathParsingError.invalidContentSelection(
                raw,
                location: PathParsingCore.loc(
                    in: input,
                    offset: offset
                )
            )
        }

        let inner = String(raw.dropFirst().dropLast())

        if let rangeSeparator = inner.range(of: "..") {
            let lhs = String(inner[..<rangeSeparator.lowerBound])
            let rhs = String(inner[rangeSeparator.upperBound...])

            guard !lhs.isEmpty, !rhs.isEmpty else {
                throw PathParsingError.invalidContentSelection(
                    raw,
                    location: PathParsingCore.loc(
                        in: input,
                        offset: offset
                    )
                )
            }

            if !lhs.contains(":"), !rhs.contains(":") {
                guard
                    let start = Int(lhs),
                    let end = Int(rhs)
                else {
                    throw PathParsingError.invalidContentSelection(
                        raw,
                        location: PathParsingCore.loc(
                            in: input,
                            offset: offset
                        )
                    )
                }

                do {
                    return .lines(
                        try LineRange(
                            start: start,
                            end: end
                        )
                    )
                } catch {
                    throw PathParsingError.invalidContentSelection(
                        raw,
                        location: PathParsingCore.loc(
                            in: input,
                            offset: offset
                        )
                    )
                }
            }

            guard
                let start = parsePosition(lhs),
                let end = parsePosition(rhs)
            else {
                throw PathParsingError.invalidContentSelection(
                    raw,
                    location: PathParsingCore.loc(
                        in: input,
                        offset: offset
                    )
                )
            }

            do {
                return .span(
                    try PositionSpan(
                        start: start,
                        end: end
                    )
                )
            } catch {
                throw PathParsingError.invalidContentSelection(
                    raw,
                    location: PathParsingCore.loc(
                        in: input,
                        offset: offset
                    )
                )
            }
        }

        guard let position = parsePosition(inner) else {
            throw PathParsingError.invalidContentSelection(
                raw,
                location: PathParsingCore.loc(
                    in: input,
                    offset: offset
                )
            )
        }

        return .point(position)
    }

    static func parsePosition(
        _ raw: String
    ) -> Position? {
        guard let separator = raw.firstIndex(of: ":") else {
            return nil
        }

        let lineRaw = String(raw[..<separator])
        let columnRaw = String(raw[raw.index(after: separator)...])

        guard
            let line = Int(lineRaw),
            let column = Int(columnRaw),
            line > 0,
            column > 0
        else {
            return nil
        }

        return Position(
            uncheckedFile: nil,
            line: line,
            column: column,
            invocation: nil
        )
    }
}
