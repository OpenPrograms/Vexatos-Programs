local unicode

do
  local done
  done, unicode = pcall(require, "unicode")
  if not done then
    unicode = string
  end
end

local selenep = {}

local timeout

-------------------------------------------------------------------------------
-- Taken from text.lua and improved

local function trim(value) -- from http://lua-users.org/wiki/StringTrim
  local from = string.match(value, "^%s*()")
  return from > #value and "" or string.match(value, ".*%S", from)
end

local escapable = {
  ["'"]  = true,
  ['"']  = true
}

local function tokenize(value, stripcomments, utime)
  if not type(stripcomments) == "boolean" then stripcomments = true end
  if not value:find("\n$") then value = value .. "\n" end
  local tokenlines, lines, skiplines = {}, 1, {}
  local tokens, token = {}, ""
  local escaped, quoted, start = false, false, -1
  local waiting
  for i = 1, unicode.len(value) do
    if timeout and utime then
      if timeout.time() >= utime + timeout.wait() then
        timeout.yield()
        utime = timeout.time()
      end
    end
    local char = unicode.sub(value, i, i)

    if escaped and not escapable[quoted] then
      escaped = false
    end

    if escaped then -- escaped character
      escaped = false
      token = token .. char
    elseif char == "\\" and quoted and escapable[quoted] then -- escape character?
      escaped = true
      token = token .. char
    elseif char == "\n" and quoted == "--" then
      quoted = false
      if token ~= "" then
        if not stripcomments then
          table.insert(tokens, token)
          table.insert(tokenlines, lines)
        end
        token = ""
      end
      lines = lines + 1
    elseif char == "]" and quoted and string.find(token, "%]=*$") and string.find(quoted, "^%-%-%[=*%[") and #(string.match(token, "%]=*$") .. char) == #quoted - 2 then
      quoted = false
      token = token .. char
      if stripcomments then
        for w in token:gmatch("\n") do
          lines = lines + 1
        end
      else
        table.insert(tokens, token)
        table.insert(tokenlines, lines)
        skiplines[#tokenlines] = {}
        for w in token:gmatch("\n") do
          lines = lines + 1
          table.insert(skiplines[#tokenlines], lines)
        end
      end
      token = ""
    elseif char == "[" and quoted == "--" and string.find(token, "%-%-%[=*$") then
      local s = string.match(token, "%[=*$")
      quoted = quoted .. s .. char
      token = token .. char
    elseif char == quoted and escapable[char] then -- end of quoted string
      quoted = false
      token = token .. char
      table.insert(tokens, token)
      table.insert(tokenlines, lines)
      token = ""
    elseif char == "]" and quoted and string.find(token, "%]=*$") and string.find(quoted, "^%[=*%[") and #(string.match(token, "%]=*$") .. char) == #quoted then
      quoted = false
      token = token .. char
      table.insert(tokens, token)
      table.insert(tokenlines, lines)
      skiplines[#tokenlines] = {}
      for w in token:gmatch("\n") do
        lines = lines + 1
        table.insert(skiplines[#tokenlines], lines)
      end
      token = ""
    elseif not quoted and escapable[char] then
      quoted = char
      start = i
      token = token .. char
    elseif char == "-" and not quoted and string.find(token, "%-$") then
      local s = string.match(token, "%-$")
      quoted = s .. char
      start = i - #s
      token = token .. char
    elseif char == "[" and not quoted and string.find(token, "%[=*$") then -- derpy quote
      local s = string.match(token, "%[=*$")
      quoted = s .. char
      start = i - #s
      token = token .. char
    elseif not quoted and string.find(char, "%s") then -- delimiter
      if token ~= "" then
        table.insert(tokens, token)
        table.insert(tokenlines, lines)
        token = ""
      end
      if char == "\n" then
        lines = lines + 1
      end
    elseif char == "=" and not quoted and token == "" and tokens[#tokens] and (string.find(tokens[#tokens], "^[%+%-%*/%%^&|><%.:]$") or string.find(tokens[#tokens], "^([/<>%.])%1$")) then
      tokens[#tokens] = tokens[#tokens] .. char
    elseif not quoted and string.find(char, "^[/<>%.%$]$") then
      if waiting == false and token == "" and tokens[#tokens] and string.find(tokens[#tokens], "^%"..char.."$") then
        tokens[#tokens] = tokens[#tokens] .. char
        waiting = nil
      else
        if token ~= "" then
          table.insert(tokens, token)
          table.insert(tokenlines, lines)
          token = ""
        end
        table.insert(tokens, char)
        table.insert(tokenlines, lines)
        waiting  = true
      end
    elseif not quoted and string.find(char, "^[%(%):%?,%+%-%*%%^&|=]$") then
      if token ~= "" then
        table.insert(tokens, token)
        table.insert(tokenlines, lines)
        token = ""
      end
      table.insert(tokens, char)
      table.insert(tokenlines, lines)
    elseif not quoted and token == "" and tokens[#tokens] and ((char == ">" and string.find(tokens[#tokens], "^[%-=]$")) or (char == "-" and string.find(tokens[#tokens], "^<$"))) then
      tokens[#tokens] = tokens[#tokens] .. char
    else -- normal char
      token = token .. char
    end
    if waiting then
      waiting = false
    else
      waiting = nil
    end
  end
  if quoted then
    return nil, "unclosed quote at index " .. start
  end
  if token ~= "" then
    table.insert(tokens, token)
    table.insert(tokenlines, lines)
    lines = lines + 1
  end
  local i = 1
  while i <= #tokens do
    if tokens[i] == nil or #tokens[i] <= 0 then
      table.remove(tokens, i)
      local l = tokenlines[i]
      table.remove(tokenlines, i)
    else
      tokens[i] = trim(tokens[i])
      i = i + 1
    end
  end
  return tokens, tokenlines, skiplines, utime
end

-------------------------------------------------------------------------------

local varPattern = "[%a_][%w_]*"
--local lambdaParPattern = "("..varPattern..")((%s*,%s*)("..varPattern.."))*"

local function perror(msg, lvl)
  msg = msg or "unknown error"
  lvl = lvl or 1
  error("[Selene] error while parsing: " .. msg, lvl + 1)
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
        result = result .. " " .. curr
      else
        result = curr .. " " .. result
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
  for str in self:gmatch("([^" .. sep .. "]+)") do
    t[i] = trim(str)
    i = i + 1
  end
  return t
end

local function tryAddReturn(code, stripcomments)
  local tChunk, msg = tokenize(code, stripcomments)
  if not tChunk then
    perror(msg)
  end
  msg = nil
  for _, part in ipairs(tChunk) do
    if part:find("^return$") then
      return code
    end
  end
  return "return " .. code
end

local function findLambda(tChunk, i, part, line, tokenlines, stripcomments)
  local params = {}
  local step = i - 1
  local inst, step = bracket(tChunk, ")", "(", step, "", -1)
  local params = split(inst, ",")
  local start = step
  step = i + 1
  local funcode, step = bracket(tChunk, "(", ")", step, "", 1)
  local stop = step
  if not funcode:find("return", 1, true) then
    funcode = "return " .. funcode
  else
    funcode = tryAddReturn(funcode, stripcomments)
  end
  for _, s in ipairs(params) do
    if not s:find("^" .. varPattern .. "$") then
      perror("invalid lambda at index " .. i .. " (line " .. line .. "): invalid parameters: " .. table.concat(params, ","))
    end
  end
  local func = "_G._selene._newFunc(function(" .. table.concat(params, ",") .. ") " .. funcode .. " end, " .. tostring(#params) .. ")"
  for i = start, stop do
    table.remove(tChunk, start)
    table.remove(tokenlines, start)
  end
  table.insert(tChunk, start, func)
  table.insert(tokenlines, start, line)
  return true
end

local function findDollars(tChunk, i, part, line, tokenlines)
  local curr = tChunk[i + 1]
  if curr:find("^%(") then
    tChunk[i] = "_G._selene._new"
  elseif curr:find("^l") then
    tChunk[i] = "_G._selene._newList"
    table.remove(tChunk, i + 1)
    table.remove(tokenlines, i + 1)
  elseif curr:find("^f") then
    tChunk[i] = "_G._selene._newFunc"
    table.remove(tChunk, i + 1)
    table.remove(tokenlines, i + 1)
  elseif curr:find("^s") then
    tChunk[i] = "_G._selene._newString"
    table.remove(tChunk, i + 1)
    table.remove(tokenlines, i + 1)
  elseif tChunk[i - 1]:find("[:%.]$") then
    tChunk[i - 1] = tChunk[i - 1]:sub(1, #(tChunk[i - 1]) - 1)
    tChunk[i] = "()"
  else
    perror("invalid $ at index " .. i .. " (line " .. line .. ")")
  end
  return true
end

local function findSelfCall(tChunk, i, part, line)
  if not tChunk[i + 2] then tChunk[i + 2] = "" end
  if tChunk[i + 1]:find(varPattern) and not tChunk[i + 2]:find("(", 1, true) and not (tChunk[i - 1] and tChunk[i - 1]:find("^:")) then
    tChunk[i + 1] = tChunk[i + 1] .. "()"
    return true
  end
  return false
end

local function findTernary(tChunk, i, part, line, tokenlines)
  local step = i - 1
  local cond, step = bracket(tChunk, ")", "(", step, "", -1)
  local start = step
  step = i + 1
  local case, step = bracket(tChunk, "(", ")", step, "", 1)
  local stop = step
  if not case:find(":", 1, true) then
    perror("invalid ternary at index " .. step .. " (line " .. line .. "): missing colon ':'")
  end
  local trueCase = case:sub(1, case:find(":", 1, true) - 1)
  local falseCase = case:sub(case:find(":", 1, true) + 1)
  local ternary = "(function() if " .. cond .. " then return " .. trueCase .. " else return " .. falseCase .. " end end)()"
  for i = start, stop do
    table.remove(tChunk, start)
    table.remove(tokenlines, start)
  end
  table.insert(tChunk, start, ternary)
  table.insert(tokenlines, start, line)
  return true
end

local function findForeach(tChunk, i, part, line, tokenlines)
  local start
  local step = i - 1
  local params = {}
  while not start do
    if tChunk[step] == "for" then
      start = step + 1
    else
      table.insert(params, 1, trim(tChunk[step]))
      step = step - 1
    end
  end
  params = split(table.concat(params), ",")
  step = i + 1
  local stop
  local vars = {}
  while not stop do
    if tChunk[step] == "do" then
      stop = step - 1
    else
      table.insert(vars, trim(tChunk[step]))
      step = step + 1
    end
  end
  vars = split(table.concat(vars), ",")
  for _, p in ipairs(params) do
    if not p:find("^" .. varPattern .. "$") then
      return false
    end
  end
  local func = table.concat(params, ",") .. " in _G.lpairs(" .. table.concat(vars, ",") .. ")"
  for i = start, stop do
    table.remove(tChunk, start)
    table.remove(tokenlines, start)
  end
  table.insert(tChunk, start, func)
  table.insert(tokenlines, start, line)
  return true
end

local function findAssignmentOperator(tChunk, i)
  local repl = tChunk[i]:sub(1, #tChunk[i] - 1)
  if tChunk[i - 1]:find(varPattern) then
    tChunk[i] = " = " .. tChunk[i - 1] .. " " .. repl
    return true
  end
  return false
end

local function findDollarAssignment(tChunk, i, part, line, tokenlines)
  if tChunk[i - 1]:find("^"..varPattern.."$") then
    tChunk[i] = " = _G._selene._new(" .. tChunk[i-1] .. ")"
    return true
  else
    perror("invalid $$ at index " .. i .. " (line " .. line .. ")")
  end
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
  ["$"    ] = findDollars,
  ["$$"   ] = findDollarAssignment,
  ["+="   ] = findAssignmentOperator,
  ["-="   ] = findAssignmentOperator,
  ["*="   ] = findAssignmentOperator,
  ["/="   ] = findAssignmentOperator,
  ["//="  ] = findAssignmentOperator,
  ["%="   ] = findAssignmentOperator,
  ["^="   ] = findAssignmentOperator,
  ["&="   ] = findAssignmentOperator,
  ["|="   ] = findAssignmentOperator,
  --["~="   ] = findAssignmentOperator,
  [">>="  ] = findAssignmentOperator,
  ["<<="  ] = findAssignmentOperator,
  ["..="  ] = findAssignmentOperator,
  [":="   ] = findAssignmentOperator,
}

local function concatWithLines(tbl, lines, skiplines)
  local chunktbl = {}
  local last = 0
  local deadlines = {}
  for i, j in ipairs(lines) do
    if not chunktbl[j] then chunktbl[j] = {} end
    table.insert(chunktbl[j], tbl[i])
    last = math.max(last, j)
    if skiplines[i] then
      for _, v in ipairs(skiplines[i]) do
        chunktbl[v] = false
        deadlines[v] = j
        last = math.max(last, v)
      end
    end
  end
  for i = 1, last do
    if not chunktbl[i] and chunktbl[i] ~= false then
      chunktbl[i] = {}
    end
  end
  local i = 1
  while i <= #chunktbl do
    if chunktbl[i] ~= false then
      if not deadlines[i] then
        chunktbl[i] = table.concat(chunktbl[i], " ")
        i = i + 1
      else
        chunktbl[deadlines[i]] = chunktbl[deadlines[i]] .. " " .. table.concat(chunktbl[i], " ")
        deadlines[i] = nil
        table.remove(chunktbl, i)
        for k = i + 1, last do
          if deadlines[k] then
            if deadlines[k] >= i then
              deadlines[k - 1] = deadlines[k] - 1
            else
              deadlines[k - 1] = deadlines[k]
            end
            deadlines[k] = nil
          end
        end
      end
    else
      deadlines[i] = nil
      table.remove(chunktbl, i)
      for k = i + 1, last do
        if deadlines[k] then
          if deadlines[k] >= i then
            deadlines[k - 1] = deadlines[k] - 1
          else
            deadlines[k - 1] = deadlines[k]
          end
          deadlines[k] = nil
        end
      end
    end
  end
  return table.concat(chunktbl, "\n")
end

local function parse(chunk, stripcomments)
  if not type(stripcomments) == "boolean" then stripcomments = true end
  local utime
  if timeout then
    utime = timeout.time()
  end
  local tChunk, tokenlines, skiplines, utime = tokenize(chunk, stripcomments, utime)
  chunk = nil
  if not tChunk then
    error(tokenlines)
  end
  for i, part in ipairs(tChunk) do
    if keywords[part] then
      if not tChunk[i + 1] then tChunk[i + 1] = "" end
      if not tChunk[i - 1] then tChunk[i - 1] = "" end
      local result = keywords[part](tChunk, i, part, tokenlines[i], tokenlines, stripcomments)
      if result then
        local cnk = concatWithLines(tChunk, tokenlines, skiplines)
        tokenlines = nil
        skiplines = nil
        tChunk = nil
        return parse(cnk, stripcomments)
      end
    end
  end
  return concatWithLines(tChunk, tokenlines, skiplines)
end

function selenep.parse(chunk, stripcomments)
  return parse(chunk, stripcomments)
end

--[[
  Allows setting a handler in case the sandbox must yield/pause every so often. All three parameters must be callable.
  'func' is the function that will be called to prevent a timeout.
  'time' needs to return the interval in which the function is called.
  'timefunc' must be a function that returns the current time. Its value will be compared to the last call's value to determine whether 'func' needs to be called.
]]
function selenep.setTimeoutHandler(func, time, timefunc)
  timeout = {}
  timeout.yield = func
  timeout.wait = time
  timeout.time = timefunc
end

return selenep
