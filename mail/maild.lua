local fs = require("filesystem")
local component = require("component")
local process = require("process")

if not component.isAvailable("modem") then
  io.stderr:write("This program requires a modem to run.\n")
  return
end
local modem = component.modem

local tunnel = nil
if component.isAvailable("tunnel") then
  tunnel = component.tunnel
end

local datpath = fs.concat(fs.path(shell.resolve(process.running())),"/data")
if not fs.exists(datpath) or not fs.isDirectory() then
  fs.remove(datpath)
  fs.makeDirectory(datpath)
end
