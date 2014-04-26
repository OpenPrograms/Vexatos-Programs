local morse = require("lib.morse")
local str = "Hello World;"
print(str)
local code = morse.receive("left")
local passed = morse.decode(code)
print(passed)