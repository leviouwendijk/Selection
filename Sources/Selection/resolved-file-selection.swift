import Foundation
import Position
import Readers

public struct ResolvedFileSelection: Sendable, Codable, Hashable {
    public let file: URL
    public let slices: [FileLineSlice]

    public let totalLineCount: Int
    public let encodingUsed: TextEncoding?
    public let byteCount: Int
    public let existed: Bool

    public init(
        file: URL,
        slices: [FileLineSlice],
        totalLineCount: Int,
        encodingUsed: TextEncoding?,
        byteCount: Int,
        existed: Bool
    ) {
        self.file = file.standardizedFileURL
        self.slices = slices
        self.totalLineCount = totalLineCount
        self.encodingUsed = encodingUsed
        self.byteCount = byteCount
        self.existed = existed
    }
}

public extension ResolvedFileSelection {
    var isEmpty: Bool {
        slices.allSatisfy(\.isEmpty)
    }

    var selectedLineCount: Int {
        slices.reduce(0) { partial, slice in
            partial + slice.lines.count
        }
    }

    var selectedText: String {
        slices
            .flatMap(\.lines)
            .joined(separator: "\n")
    }

    var selectedLineRanges: [LineRange] {
        slices.compactMap { slice in
            guard !slice.lines.isEmpty else {
                return nil
            }

            return try? LineRange(
                start: slice.startLine,
                end: slice.endLine
            )
        }
    }
}
