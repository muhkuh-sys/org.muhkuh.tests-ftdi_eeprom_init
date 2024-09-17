local class = require 'pl.class'
local TestClass = require 'test_class'
local TestClassFtdiEepromInit = class(TestClass)


function TestClassFtdiEepromInit:_init(strTestName, uiTestCase, tLogWriter, strLogLevel)
  self:super(strTestName, uiTestCase, tLogWriter, strLogLevel)

  local luaftdi = require 'luaftdi'
  self.luaftdi = luaftdi

  self.lxp = require 'lxp'

  -- Create a lookup table which translates the ASCII identifier to the index
  -- used by libftdi.
  local atKeysAsciiToNumber = {
    ['VENDOR_ID'] = luaftdi.VENDOR_ID,
    ['PRODUCT_ID'] = luaftdi.PRODUCT_ID,
    ['SELF_POWERED'] = luaftdi.SELF_POWERED,
    ['REMOTE_WAKEUP'] = luaftdi.REMOTE_WAKEUP,
    ['IS_NOT_PNP'] = luaftdi.IS_NOT_PNP,
    ['SUSPEND_DBUS7'] = luaftdi.SUSPEND_DBUS7,
    ['IN_IS_ISOCHRONOUS'] = luaftdi.IN_IS_ISOCHRONOUS,
    ['OUT_IS_ISOCHRONOUS'] = luaftdi.OUT_IS_ISOCHRONOUS,
    ['SUSPEND_PULL_DOWNS'] = luaftdi.SUSPEND_PULL_DOWNS,
    ['USE_SERIAL'] = luaftdi.USE_SERIAL,
    ['USB_VERSION'] = luaftdi.USB_VERSION,
    ['USE_USB_VERSION'] = luaftdi.USE_USB_VERSION,
    ['MAX_POWER'] = luaftdi.MAX_POWER,
    ['CHANNEL_A_TYPE'] = luaftdi.CHANNEL_A_TYPE,
    ['CHANNEL_B_TYPE'] = luaftdi.CHANNEL_B_TYPE,
    ['CHANNEL_A_DRIVER'] = luaftdi.CHANNEL_A_DRIVER,
    ['CHANNEL_B_DRIVER'] = luaftdi.CHANNEL_B_DRIVER,
    ['CBUS_FUNCTION_0'] = luaftdi.CBUS_FUNCTION_0,
    ['CBUS_FUNCTION_1'] = luaftdi.CBUS_FUNCTION_1,
    ['CBUS_FUNCTION_2'] = luaftdi.CBUS_FUNCTION_2,
    ['CBUS_FUNCTION_3'] = luaftdi.CBUS_FUNCTION_3,
    ['CBUS_FUNCTION_4'] = luaftdi.CBUS_FUNCTION_4,
    ['CBUS_FUNCTION_5'] = luaftdi.CBUS_FUNCTION_5,
    ['CBUS_FUNCTION_6'] = luaftdi.CBUS_FUNCTION_6,
    ['CBUS_FUNCTION_7'] = luaftdi.CBUS_FUNCTION_7,
    ['CBUS_FUNCTION_8'] = luaftdi.CBUS_FUNCTION_8,
    ['CBUS_FUNCTION_9'] = luaftdi.CBUS_FUNCTION_9,
    ['HIGH_CURRENT'] = luaftdi.HIGH_CURRENT,
    ['HIGH_CURRENT_A'] = luaftdi.HIGH_CURRENT_A,
    ['HIGH_CURRENT_B'] = luaftdi.HIGH_CURRENT_B,
    ['INVERT'] = luaftdi.INVERT,
    ['GROUP0_DRIVE'] = luaftdi.GROUP0_DRIVE,
    ['GROUP0_SCHMITT'] = luaftdi.GROUP0_SCHMITT,
    ['GROUP0_SLEW'] = luaftdi.GROUP0_SLEW,
    ['GROUP1_DRIVE'] = luaftdi.GROUP1_DRIVE,
    ['GROUP1_SCHMITT'] = luaftdi.GROUP1_SCHMITT,
    ['GROUP1_SLEW'] = luaftdi.GROUP1_SLEW,
    ['GROUP2_DRIVE'] = luaftdi.GROUP2_DRIVE,
    ['GROUP2_SCHMITT'] = luaftdi.GROUP2_SCHMITT,
    ['GROUP2_SLEW'] = luaftdi.GROUP2_SLEW,
    ['GROUP3_DRIVE'] = luaftdi.GROUP3_DRIVE,
    ['GROUP3_SCHMITT'] = luaftdi.GROUP3_SCHMITT,
    ['GROUP3_SLEW'] = luaftdi.GROUP3_SLEW,
    ['CHIP_SIZE'] = luaftdi.CHIP_SIZE,
    ['CHIP_TYPE'] = luaftdi.CHIP_TYPE,
    ['POWER_SAVE'] = luaftdi.POWER_SAVE,
    ['CLOCK_POLARITY'] = luaftdi.CLOCK_POLARITY,
    ['DATA_ORDER'] = luaftdi.DATA_ORDER,
    ['FLOW_CONTROL'] = luaftdi.FLOW_CONTROL,
    ['CHANNEL_C_DRIVER'] = luaftdi.CHANNEL_C_DRIVER,
    ['CHANNEL_D_DRIVER'] = luaftdi.CHANNEL_D_DRIVER,
    ['CHANNEL_A_RS485'] = luaftdi.CHANNEL_A_RS485,
    ['CHANNEL_B_RS485'] = luaftdi.CHANNEL_B_RS485,
    ['CHANNEL_C_RS485'] = luaftdi.CHANNEL_C_RS485,
    ['CHANNEL_D_RS485'] = luaftdi.CHANNEL_D_RS485,
    ['RELEASE_NUMBER'] = luaftdi.RELEASE_NUMBER,
    ['EXTERNAL_OSCILLATOR'] = luaftdi.EXTERNAL_OSCILLATOR,
    ['USER_DATA_ADDR'] = luaftdi.USER_DATA_ADDR
  }
  -- Create a reverse table to translate the libftdi index to the ASCII identifier.
  local atKeysNumberToAscii = {}
  for strKey, uiValue in pairs(atKeysAsciiToNumber) do
    atKeysNumberToAscii[uiValue] = strKey
  end
  self.atKeysAsciiToNumber = atKeysAsciiToNumber
  self.atKeysNumberToAscii = atKeysNumberToAscii

  local P = self.P
  self:__parameter {
    P:P('definition_file', 'This is the name of the file holding the EEPROM definition.'):
      required(true),

    P:U16('usb_vendor_id_blank', 'The USB vendor ID of the blank device.'):
      default(0x0403):
      required(true),

    P:U16('usb_product_id_blank', 'The USB product ID of the blank device.'):
      default(0x6010):
      required(true),

    P:P('group', 'The MAC group for the FTDI IDs.'):
      default('testgroup1'):
      required(true),

    P:U32('manufacturer', 'The manufacturer ID of the board.'):
      required(true),

    P:U32('devicenr', 'The device number of the board.'):
      required(true),

    P:U32('serial', 'The serial number of the board.'):
      required(true),

    P:U32('hwrev', 'The hardware revision of the board.'):
      required(true),

    P:U32('deviceclass', 'The device class of the board.'):
      required(true),

    P:U32('hwcomp', 'The hardware compatibility of the board.'):
      required(true)
  }

  self.strVendor = nil
  self.strProduct = nil
  self.atSettings = nil
