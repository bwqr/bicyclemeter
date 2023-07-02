#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include "sample.h"

#define SERVICE_UUID        "FFE0"
#define CHARACTERISTIC_UUID "FFE1"

SampleState SAMPLE_STATE = {};

BLECharacteristic *pCharacteristic;
BLEService *pService;
BLEServer *pServer;
BLEAdvertising *pAdvertising;

void setup() {
    Serial.begin(115200);
    
    BLEDevice::init("ESP32");
    pServer = BLEDevice::createServer();
    pService = pServer->createService(SERVICE_UUID);
    pCharacteristic = pService->createCharacteristic(
        CHARACTERISTIC_UUID,
        BLECharacteristic::PROPERTY_READ |
        BLECharacteristic::PROPERTY_WRITE |
        BLECharacteristic::PROPERTY_NOTIFY
    );
    
    pService->start();
    pAdvertising = BLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(SERVICE_UUID);
    pAdvertising->setScanResponse(true);
    pAdvertising->setMinPreferred(0x06);  // functions that help with iPhone connections issue
    BLEDevice::startAdvertising();

    setup_sample();
}

void loop() {
    uint8_t bytes[BUF_LEN];
    
    SAMPLE_STATE.read_sensor();
    
    bool res = SAMPLE_STATE.filtered_sample(bytes);
    if (res == true && pServer->getConnectedCount() > 0) {
      send(bytes, BUF_LEN);
    }
    
    delay(24);
}

void send(uint8_t *bytes, size_t size) {
    pCharacteristic->setValue(bytes, size);
    pCharacteristic->notify(true);
}
