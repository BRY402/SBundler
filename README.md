# SBundler
A Lua bundler for Roblox script builders

## Why I made this
Sometimes, I have some scripts that are better separated. This code allows me to join them (and have them working as intended) without modifying a single byte of code.
Why would I use this? Because most of the time those scripts are on GitHub, and spamming HTTP requests is just too slow/will rate-limit others.

## How it works
It works kind of how [luapack](https://github.com/Le0Developer/luapack) does. It checks for required modules in a starting file of your choice and builds the whole working code by recursively checking each required module. (Yes, very innovative.)

## Some things to consider
* Unlike requiring modules normally, this gives each module its own environment.
What does this mean? When a module assigns a global variable, like, `a = 1`, this variable will not be shared through the _G table. Instead, you have to explicitly share it by writing `_G.a = 1`, and the module that wants this variable also has to explicitly state its intent with `local a = _G.a`

* The require check will not consider package.path when searching for modules. So if you have something like
```lua
package.path = package.path..";./deps/?.lua"
require("myDep")
```
and the builder builds it wrong, it's your fault.

## Usage
You can build a Lua bundle in a bash terminal using `lua SBundler/init.lua -i yourInitFile.lua -o outputFile.lua`
