local song = require("song")
local noteList = {
  {"-F#2", "C#4_13", "P_8", "C#5_23"},
  {"P_18", "C#4_28"},
  {"P_19", "E4_27"},
  {"P_20", "F#4_26"},
  {"P_21", "G#4_25"},
  {"P_22", "B4_24"}
}
song.play(noteList, 0.0625, true)
