sm.MTFastLogic = sm.MTFastLogic or {}
sm.MTFastLogic.CompressionUtil = sm.MTFastLogic.CompressionUtil or {}

dofile "LibDeflate.lua"

sm.MTFastLogic.CompressionUtil.numberToRotation = {
    [1] = { sm.vec3.new(1, 0, 0), sm.vec3.new(0, 0, 1), sm.vec3.new(0, -1, 0) },
    [2] = { sm.vec3.new(1, 0, 0), sm.vec3.new(0, -1, 0), sm.vec3.new(0, 0, -1) },
    [3] = { sm.vec3.new(0, 1, 0), sm.vec3.new(0, 0, -1), sm.vec3.new(-1, 0, 0) },
    [4] = { sm.vec3.new(0, 1, 0), sm.vec3.new(1, 0, 0), sm.vec3.new(0, 0, -1) },
    [5] = { sm.vec3.new(0, 0, 1), sm.vec3.new(0, 1, 0), sm.vec3.new(-1, 0, 0) },
    [6] = { sm.vec3.new(0, 0, 1), sm.vec3.new(-1, 0, 0), sm.vec3.new(0, -1, 0) },
    [7] = { sm.vec3.new(0, -1, 0), sm.vec3.new(0, 0, -1), sm.vec3.new(1, 0, 0) },
    [8] = { sm.vec3.new(0, 0, -1), sm.vec3.new(0, 1, 0), sm.vec3.new(1, 0, 0) },
    [9] = { sm.vec3.new(0, 1, 0), sm.vec3.new(0, 0, 1), sm.vec3.new(1, 0, 0) },
    [10] = { sm.vec3.new(0, 0, 1), sm.vec3.new(0, -1, 0), sm.vec3.new(1, 0, 0) },
    [11] = { sm.vec3.new(-1, 0, 0), sm.vec3.new(0, 0, 1), sm.vec3.new(0, 1, 0) },
    [12] = { sm.vec3.new(0, 0, -1), sm.vec3.new(-1, 0, 0), sm.vec3.new(0, 1, 0) },
    [13] = { sm.vec3.new(1, 0, 0), sm.vec3.new(0, 0, -1), sm.vec3.new(0, 1, 0) },
    [14] = { sm.vec3.new(0, 0, 1), sm.vec3.new(1, 0, 0), sm.vec3.new(0, 1, 0) },
    [15] = { sm.vec3.new(-1, 0, 0), sm.vec3.new(0, -1, 0), sm.vec3.new(0, 0, 1) },
    [16] = { sm.vec3.new(0, -1, 0), sm.vec3.new(1, 0, 0), sm.vec3.new(0, 0, 1) },
    [17] = { sm.vec3.new(1, 0, 0), sm.vec3.new(0, 1, 0), sm.vec3.new(0, 0, 1) },
    [18] = { sm.vec3.new(0, 1, 0), sm.vec3.new(-1, 0, 0), sm.vec3.new(0, 0, 1) },
    [19] = { sm.vec3.new(0, -1, 0), sm.vec3.new(0, 0, 1), sm.vec3.new(-1, 0, 0) },
    [20] = { sm.vec3.new(0, 0, -1), sm.vec3.new(0, -1, 0), sm.vec3.new(-1, 0, 0) },
    [21] = { sm.vec3.new(-1, 0, 0), sm.vec3.new(0, 0, -1), sm.vec3.new(0, -1, 0) },
    [22] = { sm.vec3.new(0, 0, -1), sm.vec3.new(1, 0, 0), sm.vec3.new(0, -1, 0) },
    [23] = { sm.vec3.new(-1, 0, 0), sm.vec3.new(0, 1, 0), sm.vec3.new(0, 0, -1) },
    [24] = { sm.vec3.new(0, -1, 0), sm.vec3.new(-1, 0, 0), sm.vec3.new(0, 0, -1) },
}

sm.MTFastLogic.CompressionUtil.rotationToNumber = {
    ["1000-10"] = 1,
    ["10000-1"] = 2,
    ["010-100"] = 3,
    ["01000-1"] = 4,
    ["001-100"] = 5,
    ["0010-10"] = 6,
    ["0-10100"] = 7,
    ["00-1100"] = 8,
    ["010100"] = 9,
    ["001100"] = 10,
    ["-100010"] = 11,
    ["00-1010"] = 12,
    ["100010"] = 13,
    ["001010"] = 14,
    ["-100001"] = 15,
    ["0-10001"] = 16,
    ["100001"] = 17,
    ["010001"] = 18,
    ["0-10-100"] = 19,
    ["00-1-100"] = 20,
    ["-1000-10"] = 21,
    ["00-10-10"] = 22,
    ["-10000-1"] = 23,
    ["0-1000-1"] = 24,
}

