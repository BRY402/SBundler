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

local NLS = NLS or function()
    print("NLS is not supported in this script builder")
end

sb_package.preload["./options"] = function(_ENV, ...)
        local function mod(_ENV, ...)
-- @contextdef: script
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
    
    local thread = coroutine.create(setfenv and setfenv(mod, _ENV) or mod)
    local success, result = coroutine.resume(thread, _ENV, ...)

    if not success then
        print(result)
        return
    end

    return result
end

sb_package.preload["./SBPack"] = function(_ENV, ...)
        local function mod(_ENV, ...)
-- @contextdef: module
local error = error
local f = string.format
local next = next
local table_concat = table.concat
local tostring = tostring
local type = type

local function assertString(value, failmsg)
    if type(value) ~= "string" then
        error(failmsg, 2)
    end
    
    return value
end

local containerObj = {
    sources = {},
    
    newSource = function(self, Name, Source)
        self.sources[tostring(Name)] = f([[
sb_package.preload[%q] = function(_ENV, ...)
    %s
end
]], tostring(Name), assertString(Source, "Invalid container source, expected string"))
    end,
    
    removeSource = function(self, Name)
        self.sources[tostring(Name)] = nil
    end
}
containerObj.__index = containerObj

local function newContainer()
    local container = setmetatable({}, containerObj)
    container.sources = {}
    
    return container
end

local SBPack = {
    sources = {
        init = "",
        beforeBuild = ""
    },
    containers = {}
}


function SBPack:setInit(code)
    SBPack.sources.init = assertString(code, "Invalid initialization source, expected string")
end

function SBPack:beforeBuild(code)
    SBPack.sources.beforeBuild = assertString(code, "Invalid source for start of build, expected string")
end

function SBPack:createContainer(Name)
    local Name = tostring(Name)
    local container = self.containers[Name] or newContainer()
    self.containers[Name] = container
    
    return container
end

function SBPack:deleteContainer(Name)
    self.containers[tostring(Name)] = nil
end


function SBPack:clear(containerName)
    if not containerName then
        for i, _ in next, self.containers do
            self.containers[i] = {}
        end
        
        return
    end
    
    if self.containers[tostring(containerName)] then
        self.containers[tostring(containerName)] = {}
    end
end

function SBPack:generate()
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
        SBPack.sources.beforeBuild
    }
    
    for _, container in next, SBPack.containers do
        for _, source in next, container.sources do
            src[#src + 1] = source
        end
    end
    
    src[#src + 1] = SBPack.sources.init
    
    return table_concat(src, "\n")
end

local modContainer = SBPack:createContainer("modules")
local scriptContainer = SBPack:createContainer("scripts")

function SBPack:newMod(modname, Source)
    modContainer:newSource(modname, f([[
    local function mod(_ENV, ...)
%s
    end
    return (setfenv and setfenv(mod, _ENV) or mod)(_ENV, ...)]], Source))
end

function SBPack:newScript(scriptname, Source)
    scriptContainer:newSource(scriptname, f([[
    local function mod(_ENV, ...)
%s
    end
    
    local thread = coroutine.create(setfenv and setfenv(mod, _ENV) or mod)
    local success, result = coroutine.resume(thread, _ENV, ...)

    if not success then
        print(result)
        return
    end

    return result]], Source))
end

function SBPack:removeMod(modname)
    modContainer:removeSource(modname)
end

function SBPack:removeScript(scriptname)
    scriptContainer:removeSource(scriptname)
end

function SBPack:hasSource(Name)
    for _, container in next, self.containers do
        if container[tostring(Name)] ~= nil then
            return true
        end
    end
end


return SBPack
    end
    return (setfenv and setfenv(mod, _ENV) or mod)(_ENV, ...)
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

local modeMatch = "%s*%-*%s*([!%?%*]?)"
local requireMatches = {
    "require%s*(%()(.-)[%),]"..modeMatch,
    "require%s*(['\"])([^\n]-)%1"..modeMatch,
    "require%s*%[(=*)%[(.-)%]%1%]"..modeMatch
}
local commentMatches = {
    "%s*(%-%-)%s*([^\n]+)",
    "%s*%-%-%s*%[(=*)%[(.-)%]%1%]"
}
local contextMatch = "@contextdef:%s*([^\n]+)"

local function sanitize(target)
    return target:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
end

local function unwrapStr(str)
    return select(2, str:match("([\"'])([^\n]*)%1")) or select(2, str:match("%[(=*)%[(.-)%]%1%]")) or str
end

local packer = require("./SBPack") -- *
local options = require("./options") -- *
local input
local output
local verbose
local function vprint(str, ...)
    if verbose then
        print("[INFO]:", f(str, ...))
    end
end

local lsContainer = packer:createContainer("localscript")
packer:beforeBuild([[
local NLS = NLS or function()
    print("NLS is not supported in this script builder")
end
]])

local containers = {
    module = function(modname, source)
        packer:newMod(modname, source)
    end,
    
    script = function(scriptName, source)
        packer:newScript(scriptName, source)
    end,
    
    localscript = function(name, source)
        lsContainer:newSource(name, f([[
    NLS(%q, [==[%s]==])
]], name, source))
    end
}

local function getContext(src)
    for _, matchstr in ipairs(commentMatches) do
        for _, content in src:gmatch(matchstr) do
            local containerType = content:match(contextMatch)
            
            if containerType then
                return containerType
            end
        end
    end
end

local checkForMods
local function buildMod(modname, mode, fullpath)
    local modname = unwrapStr(modname)
    local modpath = fullpath..modname
    
    local ignore = mode == "!"
    local silent = mode == "?"
    local isDependency = mode == "*"
            
    if packer:hasSource(modname) or ignore then
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
    
    local srcContext = getContext(modsrc)
    if srcContext then
        containers[srcContext](modname, modsrc)
    else
        containers.script(modname, modsrc)
    end
    
    vprint("Added module %q", modname)
    modF:close()
    
    return checkForMods(fullpath, modsrc)
end

function checkForMods(fullpath, src)
    for _, matchstr in ipairs(requireMatches) do
        for _, modname, mode in src:gmatch(matchstr) do
            local success, msg = buildMod(modname, mode, fullpath)
            
            if not success and msg == 1 then
                return false, 1
            end
        end
    end
    
    return true
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

if ... and ... ~= arg[1] then -- required as a module check
    return {
        buildMod = buildMod,
        checkForMods = checkForMods,
        containers = containers,
        packer = packer
    }
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
    packer:setInit(src)
    
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