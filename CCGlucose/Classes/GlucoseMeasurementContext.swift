//
//  GlucoseMeasurementContext.swift
//  Pods
//
//  Created by Kevin Tallevi on 7/18/16.
//
//

import Foundation


// Based on Bluetooth spec:
// https://www.bluetooth.com/specifications/gatt/viewer?attributeXmlFile=org.bluetooth.characteristic.glucose_measurement_context.xml
public enum CarbohydrateID : Int {
    case reserved = 0,
    breakfast,
    lunch,
    dinner,
    snack,
    drink,
    supper,
    brunch
  
    public var description: String {
        switch self {
        case .breakfast:
            return NSLocalizedString("Breakfast", comment:"")
        case .lunch:
            return NSLocalizedString("Lunch", comment:"")
        case .dinner:
            return NSLocalizedString("Dinner", comment:"")
        case .snack:
            return NSLocalizedString("Snack", comment:"")
        case .drink:
            return NSLocalizedString("Drink", comment:"")
        case .supper:
            return NSLocalizedString("Supper", comment:"")
        case .brunch:
            return NSLocalizedString("Brunch", comment:"")
        case .reserved:
            return NSLocalizedString("Reserved", comment:"")
        }
    }
    
}

/// the confusing name 'Meal' is from the Bluetooth spec. It concerns the timing *around* a meal
/// 'Meal' is too generic (app might have a Meal class), so an alias is required
public typealias Meal = GlucoseMeasurementContextMeal

public enum GlucoseMeasurementContextMeal : Int {
    case reserved = 0,
    preprandialBeforeMeal,
    postprandialAfterMeal,
    fasting,
    casual,
    bedtime
    
    public var description: String {
        switch self {
        case .reserved:
            return NSLocalizedString("Reserved", comment:"")
        case .preprandialBeforeMeal:
            return NSLocalizedString("Preprandial (before meal)", comment:"")
        case .postprandialAfterMeal:
            return NSLocalizedString("Postprandial (after meal)", comment:"")
        case .fasting:
            return NSLocalizedString("Fasting", comment:"")
        case .casual:
            return NSLocalizedString("Casual", comment:"")
        case .bedtime:
            return NSLocalizedString("Bedtime", comment:"")
        }
    }
}


enum Tester : String {
    case reserved = "Reserved",
    isSelf = "Self",
    healthCareProfessional = "Health Care Professional",
    labTest = "Lab test",
    testerValueNotAvailable = "Tester value not available"
    
    static let allValues = [reserved, isSelf, healthCareProfessional, labTest, testerValueNotAvailable]
}

enum Health : String {
    case reserved = "Reserved",
    minorHealthIssues = "Minor Health Issues",
    majorHealthIssues = "Major Health Issues",
    duringMenses = "During menses",
    underStress = "Under stress",
    noHealthIssues = "No health issues",
    healthValueNotAvailable = "Health value not available"
    
    static let allValues = [reserved, minorHealthIssues, duringMenses, underStress, noHealthIssues, healthValueNotAvailable]
}

enum MedicationID : String {
    case reserved = "Reserved",
    rapidActingInsulin = "Rapid acting insulin",
    shortActingInsulin = "Short acting insulin",
    intermediateActingInsulin = "Intermediate acting insulin",
    longActingInsulin = "Long acting insulin",
    premixedInsulin = "Pre-mixed insulin"
    
    static let allValues = [reserved, rapidActingInsulin, shortActingInsulin, intermediateActingInsulin, longActingInsulin, premixedInsulin]
}

public enum MedicationValueUnit : Int {
    case kilograms = 0,
    liters
    
    public var description : String {
        switch self {
        case .kilograms:
            return NSLocalizedString("kilograms", comment: "")
        case .liters:
            return NSLocalizedString("liters", comment: "")
        }
    }
}

public class GlucoseMeasurementContext : NSObject {
    var packetData: NSData!
    
    public var sequenceNumber: UInt16!
    public var carbohydrateID: CarbohydrateID?
    public var carbohydrateWeight: Float?
    public var meal: Meal?
    public var tester: String?
    public var health: String?
    public var exerciseDuration: UInt16?
    public var exerciseIntensity: Int?
    public var medicationID: String?
    public var medication: Float?
    public var hbA1c: Float?
    
    let flagsRange = NSRange(location:0, length: 1)
    let sequenceNumberRange = NSRange(location:1, length: 2)
    
    public var medicationValueUnits: String! //ana made this public
    
    enum indexOffsets: Int {
        case flags = 0,
        sequenceNumber = 1,
        extendedFlags = 3,
        carbohydrateID,
        carbohydrateWeight,
        meal = 7,
        testerHealth,
        exerciseDuration,
        exerciseIntensity = 11,
        medicationID,
        medication,
        HbA1c = 15
    }
    
