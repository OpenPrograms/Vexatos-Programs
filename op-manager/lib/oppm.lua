--[[
OpenPrograms package manager, browser and downloader, for easy access to many programs
This is the library providing all the important functions.
Author: Vexatos
]]
local event = require("event")
local fs = require("filesystem")
local process = require("process")
local serial = require("serialization")
local shell = require("shell")
local wget = loadfile("/bin/wget.lua")

if not component.isAvailable("internet") then
  error("No internet card found")
  return
end

local internet = require("internet")

local oppm = {}

local function getContent(url)
  local sContent = ""
  local result, response = pcall(internet.request, url)
  if not result then
    return nil
  end
    for chunk in response do
      sContent = sContent..chunk
    end
  return sContent
end

local function getRepos()
  local success, sRepos = pcall(getContent,"https://raw.githubusercontent.com/OpenPrograms/openprograms.github.io/master/repos.cfg")
  if not success then
    io.stderr:write("Could not connect to the Internet. Please ensure you have an Internet connection.")
    return -1
  end
  return serial.unserialize(sRepos)
end

local function getPackages(repo)
  local success, sPackages = pcall(getContent,"https://raw.githubusercontent.com/"..repo.."/master/programs.cfg")
  if not success or not sPackages then
    return -1
  end
  return serial.unserialize(sPackages)
end

