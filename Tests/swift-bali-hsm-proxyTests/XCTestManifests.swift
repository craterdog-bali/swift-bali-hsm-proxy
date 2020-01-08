import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(DocumentTests.allTests),
        testCase(ArmorDTests.allTests)
    ]
}
#endif
