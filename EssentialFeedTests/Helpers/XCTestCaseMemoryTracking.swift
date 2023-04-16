//
//  XCTestCaseMemoryTracking.swift
//  EssentialFeedTests
//
//  Created by Fattah, Iram on 4/16/23.
//

import XCTest

extension XCTestCase {
     func trackForMemoryLeaks(_ instance: AnyObject, file: StaticString = #filePath, line: UInt = #line) {
        addTeardownBlock { [weak instance] in
            XCTAssertNil(instance, "Instance should have been deallocated, potential memory leak", file: file, line: line)
        }
    }
}