--For sorting table values by alphabet
local function compare(a,b)
  for i=1,math.min(#a,#b) do
    if a:sub(i,i)~=b:sub(i,i) then
      return a:sub(i,i) < b:sub(i,i)
    end
  end
  return #a < #b
end

local function downloadFile(url,path,force)
  if force then
    return wget("-fq",url,path)
  else
    return wget("-q",url,path)
  end
end

local function readFromFile(fNum)
  local path
  if fNum == 1 then
    path = "/etc/opdata.svd"
  elseif fNum == 2 then
    path = "/etc/oppm.cfg"
    if not fs.exists(path) then
      local tProcess = process.running()
      path = fs.concat(fs.path(shell.resolve(tProcess)),"/etc/oppm.cfg")
    end
  end
  if not fs.exists(fs.path(path)) then
    fs.makeDirectory(fs.path(path))
  end
  if not fs.exists(path) then
    return {-1}
  end
  local file,msg = io.open(path,"rb")
  if not file then
    error("error while trying to read file at "..path..": "..msg)
  end
  local sPacks = file:read("*a")
  file:close()
  return serial.unserialize(sPacks) or {-1}
end

local function saveToFile(tPacks)
  local file,msg = io.open("/etc/opdata.svd","wb")
  if not file then
    error("error while trying to save package names: "..msg)
  end
  local sPacks = serial.serialize(tPacks)
  file:write(sPacks)
  file:close()
end

function oppm.listPackages(filter,installed)
  filter = filter or false
  if filter then
    filter = string.lower(filter)
  end
  local packages = {}
  if not installed then
    local success, repos = pcall(getRepos)
    if not success or repos==-1 then
      error("unable to connect to the Internet")
    elseif repos==nil then
        error("error while trying to receive repository list")
    end
    for _,j in pairs(repos) do
      if j.repo then
        local lPacks = getPackages(j.repo)
        if lPacks==nil then
          error("error while trying to receive package list for " .. j.repo)
        elseif type(lPacks) == "table" then
          for k in pairs(lPacks) do
            if not k.hidden then
              table.insert(packages,k)
            end
          end
        end
      end
    end
    local lRepos = readFromFile(2)
    if lRepos and lRepos.repos then
      for _,j in pairs(lRepos.repos) do
        for k in pairs(j) do
          if not k.hidden then
            table.insert(packages,k)
          end
        end
      end
    end
  else
    local lPacks = {}
    local tPacks = readFromFile(1)
    for i in pairs(tPacks) do
      table.insert(lPacks,i)
    end
    packages = lPacks
  end
  if filter then
    local lPacks = {}
    for i,j in ipairs(packages) do
      if (#j>=#filter) and string.find(j,filter,1,true)~=nil then
          table.insert(lPacks,j)
      end
    end
    packages = lPacks
  end
  table.sort(packages,compare)
  return packages
end

local function getFullInformation(pack)
  local success, repos = pcall(getRepos)
  if not success or repos==-1 then
    error("unable to connect to the Internet")
  end
  for _,j in pairs(repos) do
    if j.repo then
      local lPacks = getPackages(j.repo)
      if lPacks==nil then
        error("error while trying to receive package list for "..j.repo)
      elseif type(lPacks) == "table" then
        for k in pairs(lPacks) do
          if k==pack then
            return lPacks[k],j.repo
          end
        end
      end
    end
  end
  local lRepos = readFromFile(2)
  if lRepos then
    for i,j in pairs(lRepos.repos) do
      for k in pairs(j) do
        if k==pack then
          return j[k],i
        end
      end
    end
  end
  return nil
end

function oppm.getInformation(pack)
  if not pack then
    return false, "no input given"
  end
  pack = string.lower(pack)
  local info = getFullInformation(pack)
  if not info then
    return false, "package does not exist"
  end
  local done = false
  local tInfo = {}
  if info.name then
    tInfo.name = info.name
    done = true
  end
  if info.description then
    tInfo.description = info.description
    done = true
  end
  if info.authors then
    tInfo.authors = info.authors
    done = true
  end
  if info.note then
    tInfo.note = info.note
    done = true
  end
  if not done then
    return false, "no information provided"
  end
  return tInfo
end

local function installPack(pack,path,update,force)
  update = update or false
  if not pack then
    return false, "no input given"
  end
  if not path and not update then
    local lConfig = readFromFile(2)
    path = lConfig.path or "/usr"
  elseif not update then
    path = shell.resolve(path)
  end
  pack = string.lower(pack)

  local tPacks = readFromFile(1)
  if not tPacks then
    error("error while trying to read local package names")
  elseif tPacks[1]==-1 then
    table.remove(tPacks,1)
  end

  local info,repo = getFullInformation(pack)
  if not info then
    return false, "package does not exist"
  end
  if update then
    path = nil
    for i,j in pairs(info.files) do
      for k,v in pairs(tPacks[pack]) do
        if k==i then
          path = string.gsub(fs.path(v),j.."/?$","/")
          break
        end
      end
      if path then
        break
      end
    end
    path = shell.resolve(string.gsub(path,"^/?","/"),nil)
  end
  if not update and fs.exists(path) then
    if not fs.isDirectory(path) then
      if force then
        path = fs.concat(fs.path(path),pack)
        fs.makeDirectory(path)
      else
        error("path points to a file, needs to be a directory")
        return
      end
    end
  elseif not update then
    if force then
      fs.makeDirectory(path)
    else
      error("directory does not exist")
      return
    end
  end
  if tPacks[pack] and (not update) then
    return false, "package has already been installed"
  elseif not tPacks[pack] and update then
    return false, "package has not been installed"
  end
  if update then
    for i,j in pairs(tPacks[pack]) do
      fs.remove(j)
    end
  end
  tPacks[pack] = {}
  for i,j in pairs(info.files) do
    local nPath
    if string.find(j,"^//") then
      local lPath = string.sub(j,2)
      if not fs.exists(lPath) then
        fs.makeDirectory(lPath)
      end
      nPath = fs.concat(lPath,string.gsub(i,".+(/.-)$","%1"),nil)
    else
      local lPath = fs.concat(path,j)
      if not fs.exists(lPath) then
        fs.makeDirectory(lPath)
      end
      nPath = fs.concat(path,j,string.gsub(i,".+(/.-)$","%1"),nil)
    end
    local success,response = pcall(downloadFile,"https://raw.githubusercontent.com/"..repo.."/"..i,nPath)
    if success and response then
      tPacks[pack][i] = nPath
    else
      fs.remove(nPath)
      for o,p in pairs(tPacks[pack]) do
        fs.remove(p)
        tPacks[pack][o]=nil
      end
      error("Error while installing files for package '"..i.."'. Installation reverted")
    end
  end
  if info.dependencies then
    for i,j in pairs(info.dependencies) do
      local nPath
      if string.find(j,"^//") then
        nPath = string.sub(j,2)
      else
        nPath = fs.concat(path,j,string.gsub(i,".+(/.-)$","%1"),nil)
      end
      if string.lower(string.sub(i,1,4))=="http" then
        local success,response = pcall(downloadFile,i,nPath)
        if success and response then
          tPacks[pack][i] = nPath
        else
          fs.remove(nPath)
          for o,p in pairs(tPacks[pack]) do
            fs.remove(p)
            tPacks[pack][o]=nil
          end
          error("Error while installing dependency package '"..i.."'. Installation reverted")
        end
      else
        local depInfo = getFullInformation(string.lower(i))
        if depInfo then
          installPack(string.lower(i),fs.concat(path,j),update)
        end
      end
    end
  end
  saveToFile(tPacks)
  return true
end

function oppm.installPackage(pack,path)
  installPack(pack,path,false)
end

function oppm.uninstallPackage(pack)
  local info,repo = getFullInformation(pack)
  if not info then
    return false, "package does not exist"
  end
  local tFiles = readFromFile(1)
  if not tFiles then
    error("error while trying to read package names")
  elseif tFiles[1]==-1 then
    table.remove(tFiles,1)
  end
  if not tFiles[pack] then
      return false, "package has not been installed"
  end
  for i,j in pairs(tFiles[pack]) do
    fs.remove(j)
  end
  tFiles[pack]=nil
  saveToFile(tFiles)
  return true
end

function oppm.updatePackage(pack)
  if pack=="all" then
    local tFiles = readFromFile(1)
    if not tFiles then
      error("error while trying to read package names")
      return
    elseif tFiles[1]==-1 then
      table.remove(tFiles,1)
    end
    local done = false
    for i in pairs(tFiles) do
      installPack(i,nil,true)
      done = true
    end
    if not done then
      return false, "No package has been installed so far"
    end
  else
    installPack(pack,nil,true)
  end
end

return oppm