end



--- Expat callback function for starting an element.
-- This function is part of the callbacks for the expat XML parser.
-- It is called when a new element is opened.
-- @param tParser The parser object.
-- @param strName The name of the element.
-- @param atAttributes A table with all attributes of the element.
function TestClassFtdiEepromInit.parseCfg_StartElement(tParser, strName, atAttributes)
  -- Get the user parameter from the expat parser. This is a table where we
  -- store the results and the current path in the XML.
  local aLxpAttr = tParser:getcallbacks().userdata
  -- Get the position in the XML text file for error messages.
  local iPosLine, iPosColumn = tParser:pos()

  -- Append the new element to the current path.
  table.insert(aLxpAttr.atCurrentPath, strName)
  aLxpAttr.strCurrentPath = table.concat(aLxpAttr.atCurrentPath, "/")

  -- Compare the current path with the expected locations.
  if aLxpAttr.strCurrentPath=="/FtdiEeprom" then
    -- This is the root element.
    -- Get the "vendor" attribute. It must be there.
    local strVendor = atAttributes['vendor']
    if strVendor==nil then
      aLxpAttr.tResult = nil
      aLxpAttr.tLog.error('Error in line %d, col %d: missing attribute "vendor".', iPosLine, iPosColumn)
    else
      -- Get the "product" attribute. It must be there.
      local strProduct = atAttributes['product']
      if strProduct==nil then
        aLxpAttr.tResult = nil
        aLxpAttr.tLog.error('Error in line %d, col %d: missing attribute "product".', iPosLine, iPosColumn)
      else
        -- Store the values of the vendor and product attributes in the table
        -- from the expat user data.
        aLxpAttr.strVendor = strVendor
        aLxpAttr.strProduct = strProduct
      end
    end

  elseif aLxpAttr.strCurrentPath=="/FtdiEeprom/Set" then
    -- This is a key/value element.
    -- Get the "key" attribute. It must be there.
    local strKey = atAttributes['key']
    if strKey==nil then
      aLxpAttr.tResult = nil
      aLxpAttr.tLog.error('Error in line %d, col %d: missing attribute "key".', iPosLine, iPosColumn)
    else
      -- Get the "value" attribute. It must be there.
      local strValue = atAttributes['value']
      if strValue==nil then
        aLxpAttr.tResult = nil
        aLxpAttr.tLog.error('Error in line %d, col %d: missing attribute "value".', iPosLine, iPosColumn)

      else
        -- Try to translate the key to a libftdi index.
        local uiKey = aLxpAttr.atValidKeys[strKey]
        if uiKey==nil then
          aLxpAttr.tResult = nil
          aLxpAttr.tLog.error('Error in line %d, col %d: unknown key "%s".', iPosLine, iPosColumn, strKey)

        -- Does the key already exists in the settings we read up to now?
        -- This would mean there are 2 entries with the same key in the XML.
        elseif aLxpAttr.atSettings[uiKey]~=nil then
          aLxpAttr.tResult = nil
          aLxpAttr.tLog.error('Error in line %d, col %d: multiple definition of key "%s".', iPosLine, iPosColumn, strKey)

        else
          -- Convert the value to a number.
          local ulValue = tonumber(strValue)
          if ulValue==nil then
            aLxpAttr.tResult = nil
            aLxpAttr.tLog.error('Error in line %d, col %d: the value "%s" can not be converted to a number.', iPosLine, iPosColumn, strValue)
          else
            -- Add the key/value pair to the settings.
            aLxpAttr.atSettings[uiKey] = ulValue
          end
        end
      end
    end
  end
