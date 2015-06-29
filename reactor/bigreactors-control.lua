--[[
Simple BigReactors Reactor Control program
Usage:
  Reactor producing RF:
    bigreactors-control [-s] [turnOn [, turnOff] ]
  -s makes the program not print anything to the screen; will automatically enable this option if there is no screen and GPU available
  Optional arguments are turnOn and turnOff, allowing you to specify when to turn the reactor on and when to turn it off. Default values are 0.1 and 0.9
  If you have turbines connected to the computer and the reactor is in steam-producing mode, it will automatically detect that.
  In turbine mode, it will try to keep the turbines at a certain speed.
    bigreactors-control [-s] [desiredSpeed [, acceptedSpeed] ]
  desiredSpeed then allows you to set the desired rotations per minute. it will default to 1800.
  acceptedSpeed is the amount the turbine's rotation speed may vary from the desired speed before the program starts reacting. Defaults to 50.
Author: Vexatos
]]

--These are the values everyone needs to set for themselves

--Default 0.1 - Turn on when equal to or below 10%
local turnOn = 0.1
--Default 0.9 - Turn off when equal to or above 90%
local turnOff = 0.9
--The maximum amount of energy a reactor can store
local maxEnergy = 10000000
--The maximum amount of energy a turbine can store
local maxEnergyTurbine = 1000000
--The desired rotations per minute of a turbine if the program runs in turbine mode
local desiredSpeed = 1800
--The amount the turbine's rotation speed may vary from the desired speed before the program starts reacting
local acceptedSpeed = 50


--Code you probably won't need to change starts here


--Loading the required libraries
local component = require("component")
local keyboard = require("keyboard")
local term = require("term")

--This is true if there is no available screen or the option -s is used
local silent = not term.isAvailable()

local hasCustomValues = false

local function serror(msg, msg2)
  msg2 = msg2 or msg
  if silent then
    error(msg, 2)
  else
    io.stderr:write(msg2)
    os.exit()
  end
end

do
  local shell = require("shell")
  local args, options = shell.parse(...)
  if options.s then silent = true end
  if #args > 0 then
    turnOn = tonumber(args[1])
    turnOff = tonumber(args[2])
    hasCustomValues = true
  end
end

--Check whether there is a Reactor Computer Port to access
if not component.isAvailable("br_reactor") then
  serror("no connected Reactor Computer Port found.", "This program requires a connected Reactor Computer Port to run.")
end

--Getting the primary port
local reactor = component.br_reactor

local turbines = {}

if reactor.isActivelyCooled() then
  if not component.isAvailable("br_turbine") then
    serror("reactor has coolant ports but no connected turbine found.")
  end
  for addr in component.list("br_turbine") do
    table.insert(turbines, component.proxy(addr))
  end
  maxEnergy = maxEnergyTurbine * #turbines
  if hasCustomValues then
    desiredSpeed = turnOn or desiredSpeed
    acceptedSpeed = turnOff or acceptedSpeed
  end
else
  if turnOn < 0 or turnOn > 1 or turnOff < 0 or turnOff > 1 then
    serror("turnOn and turnOff both need to be between 0 and 1")
  end
end

--Displays long numbers with commas
local function fancyNumber(n)
  return tostring(math.floor(n)):reverse():gsub("(%d%d%d)", "%1,"):gsub("%D$",""):reverse()
end

--Displays numbers with a special offset
local function offset(num, d)
  if num == nil then return "" end
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
local y, h
do
  local x,w
  x,y = term.getCursor()
  w,h = component.gpu.getResolution()
end

--The interface offset
local offs = #tostring(maxEnergy) + 5

local function handleReactor()
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
    term.write("Stored percentage:  " .. offset(stored / maxEnergy * 100, offs) .. " %\n", false)
    term.clearLine()
    term.write("Current Production: " .. offset(fancyNumber(reactor.getEnergyProducedLastTick()), offs) .. " RF/t", false)
  end
end

local function handleTurbines()
  local stored, production, engagedCoils, shutPorts = 0, 0, 0, 0
  local rotations = {}
  local shouldReactorRun = false
  for _, turbine in ipairs(turbines) do
    if not turbine.getActive() then
      turbine.setActive(true)
    end
    stored = stored + turbine.getEnergyStored()
    production = production + turbine.getEnergyProducedLastTick()
    local speed = turbine.getRotorSpeed()
    table.insert(rotations, speed)

    local flowRate = turbine.getFluidFlowRateMax()
    local flowMax = turbine.getFluidFlowRateMaxMax()
    if speed > (desiredSpeed + acceptedSpeed) then
      if flowRate > 0 then
        turbine.setFluidFlowRateMax(0)
      end
      shutPorts = shutPorts + 1
    else
      if flowRate < flowMax then
        turbine.setFluidFlowRateMax(flowMax)
      end
      if not shouldReactorRun then
        shouldReactorRun = true
      end
    end
    if speed < (desiredSpeed - acceptedSpeed) and turbine.getInductorEngaged() then
      turbine.setInductorEngaged(false)
    else
      engagedCoils = engagedCoils + 1
    end
    if speed > desiredSpeed then
      if not turbine.getInductorEngaged() then
        turbine.setInductorEngaged(true)
      end
    end
  end
  
  if shouldReactorRun and not reactor.getActive() then
    reactor.setActive(true)
  elseif not shouldReactorRun and reactor.getActive() then
    reactor.setActive(false)
  end
  
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
    term.write("Stored percentage:  " .. offset(stored / maxEnergy * 100, offs) .. " %\n", false)
    term.clearLine()
    term.write("Current Production: " .. offset(fancyNumber(production), offs) .. " RF/t\n", false)
    term.clearLine()
    term.write("Engaged Coils:      " .. offset(engagedCoils, offs) .. "\n", false)
    term.clearLine()
    term.write("Shut fluid ports:   " .. offset(shutPorts, offs) .. "\n", false)
    term.clearLine()
    term.write("Turbine speed:      ", false)
    if #rotations >= 1 then
      term.write(offset(rotations[1], offs) .. " RPM\n", false)
    end
    if #rotations >= 2 then
      local _, currentY = term.getCursor()
      for i = 2, math.min(#rotations, 1 + h - currentY) do
        term.clearLine()
        term.write(offset(rotations[i], offs + 20) .. " RPM\n", false)
      end
    end
  end
end

local handleControl = handleReactor
if #turbines > 0 then
  handleControl = handleTurbines
end

while true do
  handleControl()

  --Check if the program has been terminated
  if keyboard.isKeyDown(keyboard.keys.w) and keyboard.isControlDown() then
    --Shut down the reactor, place cursor in a new line and exit
    if not silent then
      term.write("\nReactor shut down.\n")
    end
    reactor.setActive(false)
    for _, turbine in ipairs(turbines) do
      turbine.setFluidFlowRateMax(turbine.turbine.getFluidFlowRateMaxMax())
      turbine.setInductorEngaged(true)
    end
    os.exit()
  end
  os.sleep(1)
end
