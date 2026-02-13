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
    "%s*%-%-%[(=*)%[(.-)%]%1%]"
}
local contextMatch = "@contextdef:%s*([^\n]+)"

local function sanitize(target)
    return target:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
end
local function unwrapStr(str)
    local start = select(2, str:find("^%[=*%[")) or select(2, str:find("^['\"]"))
    local end_ = str:find("%]=*%]$") or str:find("['\"]$")
    
    return str:sub((start or 0) + 1, (end_ or 0) - 1)
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

local containerTypes = {
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
    
    local containerType
    for _, matchstr in ipairs(commentMatches) do
        if containerType then
            break
        end
        
        for _, content in modsrc:gmatch(matchstr) do
            containerType = content:match(contextMatch)
            
            if containerType then
                break
            end
        end
    end
    
    if containerType then
        containerTypes[containerType](modname, modsrc)
    else
        containerTypes.script(modname, modsrc)
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