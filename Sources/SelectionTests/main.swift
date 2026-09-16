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
try anchorSelectionsStillResolveAndCoalesce()
print("SelectionTests: passed")
