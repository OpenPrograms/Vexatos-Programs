local shell = require("shell")
local parser = require("selene.parser")

local args, options = shell.parse(...)

local toParse = ""

if #args == 0 or options.h then
  print("Usage:")
  print("selenec <inputfile> [outputfile] to compile the input file and save it into output file or into the default file (./a.lua) if output file is not specified.")
  print("Use '-' as input file to read from standard input")
  print("Use '-' as output file to write to standard output.")
  print("You can use piping with selenec:")
  print("  selenec - - < input.lua > output.lua")
  print("which can by done the standard way:")
  print("  selenec input.lua output.lua")
  print()
  print("selenec -r makes selenec not output but run compiled file")
  print("This option is especially useful when using shebang notation")
  print("To use it add at the begin of selene file following line:")
  print("#!selenec -r")
  print()
  print("selenec -h, selenec --help to show this screen")
  os.exit(true)
end

local function writetofile(file, data)
local file, reason = io.open(shell.resolve(file), "w")
  if not file then
    io.stderr:write("Couldn't write to file \"" .. file .. '":\n')
    io.stderr:write(reason)
    os.exit(false)
  end
  file:write(data)
  file:close()
end


-- read
if args[1] == "-" then
  repeat
    local read = io.read("*L")
    if read then
      toParse = toParse..read
    end
  until not read or #read <= 0
else
  local file, reason = io.open(shell.resolve(args[1]))
  if not file then
    io.stderr:write("Couldn't open file \"" .. args[1] .. '":\n')
    io.stderr:write(reason)
    os.exit(false)
  end
  local source, reason = file:read("*a")
  if not source then
    io.stderr:write("Couldn't read from file \"" .. args[1] .. '":\n')
    io.stderr:write(reason)
    os.exit(false)
  end
  toParse = source
  file:close()
end
  
toParse = toParse:gsub("^#![^\n]+\n", "") -- remove shebang. sh will default to lua.
local parsed = parser.parse(toParse)
parsed = "require("selene")\n" .. parsed

-- decide on write function
if options.r then
  local env = setmetatable({}, {__index = _ENV})
  local argsp = table.unpack(args, 2) -- <fileanme> is 1 so 2nd is the first program argument.
  local script, reason = load(parsed, nil, "t", env)
  if not script then
    io.stderr:write(tostring(reason) .. "\n")
    os.exit(false)
  end
  local result, reason = pcall(script, argsp)
  if not result then
    io.stderr:write(reason)
    os.exit(false)
  end
elseif #args == 1 then
  io.stdout:write("No output file specified. Writting to ./a.lua")
  writetofile("./a.lua", parsed)
elseif #args == 2 then
  if args[2] ~= "-" then
    writetofile(args[2], parsed)
  else
    io.write(parsed)
  end
end
