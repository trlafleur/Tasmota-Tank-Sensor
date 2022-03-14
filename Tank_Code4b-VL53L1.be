

#- This is using a VL53L1 time of flight optical sensor to check the current volume
   of a fuel-oil heating tank. The sensor measures the distance from the
   sensor to the fuel oil and returns a value in millimeters.
   We then convert this to inches, do a table lookup from the tank
   manufacturers datasheet to get the current volume remaining in the tank.
   We display the data on the web page and send it via MQTT.

   This version is doing a linear interpolation of the manufacturers table to 
   get a more precise volume, 
   
   Please note, at this time in Tasmota 11.x.x. One need to disable all I2C device
   in your user_config_override.h file that your not using to enable the VL53L1X
   
   
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
    26-Feb-2022  1.1  TRL - Linear Interpolation version
    09-Mar-2022  1.2  TRL - Added 330 gal tank
    
    Notes:  1)  Tested with 11.0.3(tasmota)
    
    
    ToDo:   1)

    tom@lafleur.us
 
-#


#- *************************************** -#
class FOTank : Driver

    var tank_data
   
    #build an global array-->list to store sensor data for filtering
    static buf = []
    
    # this table is from the tank manufacturer datasheet, showing total gallons in inches, 44 entries plus an extra entry at top of table. 
    #static Tank275 = [2,5,9,14,19,25,31,37,44,51,58,65,72,80,87,94,101,108,115,123,130,137,144,151,158,166,173,180,187,194,201,209,216,223,230,236,243,249,254,260,265,269,272,275,275]
    static Tank330 = [2.1,6.0,10.8,16.4,22.8,30.2,37.5,45.2,53.2,61.4,69.8,78.3,86.9,95.5,104.1,112.7,121.3,129.9,138.5,147.1,155.7,164.3,172.9,181.5,190.1,198.7,207.3,215.9,224.5,233.1,241.7,250.3,258.8,267.2,275.4,283.4,291.1,298.4,305.3,311.7,317.5,322.5,326.4,328.6,328.6]
 
 
 
#- *************************************** -#
   def tank()
   
#- *************************************** -#
     def table_lookup(MyTank, dist)
     
       var top = MyTank.size()
    
       #let's do a bounds check...
       if (dist >= top - 1 )  return MyTank.item(top-1) end
       if (dist <= 0 )        return MyTank.item(0)     end
       var t6 = real (MyTank.item(int(dist)) )      # get lower value from table
       var t7 = real (MyTank.item(int(dist+1)) )    # get next value from table
       var t1 = real (int (dist+1) - int(dist))     # in our case is always = 1
       var t2 = real (dist - int(dist))             # spacing from lower value
       var t3 = real (t7 - t6)                      # delta from table entry
       #print("t6, t7, t1, t2, t3", t6, t7, t1, t2, t3)
       if ( t1 == 0) return t6 end                  # check for zero delta in table (division by zero check)
       var t4 = real ( t6 + ((t2 * t3) / t1) )
       return t4                                    # return gallons in tank
      end

#- *************************************** -#   
    var TableLength = self.Tank330.size()           # 45
    var TableTop = TableLength -1                   # 44
    var tank_offset = -25                           # offset from VL53L1 to top of tank 
    var MaxBuf = 120                                # filtering buffer size
   
    #print ("\n")
 
    # Read Sensor data
    import json
    var sensors=json.load(tasmota.read_sensors())
    if !(sensors.contains('VL53L1X')) return end
    var d = real(sensors['VL53L1X']['Distance'] )
    #print("Dist: ", d)
    
    if (self.buf.size() >= MaxBuf) self.buf.pop(0) end      # remove oldest entry
    self.buf.push(d)                                        # add new sensor reading to list

    d = 0.0                                         # clear sum
    for i : 0 .. (self.buf.size() - 1 )             # let's sum all of the entrys in the array
     d = d + self.buf.item (i)
    end
    
    d = d / self.buf.size()                         # average the sensor data from the array
    #print("Dist-avg: ", d)
    
    d = d + tank_offset                             # adjust for sensor to tank offset (dead zone)
	
    #  Convert from MM to inch
    var d1 = real ((d / 25.4) )                     # 25.4 mm per inch
    if (d1 > TableTop) d1 = TableTop end            # do a bounds check, 0 --> 44
    if (d1 <= 0) d1 = 0 end
    #print("Inch: ", d1)
    
    var d9 = real (TableTop - d1)                   # do table lookup, from end of table
    #print ("d9 ", d9)
    var d2 = table_lookup (self.Tank330, d9)    
    #print ("d9, Gal: ", d9, d2)
    
    var d3 = ((d2 / self.Tank330.item(TableTop)) * 100 )    # calculate percent of full
    d3 = int(d3 + .5)                               # round up if needed
    #print ("Percent:", d3)
    
    self.tank_data = [int (d), d1, d2, d3]          # return the data, Raw-MM, Inch, Gal, %
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
              "{s}Distance - offset{m}%.f mm{e}"..
              "{s}Distance{m}%7.2f inches{e}"..
              "{s}Volume{m}%7.2f gal{e}"..
              "{s}Percent Full{m}%.f %%{e}",
              self.tank_data[0],self.tank_data[1],self.tank_data[2],self.tank_data[3])
    tasmota.web_send_decimal(msg)
  end
  

#- *************************************** -#
  def json_append()
    if !self.tank_data return nil end
	import string
	var msg = string.format(",\"Tank\":{\"Distance_mm\":%.f,\"Distance_Inches\":%7.2f,\"Volume\":%7.2f,\"Percent_Full\":%.f}",
              self.tank_data[0],self.tank_data[1],self.tank_data[2],self.tank_data[3])
    tasmota.response_append(msg)
  end
  
end


#- *************************************** -#
FOTank = FOTank()
tasmota.add_driver(FOTank)


#- ************ The Very End ************* -#

