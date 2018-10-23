//
//  Glucose.swift
//  Pods
//
//  Created by Kevin Tallevi on 7/8/16.
//
//

import Foundation
import CoreBluetooth
import CCBluetooth
import CCToolbox

var thisGlucose : Glucose?

@objc public enum transferError : Int {
    case reserved = 0,
    success,
    opCodeNotSupported,
    invalidOperator,
    operatorNotSupported,
    invalidOperand,
    noRecordsFound,
    abortUnsuccessful,
    procedureNotCompleted,
    operandNotSupported
    
    public var description: String {
        switch self {
        case .opCodeNotSupported:
            return NSLocalizedString("Op Code Not Supported", comment:"")
        case .invalidOperator:
            return NSLocalizedString("Invalid Operator", comment:"")
        case .operatorNotSupported:
            return NSLocalizedString("Operator Not Supported", comment:"")
        case .invalidOperand:
            return NSLocalizedString("Invalid Operand", comment:"")
        case .noRecordsFound:
            return NSLocalizedString("No Records Found", comment:"")
        case .abortUnsuccessful:
            return NSLocalizedString("Abort Unsuccessful", comment:"")
        case .procedureNotCompleted:
            return NSLocalizedString("Procedure Not Completed", comment:"")
        case .operandNotSupported:
            return NSLocalizedString("Operand Not Supported", comment:"")
        case .reserved:
            return NSLocalizedString("Reserved", comment:"")
        default:
            return NSLocalizedString("", comment:"")
        }
    }
    
}

@objc public protocol GlucoseProtocol {
    func numberOfStoredRecords(number: UInt16)
    func glucoseMeasurement(measurement:GlucoseMeasurement)
    func glucoseMeasurementContext(measurementContext:GlucoseMeasurementContext)
    func glucoseFeatures(features:GlucoseFeatures)
    func glucoseMeterConnected(meter: CBPeripheral)
    func glucoseMeterDisconnected(meter: CBPeripheral)
    func glucoseMeterDidTransferMeasurements(error: NSError?)
    func glucoseError(error: NSError)
}

@objc public protocol GlucoseMeterDiscoveryProtocol {
    func glucoseMeterDiscovered(glucoseMeter:CBPeripheral)
}

public class Glucose : NSObject {
    public weak var glucoseDelegate : GlucoseProtocol?
    public weak var glucoseMeterDiscoveryDelegate: GlucoseMeterDiscoveryProtocol?
    var peripheral : CBPeripheral? {
        didSet {
            if (peripheral != nil) { // don't wipe the UUID when we disconnect and clear the peripheral
                uuid = peripheral?.identifier.uuidString
                name = peripheral?.name
            }
        }
    }
    
    //public var serviceUUIDString:String = "1809"
    //ana change for thermometer is 1809
    public var serviceUUIDString:String = "1808"
    public var autoEnableNotifications:Bool = true
    public var allowDuplicates:Bool = false
    public var batteryProfileSupported:Bool = false
    public var glucoseFeatures:GlucoseFeatures!
    
    var peripheralNameToConnectTo : String?
    var servicesAndCharacteristics : [String: [CBCharacteristic]] = [:]
    var allowedToScanForPeripherals:Bool = false
    
    public internal(set) var uuid: String?
    public internal(set) var name: String? // local name
    public internal(set) var manufacturerName : String?
    public internal(set) var modelNumber : String?
    public internal(set) var serialNumber : String?
    public internal(set) var firmwareVersion : String?
    public internal(set) var softwareVersion : String?
    public internal(set) var hardwareVersion : String?
    
    public internal(set) var systemID : String? //Ana added this
    public internal(set) var hardwareRevision : String? //Ana added this
    public internal(set) var softwareRevision : String? //Ana added this
    public internal(set) var firmwareRevision : String? //Ana added this
    public internal(set) var partNumber: String? //Ana added this
    public internal(set) var protocolProdSpec: String? //Ana added this
    public internal(set) var gmdn: String? //Ana added this
    public internal(set) var unspecified: String? //Ana added this
    
