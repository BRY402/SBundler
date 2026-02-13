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
        preBuild = ""
    },
    containers = {}
}


function SBPack:setInit(code)
    SBPack.sources.init = assertString(code, "Invalid initialization source, expected string")
end

function SBPack:setPreBuild(code)
    SBPack.sources.preBuild = assertString(code, "Invalid source for start of build, expected string")
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
        SBPack.sources.preBuild
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