--[[
Selene, A Lua library for more convenient functional programming
Author: Vexatos
]]

--------
-- Utils
--------

local function checkArg(n, have, ...)
  have = type(have)
  local function check(want, ...)
    if not want then
      return false
    else
      return have == want or check(...)
    end
  end
  if not check(...) then
    local msg = string.format("bad argument #%d (%s expected, got %s)",
                              n, table.concat({...}, " or "), have)
    error(msg, 3)
  end
end

local function shallowcopy(orig)
  local copy
  if type(orig) == 'table' then
    copy = {}
    for k, v in pairs(orig) do
      copy[k] = v
    end
  else
    copy = orig
  end
  return copy
end

local function clamp(num, mn, mx)
  checkArg(1, num, "number")
  checkArg(2, mn, "number", "nil")
  checkArg(3, mx, "number", "nil")
  if not mn and mx then
    return math.min(num, mx)
  elseif mn and not mx then
    return math.max(num, mn)
  else
    return math.max(math.min(num, mx), mn)
  end
end

-- Returns the number of parameters on the function
local function parCount(obj, def)
  checkArg(1, obj, "table", "function")
  checkArg(2, def, "number", "nil")
  if type(obj) == "function" then
    return def
  end
  local m = getmetatable(obj)
  return (m and m.parCount) or def
end

-- Returns the table type or the type
local function tblType(obj)
  if type(obj) == "table" then
    local m = getmetatable(obj)
    return (m and m.ltype) or "table"
  end
  return type(obj)
end

local function isList(t)
  checkArg(1, t, "table")
  local tp = tblType(t)
  if tp == "list" or tp == "stringlist" then
    return true
  elseif tp == "map" then
    return false
  elseif tp == "table" then
    for i in pairs(newObj._tbl) do
      if not type(i) == "number" then
        return false
      elseif i < 1 then
        return false
      end
    end
    return true
  end
  return false
end

local function checkList(n, t)
  if not isList(t) then
    local msg = string.format("[Selene] bad argument #%d (list expected, got %s)", n, have)
    error(msg, 2)
  end
end

local function insert(tbl, key, value, fuzzyList)
  fuzzyList = fuzzyList or false
  if value then
    if fuzzyList and isList(tbl) then
      table.insert(tbl, value)
    else
      tbl[key] = value
    end
  else
    table.insert(tbl, key)
  end
end

local function mpairs(obj)
  if type(obj) == "table" and isList(obj) then
    return ipairs(obj._tbl)
  else
    return pairs(obj._tbl)
  end
end

local allMaps = {"map", "list", "stringlist"}

-- Errors is the value is not a valid type (list or map)
local function checkType(n, have, ...)
  have = tblType(have)
  local things = {...}
  if #things == 0 then things = allMaps end
  local function check(want, ...)
    if not want then
      return false
    else
      return have == want or check(...)
    end
  end
  if not check(table.unpack(things)) then
    local msg = string.format("[Selene] bad argument #%d (%s expected, got %s)",
                              n, table.concat({...}, " or "), have)
    error(msg, 3)
  end
end

-- Errors if the value is not a function or does not have the required parameter count
local function checkFunc(n, have, ...)
  checkType(n, have, "function")
  if type(have) == "function" then return end
  local haveParCount = parCount(have, nil)
  have = type(have)
  if not haveParCount then
    local msg = string.format("[Selene] bad argument #%d (function expected, got %s)", n, have)
    error(msg, 2)
  end
  
  if #{...} == 0 then return end

  local level = 3
  
  local function check(want, ...)
    checkArg(level, want, "number")
    if not want then
      return false
    else
      level = level + 1
      return haveParCount == want or check(...)
    end
  end
  if not check(...) then
    local msg = string.format("[Selene] bad argument #%d (%s parameter(s) expected, got %s)",
                              n, table.concat({...}, " or "), haveParCount)
    error(msg, 3)
  end
end

--------
-- Bulk data operations, using the new $ object
--------

local mt = {
  __call = function(tbl)
    return tbl._tbl
  end,
  __len = function(tbl)
    return #tbl._tbl
  end,
  __pairs = function(tbl)
    return pairs(tbl._tbl)
  end,
  __ipairs = function(tbl)
    return ipairs(tbl._tbl)
  end,
  __tostring = function(tbl)
    return tostring(tbl._tbl)
  end,
  ltype = "map"
}

local lmt = shallowcopy(mt)
lmt.ltype = "list"