end



--- Expat callback function for closing an element.
-- This function is part of the callbacks for the expat XML parser.
-- It is called when an element is closed.
-- @param tParser The parser object.
-- @param strName The name of the closed element.
function TestClassFtdiEepromInit.parseCfg_EndElement(tParser, strName)
  local aLxpAttr = tParser:getcallbacks().userdata

  -- Remove the last element from the current path.
  table.remove(aLxpAttr.atCurrentPath)
  aLxpAttr.strCurrentPath = table.concat(aLxpAttr.atCurrentPath, "/")
end



--- Expat callback function for character data.
-- This function is part of the callbacks for the expat XML parser.
-- It is called when character data is parsed.
-- @param tParser The parser object.
-- @param strData The character data.
function TestClassFtdiEepromInit.parseCfg_CharacterData(tParser, strData)
  -- The current XML definition for the FTDI setting does not use any elements
  -- with character data, so this function is empty for now.
end



--- Parse a FTDI configuration file.
-- @param strFilename The path to the configuration file.
-- @param tLog A lua-log object which can be used for log messages.
-- @param atValidKeys A list of valid keys. It is used to validate the keys pairs in the configuration file and to translate them to numbers.
function TestClassFtdiEepromInit:parse_configuration(strFilename, tLog)
  -- Be optimistic!
  local tResult = true

  local aLxpAttr = {
    -- Start at root ("/").
    atCurrentPath = {""},
    strCurrentPath = nil,

    strVendor = nil,
    strProduct = nil,
    atSettings = {},

    tResult = true,
    atValidKeys = self.atKeysAsciiToNumber,
    tLog = tLog
  }

  local aLxpCallbacks = {}
  aLxpCallbacks._nonstrict    = false
  aLxpCallbacks.StartElement  = self.parseCfg_StartElement
  aLxpCallbacks.EndElement    = self.parseCfg_EndElement
  aLxpCallbacks.CharacterData = self.parseCfg_CharacterData
  aLxpCallbacks.userdata      = aLxpAttr

  local tParser = self.lxp.new(aLxpCallbacks)

  -- Read the complete file.
  local strXmlText, strError = self.pl.utils.readfile(strFilename, false)
  if strXmlText==nil then
    tResult = nil
    local strMsg = string.format('Error reading the file: %s', strError)
    tLog.error(strMsg)
    error(strMsg)
  else
    local tParseResult, strMsg, uiLine, uiCol, uiPos = tParser:parse(strXmlText)
    if tParseResult~=nil then
      tParseResult, strMsg, uiLine, uiCol, uiPos = tParser:parse()
    end
    tParser:close()

    if tParseResult==nil then
      tResult = nil
      local strMsg = string.format("%s: %d,%d,%d", strMsg, uiLine, uiCol, uiPos)
      tLog.error(strMsg)
      error(strMsg)
    elseif aLxpAttr.tResult==nil then
      tResult = nil
    else
      self.strVendor = aLxpAttr.strVendor
      self.strProduct = aLxpAttr.strProduct
      self.atSettings = aLxpAttr.atSettings
    end
  end

  return tResult
