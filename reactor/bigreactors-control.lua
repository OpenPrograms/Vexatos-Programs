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
      turnOn = args[1]
      turnOff = args[2]
    end
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
local function offsetNumber(n, d)
  local num = tostring(math.floor(n))
  if d <= #num then return num end
  return string.rep(" ", d - #num) .. num
end

if not silent then
  print("Press Ctrl+W to stop.")
end

--Get the current y position of the cursor for the RF display
local _,y = term.getCursor()

while true do
  --Get the current amount of energy stored
  local stored = reactor.getEnergyStored()
  --Write the currently stored energy, the percentage value and the current production rate to screen
  if not silent then
    term.setCursor(1, y)
    term.clearLine()
    term.write("Currently stored:   " .. offsetNumber(fancyNumber(stored), #tostring(maxEnergy)) .. "RF\n", false)
    term.clearLine()
    term.write("Stored percentage:  " .. offsetNumber(stored / maxEnergy * 100, 3) .. "%\n", false)
    term.clearLine()
    term.write("Current Production: " .. offsetNumber(reactor.getEnergyProducedLastTick(), #tostring(maxEnergy)) .. "RF/t", false)
  end
  
  if stored/maxEnergy <= turnOn and not reactor.isActive() then
    --The reactor is off, but the power is below the turnOn percentage
    reactor.setActive(true)
  elseif stored/maxEnergy >= turnOff and reactor.isActive() then
    --The reactor is on, but the power is above the turnOff percentage
    reactor.setActive(false)
  end

  --Check if the program has been terminated
  if keyboard.isKeyDown(keyboard.keys.w) and keyboard.isControlDown() then
    --Shut down the reactor, place cursor in a new line and exit
    if not silent then
      term.write("\nReactor shut down.\n")
    end
    reactor.setActive(false)
    os.exit()
  end
  os.sleep(1)
end
