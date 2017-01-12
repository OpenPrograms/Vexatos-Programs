local fs = require("filesystem")
local shell = require("shell")
fs.mount(...,"/mnt/oppm")
shell.setPath(shell.getPath() .. ":/mnt/oppm:/mnt/oppm/lib")
