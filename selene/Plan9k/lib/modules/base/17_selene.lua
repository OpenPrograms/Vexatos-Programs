if not _G._selene then _G._selene = {} end
_G._selene.liveMode = dofile("/etc/selene.cfg")
if _G._selene.liveMode then
  _G._PROMPT = "selene> "
  kernel.userspace._PROMPT = _G._PROMPT
end

_G._selene.initDone = true
local selene = kernel.userspace.require("selene")
_G._selene.initDone = false
selene.load(kernel.userspace)