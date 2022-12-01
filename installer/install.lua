local t = ...
local tResult

-- Install the complete "doc" folder.
--t:install('doc/', '${install_doc}/')

-- Install the complete "lua" folder.
t:install('lua/', '${install_lua_path}/')

-- Install the complete "parameter" folder.
t:install('parameter/', '${install_base}/parameter/')

tResult = true

return tResult