local fmt = {
  __call = function(fnc, ...)
    return fnc._fnc(...)
  end,
  __len = function(fnc)
    return #fnc._fnc
  end,
  __pairs = function(fnc)
    return pairs(fnc._fnc)
  end,
  __ipairs = function(fnc)
    return ipairs(fnc._fnc)
  end,
  ltype = "function"
}

local _Table = {}
local _String = {}

local smt = shallowcopy(mt)
smt.ltype = "stringlist"
smt.__call = function(str)
  return table.concat(str._tbl)
end
smt.__tostring = smt.__call

--------
-- Initialization functions
--------

local function new(t)
  checkArg(1, t, "table", "nil")
  t = t or {}
  local newObj = {}
  for i,j in pairs(_Table) do
    newObj[i] = j
  end
  newObj._tbl = t
  setmetatable(newObj, mt)
  return newObj
end

local function newStringList(s)
  checkArg(1, s, "table", "nil")
  s = s or {}
  local newObj = {}
  for i,j in pairs(_String) do
    newObj[i] = j
  end
  newObj._tbl = {}
  for i = 1, #s do
    if not s[i] or type(s[i]) ~= "string" or #s[i] > 1 then
      error("[Selene] could not create list: bad table key: "..i.." is not a character", 2)
    end
    newObj._tbl[i] = s[i]
  end
  setmetatable(newObj, smt)
  return newObj
end

local function newString(s)
  checkArg(1, s, "string", "nil")
  s = s or ""
  local newObj = {}
  for i,j in pairs(_String) do
    newObj[i] = j
  end
  newObj._tbl = {}
  for i = 1, #s do
    newObj._tbl[i] = s:sub(i,i)
  end
  setmetatable(newObj, smt)
  return newObj
end

local function newList(t)
  local newObj = new(t)
  for i in pairs(newObj._tbl) do
    if not type(i) == "number" then
      error("[Selene] could not create list: bad table key: "..i.." is not a number", 2)
    elseif i < 1 then
      error("[Selene] could not create list: bad table key: "..i.." is below 1", 2)
    end
  end
  setmetatable(newObj, lmt)
  return newObj
end

local function newListOrMap(t)
  local newObj = new(t)
  for i in pairs(newObj._tbl) do
    if not type(i) == "number" then
      return newObj
    elseif i < 1 then
      return newObj
    end
  end
  setmetatable(newObj, lmt)
  return newObj
end

local function newFunc(f, parCnt)
  checkArg(1, f, "function")
  checkArg(2, parCnt, "number")
  if parCnt < 0 then
    error("[Selene] could not create function: bad parameter amount: "..parCnt.." is below 0", 2)
  end
  local newF = {}
  local fm = shallowcopy(fmt)
  newF._fnc = f
  fm.parCount = parCnt
  setmetatable(newF, fm)
  return newF
end

--------
-- Bulk data operations on tables
--------

-- Concatenates the entries of the table just like table.concat
local function tbl_concat(self, sep, i, j)
  return table.concat(self._tbl, sep, i, j)
end

local function tbl_foreach(self, f)
  checkType(1, self)
  checkFunc(2, f)
  local parCnt = parCount(f)
  for i, j in mpairs(self) do
    if parCnt == 1 then
      f(j)
    else
      f(i, j)
    end
  end 
end

-- Iterates through each entry and calls the function, returns a list if possible, a map otherwise
local function tbl_map(self, f)
  checkType(1, self)
  checkFunc(2, f)
  local mapped = {}
  local parCnt = parCount(f)
  for i, j in mpairs(self) do
    if parCnt == 1 then
      insert(mapped, f(j))
    else
      insert(mapped, f(i, j))
    end
  end
  return newListOrMap(mapped)
end

-- Only returns the characters that match the filter, returns a list if possible, a map otherwise
local function tbl_filter(self, f)
  checkType(1, self)
  checkFunc(2, f)
  local filtered = {}
  local parCnt = parCount(f)
  if parCnt == 1 then
    for i, j in mpairs(self) do
      if f(j) then
        insert(filtered, i, j, true)
      end
    end
  else
    for i, j in mpairs(self) do
      if f(i, j) then
        insert(filtered, i, j, true)
      end
    end
  end
  return newListOrMap(filtered)
end

