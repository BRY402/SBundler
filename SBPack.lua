-- @contextdef: module
local error = error
local f = string.format
local next = next
local table_concat = table.concat
local tostring = tostring
local type = type

local containerObj = {
    sources = {},
    
    newSource = function(self, Name, Source)
        if type(Source) ~= "string" then
            error("Invalid script source, expected string", 2)
        end
        
        self.sources[tostring(Name)] = f([[
sb_package.preload[%q] = function(_ENV, ...)
    %s
end
]], tostring(Name), Source)
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
    if type(code) ~= "string" then
        error("Invalid initialization source, expected string", 2)
    end
    
    SBPack.sources.init = code
end

function SBPack:beforeBuild(code)
    if type(code) ~= "string" then
        error("Invalid source for start of build, expected string", 2)
    end
    
    SBPack.sources.beforeBuild = code
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
    if setfenv then
        setfenv(mod, _ENV)
    end

    return mod(_ENV, ...)]], Source))
end

function SBPack:newScript(scriptname, Source)
    scriptContainer:newSource(scriptname, f([[
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

    return result]], Source))
end

function SBPack:removeMod(modname)
    modContainer:removeSource(modname)
end

function SBPack:removeScript(scriptname)
    scriptContainer:removeSource(scriptname)
end

function SBPack:hasSource(name)
    for _, container in next, self.containers do
        if container[tostring(name)] ~= nil then
            return true
        end
    end
end


return SBPack