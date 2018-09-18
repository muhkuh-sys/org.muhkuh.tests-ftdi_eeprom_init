local FtdiEepromInit = require 'FtdiEepromInit'
return function(ulTestID, tLogWriter, strLogLevel) return FtdiEepromInit('@NAME@', ulTestID, tLogWriter, strLogLevel) end