-- Removes the first amt entries of the list, returns a list
local function tbl_drop(self, amt)
  checkType(1, self, "list", "stringlist")
  checkArg(2, amt, "number")
  amt = clamp(amt, 0, #self)
  if amt == 0 then return self
  elseif amt == #self then
    self._tbl = {}
    return self
  else
    local dropped = {}
    for i = amt + 1, #self do
      insert(dropped, self._tbl[i])
    end
    return newListOrMap(dropped)
  end
end

-- Removes entries while the function returns true, returns a list
local function tbl_dropwhile(self, f)
  checkType(1, self, "list", "stringlist")
  checkFunc(2, f)
  local parCnt = parCount(f)
  local dropped = {}
  local curr = 1
  if parCnt == 1 then
    for i, j in mpairs(self) do
      curr = i
      if not f(j) then
        break
      end
    end
  else
    for i, j in mpairs(self) do
      curr = i
      if not f(i, j) then
        break
      end
    end
  end
  for i = curr, #self do
    insert(dropped, self._tbl[i])
  end
  return newListOrMap(dropped)
end

--inverts the list
local function tbl_reverse(self)
  checkType(1, self, "list", "stringlist")
  local reversed = {}
  for i, j in mpairs(self) do
    table.insert(reversed, 1, j)
  end
  self._tbl = reversed
  return self
end

-- Returns the accumulator
local function tbl_foldleft(self, start, f)
  checkType(1, self)
  checkFunc(3, f)
  local m = start
  for i, j in mpairs(self) do
    m = f(m, j)
  end
  return m
end

-- Returns the accumulator
local function tbl_foldright(self, start, f)
  return tbl_foldleft(tbl_reverse(self), start, f)
end

-- Returns the first element of the table that matches the function.
local function tbl_find(self, f)
  checkType(1, self)
  checkFunc(2, f)
  local parCnt = parCount(f)
  if parCnt == 1 then
    for i,j in mpairs(self) do
      if f(j) then
        return j
      end
    end
  else
    for i,j in mpairs(self) do
      if f(i,j) then
        return j
      end
    end
  end
end

local function rawflatten(self)
  checkArg(1, self, "table")
  local flattened = {}
  for i,j in ipairs(self) do
    if tblType(j) == "table" and isList(j) then
      for k, v in ipairs(j) do
        if v ~= nil then
          table.insert(flattened, v)
        end
      end
    elseif j ~= nil then
      table.insert(flattened, j)
    end
  end
  return flattened
end

local function tbl_flatten(self)
  checkType(1, self, "list")
  return newListOrMap(rawflatten(self._tbl))
end

--------
-- Bulk data operations on stringlists
--------

local function strl_filter(self, f)
  checkType(1, self, "stringlist")
  checkFunc(2, f)
  local filtered = {}
  local parCnt = parCount(f)
  if parCnt == 1 then
    for i, j in mpairs(self) do
      if f(j) then
        insert(filtered, j)
      end
    end
  else
    for i, j in mpairs(self) do
      if f(i, j) then
        insert(filtered, i, j)
      end
    end
  end
  return newStringList(filtered)
end

local function strl_drop(self, amt)
  checkType(1, self, "stringlist")
  self = tbl_drop(self, amt)
  return table.concat(self._tbl)
end

local function strl_dropwhile(self, f)
  checkType(1, self, "stringlist")
  self = tbl_dropwhile(self, f)
  return table.concat(self._tbl)
end

--------
-- Bulk data operations on strings
--------

-- Calls a functions once per character, returns nil
local function str_foreach(self, f)
  checkArg(1, self, "string")
  checkFunc(2, f)
  local parCnt = parCount(f)
  for i = 1, #self do
    if parCnt == 1 then
      f(j)
    else
      f(i, j)
    end
  end
end

-- Iterates through each character and calls the function, returns a list if possible, a map otherwise
local function str_map(self, f)
  checkArg(1, self, "string")
  checkFunc(2, f)
  local mapped = {}
  local parCnt = parCount(f)
  for i = 1, #self do
    if parCnt == 1 then
      insert(mapped, f(self:substring(i,i)))
    else
      insert(mapped, f(i, self:substring(i,i)))
    end
  end
  return newListOrMap(mapped)
end

-- Only returns the characters that match the filter, returns a list
local function str_filter(self, f)
  checkArg(1, self, "string")
  checkFunc(2, f)
  local filtered = {}
  local parCnt = parCount(f)
  if parCnt == 1 then
    for i = 1, #self do
      local j = self:substring(i,i)
      if f(j) then
        insert(filtered, j)
      end
    end
  else
    for i = 1, #self do
      local j = self:substring(i,i)
      if f(i, j) then
        insert(filtered, i, j)
      end
    end
  end
  return newStringList(filtered)
end

-- Removes the first amt characters of the srting, returns a string
local function str_drop(self, amt)
  checkArg(1, self, "string")
  checkArg(2, amt, "number")
  amt = clamp(amt, 0, #self)
  if amt == 0 then return self
  elseif amt == #self then return ""
  else return self:sub(amt + 1) end
end

-- Removes characters while the function returns true, returns a string
local function str_dropwhile(self, f)
  checkArg(1, self, "string")
  checkFunc(2, f)
  local parCnt = parCount(f)
  local index = 0
  if parCnt == 1 then
    for i = 1, #self do
      local s = self:sub(i,i)
      if not f(s) then
        break
      end
      index = i
    end
  else
    for i = 1, #self do
      local s = self:sub(i,i)
      if not f(i, s) then
        break
      end
      index = i
    end
  end
  if index == 0 then return self
  elseif index == #self then return ""
  else return self:sub(index + 1) end
end

-- Returns the accumulator
local function str_foldleft(self, start, f)
  checkArg(1, self, "string")
  checkFunc(3, f)
  local m = start
  for i = 1, #self do
    m = f(m, self:sub(i,i))
  end
  return m
end

-- Returns the accumulator
local function str_foldright(self, start, f)
  return str_foldleft(self:reverse(), start, f)
end

-- Splits the string, returns a list
local function str_split(self, sep)
  checkArg(1, self, "string")
  checkArg(2, sep, "string")
  local t = {}
  local i = 1
  for str in self:gmatch("([^"..sep.."]+)") do
    t[i] = str
    i = i + 1
  end
  return newList(t)
end

--------
-- Parsing
--------

local selenep = require("selenep")
local function parse(chunk)
  return selenep.parse(chunk)
end

--------
-- Adding to global variables
--------

local function init()
  if _G._selene and _G._selene.initDone then return end
  if not _G._selene then _G._selene = {} end

  _G._selene._new = function(t)
    if type(t) == "string" then
      return newString(t)
    else
      return newListOrMap(t)
    end
  end
  if not _G.checkArg then _G.checkArg = checkArg end
  _G._selene._newString = newString
  _G._selene._newList = newList
  _G._selene._newFunc = newFunc
  _G.ltype = tblType
  _G.checkType = checkType
  _G.checkFunc = checkFunc
  _G.parCount = parCount
  _G.lpairs = mpairs
  _G.isList = isList

  _G.string.foreach = str_foreach
  _G.string.map = str_map
  _G.string.filter = str_filter
  _G.string.drop = str_drop
  _G.string.dropwhile = str_dropwhile
  _G.string.foldleft = str_foldleft
  _G.string.foldright = str_foldright
  _G.string.split = str_split
  
  _G.table.shallowcopy = shallowcopy
  _G.table.flatten = function(tbl)
    checkList(1, tbl)
    return rawflatten(tbl)
  end

  _Table.concat = tbl_concat
  _Table.foreach = tbl_foreach
  _Table.map = tbl_map
  _Table.filter = tbl_filter
  _Table.drop = tbl_drop
  _Table.dropwhile = tbl_dropwhile
  _Table.reverse = tbl_reverse
  _Table.foldleft = tbl_foldleft
  _Table.foldright = tbl_foldright
  _Table.find = tbl_find
  _Table.flatten = tbl_flatten

  _Table.shallowcopy = function(self)
    checkType(1, self)
    local newObj = shallowcopy(self)
    setmetatable(newObj, getmetatable(self))
    newObj._tbl = shallowcopy(self._tbl)
    return newObj
  end
  
  _String.foreach = tbl_foreach
  _String.map = tbl_map
  _String.filter = strl_filter
  _String.drop = strl_drop
  _String.dropwhile = strl_dropwhile
  _String.reverse = tbl_reverse
  _String.foldleft = tbl_foldleft
  _String.foldright = tbl_foldright
  _String.split = function(self, sep)
    checkType(1, self, "stringlist")
    return str_split(tostring(self), sep)
  end

if _G._selene and _G._selene.liveMode then
  local load = _G.load
  _G.load = function(ld, src, mv, env) 
    if _G._selene and _G._selene.liveMode then
      local s = ""
      if type(ld) == "function" then
        local nws = ld()
        while nws and #nws > 0 do
          s = s .. nws
          nws = ld()
        end
      end
      ld = parse(ld)
    end
    return load(ld, src, mv, env)
  end
end

  _G._selene.initDone = true
end

if not _G._selene or not _G._selene.initDone then
  init()
end

local selene = {}
selene.parse = parse

return selene
