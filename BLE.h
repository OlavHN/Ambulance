//
//  BLE.h
//  Ambulance
//
//  Created by Olav Nymoen on 07/05/15.
//  Copyright (c) 2015 Facebook. All rights reserved.
//

@import CoreBluetooth;
@import QuartzCore;
#import "RCTBridgeModule.h"
#import "RCTBridge.h"
#import "RCTEventDispatcher.h"

#define HRM_DEVICE_INFO_SERVICE_UUID @"180A"
#define HRM_HEART_RATE_SERVICE_UUID @"180D"
#define HT_HEALTH_THERMOMETER_SERVICE_UUID @"1809"

#define HT_MEASUREMENT_CHARACTERISTIC_UUID @"2A1C"
#define HT_BODY_LOCATION_CHARACTERISTIC_UUID @"2A1D"

#define HRM_MEASUREMENT_CHARACTERISTIC_UUID @"2A37"
#define HRM_BODY_LOCATION_CHARACTERISTIC_UUID @"2A38"

#define DEVICE_MANUFACTURER_NAME_CHARACTERISTIC_UUID @"2A29"

@interface BLE : NSObject <RCTBridgeModule, CBCentralManagerDelegate, CBPeripheralDelegate>

@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, strong) CBPeripheral     *HRMPeripheral;

// Instance method to get the heart rate BPM information
- (void) getHeartBPMData:(CBCharacteristic *)characteristic error:(NSError *)error;

// Instance methods to grab device Manufacturer Name, Body Location
- (void) getManufacturerName:(CBCharacteristic *)characteristic;
- (void) getBodyLocation:(CBCharacteristic *)characteristic;

@end