#include <SoftwareSerial.h>
#include "esp32/sample.h"

SoftwareSerial HM10(2, 3); // RX = 2, TX = 3

SampleState SAMPLE_STATE = {};

void setup() {
  // initialize serial:
  Serial.begin(9600); 
  HM10.begin(9600); // set HM10 serial at 9600 baud rate

  while(!Serial); //if it is an Arduino Micro

  Serial.println("Setup");

  setup_sample();
}

void loop() {
    // run_at_commands();
    // delay(100);
    // return;
    uint8_t bytes[BUF_LEN];

    SAMPLE_STATE.read_sensor();

    bool res = SAMPLE_STATE.filtered_sample(bytes);
    if (res == true) {
        send(bytes, BUF_LEN);
    }

    delay(24);
}

void send(uint8_t *bytes, size_t size) {
    for (int i = 0; i < size; i++) {
        HM10.write(bytes[i]);
    }
    
    HM10.flush();
}

void run_at_commands() {
  //read from the HM-10 and print in the Serial
  while(HM10.available()) {
    Serial.write(HM10.read());
  }
  Serial.flush();

  if (Serial.available()) {
    Serial.print("Echoing ");
  }
  while(Serial.available()) {
    auto a = Serial.read();
    HM10.write(a);
    Serial.write(a);
  }
  Serial.flush();
  HM10.flush();
}