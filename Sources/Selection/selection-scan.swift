import Foundation
import Path

public enum SelectionScanWarning: Sendable, Codable, Equatable {
    case duplicateInclude(PathExpression)
    case duplicateExclude(PathExpression)
    case includeShadowedByExclude(
        include: PathExpression,
        exclude: PathExpression
    )
    case selectionShadowedByExclude(
        selection: PathSelectionExpression,
        exclude: PathExpression
    )
}

public struct SelectionScanSpecification: Sendable, Codable, Equatable {
    public var includes: [PathExpression]
    public var excludes: [PathExpression]
    public var selections: [PathSelectionExpression]

    public init(
        includes: [PathExpression] = [],
        excludes: [PathExpression] = [],
        selections: [PathSelectionExpression] = []
    ) {
        self.includes = includes
        self.excludes = excludes
        self.selections = selections
    }
}

public extension SelectionScanSpecification {
    var positiveExpressions: [PathExpression] {
        includes + selections.map(\.path)
    }

    var isEmpty: Bool {
        includes.isEmpty
            && excludes.isEmpty
            && selections.isEmpty
    }

    var pathSpecification: PathScanSpecification {
        PathScanSpecification(
            includes: selectionDeduped(positiveExpressions),
            excludes: selectionDeduped(excludes)
        )
    }
}

public struct SelectionScanMatch: Sendable, Codable, Equatable {
    public let url: URL
    public let path: StandardPath
    public let type: PathSegmentType
    public let contentSelections: [ContentSelection]

    public init(
        url: URL,
        path: StandardPath,
        type: PathSegmentType,
        contentSelections: [ContentSelection] = []
    ) {
        self.url = url.standardizedFileURL
        self.path = path
        self.type = type
        self.contentSelections = contentSelections
    }
}

public struct SelectionScanResult: Sendable, Codable, Equatable {
    public let matches: [SelectionScanMatch]
    public let warnings: [SelectionScanWarning]

    public init(
        matches: [SelectionScanMatch],
        warnings: [SelectionScanWarning] = []
    ) {
        self.matches = matches
        self.warnings = warnings
    }
}


public struct SelectionScanBatchResult:
    Sendable,
    Codable,
    Equatable
{
    public let results: [SelectionScanResult]
    public let logicalTraversalCount: Int
    public let physicalTraversalCount: Int
    public let physicalTraversals:
        [PathScanPhysicalTraversalStatistics]

    public init(
        results: [SelectionScanResult],
        logicalTraversalCount: Int,
        physicalTraversalCount: Int,
        physicalTraversals:
            [PathScanPhysicalTraversalStatistics] = []
    ) {
        self.results = results
        self.logicalTraversalCount = logicalTraversalCount
        self.physicalTraversalCount = physicalTraversalCount
        self.physicalTraversals = physicalTraversals
    }
}

public enum SelectionScan {
    public static func scan(
        _ specifications: [SelectionScanSpecification],
        relativeTo anchor: PathAnchor = .cwd,
        configuration: PathWalkConfiguration = .init()
    ) throws -> SelectionScanBatchResult {
        let plans = specifications.map {
            PathScan.compile(
                $0.pathSpecification,
                relativeTo: anchor
            )
        }

        let pathBatch = try PathScan.scan(
            plans,
            configuration: configuration
        )

        precondition(
            pathBatch.results.count
                == specifications.count
        )

        let results = specifications.indices.map {
            index in

            makeResult(
                specification: specifications[index],
                pathResult: pathBatch.results[index],
                relativeTo: anchor
            )
        }

        return .init(
            results: results,
            logicalTraversalCount:
                pathBatch.logicalTraversalCount,
            physicalTraversalCount:
                pathBatch.physicalTraversalCount,
            physicalTraversals:
                pathBatch.physicalTraversals
        )
    }

    public static func scan(
        _ specification: SelectionScanSpecification,
        relativeTo anchor: PathAnchor = .cwd,
        configuration: PathWalkConfiguration = .init()
    ) throws -> SelectionScanResult {
        let pathResult = try PathScan.scan(
            specification.pathSpecification,
            relativeTo: anchor,
            configuration: configuration
        )

        return makeResult(
            specification: specification,
            pathResult: pathResult,
            relativeTo: anchor
        )
    }

    private static func makeResult(
        specification: SelectionScanSpecification,
        pathResult: PathScanResult,
        relativeTo anchor: PathAnchor
    ) -> SelectionScanResult {
        let matches = pathResult.matches.map {
            match in

            var selections: [ContentSelection] = []

            for selection in specification.selections {
                guard selection.path.matches(
                    path: match.path,
                    type: match.type,
                    relativeTo: anchor
                ) else {
                    continue
                }

                guard let content =
                    selection.content
                else {
                    continue
                }

                if !selections.contains(
                    content
                ) {
                    selections.append(
                        content
                    )
                }
            }

            return SelectionScanMatch(
                url: match.url,
                path: match.path,
                type: match.type,
                contentSelections: selections
            )
        }

        return SelectionScanResult(
            matches: matches,
            warnings: analyze(
                specification
            )
        )
    }
}

private extension SelectionScan {
    static func analyze(
        _ specification: SelectionScanSpecification
    ) -> [SelectionScanWarning] {
        var warnings: [SelectionScanWarning] = []

        warnings.append(
            contentsOf: duplicateIncludeWarnings(
                specification.includes
            )
        )

        warnings.append(
            contentsOf: duplicateExcludeWarnings(
                specification.excludes
            )
        )

        for include in specification.includes {
            for exclude in specification.excludes where include == exclude {
                warnings.append(
                    .includeShadowedByExclude(
                        include: include,
                        exclude: exclude
                    )
                )
            }
        }

        for selection in specification.selections {
            for exclude in specification.excludes where selection.path == exclude {
                warnings.append(
                    .selectionShadowedByExclude(
                        selection: selection,
                        exclude: exclude
                    )
                )
            }
        }

        return warnings
    }

    static func duplicateIncludeWarnings(
        _ includes: [PathExpression]
    ) -> [SelectionScanWarning] {
        var warnings: [SelectionScanWarning] = []

        for index in includes.indices {
            let lhs = includes[index]

            for rhs in includes.dropFirst(index + 1) where lhs == rhs {
                warnings.append(.duplicateInclude(rhs))
            }
        }

        return warnings
    }

    static func duplicateExcludeWarnings(
        _ excludes: [PathExpression]
    ) -> [SelectionScanWarning] {
        var warnings: [SelectionScanWarning] = []

        for index in excludes.indices {
            let lhs = excludes[index]

            for rhs in excludes.dropFirst(index + 1) where lhs == rhs {
                warnings.append(.duplicateExclude(rhs))
            }
        }

        return warnings
    }
}

private func selectionDeduped<T: Equatable>(
    _ values: [T]
) -> [T] {
    var out: [T] = []

    for value in values {
        if !out.contains(value) {
            out.append(value)
        }
    }

    return out
}
