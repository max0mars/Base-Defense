-- json.lua - Minimal JSON encode / decode for the online leaderboard.
--
-- encode: tables with keys 1..n (or empty, see json.EMPTY_ARRAY) become arrays,
-- other tables objects with string keys. Strings are assumed to be UTF-8.
-- decode: any JSON value; null becomes nil (json.null inside arrays, so they
-- keep their length). Errors on malformed input, so wrap it in pcall.

local json = {}

json.null = setmetatable({}, { __tostring = function() return "null" end })
-- Encodes as [] (an empty Lua table would otherwise be {})
json.EMPTY_ARRAY = setmetatable({}, { __tostring = function() return "[]" end })

-- -----------------------------------------------------------------------------
-- Encoding
-- -----------------------------------------------------------------------------

local ESCAPES = {
    ['"'] = '\\"', ["\\"] = "\\\\", ["\b"] = "\\b", ["\f"] = "\\f",
    ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t",
}

local function encodeString(s)
    return '"' .. s:gsub('[%c"\\]', function(c)
        return ESCAPES[c] or string.format("\\u%04x", c:byte())
    end) .. '"'
end

local function isArray(t)
    local n = 0
    for k in pairs(t) do
        if type(k) ~= "number" or k < 1 or k % 1 ~= 0 then return false end
        n = math.max(n, k)
    end
    return n > 0 and n or false
end

local encodeValue

local function encodeTable(t, out, visiting)
    if t == json.null then table.insert(out, "null") return end
    if t == json.EMPTY_ARRAY then table.insert(out, "[]") return end
    if visiting[t] then error("json: can't encode a cycle", 0) end
    visiting[t] = true

    local n = isArray(t)
    if n then
        table.insert(out, "[")
        for i = 1, n do
            if i > 1 then table.insert(out, ",") end
            encodeValue(t[i], out, visiting)
        end
        table.insert(out, "]")
    else
        -- Sorted keys keep the output stable
        local keys = {}
        for k in pairs(t) do
            if type(k) ~= "string" then error("json: object keys must be strings", 0) end
            table.insert(keys, k)
        end
        table.sort(keys)
        table.insert(out, "{")
        for i, k in ipairs(keys) do
            if i > 1 then table.insert(out, ",") end
            table.insert(out, encodeString(k))
            table.insert(out, ":")
            encodeValue(t[k], out, visiting)
        end
        table.insert(out, "}")
    end
    visiting[t] = nil
end

function encodeValue(v, out, visiting)
    local kind = type(v)
    if kind == "nil" then
        table.insert(out, "null")
    elseif kind == "boolean" then
        table.insert(out, tostring(v))
    elseif kind == "number" then
        if v ~= v or v == math.huge or v == -math.huge then error("json: can't encode " .. tostring(v), 0) end
        if v % 1 == 0 and math.abs(v) < 2 ^ 53 then
            table.insert(out, string.format("%d", v))
        else
            table.insert(out, string.format("%.14g", v))
        end
    elseif kind == "string" then
        table.insert(out, encodeString(v))
    elseif kind == "table" then
        encodeTable(v, out, visiting)
    else
        error("json: can't encode a " .. kind, 0)
    end
end

function json.encode(value)
    local out = {}
    encodeValue(value, out, {})
    return table.concat(out)
end

-- -----------------------------------------------------------------------------
-- Decoding
-- -----------------------------------------------------------------------------

local UNESCAPES = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }

local function utf8Char(code)
    if code < 0x80 then return string.char(code) end
    if code < 0x800 then
        return string.char(0xC0 + math.floor(code / 0x40), 0x80 + code % 0x40)
    end
    if code < 0x10000 then
        return string.char(0xE0 + math.floor(code / 0x1000), 0x80 + math.floor(code / 0x40) % 0x40, 0x80 + code % 0x40)
    end
    return string.char(0xF0 + math.floor(code / 0x40000), 0x80 + math.floor(code / 0x1000) % 0x40,
        0x80 + math.floor(code / 0x40) % 0x40, 0x80 + code % 0x40)
