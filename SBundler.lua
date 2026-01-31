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


local function handleRequire(match)
    return f("Module.mods[%s](%s)", match, match)
end
function SBundler:generate()
    local src = {
        "local Module = {mods = {}, loaded = {}}",
        "local unpack = unpack or table.unpack",
        [[
if not table.copy then
    table = setmetatable({
        copy = function(table)
            local out = {}
            for k, v in next, table do
                out[k] = v
            end

            return out
        end
    }, {__index = table})
end
]],
        "local _ENV = _ENV or getfenv()",
        [[

local loadmod = require
local function require(modname, args)
    local mod = Module.mods[modname]
    if mod then
        return mod(modname, unpack(type(args) == "table" and args or {}))
    end

    return loadmod(modname)
end
]],
    }
    
    for modname, modsrc in next, SBundler.modules do
        src[#src + 1] = ([[
Module.mods[modname] = function(...)
    local value = Module.loaded[modname]
    if value then
        return value
    end

    local _ENV = table.copy(_ENV)
    local function mod(_ENV, ...)
%s
    end
    if setfenv then
        setfenv(mod, _ENV)
    end
        
    Module.loaded[modname] = mod(_ENV, ...)
end]])
        :gsub("modname", f("%q", modname))
        :format(modsrc)
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