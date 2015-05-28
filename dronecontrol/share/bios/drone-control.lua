local addr = component.list("modem")()
local m = component.proxy(addr)
local d=component.proxy(component.list('drone')())
m.open(54541)
local function send(...)
  local args=table.pack(...)
  pcall(function() m.broadcast(54542, "fromdrone", table.unpack(args)) end)
end

local function wait()
  local code = ""
  while true do
    local evt,_,_,_,_, p, cmd = computer.pullSignal(5)
    if evt == nil then
      send("coderequest")
    elseif evt=="modem_message" and p == "codepart" then
      if cmd ~= "done" then
        code = code .. "\n" .. cmd
      else
        return load(code)
      end
    end
  end
end
while true do
  local result,reason=pcall(function()
    local result,reason=wait()
    if not result then return send(reason) end
    send(result())
  end)
  if not result then send(reason) end
end
