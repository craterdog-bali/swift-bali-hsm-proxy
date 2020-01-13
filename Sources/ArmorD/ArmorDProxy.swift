//
//  ArmorDProxy.swift
//  paymentDemo
//
//  Copyright © 2019 Aren Dalloul. All rights reserved.
//

import Foundation
import CoreBluetooth


// This class acts as a proxy to an ArmorD device that supports bluetooth low energy (BLE).
public class ArmorDProxy: NSObject, ArmorD, CBCentralManagerDelegate, CBPeripheralDelegate {

    // PRIVATE STATE

    // The BLE central manager proxy (iPhone App)
    var mobileDevice: CBCentralManager!  // must be ! because it is set after super.init() is called

    // The BLE peripheral proxy (ArmorD device)
    let BLE_Service_UUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    var blePeripheral: CBPeripheral?

    // The BLE peripheral RX characteristic (central manager writes to peripheral's UART RX line)
    let BLE_CharacteristicWrite_UUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
    var writeCharacteristic: CBCharacteristic?

    // The BLE peripheral TX characteristic (peripheral's notifies central manager using UART TX line)
    let BLE_CharacteristicNotify_UUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
    var notifyCharacteristic: CBCharacteristic?

    // A reference to the flow controller via the FlowControl protocol
    var controller: FlowControl

    // The size of the data blocks sent to the peripheral which is 512 - 2 = 510, to account for the
    // two leading bytes which tell the peripheral the request type (1 byte) and number of
    // arguments (1 byte)
    static let BLOCK_SIZE = 510

    // The request attributes
    var block = -1
    var request = [UInt8]()  // empty array of bytes
    var result: [UInt8]?
    var error: String?


    // PUBLIC INTERFACE

    public init(controller: FlowControl) {
        print("ArmorDProxy.init()")
        self.controller = controller
        super.init()  // must be called before next line which passes self in as an argument
        print("super.init() finished")
        mobileDevice = CBCentralManager(delegate: self, queue: nil)  // must be called after super.init()
        print("The mobile device has been initialized")
    }

