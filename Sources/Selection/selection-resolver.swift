import Foundation
import Position
import Readers

public enum SelectionResolver {
    public static func resolve(
        file: URL,
        selections: [ContentSelection],
        options: LineReadOptions = .default
    ) throws -> ResolvedFileSelection {
        let readResult = try LineReader(
            file
        ).read(
            options: options
        )

        return resolve(
            file: file,
            readResult: readResult,
            selections: selections
        )
    }

    public static func resolve(
        file: URL,
        readResult: LineReadResult,
        selections: [ContentSelection]
    ) -> ResolvedFileSelection {
        let slices: [FileLineSlice]

        if selections.isEmpty {
            slices = [
                FileLineSlice(
                    file: file,
                    startLine: 1,
                    lines: readResult.lines
                ),
            ]
        } else {
            let ranges = resolvedRanges(
                lines: readResult.lines,
                selections: selections
            )
            .coalesced()

            slices = readResult
                .slices(
                    ranges
                )
                .map { slice in
                    FileLineSlice(
                        file: file,
                        startLine: slice.startLine,
                        lines: slice.lines
                    )
                }
        }

        return ResolvedFileSelection(
            file: file,
            slices: slices,
            totalLineCount: readResult.lineCount,
            encodingUsed: readResult.encodingUsed,
            byteCount: readResult.byteCount,
            existed: readResult.existed,
            fileSnapshot: readResult.fileSnapshot
        )
    }

    public static func resolve(
        matches: [SelectionScanMatch],
        options: LineReadOptions = .default
    ) throws -> [ResolvedFileSelection] {
        try matches
            .sorted { lhs, rhs in
                lhs.url.path < rhs.url.path
            }
            .map { match in
                try resolve(
                    file: match.url,
                    selections: match.contentSelections,
                    options: options
                )
            }
    }

    public static func slices(
        file: URL,
        selections: [ContentSelection],
        options: LineReadOptions = .default
    ) throws -> [FileLineSlice] {
        let readResult = try LineReader(
            file
        ).read(
            options: options
        )

        return slices(
            file: file,
            lines: readResult.lines,
            selections: selections
        )
    }

    public static func slices(
        file: URL,
        lines: [String],
        selections: [ContentSelection]
    ) -> [FileLineSlice] {
        guard !selections.isEmpty else {
            return [
                FileLineSlice(
                    file: file,
                    startLine: 1,
                    lines: lines
                ),
            ]
        }

        return resolvedRanges(
            lines: lines,
            selections: selections
        )
        .coalesced()
        .compactMap { range in
            FileLineSlice(
                file: file,
                lines: lines,
                range: range
            )
        }
    }
}

private extension SelectionResolver {
    static func resolvedRanges(
        lines: [String],
        selections: [ContentSelection]
    ) -> [LineRange] {
        var ranges: [LineRange] = []

        for selection in selections {
            switch selection {
            case .anchor(let anchor):
                ranges.append(
                    contentsOf: anchorRanges(
                        lines: lines,
                        anchor: anchor
                    )
                )

            case .lines,
                 .point,
                 .span:
                if let range = selection.lineRange {
                    ranges.append(
                        range
                    )
                }
            }
        }

        return ranges
    }

    static func anchorRanges(
        lines: [String],
        anchor: ContentAnchorSelection
    ) -> [LineRange] {
        var ranges: [LineRange] = []

        for (index, line) in lines.enumerated()
            where line.contains(anchor.text)
        {
            let startLine = max(
                1,
                index + 1 + anchor.offset
            )
            let endLine = min(
                lines.count,
                startLine + anchor.count - 1
            )

            guard endLine >= startLine else {
                continue
            }

            ranges.append(
                LineRange(
                    uncheckedStart: startLine,
                    uncheckedEnd: endLine
                )
            )
        }

        return ranges
    }
}
