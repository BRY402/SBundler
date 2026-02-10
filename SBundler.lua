local error = error
local f = string.format
local next = next
local table_concat = table.concat
local tostring = tostring
local type = type

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
        [[
local coroutine = coroutine
local package
local print = print

local require = (function(_ENV)
    local unpack = unpack or table.unpack

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
            loaded[modname] = require(modname) --!
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
        
    local thread = coroutine.create(mod)
    local success, result = coroutine.resume(thread, _ENV, ...)

    if not success then
        print(result)
        return
    end

    return result
end]], modname, modsrc)
    end
    
    src[#src + 1] = SBundler.init
    
    return table_concat(src, "\n")
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