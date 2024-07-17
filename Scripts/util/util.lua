local random = math.random
sm.MTUtil = sm.MTUtil or {}
dofile "profiler.lua"

-- deque class --
local deque = {
    new = function()
        return { front = 0, back = -1 }
    end,

    is_empty = function(dequeObject)
        return dequeObject.front > dequeObject.back
    end,

    front = function(dequeObject)
        return dequeObject[dequeObject.front]
    end,

    back = function(dequeObject)
        return dequeObject[dequeObject.back]
    end,

    push_front = function(dequeObject, value)
        dequeObject.front = dequeObject.front - 1
        dequeObject[dequeObject.front] = value
    end,

    pop_front = function(dequeObject)
        if dequeObject.front <= dequeObject.back then
            local result = dequeObject[dequeObject.front]
            dequeObject[dequeObject.front] = nil
            dequeObject.front = dequeObject.front + 1
            return result
        end
    end,

    push_back = function(dequeObject, value)
        dequeObject.back = dequeObject.back + 1
        dequeObject[dequeObject.back] = value
    end,

    pop_back = function(dequeObject)
        if dequeObject.front <= dequeObject.back then
            local result = dequeObject[dequeObject.back]
            dequeObject[dequeObject.back] = nil
            dequeObject.back = dequeObject.back - 1
            return result
        end
    end
}
sm.MTUtil.deque = deque

if not table.unpack then
    ---@diagnostic disable-next-line: deprecated
    table.unpack = unpack
end

function values(t)
    local valuesT = {}
    for i, v in ipairs(t) do
        valuesT[i] = v
    end
    local i = 0
    return function()
        i = i + 1; return valuesT[i]
    end
end

function table.contains(tbl, value)
    for _, v in ipairs(tbl) do
        if (v == value) then
            return true
        end
    end
    return false
end

function table.containsWithOut(tbl, value, out)
    for k, v in pairs(tbl) do
        if (v == value) then
            out[0] = k
            return true
        end
    end
    return false
end

function table.find(tbl, value)
    for k, v in ipairs(tbl) do
        if (v == value) then
            return k
        end
    end
    return nil
end

function table.afind(tbl, value) -- arbitrary find
    for k, v in pairs(tbl) do
        if (v == value) then
            return k
        end
    end
    return nil
end

function table.toString(tbl)
    local result = "{"
    for k, v in pairs(tbl) do
        -- Check the key type (ignore any numerical keys - assume its an array)
        if type(k) == "string" then
            result = result .. "[\"" .. k .. "\"]" .. "="
        end
        -- Check the value type
        if type(v) == "table" then
            result = result .. table_to_string(v)
        elseif type(v) == "boolean" then
            result = result .. tostring(v)
        else
            result = result .. "\"" .. v .. "\""
        end
        result = result .. ","
    end
    -- Remove leading commas from the result
    if result ~= "" then
        result = result:sub(1, result:len() - 1)
    end
    return result .. "}"
end

function table.removeValue(tbl, value)
    local index = table.find(tbl, value)
    if index == nil then return nil end
    return table.remove(tbl, index)
end

function table.length(tbl)
    local count = 0
    for _, _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

function table.getKeys(t)
    local keys = {}
    for key, _ in pairs(t) do
        table.insert(keys, key)
    end
    return keys
end

function table.lengthSumOfContainedElements(tbl)
    local total = 0
    for k, v in pairs(tbl) do
        total = total + table.length(v)
    end
    return total
end

function table.sumOfContainedElements(tbl)
    local sum = 0
    for k, v in pairs(tbl) do
        sum = sum + v
    end
    return sum
end

function table.copy(tbl)
    local newTable = {}
    for key, value in pairs(tbl) do
        newTable[key] = value
    end
    return newTable
end

function table.deepCopy(tbl)
    local newTable = {}
    for key, value in pairs(tbl) do
        if type(value) == "table" then
            value = table.deepCopy(value)
        end
        newTable[key] = value
    end
    return newTable
end

function table.copyTo(tbl, newTable)
    for key, value in pairs(tbl) do
        newTable[key] = value
    end
    return newTable
end

function table.deepCopyTo(tbl, newTable)
    for key, value in pairs(tbl) do
        if type(value) == "table" then
            value = table.deepCopy(value)
        end
        newTable[key] = value
    end
    return newTable
end

