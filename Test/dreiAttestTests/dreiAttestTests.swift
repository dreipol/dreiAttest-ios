//
//  dreiAttestTests.swift
//  dreiAttestTests
//
//  Created by Nils Becker on 18.01.21.
//

import XCTest

class dreiAttestTests: XCTestCase {

    override func setUpWithError() throws {
        UserDefaults.resetStandardUserDefaults()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testUserDefaultKeys() {
        XCTAssert(Key.uid("test").key == "dreiAttestTests.Key.uid(\"test\")")
    }

    func testUidGeneration() {
        let user1 = "user1"
        let user2 = "user2"
        let empty = ""

        let uid1 = UserDefaults.standard.serviceUid(for: user1)
        let uid1Components = uid1.components(separatedBy: ";")
        let uid2Components = UserDefaults.standard.serviceUid(for: user2).components(separatedBy: ";")
        let uid3Components = UserDefaults.standard.serviceUid(for: empty).components(separatedBy: ";")

        // user
        XCTAssert(uid1Components[0] == user1)
        XCTAssert(uid2Components[0] == user2)
        XCTAssert(uid3Components[0] == empty)

        // UUID
        XCTAssert(uid1Components[1] != uid2Components[1])
        XCTAssert(uid1Components[1] != uid3Components[1])
        XCTAssert(uid2Components[1] != uid3Components[1])

        // reload
        XCTAssert(UserDefaults.standard.serviceUid(for: user1) == uid1)
    }
}
