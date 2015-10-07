--This will make Selene work with ComputerCraft.

local function mrpairs(t, oldf, mf)
  if type(t) == "table" then
    local res, mt = pcall(getmetatable, t)
    if res and mt and mt[mf] then
      local m1,m2,m3 = mt[mf](t)
      return m1,m2,m3
    end
  end
  return oldf(t)
end

local function load()
  if not _G._selene then _G._selene = {} end
  _G._selene._oldpairs = _G.pairs
  _G._selene._oldipairs = _G.ipairs
  _G.pairs = function(t)
    return mrpairs(t, _G._selene._oldpairs, "__pairs")
  end
  _G.ipairs = function(t)
    return mrpairs(t, _G._selene._oldipairs, "__ipairs")
  end
  _G._selene.liveMode = true
  local selene = require("selene")
  selene.load()
end

load()
