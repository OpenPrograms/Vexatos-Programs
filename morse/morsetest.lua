local morse = require("lib.morse")
local str = "Hello World;?bce:)"
print(str)
local code = morse.encode(str)
print(code)
local passed = morse.decode(code)
print(passed)
morse.send(code,"back")