    public internal(set) var regCertDataList : NSData? //Ana added this
    public internal(set) var dateTimeValue : String? //Ana added this
    public internal(set) var currentSensorDateTime : Date? //Ana added this
    
    public internal(set) var continuaVersion : UInt32? //Ana added this
    public internal(set) var majorVersion : UInt32? //Ana added this
    public internal(set) var minorVersion : UInt32? //Ana added this
    public internal(set) var certDeviceCount : UInt32? //Ana added this
    public internal(set) var certDeviceClass: Int? //Ana added this
    public internal(set) var regStatusAuthBody: UInt32? //Ana added this
    public internal(set) var regStatusBit: UInt32? //Ana added this
    
    public internal(set) var tCode:Int = 4 //Ana added this
    
    public var sensorCurrentTime: NSData?  //Ana added this
    
    public class func sharedInstance() -> Glucose {
        if thisGlucose == nil {
            thisGlucose = Glucose()
        }
        return thisGlucose!
    }
    
    public override init() {
        super.init()
        print("Glucose#init")
        self.configureBluetoothParameters()
    }
    
    public init(peripheral:CBPeripheral!) {
        super.init()
        print("Glucose#init[peripheral]")
        self.peripheral = peripheral
        self.configureBluetoothParameters()
        self.connectToGlucoseMeter(glucoseMeter: peripheral)
    }
    
    public init(peripheralName:String) {
        super.init()
        print("Glucose#init")
        self.peripheralNameToConnectTo = peripheralName
        self.configureBluetoothParameters()
    }
    
    public init(uuidString:String) {
        super.init()
        print("Glucose#init")
        self.configureBluetoothParameters()
        self.reconnectToGlucoseMeter(uuidString: uuidString)
    }
    
    func configureBluetoothParameters() {
        //Bluetooth.sharedInstance().serviceUUIDString = "1809"
        //ana change for thermometer is 1809
        Bluetooth.sharedInstance().serviceUUIDString = "1808"
        Bluetooth.sharedInstance().allowDuplicates = false
        Bluetooth.sharedInstance().autoEnableNotifications = true // FIXME: should be configured or use delegate, not both
        Bluetooth.sharedInstance().bluetoothDelegate = self
        Bluetooth.sharedInstance().bluetoothPeripheralDelegate = self
        Bluetooth.sharedInstance().bluetoothServiceDelegate = self
        Bluetooth.sharedInstance().bluetoothCharacteristicDelegate = self
    }
    
    public func connectToGlucoseMeter(glucoseMeter: CBPeripheral) {
        //self.peripheral = glucoseMeter
        Bluetooth.sharedInstance().stopScanning()
        Bluetooth.sharedInstance().connectPeripheral(glucoseMeter)
    }
    
    public func reconnectToGlucoseMeter(uuidString: String) {
        Bluetooth.sharedInstance().stopScanning()
        Bluetooth.sharedInstance().reconnectPeripheral(uuidString)
    }
    
    public func disconnectGlucoseMeter() {
        if let peripheral = self.peripheral {
            Bluetooth.sharedInstance().disconnectPeripheral(peripheral)
        }
    }
    
    func parseFeaturesResponse(data: NSData) {
        self.glucoseFeatures = GlucoseFeatures(data: data)
        glucoseDelegate?.glucoseFeatures(features: self.glucoseFeatures)
    }
    
