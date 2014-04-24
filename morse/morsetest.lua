local morse = require("lib.morse")
local str = "Hello World;Pastry fork; abcdefglmnop; -,-"
print(str)
local code = morse.encode(str)
print(code)
local passed = morse.decode(code)
print(passed)