end



function TestClassFtdiEepromInit:__get_mac(atAttr, tLog)
  local aucMac = nil

  local pretzel = require 'pretzel'
  local tBoardInfo = pretzel:get_board_info(atAttr.group, atAttr.manufacturer, atAttr.devicenr, atAttr.serialnr)
  if tBoardInfo==nil then
    tLog.error('Failed to search for the board.')
  elseif #tBoardInfo == 0 then
    tLog.info('No assigned FTDI serial number found. Request a new one.')

    aucMac = pretzel:request(atAttr, 1)
    if aucMac==nil then
      tLog.error('Failed to request the MAC for the board.')
    end
    tLog.info('Received a new MAC for the board: %02X:%02X:%02X:%02X:%02X:%02X .', aucMac[1], aucMac[2], aucMac[3], aucMac[4], aucMac[5], aucMac[6])
  elseif #tBoardInfo == 1 then
    local tAttr = tBoardInfo[1]
    local strMac = tAttr.mac
    local strMac1, strMac2, strMac3, strMac4, strMac5, strMac6 = string.match(strMac, '(%x%x)(%x%x)(%x%x)(%x%x)(%x%x)(%x%x)')
    aucMac = {
      tonumber(strMac1, 16),
      tonumber(strMac2, 16),
      tonumber(strMac3, 16),
      tonumber(strMac4, 16),
      tonumber(strMac5, 16),
      tonumber(strMac6, 16)
    }
    tLog.info('Found existing MAC for the board: %02X:%02X:%02X:%02X:%02X:%02X .', aucMac[1], aucMac[2], aucMac[3], aucMac[4], aucMac[5], aucMac[6])
  else
    tLog.error('More than one entry found for the board.')
  end

  return aucMac
end



function TestClassFtdiEepromInit:__get_serial(atAttr, tLog)
  local strSerial = nil

  local aucMac = self:__get_mac(atAttr, tLog)
  if aucMac==nil then
    local strMsg = ('Failed to get a pseudo MAC for the board. The serial can not be generated.')
    tLog.error(strMsg)
    error(strMsg)
  end

  -- Create a 6 digit serial from the pseudo mac.
  strSerial = string.format('HXD%02X%02X%02X', aucMac[4], aucMac[5], aucMac[6])
  tLog.info('Using serial number %s.', strSerial)

  return strSerial
end



function TestClassFtdiEepromInit:__verify_settings(tContext, tProgrammedDevice)
  local tLog = self.tLog
  local fCompareResult = true

  -- Open the programmed device.
  tLog.debug('Open the programmed device.')
  local tResult, strError = tContext:usb_open_dev(tProgrammedDevice)
  assert(tResult, strError)

  -- Get the EEPROM object.
  tLog.debug('Read the EEPROM.')
  local tEeprom = tContext:eeprom()
  assert(tEeprom, 'Failed to get the Eeprom object.')

  -- Read the EEPROM.
  tResult, strError = tEeprom:read()
  assert(tResult, strError)

  local atVerifyBlacklist = {
  }

  -- Verify all values from the configuration file except a few blacklisted fields.
  for uiKey, uiValue in pairs(self.atSettings) do
    -- Is the key in the blacklist?
    if atVerifyBlacklist[uiKey]~=nil then
      -- No, the key is not blacklisted.

      -- Get the value.
      local tEepromValue, strEepromError = tEeprom:get_value(uiKey)
      if tEepromValue==nil then
        tLog.error('Failed to get the value "%s": %s', tostring(uiKey), strEepromError)
        error('Failed to get the value.')
      end

      -- Is the value the same?
      if uiValue==tEepromValue then
        tLog.debug('The value for "%s" matches.', tostring(uiKey))
      else
        tLog.error('The values for "%s" differ: definition="%s", eeprom="%s"', tostring(uiKey), tostring(uiValue), tostring(tEepromValue))
        fCompareResult = false
      end
    end
  end

  return fCompareResult
