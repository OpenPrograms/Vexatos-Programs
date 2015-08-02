--This will make Selene work once ComputerCraft uses Lua 5.2.
if not _G._selene then _G._selene = {} end
local success, mode = pcall(dofile, "/etc/selene.cfg")
if success then
  _G._selene.liveMode = mode
else
  _G._selene.liveMode = false
end

require("selene")