    func parseRACPReponse(data:NSData) {
        print("parsing RACP response: \(data)")
        let hexString = data.toHexString()
        let hexStringHeader = hexString.subStringWithRange(0, to: 2)
        print("hexStringHeader: \(hexStringHeader)")
        
        if(hexStringHeader == numberOfStoredRecordsResponse) {
            print("numberOfStoredRecordsResponse")
            let numberOfStoredRecordsStr = data.swapUInt16Data().toHexString().subStringWithRange(4, to: 8)
            let numberOfStoredRecords = UInt16(strtoul(numberOfStoredRecordsStr, nil, 16))
            glucoseDelegate?.numberOfStoredRecords(number: numberOfStoredRecords)
        }
        if(hexStringHeader == responseCode) {
            print("responseCode")
            var hexStringData = hexString.subStringWithRange(4, to: hexString.characters.count)
            print("hexStringData: \(hexStringData)")
            
            let responseStatusString = hexStringData.subStringWithRange(2, to: hexStringData.characters.count)
            
            switch responseStatusString {
            case "01": //Success
                glucoseDelegate?.glucoseMeterDidTransferMeasurements(error: nil)
            default:
                let responseStatusInt: Int? = Int(responseStatusString)
                let transferErrorString = transferError(rawValue: responseStatusInt!)?.description
                
                let userInfo: [NSObject : AnyObject] =
                    [
                        NSLocalizedDescriptionKey as NSObject :  NSLocalizedString("Transfer Error", value: transferErrorString!, comment: "") as AnyObject,
                        ]
                let err = NSError(domain: "CCGlucose", code: responseStatusInt!, userInfo: userInfo)
                glucoseDelegate?.glucoseMeterDidTransferMeasurements(error: err)
            }
        }
    }
    
    func parseGlucoseMeasurement(data:NSData) {
        // ensure the first byte is not zero before parsing the data
        var values = [UInt8](repeating:0, count: 1)
        data.getBytes(&values, length: 1)
        
        if (values[0] != 0) {
            let glucoseMeasurement = GlucoseMeasurement(data: data)
            glucoseDelegate?.glucoseMeasurement(measurement: glucoseMeasurement)
        }
    }
    
    func parseGlucoseMeasurementContext(data:NSData) {
        var values = [UInt8](repeating:0, count: 1)
        data.getBytes(&values, length: 1)
        
        if (values[0] != 0) {
            let glucoseMeasurementContext = GlucoseMeasurementContext(data: data)
            glucoseDelegate?.glucoseMeasurementContext(measurementContext: glucoseMeasurementContext)
        }
    }
    
    public func readNumberOfRecords() {
        print("Glucose#readNumberOfRecords")
        let data = readNumberOfStoredRecords.dataFromHexadecimalString()
        if let peripheral = self.peripheral {
            Bluetooth.sharedInstance().writeCharacteristic(peripheral.findCharacteristicByUUID(recordAccessControlPointCharacteristic)!, data: data! as Data)
        }
    }
    
    public func downloadAllRecords() {
        print("Glucose#downloadAllRecords")
        let data = readAllStoredRecords.dataFromHexadecimalString()
        if let peripheral = self.peripheral {
            Bluetooth.sharedInstance().writeCharacteristic(peripheral.findCharacteristicByUUID(recordAccessControlPointCharacteristic)!, data: data! as Data)
        }
    }
    
    public func downloadRecordNumber(recordNumber: Int) {
        let commandPrefix = "010401"
        var recordNumberInt = recordNumber
        let recordNumberData = NSData(bytes: &recordNumberInt, length: MemoryLayout<UInt16>.size)
        let recordNumberHex = String(recordNumberData.toHexString())
        
        let command = commandPrefix +
            (recordNumberHex?.subStringWithRange(0, to: 2))! +
            (recordNumberHex?.subStringWithRange(2, to: 4))! +
            (recordNumberHex?.subStringWithRange(0, to: 2))! +
            (recordNumberHex?.subStringWithRange(2, to: 4))!
        
        print("command: \(command)")
        let commandData = command.dataFromHexadecimalString()
        if let peripheral = self.peripheral {
            Bluetooth.sharedInstance().writeCharacteristic(peripheral.findCharacteristicByUUID(recordAccessControlPointCharacteristic)!, data: commandData! as Data)
        }
    }
    
