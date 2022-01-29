

#- This is using a SR04M ultrasonics sensor to check the current volume
   of a fuel-oil heating tank. The sensor measures the distance from the
   sensor to the fuel oil and returns a value in centmeters.
   We then convert this to inches, do a table lookup from the tank
   manufacturer's datasheet to get the current volume remaining in the tank.
   We display the data on the web page and send it via MQTT.
   
   There are a number of variants of the SR04 available, SR04T/M have a single 
   waterproof transducer, and have a dead zone of about 20CM (7.9 in)
   Standard SR04 with two transducers has a dead zone of about 2CM (0.79 in)
   
   When we start this project we were doing a linear interpolation of the
   manufacturers table to get a more precise volume, but common sense
   step in when we realize we just need to know if the tank was full or almost
   empty, so we now just use a simple table lookup...
   
   
   Add to: tasmota/user_config_override.h and re-compile
   
   This will enable SR04, Echo on GPIO 13 and Trig on GPIO 12
   
    #define USER_TEMPLATE "{\"NAME\":\"Tank Monitor SR04\",\"GPIO\":[1,1,1,1,1,1,1,1,1856,1888,1,1,1,1,1,1,0,1,1,1,0,1,1,1,0,0,0,0,1,1,1,1,1,0,0,1],\"FLAG\":0,\"BASE\":1,\"CMND\":\"SetOption8 1\",\"CMND\":\"Module 0\"}"
   
    #ifndef USE_SR04
    #define USE_SR04
    #endif
   
    #define USE_BERRY_DEBUG 
   
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
    static Tank275 = [2,5,9,14,19,25,31,37,44,51,58,65,72,80,87,94,101,108,115,123,130,137,144,151,158,166,173,180,187,194,201,209,216,223,230,236,243,249,254,260,265,269,272,275,275]
 
 
 
#- *************************************** -#
   def tank()
    
    var TableLength =   self.Tank275.size()         # 45
    var TableTop = TableLength -1
    var tank_offset = -20                           # offset from SR04t to top of tank (dead zone...)
    var MaxBuf = 120                                # filtering buffer size
   
    #print ("\n")
 
    # Read Sensor data
    import json
    var sensors=json.load(tasmota.read_sensors())
    if !(sensors.contains('SR04')) return end
    var d = sensors['SR04']['Distance']
    #print("Dist: ", d)
    
    if (self.buf.size() >= MaxBuf) self.buf.pop(0) end      # remove old entry
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
	
    #  Convert from CM to inch and round up
    var d1 = (d / 2.54) + .5                        # 2.54 cm to one inch
    d1 = int(d1)                                    # we want an integer here for table lookup
    if (d1 > TableTop) d1 = TableTop end            # do a bounds check, 0 --> 44
    if (d1 <= 0) d1 = 0 end
    #print("Inch: ",d1)
    
    var d2 = self.Tank275.item(TableTop - d1)       # do table lookup, from end of table
    d2 = int(d2)                                    # make sure its an integer
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
    if !self.tank_data return nil end               #- exit if not initialized -#	
    var msg = string.format(
              "{s}Distance{m}%.f cm{e}"..
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
	var msg = string.format(",\"Tank\":{\"Distance cm\":%.f,\"Distance Inches\":%.f,\"Volume\":%.f,\"Percent Full\":%.f}",
              self.tank_data[0],self.tank_data[1],self.tank_data[2],self.tank_data[3])
    tasmota.response_append(msg)
  end
  
end


#- *************************************** -#
FOTank = FOTank()
tasmota.add_driver(FOTank)


#- ************ The Very End ************* -#
