import XCTest
@testable import BowlingTrackingCoreTests

fileprivate extension ImportedVideoAnalyzerTests {
    @available(*, deprecated, message: "Not actually deprecated. Marked as deprecated to allow inclusion of deprecated tests (which test deprecated functionality) without warnings")
    static nonisolated(unsafe) let __allTests__ImportedVideoAnalyzerTests = [
        ("testAnalyzesMultipleManualShotRanges", testAnalyzesMultipleManualShotRanges),
        ("testRejectsInvalidManualShotRange", testRejectsInvalidManualShotRange)
    ]
}

fileprivate extension ShotMetricEstimatorTests {
    @available(*, deprecated, message: "Not actually deprecated. Marked as deprecated to allow inclusion of deprecated tests (which test deprecated functionality) without warnings")
    static nonisolated(unsafe) let __allTests__ShotMetricEstimatorTests = [
        ("testComputesAverageSpeedFromLanePath", testComputesAverageSpeedFromLanePath),
        ("testComputesLaunchAngleAndHookBoards", testComputesLaunchAngleAndHookBoards),
        ("testInterpolatesBoardsAtReferenceDistances", testInterpolatesBoardsAtReferenceDistances)
    ]
}
@available(*, deprecated, message: "Not actually deprecated. Marked as deprecated to allow inclusion of deprecated tests (which test deprecated functionality) without warnings")
func __BowlingTrackingCoreTests__allTests() -> [XCTestCaseEntry] {
    return [
        testCase(ImportedVideoAnalyzerTests.__allTests__ImportedVideoAnalyzerTests),
        testCase(ShotMetricEstimatorTests.__allTests__ShotMetricEstimatorTests)
    ]
}