end



function TestClassFtdiEepromInit:__program_blank_device(tContext, tBlankDevice, atPretzelAttr)
  local luaftdi = self.luaftdi
  local tLog = self.tLog

  -- Open the blank device.
  tLog.debug('Open the blank device.')
  local tResult, strError = tContext:usb_open_dev(tBlankDevice)
  assert(tResult, strError)

  -- Get the EEPROM object.
  tLog.debug('Read the EEPROM.')
  local tEeprom = tContext:eeprom()
  assert(tEeprom, 'Failed to get the Eeprom object.')

  -- Read the EEPROM.
  tResult, strError = tEeprom:read()
  assert(tResult, strError)

  -- Get the EEPROM size.
  tResult, strError = tEeprom:get_value(luaftdi.CHIP_SIZE)
  assert(tResult, strError)
  local iEepromSize = tResult
  if iEepromSize~=-1 then
    tContext:usb_close()
    error('The EEPROM is not empty!')
  end
  tLog.info('The EEPROM is empty.')

  local strFTDISerial = self:__get_serial(atPretzelAttr, tLog)

  -- Create a new EEPROM structure.
  tResult, strError = tEeprom:initdefaults(self.strVendor, self.strProduct, strFTDISerial)
  assert(tResult, strError)
  -- Apply all values from the configuration file.
  for uiKey, uiValue in pairs(self.atSettings) do
    tResult, strError = tEeprom:set_value(uiKey, uiValue)
    assert(tResult, strError)
  end

  -- Build the checksum for the EEPROM structure.
  tResult, strError = tEeprom:build()
  assert(tResult, strError)

  -- Write the EEPROM structure to the device.
  tLog.info('Write the configuration to the EEPROM.')
  tResult, strError = tEeprom:write()
  assert(tResult, strError)

  -- Reset the device to apply the new values.
  tResult, strError = tContext:usb_reset()
  assert(tResult, strError)

  -- Try to reset the device in the OS so that it appears with the new values.
  tResult, strError = tContext:usb_reset_device()
  tLog.debug('usb_reset_device returned %s, %s', tostring(tResult), tostring(strError))
end



