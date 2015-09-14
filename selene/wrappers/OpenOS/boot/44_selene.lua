if not _G._selene then _G._selene = {} end
_G._selene.liveMode = dofile("/etc/selene.cfg")
if _G._selene.liveMode then
  _G._PROMPT = "selene> "
end

local selene = require("selene")
selene.load()

local computer = require("computer")
selene.parser.setTimeoutHandler(
  function()
    computer.pullSignal(0)
  end,
  function()
    return 3
  end,
  computer.uptime
)
