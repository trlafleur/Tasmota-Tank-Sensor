

#- This is using a VL53L1 time of flight optical sensor to check the current volume
   of a fuel-oil heating tank. The sensor measures the distance from the
   sensor to the fuel oil and returns a value in millimeters.
   We then convert this to inches, do a table lookup from the tank
   manufacturer's datasheet to get the current volume remaining in the tank.
   We display the data on the web page and send it via MQTT.

   When we start this project we were doing a linear interpolation of the
   manufacturers table to get a more precise volume, but common sense
   step in when we realize we just need to know if the tank was full or almost
   empty, so we now just use a simple table lookup..…
   
   Please note, at this time in Tasmota 10.1.. One need to disable all I2C device
   in your user_config_override.h file that you're not using to enable the VL53L1X
   
   
   Add to: tasmota/user_config_override.h and re-compile
   
   This will enable I2C on GPIO 22 and 23
    #define USER_TEMPLATE "{\"NAME\":\"Tank Sensor VL53L1X\",\"GPIO\":[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,1,608,640,0,1,1,1,0,0,0,0,1,1,1,1,1,0,0,1],\"FLAG\":0,\"BASE\":1,\"CMND\":\"SetOption8 1\",\"CMND\":\"Module 0\"}"
   
    #ifndef USE_VL53L1X
    #define USE_VL53L1X
    #endif
   
    #define USE_BERRY_DEBUG 

    #define I2CDRIVERS_0_31  0x00000000
    #define I2CDRIVERS_32_63 0x00400000     // enable only device 54, the VL53L1
    #define I2CDRIVERS_64_95 0x00000000
   
   
   To load this file, compile Tasmota32 with the option above...
   Then Load the new binary image in your ESP32 and re-boot it. 
   Open the web page for this device, select Console, then Manage File System
   Rename this Berry file to "autoexec.be", then upload it to the ESP32 file system. 
   Reboot Tasmota, this Berry file will run after re-booting.
 -#
   
 #- *************************************** -#
 

 #-
    CHANGE LOG:
 
    DATE         REV  DESCRIPTION
    -----------  ---  ----------------------------------------------------------
    28-Jan-2022  1.0  TRL - 1st release
 
    
    Notes:  1)  Tested with 2022.01.3(tasmota)
    
    
    ToDo:   1)

    tom@lafleur.us
 
-#


#- *************************************** -#
class FOTank : Driver

    var tank_data
   
    #build an global array-->list to store sensor for filtering
    static buf = []
    # this table is from the manufacturer datasheet, showing total gallons in inches, 44 entries plus a zero-entry. 
    static Tank275 = [0,2,5,9,14,19,25,31,37,44,51,58,65,72,80,87,94,101,108,115,123,130,137,144,151,158,166,173,180,187,194,201,209,216,223,230,236,243,249,254,260,265,269,272,275]
 
 
 
#- *************************************** -#
   def tank()
    
    var TableLength =   self.Tank275.size()           #45
    var TableTop = TableLength -1
    var tank_offset = 0                             # offset from VL53L1 to top of tank (dead zone...)
    var MaxBuf = 120                                # filtering buffer size
   
    #print ("\n")
 
    # Read Sensor data
    import json
    var sensors=json.load(tasmota.read_sensors())
    if !(sensors.contains('VL53L1X')) return end
    var d = sensors['VL53L1X']['Distance']
    #print("Dist: ", d)
    
    if (self.buf.size() >= MaxBuf) self.buf.pop(0) end      # remove oldest entry
    self.buf.push(d)                                        # add new sensor reading to list
    #print (self.buf)
    #print ("Size: :", self.buf.size()) 

    d = 0
    for i : 0 .. (self.buf.size()-1 )               # let's sum all of the entrys
    #print ("I: ",i)
    d = d + self.buf.item (i)
    end
    
    #print("Buf: ", self.buf)
    
    d = d / self.buf.size()                         # average the sensor data
    #print("Dist-avd: ", d)
    
    d = d + tank_offset                             # adjust for sensor to tank offset (dead zone)
	
    #  Convert from MM to inch and round up
    var d1 = (d / 25.4) + .5                        # 25.4 mm per inch
    d1 = int(d1)                                    # we want an integer here for table lookup
    if (d1 > TableTop) d1 = TableTop end            # do a bounds check, 0 --> 44
    if (d1 <= 0) d1 = 0 end
    #print("Inch: ",d1)
    
    var d2 = self.Tank275.item(TableTop - d1)       # do table lookup, from end of table
    d2 = int(d2)
    #print ("Gal: ",d2)
    
    var d3 = (real(d2) / self.Tank275.item(TableTop)) * 100    # calculate percent of full
    d3 = int (d3)
    #print ("Percent:", d3)
    
    self.tank_data = [int (d), d1, d2, d3]          # return the data
    return self.tank_data
  end


#- *************************************** -#
  def every_second()
	if !self.tank return nil end
	self.tank()
  end
  
   
#- *************************************** -#
  def web_sensor()
    import string
    if !self.tank_data return nil end               # exit if not initialized
    var msg = string.format(
              "{s}Distance{m}%.f mm{e}"..
              "{s}Distance{m}%.f inches{e}"..
              "{s}Volume{m}%.f gal{e}"..
              "{s}Percent Full{m}%.f %%{e}",
              self.tank_data[0],self.tank_data[1],self.tank_data[2],self.tank_data[3])
    tasmota.web_send_decimal(msg)
  end
  

#- *************************************** -#
  def json_append()
    if !self.tank_data return nil end
	import string
	var msg = string.format(",\"Tank\":{\"Distance mm\":%.f,\"Distance Inches\":%.f,\"Volume\":%.f,\"Percent Full\":%.f}",
              self.tank_data[0],self.tank_data[1],self.tank_data[2],self.tank_data[3])
    tasmota.response_append(msg)
  end
  
end


#- *************************************** -#
FOTank = FOTank()
tasmota.add_driver(FOTank)


#- ************ The Very End ************* -#

