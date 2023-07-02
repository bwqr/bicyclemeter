#ifndef SAMPLE
#define SAMPLE

#include <Wire.h>

#define MAX_SAMPLE 10
#define BUF_LEN 8

const int MPU_ADDR = 0x68;  // I2C address of the MPU-6050

void to_bytes(uint8_t *bytes, int16_t acc_x, int16_t acc_y, int16_t acc_z, uint16_t ang_vel) {
    bytes[0] = (acc_x >> 8) & 0xFF;
    bytes[1] = acc_x & 0xFF;
    bytes[2] = (acc_y >> 8) & 0xFF;
    bytes[3] = acc_y & 0xFF;
    bytes[4] = (acc_z >> 8) & 0xFF;
    bytes[5] = acc_z & 0xFF;
    bytes[6] = (ang_vel >> 8) & 0xFF;
    bytes[7] = ang_vel & 0xFF;
}

struct Vec3 {
    int16_t x = 0;
    int16_t y = 0;
    int16_t z = 0;

    float len() const {
      return sqrt((float) x * x + (float) y * y + (float) z * z);      
    }
};

struct Sample {
    Vec3 acc = { };
    Vec3 gyr = { };
    int16_t temp = 0;

    void read() {
        Wire.beginTransmission(MPU_ADDR);
        Wire.write(0x3B);  // starting with register 0x3B (ACCEL_XOUT_H)
        Wire.endTransmission(false);
        Wire.requestFrom(MPU_ADDR,14,true);  // request a total of 14 registers

        this->acc.x = Wire.read() << 8 | Wire.read();  // 0x3B (ACCEL_XOUT_H) & 0x3C (ACCEL_XOUT_L)    
        this->acc.y = Wire.read() << 8 | Wire.read();  // 0x3D (ACCEL_YOUT_H) & 0x3E (ACCEL_YOUT_L)
        this->acc.z = Wire.read() << 8 | Wire.read();  // 0x3F (ACCEL_ZOUT_H) & 0x40 (ACCEL_ZOUT_L)
        this->temp = Wire.read() << 8 | Wire.read();  // 0x41 (TEMP_OUT_H) & 0x42 (TEMP_OUT_L)
        this->gyr.x = Wire.read() << 8 | Wire.read();  // 0x43 (GYRO_XOUT_H) & 0x44 (GYRO_XOUT_L)
        this->gyr.y = Wire.read() << 8 | Wire.read();  // 0x45 (GYRO_YOUT_H) & 0x46 (GYRO_YOUT_L)
        this->gyr.z = Wire.read() << 8 | Wire.read();  // 0x47 (GYRO_ZOUT_H) & 0x48 (GYRO_ZOUT_L)
    }

    void print() {
        Serial.print("\tAcX = "); Serial.print(this->acc.x);
        Serial.print("\t| AcY = "); Serial.print(this->acc.y);
        Serial.print("\t| AcZ = "); Serial.print(this->acc.z);
        Serial.print("\t| Tmp = "); Serial.print(this->temp / 340.00+36.53);  //equation for temperature in degrees C from datasheet
        Serial.print("\t| GyX = "); Serial.print(this->gyr.x);
        Serial.print("\t| GyY = "); Serial.print(this->gyr.y);
        Serial.print("\t| GyZ = "); Serial.println(this->gyr.z);
    }
};

struct SampleState {
private:
    Sample samples[MAX_SAMPLE] = { };
    int8_t index = 0;

public:
    void read_sensor() {
        // This should not be the case since caller should have already called the filtered_sample 
        // Otherwise overwrite latest sample with a new one
        if (this->index >= MAX_SAMPLE) {
            this->index = MAX_SAMPLE - 1;
        }

        this->samples[this->index].read();

        this->index += 1;
    }

    bool filtered_sample(uint8_t *bytes) {
        if (this->index < MAX_SAMPLE) {
            return false;
        }

        this->index = 0;
        float acc_x = 0, acc_y = 0, acc_z = 0, ang_vel = 0;

        for (int i = 0; i < MAX_SAMPLE; i++) {
            ang_vel += samples[i].gyr.len();
            acc_x += samples[i].acc.x;
            acc_y += samples[i].acc.y;
            acc_z += samples[i].acc.z;
        }

        acc_x /= MAX_SAMPLE * 16384.0;
        acc_y /= MAX_SAMPLE * 16384.0;
        acc_z /= MAX_SAMPLE * 16384.0;
        ang_vel /= MAX_SAMPLE * 131.0;

//        Serial.print("AccX "); Serial.print(acc_x);
//        Serial.print("\tAccY "); Serial.print(acc_y);
//        Serial.print("\tAccZ "); Serial.print(acc_z);
//        Serial.print("\tang_vel "); Serial.print(ang_vel);
//        Serial.print("\trpm "); Serial.println((float) ang_vel * 60.0 / 360.0);
        Serial.print(acc_x); Serial.print(",");
        Serial.print(acc_y); Serial.print(",");
        Serial.println(acc_z);

        to_bytes(
            bytes,
            acc_x * 1000.0,
            acc_y * 1000.0,
            acc_z * 1000.0,
            ang_vel * 100.0
        );

        return true;
    }
};

void setup_sample() {
    #ifdef ARDUINO_AVR_UNO
    Wire.begin();
    #else
    Wire.begin(21, 22, 100000);
    #endif
    
    Wire.beginTransmission(MPU_ADDR);
    Wire.write(0x6B);  // PWR_MGMT_1 register
    Wire.write(0);     // set to zero (wakes up the MPU-6050)
    Wire.endTransmission(true);
}
#endif // SAMPLE
