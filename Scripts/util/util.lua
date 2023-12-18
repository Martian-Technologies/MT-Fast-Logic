-- deque class --
deque = {}
if true then
    function deque.new()
        return { front = 0, back = -1 }
    end

    function deque.is_empty(dequeObject)
        return dequeObject.front > dequeObject.back
    end

    function deque.front(dequeObject)
        return dequeObject[dequeObject.front]
    end

    function deque.back(dequeObject)
        return dequeObject[dequeObject.back]
    end

    function deque.push_front(dequeObject, value)
        dequeObject.front = dequeObject.front - 1
        dequeObject[dequeObject.front] = value
    end

    function deque.pop_front(dequeObject)
        if dequeObject.front <= dequeObject.back then
            local result = dequeObject[dequeObject.front]
            dequeObject[dequeObject.front] = nil
            dequeObject.front = dequeObject.front + 1
            return result
        end
    end

    function deque.push_back(dequeObject, value)
        dequeObject.back = dequeObject.back + 1
        dequeObject[dequeObject.back] = value
    end

    function deque.pop_back(dequeObject)
        if dequeObject.front <= dequeObject.back then
            local result = dequeObject[dequeObject.back]
            dequeObject[dequeObject.back] = nil
            dequeObject.back = dequeObject.back - 1
            return result
        end
    end
end

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

function table.contains(table, value)
    for v in values(table) do
        if (v == value) then
            return true
        end
    end
    return false
end

function table.containsWithOut(table, value, out)
    for k, v in pairs(table) do
        if (v == value) then
            out[0] = k
            return true
        end
    end
    return false
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

function table.length(tbl)
    local count = 0
    for _, _ in pairs(tbl) do
       count = count + 1
    end
    return count
end

function table.getKeys(t)
  local keys={}
  for key,_ in pairs(t) do
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