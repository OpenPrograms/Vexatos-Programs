local shell = require("shell")
local component = require("component")

local args, options = shell.parse(...)

if #args < 1 then
  print("Usage:")
  print("holocol <color> - sets the primary hologram color.")
  print("holocol <color1> [, color2 [, color3]] - sets multiple colors for a Tier 2 Hologram Projector.")
  return
end

if not component.isAvailable("hologram") then
  io.stderr:write("This program requires a Hologram Projector to run.")
  return
end

local hol = component.hologram

local colors = {tonumber(args[1]), tonumber(args[2]), tonumber(args[3])}

if colors[1] then
  if colors[1] < 0x0 or colors[1] > 0xFFFFFF then
    io.stderr:write("First color needs to be between 0x0 and 0xFFFFFF")
    return
  end
  hol.setPaletteColor(1, colors[1])
end

if colors[2] then
  if colors[1] < 0x0 or colors[1] > 0xFFFFFF then
    io.stderr:write("Second color needs to be between 0x0 and 0xFFFFFF")
    return
  end
  hol.setPaletteColor(2, colors[2])
end

if colors[3] then
  if colors[1] < 0x0 or colors[1] > 0xFFFFFF then
    io.stderr:write("Third color needs to be between 0x0 and 0xFFFFFF")
    return
  end
  hol.setPaletteColor(3, colors[3])
end