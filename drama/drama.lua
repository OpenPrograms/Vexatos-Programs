local term = require("term")
local component = require("component")

if not component.isAvailable("internet") then
  io.stderr:write("This program requires an internet card to run.")
  return
end

local internet = require("internet")
local timeOut = 3
 
while true do
  term.clear()
  term.setCursor(1,1)
 
  local response = internet.request("http://asie.pl/drama.php?plain")
  local drama = response()
  term.write(drama)
  os.sleep(timeOut)
end