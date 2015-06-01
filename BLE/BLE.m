//
//  BLE.m
//  Ambulance
//
//  Created by Olav Nymoen on 07/05/15.
//  Copyright (c) 2015 Facebook. All rights reserved.
//

#import "BLE.h"

@implementation BLE

@synthesize bridge = _bridge;

RCT_EXPORT_MODULE();

#pragma mark - CBCentralManagerDelegate

// method called whenever you have successfully connected to the BLE peripheral
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
  [peripheral setDelegate:self];
  [peripheral discoverServices:nil];
  //NSLog(NSString stringWithFormat:@"Connected: %@", peripheral.state == CBPeripheralStateConnected ? @"YES" : @"NO");
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral
                 error:(NSError *)error
{
  [self.bridge.eventDispatcher sendDeviceEventWithName:@"disconnect" body:@{@"error": [error localizedDescription]}];
}

// CBCentralManagerDelegate - This is called with the CBPeripheral class as its main input parameter. This contains most of the information there is to know about a BLE peripheral.
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
  NSString *localName = [advertisementData objectForKey:CBAdvertisementDataLocalNameKey];
  if ([localName length] > 0) {
    NSLog(@"Found the heart rate monitor: %@", localName);
    [self.centralManager stopScan];
    self.HRMPeripheral = peripheral;
    peripheral.delegate = self;
    [self.centralManager connectPeripheral:peripheral options:nil];
  }
}

// method called whenever the device state changes.
- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
  // Determine the state of the peripheral
  if ([central state] == CBCentralManagerStatePoweredOff) {
    NSLog(@"CoreBluetooth BLE hardware is powered off");
  }
  else if ([central state] == CBCentralManagerStatePoweredOn) {
    NSLog(@"CoreBluetooth BLE hardware is powered on and ready");
    NSArray *services = @[[CBUUID UUIDWithString:HRM_HEART_RATE_SERVICE_UUID], [CBUUID UUIDWithString:HRM_DEVICE_INFO_SERVICE_UUID]];
    [self.centralManager scanForPeripheralsWithServices:services options:nil];
  }
  else if ([central state] == CBCentralManagerStateUnauthorized) {
    NSLog(@"CoreBluetooth BLE state is unauthorized");
  }
  else if ([central state] == CBCentralManagerStateUnknown) {
    NSLog(@"CoreBluetooth BLE state is unknown");
  }
  else if ([central state] == CBCentralManagerStateUnsupported) {
    NSLog(@"CoreBluetooth BLE hardware is unsupported on this platform");
  }
}

#pragma mark - CBPeripheralDelegate

// CBPeripheralDelegate - Invoked when you discover the peripheral's available services.
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
  for (CBService *service in peripheral.services) {
    NSLog(@"Discovered service: %@", service.UUID);
    [peripheral discoverCharacteristics:nil forService:service];
  }
}

// Invoked when you discover the characteristics of a specified service.
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
  if ([service.UUID isEqual:[CBUUID UUIDWithString:HRM_HEART_RATE_SERVICE_UUID]])  {  // 1
    for (CBCharacteristic *aChar in service.characteristics)
    {
      // Request heart rate notifications
      if ([aChar.UUID isEqual:[CBUUID UUIDWithString:HRM_MEASUREMENT_CHARACTERISTIC_UUID]]) { // 2
        [self.HRMPeripheral setNotifyValue:YES forCharacteristic:aChar];
        NSLog(@"Found heart rate measurement characteristic");
      }
      // Request body sensor location
      else if ([aChar.UUID isEqual:[CBUUID UUIDWithString:HRM_BODY_LOCATION_CHARACTERISTIC_UUID]]) { // 3
        [self.HRMPeripheral readValueForCharacteristic:aChar];
        NSLog(@"Found body sensor location characteristic");
      }
    }
  }
  
  if ([service.UUID isEqual:[CBUUID UUIDWithString:HT_HEALTH_THERMOMETER_SERVICE_UUID]])  {  // 1
    for (CBCharacteristic *aChar in service.characteristics)
    {
      // Request heart rate notifications
      if ([aChar.UUID isEqual:[CBUUID UUIDWithString:HT_MEASUREMENT_CHARACTERISTIC_UUID]]) { // 2
        [self.HRMPeripheral setNotifyValue:YES forCharacteristic:aChar];
        NSLog(@"Found thermometer measurement characteristic");
      }
      // Request body sensor location
      else if ([aChar.UUID isEqual:[CBUUID UUIDWithString:HT_BODY_LOCATION_CHARACTERISTIC_UUID]]) { // 3
        [self.HRMPeripheral readValueForCharacteristic:aChar];
        NSLog(@"Found body sensor location characteristic");
      }
    }
  }
  
  // Retrieve Device Information Services for the Manufacturer Name
  if ([service.UUID isEqual:[CBUUID UUIDWithString:HRM_DEVICE_INFO_SERVICE_UUID]])  { // 4
    for (CBCharacteristic *aChar in service.characteristics)
    {
      if ([aChar.UUID isEqual:[CBUUID UUIDWithString:DEVICE_MANUFACTURER_NAME_CHARACTERISTIC_UUID]]) {
        [self.HRMPeripheral readValueForCharacteristic:aChar];
        NSLog(@"Found a device manufacturer name characteristic");
      }
    }
  }
}

