local component=require("component")
local robot=require("robot")
local gpu=component.gpu
local camera = component.camera
local array = " .,-=+xX#"
local monitor = require("term")
local shell = require("shell")
local yp = 1
local spin=0
monitor.clear()
--monitor.setTextScale(0.5)
monitor.setCursor(1,1)

local args = shell.parse(...)
local size = 6
if #args>0 and type(args[1]) == "number" then
  size = args[1]
end

for j = 1,size+1 do
  for i = 1,size+1 do
    local d = camera.distanceDown(0,0)
    --print("d: "..tostring(d))
    local a = 1
    if d >= 0 then a = 8-math.floor(d) end
    --if d >= 0 then a = 2 + (8 - math.min(8, (d/1.2))) end
    if spin==0 then
      monitor.write(string.sub(array, a, a))
    else
      local x,y = monitor.getCursor()
      gpu.set(x-1,y,string.sub(array,a,a))
      monitor.setCursor(x-1,y)
    end
    --monitor.write(d.." ")
    if i<=size then
      robot.forward()
    end
  end
  yp=yp+1
  if spin==0 then
    monitor.setCursor(size+2,yp)
    robot.turnRight()
    robot.forward()
    robot.turnRight()
    spin=1
  else
    monitor.setCursor(1,yp)
    robot.turnLeft()
    robot.forward()
    robot.turnLeft()
    spin=0
  end
end
if size % 2 == 1 then
  robot.turnLeft()
end
