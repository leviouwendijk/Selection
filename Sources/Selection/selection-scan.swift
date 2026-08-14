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


public struct CompiledSelectionScanPlan:
    Sendable,
    Codable,
    Equatable
{
    public let specification:
        SelectionScanSpecification
    public let pathPlan:
        CompiledPathScanPlan

    public init(
        specification: SelectionScanSpecification,
        pathPlan: CompiledPathScanPlan
    ) {
        self.specification = specification
        self.pathPlan = pathPlan
    }

    public var traversalRoots: [URL] {
        pathPlan
            .traversals
            .map {
                $0.root.standardizedFileURL
            }
    }
}

public struct SelectionScanBatchStatistics:
    Sendable,
    Codable,
    Equatable
{
    public let totalDuration: TimeInterval
    public let compilationDuration: TimeInterval
    public let path: PathScanBatchStatistics
    public let resultConstructionDuration:
        TimeInterval

    public init(
        totalDuration: TimeInterval = 0,
        compilationDuration: TimeInterval = 0,
        path: PathScanBatchStatistics = .init(),
        resultConstructionDuration:
            TimeInterval = 0
    ) {
        self.totalDuration = totalDuration
        self.compilationDuration =
            compilationDuration
        self.path = path
        self.resultConstructionDuration =
            resultConstructionDuration
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
    public let statistics:
        SelectionScanBatchStatistics

    public init(
        results: [SelectionScanResult],
        logicalTraversalCount: Int,
        physicalTraversalCount: Int,
        physicalTraversals:
            [PathScanPhysicalTraversalStatistics] = [],
        statistics:
            SelectionScanBatchStatistics = .init()
    ) {
        self.results = results
        self.logicalTraversalCount = logicalTraversalCount
        self.physicalTraversalCount = physicalTraversalCount
        self.physicalTraversals = physicalTraversals
        self.statistics = statistics
    }
}

public enum SelectionScan {
    public static func compile(
        _ specification: SelectionScanSpecification,
        relativeTo anchor: PathAnchor = .cwd
    ) -> CompiledSelectionScanPlan {
        .init(
            specification: specification,
            pathPlan: PathScan.compile(
                specification.pathSpecification,
                relativeTo: anchor
            )
        )
    }

    public static func scan(
        _ specifications: [SelectionScanSpecification],
        relativeTo anchor: PathAnchor = .cwd,
        configuration: PathWalkConfiguration = .init()
    ) throws -> SelectionScanBatchResult {
        let startedAt = Date()
        let compilationStartedAt = Date()

        let plans = specifications.map {
            compile(
                $0,
                relativeTo: anchor
            )
        }

        let compilationDuration =
            Date().timeIntervalSince(
                compilationStartedAt
            )

        let scanned = try scan(
            plans,
            configuration: configuration
        )

        return .init(
            results: scanned.results,
            logicalTraversalCount:
                scanned.logicalTraversalCount,
            physicalTraversalCount:
                scanned.physicalTraversalCount,
            physicalTraversals:
                scanned.physicalTraversals,
            statistics: .init(
                totalDuration:
                    Date().timeIntervalSince(
                        startedAt
                    ),
                compilationDuration:
                    compilationDuration,
                path:
                    scanned.statistics.path,
                resultConstructionDuration:
                    scanned
                    .statistics
                    .resultConstructionDuration
            )
        )
    }

    public static func scan(
        _ plans: [CompiledSelectionScanPlan],
        configuration: PathWalkConfiguration = .init()
    ) throws -> SelectionScanBatchResult {
        let startedAt = Date()

        let pathBatch = try PathScan.scan(
            plans.map(
                \.pathPlan
            ),
            configuration: configuration
        )

        precondition(
            pathBatch.results.count
                == plans.count
        )

        let resultConstructionStartedAt =
            Date()

        let results = plans.indices.map {
            index in

            makeResult(
                specification:
                    plans[index].specification,
                pathResult:
                    pathBatch.results[index],
                relativeTo:
                    .directoryURL(
                        plans[index]
                        .pathPlan
                        .traversals
                        .first?
                        .anchorDirectory
                        ?? URL(
                            fileURLWithPath:
                                FileManager
                                .default
                                .currentDirectoryPath,
                            isDirectory: true
                        )
                    )
            )
        }

        let resultConstructionDuration =
            Date().timeIntervalSince(
                resultConstructionStartedAt
            )

        return .init(
            results: results,
            logicalTraversalCount:
                pathBatch.logicalTraversalCount,
            physicalTraversalCount:
                pathBatch.physicalTraversalCount,
            physicalTraversals:
                pathBatch.physicalTraversals,
            statistics: .init(
                totalDuration:
                    Date().timeIntervalSince(
                        startedAt
                    ),
                compilationDuration: 0,
                path:
                    pathBatch.statistics,
                resultConstructionDuration:
                    resultConstructionDuration
            )
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