    struct Flag {
        var position: Int?
        var value: Int?
        var dataLength: Int?
    }
    var flags: [Flag] = []

    enum FlagBytes: Int {
        case carbohydrateIDAndCarbohydratePresent, mealPresent, testerHealthPresent, exerciseDurationAndExerciseIntensityPresent, medicationIDAndMedicationPresent, hbA1cPresent, extendedFlagsPresent, count
    }

    func parseFlags() {
        let flagsData = packetData.subdata(with: flagsRange) as NSData!
        let flagsString = flagsData?.toHexString()
        let flagsByte = Int(strtoul(flagsString, nil, 16))
        print("flags byte: \(flagsByte)")
        
        self.flags.append(Flag(position: FlagBytes.carbohydrateIDAndCarbohydratePresent.rawValue, value: flagsByte.bit(0), dataLength: 1))
        self.flags.append(Flag(position: FlagBytes.mealPresent.rawValue, value: flagsByte.bit(1), dataLength: 1))
        self.flags.append(Flag(position: FlagBytes.testerHealthPresent.rawValue, value: flagsByte.bit(2), dataLength: 1))
        self.flags.append(Flag(position: FlagBytes.exerciseDurationAndExerciseIntensityPresent.rawValue, value: flagsByte.bit(3), dataLength: 1))
        self.flags.append(Flag(position: FlagBytes.medicationIDAndMedicationPresent.rawValue, value: flagsByte.bit(4), dataLength: 1))
        self.flags.append(Flag(position: FlagBytes.hbA1cPresent.rawValue, value: flagsByte.bit(6), dataLength: 1))
        self.flags.append(Flag(position: FlagBytes.extendedFlagsPresent.rawValue, value: flagsByte.bit(7), dataLength: 1))
        
        self.medicationValueUnits = (MedicationValueUnit(rawValue: flagsByte.bit(5))?.description)!
    }
    
    func getOffset(max: Int) -> Int {
        //first 3 bytes are mandatory
        var offset: Int = 2
        
        for flag in flags {
            if flag.value == 1 {
                offset += flag.dataLength!
            }
        }
        
        if offset >= max {
            return max
        }
        
        return offset
    }
    
    func flagPresent(flagByte: Int) -> Int {
        for flag in flags {
            if flag.position == flagByte {
                return flag.value!
            }
        }
        
        return 0
    }

    func parseSequenceNumber() -> UInt16 {
        let sequenceNumberData: NSData! = packetData.subdata(with: sequenceNumberRange) as NSData!
        let swappedSequenceNumberData = sequenceNumberData.swapUInt16Data().toHexString()
        let sequenceNumber = UInt16(strtoul(swappedSequenceNumberData, nil, 16))
        print("sequenceNumber: \(sequenceNumber)")
        
        return sequenceNumber
    }

    init(data: NSData) {
        super.init()
        print("GlucoseMeasurementContext#init - \(self.packetData)")
        self.packetData = data
        
        parseFlags()
        self.sequenceNumber = parseSequenceNumber()

        if self.flagPresent(flagByte: FlagBytes.extendedFlagsPresent.rawValue).toBool()! {
            parseExtendedFlags()
        }
        
        if self.flagPresent(flagByte: FlagBytes.carbohydrateIDAndCarbohydratePresent.rawValue).toBool()! {
            parseCarbohydrateID()
            parseCarbohydrate()
        }
        
        if self.flagPresent(flagByte: FlagBytes.mealPresent.rawValue).toBool()! {
            parseMeal()
        }
        
        if self.flagPresent(flagByte: FlagBytes.testerHealthPresent.rawValue).toBool()! {
            parseTesterAndHealth()
        }
        
        if self.flagPresent(flagByte: FlagBytes.exerciseDurationAndExerciseIntensityPresent.rawValue).toBool()! {
            parseExerciseDuration()
            parseExerciseIntensity()
        }
        
        if self.flagPresent(flagByte: FlagBytes.medicationIDAndMedicationPresent.rawValue).toBool()! {
            parseMedicationID()
            parseMedication()
        }
        
        if self.flagPresent(flagByte: FlagBytes.hbA1cPresent.rawValue).toBool()! {
            parseHbA1c()
        }
    }
    

    func parseExtendedFlags() {
        //reserved for future use
    }
    