    public func downloadRecordsWithRange(from: Int , to: Int) {
        let commandPrefix = "010401"
        var recordNumberFromInt = from
        let recordNumberFromData = NSData(bytes: &recordNumberFromInt, length: MemoryLayout<UInt16>.size)
        let recordNumberFromHex = String(recordNumberFromData.toHexString())
        
        var recordNumberToInt = to
        let recordNumberToData = NSData(bytes: &recordNumberToInt, length: MemoryLayout<UInt16>.size)
        let recordNumberToHex = String(recordNumberToData.toHexString())
        
        let command = commandPrefix +
            (recordNumberFromHex?.subStringWithRange(0, to: 2))! +
            (recordNumberFromHex?.subStringWithRange(2, to: 4))! +
            (recordNumberToHex?.subStringWithRange(0, to: 2))! +
            (recordNumberToHex?.subStringWithRange(2, to: 4))!
        
        print("command: \(command)")
        let commandData = command.dataFromHexadecimalString()
        if let peripheral = self.peripheral {
            Bluetooth.sharedInstance().writeCharacteristic(peripheral.findCharacteristicByUUID(recordAccessControlPointCharacteristic)!, data: commandData! as Data)
        }
    }
    
    public func downloadRecordsGreaterThanAndEqualTo(recordNumber: Int) {
        let commandPrefix = "010301"
        var recordNumberInt = recordNumber
        let recordNumberData = NSData(bytes: &recordNumberInt, length: MemoryLayout<UInt16>.size)
        let recordNumberHex = String(recordNumberData.toHexString())
        
        let command = commandPrefix +
            (recordNumberHex?.subStringWithRange(0, to: 2))! +
            (recordNumberHex?.subStringWithRange(2, to: 4))!
        
        print("command: \(command)")
        let commandData = command.dataFromHexadecimalString()
        if let peripheral = self.peripheral {
            Bluetooth.sharedInstance().writeCharacteristic(peripheral.findCharacteristicByUUID(recordAccessControlPointCharacteristic)!, data: commandData! as Data)
        }
    }
    
    public func downloadRecordsLessThanAndEqualTo(recordNumber: Int) {
        let commandPrefix = "010201"
        var recordNumberInt = recordNumber
        let recordNumberData = NSData(bytes: &recordNumberInt, length: MemoryLayout<UInt16>.size)
        let recordNumberHex = String(recordNumberData.toHexString())
        
        let command = commandPrefix +
            (recordNumberHex?.subStringWithRange(0, to: 2))! +
            (recordNumberHex?.subStringWithRange(2, to: 4))!
        
        print("command: \(command)")
        let commandData = command.dataFromHexadecimalString()
        if let peripheral = self.peripheral {
            Bluetooth.sharedInstance().writeCharacteristic(peripheral.findCharacteristicByUUID(recordAccessControlPointCharacteristic)!, data: commandData! as Data)
        }
    }
    
    public func downloadFirstRecord() {
        let command = "0105"
        print("command: \(command)")
        let commandData = command.dataFromHexadecimalString()
        if let peripheral = self.peripheral {
            Bluetooth.sharedInstance().writeCharacteristic(peripheral.findCharacteristicByUUID(recordAccessControlPointCharacteristic)!, data: commandData! as Data)
        }
    }
    
    public func downloadLastRecord() {
        let command = "0106"
        print("command: \(command)")
        let commandData = command.dataFromHexadecimalString()
        if let peripheral = self.peripheral {
            Bluetooth.sharedInstance().writeCharacteristic(peripheral.findCharacteristicByUUID(recordAccessControlPointCharacteristic)!, data: commandData! as Data)
        }
    }
    
    public func readGlucoseFeatures() {
        print("Glucose#readGlucoseFeatures")
        if let peripheral = self.peripheral {
            Bluetooth.sharedInstance().readCharacteristic(peripheral.findCharacteristicByUUID(glucoseFeatureCharacteristic)!)
        }
    }
    
