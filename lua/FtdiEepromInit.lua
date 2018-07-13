local class = require 'pl.class'
local FtdiEepromInit = class()


function FtdiEepromInit:_init(strTestName)
  self.parameters = require 'parameters'
  self.pl = require'pl.import_into'()
  self.lxp = require 'lxp'

  self.CFG_strTestName = strTestName

  self.CFG_aParameterDefinitions = {
    {
      name="definition_file",
      default=nil,
      help="This is the name of the file holding the EEPROM definition.",
      mandatory=true,
      validate=nil,
      constrains=nil
    },
    {
      name="usb_vendor_id_blank",
      default="0x0403",
      help="The USB vendor ID of the blank device.",
      mandatory=true,
      validate=parameters.test_uint16,
      constrains=nil
    },
    {
      name="usb_product_id_blank",
      default="0x6010",
      help="The USB product ID of the blank device.",
      mandatory=true,
      validate=parameters.test_uint16,
      constrains=nil
    },
    {
      name="group",
      default='testgroup1',
      help="The MAC group for the FTDI IDs.",
      mandatory=true,
      validate=nil,
      constrains=nil
    },
    {
      name="manufacturer",
      default=nil,
      help="The manufacturer ID of the board.",
      mandatory=true,
      validate=parameters.test_uint32,
      constrains=nil
    },
    {
      name="devicenr",
      default=nil,
      help="The device number of the board.",
      mandatory=true,
      validate=parameters.test_uint32,
      constrains=nil
    },
    {
      name="serial",
      default=nil,
      help="The serial number of the board.",
      mandatory=true,
      validate=parameters.test_uint32,
      constrains=nil
    },
    {
      name="hwrev",
      default=nil,
      help="The hardware revision of the board.",
      mandatory=true,
      validate=parameters.test_uint32,
      constrains=nil
    },
    {
      name="deviceclass",
      default=nil,
      help="The device class of the board.",
      mandatory=true,
      validate=parameters.test_uint32,
      constrains=nil
    },
    {
      name="hwcomp",
      default=nil,
      help="The hardware compatibility of the board.",
      mandatory=true,
      validate=parameters.test_uint32,
      constrains=nil
    }
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
function FtdiEepromInit.parseCfg_StartElement(tParser, strName, atAttributes)
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
          ulValue = tonumber(strValue)
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
function FtdiEepromInit.parseCfg_EndElement(tParser, strName)
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
function FtdiEepromInit.parseCfg_CharacterData(tParser, strData)
  -- The current XML definition for the FTDI setting does not use any elements
  -- with character data, so this function is empty for now.
end



--- Parse a FTDI configuration file.
-- @param strFilename The path to the configuration file.
-- @param tLog A lua-log object which can be used for log messages.
-- @param atValidKeys A list of valid keys. It is used to validate the keys pairs in the configuration file and to translate them to numbers.
function FtdiEepromInit:parse_configuration(strFilename, tLog, atValidKeys)
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
    atValidKeys = atValidKeys,
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
    tLog.error('Error reading the file: %s', strError)
  else
    local tParseResult, strMsg, uiLine, uiCol, uiPos = tParser:parse(strXmlText)
    if tParseResult~=nil then
      tParseResult, strMsg, uiLine, uiCol, uiPos = tParser:parse()
    end
    tParser:close()

    if tParseResult==nil then
      tResult = nil
      tLog.error("%s: %d,%d,%d", strMsg, uiLine, uiCol, uiPos)
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



function FtdiEepromInit:__get_mac(atAttr, tLog)
  local aucMac = nil

  local pretzel = require 'pretzel'
  local tBoardInfo = pretzel:get_board_info(atAttr.group, atAttr.manufacturer, atAttr.devicenr, atAttr.serialnr)
  if tBoardInfo==nil then
    tLog.error('Failed to search for the board.')
  end
  if #tBoardInfo == 0 then
    tLog.info('No assigned FTDI serial number found. Request a new one.')

    aucMac = pretzel:request(atAttr, 1)
    if aucMac==nil then
      tLog.error('Failed to request the MAC for the board.')
    end
    tLog.info('Received a new MAC for the board: %02X:%02X:%02X:%02X:%02X:%02X .', aucMac[1], aucMac[2], aucMac[3], aucMac[4], aucMac[5], aucMac[6])
  elseif #tBoardInfo == 1 then
    local tAttr = tBoardInfo[1]
    local strMac = tAttr.mac
    strMac1, strMac2, strMac3, strMac4, strMac5, strMac6 = string.match(strMac, '(%x%x)(%x%x)(%x%x)(%x%x)(%x%x)(%x%x)')
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



function FtdiEepromInit:__get_serial(atAttr, tLog)
  local strSerial = nil

  local aucMac = self:__get_mac(atAttr, tLog)
  if aucMac==nil then
    tLog.error('Failed to get a pseudo MAC for the board. The serial can not be generated.')
  else
    -- Create a 6 digit serial from the pseudo mac.
    strSerial = string.format('HXD%02X%02X%02X', aucMac[4], aucMac[5], aucMac[6])
    tLog.info('Using serial number %s.', strSerial)
  end

  return strSerial
end



function FtdiEepromInit:run(aParameters, tLog)
  ----------------------------------------------------------------------
  --
  -- Parse the parameters and collect all options.
  --

  -- Parse the definition_file option.
  local strDefinitionFile = aParameters['definition_file']
  if strDefinitionFile==nil then
    error('No definition file specified.')
  end
  -- Does the file exist?
  if self.pl.path.exists(strDefinitionFile)==nil then
    error(string.format('Failed to open the definition file "%s".', strDefinitionFile))
  end

  -- Get the USB vendor and product ID of the blank device.
  local usUSBVendorBlank = tonumber(aParameters['usb_vendor_id_blank'])
  local usUSBProductBlank = tonumber(aParameters['usb_product_id_blank'])

  local strMacGroupName = aParameters['group']
  local ulManufacturer = tonumber(aParameters['manufacturer'])
  local ulDeviceNr = tonumber(aParameters['devicenr'])
  local ulSerial = tonumber(aParameters['serial'])
  local ulHwRev = tonumber(aParameters['hwrev'])
  local ulDeviceClass = tonumber(aParameters['deviceclass'])
  local ulHwComp = tonumber(aParameters['hwcomp'])

  local luaftdi = require 'luaftdi'

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

  -- Read the definition file.
  local tResult = self:parse_configuration(strDefinitionFile, tLog, atKeysAsciiToNumber)
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

  -- There must be only 1 blank device available.
  local ulDeviceCnt = 0
  for tListEntry in tList:iter() do
    ulDeviceCnt = ulDeviceCnt + 1
  end
  tLog.info('Found %d blank devices with VID=0x%04x and PID=0x%04x.', ulDeviceCnt, usUSBVendorBlank, usUSBProductBlank)
  if ulDeviceCnt==0 then
    error('No blank FTDI device found.')
  end
  if ulDeviceCnt>1 then
    error('More than 1 blank FTDI found.')
  end

  -- Open the blank device.
  tLog.debug('Open the blank device.')
  local tResult, strError = tContext:usb_open(usUSBVendorBlank, usUSBProductBlank)
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


  -- Get the production date.
  local date = require 'date'
  -- Get the local time.
  local tDateNow = date(false)
  -- Get the lower 2 digits of the year.
  local ulYear = tDateNow:getisoyear() % 100
  -- Get the week number.
  local ulWeek = tDateNow:getweeknumber()
  local usProductionDate = ulYear*256 + ulWeek

  local atAttr = {
    group = strMacGroupName,
    manufacturer = ulManufacturer,
    devicenr = ulDeviceNr,
    serialnr = ulSerial,
    hwrev = ulHwRev,
    productiondate = usProductionDate,
    deviceclass = ulDeviceClass,
    hwcompaibility = ulHwComp
  }

  local strFTDISerial = self:__get_serial(atAttr, tLog)

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

return FtdiEepromInit
