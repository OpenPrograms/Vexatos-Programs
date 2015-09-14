local function initSelene()
  local u = kernel.userspace
  if not u._selene then u._selene = {} end
  u._selene.liveMode = u.dofile("/etc/selene.cfg")
  if u._selene.liveMode then
    u._PROMPT = _PROMPT
  end

  local selene = u.require("selene")
  selene.load(u)

  selene.parser.setTimeoutHandler(
    function()
      u.os.sleep(0)
    end,
    function()
      return 3
    end,
    computer.uptime
  )
end

function start()
  kernel.modules.keventd.listen("init", function()
    initSelene()
  end)
end
