--[[
OpenPrograms package manager, browser and downloader, for easy access to many programs
Author: Vexatos
]]
local component = require("component")
local event = require("event")
local fs = require("filesystem")
local process = require("process")
local serial = require("serialization")
local shell = require("shell")
local term = require("term")

local wget = loadfile("/bin/wget.lua")

local gpu = component.gpu

if not component.isAvailable("internet") then
  io.stderr:write("This program requires an internet card to run.")
  return
end
local internet = require("internet")

local args, options = shell.parse(...)


local function printUsage()
  print("OpenPrograms Package Manager, use this to browse through and download OpenPrograms programs easily")
  print("Usage:")
  print("'oppm list [-i]' to get a list of all the available program packages")
  print("'oppm list [-i] <filter>' to get a list of available packages containing the specified substring")
  print(" -i: Only list already installed packages")
  print("'oppm info <package>' to get further information about a program package")
  print("'oppm install [-f] <package> [path]' to download a package to a directory on your system (or /usr by default)")
  print("'oppm update <package>' to update an already installed package")
  print("'oppm uninstall <package>' to remove a package from your system")
  print(" -f: Force creation of directories and overwriting of existing files.")
end

local function getContent(url)
  local sContent = ""
  local result, response = pcall(internet.request, url)
  if result then
    for chunk in response do
      sContent = sContent..chunk
    end
  end
  return sContent
end

local function getRepos()
  local sRepos = getContent("https://raw.githubusercontent.com/OpenPrograms/openprograms.github.io/master/repos.lua")
  return serial.unserialize(sRepos)
end

local function getPackages(repo)
  local sPackages = getContent("https://raw.githubusercontent.com/OpenPrograms/"..repo.."/master/programs.lua")
  return serial.unserialize(sPackages)
end

