import XCTest
@testable import swift_bali_hsm_proxy

final class ArmorDTests: XCTestCase {
    
    func testArmorD() {
        class FlowController: FlowControl {
            var step = 0
            var bytes = formatter.generateBytes(size: 500)
            var signature: [UInt8]?
            var digest: [UInt8]?
            var mobileKey = formatter.generateBytes(size: 64)
            var publicKey: [UInt8]?

            func stepFailed(reason: String) {
                print("Step failed: \(reason)")
            }
            
            func stepSucceeded(device: ArmorD, result: [UInt8]?) {
                step += 1
                switch (step) {
                    case 1:
                        device.processRequest(type: "eraseKeys")
                    case 2:
                        print("Keys erased: \(String(describing: result))")
                        device.processRequest(type: "generateKeys", mobileKey)
                    case 3:
                        print("Keys generated: \(String(describing: result))")
                        publicKey = result
                        device.processRequest(type: "signBytes", mobileKey, bytes)
                    case 4:
                        print("Bytes signed: \(String(describing: result))")
                        signature = result
                        device.processRequest(type: "validSignature", publicKey!, signature!, bytes)
                    case 5:
                        print("Signature valid: \(String(describing: result))")
                        device.processRequest(type: "digestBytes", bytes)
                    case 6:
                        print("Bytes digested: \(String(describing: result))")
                        digest = result
                        device.processRequest(type: "eraseKeys")
                    default:
                        return  // done
                }
            }
        }

        let controller = FlowController()
        _ = ArmorDProxy(controller: controller)
        Thread.sleep(forTimeInterval: 10)
        print("Done sleeping.")
    }

}
