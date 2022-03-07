
# Tasmota-Tank-Sensor
Tasmota-Berry Tank Sensor for fuel-oil volume measurement using a VL53L1X or SR04 sensor

Please see this tech note for sensor cover materal:
~~~
<https://www.st.com/resource/en/application_note/an5231-cover-window-guidelines-for-the-vl53l1x-longdistance-ranging-timeofflight-sensor-stmicroelectronics.pdf>
~~~
Typical tank size charts:
~~~
https://www.fuelsnap.com/heating_oil_tank_charts.php
~~~


## The Sensor body

The sensor was prepared with 4 x 28 awg 6-inch wires that will be connected later to the ESP32 board. The sensor body was made from a 2in PVC coupling, threaded on one end for the tank, and “slip” fitting on the other. A sheet of clear 1/16in Lexan was cut with a 2 ½ in hole saw to make the mounting plate for the sensor. (The inside diameter of the 2 1/2in hole saw is just the correct size for the mounting plate) The sensor was centered in the Lexan and mounted to the Lexan with 2 x 2.5mm stainless screws, thru the Lexan, with a nut that was pre-tighten, and a nylon washer to get the correct distance from the sensor to the Lexan, then the sensor, another nylon washer on top and finally a nut. Lexan was selected as its resistance to fuel oil.

The PVC coupling was prepared with a bead of Permatex 82180 oil-resistant silicone on the inside ridge of the coupling.  The sensor assembled was then pressed inside the coupling onto the black silicone to form a vapor-free seal from the tank to the sensor. A weight was added to keep pressure on the bond, and it was left to cure for 12hr.

Above the sensor, a thin piece of cardboard was cut with a hole in the center to route the cable to the ESP32. This allowed the ESP32 to free float above the sensor without any issue of contact between the sensor and the ESP32 board.

The sensor wires were connected to the ESP32 D1 style board to GND, +3.3V, SDA on GPIO 23, and SCL to GPIO 22.  To supply power, a cable was attached to GND and to VCC pins on the ESP32 board. This cable was routed to a cable gland mounted on top of a 2in PVC plug. The cable was connected to a 5V power source. (NOTE: 5V Only!!)  PVC plug was pressed fit into the coupling, not glued, I use some white tape to seal plug to body of coupling.

        
## Programming the firmware

Programming of the ESP32 was done via its micro-USB connector. 

The sensor used on the project is an ST-Micro VL53L1X time of flight optical sensor, using the Tasmota Open source IOT firmware for ESP32 with its Berry scripting language. It provides a rich framework for developing IoT projects like this. We looks at other sensor options like SR04M ultrasonic sensor but decided on the VL53L1X optical device. Another option would be the older VL53L0X with some minor changes to the software.

Tasmota has many, many options, it supports a web interface and a full MQTT delivery of sensors data to a downstream device like Node-Red, Grafana, or home automation system, it also has a very rich scripting language (Berry) available.

The standard release (Ver: 10.0.0.0) that we used did not load the driver for the VL53L1X as a standard option, and we then needed to re-compile the Tasmota program, which was done via Visual Studio Code and a copy of the source-tree from GitHub. A pre-compiled binary is available in GitHub for this project.

It appears that the I2C driver for the VL53L1X does not play well with some of the other pre-define drivers in Tasmota. To solve this issue we needed to disable all of the I2C drivers except this one…

All changes were made  in one file:  tasmota/user_config_override.h 
and re-compile of Tasmota ESP32.

This will enable I2C on GPIO 22 and 23

~~~
#define USER_TEMPLATE "{\"NAME\":\"Tank Sensor VL53L1X\",\"GPIO\":[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,1,608,640,0,1,1,1,0,0,0,0,1,1,1,1,1,0,0,1],\"FLAG\":0,\"BASE\":1,\"CMND\":\"SetOption8 1\",\"CMND\":\"Module 0\"}"
   
    
#ifndef USE_VL53L1X   // Time of Flight Sensor
#define USE_VL53L1X 
#endif

#ifdef USE_VL53L1X
  #undef USE_VL53L0X    // same I2C address as VL53L1
  #undef USE_TSL2561
  #undef USE_TSL2591

  // I2C enable bit array
  #undef  I2CDRIVERS_0_31
  #define I2CDRIVERS_0_31  0x00000000
  #undef  I2CDRIVERS_32_63
  #define I2CDRIVERS_32_63 0x00400000   // enable only device 54, the VL53L1
  #undef  I2CDRIVERS_64_95
  #define I2CDRIVERS_64_95 0x00000000
#endif
~~~
To load this file, compile Tasmota32 with the option above...
Then Load the new binary image in your ESP32 and re-boot it. 
Open the web page for this device, select Console, then Manage File System,
Rename the Berry file your using to "autoexec.be", then upload it to the ESP32 file system. 
Reboot Tasmota, the Berry file will run after re-booting.

There are three version of the Berry script flies for this project:
~~~
Tank_Code3-VL53L1.be            Is for the VL53L1 TOF sensor with table lookup
Tank_Code4-VL53L1.be            As above, but also use linear interpolation of the lookup-table
Tank_Code3-SR04M.be             Is for the SR04 ultrasonic sensor sensor
~~~
A simple Node-Red flow that is include in GitHub will send an email if tank is low...
Yes, I know that Tasmota can also send email, but this separates sensor from control.
~~~
tasmota32-2022.01.3-VL53L1X.bin is compiled for VL53L1X and is located in GitHub
user_config_override.h was used to build this .bin
~~~
