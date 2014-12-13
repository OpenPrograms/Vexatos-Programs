--[[Runs notes inside a table or a string (notes seperated by free spaces, then) using special syntax, the Note API and computer.beep
  Examples:
  "E5": Plays the note "E5" for the duration specified in the second parameter (default 0.125, equaling 120 bpm)
  "-E5": Plays the note "E5" with double the specified duration
  "E5_4": Plays the note "E5" with 4 times the specified duration, change "4" to any number x to play the note x times the duration specified
  "P_4": Plays a pause with 4 times the specified duration, change "4" to any number x to play the note x times the duration specified
  For note names, use the syntax of the strings of the Note API
  
  if you set the third parameter to true, you may insert a table containing tables or strings looking the same as explained above.
  This will allow you to play multiple channels of a song simultaneously, up to 8 at a time.
  This mode requires the mod Computronics to be present and the computer to contain a Beep Card from that mod.
]]

local n = require("note")
local song = {}

local function insertSynchronized(tMain, tInsert)
  tMain = tMain or {}
  if not tInsert then
    error("Error during song parsing, found nil insert table", 2)
  elseif #tInsert == 0 then
    return tMain
  end
  if #tMain == 0 then
    for i,j in ipairs(tInsert) do
      table.insert(tMain, {j[1], {j[2]}})
    end
    return tMain
  end
  
  --now the fun begins
  
  for i,j in ipairs(tInsert) do
    for k,v in ipairs(tMain) do
      --is the time frame already there?
      if v[1] == j[1] then
        table.insert(v[2], j[2])
        break
      elseif  v[1] > j[1] then
       --it is not.
       table.insert(tMain, k, {j[1], {j[2]}})
       break
      end
    end
  end
  return tMain
end

function song.play(notes, shortest, multi)
  if not shortest then shortest = 0.125 end
  if not type(shortest)=="number" then
    shortest = 0.125
  end
  multi = multi or false
  if not type(multi)=="boolean" then
    multi = false
  end
  if not multi then
    local typo = type(notes)
    if typo == "table" then
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
    elseif typo == "string" then
      local duration
      for j in string.gmatch(notes,"%S+") do
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
    else
      error("Wrong input given, song.play requires a table or a string as first parameter",2)
    end
  else
    --beep card mode
    local component = require("component")
    if not component.isAvailable("beep") then
      error("No beep card found, not possible to have multiple sound channels")
    end
    local beep = component.beep
    local freqMap = {}
    
    --parsing start
    
    for k,v in ipairs(notes) do
      local duration
      local timeMap = {}
      local timecount = 0
      local pause = -1
      if(type(v) == "string") then
        local tB = {}
        for j in string.gmatch(notes,"%S+") do
          table.insert(tB, j)
        end
        v = tB
      end
      for i,j in ipairs(v) do
        if string.find(j,"P") then
          --os.sleep(shortest*tonumber(string.match(j,"P_(%d+)")))
          duration = 0
        elseif string.find(j,"%-") then
          duration = 2
        elseif string.find(j,"_") then
          duration = tonumber(string.match(j,".*_(%d+)"))
        else
          duration = 1
        end
        if duration ~= 0 then
          table.insert(timeMap, {timecount, {n.freq(string.match(j,"(%a.?%d)_?%d*")), shortest*duration}})
          timecount = timecount + duration
        else
          table.insert(timeMap, {timecount, {pause, shortest*tonumber(string.match(j,"P_(%d+)"))}})
          timecount = timecount + tonumber(string.match(j,"P_(%d+)"))
          pause = pause - 1
        end
      end
      --timeMap: {{time, {freq, duration}}, {time2, freq2, duration2}}}
      insertSynchronized(freqMap, timeMap)
    end
    --freqMap: {{time, {channel={freq, duration}, channel2={freq2, duration2}}}, {time3, {channel3={freq3, duration3}, channel4={freq4, duration4}}}}
    
    --parsing end
    
    for k,v in ipairs(freqMap) do
      local fMap = {}
      for i,j in pairs(v[2]) do
        if type(j[1]) == "number" and j[1] >= 0 then
          fMap[j[1]] = j[2]
        else
          --pause here
        end
      end
      beep.beep(fMap)
      if k < #freqMap - 1 then
        os.sleep((freqMap[k+1][1] - v[1]) * shortest)
      end
    end
  end
end

return song
