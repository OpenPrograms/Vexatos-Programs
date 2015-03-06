--[[
Simple BigReactors Reactor Control program
Usage:
  bigreactors-control [-s] [turnOn turnOff]
  -s makes the program not print anything to the screen; will automatically enable this option if there is no screen and GPU available
  Optional arguments are turnOn and turnOff, allowing you to specify when to turn the reactor on and when to turn it off. Default values are 0.1 and 0.9
Author: Vexatos
]]

--These are the values everyone needs to set for themselves

--Default 0.1 - Turn on when equal to or below 10%
local turnOn = 0.1
--Default 0.9 - Turn off when equal to or above 90%
local turnOff = 0.9
--The maximum amount of energy the reactor can store
local maxEnergy = 10000000


--Code you probably won't need to change starts here


--Loading the required libraries
local component = require("component")
local keyboard = require("keyboard")
local term = require("term")

--This is true if there is no available screen or the option -s is used
local silent = not term.isAvailable()

do
  local shell = require("shell")
  local args, options = shell.parse(...)
  if options.s then silent = true end
  if #args > 0 then
    if #args < 2 then
      if silent then
        error("invalid number of arguments. needs to be 0 or 2")
      else
        io.stderr:write("invalid number of arguments, needs to be 0 or 2")
        return
      end
    else
      turnOn = tonumber(args[1])
      turnOff = tonumber(args[2])
    end
  end
end

if turnOn < 0 or turnOn > 1 or turnOff < 0 or turnOff > 1 then
  if silent then
    error("turnOn and turnOff both need to be between 0 and 1")
  else
    io.stderr:write("turnOn and turnOff both need to be between 0 and 1")
    return
  end
end

--Check whether there is a Reactor Computer Port to access
if not component.isAvailable("br_reactor") then
  if silent then
    error("no connected Reactor Computer Port found.")
  else
    io.stderr:write("This program requires a connected Reactor Computer Port to run.")
    return
  end
end

--Getting the primary port
local reactor = component.br_reactor

--Displays long numbers with commas
local function fancyNumber(n)
  return tostring(math.floor(n)):reverse():gsub("(%d%d%d)", "%1,"):gsub("%D$",""):reverse()
end

--Displays numbers with a special offset
local function offset(num, d)
  if type(num) ~= "string" then
    if type(num) == "number" then
      return offset(tostring(math.floor(num)), d)
    end
    return offset(tostring(num), d)
  end
  if d <= #num then return num end
  return string.rep(" ", d - #num) .. num
end

if not silent then
  component.gpu.setResolution(component.gpu.maxResolution())
  term.clear()

  print("Press Ctrl+W to stop.")
end

--Get the current y position of the cursor for the RF display
local _,y = term.getCursor()

--The interface offset
local offs = #tostring(maxEnergy) + 5

while true do
  --Get the current amount of energy stored
  local stored = reactor.getEnergyStored()
  
  if stored/maxEnergy <= turnOn and not reactor.getActive() then
    --The reactor is off, but the power is below the turnOn percentage
    reactor.setActive(true)
  elseif stored/maxEnergy >= turnOff and reactor.getActive() then
    --The reactor is on, but the power is above the turnOff percentage
    reactor.setActive(false)
  end

  --Write the reactor state, the currently stored energy, the percentage value and the current production rate to screen
  if not silent then
    term.setCursor(1, y)
    term.clearLine()
    local state = reactor.getActive()
    if state then
      state = "On"
    else
      state = "Off"
    end
    term.write("Reactor state:      " .. offset(state, offs) .. "\n", false)
    term.clearLine()
    term.write("Currently stored:   " .. offset(fancyNumber(stored), offs) .. " RF\n", false)
    term.clearLine()
    term.write("Stored percentage:  " .. offset(stored / maxEnergy * 100, offs) .. "%\n", false)
    term.clearLine()
    term.write("Current Production: " .. offset(reactor.getEnergyProducedLastTick(), offs) .. " RF/t", false)
  end

  --Check if the program has been terminated
  if keyboard.isKeyDown(keyboard.keys.w) and keyboard.isControlDown() then
    --Shut down the reactor, place cursor in a new line and exit
    if not silent then
      term.write("Reactor shut down.\n")
    end
    reactor.setActive(false)
    os.exit()
  end
  os.sleep(1)
end
