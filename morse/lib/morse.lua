--Morse library to parse strings to redstone signals
local component = require("component")
local computer = require("computer")
local event = require("event")
local sides = require("sides")
local morse = {}
local alphabet = {
  a = ".-",
  b = "-...",
  c = "-.-.",
  d = "-..",
  e = ".",
  f = "..-.",
  g = "--.",
  h = "....",
  i = "..",
  j = ".---",
  k = "-.-",
  l = ".-..",
  m = "--",
  n = "-.",
  o = "---",
  p = ".--.",
  q = "--.-",
  r = ".-.",
  s = "...",
  t = "-",
  u = "..-",
  v = "...-",
  w = ".--",
  x = "-..-",
  y = "-.--",
  z = "--..",
  ["0"] = "-----",
  ["1"] = ".----",
  ["2"] = "..---",
  ["3"] = "...--",
  ["4"] = "....-",
  ["5"] = ".....",
  ["6"] = "-....",
  ["7"] = "--...",
  ["8"] = "---..",
  ["9"] = "----.",
  ["."] = ".-.-.-",
  [","] = "--..--",
  [":"] = "---...",
  [";"] = "-.-.-.",
  ["?"] = "..--..",
  ["-"] = "-....-",
  ["_"] = "..--.-",
  ["("] = "-.--.",
  [")"] = "-.--.-",
  ["'"] = ".----.",
  ["="] = "-...-",
  ["+"] = ".-.-.",
  ["/"] = "-..-.",
  ["@"] = ".--.-.",
  start = "-.-.-",
  stop = "...-.-",
  [" "] = " ",
  }

local reverseAlphabet = {}
do
  for k,v in pairs(alphabet) do
    reverseAlphabet[v]=k
  end
end

assert(component.isAvailable("redstone"),"This program requires a redstone card or redstone I/O block.")
local rs = component.redstone

function morse.encode(str)
  str = string.lower(str)
  local chars = {}
  for char in string.gmatch(str,".") do
    table.insert(chars,char)
  end
  local code = {}
  for _,char in ipairs(chars) do
    assert(alphabet[char] ~= nil and char ~= "." and char ~= "-","Non-parsable character \""..char.."\" found. Check morse.lua to see which characters are supported")
    table.insert(code,alphabet[char])
  end
  return alphabet.start.."____"..table.concat(code,"____").."____"..alphabet.stop
end

function morse.decode(str)
  str = string.gsub(str,"%-%.%-%.%-__","")
  str = string.gsub(str,"__%.%.%.%-%.%-","")
  local chars = {}
  for char in string.gmatch(str,"__.-__") do
    char = string.gsub(char,"^__","")
    char = string.gsub(char,"__$","")
    table.insert(chars,char)
  end
  local code = {}
  for _,char in ipairs(chars) do
    table.insert(code,reverseAlphabet[char])
  end
  return string.upper(table.concat(code,""))
end

function morse.send(code,side)
  --WIP Not working yet
  local multi = 2
  if type(side) == "string" then
    side = sides[side]
  end
  local chars = {}
  for char in string.gmatch(code,".") do
    table.insert(chars,char)
  end
  local val = 0.1
  for _,char in ipairs(chars) do
    if char == "." then
      rs.setOutput(side, 15)
      os.sleep(0.1*multi)
      --val = 0.1
    elseif char == "-" then
      rs.setOutput(side, 15)
      os.sleep(0.3*multi)
      --val = 0.1
      --elseif char == "_" then
      --val = 0.1
      --elseif char == " " then
      ---val = 0.7
    end
    rs.setOutput(side, 0)
    os.sleep(val*multi)
  end
  rs.setOutput(side,0)
end

function morse.receive(side)
  --WIP Not working yet.
  if type(side) == "string" then
    side = sides[side]
  end
  local chars = {}
  local rec = true
  local value = 0
  local elapsed
  local id = 0
  local time = computer.uptime()
  local s = event.listen("redstone_changed",function()
    elapsed = computer.uptime()-time
    if value >=1 then
      if elapsed < 1 and elapsed > 0.5 then
        table.insert(chars,"____")
      elseif elapsed > 1 then
        table.insert(chars," ")
      end
      if #table >= 6 and table.concat(chars,"",#chars-5) == "...-.-" then
        rec = false
      end
    else
      if elapsed < 0.5 then
        table.insert(chars,".")
      elseif elapsed > 0.5 then
        table.insert(chars,"-")
      end
    end
    event.cancel(id)
    id = event.timer(8,function()
      rec = false
    end)
    value = rs.getInput(side)
    time = computer.uptime()
  end)
  repeat
    os.sleep()
  until rec == false
  return table.concat(chars)
end

return morse