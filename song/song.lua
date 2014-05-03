--[[Runs notes inside a table using special syntax, the Note API and computer.beep
  Examples:
  "E5": Plays the note "E5" for the duration specified in the second parameter (default 0.125, equaling 120 bpm)
  "-E5": Plays the note "E5" with double the specified duration
  "E5_4": Plays the note "E5" with 4 times the specified duration, change "4" to any number x to play the note x times the duration specified
  "P_4": Plays a pause with 4 times the specified duration, change "4" to any number x to play the note x times the duration specified
  For note names, use the syntax of the strings of the Note API
]]

local n = require(notes)
local song = {}
function song.play(notes,shortest)
  if not type(notes) == "table" then
    error("Wrong input given, song.play requires a table as first parameter",2)
  end
  if not type(shortest)=="number" then
    shortest = 0.125
  end
  if not shortest then shortest = 0.125 end
  local duration
  for i,j in ipairs(notes) do
    if string.find(j,"P") then
      os.sleep(shortest*tonumber(string.match(j,"P_(%d+)")))
      duration = 0
    elseif string.find(j,"%-") then
      duration = 2
    elseif string.find(j,"_") then
      duration = tonumber(string.match(j,".*_(%d+)"))
    else
      duration = 1
    end
    if duration ~= 0 then
      n.play(string.match(j,"(%a.?%d)_?%d*"),shortest*duration)
    end
  end
end

return song
