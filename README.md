# SBundler
A Lua bundler for Roblox script builders

## Why I made this
* Sometimes, I have some scripts that are better separated. This code allows me to join them (and have them working as intended) without modifying a single byte of code.

* Why would I use this? Because most of the time those scripts are on GitHub, and spamming HTTP requests is just too slow/will rate-limit others.

## How it works
* It works kind of how [luapack](https://github.com/Le0Developer/luapack) does. It checks for required modules in a starting file of your choice and builds the whole working code by recursively checking each required module. (Yes, very innovative.)

## Some things to consider
* Unlike requiring modules normally, this gives each module its own environment.
What does this mean? When a module assigns a global variable, like, `a = 1`, this variable will not be shared through the _G table. Instead, you have to explicitly share it by writing `_G.a = 1`, and the module that wants this variable also has to explicitly state its intent with `local a = _G.a`

* The require check will not consider package.path when searching for modules. So if you have something like
```lua
package.path = package.path..";./deps/?.lua"
require("myDep")
```
and the builder builds it wrong, it's your fault.

* The require function will not work as intended, if you have code that checks the required path and name given with `local name, path = ...`, you will find that only the name variable is defined. This is because I cannot share the path easily, and it's kind of useless considering all the modules are inside the same file anyway. But, I did add an array argument 'args' to the require function, which allows you to add any variables of your liking to the vararg.

* To silence warnings on modules you don't want the builder to check for, just add a comment with an exclamation mark in front of the require call

> Example: require("foo") --!


## Usage
You can build a Lua bundle in a bash terminal using 
``
cd SBundler;
lua init.lua -i ../yourInitFile.lua -o ../outputFile.lua
``

Or, you can copy the SBundle.lua file into your system and run it in a bash terminal with `lua SBundle.lua -i yourInitFile.lua -o outputFile.lua`