function table.appendTable(tbl, tblToAppend)
    for i = 1, #tblToAppend do
        tbl[#tbl + 1] = tblToAppend[i]
    end
    return tbl
end

function table.getKeysSortedByValue(tbl, sortFunction, validationFunction)
    if validationFunction == nil then validationFunction = function(val) return true end end
    local keys = {}
    for key, _ in pairs(tbl) do
        if (validationFunction(tbl[key])) then
            table.insert(keys, key)
        end
    end

    table.sort(keys, function(a, b)
        return sortFunction(tbl[a], tbl[b])
    end)

    return keys
end

printOld = printOld or print
formater = {}
local formater = formater
function formater.getFormatedForPrint(val, depth, maxTableLength, unrollTables, indentationDepth, recursedTables)
    indentationDepth = indentationDepth or 0
    indentationDepth = indentationDepth + 1
    depth = depth or 5
    depth = depth - 1
    recursedTables = recursedTables or {}
    if depth == -1 and type(val) == "table" then
        return "tbl"
    end
    if val == nil then
        return "nil"
    elseif type(val) == "number" then
        val = math.floor(val * 100 + 0.5) / 100
        return tostring(val)
    elseif type(val) == "table" then
        if depth == 0 then
            return "tbl"
        end
        if table.contains(recursedTables, val) then
            depth = 0
        end
        table.insert(recursedTables, val)
        local i = 1
        local str = "{"
        local count = 0
        maxTableLength = maxTableLength or 100
        unrollTables = unrollTables or false
        for key, value in pairs(val) do
            if count >= maxTableLength then
                str = str .. "..."
                break
            end
            count = count + 1
            if (#str > 1) then
                str = str .. ","
            end
            if unrollTables then
                str = str .. "\n"
                for i = 1, indentationDepth do
                    str = str .. "    "
                end
            elseif (#str > 1) then
                str = str .. " "
            end
            if (key == i) then
                i = i + 1
                str = str .. formater.getFormatedForPrint(value, depth, maxTableLength, unrollTables, indentationDepth, recursedTables)
            else
                str = str ..
                    "[" ..
                    formater.getFormatedForPrint(key, depth, maxTableLength, unrollTables, indentationDepth, recursedTables) ..
                    "] = " .. formater.getFormatedForPrint(value, depth, maxTableLength, unrollTables, indentationDepth, recursedTables)
            end
        end
        if unrollTables then
            str = str .. "\n"
            for i = 1, indentationDepth - 1 do
                str = str .. "    "
            end
        end
        return str .. "}"
        -- return depth
    elseif type(val) == "del" then
        return "del"
    elseif type(val) == "string" then
        return val
    elseif type(val) == "boolean" then
        if val then
            return "true"
        end
        return "false"
    elseif type(val) == "Shape" then
        return "{<Shape>, id = " .. formater.getFormatedForPrint(val:getId(), depth, maxTableLength, unrollTables, indentationDepth, recursedTables) .. "}"
    elseif type(val) == "Vec3" then
        return "Vec3 <" ..
            formater.getFormatedForPrint(val.x, depth, maxTableLength, unrollTables, indentationDepth, recursedTables) .. ", " ..
            formater.getFormatedForPrint(val.y, depth, maxTableLength, unrollTables, indentationDepth, recursedTables) .. ", " ..
            formater.getFormatedForPrint(val.z, depth, maxTableLength, unrollTables, indentationDepth, recursedTables) .. ">"
    elseif type(val) == "Color" then
        local str = "Color <" ..
            formater.getFormatedForPrint(val.r, depth, maxTableLength, unrollTables, indentationDepth, recursedTables) .. ", " ..
            formater.getFormatedForPrint(val.g, depth, maxTableLength, unrollTables, indentationDepth, recursedTables) .. ", " ..
            formater.getFormatedForPrint(val.b, depth, maxTableLength, unrollTables, indentationDepth, recursedTables)
        if val.a ~= 1 then
            str = str .. ", " .. formater.getFormatedForPrint(val.a, depth, maxTableLength, unrollTables, indentationDepth, recursedTables) .. ">"
        else
            str = str .. ">"
        end
        return str
    else
        local status, result = pcall(tostring, val)
        if status ~= true or result == nil or result == type(val) then -- if the tostring function failed or provides no useful information
            return type(val)
        end
        -- if the tostring function succeeded and provided useful information
        -- first, check if the result starts with the type of the value
        if result:sub(1, #type(val)) == type(val) then
            return result
        end
        return type(val) .. " <" .. result .. ">"
    end
end

function print(...)
    local strings = {}
    for i = 1, select("#", ...) do
        local val = select(i, ...)
        strings[#strings + 1] = formater.getFormatedForPrint(val)
    end
    printOld(table.concat(strings, " "))
    -- printOld(formater.getFormatedForPrint(val))
end

function advPrint(val, depth, maxTableLength, unrollTables)
    printOld(formater.getFormatedForPrint(val, depth, maxTableLength, unrollTables))
end

-- input the keys you want to be able to hash
function table.makeConstantKeysOnlyHash(keys)
    local unhashedLookUp = {}
    local hashedLookUp = {}
    for _, value in pairs(keys) do
        hashedLookUp[value] = #unhashedLookUp + 1
        unhashedLookUp[#unhashedLookUp + 1] = value
    end
    return { ["hashedLookUp"] = hashedLookUp, ["unhashedLookUp"] = unhashedLookUp, ["size"] = #unhashedLookUp, ["tables"] = {}, ["tableFills"] = {} }
end

function table.addToConstantKeysOnlyHash(hashData, key)
    if (hashData.hashedLookUp[key] ~= nil) then
        return hashData.hashedLookUp[key]
    end
    hashData.size = hashData.size + 1
    hashData.hashedLookUp[key] = hashData.size
    hashData.unhashedLookUp[hashData.size] = key
    for i = 1, #hashData.tables do
        if hashData.tables[i][hashData.size] == nil then
            hashData.tables[i][hashData.size] = hashData.tableFills[i]
        end
    end
    return hashData.size
end

function table.addBlankToConstantKeysOnlyHash(hashData)
    hashData.size = hashData.size + 1
    hashData.unhashedLookUp[hashData.size] = false
    for i = 1, #hashData.tables do
        if hashData.tables[i][hashData.size] == nil then
            hashData.tables[i][hashData.size] = hashData.tableFills[i]
        end
    end
    return hashData.size
end

function table.removeFromConstantKeysOnlyHash(hashData, key)
    if (hashData.hashedLookUp[key] ~= nil) then
        hashData.unhashedLookUp[hashData.hashedLookUp[key]] = "del"
        hashData.hashedLookUp[key] = nil
    end
end

function table.makeArrayForHash(hash, val)
    local tbl = table.makeArray(hash.size, val)
    hash.tables[#hash.tables + 1] = tbl
    hash.tableFills[#hash.tableFills + 1] = val or false
    return tbl
end

function table.hashArrayValues(hashData, tbl)
    local newTbl = {}
    for key, value in pairs(tbl) do
        local hashed = hashData.hashedLookUp[value]
        if hashed ~= nil then
            newTbl[key] = hashed
        end
    end
    return newTbl
end

function table.getMissingHashValues(hashData, tbl)
    local newTbl = {}
    for _, value in pairs(tbl) do
        if hashData.hashedLookUp[value] == nil then
            newTbl[#newTbl + 1] = value
        end
    end
    return newTbl
end

function table.makeArray(size, val)
    if val == nil then
        val = false
    end
    local tbl = {}
    for i = 1, size do
        tbl[i] = val
    end
    return tbl
end

function string.replace_char(pos, str, r)
    return str:sub(1, pos - 1) .. r .. str:sub(pos + 1)
end

local uuidIndex = uuidIndex or 0
function string.uuid()
    --     local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    --     return string.gsub(template, '[xy]', function(c)
    --         local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
    --         return string.format('%x', v)
    --     end)
    
    uuidIndex = uuidIndex + 1
    return uuidIndex;
end

function string.vecToString(vec, sep)
    if sep == nil then
        sep = ","
    end
    return (
        tostring(math.floor(vec.x)) .. sep ..
        tostring(math.floor(vec.y)) .. sep ..
        tostring(math.floor(vec.z))
    )
end

function string.stringToVec(str, sep)
    if sep == nil then
        sep = ","
    end
    local comps = string.split(str, sep)
    return sm.vec3.new(
        tonumber(comps[1]),
        tonumber(comps[2]),
        tonumber(comps[3])
    )
end

function string.split(inputstr, sep)
    sep=sep or '%s'
    local t={}
    for field,s in string.gmatch(inputstr, "([^"..sep.."]*)("..sep.."?)") do
        table.insert(t,field)
        if s=="" then
            return t
        end
    end
end

function sm.MTUtil.getOffset(rot)
    local xAxisSimple = rot.xAxis.x + rot.xAxis.y * 2 + rot.xAxis.z * 3
	local zAxisSimple = rot.zAxis.x + rot.zAxis.y * 2 + rot.zAxis.z * 3
	
	local offset = sm.vec3.new(0,0,0)
	
	if  (zAxisSimple ==  2 and (xAxisSimple == -1 or xAxisSimple == -3)) or
		(zAxisSimple ==  3 and (xAxisSimple ==  2 or xAxisSimple == -1)) or
		(zAxisSimple == -1 and (xAxisSimple ~= 1 and xAxisSimple ~= -1)) or
		(zAxisSimple == -2 and (xAxisSimple ==  3 or xAxisSimple == -1)) or
		(zAxisSimple == -3 and (xAxisSimple == -1 or xAxisSimple == -2)) then
			offset.x = -1
	end
	
	if  (zAxisSimple ==  1 and (xAxisSimple ==  3 or xAxisSimple == -2)) or
		(zAxisSimple ==  3 and (xAxisSimple == -1 or xAxisSimple == -2)) or
		(zAxisSimple == -1 and (xAxisSimple == -2 or xAxisSimple == -3)) or
		(zAxisSimple == -2 and (xAxisSimple ~= 2 and xAxisSimple ~= -2)) or
		(zAxisSimple == -3 and (xAxisSimple ==  1 or xAxisSimple == -2)) then
			offset.y = -1 
	end                   
	                      
	if  (zAxisSimple ==  1 and (xAxisSimple == -2 or xAxisSimple == -3)) or
		(zAxisSimple ==  2 and (xAxisSimple ==  1 or xAxisSimple == -3)) or
		(zAxisSimple == -1 and (xAxisSimple ==  2 or xAxisSimple == -3)) or
		(zAxisSimple == -2 and (xAxisSimple == -1 or xAxisSimple == -3)) or
		(zAxisSimple == -3 and (xAxisSimple ~= 3 and xAxisSimple ~= -3)) then
			offset.z = -1
	end

    return offset
end