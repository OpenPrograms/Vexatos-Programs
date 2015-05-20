Selene
======

This is a Lua library I made for more convenient functional programming. It provides special syntax as well as convenient functions on tables and strings.
###Table of contents
  - [Syntax](#syntax)
    - [Smart self-calling](#smart-self-calling)
    - [Wrapped tables](#wrapped-tables)
      - [What you can do with wrapped tables or strings](#what-you-can-do-with-wrapped-tables-or-strings)
      - [Utility functions for wrapped tables](#utility-functions-for-wrapped-tables)
    - [Lambdas](#lambdas)
      - [Utility functions for wrapped and normal functions](#utility-functions-for-wrapped-and-normal-functions)
    - [Ternary Operators](#ternary-operators)
    - [Foreach](#foreach)
  - [Functions](#functions)
    - [bit32](#bit32)
    - [table](#table)
    - [string](#string)
    - [Wrapped tables](#wrapped-tables-1)
    - [Wrapped strings](#wrapped-strings)

#Syntax
This is a list of the special syntax available in Selene.
###Smart self-calling
A tweak that makes method calls with no parameters more convenient.
Basically, it allows doing this
```lua
local s = "Hello World"
local r = s:reverse
```
Which equates
```lua
local s = "Hello World"
local r = s:reverse()
```
###Wrapped tables
You can use `$(t: table or string)` to turn a table or a string into a wrapped table or string to perform bulk data operations on them. If the table is a list (i.e. if every key in the table is a number valid for `ipairs`), it will automatically create a list, otherwise it will create a map.
```lua
local t = {"one", "two"}
t = $(t) -- Will create a list
local p = {a="one", b="two"}
p = $(p) -- Will create a map
local s = "Fish"
s = $(s) -- Will create a wrapped string, you can iterate through each character just like you can using a list.
```
If you want to enforce a certain type of wrapped table, you can use `$l()` to create a list and `$s()` to create a wrapped string. If the wrapped table of the specific type cannot be created for some reason, the function will error.

Turning a wrapped table or string back into a normal table or string is quite easy:
```lua
t = t() -- Calling the table like a function turns it back into a normal table
p = p:$ -- This also creates a table again
s = s.$ -- This is the third way of getting back your string or table.
s = tostring(s) -- This is a way of getting back strings from wrapped strings.
```
A note about wrapped strings: If you call `pairs` or `ipairs` with a wrapped string as a parameter, it will iterate through every character in the string.
####What you can do with wrapped tables or strings
See [the functions documentation](#functions) for methods may call on wrapped tables or strings.
####Utility functions for wrapped tables
 - `ltype(t: anything):string` This functions works just like `type`, just that it, if it finds a wrapped table, may return `"map"`, `"list"` or `"stringlist"`.
 - `checkType(n:number, t:anything, types:string...)` This function errors when `t` does not match any of the specified types of wrapped tables. `n` is the index of the parameter, used for a more descriptive error message. if no type is specified, it will error if `t` is not a wrapped table.
 - `lpairs(t:wrapped table)` This functions works just like `ipairs` when called with a list or wrapped string and just like `pairs` when called with anything else.
 - `isList(t:wrapped table or table):boolean` This function returns true if the table is either a list (as a wrapped table) or a normal table that can be turned into a list (i.e. if every key in the table is a number valid for `ipairs`)

###Lambdas
Lambdas are wrapped in `()` brackets and always look like `(<var1> [, var2, ...] -> <operation>)`. Alternatively to the `->` you can also use `=>`.
```lua
local t = {"one", "two"}
t = $(t):filter((s -> s:find("t")))()
-- t should be {"two"} now
local f = (s, r -> s + r) -- f is now a function that, once executed with the parameters s and r, returns the sum of s and r.
```
It will automatically be parsed into a wrapped Lua function, and, if the lambda does not contain any `return`, automatically add a `return` in the front.
####Utility functions for wrapped and normal functions
 - `checkFunc(f:function, parCount:number...)` This function errors if the specified variable does not contain a function or a wrapped function. If it is a wrapped function, it will error if the amount of its parameters does not match any of the numbers given to this function.
 - `parCount(f:function, def:number or nil):number` This function errors if `f` is not a function or a wrapped function. If it is a normal function, it will return `def`. If it is a wrapped function, it will return the amount of its parameters. If it can't for some reason, it will return `def`.
 - `$f(f:function, parCount:number):wrapped function` This functions turns a normal Lua function into a wrapped function with the specified amount of parameters. This could be useful if you want to use `checkFunc` or `parCount` to depend on a specific number of parameters. You can call this wrapped function just like you can call any normal Lua function.

###Ternary Operators
Ternary operators are wrapped in `()` brackets and always look like `(<condition> ? <trueCase> : <falseCase>)`.
```lua
local a = 5
local c = (a >= 5 ? 1 : -1) -- c should be 1 now.
```
If `<condition>` is true, the first case will be returned, otherwise the second one will.
###Foreach
Selene supports alternative syntax for foreach:
```lua
local b = {"one", "two", "three"}
for i,j <- b do
  print(i, j)
end
```
If the table can be iterated through with `ipairs` (i.e. if every key in the table is a number valid for `ipairs`), it will choose that, otherwise it will choose `pairs`.

#Functions
This is a list of the functions available on wrapped tables or strings as specified [here](#syntax) as well as functions added to native libraries.
###bit32
Firstly, Selene adds two convenient functions to the `bit32` library, called fish-or or `for`:
 - `bit32.bfor(n1:number, n2:number, n3:number):number` This functions returns the bitwise fish-or of its operands. A bit will be 1 if two out of three of the operands' bits are 1.
 - `bit32.nfor(n1:anything, n2:anything, n3:anything):boolean` This returns `true` if two out of three of the operands are not `nil` and not `false`

###table
The native `table` library got two new functions:
 - `table.shallowcopy(t:table):table` This will return a copy `t` that contains every entry `t` did contain.
 - `table.flatten(t:table):table` This will collapse one level of inner tables and merge their entries into `t`. `t` need to be a valid list (every key in the table has to be a number valid for `ipairs`). Inner tables will only get merged if they are lists as well, tables with invalid keys will stay the way they are in the table.
 - `table.range(start:number, stop:number [, step:number]):table` This will create a range of numbers ranging from `start` to `stop`, with a step size of `step` or 1.
 - `table.zipped(t1:table, t2:table):table` This will merge two tables into one if both have the same length, in the pattern `{{t1[1], t2[1]}, {t1[2], t2[2]}, ...}`

###string
These functions will not work directly called on a string, i.e. `string.drop("Hello", 2)` will work but `("Hello"):drop(2)` will not. For that, use wrapped strings.
`function` may be a Lua function or a wrapped function (for instance a lambda).
 - `string.foreach(s:string, f:function)` This calls `f` once for every character in the string, with either the character or the index and the character as parameters.
 - `string.map(s:string, f:function):list or map` This function calls `f` once for every character in the string, with either the character or the index and the character as parameters, and inserts whatever it returns into a new table, which will then get returned as a list if possible and a map otherwise.
 - `string.filter(s:string, f:function):stringlist` This function calls `f` once for every character in the string, with either the character or the index and the character as parameters, and, if `f` returns `true`, will insert the character into a new wrapped string which will get returned, meaning that every character `f` returns `false` on will be removed.
 - `string.drop(s:string, n:number):string` This function will remove the first `n` characters from the string and return the new string.
 - `string.dropwhile(s:string, f:function):string` This function will remove the first character of the string as long as `f` returns `true` on that character (or on the index and the character).
 - `string.foldleft(s:string, m:anything, f:function):anything` This function calls `f` once for every character in the string, with `m` and that character as parameters. The value `f` returns will then be assigned to `m` for the next iteration.
 - `string.foldright(s:string, m:anything, f:function):anything` Exactly like `string.foldleft`, just that it starts iterating at the end of the string.
 - `string.split(s:string, sep:string or nil):list` This function splits the string whenever it encounters the specified separator, returning a list of every part of the string.

###Wrapped tables
These are the functions you can call on wrapped tables. `$()` represents a wrapped list or map, `$l()` represents a list.
 - `$():concat(sep:string, i:number, j:number):string` This works exactly like `table.concat`.
 - `$():foreach(f:function)` This works exactly like `string.foreach`, just that it will iterate through each key/value pair in the table.
 - `$():map(f:function):list or map` This works exactly like `string.map`, just that it will iterate through each key/value pair in the table.
 - `$():filter(f:function):list or map` This works exactly like `string.filter`, just that it will iterate through each key/value pair in the table and will return a list if possible, a map otherwise.
 - `$():foldleft(m:anything, f:function):anything` This works exactly like `string.foldleft`, just that it will iterate through each key/value pair in the table.
 - `$():foldright(m:anything, f:function):anything` TExactly like `$():foldleft`, just that it starts iterating at the end of the list.
 - `$():find(f:function):anything` This returns the first element of the table that `f` returns `true` on.
 - `$():shallowcopy()` This works exactly like `table.shallowcopy`.
 - `$l():drop(n:number):list` This function will remove the first `n` entries from the list and return itself with the dropped entries.
 - `$l():dropwhile(function):list` This works exactly like `string.dropwhile`, just that it will iterate through each key/value pair in the table and will return a itself with the dropped entries.
 - `$l():reverse():list` This function will invert the list so that the last entry will be the first one etc.
 - `$l():flatten():list` This works exactly like `table.flatten`.
 - `$l():zip(other:list or table or function)` This will merge the other table (which has to be an ipairs-valid list) or list into itself if both lists have the same length, in the pattern `{{t1[1], t2[1]}, {t1[2], t2[2]}, ...}`. If `other` is a function or wrapped function, it will call it once per iteration and merge the returned value in the described pattern.

###Wrapped strings
Wrapped strings or stringslists can mostly be seen as lists and have all the functions wrapped tables have (including `drop`, `dropwhile` and `reverse`). However, they do not have `concat`, `find` or `flatten`. `drop()` and `dropwhile` will return strings, `filter` will return a stringlist, and they have one extra function:
 - `$s():split(sep:string or nil):list` This works exactly like `string.split`. 
