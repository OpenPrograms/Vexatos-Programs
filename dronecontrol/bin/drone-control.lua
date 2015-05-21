--[[
Drone Control, a Client and Drone BIOS to make drones load code to execute from the client.
Requires Wireless Network Cards in the client and all the drones.
To use it, flash share/bios/drone-control.lua onto each drone you want to use.
Open /etc/drone-control.cfg and enter pairs of the drones' wireless network card addresses
and the file you would like to load onto the drone, like this:
  ["5bc136db-e69a-4c39-877b-899130a8385b"] = "/usr/droneprograms/example.lua",
This would send the code in example.lua to the drone with a Wireless Network card
with the address 5bc136db-e69a-4c39-877b-899130a8385b.
The code, once arrived, will be executed immediately.
Author: Vexatos
]]
local component = require("component")
local event = require("event")
local serial = require("serialization")

local modem = component.modem
modem.open(54542)

local lookup
do
  local path = "/etc/dronecontrol.cfg"
  local file,msg = io.open(path,"rb")
  if not file then
    io.stderr:write("Error while trying to read file at "..path..": "..msg)
    return
  end
  local code = file:read("*a")
  file:close()
  lookup = serial.unserialize(code)
  if not lookup then
    io.stderr:write("Error while trying to read file at "..path..": Could not parse file.")
    lookup = {}
  end
end

local function findCode(addr)
  if lookup[addr] then return loadfile(lookup[addr]) else return nil end
end

local function getMessage(evt, laddr, addr, port, dist, tp, ...)
  return evt, laddr, addr, port, dist, tp, table.pack(...)
end

local psize = modem.maxPacketSize() - 2

while true do
  local evt, _, addr, _, _, tp, msg = getMessage(event.pull(5, "modem_message"))

  if tp and tp == "fromdrone" then
    if #msg >= 1 and msg[1] == "coderequest" then
      local packs = {}
      local code = findCode(addr)
      if code then
        while #code > 0 and code ~= "" do
          local part = code:sub(1, psize)
          table.insert(packs, part)
          code = code:sub(psize + 1)
        end
        for i,p in ipairs(packs) do
          modem.send(addr, 54542, "codepart", p)
          os.sleep(0.2)
        end
        modem.send(addr, 54542, "codepart", "done")
      end
    else
      print(addr, tp, table.unpack(msg))
    end
  end
end