function TestClassFtdiEepromInit:run()
  local atParameter = self.atParameter
  local tLog = self.tLog
  local atKeysNumberToAscii = self.atKeysNumberToAscii

  ----------------------------------------------------------------------
  --
  -- Parse the parameters and collect all options.
  --

  -- Parse the definition_file option.
  local strDefinitionFile = atParameter['definition_file']:get()
  if strDefinitionFile==nil then
    error('No definition file specified.')
  end
  -- Does the file exist?
  if self.pl.path.exists(strDefinitionFile)==nil then
    error(string.format('Failed to open the definition file "%s".', strDefinitionFile))
  end

  -- Get the USB vendor and product ID of the blank device.
  local usUSBVendorBlank = atParameter['usb_vendor_id_blank']:get()
  local usUSBProductBlank = atParameter['usb_product_id_blank']:get()

  local strMacGroupName = atParameter['group']:get()
  local ulManufacturer = atParameter['manufacturer']:get()
  local ulDeviceNr = atParameter['devicenr']:get()
  local ulSerial = atParameter['serial']:get()
  local ulHwRev = atParameter['hwrev']:get()
  local ulDeviceClass = atParameter['deviceclass']:get()
  local ulHwComp = atParameter['hwcomp']:get()

  local luaftdi = require 'luaftdi'


  -- Read the definition file.
  local tResult = self:parse_configuration(strDefinitionFile, tLog)
  if tResult==nil then
    error('Failed to parse the configuration file.')
  end

  -- Show the settings from the configuration file.
  tLog.debug('Vendor:  "%s"', self.strVendor)
  tLog.debug('Product: "%s"', self.strProduct)
  for uiKey, uiValue in pairs(self.atSettings) do
    local strKey = atKeysNumberToAscii[uiKey]
    tLog.debug('  %s = %d (0x%08x)', strKey, uiValue, uiValue)
  end


  -- Create a new FTDI context.
  local tContext = luaftdi.Context()

  -- Scan for all blank devices with the requested VID and PID.
  tLog.debug('Looking for blank USB devices with VID=0x%04x and PID=0x%04x.', usUSBVendorBlank, usUSBProductBlank)
  local tList = tContext:usb_find_all(usUSBVendorBlank, usUSBProductBlank)

  -- Filter the device list with the product and serial string.
  local atBlankDevices = {}
  for tListEntry in tList:iter() do
    -- Get the strings. This fails if the EEPROM is empty.
    local strManufacturer = tListEntry:get_manufacturer()
    local strProduct = tListEntry:get_description()
    local strSerial = tListEntry:get_serial()
    if strManufacturer==nil and strProduct==nil and strSerial==nil then
      table.insert(atBlankDevices, tListEntry)
    else
      tLog.debug('Filter device with manufacturer="%s", product="%s", serial="%s".', tostring(strManufacturer), tostring(strProduct), tostring(strSerial))
    end
  end

  -- There must be only 1 blank device available.
  local ulBlankDeviceCnt = #atBlankDevices
  tLog.info('Found %d matching blank devices.', ulBlankDeviceCnt)
  if ulBlankDeviceCnt==0 then
    tLog.info('No matching blank FTDI device found. Now looking for programmed devices.')

    self.pl.pretty.dump(self.atSettings)
    local usUSBVendorProgrammed = self.atSettings[luaftdi.VENDOR_ID]
    local usUSBProductProgrammed = self.atSettings[luaftdi.PRODUCT_ID]
    tLog.debug('Looking for programmed USB devices with VID=0x%04x and PID=0x%04x.', usUSBVendorProgrammed, usUSBProductProgrammed)
    local tListProgrammed = tContext:usb_find_all(usUSBVendorProgrammed, usUSBProductProgrammed)

    local atProgrammedDevices = {}
    for tListEntry in tListProgrammed:iter() do
      -- Get the strings. This fails if the EEPROM is empty.
      local strManufacturer = tListEntry:get_manufacturer()
      local strProduct = tListEntry:get_description()
      local strSerial = tListEntry:get_serial()
      if strManufacturer==self.strVendor and strProduct==self.strProduct then
        table.insert(atProgrammedDevices, tListEntry)
      else
        tLog.debug('Filter device with manufacturer="%s", product="%s", serial="%s".', tostring(strManufacturer), tostring(strProduct), tostring(strSerial))
      end
    end

    local ulProgrammedDeviceCnt = #atProgrammedDevices
    tLog.info('Found %d matching programmed devices.', ulProgrammedDeviceCnt)
    if ulProgrammedDeviceCnt==0 then
      tLog.error('No blank and no programmed device found.')
      error('No blank and no programmed device found.')

    elseif ulProgrammedDeviceCnt==1 then
      local fResult = self:__verify_settings(tContext, atProgrammedDevices[1])
      if fResult==true then
        tLog.info('All values match. Found a programmed device.')
      else
        tLog.error('The programmed device differs from the definition. This is something else.')
        error('The programmed device differs from the definition. This is something else.')
      end

    else
      tLog.error('No blank device and more than one programmed device found.')
      error('No blank device and more than one programmed device found.')
    end

  elseif ulBlankDeviceCnt==1 then
    -- Get the production date.
    local date = require 'date'
    -- Get the local time.
    local tDateNow = date(false)
    -- Get the lower 2 digits of the year.
    local ulYear = tDateNow:getisoyear() % 100
    -- Get the week number.
    local ulWeek = tDateNow:getisoweeknumber()
    local usProductionDate = ulYear*256 + ulWeek

    local atPretzelAttr = {
      group = strMacGroupName,
      manufacturer = ulManufacturer,
      devicenr = ulDeviceNr,
      serialnr = ulSerial,
      hwrev = ulHwRev,
      productiondate = usProductionDate,
      deviceclass = ulDeviceClass,
      hwcompaibility = ulHwComp
    }

    self:__program_blank_device(tContext, atBlankDevices[1], atPretzelAttr)

  else
    error('More than 1 matching blank FTDI found.')
  end

  -- Close the FTDI context.
  tContext:usb_close()

  print("")
  print(" #######  ##    ## ")
  print("##     ## ##   ##  ")
  print("##     ## ##  ##   ")
  print("##     ## #####    ")
  print("##     ## ##  ##   ")
  print("##     ## ##   ##  ")
  print(" #######  ##    ## ")
  print("")
end

return TestClassFtdiEepromInit
