local f = string.format
local requireMatches = {
    "require%s*%((.-)[%),]",
    "require%s*['\"](.-)['\"]",
    "require%s*%[=*%[(.-)%]=*%]"
}

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
        local success = false
        for modname in src:gmatch(matchstr) do
            local modname = string.sub(modname, 2, -2)
            
            if not SBundler:hasMod(modname) then
                local modF = io.open(fpath..modname..".lua", "r")
                
                if modF then
                    local modsrc = modF:read("*a")
                    SBundler:addMod(modname, modsrc)

                    vprint("Added module %q", modname)
                    checkForMods(fpath, modsrc)
                else
                    print("[ERROR]: failed to read file '"..fpath..modname..".lua'")
                end
            end
        end
        
        if success then
            break
        end
    end
end

if not arg then
    print("Insert init file path:")
    input = io.read()
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
            print(table.concat(helpPage, "\n  "))
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
    print(table.concat(helpPage, "\n  "))
    return
end

local inputF = io.open(input, "r")
if inputF then
    local src = inputF:read("*a")
    local fpath = input:match(".*/")
    SBundler:onStart(src)
    
    checkForMods(fpath, src)
else
    print("[ERROR]: File not found")
end

if not output then
    local outF = io.open("./sbbout.lua", "w")
    if outF then
        outF:write(SBundler:generate())
    else
        print("Unable to write to path './sbbout.lua'")
    end
    
    return
end

local outF = io.open(output, "w")
if outF then
    outF:write(SBundler:generate())
else
    print("Unable to write to path '"..output.."'")
end
