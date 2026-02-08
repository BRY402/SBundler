local f = string.format
local io_open = io.open
local io_read = io.read
local ipairs = ipairs
local next = next
local print = print
local require = require
local table_concat = table.concat

local requireMatches = {
    "require%s*(%()(.-)[%),]%s*%-*%s*(!?)",
    "require%s*(['\"])(.-)%1%s*%-*%s*(!?)",
    "require%s*%[(=*)%[(.-)%]%1%]%s*%-*%s*(!?)"
}
local function sanitize(target)
    return target:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
end
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
        for _, modname, ignore in src:gmatch(matchstr) do
            local modname = unwrapStr(modname)
            local mpath = fpath..modname
            
            if not SBundler:hasMod(modname) and (#ignore == 0) then
                local modF = io_open(mpath..".lua", "r") or io.open(mpath.."/init.lua", "r")
                
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
    local fpath = input:match(".*/") or "./"
    SBundler:onStart(src)
    
    checkForMods(fpath, src)
else
    print("[ERROR]: File '"..input.."' not found")
    return
end

local output = output or "./sbbout.lua"
local outF = io_open(output, "w")
if outF then
    outF:write(SBundler:generate())
else
    print("[ERROR]: Unable to write to path '"..output.."'")
end