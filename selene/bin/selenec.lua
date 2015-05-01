local shell = require("shell")
local selene = require("selene")

local args, options = shell.parse(...)
local toParse = ""
if options.p then
  -- For piping
  repeat
    local read = io.read("*L")
    if read then
      toParse = toParse..read
    end
  until not read or #read <= 0
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
    local parsed = selene.parse(toParse)
    local newFile, newReason = io.open(shell.resolve(args[2]), "w")
    if not file then
      io.stderr:write(reason)
      return
    end
    newFile:write(parsed)
    newFile:close()
  end
else
  print("Usage:")
  print("selenec <inputfile> <outputfile> to compile the input file and save it into the output file")
  print("selenec -p to use with piping: ")
  print("selenec -p < input.lua > output.lua")
end