sm.MTFastLogic.CompressionUtil.typeToNumber = {
    andBlocks = 0,
    orBlocks = 1,
    xorBlocks = 2,
    nandBlocks = 3,
    norBlocks = 4,
    xnorBlocks = 5,
}

sm.MTFastLogic.CompressionUtil.numberToType = {
    [0] = "andBlocks",
    [1] = "orBlocks",
    [2] = "xorBlocks",
    [3] = "nandBlocks",
    [4] = "norBlocks",
    [5] = "xnorBlocks",
}


-- makes a table into a string for compression.This works on table onlu if they are very simple (not looping refrences and data types other than string, number, and table)
function sm.MTFastLogic.CompressionUtil.tableToString(table)
    local str = ""
    local i = 1
    for k, v in pairs(table) do
        local needsKey = k == i
        if type(v) == "table" then
            v = "{" .. sm.MTFastLogic.CompressionUtil.tableToString(v) .. "}"
        elseif type(v) ~= "string" then
            v = tostring(v)
        else
            if tonumber(v) ~= nil then
                v = v .. "'"
            end
        end
        if type(k) ~= "string" then
            k = tostring(k)
        else
            if tonumber(k) ~= nil then
                k = k .. "'"
            end
        end
        if string.sub(str, -1, -1) ~= "}" and string.sub(str, -1, -1) ~= "'" and string.sub(v, 1, 1) ~= "{" and str ~= "" then
            str = str .. "|"
        end
        if needsKey then
            i = i + 1
            str = str .. v
        else
            str = str .. k .. "]" .. v
        end
    end
    -- if string.sub(str, -1, -1) == "}" then
    --     str = string.sub(str, 1, -2)
    -- end
    return str --string.sub(str, 2, -1)
end

-- undoes tableToString to got from a compressed string to a table
function sm.MTFastLogic.CompressionUtil.stringToTable(str)
    local tbl = {}
    local chunk = ""
    local gettingTableString = false
    local key = 1
    local isString = false
    local countKey = true
    local depth = 0
    local stringIndex = 1
    for c in str:gmatch "." do
        ::again::
        if gettingTableString then
            if c == "{" then
                depth = depth + 1
                chunk = chunk .. c
            elseif c == "}" then
                if depth > 0 then
                    depth = depth - 1
                    chunk = chunk .. c
                else
                    chunk = sm.MTFastLogic.CompressionUtil.stringToTable(chunk)
                    gettingTableString = false
                    c = "|"
                    goto again
                end
            else
                chunk = chunk .. c
            end
        else
            local endChunk = false
            if c == "|" then
                endChunk = true
            elseif c == "{" then
                if chunk ~= "" then
                    endChunk = true
                end
                gettingTableString = true
            elseif c == "}" then
                endChunk = true
            elseif c == "]" then
                if chunk == "" then
                    key = key - 1
                    chunk = tbl[key]
                    tbl[key] = nil
                    if tonumber(chunk) ~= nil then
                        chunk = tonumber(chunk)
                    end
                end
                key = chunk
                chunk = ""
                countKey = false
            elseif c == "'" then
                isString = true
                endChunk = true
            else
                chunk = chunk .. c
            end

            if endChunk then
                if tonumber(chunk) ~= nil and not isString then
                    chunk = tonumber(chunk)
                end
                isString = false
                if countKey ~= nil then
                    if chunk ~= "" then
                        tbl[key] = chunk
                    end
                    if c == "}" then
                        tbl = { tbl }
                    end
                    if chunk ~= "" then
                        if countKey == true then
                            key = key + 1
                        else
                            countKey = nil
                        end
                    end
                    chunk = ""
                end
            end
        end
        if stringIndex == #str then
            if gettingTableString then
                chunk = sm.MTFastLogic.CompressionUtil.stringToTable(chunk)
                gettingTableString = false
            end
            c = "|"
            stringIndex = stringIndex + 1
            goto again
        end
        stringIndex = stringIndex + 1
    end
    return tbl
end

