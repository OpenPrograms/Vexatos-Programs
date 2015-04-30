if not _G.selene then _G.selene = {} end
local okay, reason = load("/etc/selene.cfg")
if not okay then
  io.stderr:write('failed loading config: ' .. reason .. "\n")
  _G.selene.liveMode = true
else
  _G.selene.liveMode = okay()
end
require("selene")
