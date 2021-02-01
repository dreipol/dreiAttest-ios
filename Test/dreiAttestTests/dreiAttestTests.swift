//
//  dreiAttestTests.swift
//  dreiAttestTests
//
//  Created by Nils Becker on 18.01.21.
//

import XCTest
import Mocker
import SwiftCBOR
import CryptoKit

class dreiAttestTests: XCTestCase {

    override func setUpWithError() throws {
        for key in UserDefaults.standard.dictionaryRepresentation().keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
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
        }, error: {error in
            XCTFail(error.debugDescription)
        })
        service1.getKeyId(callback: {_ in
            expectation2.fulfill()
        }, error: {error in
            XCTFail(error.debugDescription)
        })
        wait(for: [expectation1, expectation2], timeout: 10)

        service2.getKeyId(callback: {_ in
            expectation3.fulfill()
        }, error: {error in
            XCTFail(error.debugDescription)
        })
        service3.getKeyId(callback: {_ in
            expectation4.fulfill()
        }, error: {error in
            XCTFail(error.debugDescription)
        })

        wait(for: [expectation3, expectation4], timeout: 10)
        XCTAssert(service1.networkHelper.registerCount == 1)
        XCTAssert(service2.networkHelper.registerCount == 0)
        XCTAssert(service3.networkHelper.registerCount == 1)
    }

    func decodeAttestation(attestation: CBOR) -> (certificates: [Data], receipt: Data, auth:Data)? {
        guard case .map(let root) = attestation,
              root[.utf8String("fmt")] == .utf8String("apple-appattest"),
              case .some(.map(let attStmt)) = root[.utf8String("attStmt")],
              case .byteString(let authData) = root[.utf8String("authData")],
              case .array(let certificates) = attStmt[.utf8String("x5c")],
              case .byteString(let receipt) = attStmt[.utf8String("receipt")] else {
            return nil
        }

        let certificatesDecoded: [Data] = certificates.compactMap({
            guard case .byteString(let data) = $0 else {
                return nil
            }

            return Data(data)
        })

        return (certificates: certificatesDecoded, receipt: Data(receipt), auth: Data(authData))
    }

    func testKeyRegistration() throws {
        guard let baseURL = URL(string: "https://dreipol.ch") else {
            XCTFail()
            return
        }

        let configuration = URLSessionConfiguration.af.default
        configuration.protocolClasses = [MockingURLProtocol.self] + (configuration.protocolClasses ?? [])
        let service = try AttestService(baseAddress: baseURL, uid: "registration", config: Config(networkHelperType: DefaultNetworkHelper.self, sessionConfiguration: configuration))

        let snonce = UUID().uuidString
        Mock(url: baseURL.appendingPathComponent("dreiAttest/getNonce"), dataType: .html, statusCode: 200, data: [.get: snonce.data(using: .utf8) ?? Data()])
            .register()
        var registration = Mock(url: baseURL.appendingPathComponent("dreiAttest/publishKey"), dataType: .html, statusCode: 200, data: [.post: Data()])
        registration.onRequest = { _, body in
            guard let attestationString = body?["attestation"] as? String,
                  let attestation = Data(base64Encoded: attestationString),
                  let decoded = try? CBOR.decode([UInt8](attestation)),
                  self.decodeAttestation(attestation: decoded) != nil else {
                XCTFail()
                return
            }
        }
        registration.register()

        let expectation = XCTestExpectation()
        service.getKeyId(callback: { id in
            expectation.fulfill()
        }, error: { error in
            XCTFail(error.debugDescription)
        })

        wait(for: [expectation], timeout: 5)
    }

    func testKeyRegistrationNonce() {
        XCTAssertEqual(DefaultNetworkHelper.nonce(uid: "user1", keyId: "abc", snonce: "AsG/cH/+402bG/Ggvo7M7w6K0D6o8IVWB/nKhLGm2S4="), Data(SHA256.hash(data: "user1abcAsG/cH/+402bG/Ggvo7M7w6K0D6o8IVWB/nKhLGm2S4=".data(using: .utf8)!)))
        XCTAssertEqual(DefaultNetworkHelper.nonce(uid: "user1", keyId: "abc", snonce: ""), Data(SHA256.hash(data: "user1abc".data(using: .utf8)!)))
        XCTAssertEqual(DefaultNetworkHelper.nonce(uid: "user1", keyId: "", snonce: "AsG/cH/+402bG/Ggvo7M7w6K0D6o8IVWB/nKhLGm2S4="), Data(SHA256.hash(data: "user1AsG/cH/+402bG/Ggvo7M7w6K0D6o8IVWB/nKhLGm2S4=".data(using: .utf8)!)))
        XCTAssertEqual(DefaultNetworkHelper.nonce(uid: "", keyId: "abc", snonce: "AsG/cH/+402bG/Ggvo7M7w6K0D6o8IVWB/nKhLGm2S4="), Data(SHA256.hash(data: "abcAsG/cH/+402bG/Ggvo7M7w6K0D6o8IVWB/nKhLGm2S4=".data(using: .utf8)!)))
    }
}
