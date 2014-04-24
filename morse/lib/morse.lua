--Morse library to parse strings to redstone signals
local component = require("component")
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
  okay = "...-.",
  error = "........",
  }

do
  local letter = {}
  for k in pairs(alphabet) do
    table.insert(letter, k)
  end
  for _, k in pairs(letter) do
    alphabet[alphabet[k]] = k
  end
end

assert(component.isAvailable("redstone"),"This program requires a redstone card or redstone I/O block.")
local redstone = component.redstone

function morse.encode(str)
  str = string.lower(str)
  local chars = {}
  for char in string.gmatch(str,".") do
    table.insert(chars,char)
  end
  local code = {}
  for _,char in ipairs(chars) do
    assert(alphabet[char] ~= nil and char ~= ".","Non-parsable character \""..char.."\" found. Check morse.lua to see which characters are supported")
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
    table.insert(code,alphabet[char])
  end
  return string.upper(table.concat(code,""))
end

function morse.send(code)
--TODO Add send
end

function morse.receive()
--TODO Add receiver
end

return morse