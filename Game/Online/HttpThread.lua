-- =============================================================================
-- HTTP THREAD (HttpThread.lua)
-- Runs in a love.thread: takes requests off a channel, makes them with the
-- system's curl (shipped with Windows 10+ and macOS) and pushes the responses
-- back. LÖVE 11 has no HTTPS of its own, so this is how the game reaches the
-- leaderboard server. Started by Game/Online/Http.lua.
--
-- Request  { id, method, url, body }       (body: string or nil)
-- Response { id, status, body, error }     (status 0 + error: curl failed)
--
-- The request and response bodies go through files in the save folder, so no
-- data is ever put on a command line. On Windows curl is started through the
-- Win32 API with CREATE_NO_WINDOW; io.popen would flash a console window.
-- =============================================================================

require("love.filesystem")
local ffi = require("ffi")

local requests = love.thread.getChannel("http_requests")
local responses = love.thread.getChannel("http_responses")

local TIMEOUT = 15 -- seconds, per request
local BODY_IN, BODY_OUT, HEADERS = "http_request.tmp", "http_response.tmp", "http_headers.tmp"

local isWindows = ffi.os == "Windows"
local saveDir = love.filesystem.getSaveDirectory()

local function realPath(name)
    return saveDir .. "/" .. name
end

local function quote(s)
    return '"' .. s .. '"'
end

-- -----------------------------------------------------------------------------
-- Starting curl
-- -----------------------------------------------------------------------------

local run

if isWindows then
    ffi.cdef [[
        typedef struct {
            uint32_t cb; void *lpReserved; void *lpDesktop; void *lpTitle;
            uint32_t dwX, dwY, dwXSize, dwYSize, dwXCountChars, dwYCountChars, dwFillAttribute, dwFlags;
            uint16_t wShowWindow, cbReserved2; void *lpReserved2;
            void *hStdInput, *hStdOutput, *hStdError;
        } BD_STARTUPINFOW;
        typedef struct { void *hProcess, *hThread; uint32_t dwProcessId, dwThreadId; } BD_PROCESS_INFORMATION;
        int CreateProcessW(const uint16_t *app, uint16_t *cmd, void *pa, void *ta, int inherit, uint32_t flags,
                           void *env, const uint16_t *dir, BD_STARTUPINFOW *si, BD_PROCESS_INFORMATION *pi);
        uint32_t WaitForSingleObject(void *handle, uint32_t ms);
        int GetExitCodeProcess(void *process, uint32_t *code);
        int CloseHandle(void *handle);
        int MultiByteToWideChar(uint32_t page, uint32_t flags, const char *s, int len, uint16_t *out, int outLen);
    ]]
    local kernel32 = ffi.load("kernel32")
    local CP_UTF8, CREATE_NO_WINDOW, INFINITE = 65001, 0x08000000, 0xFFFFFFFF

    local function wide(s)
        local n = kernel32.MultiByteToWideChar(CP_UTF8, 0, s, -1, nil, 0)
        local buf = ffi.new("uint16_t[?]", n)
        kernel32.MultiByteToWideChar(CP_UTF8, 0, s, -1, buf, n)
        return buf
    end

    --- Runs a command line without a console window. Returns the exit code, or nil.
    function run(cmdline)
        local si = ffi.new("BD_STARTUPINFOW")
        si.cb = ffi.sizeof(si)
        local pi = ffi.new("BD_PROCESS_INFORMATION")
        if kernel32.CreateProcessW(nil, wide(cmdline), nil, nil, 0, CREATE_NO_WINDOW, nil, nil, si, pi) == 0 then
            return nil
        end
        kernel32.WaitForSingleObject(pi.hProcess, INFINITE)
        local code = ffi.new("uint32_t[1]")
        kernel32.GetExitCodeProcess(pi.hProcess, code)
        kernel32.CloseHandle(pi.hThread)
        kernel32.CloseHandle(pi.hProcess)
        return tonumber(code[0])
    end
else
    function run(cmdline)
        local ok, _, code = os.execute(cmdline .. " >/dev/null 2>&1")
        if type(ok) == "number" then return ok end -- Lua 5.1 / LuaJIT: the exit status
        return code
    end
end

-- -----------------------------------------------------------------------------
-- Requests
-- -----------------------------------------------------------------------------

--- The status code of the final response in a curl header dump (it can hold
--- several, e.g. a "100 Continue" before the real one).
local function parseStatus(headers)
    local status = 0
    for code in (headers or ""):gmatch("HTTP/[%d%.]+ (%d%d%d)") do status = tonumber(code) end
    return status
end

local function perform(req)
    love.filesystem.remove(BODY_OUT)
    love.filesystem.remove(HEADERS)

    local args = {
        isWindows and "curl.exe" or "curl",
        "-s", "--max-time", tostring(TIMEOUT),
        "--create-dirs", -- the save folder may not exist yet
        "-X", req.method or "GET",
        "-o", quote(realPath(BODY_OUT)),
        "-D", quote(realPath(HEADERS)),
    }
    if req.body then
        love.filesystem.write(BODY_IN, req.body)
        table.insert(args, '-H "Content-Type: application/json"')
        table.insert(args, "--data-binary " .. quote("@" .. realPath(BODY_IN)))
    end
    table.insert(args, quote(req.url))

    local code = run(table.concat(args, " "))
    if code == nil then
        return { id = req.id, status = 0, error = "couldn't start curl" }
    end
    if code ~= 0 then
        return { id = req.id, status = 0, error = "curl exit code " .. code }
    end
    return {
        id = req.id,
        status = parseStatus(love.filesystem.read(HEADERS)),
        body = love.filesystem.read(BODY_OUT) or "",
    }
end

while true do
    local req = requests:demand()
    if req == "quit" then break end
    local ok, result = pcall(perform, req)
    if not ok then result = { id = req.id, status = 0, error = tostring(result) } end
    responses:push(result)
end