    //Ana created this function
    public func parseReqCertInfo() {
        let certInfo = self.regCertDataList
        var value: UInt32 = 0
        var valueHex: UInt64 = 0
        var indexCounter = 4
        
        
        //Continua version
        let counterCertInfo = certInfo?.dataRange(indexCounter, Length: 1)
        counterCertInfo?.getBytes(&value, length: 1)
        self.continuaVersion = UInt32(value)
        indexCounter += 4
        print("continua version \(String(describing: continuaVersion))")
        
        //major version
        let counterMajorVersion = certInfo?.dataRange(indexCounter, Length: 1)
        counterMajorVersion?.getBytes(&value, length: 1)
        self.majorVersion = UInt32(value)
        indexCounter += 1
        print("major version \(String(describing: majorVersion))")
        
        //minor version
        let counterMinorVersion = certInfo?.dataRange(indexCounter, Length: 1)
        counterMinorVersion?.getBytes(&value, length: 1)
        self.minorVersion = UInt32(value)
        indexCounter += 2
        print("minor version \(String(describing: minorVersion))")
        
        //certified device list count
        let counterCertDeviceCount = certInfo?.dataRange(indexCounter, Length: 1)
        counterCertDeviceCount?.getBytes(&value, length: 1)
        self.certDeviceCount = UInt32(value)
        indexCounter += 3
        print("certified device list count \(String(describing: certDeviceCount))")
        
        //certified device class
        let counterCertDeviceClass = certInfo?.dataRange(indexCounter, Length: 2)
        
        var pom: String = String(describing: counterCertDeviceClass!)
        pom = pom.replacingOccurrences(of: "<", with: "")
        pom = pom.replacingOccurrences(of: ">", with: "")
        self.certDeviceClass = Int(pom, radix: 16)!
        indexCounter += 2
        print("certified device class \(String(describing: certDeviceClass))")
        
        //regulation status auth-body
        let counterRegStatusAuthBody = certInfo?.dataRange(indexCounter, Length: 1)
        counterRegStatusAuthBody?.getBytes(&value, length: 1)
        self.regStatusAuthBody = UInt32(value)
        indexCounter += 5
        print("reg status auth-body \(String(describing: regStatusAuthBody))")
        
        //regulation status bit set
        let counterRegStatusBit = certInfo?.dataRange(indexCounter, Length: 1)
        counterRegStatusBit?.getBytes(&value, length: 1)
        self.regStatusBit = UInt32(value)
        print("reg status auth-body \(String(describing: regStatusBit))")
        
    }
    
    //Ana created this function
    public func parseDateTime() {
        let data = self.sensorCurrentTime
        
        var indexCounter = 0
        print("parseDateTime [indexCounter:\(indexCounter)]")
        
        let calendar = Calendar(identifier: Calendar.Identifier.gregorian)
        let dateComponents = NSDateComponents()
        
        let yearData = data?.dataRange(indexCounter, Length: 2)
        print("yearData: \(String(describing: yearData))")
        let swappedYearData = yearData?.swapUInt16Data()
        
        swappedYearData?.shortFloatToFloat()
        print("swappedYearData: \(String(describing: swappedYearData))")
        
        let swappedYearString = swappedYearData?.toHexString()
        dateComponents.year = Int(strtoul(swappedYearString, nil, 16))
        indexCounter += 2
        
        // Month
        let monthData = data?.dataRange(indexCounter, Length: 1)
        print("monthData: \(String(describing: monthData))")
        dateComponents.month = Int(strtoul(monthData?.toHexString(), nil, 16))
        indexCounter += 1
        
        // Day
        let dayData = data?.dataRange(indexCounter, Length: 1)
        print("dayData: \(String(describing: dayData))")
        dateComponents.day = Int(strtoul(dayData?.toHexString(), nil, 16))
        indexCounter += 1
        
        // Hours
        let hoursData = data?.dataRange(indexCounter, Length: 1)
        print("hoursData: \(String(describing: hoursData))")
        dateComponents.hour = Int(strtoul(hoursData?.toHexString(), nil, 16))
        indexCounter += 1
        
        // Minutes
        let minutesData = data?.dataRange(indexCounter, Length: 1)
        print("minutesData: \(String(describing: minutesData))")
        dateComponents.minute = Int(strtoul(minutesData?.toHexString(), nil, 16))
        indexCounter += 1
        
        // Seconds
        let secondsData = data?.dataRange(indexCounter, Length: 1)
        print("secondsData: \(String(describing: secondsData))")
        dateComponents.second = Int(strtoul(secondsData?.toHexString(), nil, 16))
        indexCounter += 1
        
        print("dateComponents: \(dateComponents)")
        
        let measurementDate = calendar.date(from: dateComponents as DateComponents)
        print("measurementDateAna: \(String(describing: measurementDate))")
        self.currentSensorDateTime = measurementDate
    }
}

