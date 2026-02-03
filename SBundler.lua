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
        "local _ENV = _ENV or getfenv()",
        [[
local require = (function()
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
end)()
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