--Sort table values by alphabet
local function compare(a,b)
  for i=1,math.min(#a,#b) do
    if a:sub(i,i)~=b:sub(i,i) then
      return a:sub(i,i) < b:sub(i,i)
    end
  end
  return #a < #b
end

local function downloadFile(url,path)
  if options.f then
    wget("-fq",url,path)
  else
    wget("-q",url,path)
  end
end

local function readFromFile()
  local tPath = process.running()
  local path = fs.path(shell.resolve(tPath)).."opdata.svd"
  if not fs.exists(path) then
    return {-1}
  end
  local file,msg = io.open(path,"rb")
  if not file then
    io.stderr:write("Error while trying to read package names: "..msg)
    return
  end
  local sPacks = file:read("*a")
  file:close()
  return serial.unserialize(sPacks) or {-1}
end

local function saveToFile(tPacks)
  local tPath = process.running()
  local file,msg = io.open(fs.path(shell.resolve(tPath)).."opdata.svd","wb")
  if not file then
    io.stderr:write("Error while trying to save package names: "..msg)
    return
  end
  local sPacks = serial.serialize(tPacks)
  file:write(sPacks)
  file:close()
end

local function listPackages(filter)
  filter = filter or false
  if filter then
    filter = string.lower(filter)
  end
  print("Receiving Package list...")
  local repos = getRepos()
  if repos==nil then
      print("Error while trying to receive repository list")
      return
    end
  local packages = {}
  for _,j in pairs(repos) do
    local lPacks = getPackages(j)
    if lPacks==nil then
      print("Error while trying to receive package list for "..j)
      return
    end
    for k in pairs(lPacks) do
      if not k.hidden then
        table.insert(packages,k)
      end
    end
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
  if options.i then
    local lPacks = {}
    local tPacks = readFromFile()
    for i,j in ipairs(packages) do
      if tPacks[j] then
        table.insert(lPacks,j)
      end
    end
    packages = lPacks
  end
  table.sort(packages,compare)
  return packages
end

local function printPackages(tPacks)
  if tPacks==nil or not tPacks[1] then
    print("No package matching specified filter found.")
    return
  end
  term.clear()
  local xRes,yRes = gpu.getResolution()
  print("--OpenPrograms Package list--")
  local xCur,yCur = term.getCursor()
  for _,j in ipairs(tPacks) do
    term.write(j.."\n")
    yCur = yCur+1
    if yCur>yRes-1 then
      term.write("[Press any key to continue]")
      local event = event.pull("key_down")
      if event then
        term.clear()
        print("--OpenPrograms Package list--")
        xCur,yCur = term.getCursor()
      end
    end
  end
end

local function getInformation(pack)
  local repos = getRepos()
  for _,j in pairs(repos) do
    local lPacks = getPackages(j)
    for k in pairs(lPacks) do
      if k==pack then
        return lPacks[k],j
      end
    end
  end
  return nil
end

local function provideInfo(pack)
  if not pack then
    printUsage()
    return
  end
  pack = string.lower(pack)
  local info = getInformation(pack)
  if not info then
    print("Package does not exist")
    return
  end
  local done = false
  print("--Information about package '"..pack.."'--")
  if info.name then
    print("Name: "..info.name)
    done = true
  end
  if info.description then
    print("Description: "..info.description)
    done = true
  end
  if info.authors then
    print("Authors: "..info.authors)
    done = true
  end
  if info.instructions then
    print("Instructions: "..info.authors)
    done = true
  end
  if not done then
    print("No information provided.")
  end
end

local function installPackage(pack,path,update)
  update = update or false
  if not pack then
    printUsage()
    return
  end
  if not path and not update then
    path = "/usr"
    print("Installing package to "..path.."...")
  elseif not update then
    path = shell.resolve(path)
    print("Installing package to "..path.."...")
  end
  pack = string.lower(pack)

  local tPacks = readFromFile()
  if not tPacks then
    io.stderr:write("Error while trying to read package names")
    return
  elseif tPacks[1]==-1 then
    table.remove(tPacks,1)
  end

  local info,repo = getInformation(pack)
  if not info then
    print("Package does not exist")
    return
  end
  if update then
    print("Updating package "..pack)
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
      if options.f then
        path = fs.concat(fs.path(path),pack)
        fs.makeDirectory(path)
      else
        print("Path points to a file, needs to be a directory.")
        return
      end
    end
  elseif not update then
    if options.f then
      fs.makeDirectory(path)
    else
      print("Directory does not exist.")
      return
    end
  end
  if tPacks[pack] and (not update) then
    print("Package already has been installed")
    return
  elseif not tPacks[pack] and update then
    print("Package has not been installed.")
    print("If it has, uninstall it manually and reinstall it.")
    return
  end
  if update then
    term.write("Removing old files...")
    for i,j in pairs(tPacks[pack]) do
      fs.remove(j)
    end
    term.write("Done.\n")
  end
  tPacks[pack] = {}
  term.write("Installing Files...")
  for i,j in pairs(info.files) do
    local lPath = fs.concat(path,j)
    if not fs.exists(lPath) then
      fs.makeDirectory(lPath)
    end
    local success = pcall(downloadFile,"https://raw.githubusercontent.com/OpenPrograms/"..repo.."/"..i,fs.concat(path,j,string.gsub(i,".+(/.-)$","%1"),nil))
    if success then
      tPacks[pack][i] = fs.concat(path,j,string.gsub(i,".+(/.-)$","%1"),nil)
    end
  end
  if info.dependencies then
    term.write("Done.\nInstalling Dependencies...")
    for i,j in pairs(info.dependencies) do
      if string.lower(string.sub(i,1,4))=="http" then
        local success = pcall(downloadFile,i,fs.concat(path,j,string.gsub(i,".+(/.-)$","%1"),nil))
        if success then
          tPacks[pack][i] = fs.concat(path,j,string.gsub(i,".+(/.-)$","%1"),nil)
        end
      else
        local depInfo = getInformation(string.lower(i))
        if not depInfo then
          term.write("\nDependency package "..i.." does not exist.")
        end
        installPackage(string.lower(i),fs.concat(path,j))
      end
    end
  end
  term.write("Done.\n")
  saveToFile(tPacks)
  print("Successfully installed package "..pack)
end

local function uninstallPackage(pack)
  local info,repo = getInformation(pack)
  if not info then
    print("Package does not exist")
    return
  end
  local tFiles = readFromFile()
  if not tFiles then
    io.stderr:write("Error while trying to read package names")
    return
  elseif tFiles[1]==-1 then
    table.remove(tFiles,1)
  end
  if not tFiles[pack] then
      print("Package has not been installed.")
      print("If it has, you have to remove it manually.")
      return
  end
  term.write("Removing package files...")
  for i,j in pairs(tFiles[pack]) do
    fs.remove(j)
  end
  term.write("Done\nRemoving references...")
  tFiles[pack]=nil
  saveToFile(tFiles)
  term.write("Done.\n")
  print("Successfully uninstalled package "..pack)
end

if args[1] == "list" then
  local tPacks = listPackages(args[2])
  printPackages(tPacks)
elseif args[1] == "info" then
  provideInfo(args[2])
elseif args[1] == "install" then
  installPackage(args[2],args[3],false)
elseif args[1] == "update" then
  installPackage(args[2],nil,true)
elseif args[1] == "uninstall" then
  uninstallPackage(args[2])
else
  printUsage()
  return
end
