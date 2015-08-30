if not _G._selene then _G._selene = {} end
_G._selene.liveMode = dofile("/etc/selene.cfg")
if _G._selene.liveMode then
  _G._PROMPT = "selene> "
end
require("selene").load()