end

local decodeValue

local function fail(s, i, what)
    error(string.format("json: %s at character %d", what, i), 0)
end

local function skipSpace(s, i)
    return s:find("[^ \t\r\n]", i) or #s + 1
end

local function decodeString(s, i)
    local parts = {}
    local j = i + 1
    while true do
        local c = s:sub(j, j)
        if c == "" then fail(s, j, "unterminated string") end
        if c == '"' then return table.concat(parts), j + 1 end
        if c == "\\" then
            local e = s:sub(j + 1, j + 1)
            if e == "u" then
                local code = tonumber(s:sub(j + 2, j + 5), 16)
                if not code then fail(s, j, "bad \\u escape") end
                j = j + 6
                -- A surrogate pair is two escapes making one character
                if code >= 0xD800 and code <= 0xDBFF and s:sub(j, j + 1) == "\\u" then
                    local low = tonumber(s:sub(j + 2, j + 5), 16)
                    if low and low >= 0xDC00 and low <= 0xDFFF then
                        code = 0x10000 + (code - 0xD800) * 0x400 + (low - 0xDC00)
                        j = j + 6
                    end
                end
                table.insert(parts, utf8Char(code))
            elseif UNESCAPES[e] then
                table.insert(parts, UNESCAPES[e])
                j = j + 2
            else
                fail(s, j, "bad escape")
            end
        else
            local stop = s:find('["\\]', j) or #s + 1
            table.insert(parts, s:sub(j, stop - 1))
            j = stop
        end
    end
end

local function decodeArray(s, i)
    local arr, n = {}, 0
    i = skipSpace(s, i + 1)
    if s:sub(i, i) == "]" then return arr, i + 1 end
    while true do
        local v
        v, i = decodeValue(s, i)
        n = n + 1
        arr[n] = (v == nil) and json.null or v
        i = skipSpace(s, i)
        local c = s:sub(i, i)
        if c == "]" then return arr, i + 1 end
        if c ~= "," then fail(s, i, "expected ',' or ']'") end
        i = skipSpace(s, i + 1)
    end
end

local function decodeObject(s, i)
    local obj = {}
    i = skipSpace(s, i + 1)
    if s:sub(i, i) == "}" then return obj, i + 1 end
    while true do
        if s:sub(i, i) ~= '"' then fail(s, i, "expected a key") end
        local key
        key, i = decodeString(s, i)
        i = skipSpace(s, i)
        if s:sub(i, i) ~= ":" then fail(s, i, "expected ':'") end
        local v
        v, i = decodeValue(s, skipSpace(s, i + 1))
        obj[key] = v
        i = skipSpace(s, i)
        local c = s:sub(i, i)
        if c == "}" then return obj, i + 1 end
        if c ~= "," then fail(s, i, "expected ',' or '}'") end
        i = skipSpace(s, i + 1)
    end
end

function decodeValue(s, i)
    i = skipSpace(s, i)
    local c = s:sub(i, i)
    if c == "{" then return decodeObject(s, i) end
    if c == "[" then return decodeArray(s, i) end
    if c == '"' then return decodeString(s, i) end
    if s:sub(i, i + 3) == "true" then return true, i + 4 end
    if s:sub(i, i + 4) == "false" then return false, i + 5 end
    if s:sub(i, i + 3) == "null" then return nil, i + 4 end
    local num = s:match("^-?%d+%.?%d*[eE]?[-+]?%d*", i)
    if num and num ~= "" and num ~= "-" then
        local value = tonumber(num)
        if value then return value, i + #num end
    end
    fail(s, i, "unexpected '" .. c .. "'")
end

function json.decode(s)
    if type(s) ~= "string" then error("json: expected a string", 0) end
    local value, i = decodeValue(s, 1)
    i = skipSpace(s, i)
    if i <= #s then fail(s, i, "trailing characters") end
    return value
end

return json
