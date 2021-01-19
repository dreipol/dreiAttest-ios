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
        XCTAssert(Key.uid("test1").key != Key.uid("test2").key)
        XCTAssert(Key.uid("test1").key == Key.uid("test1").key)
        XCTAssert(Key.uid("test1").key != Key.keyId(uid: "test1").key)
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

    func testKeyGeneration() throws {
        guard let testURL = URL(string: "https://dreipol.ch") else {
            XCTFail()
            return
        }

        let config = Config(networkHelperType: KeyCountingNetworkHelper.self)
        let service1 = try AttestService(baseAddress: testURL, uid: "user1", config: config)
        let service2 = try AttestService(baseAddress: testURL, uid: "user1", config: config)
        let service3 = try AttestService(baseAddress: testURL, uid: "user2", config: config)

        let expectation1 = XCTestExpectation()
        let expectation2 = XCTestExpectation()
        let expectation3 = XCTestExpectation()
        let expectation4 = XCTestExpectation()
        service1.getKeyId(callback: {_ in
            expectation1.fulfill()
        }, error: {_ in })
        service1.getKeyId(callback: {_ in
            expectation2.fulfill()
        }, error: {_ in })
        service2.getKeyId(callback: {_ in
            expectation3.fulfill()
        }, error: {_ in })
        service3.getKeyId(callback: {_ in
            expectation4.fulfill()
        }, error: {_ in })

        wait(for: [expectation1, expectation2, expectation3, expectation4], timeout: 10)
        XCTAssert(service1.networkHelper.registerCount == 1)
        XCTAssert(service2.networkHelper.registerCount == 0)
        XCTAssert(service3.networkHelper.registerCount == 1)
    }
}