    func parseCarbohydrateID() {
        let offset: Int = getOffset(max: indexOffsets.carbohydrateID.rawValue)
        print("parseCarbohydrateID - offset: \(offset)")

        let carbohydrateIDData = packetData.subdata(with: NSRange(location:offset, length: 1)) as NSData!
        let carbohydrateIDByte = Int(strtoul(carbohydrateIDData?.toHexString(), nil, 16))
        print("carbohydrateIDByte: \(carbohydrateIDByte)")
        if let carbohydrateID = CarbohydrateID(rawValue:carbohydrateIDByte) {
            self.carbohydrateID = carbohydrateID
        }
        print("carbohydrateID: \(String(describing: carbohydrateID))")
    }
    
    func parseCarbohydrate() {
        let offset: Int = getOffset(max: indexOffsets.carbohydrateWeight.rawValue)
        print("parseCarbohydrate - offset: \(offset)")

        let carbohydrateData = packetData.subdata(with: NSRange(location:offset, length: 2)) as NSData!
        self.carbohydrateWeight = carbohydrateData?.shortFloatToFloat()
        print("carbohydrate: \(String(describing: self.carbohydrateWeight))")
    }
    
    func parseMeal() {
        let offset: Int = getOffset(max: indexOffsets.meal.rawValue)
        print("parseMeal - offset: \(offset)")
        
        let mealData = packetData.subdata(with: NSRange(location:offset, length: 1)) as NSData!
        let mealByte = Int(strtoul(mealData?.toHexString(), nil, 16))
        print("mealByte: \(mealByte)")
        if let meal = Meal(rawValue: mealByte) {
            self.meal = meal
        }
        print("meal: \(String(describing: meal))")
    }
    
    func parseTesterAndHealth() {
        let offset: Int = getOffset(max: indexOffsets.testerHealth.rawValue)
        print("parseMeal - offset: \(offset)")

        let testerData = packetData.subdata(with: NSRange(location:offset, length: 1)) as NSData!
        let tester = testerData?.lowNibbleAtPosition()
        let health = testerData?.highNibbleAtPosition()
        
        if(tester! > 3) {
            print("tester is reserved for future use")
            self.tester = "Reserved"
        } else {
            print("tester: \(Tester.allValues[tester!].rawValue)")
            self.tester = Tester.allValues[tester!].rawValue
        }
        
        if(health! > 5) {
            print("health is reserved for future use")
            self.health = "Reserved"
        } else {
            print("health: \(Health.allValues[health!].rawValue)")
            self.health = Health.allValues[health!].rawValue
        }
    }
    
    func parseExerciseDuration() {
        let offset: Int = getOffset(max: indexOffsets.exerciseDuration.rawValue)
        print("parseExerciseDuration - offset: \(offset)")

        let exerciseDurationData = packetData.subdata(with: NSRange(location:offset, length: 2)) as NSData!
        let exerciseDurationInt : UInt16 = exerciseDurationData!.readInteger(0);
        print("exerciseDurationInt: \(exerciseDurationInt)")
        self.exerciseDuration = exerciseDurationInt
    }
    
    func parseExerciseIntensity() {
        let offset: Int = getOffset(max: indexOffsets.exerciseIntensity.rawValue)
        print("parseExerciseIntensity - offset: \(offset)")
        
        let exerciseIntensityData = packetData.subdata(with: NSRange(location:offset, length: 1)) as NSData!
        self.exerciseIntensity = Int(strtoul(exerciseIntensityData?.toHexString(), nil, 16))
        print("exercise intensity \(String(describing: self.exerciseIntensity))")
    }
    
    func parseMedicationID() {
        let offset: Int = getOffset(max: indexOffsets.medicationID.rawValue)
        print("parseMedicationID - offset: \(offset)")
        
        let medicationIDData = packetData.subdata(with: NSRange(location:offset, length: 1)) as NSData!
        let medicationIDByte = Int(strtoul(medicationIDData?.toHexString(), nil, 16))
        
        if(medicationIDByte > 5) {
            self.medicationID = "Reserved"
        } else {
            print("medicationID: \(MedicationID.allValues[medicationIDByte].rawValue)")
            self.medicationID = MedicationID.allValues[medicationIDByte].rawValue
        }
    }
    
    func parseMedication() {
        let offset: Int = getOffset(max: indexOffsets.medication.rawValue)
        print("parseMedication - offset: \(offset)")
        
        let medicationData = packetData.subdata(with: NSRange(location:offset, length: 2)) as NSData!
        self.medication = medicationData?.shortFloatToFloat()
        print("medication \(String(describing: self.medication))")
    }
    
    func parseHbA1c() {
        let offset: Int = getOffset(max: indexOffsets.HbA1c.rawValue)
        print("parseMedication - offset: \(offset)")
        
        let hbA1cData = packetData.subdata(with: NSRange(location:offset, length: 2)) as NSData!
        self.hbA1c = hbA1cData?.shortFloatToFloat()
        print("hbA1c \(String(describing: self.hbA1c))")
    }
}
