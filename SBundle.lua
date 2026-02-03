local unpack = unpack or table.unpack
local require = (function(_ENV)
    package = package or {preload = {}}
    local loaded = {}
    package.loaded = setmetatable({}, {__index = loaded})

    return function(modname, args)
        local res = loaded[modname]
        if res then
            return res
        end

        local mod = package.preload[modname]
        if mod then
            local args = type(args) == "table" and args or {args}
            loaded[modname] = mod(setmetatable({}, {__index = _ENV}), modname, unpack(args))
        else
            loaded[modname] = require(modname)
        end

        return loaded[modname]
    end
end)(_ENV or getfenv())

package.preload["./SBundler"] = function(_ENV, ...)
    local function mod(_ENV, ...)
local f = string.format

local SBundler = {
    init = "",
    modules = {}
}


function SBundler:onStart(code)
    if type(code) ~= "string" then
        error("Invalid initialization source, expected string", 2)
    end
    
    SBundler.init = code
end


function SBundler:clear()
    self.modules = {}
end

function SBundler:generate()
    local src = {
        "local unpack = unpack or table.unpack",
        [[
local require = (function(_ENV)
    package = package or {preload = {}}
    local loaded = {}
    package.loaded = setmetatable({}, {__index = loaded})

    return function(modname, args)
        local res = loaded[modname]
        if res then
            return res
        end

        local mod = package.preload[modname]
        if mod then
            local args = type(args) == "table" and args or {args}
            loaded[modname] = mod(setmetatable({}, {__index = _ENV}), modname, unpack(args))
        else
            loaded[modname] = require(modname)
        end

        return loaded[modname]
    end
end)(_ENV or getfenv())
]],
    }
    
    for modname, modsrc in next, SBundler.modules do
        src[#src + 1] = f([[
package.preload[%q] = function(_ENV, ...)
    local function mod(_ENV, ...)
%s
    end
    if setfenv then
        setfenv(mod, _ENV)
    end

    return mod(_ENV, ...)
end]], modname, modsrc)
    end
    
    src[#src + 1] = SBundler.init
    
    return table.concat(src, "\n")
end


function SBundler:addMod(modname, Source)
    if type(Source) ~= "string" then
        error("Invalid module source, expected string", 2)
    end
    
    self.modules[tostring(modname)] = Source
end

function SBundler:removeMod(modname)
    self.modules[tostring(modname)] = nil
end

function SBundler:hasMod(modname)
    return self.modules[tostring(modname)] ~= nil
end


return SBundler
    end
    if setfenv then
        setfenv(mod, _ENV)
    end

    return mod(_ENV, ...)
end
package.preload["./options"] = function(_ENV, ...)
    local function mod(_ENV, ...)
-- rewritte the code to be better (some day)
local options = {}
local long_options = {}

local module = {
    options = options,
    long_options = long_options
}

local function handle_opt(opts, Arg)
    local optL = #opts
    for i = 1, optL do
        local optN = opts:sub(i, i)
        options[optN](i == optL and Arg)
    end
end

function module.doOptions(arg)
    for optI, optN in ipairs(arg) do
        if optN:sub(1, 1) == "-" then
            local Arg = arg[optI + 1]
            local carg = (Arg and Arg or "-"):sub(1, 1) ~= "-" and Arg
            if carg then
                table.remove(arg, optI + 1)
            end
            
            if optN:sub(2, 2) == "-" then
                long_options[optN](carg)
            else
                handle_opt(optN:sub(2, -1), carg)
            end
        end
    end
end

return module
    end
    if setfenv then
        setfenv(mod, _ENV)
    end

    return mod(_ENV, ...)
end
local f = string.format
local requireMatches = {
    "require%s*(%()(.-)[%),]",
    "require%s*(['\"])(.-)%1",
    "require%s*%[(=*)%[(.-)%]%1%]"
}
local function unwrapStr(str)
    local start = select(2, str:find("^%[=*%[")) or select(2, str:find("^['\"]"))
    local end_ = str:find("%]=*%]$") or str:find("['\"]$")
    
    return str:sub((start or 0) + 1, (end_ or 0) - 1)
end

local SBundler = require("./SBundler")
local options = require("./options")
local input
local output
local verbose
local function vprint(str, ...)
    if verbose then
        print("[INFO]:", f(str, ...))
    end
end

local function checkForMods(fpath, src)
    for _, matchstr in ipairs(requireMatches) do
        for _, modname in src:gmatch(matchstr) do
            local modname = unwrapStr(modname)
            local mpath = fpath..modname
            
            if not SBundler:hasMod(modname) then
                local modF = io.open(mpath..".lua", "r") or io.open(mpath.."/init.lua", "r")
                
                if modF then
                    local modsrc = modF:read("*a")
                    SBundler:addMod(modname, modsrc)

                    vprint("Added module %q", modname)
                    checkForMods(fpath, modsrc)
                    
                else
                    print("[WARNING]: failed to find module '"..mpath..".lua' or '"..mpath.."/init.lua'")
                end
            end
        end
    end
end

if not arg then
    print("Insert init file path:")
    input = io.read()
end

local helpPage = {
  "Available command options:",
    "-h --help    commandName  display this help page",
    "-i --input   directory    init file path to read",
    "-o --output  name         output to file 'name' (default is \"sbbout.lua\")",
    "-v --verbose              list all files being read and extra information"
}

if arg then
    options.options.h = function(commandName)
        if not commandName then
            print(table.concat(helpPage, "\n  "))
            return
        end
        
        for _, commandPage in ipairs(helpPage) do
            if commandPage:match("%-%-?"..sanitize(commandName)) then
                print(" ", commandPage)
                return
            end
        end
    end
    
    options.options.i = function(path)
        input = path
    end
    options.options.o = function(path)
        output = path
    end
    options.options.v = function(path)
        verbose = true
    end
    
    options.long_options.help = options.options.h
    options.long_options.input = options.options.i
    options.long_options.output = options.options.o
    options.long_options.verbose = options.options.v
    
    options.doOptions(arg)
end

if not input and arg then
    print(table.concat(helpPage, "\n  "))
    return
end

local inputF = io.open(input, "r")
if inputF then
    local src = inputF:read("*a")
    local fpath = input:match(".*/") or "./"
    SBundler:onStart(src)
    
    checkForMods(fpath, src)
else
    print("[ERROR]: File '"..input.."' not found")
    return
end

local result = SBundler:generate()
if not output then
    local outF = io.open("./sbbout.lua", "w")
    if outF then
        outF:write(result)
    else
        print("[ERROR]: Unable to write to path './sbbout.lua'")
    end
    
    return
end

local outF = io.open(output, "w")
if outF then
    outF:write(result)
else
    print("[ERROR]: Unable to write to path '"..output.."'")
end