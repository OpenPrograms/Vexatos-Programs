--[[
Simple BigReactors Reactor Control program
Usage:
  Reactor producing RF:
    bigreactors-control [-s] [turnOn [, turnOff] ]
  -s makes the program not print anything to the screen; will automatically enable this option if there is no screen and GPU available
  Optional arguments are turnOn and turnOff, allowing you to specify when to turn the reactor on and when to turn it off. Default values are 0.1 and 0.9
  If you have turbines connected to the computer and the reactor is in steam-producing mode, it will automatically detect that.
  In turbine mode, it will try to keep the turbines at a certain speed.
    bigreactors-control [-s] [-b] [desiredSpeed [, acceptedSpeed] ]
  desiredSpeed then allows you to set the desired rotations per minute. it will default to 1790.
  acceptedSpeed is the amount the turbine's rotation speed may vary from the desired speed before the program starts reacting. Defaults to 50.
  -b will make the program run the reactor at 100% for a few seconds to find out how much it can produce at most and will then set the control rods to
  make the reactor only produce as much steam as needed. Make sure to extract all steam from the reactor while the evaluation is running,
  otherwise it might not find the best possible value! If it is not possible to extract all steam, you should consider running the program without -b
  and manually set the control rods.
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
local desiredSpeed = 1790
--The amount the turbine's rotation speed may vary from the desired speed before the program starts reacting
local acceptedSpeed = 50
--The amount of steam one turbine can take per tick, in milibuckets
local neededSteam = 2000


--Code you probably won't need to change starts here


--Loading the required libraries
local component = require("component")
local keyboard = require("keyboard")
local term = require("term")

--This is true if there is no available screen or the option -s is used
local silent = not term.isAvailable()

local hasCustomValues, shouldChangeRods = false, false

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
  if options.b then shouldChangeRods = true end
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

local lb = component.isAvailable("light_board") and component.light_board or nil

local turbines = {}

if reactor.isActivelyCooled() then
  if not component.isAvailable("br_turbine") then
    serror("reactor has coolant ports but no connected turbine found.")
  end
  for addr in component.list("br_turbine") do
    table.insert(turbines, component.proxy(addr))
  end
  maxEnergy = maxEnergyTurbine * #turbines
  neededSteam = neededSteam * #turbines
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
local function offset(num, d, ext)
  if num == nil then return "" end
  if type(num) ~= "string" then
    if type(num) == "number" then
      if ext then
        return offset(tostring(math.floor(num * 100) / 100), d)
      else
        return offset(tostring(math.floor(num)), d)
      end
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

local benchmark, madeSteamMax = 0, 0

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
    if turbine.getInductorEngaged() then
      if speed < (desiredSpeed - acceptedSpeed) then
        turbine.setInductorEngaged(false)
      end
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

  local madeSteam = reactor.getHotFluidProducedLastTick()
  local neededPercent = 100

  if shouldChangeRods then
    if benchmark >= 0 then
      if not reactor.getActive() then
        reactor.setActive(true)
      else
        reactor.setAllControlRodLevels(0)
        if madeSteam - madeSteamMax < 5 and madeSteam - madeSteamMax > -5 then
          if benchmark >= 10 then
            benchmark = -1
          else
            benchmark = benchmark + 1
          end
        else
          benchmark = 0
          madeSteamMax = madeSteam
        end
      end
    else
      if reactor.getActive() then
        neededPercent = math.ceil((neededSteam / madeSteamMax) * 100)
        reactor.setAllControlRodLevels(math.min(math.max(100 - neededPercent, 0), 100))
      end
    end
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
    term.write("Energy Production:  " .. offset(fancyNumber(production), offs) .. " RF/t\n", false)
    term.clearLine()
    term.write("Fuel Consumption:   " .. offset(reactor.getFuelConsumedLastTick(), offs, true) .. " mB/t\n", false)
    if shouldChangeRods then
      term.clearLine()
      local evl = ""
      if benchmark >= 0 then
        evl = " (Evaluating)" .. string.rep(".", benchmark)
      end
      term.write("Reactor power:      " .. offset(neededPercent, offs) .. " %" .. evl .. "\n", false)
    end
    term.clearLine()
    term.write("Steam production:   " .. offset(fancyNumber(madeSteam), offs) .. " mB/t\n", false)
    term.clearLine()
    term.write("Steam consumption:  " .. offset(fancyNumber(neededSteam), offs) .. " mB/t\n", false)
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

local function handleLights()
  lb.setColor(1, reactor.getActive() and 0x00FF00 or 0xFF0000)

  local perc = reactor.getEnergyStored() / maxEnergy
  local green = math.max(math.min(math.ceil(0xFF * ((1 - perc)*2)), 0xFF), 0)
  local red = math.max(math.min(math.ceil(0xFF * (perc * 2)), 0xFF), 0)
  lb.setColor(2, (red << 16) | (green << 8))

  perc = reactor.getFuelAmount() / reactor.getFuelAmountMax()
  red = math.max(math.min(math.ceil(0xE0 * ((1 - perc) * 2)), 0xE0), 0)
  green = math.max(math.min(math.ceil(0xFF * (perc * 2)), 0xFF), 0)
  lb.setColor(3, (red << 16) | (green << 8))

  perc = reactor.getWasteAmount() / 1000
  if perc >= 1 then
    red = 0xFF
    green = 0x00
  else
    green = math.max(math.min(math.ceil(0xE0 * ((1 - perc)*2)), 0xE0), 0)
    red = math.max(math.min(math.ceil(0xFF * (perc * 2)), 0xFF), 0)
  end
  lb.setColor(4, (red << 16) | (green << 8))
end

if lb then
  for i = 1, 4 do
    lb.setActive(i, true)
  end
end

while true do
  handleControl()
  if lb then
    handleLights()
  end

  --Check if the program has been terminated
  if keyboard.isKeyDown(keyboard.keys.w) and keyboard.isControlDown() then
    --Shut down the reactor, place cursor in a new line and exit
    if not silent then
      term.write("\nReactor shut down.\n")
    end
    reactor.setActive(false)
    for _, turbine in ipairs(turbines) do
      turbine.setFluidFlowRateMax(turbine.getFluidFlowRateMaxMax())
      turbine.setInductorEngaged(true)
    end
    if lb then
      for i = 1, 4 do
        lb.setActive(i, false)
      end
    end
    os.exit()
  end
  os.sleep(1)
end
