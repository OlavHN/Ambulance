#include "mbed.h"
#include "BLEDevice.h"
#include "HeartRateService.h"
#include "DeviceInformationService.h"
#include "HealthThermometerService.h"

/* Enable the following if you need to throttle the connection interval. This has
 * the effect of reducing energy consumption after a connection is made;
 * particularly for applications where the central may want a fast connection
 * interval.*/
#define UPDATE_PARAMS_FOR_LONGER_CONNECTION_INTERVAL 0

BLEDevice  ble;
AnalogIn temperaturePin(P0_2);
AnalogIn heart(P0_1);
DigitalOut led1(LED1);

const static char     DEVICE_NAME[]        = "HlthHckr";
static const uint16_t uuid16_list[]        = {GattService::UUID_HEART_RATE_SERVICE,
                                              GattService::UUID_DEVICE_INFORMATION_SERVICE};
static volatile bool  triggerSensorPolling = false;

void disconnectionCallback(Gap::Handle_t handle, Gap::DisconnectionReason_t reason)
{
    ble.startAdvertising(); // restart advertising
}

void periodicCallback(void)
{
    led1 = !led1; /* Do blinky on LED1 while we're waiting for BLE events */

    /* Note that the periodicCallback() executes in interrupt context, so it is safer to do
     * heavy-weight sensor polling from the main thread. */
    triggerSensorPolling = true;
}

void periodicCallback2(void)
{
    /*int hrVal = 0;
    int i;
    for (i = 0; i < 16; i++)
    {
        hrVal += heart.read_u16();
    }*/
    int hrVal =  heart.read_u16();//hrVal / 16;
    printf("%c", hrVal / 4);
}

int main(void)
{
    led1 = 1;
    Ticker ticker;
    //Ticker ticker2;
    //ticker2.attach(periodicCallback2, .005);
    ticker.attach(periodicCallback, 1); // blink LED every second

    ble.init();
    ble.onDisconnection(disconnectionCallback);

    /* Setup heart rate service. */
    uint8_t hrmCounter = 100; // init HRM to 100bps
    HeartRateService hrService(ble, hrmCounter, HeartRateService::LOCATION_FINGER);
    
    /* Setup temperature service. */
    float htCounter = 0.0f;
    HealthThermometerService htService(ble, htCounter, HealthThermometerService::LOCATION_FINGER);

    /* Setup auxiliary service. */
    DeviceInformationService deviceInfo(ble, "Ambulance Beacon", "Model1", "SN1", "hw-rev1", "fw-rev1", "soft-rev1");

    /* Setup advertising. */
    ble.accumulateAdvertisingPayload(GapAdvertisingData::BREDR_NOT_SUPPORTED | GapAdvertisingData::LE_GENERAL_DISCOVERABLE);
    ble.accumulateAdvertisingPayload(GapAdvertisingData::COMPLETE_LIST_16BIT_SERVICE_IDS, (uint8_t *)uuid16_list, sizeof(uuid16_list));
    ble.accumulateAdvertisingPayload(GapAdvertisingData::GENERIC_HEART_RATE_SENSOR);
    ble.accumulateAdvertisingPayload(GapAdvertisingData::GENERIC_THERMOMETER);
    ble.accumulateAdvertisingPayload(GapAdvertisingData::COMPLETE_LOCAL_NAME, (uint8_t *)DEVICE_NAME, sizeof(DEVICE_NAME));
    ble.setAdvertisingType(GapAdvertisingParams::ADV_CONNECTABLE_UNDIRECTED);
    ble.setAdvertisingInterval(1000);
    ble.startAdvertising();

    // infinite loop
    while (1) {
        float rtfloat = ((float)temperaturePin.read_u16() / 1024);
        float voltaget = rtfloat * 5;
        float temp = (voltaget - 0.5) * 100;
        temp = temp / 3.8;

        // Should be (read() * 3.3V) - 500mV to get the temperature in C
        // but no clue what goes on here, works fine on Arduino
        htCounter = temp;
        
        // check for trigger from periodicCallback()
        if (triggerSensorPolling && ble.getGapState().connected) {
            triggerSensorPolling = false;

            // Do blocking calls or whatever is necessary for sensor polling.
            // In our case, we simply update the HRM measurement. 
            hrmCounter++;
            //printf("Hello! 0x%04X \n", hr.read_u16());
            
            //  100 <= HRM bps <=175
            if (hrmCounter == 200) {
                hrmCounter = 100;
            }
            
            // update bps
            hrService.updateHeartRate(hrmCounter);
            htService.updateTemperature(htCounter);
        } else {
            ble.waitForEvent(); // low power wait for event
        }
    }
}
