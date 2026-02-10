# SBPacker
A Lua packer for Roblox script builders

## Why I made this
* Sometimes, I have some scripts that are better separated. This code allows me to join them (and have them working as intended) without modifying a single byte of code.

---

* Why would I use this? Because most of the time those scripts are on GitHub, and spamming HTTP requests is just too slow/will rate-limit others.

## How it works
* It works kind of how [luapack](https://github.com/Le0Developer/luapack) does. It checks for required modules in a starting file of your choice and builds the whole working code by recursively checking each required module. (Yes, very innovative.)

## Some things to consider
> for definition, imagine source containers as containers for Lua code only (either a module or a script)
* Unlike requiring source containers normally, this gives each source container its own environment.
What does this mean? When a source container assigns a global variable, like, `a = 1`, this variable will not be shared through the _G table. Instead, you have to explicitly share it by writing `_G.a = 1`, and the source container that wants this variable also has to explicitly state its intent with `local a = _G.a`

---

* The require check will not consider package.path when searching for source containers. So if you have something like
```lua
package.path = package.path..";./deps/?.lua"
require("myDep")
```
and the builder builds it wrong, it's your fault.

---

* The require function will not work as intended(by native Lua standards), if you have code that checks the required path and name given with `local name, path = ...`, you will find that only the name variable is defined. This is because I cannot share the path easily, and it's kind of useless considering all the source containers are inside the same file anyway. But, I did add an array argument 'args' to the require function, which allows you to add any variables of your liking to the vararg.

---

* By default, each source container has its own separate coroutine thread. If a source container throws an error, the whole program won't crash, and instead only said source container that threw the error(and possibly others that depend on it) will fail.
* To change the behavior from script to module (so that errors are in the same coroutine thread) you have to specify the source container as a module by adding a comment with a dollar sign in front of the require call.
> Example: require("foo") --$

---

* To silence warnings on modules you don't want the builder to check for, just add a comment with an exclamation mark in front of the require call.
> Example: require("foo") --!

---

* The following is a list of all require modes (must be in a comment in front of the require call, multiple modes can be defined inside the same comment):

1. ! = ignore\
source containers marked by this will not be included in the final build

3. @ = script\
source containers marked by this will be treated as scripts (default) and will not crash the calling thread on fail (the returned value is still received by the require call)

4. $ = module\
source containers marked by this will be treated as modules and will crash the calling thread on fail

5. ? = optional\
source containers marked by this are optional and will not warn during the building process if missing

6. \* = obligatory(dependency)\
source containers marked by this are obligatory and will stop the building process if missing

## Usage
You can build a Lua pack in a bash terminal using:
``
cd SBPacker;
lua init.lua -i ../yourInitFile.lua -o ../outputFile.lua
``

Alternatively, you can copy the SBPacker.lua file into your system and run it in a bash terminal with `lua SBPacker.lua -i yourInitFile.lua -o outputFile.lua`
