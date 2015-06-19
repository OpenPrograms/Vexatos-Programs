local shell = require("shell")
if _G._selene and _G._selene.liveMode then
  shell.execute("lua")
else
  local env = setmetatable({}, {__index = _ENV})
  local parser = require("selene.parser")
  env._PROMPT = "selene> "
  local oldload = env.load
  env.load = function(ld, src, mv, env) 
    local s = ""
    if type(ld) == "function" then
      local nws = ld()
      while nws and #nws > 0 do
        s = s .. nws
        nws = ld()
      end
    end
    ld = parser.parse(ld)
    return oldload(ld, src, mv, env)
  end
  shell.execute("lua", env)
end
