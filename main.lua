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

local videoChanges = {}
local m_RAM = {
    __index = function(tbl, i)
        if type(i) ~= "number" then
            error("Cannot access index "..i.." in memory: magic is not allowed.")
        end
        return rawget(tbl, uint_16(i)+1) or 0
    end,
    __newindex = function(tbl, i, v)
        if type(i) ~= "number" then
            error("Cannot set index "..i.." in memory: magic is not allowed.")
        end
        rawset(tbl, uint_16(i)+1, uint_16(v))
    end
}

local RAM = {}

setmetatable(RAM, m_RAM)

local m_REG = {
    __index = function(tbl, i)
        if i == "m" then
            return RAM[tbl.a]
        else
            if not rawget(tbl, i) then
                error("Cannot access nonexistant register "..i..": magic is not allowed.")
            end
            return rawget(tbl, i)
        end
    end,
    __newindex = function(tbl, i, v)
        if i == "m" then
            RAM[tbl.a] = v
        else
            if not rawget(tbl, i) then
                error("Cannot create new register "..i..": magic is not allowed.")
            end
            rawset(tbl, i, uint_16(v))
        end
    end
}

local REG = {
    a = 0,
    x = 0,
    y = 0,
}
setmetatable(REG, m_REG)

REG.x = 3
REG.y = -25

local instructions = {}

function love.load()
    local pattern = "%s-([%w_]+)%s-([%uamxy_]*)%s-(:?)%s-(-?)([%u%damxy_]*)%s-([;\n])"
    local comment = "#.-\n"

    local file = love.filesystem.read("main.zasm")
    file = string.gsub(file.."\n", comment, "")

    local macros = {}
    local variables = {}

    function macros.DEFINE(name, val)
        if #name:gsub("[%u_]+", "") > 0 then
            error("Invalid DEFINE name: "..name)
        end
        if type(val) ~= "number" then
            error("Invalid DEFINE value: "..val[1].." (pointless define)")
        end
        variables[name] = uint_16(val)
    end

    function macros.LABEL(name)
        if #name:gsub("[%u_]+", "") > 0 then
            error("Invalid LABEL name: "..name)
        end
        variables[name] = uint_16(#instructions)
    end

    for op, reg, swap, negative, arg, lineEnder in file:gmatch(pattern) do
        local isNegative = negative == "-"

        if swap == "" then
            reg = arg
            arg = ""
        end

        local val

        if arg:match("^%d+$") then
            if isNegative then
                val = uint_16(-tonumber(arg))
            else
                val = uint_16(tonumber(arg))
            end
        elseif arg:match("^[%u_]+$") then
            if isNegative then
                val = uint_16(-variables[arg])
            else
                val = variables[arg]
            end
        elseif arg:match("^[amxy]$") then
            if isNegative then
                val = {arg, true}
            else
                val = {arg}
            end
        elseif arg == "" then
            val = 0
        else
            error("Invalid argument: "..arg)
        end

        print(op.." '"..reg.."': "..tostring(val))
        if macros[op] then
            macros[op](reg, val)
        else
            if not OP[op] then
                error("Invalid instruction: "..op)
            end

            instructions[#instructions+1] = {OP[op], reg, val}
        end
    end
    local invalid = (file:gsub(pattern, ""):gsub("%s", ""))
    if #invalid > 0 then
        error("Invalid characters: "..invalid)
    end
    print(#instructions)
end

local pt_limit = 1000

local index = 1

function OP.add(reg, val)
    REG[reg] = REG[reg] + val
end

function OP.sub(reg, val)
    REG[reg] = REG[reg] - val
end

function OP.set(reg, val)
    REG[reg] = val
end

function OP.goto(_, val)
    index = val
end

OP["break"] = function()
    return true
end

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

        index = index + 1

        if ret then
            break
        end
    end
end

function memdebug()
    local ret = ''
    for key, value in pairs(REG) do
        ret = ret .. key .. ": " .. value .. "\n"
    end
    for key, value in pairs(RAM) do
        ret = ret .. "RAM-" .. (key-1) .. ": " .. value .. "\n"
    end
    return ret
end

function love.draw()
    love.graphics.print(memdebug(), 0, 0)
    love.graphics.scale(2, 2)
end