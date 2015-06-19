if not _selene then _selene = {} end
_selene.liveMode = dofile("/etc/selene.cfg")
if _selene.liveMode then
  _PROMPT = "selene> "
  kernel.userspace._PROMPT = _PROMPT
end

_selene.initDone = true
local selene = kernel.userspace.require("selene")
_selene.initDone = false
selene.load(kernel.userspace)
