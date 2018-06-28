local Pretzel = {}


-- This is the hostname or the ip of the pretzel server.
Pretzel.CFG_Pretzel_Server = "MACSERVER"
-- This is the database name.
Pretzel.CFG_Pretzel_DB     = "pretzel"
-- This is the database user with READ-ONLY rights.
Pretzel.CFG_Pretzel_User   = "pretzel_info"
-- This is the password for the database user with READ-ONLY rights.
Pretzel.CFG_Pretzel_Pwd    = "pretzel_info"



function Pretzel:__curl_progress(ulDlTotal, ulDlNow)
  print(string.format('%d%% (%d/%d)', ulDlTotal/ulDlNow*100, ulDlNow, ulDlTotal))
  return true
end



function Pretzel:__curl_download(aucBuffer)
  table.insert(self.atDownloadData, aucBuffer)
  return true
end



function Pretzel:__get_url(strUrl)
  local tResult = nil
  local curl = require 'lcurl'
  local tCURL = curl.easy()

  tCURL:setopt_url(strUrl)

  -- Collect the received data in a table.
  self.atDownloadData = {}
  tCURL:setopt(curl.OPT_FOLLOWLOCATION, true)
  tCURL:setopt_writefunction(self.__curl_download, self)
  tCURL:setopt_progressfunction(self.__curl_progress, self)

  local tCallResult, strError = pcall(tCURL.perform, tCURL)
  if tCallResult~=true then
    error(string.format('Failed to retrieve URL "%s": %s', strUrl, strError))
  else
    local uiHttpResult = tCURL:getinfo(curl.INFO_RESPONSE_CODE)
    if uiHttpResult==200 then
      tResult = table.concat(self.atDownloadData)
    else
      error(string.format('Error downloading URL "%s": HTTP response %s', strUrl, tostring(uiHttpResult)))
    end
  end
  tCURL:close()

  return tResult
end



function Pretzel:__get_group_idx(tConnection, strGroup)
  local ulGroupIndex


  local strQuery = string.format("SELECT idx FROM groups WHERE name='%s'", strGroup)
  local tCursor = tConnection:execute(strQuery)
  if not tCursor then
    print(string.format("Failed to execute the query: %s", strQuery))
  else
    local aRow = tCursor:fetch({}, "a")
    if not aRow then
      print(string.format("Group not found: %s", strGroup))
    else
      -- Get the group index.
      ulGroupIndex = tonumber(aRow["idx"])
    end

    -- Close the cursor.
    tCursor:close()
  end

  return ulGroupIndex
end



function Pretzel:__get_pools_in_group(tConnection, strGroup)
  local astrPools


  -- Get the index of the group.
  local ulGroupIndex = self:__get_group_idx(tConnection, strGroup)
  if ulGroupIndex~=nil then
    -- Get all members of the group.
    local strQuery = string.format("SELECT name FROM pools WHERE groupidx=%d", ulGroupIndex)
    local tCursor, strError = tConnection:execute(strQuery)
    if not tCursor then
      print(string.format('Failed to execute the query "%s": %s', strQuery, strError))
    else
      astrPools = {}
      repeat
        local aRow = tCursor:fetch({}, "a")
        if aRow then
          table.insert(astrPools, aRow["name"])
        end
      until not aRow

      -- Close the cursor.
      tCursor:close()
    end
  end

  return astrPools
end



function Pretzel:request(dev_par, cnt)
  local aucResult


  print("pretzel request")

  -- Get a MAC address from the server.
  local strUrl = string.format('http://%s/pretzel/index.php?area=reqmac&group=%s&cnt=%d&manufacturer=%d&devicenr=%d&serialnr=%d&hwrev=%d&productiondate=%d&deviceclass=%d&hwcompaibility=%d', self.CFG_Pretzel_Server, dev_par.group, cnt, dev_par.manufacturer, dev_par.devicenr, dev_par.serialnr, dev_par.hwrev, dev_par.productiondate, dev_par.deviceclass, dev_par.hwcompaibility)
  print("MAC query: " .. strUrl)

  local tResponse = self:__get_url(strUrl)
  print("server's response: " .. tResponse)

  -- Check the response.
  if tResponse==nil then
    error('Failed to request a new FTDI serial.')
  else
    local mac,size = string.match(tResponse, '\*(%x+),(%d+)')
    if not mac then
      print("Failed to query mac address!")
    elseif cnt~=tonumber(size) then
      print("Failed to query mac address:")
      print("Server response does not match the request:")
      print("asked for "..cnt.." addresses, got "..size)
    else
      print("Success:", mac, size)
      mac = string.sub('00000000000' .. mac, -12)

      aucResult = {}
      for i=0,5 do
        table.insert(aucResult, tonumber('0x' .. mac:sub(i*2+1, i*2+2)))
      end
    end
  end

  return aucResult
end


-----------------------------------------------------------------------------
--- Get all pretzel entries for a board.
-- A board is specified by its manufacturer, device number and the serial number.
--
-- @param strGroup Group name of the MAC pool as a string
-- @param ulManufacturer The board's manufacturer number
-- @param ulDeviceNr The board's device number
-- @param ulSerialNr The board's serial number
--
-- @return nil if an error occured
-- @return a table with 0 or more entries 
--
function Pretzel:get_board_info(strGroup, ulManufacturer, ulDeviceNr, ulSerialNr)
  local board_info
  local luasql = require 'luasql.mysql'

  -- Create a MySQL environment.
  local tEnv = luasql.mysql()
  if not tEnv then
    print "failed to create mysql environment!"
  else
    -- Open a connection to the database.
    local tConnection = tEnv:connect(self.CFG_Pretzel_DB, self.CFG_Pretzel_User, self.CFG_Pretzel_Pwd, self.CFG_Pretzel_Server)
    if not tConnection then
      print "failed to connect to the database!"
    else
      -- Initialize the board infos.
      board_info = {}

      -- Get all pools in the group.
      local astrPools = self:__get_pools_in_group(tConnection, strGroup)
      for _, strPool in pairs(astrPools) do
        local strQuery = string.format("SELECT HEX(mac),hwrev,deviceclass,hwcompatibility,assigndate,productiondate from %s WHERE valid=1 AND manufacturer=%d AND devicenr=%d AND serial=%d", strPool, ulManufacturer, ulDeviceNr, ulSerialNr)
        local tCursor, strError = tConnection:execute(strQuery)
        if not tCursor then
          print(string.format('Failed to execute the query "%s": %s', strQuery, strError))
          break
        else
          -- Get all rows.
          repeat
            row = tCursor:fetch({}, "a")
            if row then
              row.mac = string.sub("000000000000"..row["HEX(mac)"], -12)
              row["HEX(mac)"] = nil
              table.insert(board_info, row)
            end
          until not row
          -- Close the cursor.
          tCursor:close()
        end
      end

      -- Close the connection.
      tConnection:close()
    end
    -- close the environment
    tEnv:close()
  end

  return board_info
end



return Pretzel