// Invoked when you retrieve a specified characteristic's value, or when the peripheral device notifies your app that the characteristic's value has changed.
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
  // Updated value for heart rate measurement received
  if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:HRM_MEASUREMENT_CHARACTERISTIC_UUID]]) { // 1
    // Get the Heart Rate Monitor BPM (weird format stuff)
    NSData *data = [characteristic value];
    const uint8_t *reportData = [data bytes];
    uint16_t bpm = 0;
    if ((reportData[0] & 0x01) == 0) {          // 2
      // Retrieve the BPM value for the Heart Rate Monitor
      bpm = reportData[1];
    }
    else {
      bpm = CFSwapInt16LittleToHost(*(uint16_t *)(&reportData[1]));  // 3
    }
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"sensor" body:@{@"bpm": [NSString stringWithFormat:@"%i", bpm]}];
    //[self getHeartBPMData:characteristic error:error];
  }
  // Updated value for temp rate measurement received
  if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:HT_MEASUREMENT_CHARACTERISTIC_UUID]]) { // 1
    // Get the temp
    NSData *data = [characteristic value];
    const uint8_t *reportData = [data bytes];
    int32_t tempData = (int32_t)CFSwapInt32LittleToHost(*(uint32_t*)&reportData[1]);
    int8_t exponent = (int8_t)(tempData >> 24);
    int32_t mantissa = (int32_t)(tempData & 0x00FFFFFF);
    float temp = (float)(mantissa*pow(10, exponent));
    
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"sensor" body:@{@"temp": [NSString stringWithFormat:@"%.1f", temp]}];
    //[self getHeartBPMData:characteristic error:error];
  }
  // Retrieve the characteristic value for manufacturer name received
  if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:DEVICE_MANUFACTURER_NAME_CHARACTERISTIC_UUID]]) {  // 2
    NSString *manufacturerName = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"sensor" body:@{@"manufacturer": manufacturerName}];
    [self getManufacturerName:characteristic];
  }
  // Retrieve the characteristic value for the body sensor location received
  else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:HRM_BODY_LOCATION_CHARACTERISTIC_UUID]]) {  // 3
    [self getBodyLocation:characteristic];
  }
  
  // Add your constructed device information to your UITextView
  //self.deviceInfo.text = [NSString stringWithFormat:@"%@\n%@\n%@\n", self.connected, self.bodyData, self.manufacturer];  // 4
}

#pragma mark - CBCharacteristic helpers

// Instance method to get the heart rate BPM information
- (void) getHeartBPMData:(CBCharacteristic *)characteristic error:(NSError *)error
{
}
// Instance method to get the manufacturer name of the device
- (void) getManufacturerName:(CBCharacteristic *)characteristic
{
  
}
// Instance method to get the body location of the device
- (void) getBodyLocation:(CBCharacteristic *)characteristic
{
}

RCT_EXPORT_METHOD(scan)
{
  // Scan for all available CoreBluetooth LE devices
  CBCentralManager *centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
  
  self.centralManager = centralManager;
}

RCT_EXPORT_METHOD(test)
{
  NSLog(@"sending evt");
  [self.bridge.eventDispatcher sendDeviceEventWithName:@"evt" body:@{@"name": @"KAKE"}];
  
}

@end