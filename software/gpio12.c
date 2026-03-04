// ----------------------------------------------------------------------------
// Copyright (c) 2020-2025 RVX contributors
//
// This work is licensed under the MIT License, see LICENSE file for details.
// SPDX-License-Identifier: MIT
// ----------------------------------------------------------------------------

#include "libsteel.h"

#define DEFAULT_BAUD_RATE     9600
#define DEFAULT_CLOCK_HZ      50000000

//GPIO12.hex
// Base address for GPIO controller from memory map
#define GPIO_BASE_ADDRESS 0x80020000
int main() {
    // Initialize GPIO controller
    GpioController *gpio = (GpioController *)GPIO_BASE_ADDRESS;

    // Configure LED pins (0-5) as outputs
    gpio_set_output(gpio, 0); // LED 0
    gpio_set_output(gpio, 1); // LED 1
    gpio_set_output(gpio, 2); // LED 2
    gpio_set_output(gpio, 3); // LED 3
    gpio_set_output(gpio, 4); // LED 4
    gpio_set_output(gpio, 5); // LED 5

    // Set LED 0 to always on
    gpio_set(gpio, 0);

    // Configure switch pins (11-15) as inputs
    gpio_set_input(gpio, 11); // Switch for LED 1
    gpio_set_input(gpio, 12); // Switch for LED 2
    gpio_set_input(gpio, 13); // Switch for LED 3
    gpio_set_input(gpio, 14); // Switch for LED 4
    gpio_set_input(gpio, 15); // Switch for LED 5

    while (1) {
        // Read switch states and set corresponding LEDs
        gpio_write(gpio, 1, gpio_read(gpio, 11)); // LED 1 follows switch on pin 11
        gpio_write(gpio, 2, gpio_read(gpio, 12)); // LED 2 follows switch on pin 12
        gpio_write(gpio, 3, gpio_read(gpio, 13)); // LED 3 follows switch on pin 13
        gpio_write(gpio, 4, gpio_read(gpio, 14)); // LED 4 follows switch on pin 14
        gpio_write(gpio, 5, gpio_read(gpio, 15)); // LED 5 follows switch on pin 15
    }

    return 0;
}