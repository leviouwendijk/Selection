import Foundation
import Position
import Readers

public enum SelectionResolver {
    public static func resolve(
        file: URL,
        selections: [ContentSelection],
        options: LineReadOptions = .default
    ) throws -> ResolvedFileSelection {
        let readResult = try LineReader(file).read(
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
        ResolvedFileSelection(
            file: file,
            slices: slices(
                file: file,
                lines: readResult.lines,
                selections: selections
            ),
            totalLineCount: readResult.lineCount,
            encodingUsed: readResult.encodingUsed,
            byteCount: readResult.byteCount,
            existed: readResult.existed
        )
    }

    public static func resolve(
        matches: [SelectionScanMatch],
        options: LineReadOptions = .default
    ) throws -> [ResolvedFileSelection] {
        try matches
            .sorted { $0.url.path < $1.url.path }
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
        let readResult = try LineReader(file).read(
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
                )
            ]
        }

        var out: [FileLineSlice] = []

        for selection in selections {
            switch selection {
            case .lines(let range):
                if let slice = lineRangeSlice(
                    allLines: lines,
                    file: file,
                    range: range
                ) {
                    out.append(slice)
                }

            case .point(let position):
                let range = LineRange(
                    uncheckedStart: position.line,
                    uncheckedEnd: position.line
                )

                if let slice = lineRangeSlice(
                    allLines: lines,
                    file: file,
                    range: range
                ) {
                    out.append(slice)
                }

            case .span(let span):
                let range = LineRange(
                    uncheckedStart: span.start.line,
                    uncheckedEnd: span.end.line
                )

                if let slice = lineRangeSlice(
                    allLines: lines,
                    file: file,
                    range: range
                ) {
                    out.append(slice)
                }

            case .anchor(let anchor):
                out.append(
                    contentsOf: anchorSlices(
                        allLines: lines,
                        file: file,
                        anchor: anchor
                    )
                )
            }
        }

        return mergeOverlapping(out)
    }
}

private extension SelectionResolver {
    static func lineRangeSlice(
        allLines: [String],
        file: URL,
        range: LineRange
    ) -> FileLineSlice? {
        guard !allLines.isEmpty else {
            return nil
        }

        let startLine = max(1, range.start)
        let endLine = min(
            allLines.count,
            range.end
        )

        guard endLine >= startLine else {
            return nil
        }

        return FileLineSlice(
            file: file,
            startLine: startLine,
            lines: Array(
                allLines[(startLine - 1)..<endLine]
            )
        )
    }

    static func anchorSlices(
        allLines: [String],
        file: URL,
        anchor: ContentAnchorSelection
    ) -> [FileLineSlice] {
        var out: [FileLineSlice] = []

        for (index, line) in allLines.enumerated()
            where line.contains(anchor.text)
        {
            let startLine = max(
                1,
                index + 1 + anchor.offset
            )

            let endLine = min(
                allLines.count,
                startLine + anchor.count - 1
            )

            guard endLine >= startLine else {
                continue
            }

            out.append(
                FileLineSlice(
                    file: file,
                    startLine: startLine,
                    lines: Array(
                        allLines[(startLine - 1)..<endLine]
                    )
                )
            )
        }

        return out
    }

    static func mergeOverlapping(
        _ slices: [FileLineSlice]
    ) -> [FileLineSlice] {
        let sorted = slices.sorted {
            if $0.file != $1.file {
                return $0.file.path < $1.file.path
            }

            return $0.startLine < $1.startLine
        }

        var out: [FileLineSlice] = []

        for slice in sorted {
            guard let last = out.last,
                  last.file == slice.file,
                  slice.startLine <= (last.endLine + 1)
            else {
                out.append(slice)
                continue
            }

            if slice.endLine <= last.endLine {
                continue
            }

            let appendFromLine = last.endLine + 1
            let offset = max(
                0,
                appendFromLine - slice.startLine
            )

            let mergedLines = last.lines + slice.lines.dropFirst(offset)

            out[out.count - 1] = FileLineSlice(
                file: last.file,
                startLine: last.startLine,
                lines: Array(mergedLines)
            )
        }

        return out
    }
}
