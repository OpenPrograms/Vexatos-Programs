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

local function injectConfig()
  local config = [[
-- Set this to true to load Selene on this computer on startup.
local enableSelene = false
-- Set this to false to disable live interpreting of Selene files. Will require compiling manually using selene.parse
local liveMode = false


return enableSelene, liveMode
]]
  local path = "/etc/selene.cfg"
  if not fs.exists(path) then
    local file = fs.open(path, "w")
    if file then
      file.write(config)
      file.close()
    end
  end
end

local function readConfig()
  local success, enable, mode = pcall(dofile, "/etc/selene.cfg")
  if success then
    _G._selene.liveMode = mode
    if enable then
      local selene = require("selene")
      selene.load()

      selene.parser.setTimeoutHandler(
        function()
          sleep(0)
        end,
        function()
          return 3
        end,
        os.clock
      )
    end
  else
    _G._selene.liveMode = false
  end
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
  injectConfig()
  readConfig()
end

load()