extension Glucose: BluetoothProtocol {
    public func scanForGlucoseMeters() {
        Bluetooth.sharedInstance().startScanning(self.allowDuplicates)
        
        // FIXME: if start scanning should be called twice, then this requires a comment
        if(self.allowedToScanForPeripherals) {
            Bluetooth.sharedInstance().startScanning(self.allowDuplicates)
        }
    }
    
    public func bluetoothIsAvailable() {
        self.allowedToScanForPeripherals = true
        
        if let peripheral = self.peripheral {
            Bluetooth.sharedInstance().connectPeripheral(peripheral)
        } else {
            Bluetooth.sharedInstance().startScanning(self.allowDuplicates)
        }
    }
    
    public func bluetoothIsUnavailable() {
        
    }
    
    public func bluetoothError(_ error:Error?) {
        
    }
}

extension Glucose: BluetoothPeripheralProtocol {
    public func didDiscoverPeripheral(_ peripheral:CBPeripheral) {
        print("Glucose#didDiscoverPeripheral")
        // !!!: keep a reference to the peripheral to avoid the error:
        // "API MISUSE: Cancelling connection for unused peripheral <private>, Did you forget to keep a reference to it?"
        self.peripheral = peripheral
        if (self.peripheralNameToConnectTo != nil) {
            if (peripheral.name == self.peripheralNameToConnectTo) {
                Bluetooth.sharedInstance().connectPeripheral(peripheral)
            }
        } else {
            glucoseMeterDiscoveryDelegate?.glucoseMeterDiscovered(glucoseMeter: peripheral)
        }
    }
    
    public func didConnectPeripheral(_ cbPeripheral:CBPeripheral) {
        print("Glucose#didConnectPeripheral")
        self.peripheral = cbPeripheral
        glucoseDelegate?.glucoseMeterConnected(meter: cbPeripheral)
        
        Bluetooth.sharedInstance().discoverAllServices(cbPeripheral)
    }
    
    public func didDisconnectPeripheral(_ cbPeripheral: CBPeripheral) {
        self.peripheral = nil
        glucoseDelegate?.glucoseMeterDisconnected(meter: cbPeripheral)
    }
}

extension Glucose: BluetoothServiceProtocol {
    public func didDiscoverServices(_ services: [CBService]) {
        print("Glucose#didDiscoverServices - \(services)")
    }
    
    public func didDiscoverServiceWithCharacteristics(_ service:CBService) {
        print("didDiscoverServiceWithCharacteristics - \(service.uuid.uuidString)")
        servicesAndCharacteristics[service.uuid.uuidString] = service.characteristics
        
        for characteristic in service.characteristics! {
            print("reading \(characteristic.uuid.uuidString)")
            DispatchQueue.global(qos: .background).async {
                self.peripheral?.readValue(for: characteristic)
            }
        }
    }
}

