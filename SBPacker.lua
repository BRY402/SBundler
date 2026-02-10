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