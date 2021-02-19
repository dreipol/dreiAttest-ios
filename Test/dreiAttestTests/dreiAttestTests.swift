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
import Alamofire

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
        let service1 = try AttestService(baseAddress: testURL, uid: "user1", validationLevel: .signOnly, config: config)
        let service2 = try AttestService(baseAddress: testURL, uid: "user1", validationLevel: .signOnly, config: config)
        let service3 = try AttestService(baseAddress: testURL, uid: "user2", validationLevel: .signOnly, config: config)

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
        XCTAssert(service1.keyNetworkHelper.registerCount == 1)
        XCTAssert(service2.keyNetworkHelper.registerCount == 0)
        XCTAssert(service3.keyNetworkHelper.registerCount == 1)
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
        let service = try AttestService(baseAddress: baseURL, uid: "registration", validationLevel: .signOnly, config: Config(networkHelperType: DefaultKeyNetworkHelper.self, sessionConfiguration: configuration))

        let snonce = UUID().uuidString
        Mock(url: baseURL.appendingPathComponent("dreiattest/nonce"), dataType: .html, statusCode: 200, data: [.get: snonce.data(using: .utf8) ?? Data()])
            .register()
        var registration = Mock(url: baseURL.appendingPathComponent("dreiattest/key"), dataType: .html, statusCode: 200, data: [.post: Data()])
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
        XCTAssertEqual(DefaultKeyNetworkHelper.nonce(uid: "user1", keyId: "abc", snonce: "AsG/cH/+402bG/Ggvo7M7w6K0D6o8IVWB/nKhLGm2S4="), Data(SHA256.hash(data: "user1abcAsG/cH/+402bG/Ggvo7M7w6K0D6o8IVWB/nKhLGm2S4=".data(using: .utf8)!)))
        XCTAssertEqual(DefaultKeyNetworkHelper.nonce(uid: "user1", keyId: "abc", snonce: ""), Data(SHA256.hash(data: "user1abc".data(using: .utf8)!)))
        XCTAssertEqual(DefaultKeyNetworkHelper.nonce(uid: "user1", keyId: "", snonce: "AsG/cH/+402bG/Ggvo7M7w6K0D6o8IVWB/nKhLGm2S4="), Data(SHA256.hash(data: "user1AsG/cH/+402bG/Ggvo7M7w6K0D6o8IVWB/nKhLGm2S4=".data(using: .utf8)!)))
        XCTAssertEqual(DefaultKeyNetworkHelper.nonce(uid: "", keyId: "abc", snonce: "AsG/cH/+402bG/Ggvo7M7w6K0D6o8IVWB/nKhLGm2S4="), Data(SHA256.hash(data: "abcAsG/cH/+402bG/Ggvo7M7w6K0D6o8IVWB/nKhLGm2S4=".data(using: .utf8)!)))
    }

    func testRequestHash() throws {
        var originalRequest = try URLRequest(url: URL(string: "https://dreipol.ch/test")!, method: .get, headers: HTTPHeaders([.accept("text/json")]))
        originalRequest.httpBody = "hello".data(using: .utf8)
        var request1 = originalRequest
        request1.url = URL(string: "https://dreipol.ch")!
        var request2 = originalRequest
        request2.method = .delete
        var request3 = originalRequest
        request3.setValue(nil, forHTTPHeaderField: "Accept")
        var request4 = originalRequest
        request4.headers =  HTTPHeaders([.userAgent("text/json")])
        var request5 = originalRequest
        request5.headers =  HTTPHeaders([.accept("text/plain")])
        var request6 = originalRequest
        request6.httpBody = nil
        var request7 = originalRequest
        request7.httpBody = "world".data(using: .utf8)

        XCTAssertNotEqual(ServiceRequestHelper.requestHash(originalRequest), ServiceRequestHelper.requestHash(request1))
        XCTAssertNotEqual(ServiceRequestHelper.requestHash(originalRequest), ServiceRequestHelper.requestHash(request2))
        XCTAssertNotEqual(ServiceRequestHelper.requestHash(originalRequest), ServiceRequestHelper.requestHash(request3))
        XCTAssertNotEqual(ServiceRequestHelper.requestHash(originalRequest), ServiceRequestHelper.requestHash(request4))
        XCTAssertNotEqual(ServiceRequestHelper.requestHash(originalRequest), ServiceRequestHelper.requestHash(request5))
        XCTAssertNotEqual(ServiceRequestHelper.requestHash(originalRequest), ServiceRequestHelper.requestHash(request6))
        XCTAssertNotEqual(ServiceRequestHelper.requestHash(originalRequest), ServiceRequestHelper.requestHash(request7))
    }

    func testHeaderInsertion() throws {
        let service1 = try AttestService(baseAddress: URL(string: "https://dreipol.ch/test")!, uid: "", validationLevel: .signOnly, config: Config(networkHelperType: AlwaysAcceptingKeyNetworkHelper.self))
        let service2 = try AttestService(baseAddress: URL(string: "https://dreipol.ch/test2")!, uid: "", validationLevel: .signOnly, config: Config(networkHelperType: AlwaysAcceptingKeyNetworkHelper.self))
        let service3 = try AttestService(baseAddress: URL(string: "https://dreipol.ch/test/a")!, uid: "", validationLevel: .signOnly, config: Config(networkHelperType: AlwaysAcceptingKeyNetworkHelper.self))

        let request1 = try URLRequest(url: URL(string: "https://dreipol.ch/test/abc")!, method: .get, headers: HTTPHeaders([.accept("text/json")]))
        let request2 = try URLRequest(url: URL(string: "https://dreipol.ch/test/abc")!, method: .get, headers: HTTPHeaders([.accept("text/json"), .signature(value: "123")]))

        let expectations = (0..<5).map({ _ in XCTestExpectation() })

        service1.adapt(request1, for: Session()) {
            switch $0 {
            case .success(let request):
                XCTAssertNotNil(request.allHTTPHeaderFields?["Dreiattest-signature"])
                XCTAssertNotNil(request.allHTTPHeaderFields?["Dreiattest-nonce"])
                XCTAssertEqual(request.allHTTPHeaderFields?["Dreiattest-uid"], service1.serviceUid)
            default:
                XCTFail()
            }
            expectations[0].fulfill()
        }

        service1.adapt(request2, for: Session()) {
            switch $0 {
            case .failure(AttestError.illegalHeaders):
                break
            default:
                XCTFail()
            }
            expectations[1].fulfill()
        }

        service2.adapt(request1, for: Session()) {
            switch $0 {
            case .success(let request):
                XCTAssertEqual(request, request1)
            default:
                XCTFail()
            }
            expectations[2].fulfill()
        }

        // Make sure we don't fail when chaining Attest Services
        service2.adapt(request2, for: Session()) {
            switch $0 {
            case .success(let request):
                XCTAssertEqual(request, request2)
            default:
                XCTFail()
            }
            expectations[3].fulfill()
        }

        service3.adapt(request1, for: Session()) {
            switch $0 {
            case .success(let request):
                XCTAssertEqual(request, request1)
            default:
                XCTFail()
            }
            expectations[4].fulfill()
        }

        wait(for: expectations, timeout: 10)
    }

    func testBypass() throws {
        let config = Config(networkHelperType: KeyCountingNetworkHelper.self, sharedSecret: "abc")
        let service = try AttestService(baseAddress: URL(string: "https://dreipol.ch")!, uid: "user1", validationLevel: .signOnly, config: config)

        let expectation = XCTestExpectation()

        let request = URLRequest(url: URL(string: "https://dreipol.ch/test")!)
        service.adapt(request, for: Session()) { result in
            switch result {
            case .success(let adapted):
                XCTAssertEqual(adapted.allHTTPHeaderFields?["Dreiattest-shared-secret"], "abc")
                XCTAssertNotNil(adapted.allHTTPHeaderFields?["Dreiattest-uid"])
            case .failure:
                XCTFail()
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10)
        XCTAssertEqual(service.keyNetworkHelper.registerCount, 0)
    }

    func testKeyRenewal() throws {
        guard let baseURL = URL(string: "https://dreipol.ch") else {
            XCTFail()
            return
        }

        let configuration = URLSessionConfiguration.af.default
        configuration.protocolClasses = [MockingURLProtocol.self] + (configuration.protocolClasses ?? [])
        let service = try AttestService(baseAddress: baseURL, uid: "renewal", validationLevel: .signOnly, config: Config(networkHelperType: ForwardingKeyCountingNetworkHelper.self, sessionConfiguration: configuration))

        let snonce = UUID().uuidString
        Mock(url: baseURL.appendingPathComponent("dreiattest/nonce"), dataType: .html, statusCode: 200, data: [.get: snonce.data(using: .utf8) ?? Data()])
            .register()
        Mock(url: baseURL.appendingPathComponent("dreiattest/key"), dataType: .html, statusCode: 200, data: [.post: Data()])
            .register()
        Mock(url: baseURL.appendingPathComponent("test"), dataType: .json, statusCode: 403, data: [.get: Data()], additionalHeaders: [HTTPHeader.errorHeaderName: "dreiAttest_invalid_key"])
            .register()
        Mock(url: URL(string: "https://drei.io/test")!, dataType: .json, statusCode: 403, data: [.get: Data()], additionalHeaders: [HTTPHeader.errorHeaderName: "dreiAttest_invalid_key"])
            .register()

        let expectation1 = XCTestExpectation()
        let expectation2 = XCTestExpectation()
        let session = Session(configuration: configuration, interceptor: service)


        session.request(baseURL.appendingPathComponent("test"))
            .validate()
            .response { result in
            expectation1.fulfill()
        }.resume()
        wait(for: [expectation1], timeout: 5)
        XCTAssertEqual(service.keyNetworkHelper.registerCount, 2)

        session.request(URL(string: "https://drei.io/test")!)
            .validate()
            .response { result in
            expectation2.fulfill()
        }.resume()

        wait(for: [expectation2], timeout: 5)
        XCTAssertEqual(service.keyNetworkHelper.registerCount, 2)
    }
}
