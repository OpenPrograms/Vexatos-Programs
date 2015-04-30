local unicode = require("unicode")

local selenep = {}

-------------------------------------------------------------------------------
-- Stolen from text.lua

local endQuote = {
  ["'"] = "'",
  ['"'] = '"',
}

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
    elseif char == quoted or (char == "]" and string.find(token, "%]=*$") and string.match(token, "%]=*$")..char == quoted) then -- end of quoted string
      quoted = false
      token = token .. char
    elseif (char == "'" or char == '"') and not quoted then
      quoted = char
      start = i
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
    elseif string.find(char, "[%(%)%$:%?]") and not quoted then
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
  return tokens
end

-------------------------------------------------------------------------------

local varPattern = "[a-zA-Z_][a-zA-Z0-9_]*"
local lambdaParPattern = "[("..varPattern.."),]+"

local function perror(msg, lvl)
  msg = msg or ""
  lvl = lvl or 1
  error("[Selene] error while parsing: "..msg, lvl + 2)
end

local function bracket(tChunk, plus, minus, step, result, incr)
  local curr = tChunk[step]
  local brackets = 1
  while brackets > 0 do
      if curr:find(plus, 1, true) then
        brackets = brackets + 1
      end
      if curr:find(minus, 1, true) then
        brackets = brackets - 1
      end
      if brackets > 0 then
        result = result.." "..curr
        step = step + incr
        curr = tChunk[step]
      end
  end
  return result, step
end

local function findLambda(tChunk, i, part)
  local params = {}
  local step = i - 1
  local curr = tChunk[step]
  if curr:find(")", 1, true) then
    while not curr:find("(", 1, true) do
      --[[if not curr:match(lambdaParPattern) then
        perror("invalid lambda at index "..step)
      end]]
      if curr:find(varPattern) then
        table.insert(params, 1, curr)
      end
      step = step - 1
      curr = tChunk[step]
    end
  elseif curr:find(varPattern) then
    table.insert(params, curr)
  else
    perror("invalid lambda at index "..step.. " not in brackets '()'")
  end
  local start = step
  step = i + 1
  curr = tChunk[step]
  if not curr:find("(", 1, true) then
    perror("invalid lambda at index "..step.. " not in brackets '()'")
  end
  step = step + 1
  local funcode, step = bracket(tChunk, "(", ")", step, "", 1)
  local stop = step
  if not funcode:find("return", 1, true) then
    funcode = "return "..funcode
  end
  local func = "_G._selene._newFunc(function("..table.concat(params, ",")..") "..funcode.." end, "#params")"
  for i = start, stop do
    table.remove(tChunk, i)
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
  else
    perror("invalid $ at index "..i)
  end
  return true
end

local function findSelfCall(tChunk, i, part)
  local prev = tChunk[i - 1]
  local front = tChunk[i + 1]
  if tChunk[i - 1]:find(varPattern) and tChunk[i + 1]:find(varPattern) and not tChunk[i + 2]:find("(", 1, true) then
    tChunk[i+1] = tChunk[i+1].."()"
    return true
  end
  return false
end

local function findTernary(tChunk, i, part)
  local step = i - 1
  local curr
  if not tChunk[step]:find(")", 1, true) then
    perror("invalid ternary at index "..step.. " not in brackets '()'")
  end
  step = step - 1
  local cond, step = bracket(tChunk, ")", "(", step, "", -1)
  local start = step
  step = i + 1
  local curr = tChunk[step]
  if not curr:find("(", 1, true) then
    perror("invalid ternary at index "..step.. " not in brackets '()'"
  end
  step = step + 1
  local trueCase, step = bracket(tChunk, "(", ")", step, "", 1)
  step = step + 1
  if not tChunk[step]:find(":", 1, true) then
    perror("invalid ternary at index "..step..": missing colon ':'")
  end
  step = step + 1
  local falseCase, step = bracket(tChunk, "(", ")", step, "", 1)
  local stop = step
  local ternary = "(function() if "..cond.." then return "..trueCase.." else return "..falseCase.." end)()"
  for i = start, stop do
    table.remove(tChunk, i)
  end
  table.insert(tChunk, start, ternary)
  return true
end

local keywords = {
  ["->"   ] = findLambda,
  ["=>"   ] = findLambda,
  --["<-"   ] = function() end,
  ["?"    ] = findTernary,
  [":"    ] = findSelfCall,
  --["match"] = function() end,
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
      local result, msg = pcall(keywords[part], tChunk, i, part)
      if not result then
        error(msg)
      end
      if msg then
        local cnk = table.concat(tChunk, " ")
        tChunk = nil
        return parse(cnk)
      end
    end
  end
  return table.concat(tChunk, " ")
end

function selenep.parse(chunk)
  return parse(chunk)
end

return selenep