    /*
     * This function is called when the mobile device's bluetooth status changes. It initiates
     * the request processing with the flow controller. If no requests are pending, nothing
     * happens until the user initiates the next request sequence.
     */
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("Bluetooth is available")
        switch central.state {
        case .unknown:
            print("Bluetooth status is UNKNOWN")
        case .resetting:
            print("Bluetooth status is RESETTING")
        case .unsupported:
            print("Bluetooth status is UNSUPPORTED")
        case .unauthorized:
            print("Bluetooth status is UNAUTHORIZED")
        case .poweredOff:
            print("Bluetooth status is POWERED OFF")
        case .poweredOn:
            print("Bluetooth status is POWERED ON")
            controller.nextStep(device: self, result: nil)  // triggers processRequest()
        @unknown default:
            print("Bluetooth status is \(central.state)")
        }
    }
    
    /*
     * This function sends a request to a BLEUart service for processing (utilizing the
     * processBlock function)
     *
     * Note: A BLEUart service can only handle requests up to 512 bytes in length. If the
     * specified request is longer than this limit, it is broken up into separate 512 byte
     * blocks and each block is sent as a separate BLE request.
     */
    public func processRequest(type: String, _ args: [UInt8]...) {
        print("Processing a request of type: \(type)")

        // decode the request type
        var requestType: UInt8 = 255  // set to an invalid type
        switch(type) {
        case "generateKeys":
            requestType = 1
        case "rotateKeys":
            requestType = 2
        case "eraseKeys":
            requestType = 3
        case "digestBytes":
            requestType = 4
        case "signBytes":
            requestType = 5
        case "validSignature":
            requestType = 6
        default:
            print("Error: Invalid request type: \(type)")
        }

        // assemble the request type and number of arguments as the first two bytes of the request
        request = [UInt8]()  // reset the request buffer
        request += [requestType, UInt8(args.count)]

        // add the length of each argument as two bytes followed by the argument bytes for each argument
        for arg in args {
            let length: Int = arg.count
            request += [UInt8(length >> 8), UInt8(length & 0xFF)] // the length of this argument
            request += arg // the argument bytes
        }

        // the request is fully assembled
        print("Request: \(request)")
        
        // calculate the current block number (first block is zero)
        block = Int((Double(request.count - 2) / Double(ArmorDProxy.BLOCK_SIZE)).rounded(.down))
        print("New block count: \(block)")
        print("")

        // process the first (and perhaps only) block
        connect()  // eventually triggers processBlock()
    }
    
    /*
     * This function attempts to connect to an ArmorD peripheral. It triggers the 'didDiscover' callback.
     */
    func connect() {
        print("Connecting to an ArmorD peripheral...")
        mobileDevice.scanForPeripherals(withServices: [BLE_Service_UUID], options: nil)
    }
    
    /*
     * This function is called when a peripheral has been discovered by mobileDevice.scanForPeripherals().
     * It triggers the 'didConnect' callback.
     */
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        mobileDevice.stopScan()
        let name = String(describing: peripheral.name)
        print("The following peripheral was found:")
        print("  name: \(name)")
        print("  advertisement: \(advertisementData)")
        blePeripheral = peripheral
        blePeripheral!.delegate = self
        mobileDevice.connect(blePeripheral!, options: nil)  // triggers 'didConnect' callback
    }
    
    /*
     * This function is called each time a peripheral has been connected to by mobileDevice.connect(). It
     * triggers the 'didDiscoverServices' callback.
     */
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        if peripheral == blePeripheral {
            print("Connected to peripheral: \(String(describing: peripheral))")
            blePeripheral!.discoverServices([BLE_Service_UUID]) // triggers 'didDiscoverServices' callback
        }
    }
    
    /*
     * This function is called each time peripheral services are discovered. It triggers
     * the 'didDiscoverCharacteristicsFor' callback.
     */
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            let reason = String(describing: error!.localizedDescription)
            print("Error discovering services: \(reason)")
            disconnect()
            return
        }
        guard let services = peripheral.services else {
            // No services found, keep trying...
            return
        }
        print("Found \(services.count) services.")
        for service in services {
            print("Found service: \(service.uuid)")
            if service.uuid.isEqual(BLE_Service_UUID)  {
                peripheral.discoverCharacteristics([
                    BLE_CharacteristicWrite_UUID,
                    BLE_CharacteristicNotify_UUID
                ], for: service) // triggers didDiscoverCharacteristicsFor
            }
        }
    }
    
    /*
     * This function is called each time characteristics for a peripheral service are discovered
     */
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            self.error = "Error discovering characteristics: \(error!.localizedDescription)"
            disconnect()
            return
        }
        guard let characteristics = service.characteristics else {
            // No characteristics found, keep trying...
            return
        }
        print("Found \(characteristics.count) characteristics.")
        for characteristic in characteristics {
            if characteristic.uuid.isEqual(BLE_CharacteristicWrite_UUID)  {
                print("Found write characteristic: \(characteristic.uuid)")
                writeCharacteristic = characteristic
            } else if characteristic.uuid.isEqual(BLE_CharacteristicNotify_UUID) {
                print("Found notify characteristic: \(characteristic.uuid)")
                notifyCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: notifyCharacteristic!) // triggers didUpdateNotificationStateFor
            }
        }
    }
    
    /*
     * This function is called each time the notification state on the ArmorD peripheral service
     * changes.
     */
    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            self.error = "Error changing notification state:\(error!.localizedDescription)"
            disconnect()
            return
        }
        let uuid = characteristic.uuid
        guard characteristic.isNotifying else {
            self.error = "Unable to receive notifications from characteristic: \(uuid)"
            disconnect()
            return
        }
        print ("Notifications have begun for: \(uuid)")
        processBlock() // triggers 'didWriteValueFor' and 'didUpdateValueFor' callbacks
    }

    /*
     * This function sends the next block of the current request to the peripheral to be
     * processed.
     */
    func processBlock() {
        var buffer: [UInt8], length: Int;
        print("Processing block: \(block)")
        if (block > 0) {
            // the offset includes the header bytes
            let offset = block * ArmorDProxy.BLOCK_SIZE + 2
            
            // calculate the current block size
            length = min(request.count - offset, ArmorDProxy.BLOCK_SIZE)
            
            // concatenate a header and the current block bytes
            buffer = [0x00, UInt8(block)] + Array(request[offset ..< (offset + length)])
        } else {
            // calculate the size of the first block
            length = min(request.count, ArmorDProxy.BLOCK_SIZE + 2)

            // load the first block into the buffer
            buffer = Array(request[0..<length])  // includes the actual header
        }
        block -= 1  // decrement the block count
        let data = NSData(bytes: buffer, length: buffer.count)
        // triggers 'didWriteValueFor' and 'didUpdateValueFor' callbacks
        blePeripheral!.writeValue(data as Data, for: writeCharacteristic!, type: CBCharacteristicWriteType.withResponse)
        print("\(buffer.count) bytes were written to the ArmorD device.")
    }

    /*
     * This function is called each time a request was sent to the peripheral. It is just for tracking
     * purposes, the 'didUpdateValueFor' callback will be called next if no error occurred.
     */
    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            self.error = String(describing: error!.localizedDescription)
            disconnect()
            return
        }
        print("Request sent.")
    }
    
    /*
     * This function is called each time a response is received from the ArmorD peripheral. It will either
     * process the next block in the request or initiate the processing of the next request.
     */
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        print("A response was received from the ArmorD peripheral.")
        guard error == nil else {
            self.error = "An error occurred while processing the request: \(String(describing: error!.localizedDescription))"
            disconnect()
            return
        }
        guard characteristic == notifyCharacteristic else {
            print("Received an unexpected characteristic update notification: \(characteristic)")
            //disconnect()  see if this ever happens before deciding whether this is necessary
            return
        }
        let characteristicData = characteristic.value!
        print("Characteristic Data: \(characteristicData)")
        result = [UInt8](characteristicData)
        guard result!.count > 1 || result![0] != 255 else {
            self.error = "ArmorD rejected the request with a status: \(result![0])"
            disconnect()
            return
        }
        guard block >= 0 else {
            print("ArmorD completed the processing of the request.")
            disconnect()
            return
        }
        print("ArmorD is ready for the next block of the request.")
        processBlock() // triggers another didUpdateValueFor
    }

    /*
     * Disconnect from the ArmorD peripheral. It triggers the 'didDisconnectPeripheral' callback.
     */
    func disconnect() {
        print("Disconnecting from the ArmorD peripheral...")
        mobileDevice.cancelPeripheralConnection(blePeripheral!)
    }

    /*
     * This function is called each time the peripheral has been disconnected. It tells the flow
     * controller the outcome of the request which may result in another request being initiated.
     */
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard error == nil else {
            let reason = String(describing: error!.localizedDescription)
            print("Error while disconnecting peripheral: \(reason)")
            // can't really do anything about it, except assume we are disconnected...
            return
        }
        print("Disconnected from peripheral: \(String(describing: peripheral))")
        guard self.error == nil else {
            print("Error while processing request: \(String(describing: self.error))")
            controller.stepFailed(device: self, error: self.error!)  // may trigger processRequest()
            self.error = nil  // must reset this before next request occurs
            return
        }
        print("The request was successfully processed: \(String(describing: result))")
        controller.nextStep(device: self, result: result)  // may trigger processRequest()
        result = nil  // must reset this before next request occurs
    }
    
}
