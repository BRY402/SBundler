local coroutine = coroutine
local sb_package = {preload = {}}
local print = print

local require = (function(_ENV)
    local unpack = unpack or table.unpack
    local loaded = {}
    sb_package.loaded = setmetatable({}, {__index = loaded})

    return function(modname, args)
        local res = loaded[modname]
        if res then
            return res
        end

        local mod = sb_package.preload[modname]
        if mod then
            local args = type(args) == "table" and args or {args}
            loaded[modname] = mod(setmetatable({}, {__index = _ENV}), modname, unpack(args))
        else
            loaded[modname] = require(modname) --!
        end

        return loaded[modname]
    end
end)(_ENV or getfenv())

sb_package.preload["./SBPacker"] = function(_ENV, ...)
    local function mod(_ENV, ...)
local error = error
local f = string.format
local next = next
local table_concat = table.concat
local tostring = tostring
local type = type

local SBPacker = {
    init = "",
    modules = {},
    scripts = {}
}


function SBPacker:onStart(code)
    if type(code) ~= "string" then
        error("Invalid initialization source, expected string", 2)
    end
    
    SBPacker.init = code
end


function SBPacker:clear()
    self.modules = {}
end

function SBPacker:generate()
    local src = {
        [[
local coroutine = coroutine
local sb_package = {preload = {}}
local print = print

local require = (function(_ENV)
    local unpack = unpack or table.unpack
    local loaded = {}
    sb_package.loaded = setmetatable({}, {__index = loaded})

    return function(modname, args)
        local res = loaded[modname]
        if res then
            return res
        end

        local mod = sb_package.preload[modname]
        if mod then
            local args = type(args) == "table" and args or {args}
            loaded[modname] = mod(setmetatable({}, {__index = _ENV}), modname, unpack(args))
        else
            loaded[modname] = require(modname) --!
        end

        return loaded[modname]
    end
end)(_ENV or getfenv())
]],
    }
    
    for _, modsrc in next, SBPacker.modules do
        src[#src + 1] = modsrc
    end
    for _, scriptsrc in next, SBPacker.scripts do
        src[#src + 1] = scriptsrc
    end
    
    src[#src + 1] = SBPacker.init
    
    return table_concat(src, "\n")
end


function SBPacker:addMod(modname, Source)
    if type(Source) ~= "string" then
        error("Invalid module source, expected string", 2)
    end
    
    self.modules[tostring(modname)] = f([[
sb_package.preload[%q] = function(_ENV, ...)
    local function mod(_ENV, ...)
%s
    end
    if setfenv then
        setfenv(mod, _ENV)
    end

    return mod(_ENV, ...)
end]], modname, Source)
end

function SBPacker:addScript(scriptname, Source)
    if type(Source) ~= "string" then
        error("Invalid script source, expected string", 2)
    end
    
    self.scripts[tostring(scriptname)] = f([[
sb_package.preload[%q] = function(_ENV, ...)
    local function mod(_ENV, ...)
%s
    end
    if setfenv then
        setfenv(mod, _ENV)
    end
        
    local thread = coroutine.create(mod)
    local success, result = coroutine.resume(thread, _ENV, ...)

    if not success then
        print(result)
        return
    end

    return result
end]], scriptname, Source)
end

function SBPacker:removeMod(modname)
    self.modules[tostring(modname)] = nil
end

function SBPacker:removeScript(scriptname)
    self.scripts[tostring(scriptname)] = nil
end

function SBPacker:hasSourceContainer(name)
    return self.modules[tostring(name)] ~= nil or self.scripts[tostring(name)] ~= nil
end


return SBPacker
    end
    if setfenv then
        setfenv(mod, _ENV)
    end

    return mod(_ENV, ...)
end
sb_package.preload["./options"] = function(_ENV, ...)
    local function mod(_ENV, ...)
-- rewritte the code to be better (some day)
local ipairs = ipairs
local table_remove = table.remove

local options = {}
local long_options = {}

local module = {
    options = options,
    long_options = long_options
}

local function handle_opt(opts, Arg)
    local optL = #opts
    local res
    for i = optL, 1, -1 do
        local optN = opts:sub(i, i)
        res = options[optN](res or Arg) or ""
    end
end

function module.doOptions(arg)
    for optI, optN in ipairs(arg) do
        if optN:sub(1, 1) == "-" then
            local Arg = arg[optI + 1]
            local carg = (Arg and Arg or "-"):sub(1, 1) ~= "-" and Arg
            if carg then
                table_remove(arg, optI + 1)
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
        
    local thread = coroutine.create(mod)
    local success, result = coroutine.resume(thread, _ENV, ...)

    if not success then
        print(result)
        return
    end

    return result
end
local f = string.format
local io_open = io.open
local io_read = io.read
local ipairs = ipairs
local next = next
local print = print
local require = require
local select = select
local table_concat = table.concat

local modeMatch = "%s*%-*%s*([!@%$%?%*]*)"
local requireMatches = {
    "require%s*(%()(.-)[%),]"..modeMatch,
    "require%s*(['\"])([^\n]-)%1"..modeMatch,
    "require%s*%[(=*)%[(.-)%]%1%]"..modeMatch
}
local function sanitize(target)
    return target:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
end
local function unwrapStr(str)
    local start = select(2, str:find("^%[=*%[")) or select(2, str:find("^['\"]"))
    local end_ = str:find("%]=*%]$") or str:find("['\"]$")
    
    return str:sub((start or 0) + 1, (end_ or 0) - 1)
end

local packer = require("./SBPacker") -- $*
local options = require("./options") -- @*
local input
local output
local verbose
local function vprint(str, ...)
    if verbose then
        print("[INFO]:", f(str, ...))
    end
end

local function buildMod(modname, mode, fullpath)
    local modname = unwrapStr(modname)
    local modpath = fullpath..modname
    
    local ignore = mode:find("!")
    local isScript = mode:find("@")
    local isMod = mode:find("%$")
    local silent = mode:find("%?")
    local isDependency = mode:find("%*")
    local none = #mode == 0
            
    if packer:hasSourceContainer(modname) or ignore then
        return false, 2
    end
    
    local modF = io_open(modpath..".lua", "r") or io_open(modpath.."/init.lua", "r")
        
    if not modF then
        if not silent then
            print(f("[%s]: failed to find module '%s.lua' or '%s/init.lua'"), isDependency and "ERROR" or "WARNING", modpath, modpath)
        end
            
        if isDependency then
            return false, 1
        end
        
        return false, 0
    end
        
    local modsrc = modF:read("*a")
    if isMod then
        packer:addMod(modname, modsrc)
    elseif isScript or none then
        packer:addScript(modname, modsrc)
    end
    
    vprint("Added module %q", modname)
    modF:close()
            
    return true
end

local function checkForMods(fullpath, src)
    for _, matchstr in ipairs(requireMatches) do
        for _, modname, mode in src:gmatch(matchstr) do
            local success, msg = buildMod(modname, mode, fullpath)
            if not success and msg == 1 then
                return
            end
        end
    end
end

if not arg then
    print("Insert init file path:")
    input = io_read()
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
            print(table_concat(helpPage, "\n  "))
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
    if not arg[1] then
        print(table_concat(helpPage, "\n  "))
    end
    
    return
end

local inputF = io_open(input, "r")
if inputF then
    local src = inputF:read("*a")
    local fullpath = input:match(".*/") or "./"
    packer:onStart(src)
    
    checkForMods(fullpath, src)
else
    print("[ERROR]: File '"..input.."' not found")
    return
end

local output = output or "./sbbout.lua"
local outF = io_open(output, "w")
if outF then
    outF:write(packer:generate())
else
    print("[ERROR]: Unable to write to path '"..output.."'")
end