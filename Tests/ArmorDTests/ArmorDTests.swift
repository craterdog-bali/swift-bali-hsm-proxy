import XCTest
@testable import ArmorD

func randomBytes(size: Int) -> [UInt8] {
    let bytes = [UInt8](repeating: 0, count: size).map { _ in UInt8.random(in: 0..<255) }
    return bytes
}

final class ArmorDTests: XCTestCase {
    
    func testArmorD() {
        class FlowController: FlowControl {
            var step = 0
            var bytes = randomBytes(size: 500)
            var signature: [UInt8]?
            var digest: [UInt8]?
            var mobileKey = randomBytes(size: 64)
            var publicKey: [UInt8]?

            func stepFailed(reason: String) {
                print("Step failed: \(reason)")
            }
            
            func nextStep(device: ArmorD, result: [UInt8]?) {
                print("nextStep: \(step)")
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
