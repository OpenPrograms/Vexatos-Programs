local shell = require("shell")
local selene = require("selene")

local args = shell.parse(...)
local toParse = ""
if #args == 0 then
  -- For piping
  repeat
    local read = io.read("*L")
    if read then
      toParse = toParse..read
    end
  until not read
  local parsed = selene.parse(toParse)
  io.write(parsed)
elseif args[1] and args[2] then
  local file, reason = io.open(shell.resolve(args[1]))
  if not file then
    io.stderr:write(reason)
    return
  end
  repeat
    local source, reason = file:read("*a")
    if not source then
      io.stderr:write(reason)
      return
    end
    toParse = source
  until not line
  file:close()
  if #toParse > 0 then
    local newFile, newReason = io.open(shell.resolve(args[2]), "w")
    if not file then
      io.stderr:write(reason)
      return
    end
    local parsed = selene.parse(toParse)
    file:write(parsed)
    newFile:close()
  end
else
  print("Usage:")
  print("selenec <inputfile> <outputfile> to compile the input file and save it into the output file")
  print("Can also be used with redirecting:")
  print("selenec < input.lua > output.lua")
end