-- faster than tableToString but only works on 1d arrays of numbers
function sm.MTFastLogic.CompressionUtil.arrayToString(data)
    local str = ""
    for i = 1, #data do
        if #str > 0 then str = str .. "," end
        str = str .. tostring(data[i] - (data[i-1] or 0))
    end
    return str
end

-- faster than stringToTable but only works on strings made with arrayToString
function sm.MTFastLogic.CompressionUtil.stringToArray(str)
    local data = {}
    for c in str:gmatch "[-%d]%d*" do
        data[#data+1] = tonumber(c) + (data[#data] or 0)
    end
    return data
end

-- faster than tableToString but only works on 1d hashTables allowing numbers and strings
function sm.MTFastLogic.CompressionUtil.hashToString(data)
    local str = ""
    for k, v in pairs(data) do
        if #str > 0 then str = str end
        if type(k) == "number" then
            k = "'" .. tostring(k)
        else
            k = ":" .. k
        end
        if type(v) == "number" then
            v = "'" .. tostring(v)
        else
            v = ":" .. v
        end
        str = str .. k .. v
    end
    return str
end

-- faster than stringToTable but only works on strings made with hashToString
function sm.MTFastLogic.CompressionUtil.stringToHash(str)
    local data = {}
    local key = nil
    for c in str:gmatch "[']?[%a%d]+" do
        if string.sub(c, 1, 1) == "'" then
            c = tonumber(string.sub(c, 2, #c))
        end
        if key == nil then
            key = c
        else
            data[key] = c
            key = nil
        end
    end
    return data
end

local binToGoofyEncoding = {
    ["00000"] = "a",
    ["00001"] = "b",
    ["00010"] = "c",
    ["00011"] = "d",
    ["00100"] = "e",
    ["00101"] = "f",
    ["00110"] = "g",
    ["00111"] = "h",
    ["01000"] = "i",
    ["01001"] = "j",
    ["01010"] = "k",
    ["01011"] = "l",
    ["01100"] = "m",
    ["01101"] = "n",
    ["01110"] = "o",
    ["01111"] = "p",
    ["10000"] = "q",
    ["10001"] = "r",
    ["10010"] = "s",
    ["10011"] = "t",
    ["10100"] = "u",
    ["10101"] = "v",
    ["10110"] = "w",
    ["10111"] = "x",
    ["11000"] = "y",
    ["11001"] = "z",
    ["11010"] = "A",
    ["11011"] = "B",
    ["11100"] = "C",
    ["11101"] = "D",
    ["11110"] = "E",
    ["11111"] = "F",
    ["0000"] = "G",
    ["0001"] = "H",
    ["0010"] = "I",
    ["0011"] = "J",
    ["0100"] = "K",
    ["0101"] = "L",
    ["0110"] = "M",
    ["0111"] = "N",
    ["1000"] = "O",
    ["1001"] = "P",
    ["1010"] = "Q",
    ["1011"] = "R",
    ["1100"] = "S",
    ["1101"] = "T",
    ["1110"] = "U",
    ["1111"] = "V",
    ["000"] = "W",
    ["001"] = "X",
    ["010"] = "Y",
    ["011"] = "Z",
    ["100"] = "0",
    ["101"] = "1",
    ["110"] = "2",
    ["111"] = "3",
    ["00"] = "4",
    ["01"] = "5",
    ["10"] = "6",
    ["11"] = "7",
    ["0"] = "8",
    ["1"] = "9",
}

local goofyToBinaryEncoding = {}
for k,v in pairs(binToGoofyEncoding) do
    goofyToBinaryEncoding[v] = k
end

local function goofyToBinary(goofy)
    local binary = ""
    for c in goofy:gmatch "." do
        binary = binary .. goofyToBinaryEncoding[c]
    end
    return binary
end

local function binaryToGoofy(binary)
    local goofy = ""
    for i = 1, #binary, 5 do
        goofy = goofy .. binToGoofyEncoding[string.sub(binary, i, i+4)]
    end
    return goofy
end

function sm.MTFastLogic.CompressionUtil.binHashToGoofy(data)
    local output = {}
    for k, v in pairs(data) do
        output[binaryToGoofy(k)] = binaryToGoofy(v)
    end
    return output
end

function sm.MTFastLogic.CompressionUtil.goofyToBinHash(data)
    local output = {}
    for k, v in pairs(data) do
        output[goofyToBinary(k)] = goofyToBinary(v)
    end
    return output
end