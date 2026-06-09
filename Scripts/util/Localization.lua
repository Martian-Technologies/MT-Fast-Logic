-- ID-based localization for MT-Fast-Logic Lua UI strings.
--
-- String data lives in Scripts/util/Localization.json so English and Russian are
-- both values for stable ids instead of English being used as the lookup key.
--
-- Usage:
--   tr("mt.some.id")
--   tr("mt.some.id", { value = 123 }) -- replaces {value}

MTLocalization = MTLocalization or {}

MTLocalization.defaultLanguage = "English"
MTLocalization.path = "$CONTENT_DATA/Scripts/util/Localization.json"
MTLocalization.strings = MTLocalization.strings or nil

local function substitute(text, vars)
    if vars == nil then
        return text
    end
    return (string.gsub(text, "{([%w_]+)}", function(key)
        local value = vars[key]
        if value == nil then
            return "{" .. key .. "}"
        end
        return tostring(value)
    end))
end

function MTLocalization.loadStrings()
    if MTLocalization.strings ~= nil then
        return MTLocalization.strings
    end

    MTLocalization.strings = {}

    if sm == nil or sm.json == nil or sm.json.open == nil then
        return MTLocalization.strings
    end

    local ok, data = pcall(sm.json.open, MTLocalization.path)
    if ok and type(data) == "table" then
        MTLocalization.strings = data
    else
        print("MTLocalization: failed to load " .. MTLocalization.path)
    end

    return MTLocalization.strings
end

function MTLocalization.getLanguage()
    if sm ~= nil and sm.gui ~= nil and sm.gui.getCurrentLanguage ~= nil then
        local ok, language = pcall(sm.gui.getCurrentLanguage)
        if ok and type(language) == "string" then
            return language
        end
    end
    return MTLocalization.defaultLanguage
end

function MTLocalization.get(id, vars, language)
    local strings = MTLocalization.loadStrings()
    local entry = strings[id]
    if entry == nil then
        return id
    end

    local selectedLanguage = language or MTLocalization.getLanguage()
    local text = entry[selectedLanguage] or entry[MTLocalization.defaultLanguage] or id
    return substitute(text, vars)
end

function MTLocalization.resolve(value, vars, language)
    if type(value) ~= "string" then
        return value
    end
    if MTLocalization.loadStrings()[value] == nil then
        return value
    end
    return MTLocalization.get(value, vars, language)
end

function MTLocalization.isLanguage(language)
    return MTLocalization.getLanguage() == language
end

function MTLocalization.patchGui()
    if sm == nil or sm.gui == nil or sm.gui.setInteractionText == nil then
        return
    end
    if sm.gui._mtLocalizationOriginalSetInteractionText ~= nil then
        return
    end

    local unpackArgs = table.unpack or unpack
    sm.gui._mtLocalizationOriginalSetInteractionText = sm.gui.setInteractionText
    sm.gui.setInteractionText = function(...)
        local n = select("#", ...)
        local args = { ... }
        for i = 1, n do
            args[i] = MTLocalization.resolve(args[i])
        end
        return sm.gui._mtLocalizationOriginalSetInteractionText(unpackArgs(args, 1, n))
    end
end

function tr(id, vars)
    return MTLocalization.get(id, vars)
end

MTLocalization.loadStrings()
MTLocalization.patchGui()
