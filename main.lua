string.matchany = require("matchany")

local OP = {}

local function wrap(x, x_max)
    return x - math.floor(x/x_max)*x_max
end

local function uint_16(val)
    return wrap(val, 65536)
end

local function expr(e)
    return e
end

-- number type: 16 bit
-- RAM size: 65536
-- registers: A, M, X, Y

local r_RAM = {}
local m_RAM = {
    __index = function(tbl, i)
        if type(i) ~= "number" then
            error("Cannot access index "..i.." in memory: magic is not allowed.")
        end
        return rawget(r_RAM, uint_16(i)+1) or 0
    end,
    __newindex = function(tbl, i, v)
        if type(i) ~= "number" then
            error("Cannot set index "..i.." in memory: magic is not allowed.")
        end
        local index = uint_16(i)
        rawset(r_RAM, index+1, uint_16(v))
    end
}

local RAM = {}

setmetatable(RAM, m_RAM)

local r_REG = {
    a = 0,
    x = 0,
    y = 0,
}
local m_REG = {
    __index = function(tbl, i)
        if i == "m" then
            return RAM[r_REG.a]
        else
            if not rawget(r_REG, i) then
                error("Cannot access nonexistant register "..i..": magic is not allowed.")
            end
            return rawget(r_REG, i)
        end
    end,
    __newindex = function(tbl, i, v)
        -- print("SET REG", i, v)
        if i == "m" then
            RAM[r_REG.a] = v
        else
            if not rawget(r_REG, i) then
                error("Cannot create new register "..i..": magic is not allowed.")
            end
            -- print(uint_16(v))
            rawset(r_REG, i, uint_16(v))
        end
    end
}

local REG = {}
setmetatable(REG, m_REG)

local instructions = {}