extension Glucose: BluetoothCharacteristicProtocol {
    public func didUpdateValueForCharacteristic(_ cbPeripheral: CBPeripheral, characteristic: CBCharacteristic) {
        print("Glucose#didUpdateValueForCharacteristic: \(characteristic) value:\(String(describing: characteristic.value))")
        if(characteristic.uuid.uuidString == glucoseFeatureCharacteristic) {
            self.parseFeaturesResponse(data: characteristic.value! as NSData)
        } else if(characteristic.uuid.uuidString == recordAccessControlPointCharacteristic) {
            self.parseRACPReponse(data: characteristic.value! as NSData)
        } else if(characteristic.uuid.uuidString == glucoseMeasurementCharacteristic) {
            self.parseGlucoseMeasurement(data: characteristic.value! as NSData)
        } else if(characteristic.uuid.uuidString == glucoseMeasurementContextCharacteristic) {
            self.parseGlucoseMeasurementContext(data: characteristic.value! as NSData)
        } else if (characteristic.uuid.uuidString == "2A19") {
            batteryProfileSupported = true
        } else if (characteristic.uuid.uuidString == "2A29") {
            self.manufacturerName = String(data: characteristic.value!, encoding: .utf8)
            print("manufacturerName: \(String(describing: self.manufacturerName))")
        } else if (characteristic.uuid.uuidString == "2A24") {
            self.modelNumber = String(data: characteristic.value!, encoding: .utf8)
            print("modelNumber: \(String(describing: self.modelNumber))")
        } else if (characteristic.uuid.uuidString == "2A25") {
            self.serialNumber = String(data: characteristic.value!, encoding: .utf8)
            print("serialNumber: \(String(describing: self.serialNumber!))")
        } else if (characteristic.uuid.uuidString == "2A26") {
            self.firmwareVersion = String(data: characteristic.value!, encoding: .utf8)
            self.firmwareRevision = String(data: characteristic.value!, encoding: .utf8)
            print("firmwareVersion: \(String(describing: self.firmwareVersion))")
        } else if (characteristic.uuid.uuidString == "2A19") {
            print("battery level")
        }
        if (characteristic.uuid.uuidString == "2A27") {
            self.hardwareVersion = String(data: characteristic.value!, encoding: .utf8)
            self.hardwareRevision = String(data: characteristic.value!, encoding: .utf8)
            print("hardwareVersion: \(String(describing: self.hardwareVersion))")
        }
        if (characteristic.uuid.uuidString == "2A28") {
            self.softwareVersion = String(data: characteristic.value!, encoding: .utf8)
            self.softwareRevision = String(data: characteristic.value!, encoding: .utf8)
            print("softwareVersion: \(String(describing: self.softwareVersion))")
        }
        if (characteristic.uuid.uuidString == "2A2A"){
            self.regCertDataList = characteristic.value! as NSData
            //print("regCertDataList: \(String(describing: self.regCertDataList))")
        }
        if (characteristic.uuid.uuidString == "2A08"){
            self.sensorCurrentTime = characteristic.value! as NSData
        }
        if (characteristic.uuid.uuidString == "2A23") {
            //self.systemID = String(data: characteristic.value!, encoding: .unicode)
            self.systemID = "1111111"
            print("systemID: \(String(describing: self.systemID))")
        }
    }
    
    public func didUpdateNotificationStateFor(_ characteristic:CBCharacteristic) {
        print("Glucose#didUpdateNotificationStateFor characteristic: \(characteristic.uuid.uuidString)")
        if(characteristic.uuid.uuidString == recordAccessControlPointCharacteristic) {
            readGlucoseFeatures()
            readNumberOfRecords()
        }
    }
    
    public func didWriteValueForCharacteristic(_ cbPeripheral: CBPeripheral, didWriteValueFor descriptor:CBDescriptor) {
        
    }
}
