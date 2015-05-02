local unicode

do
  local done
  done, unicode = pcall(require, "unicode")
  if not done then
    unicode = string
  end
end

local selenep = {}

-------------------------------------------------------------------------------
-- Stolen from text.lua

local endQuote = {
  ["'"] = "'",
  ['"'] = '"',
}

local function trim(value) -- from http://lua-users.org/wiki/StringTrim
  local from = string.match(value, "^%s*()")
  return from > #value and "" or string.match(value, ".*%S", from)
end

local function tokenize(value)
  checkArg(1, value, "string")
  local tokens, token = {}, ""
  local escaped, quoted, start = false, false, -1
  for i = 1, unicode.len(value) do
    local char = unicode.sub(value, i, i)
    if escaped then -- escaped character
      escaped = false
      token = token .. char
    elseif char == "\\" and quoted ~= "'" then -- escape character?
      escaped = true
      token = token .. char
    elseif char == "\n" and quoted == "--" then
      quoted = false
      if token ~= "" then
        table.insert(tokens, token)
        token = ""
      end
    elseif char == "]" and quoted == "--[[" and string.find(token, "%]$") then
      quoted = false
      if token ~= "" then
        table.insert(tokens, token..char)
        token = ""
      end
    elseif char == "[" and quoted == "--" and string.find(token, "%-%-%[$") then
      quoted = quoted .. "[["
      token = token .. char
    elseif char == quoted or (char == "]" and string.find(token, "%]=*$") and #(string.match(token, "%]=*$")..char) == #quoted) then -- end of quoted string
      quoted = false
      token = token .. char
    elseif (char == "'" or char == '"') and not quoted then
      quoted = char
      start = i
      token = token .. char
    elseif char == "-" and string.find(token, "%-$") and not quoted then
      local s = string.match(token, "%-$")
      quoted = s..char
      start = i - #s
      token = token .. char
    elseif (char == "[") and string.find(token, "%[=*$") and not quoted then -- derpy quote
      local s = string.match(token, "%[=*$")
      quoted = s..char
      start = i - #s
      token = token .. char
    elseif string.find(char, "%s") and not quoted then -- delimiter
      if token ~= "" then
        table.insert(tokens, token)
        token = ""
      end
    elseif string.find(char, "[%(%)%$:%?,]") and not quoted then
      if token ~= "" then
        table.insert(tokens, token)
        token = ""
      end
      table.insert(tokens, char)
    elseif string.find(char, "[%->]") and string.find(token, "[%-=<]$") and not quoted then
      table.insert(tokens, token:sub(1, #token - 1))
      table.insert(tokens, token:sub(#token)..char)
      token = ""
    else -- normal char
      token = token .. char
    end
  end
  if quoted then
    return nil, "unclosed quote at index " .. start
  end
  if token ~= "" then
    table.insert(tokens, token)
  end
  local i = 1
  while i <= #tokens do
    if tokens[i] == nil or #tokens[i] <= 0 then
      table.remove(tokens, i)
    else
     tokens[i] = trim(tokens[i])
     i = i + 1
    end
  end
  return tokens
end

-------------------------------------------------------------------------------

local varPattern = "[%a_][%w_]*"
--local lambdaParPattern = "("..varPattern..")((%s*,%s*)("..varPattern.."))*"

local function perror(msg, lvl)
  msg = msg or "unknown error"
  lvl = lvl or 1
  error("[Selene] error while parsing: "..msg, lvl + 1)
end

local function bracket(tChunk, plus, minus, step, result, incr, start)
  local curr = tChunk[step]
  local brackets = start or 1
  while brackets > 0 do
    if curr:find(plus, 1, true) then
      brackets = brackets + 1
    end
    if curr:find(minus, 1, true) then
      brackets = brackets - 1
    end
    if brackets > 0 then
      if incr > 0 then
        result = result.." "..curr
      else
        result = curr.." "..result
      end
      step = step + incr
      curr = tChunk[step]
    end
  end
  return result, step
end

local function split(self, sep)
  local t = {}
  local i = 1
  for str in self:gmatch("([^"..sep.."]+)") do
    t[i] = trim(str)
    i = i + 1
  end
  return t
end

local function findLambda(tChunk, i, part)
  local params = {}
  local step = i - 1
  local inst, step = bracket(tChunk, ")", "(", step, "", -1)
  local params = split(inst, ",")
  local start = step
  step = i + 1
  local funcode, step = bracket(tChunk, "(", ")", step, "", 1)
  local stop = step
  if not funcode:find("return", 1, true) then
    funcode = "return "..funcode
  end
  for _, s in ipairs(params) do
    if not s:find("^"..varPattern .. "$") then
      perror("invalid lambda at index "..i..": invalid parameters")
    end
  end
  local func = "_G._selene._newFunc(function("..table.concat(params, ",")..") "..funcode.." end, "..tostring(#params)..")"
  for i = start, stop do
    table.remove(tChunk, start)
  end
  table.insert(tChunk, start, func)
  return true
end

local function findDollars(tChunk, i, part)
  local curr = tChunk[i + 1]
  if curr:find("(", 1, true) then
    tChunk[i] = "_G._selene._new"
  elseif curr:find("l", 1, true) then
    tChunk[i] = "_G._selene._newList"
  elseif curr:find("f", 1, true) then
    tChunk[i] = "_G._selene._newFunc"
  elseif curr:find("s", 1, true) then
    tChunk[i] = "_G._selene._newString"
  elseif tChunk[i - 1]:find("[:%.]$") then
    tChunk[i - 1] = tChunk[i - 1]:sub(1, #(tChunk[i - 1]) - 1)
    tChunk[i] = "._tbl"
  else
    perror("invalid $ at index "..i)
  end
  return true
end

local function findSelfCall(tChunk, i, part)
  local prev = tChunk[i - 1]
  local front = tChunk[i + 1]
  if tChunk[i + 1]:find(varPattern) and not tChunk[i + 2]:find("(", 1, true) then
    tChunk[i+1] = tChunk[i+1].."()"
    return true
  end
  return false
end

local function findTernary(tChunk, i, part)
  local step = i - 1
  local cond, step = bracket(tChunk, ")", "(", step, "", -1)
  local start = step
  step = i + 1
  local case, step = bracket(tChunk, "(", ")", step, "", 1)
  local stop = step
  if not case:find(":", 1, true) then
    perror("invalid ternary at index "..step..": missing colon ':'")
  end
  local trueCase = case:sub(1, case:find(":", 1, true) - 1)
  local falseCase = case:sub(case:find(":", 1, true) + 1)
  local ternary = "(function() if "..cond.." then return "..trueCase.." else return "..falseCase.." end end)()"
  for i = start, stop do
    table.remove(tChunk, start)
  end
  table.insert(tChunk, start, ternary)
  return true
end

local function findForeach(tChunk, i, part)
  local start = nil
  local vars = ""
  local step = i - 1
  while not start do
    if tChunk[step] == "for" then
      start = step + 1
    else
      vars = tChunk[step] .. " " .. vars
      step = step - 1
    end
  end
  local params = split(vars, ",")
  step = i + 1
  local stop = nil
  vars = ""
  while not stop do
    if tChunk[step] == "do" then
      stop = step - 1
    else
      vars = vars .. " " .. tChunk[step]
      step = step + 1
    end
  end
  for _, p in ipairs(params) do
    if not p:find("^"..varPattern .. "$") then
      return false
    end
  end
  local func = table.concat(params, ",") .. "in mpairs("..vars..")"
  for i = start, stop do
    table.remove(tChunk, start)
  end
  table.insert(tChunk, start, func)
  return true
end

--[[local types = {
  ["nil"] = true,
  ["boolean"] = true,
  ["string"] = true,
  ["number"] = true,
  ["table"] = true,
  ["function"] = true,
  ["thread"] = true,
  ["userdata"] = true,
  ["list"] = true,
  ["map"] = true,
  ["stringlist"] = true,
}

local function findMatch(tChunk, i, part)
  if not tChunk[i + 1]:find("(", 1, true) then
    perror("invalid match at index "..i..": no brackets () found")
  end
  local start = i
  local step = i + 2
  local cases, step = bracket(tChunk, "(", ")", step, "", 1)
  local stop = step
end]]

local keywords = {
  ["->"   ] = findLambda,
  ["=>"   ] = findLambda,
  ["<-"   ] = findForeach,
  ["?"    ] = findTernary,
  [":"    ] = findSelfCall,
  --["match"] = findMatch,
  ["$"    ] = findDollars
}

local function parse(chunk)
  local tChunk, msg = tokenize(chunk)
  chunk = nil
  if not tChunk then
    error(msg)
  end
  for i, part in ipairs(tChunk) do
    if keywords[part] then
      if not tChunk[i + 1] then tChunk[i + 1] = "" end
      if not tChunk[i - 1] then tChunk[i - 1] = "" end
      local result = keywords[part](tChunk, i, part)
      if result then
        local cnk = table.concat(tChunk, "\n")
        tChunk = nil
        return parse(cnk)
      end
    end
  end
  return table.concat(tChunk, "\n")
end

function selenep.parse(chunk)
  return parse(chunk)
end

return selenep