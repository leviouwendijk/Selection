import Foundation
import Position
import Readers
import Selection

enum RegressionFailure: Error {
    case assertion(String)
}

func expect(
    _ condition: @autoclosure () -> Bool,
    _ message: String
) throws {
    guard condition() else {
        throw RegressionFailure.assertion(
            message
        )
    }
}

func selectionResolverUsesSharedRangeAndSlicePrimitives() throws {
    let file = URL(
        fileURLWithPath: "/tmp/selection.swift"
    )
    let readResult = LineReadResult(
        url: file,
        lines: [
            "one",
            "two",
            "three",
            "four",
        ],
        encodingUsed: nil,
        byteCount: 18,
        existed: true
    )
    let first = try LineRange(start: 1, end: 2)
    let second = try LineRange(start: 2, end: 3)

    let resolved = SelectionResolver.resolve(
        file: file,
        readResult: readResult,
        selections: [
            .lines(first),
            .lines(second),
        ]
    )

    try expect(
        resolved.slices.count == 1,
        "overlapping selections coalesce"
    )
    try expect(
        resolved.slices[0].startLine == 1,
        "coalesced selection start"
    )
    try expect(
        resolved.slices[0].lines == [
            "one",
            "two",
            "three",
        ],
        "coalesced selection contents"
    )
}

func selectionResolverPreservesFileSnapshot() throws {
    let file = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "selection-snapshot-\(UUID().uuidString).swift"
        )

    defer {
        try? FileManager.default.removeItem(
            at: file
        )
    }

    try "one\ntwo\nthree".write(
        to: file,
        atomically: true,
        encoding: .utf8
    )

    let resolved = try SelectionResolver.resolve(
        file: file,
        selections: [
            .lines(
                try LineRange(
                    start: 1,
                    end: 2
                )
            ),
        ]
    )

    try expect(
        resolved.fileSnapshot != nil,
        "resolved selection preserves file snapshot"
    )
    try expect(
        resolved.fileSnapshot?.contentFingerprint != nil,
        "resolved selection preserves content fingerprint"
    )
}

func anchorSelectionsStillResolveAndCoalesce() throws {
    let file = URL(
        fileURLWithPath: "/tmp/anchor.txt"
    )
    let slices = SelectionResolver.slices(
        file: file,
        lines: [
            "alpha",
            "needle",
            "needle",
            "omega",
        ],
        selections: [
            .anchor(
                .init(
                    text: "needle"
                )
            ),
        ]
    )

    try expect(
        slices.count == 1,
        "adjacent anchor selections coalesce"
    )
    try expect(
        slices[0].startLine == 2,
        "anchor selection start"
    )
    try expect(
        slices[0].lines == [
            "needle",
            "needle",
        ],
        "anchor selection contents"
    )
}

try selectionResolverUsesSharedRangeAndSlicePrimitives()
try selectionResolverPreservesFileSnapshot()
try anchorSelectionsStillResolveAndCoalesce()
print("SelectionTests: passed")