function love.load()
    local patterns = {
        "%s- ([%w_]+) %s- ;",
        "%s- ([%w_]+) %s- ([%+%-]?g?[%uamxy_]+) %s- ;",
        "%s- ([%w_]+) %s- : %s- 3:(-?) ([%u%dgamxy_]+) %s- ;",
        "%s- ([%w_]+) %s- ([%+%-]?g?[%uamxy_]+) %s- : %s- 5:(%b{}) %s- ;?",
        "%s- ([%w_]+) %s- : %s- 5:(%b{}) %s- ;",
        "%s- ([%w_]+) %s- 6:(%b()) %s- ;",
        "%s- ([%w_]+) %s- ([%+%-]?g?[%uamxy_]+) %s- : %s- (-?) ([%u%damxy_]+) %s- ;",
        "%s",
        "([^\n]+)"
    }
    local comment = "#.-\n"

    local file = love.filesystem.read("main.zasm")
    file = string.gsub(file.."\n", comment, "")

    local globals = {}
        
    local debugFinal = ""

    local function parse(str, vars, macs, isLocal, instr)
        local variables = {}
        local macros = {}
        local instructions = instr or {}

        local labels = {}

        vars = vars or {}

        setmetatable(variables, {__index = function(tbl, i)
            return rawget(tbl, i) or vars[i] or globals[i]
        end})
        setmetatable(macros, {__index = macs or {}})

        function macros.DEFINE(name, val, block)
            if block then
                if #name:gsub("[%u_]+", "") > 0 then
                    error("Invalid DEFINE name: "..name)
                end
                if variables[name] or labels[name] then
                    error("DEFINE name taken: "..name)
                end
                macros[name] = function (...)
                    local args = {...}
                    local insert = block
                    for i = #args, 1, -1 do
                        insert = insert:gsub("%$"..i, args[i])
                    end
                    parse(insert, variables, macros, true, instructions)
                end
            else
                local realName = name:gsub("^[%+%-]?g?", "")
                -- print(realName)
                if #name:gsub("[%+%-]?g?[%u_]+", "") > 0 then
                    error("Invalid DEFINE name: "..name)
                end
                if macros[realName] or labels[name] then
                    error("DEFINE name taken: "..realName)
                end
                if type(val) ~= "number" then
                    error("Invalid DEFINE value: "..val[1].." (pointless define)")
                end
                local first = name:sub(1, 1)
                local second = name:sub(2, 2)
                if first == "g" or second == "g" or not isLocal then
                    -- print("global")
                    if first == "+" then
                        globals[realName] = uint_16(globals[realName] + val)
                    elseif first == "-" then
                        globals[realName] = uint_16(globals[realName] - val)
                    else
                        globals[realName] = uint_16(val)
                    end
                else
                    -- print("local")
                    if first == "+" then
                        variables[realName] = uint_16(variables[realName] + val)
                    elseif first == "-" then
                        variables[realName] = uint_16(variables[realName] - val)
                    else
                        variables[realName] = uint_16(val)
                    end
                end
            end
        end
    
        function macros.LABEL(name)
            if #name:gsub("[%u_]+", "") > 0 then
                error("Invalid LABEL name: "..name)
            end
            if macros[name] or variables[name] then
                error("LABEL name taken: "..name)
            end
            variables[name] = uint_16(#instructions)
        end

        for i, op, reg, negative, arg, block, macroargs in str:matchany(patterns) do
            if i == #patterns then
                error("Unknown match: \n\""..op..'"')
            end
            if not op then
                goto continue
            end
            if op == "LABEL" then
                local label
                if reg then
                    label = reg
                elseif macroargs then
                    local args = {}
                    for macroarg in macroargs:gsub("^%(", ""):gsub("%)$", ""):gmatch("[^,]+") do
                        args[#args+1] = macroarg:gsub("^%s*", ""):gsub("%s*$", "")
                    end
                    label = args[1]
                end
                labels[label] = {}
            end
            ::continue::
        end

        for i, op, reg, negative, arg, block, macroargs in str:matchany(patterns) do
            -- print(i, op, reg, negative, arg, block, macroargs)

            if not op then
                goto continue
            end

            if i == #patterns then
                error("Unknown match: \n\""..op..'"')
            end
    
            local isNegative = negative == "-"
    
            local val
            local isLabel = false
    
            if arg then
                if arg:match("^%d+$") then
                    val = uint_16(tonumber(negative..arg))
                elseif arg:match("^[%u_]+$") then
                    if labels[arg] then
                        isLabel = arg
                        if isNegative then
                            val = -1
                        else
                            val = 1
                        end
                    elseif variables[arg] then
                        if isNegative then
                            val = uint_16(-variables[arg])
                        else
                            val = variables[arg]
                        end
                    else
                        error("Define error: "..arg.." is not defined")
                    end
                elseif arg:match("^[amxy]$") then
                    if isNegative then
                        val = {arg, true}
                    else
                        val = {arg}
                    end
                else
                    error("Invalid argument: "..arg)
                end
            else
                val = 0
            end
    
            if macros[op] then
                if block then
                    macros[op](reg, nil, block:gsub("^{s*", ""):gsub("s*}$", ""))
                elseif macroargs then
                    local args = {}
                    for macroarg in macroargs:gsub("^%(", ""):gsub("%)$", ""):gmatch("[^,]+") do
                        args[#args+1] = macroarg:gsub("^%s*", ""):gsub("%s*$", "")
                    end
                    macros[op](unpack(args))
                else
                    macros[op](reg, val)
                end
            else
                if block then
                    error("Invalid instruction: argument must be a literal")
                end
                if not OP[op] then
                    error("Invalid instruction: "..op)
                end
    
                -- debugFinal = debugFinal .. op .. " " .. tostring(reg) .. ": " .. tostring(type(val) == "table" and val[1] or val) .. ";\n"
                local instruction = {OP[op], reg, val}
                if isLabel then
                    labels[isLabel][#labels[isLabel]+1] = instruction
                end
                instructions[#instructions+1] = instruction
            end
            ::continue::
        end
        for label, t in pairs(labels) do
            for _, instruction in ipairs(t) do
                -- print(unpack(instruction))
                instruction[3] = uint_16(variables[label] * instruction[3])
                -- print(unpack(instruction))
            end
        end
        return instructions
    end
    parse(file, nil, nil, nil, instructions)
    -- print(#instructions)
    -- print(debugFinal)
end

local index = 1

function OP.add(reg, val)
    REG[reg] = REG[reg] + val
end

function OP.sub(reg, val)
    REG[reg] = REG[reg] - val
end

function OP.mul(reg, val)
    REG[reg] = REG[reg] * val
end

function OP.div(reg, val)
    REG[reg] = REG[reg] / val
end

function OP.set(reg, val)
    REG[reg] = val
end

function OP.jmp(_, val)
    index = val
end

function OP.jeq(reg, val)
    if REG[reg] == 0 then
        index = val
    end
end

function OP.jnz(reg, val)
    if REG[reg] ~= 0 then
        index = val
    end
end

function OP.jgt(reg, val)
    if REG[reg] > 0 and REG[reg] < 0x7fff then
        index = val
    end
end

function OP.jge(reg, val)
    if REG[reg] >= 0 and REG[reg] < 0x7fff then
        index = val
    end
end

function OP.jlt(reg, val)
    if REG[reg] >= 0x8000 and REG[reg] <= 0xffff then
        index = val
    end
end

function OP.jle(reg, val)
    if REG[reg] >= 0x8000 and REG[reg] <= 0xffff or REG[reg] == 0 then
        index = val
    end
end

OP["break"] = function()
    return true
end

local pt_limit = ({
 --[[ 1 ]] 1, -- 60 Hz
 --[[ 2 ]] 10, -- 600 Hz
 --[[ 3 ]] 100, -- 6 KHz
 --[[ 4 ]] 500, -- 30 KHz
 --[[ 5 ]] 1000, -- 60 KHz
 --[[ 6 ]] 5000, -- 300 KHz
 --[[ 7 ]] 10000, -- 600 KHz
 --[[ 8 ]] 40000, -- 2.4 MHz
 --[[ 9 ]] 120000, -- 9.6 MHz
 --[[ 10 ]] 240000, -- 19.2 MHz
 --[[ 11 ]] 400000, -- 24 MHz
 --[[ 12 ]] 1200000, -- 96 MHz
 --[[ 13 ]] 16666667, -- 1 GHz
})[1]

function love.update()
    for i = 1, pt_limit, 1 do
        if index > #instructions then
            break
        end

        local func = instructions[index][1]
        local reg = instructions[index][2]
        local arg = instructions[index][3]
        local val
        if type(arg) == "table" then
            if arg[2] then
                val = -REG[arg[1]]
            else
                val = REG[arg[1]]
            end
        else
            val = arg
        end
        local ret = func(reg, val)

        -- print(index)

        index = index + 1

        if ret then
            break
        end
    end
end

function memdebug()
    local ret = 'FPS: '..love.timer.getFPS()..'\n'
    for key, value in pairs(r_REG) do
        ret = ret .. key .. ": " .. value .. "\n"
    end
    for key, value in pairs(r_RAM) do
        ret = ret .. "RAM-" .. (key-1) .. ": " .. value .. "\n"
    end
    return ret
end

function love.draw()
    love.graphics.print(memdebug(), 0, 0)
    love.graphics.scale(2, 2)
end