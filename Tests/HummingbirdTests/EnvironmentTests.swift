//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2021 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation
import Hummingbird
import XCTest

final class EnvironmentTests: XCTestCase {
    func testInitFromEnvironment() {
        XCTAssertEqual(setenv("TEST_VAR", "testSetFromEnvironment", 1), 0)
        let env = HBEnvironment()
        XCTAssertEqual(env.get("TEST_VAR"), "testSetFromEnvironment")
    }

    func testInitFromDictionary() {
        let env = HBEnvironment(values: ["TEST_VAR": "testSetFromDictionary"])
        XCTAssertEqual(env.get("TEST_VAR"), "testSetFromDictionary")
    }

    func testInitFromCodable() {
        let json = #"{"TEST_VAR": "testSetFromCodable"}"#
        var env: HBEnvironment?
        XCTAssertNoThrow(env = try JSONDecoder().decode(HBEnvironment.self, from: Data(json.utf8)))
        XCTAssertEqual(env?.get("TEST_VAR"), "testSetFromCodable")
    }

    func testSet() {
        var env = HBEnvironment()
        env.set("TEST_VAR", value: "testSet")
        XCTAssertEqual(env.get("TEST_VAR"), "testSet")
    }

    func testLogLevel() {
        setenv("LOG_LEVEL", "trace", 1)
        let app = HBApplication()
        XCTAssertEqual(app.logger.logLevel, .trace)
    }
}
