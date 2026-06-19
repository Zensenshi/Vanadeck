-- VanaDeck Ashita Addon
-- Sends live player and party status over TCP to the companion Flutter app.

addon.name = 'vanadeck'
addon.author = 'VanaDeck contributors'
addon.version = '1.0'
addon.desc = 'Send FFXI player status to localhost:8080 as newline-delimited JSON.'

require 'common'

local function create_text_encoding_converter()
    local ffiOk, ffi = pcall(require, 'ffi')
    if not ffiOk then
        return nil
    end

    pcall(ffi.cdef, [[
        int MultiByteToWideChar(unsigned int CodePage, unsigned int dwFlags, const char* lpMultiByteStr, int cbMultiByte, wchar_t* lpWideCharStr, int cchWideChar);
        int WideCharToMultiByte(unsigned int CodePage, unsigned int dwFlags, const wchar_t* lpWideCharStr, int cchWideChar, char* lpMultiByteStr, int cbMultiByte, const char* lpDefaultChar, int* lpUsedDefaultChar);
    ]])

    local code_page = {
        utf8 = 65001,
        shiftjis = 932,
    }

    local function convert_string(input, codepage_from, codepage_to)
        if type(input) ~= 'string' or input == '' then
            return input
        end

        local ok, converted = pcall(function()
            local input_buffer = ffi.new('char[?]', #input + 1)
            ffi.copy(input_buffer, input)

            local wide_length = ffi.C.MultiByteToWideChar(codepage_from, 0, input_buffer, -1, nil, 0)
            if wide_length <= 0 then
                return input
            end

            local wide_buffer = ffi.new('wchar_t[?]', wide_length)
            if ffi.C.MultiByteToWideChar(codepage_from, 0, input_buffer, -1, wide_buffer, wide_length) <= 0 then
                return input
            end

            local output_length = ffi.C.WideCharToMultiByte(codepage_to, 0, wide_buffer, -1, nil, 0, nil, nil)
            if output_length <= 0 then
                return input
            end

            local output_buffer = ffi.new('char[?]', output_length)
            if ffi.C.WideCharToMultiByte(codepage_to, 0, wide_buffer, -1, output_buffer, output_length, nil, nil) <= 0 then
                return input
            end

            return ffi.string(output_buffer)
        end)

        if ok and type(converted) == 'string' then
            return converted
        end

        return input
    end

    return {
        shiftjis_to_utf8 = function(input)
            return convert_string(input, code_page.shiftjis, code_page.utf8)
        end,
        utf8_to_shiftjis = function(input)
            return convert_string(input, code_page.utf8, code_page.shiftjis)
        end,
    }
end

local text_encoding = nil

local function is_valid_utf8(input)
    if type(input) ~= 'string' then
        return false
    end

    local index = 1
    local length = #input
    while index <= length do
        local byte = input:byte(index)
        local extra = 0
        local min_codepoint = 0
        local codepoint = 0

        if byte <= 0x7F then
            index = index + 1
        elseif byte >= 0xC2 and byte <= 0xDF then
            extra = 1
            min_codepoint = 0x80
            codepoint = byte - 0xC0
        elseif byte >= 0xE0 and byte <= 0xEF then
            extra = 2
            min_codepoint = 0x800
            codepoint = byte - 0xE0
        elseif byte >= 0xF0 and byte <= 0xF4 then
            extra = 3
            min_codepoint = 0x10000
            codepoint = byte - 0xF0
        else
            return false
        end

        if extra > 0 then
            if index + extra > length then
                return false
            end

            for offset = 1, extra do
                local continuation = input:byte(index + offset)
                if continuation < 0x80 or continuation > 0xBF then
                    return false
                end
                codepoint = (codepoint * 0x40) + (continuation - 0x80)
            end

            if codepoint < min_codepoint or codepoint > 0x10FFFF or
                (codepoint >= 0xD800 and codepoint <= 0xDFFF) then
                return false
            end
            index = index + extra + 1
        end
    end

    return true
end

local function shiftjis_to_utf8_if_needed(input)
    if type(input) ~= 'string' or input == '' then
        return input
    end
    if is_valid_utf8(input) then
        return input
    end
    if text_encoding then
        return text_encoding.shiftjis_to_utf8(input)
    end
    return input
end

local function create_json_encoder()
    local ok, json = pcall(require, 'json')
    if ok and json and json.encode then
        return json
    end

    ok, json = pcall(require, 'cjson')
    if ok and json and json.encode then
        return json
    end

    local function escape_string(value)
        return '"' .. tostring(value):gsub('[%z\1-\31\\"]', function(c)
            local escapes = {
                ['\\'] = '\\\\',
                ['"'] = '\\"',
                ['\b'] = '\\b',
                ['\f'] = '\\f',
                ['\n'] = '\\n',
                ['\r'] = '\\r',
                ['\t'] = '\\t',
            }
            return escapes[c] or string.format('\\u%04x', c:byte())
        end) .. '"'
    end

    local encode
    encode = function(value)
        local valueType = type(value)
        if valueType == 'nil' then
            return 'null'
        end
        if valueType == 'boolean' then
            return tostring(value)
        end
        if valueType == 'number' then
            return tostring(value)
        end
        if valueType == 'string' then
            return escape_string(value)
        end
        if valueType == 'table' then
            local isArray = true
            local count = 0
            for key, _ in pairs(value) do
                count = count + 1
                if type(key) ~= 'number' then
                    isArray = false
                end
            end

            local parts = {}
            if isArray then
                for index = 1, count do
                    table.insert(parts, encode(value[index]))
                end
                return '[' .. table.concat(parts, ',') .. ']'
            end

            for key, item in pairs(value) do
                table.insert(parts, escape_string(key) .. ':' .. encode(item))
            end
            return '{' .. table.concat(parts, ',') .. '}'
        end

        return 'null'
    end

    return { encode = encode }
end

local function create_socket_transport()
    local ok, socket = pcall(require, 'socket')
    if ok and socket and socket.tcp then
        return socket, 'LuaSocket'
    end

    local ffiOk, ffi = pcall(require, 'ffi')
    if not ffiOk then
        return nil, 'LuaJIT FFI unavailable'
    end

    local cdefOk, cdefErr = pcall(ffi.cdef, [[
        typedef unsigned short u_short;
        typedef unsigned long u_long;
        typedef uintptr_t SOCKET;

        typedef struct WSAData {
            unsigned short wVersion;
            unsigned short wHighVersion;
            char szDescription[257];
            char szSystemStatus[129];
            unsigned short iMaxSockets;
            unsigned short iMaxUdpDg;
            char* lpVendorInfo;
        } WSADATA;

        struct in_addr {
            unsigned long s_addr;
        };

        struct sockaddr {
            unsigned short sa_family;
            char sa_data[14];
        };

        struct sockaddr_in {
            short sin_family;
            unsigned short sin_port;
            struct in_addr sin_addr;
            char sin_zero[8];
        };

        int WSAStartup(unsigned short wVersionRequested, WSADATA* lpWSAData);
        int WSACleanup(void);
        SOCKET socket(int af, int type, int protocol);
        int connect(SOCKET s, const struct sockaddr* name, int namelen);
        int ioctlsocket(SOCKET s, long cmd, u_long* argp);
        int recv(SOCKET s, char* buf, int len, int flags);
        int send(SOCKET s, const char* buf, int len, int flags);
        int closesocket(SOCKET s);
        unsigned short htons(unsigned short hostshort);
        unsigned long inet_addr(const char* cp);
        int WSAGetLastError(void);
    ]])
    if not cdefOk and not tostring(cdefErr):find('redefine') then
        return nil, 'WinSock definitions failed: ' .. tostring(cdefErr)
    end

    local loadOk, ws2 = pcall(ffi.load, 'Ws2_32')
    if not loadOk then
        return nil, 'WinSock library load failed: ' .. tostring(ws2)
    end

    local wsaData = ffi.new('WSADATA[1]')
    if ws2.WSAStartup(0x0202, wsaData) ~= 0 then
        return nil, 'WinSock startup failed'
    end

    local transport = {}
    transport.tcp = function()
        local rawSocket = nil
        local receiveBuffer = ''
        local wrapper = {}

        wrapper.settimeout = function() end

        wrapper.connect = function(_, address, targetPort)
            rawSocket = ws2.socket(2, 1, 6)
            if rawSocket == ffi.cast('SOCKET', -1) then
                return nil, 'socket failed: ' .. tostring(ws2.WSAGetLastError())
            end

            local sockaddr = ffi.new('struct sockaddr_in')
            sockaddr.sin_family = 2
            sockaddr.sin_port = ws2.htons(targetPort)
            sockaddr.sin_addr.s_addr = ws2.inet_addr(address)

            local result = ws2.connect(rawSocket, ffi.cast('const struct sockaddr*', sockaddr), ffi.sizeof(sockaddr))
            if result ~= 0 then
                local err = ws2.WSAGetLastError()
                ws2.closesocket(rawSocket)
                rawSocket = nil
                return nil, 'connect failed: ' .. tostring(err)
            end

            local nonblocking = ffi.new('u_long[1]', 1)
            ws2.ioctlsocket(rawSocket, 0x8004667E, nonblocking)

            return true
        end

        wrapper.send = function(_, payload)
            if rawSocket == nil then
                return nil, 'not connected'
            end

            local total = 0
            local length = #payload
            while total < length do
                local chunk = payload:sub(total + 1)
                local sent = ws2.send(rawSocket, chunk, #chunk, 0)
                if sent < 0 then
                    return nil, 'send failed: ' .. tostring(ws2.WSAGetLastError())
                end
                if sent == 0 then
                    return nil, 'send failed: connection closed'
                end
                total = total + sent
            end

            return total
        end

        wrapper.receive = function(_, pattern)
            if rawSocket == nil then
                return nil, 'not connected'
            end

            local newline = receiveBuffer:find('\n', 1, true)
            if newline then
                local line = receiveBuffer:sub(1, newline - 1):gsub('\r$', '')
                receiveBuffer = receiveBuffer:sub(newline + 1)
                return line
            end

            local buffer = ffi.new('char[4096]')
            local received = ws2.recv(rawSocket, buffer, 4096, 0)
            if received > 0 then
                receiveBuffer = receiveBuffer .. ffi.string(buffer, received)
                newline = receiveBuffer:find('\n', 1, true)
                if newline then
                    local line = receiveBuffer:sub(1, newline - 1):gsub('\r$', '')
                    receiveBuffer = receiveBuffer:sub(newline + 1)
                    return line
                end
                return nil, 'timeout'
            end
            if received == 0 then
                return nil, 'closed'
            end

            local err = ws2.WSAGetLastError()
            if err == 10035 then
                return nil, 'timeout'
            end

            return nil, 'receive failed: ' .. tostring(err)
        end

        wrapper.close = function()
            if rawSocket ~= nil then
                ws2.closesocket(rawSocket)
                rawSocket = nil
            end
        end

        return wrapper
    end

    return transport, 'WinSock FFI'
end

local json = create_json_encoder()
text_encoding = create_text_encoding_converter()
local socket, socket_source = create_socket_transport()
local macro_ok, macro_lib = pcall(require, 'ffxi.macros')
if not macro_ok then
    macro_lib = nil
end

local client = nil
local last_send = 0
local send_interval = 1.0
local subtarget_send_interval = 0.08
local last_subtarget_active = false
local host = '127.0.0.1'
local port = 8080
local was_connected = false
local active_macro_book = 1
local active_macro_set = 1
local manual_subtarget_party_index = nil
local manual_subtarget_expires_at = 0
local chat_messages = {}
local max_chat_messages = 80
local chat_sequence = 0
local last_chat_message_key = nil
local last_chat_message_at = 0
local chat_duplicate_window = 1.5
local max_command_length = 512
local max_commands_per_frame = 20
local macro_input_prefix = '__vanadeck_macro_input__:'
local macro_metadata_refresh_interval = 0.75
local ctrl_down = false
local key_ffi = nil
local key_user32 = nil
local ashita_input_manager = nil
local ashita_send_key_supported = nil
local pending_ashita_key_ups = {}
local ashita_xinput_supported = nil
local pending_xinput_button_ups = {}
local pending_targeted_macro = nil
local targeted_macro_sequence = 0
local macro_metadata_cache = {
    key = '',
    expires_at = 0,
    names = {},
    needsTarget = {},
}

local key_ffi_ok, loaded_key_ffi = pcall(require, 'ffi')
if key_ffi_ok then
    key_ffi = loaded_key_ffi
    pcall(key_ffi.cdef, [[
        typedef unsigned char BYTE;
        typedef unsigned int UINT;
        typedef unsigned short WORD;
        typedef unsigned long DWORD;
        typedef uintptr_t ULONG_PTR;
        typedef struct tagKEYBDINPUT {
            WORD wVk;
            WORD wScan;
            DWORD dwFlags;
            DWORD time;
            ULONG_PTR dwExtraInfo;
        } KEYBDINPUT;
        typedef struct tagINPUT {
            DWORD type;
            KEYBDINPUT ki;
        } INPUT;
        void keybd_event(BYTE bVk, BYTE bScan, DWORD dwFlags, ULONG_PTR dwExtraInfo);
        UINT SendInput(UINT cInputs, INPUT* pInputs, int cbSize);
        short VkKeyScanA(char ch);
    ]])

    local user32_ok, loaded_user32 = pcall(key_ffi.load, 'user32')
    if user32_ok then
        key_user32 = loaded_user32
    end
end

local key_input_type_keyboard = 1
local keyeventf_extendedkey = 0x0001
local keyeventf_keyup = 0x0002
local keyeventf_scancode = 0x0008
local xinput_button_a = 12
local xinput_button_b = 13
local virtual_key_scancodes = {
    [0x0D] = 0x1C, -- VK_RETURN
    [0x08] = 0x0E, -- VK_BACK
    [0x09] = 0x0F, -- VK_TAB
    [0x20] = 0x39, -- VK_SPACE
    [0x1B] = 0x01, -- VK_ESCAPE
    [0x25] = { scan = 0x4B, extended = true }, -- VK_LEFT
    [0x26] = { scan = 0x48, extended = true }, -- VK_UP
    [0x27] = { scan = 0x4D, extended = true }, -- VK_RIGHT
    [0x28] = { scan = 0x50, extended = true }, -- VK_DOWN
    [0x60] = 0x52, -- VK_NUMPAD0
    [0x61] = 0x4F, -- VK_NUMPAD1
    [0x62] = 0x50, -- VK_NUMPAD2
    [0x63] = 0x51, -- VK_NUMPAD3
    [0x64] = 0x4B, -- VK_NUMPAD4
    [0x65] = 0x4C, -- VK_NUMPAD5
    [0x66] = 0x4D, -- VK_NUMPAD6
    [0x67] = 0x47, -- VK_NUMPAD7
    [0x68] = 0x48, -- VK_NUMPAD8
    [0x69] = 0x49, -- VK_NUMPAD9
    [0x6E] = 0x53, -- VK_DECIMAL
    [0x70] = 0x3B, -- VK_F1
    [0x71] = 0x3C, -- VK_F2
    [0x72] = 0x3D, -- VK_F3
    [0x73] = 0x3E, -- VK_F4
    [0x74] = 0x3F, -- VK_F5
    [0x75] = 0x40, -- VK_F6
    [0x76] = 0x41, -- VK_F7
    [0x77] = 0x42, -- VK_F8
    [0x78] = 0x43, -- VK_F9
    [0x79] = 0x44, -- VK_F10
    [0x7A] = 0x57, -- VK_F11
    [0x7B] = 0x58, -- VK_F12
}

local virtual_key_dik_codes = {
    [0x0D] = 0x1C, -- VK_RETURN / DIK_RETURN
    [0x08] = 0x0E, -- VK_BACK / DIK_BACK
    [0x09] = 0x0F, -- VK_TAB / DIK_TAB
    [0x20] = 0x39, -- VK_SPACE / DIK_SPACE
    [0x1B] = 0x01, -- VK_ESCAPE / DIK_ESCAPE
    [0x10] = 0x2A, -- VK_SHIFT / DIK_LSHIFT
    [0x11] = 0x1D, -- VK_CONTROL / DIK_LCONTROL
    [0x12] = 0x38, -- VK_MENU / DIK_LMENU
    [0x25] = 0xCB, -- VK_LEFT / DIK_LEFT
    [0x26] = 0xC8, -- VK_UP / DIK_UP
    [0x27] = 0xCD, -- VK_RIGHT / DIK_RIGHT
    [0x28] = 0xD0, -- VK_DOWN / DIK_DOWN
    [0x30] = 0x0B, -- VK_0 / DIK_0
    [0x31] = 0x02, -- VK_1 / DIK_1
    [0x32] = 0x03, -- VK_2 / DIK_2
    [0x33] = 0x04, -- VK_3 / DIK_3
    [0x34] = 0x05, -- VK_4 / DIK_4
    [0x35] = 0x06, -- VK_5 / DIK_5
    [0x36] = 0x07, -- VK_6 / DIK_6
    [0x37] = 0x08, -- VK_7 / DIK_7
    [0x38] = 0x09, -- VK_8 / DIK_8
    [0x39] = 0x0A, -- VK_9 / DIK_9
    [0x60] = 0x52, -- VK_NUMPAD0 / DIK_NUMPAD0
    [0x61] = 0x4F, -- VK_NUMPAD1 / DIK_NUMPAD1
    [0x62] = 0x50, -- VK_NUMPAD2 / DIK_NUMPAD2
    [0x63] = 0x51, -- VK_NUMPAD3 / DIK_NUMPAD3
    [0x64] = 0x4B, -- VK_NUMPAD4 / DIK_NUMPAD4
    [0x65] = 0x4C, -- VK_NUMPAD5 / DIK_NUMPAD5
    [0x66] = 0x4D, -- VK_NUMPAD6 / DIK_NUMPAD6
    [0x67] = 0x47, -- VK_NUMPAD7 / DIK_NUMPAD7
    [0x68] = 0x48, -- VK_NUMPAD8 / DIK_NUMPAD8
    [0x69] = 0x49, -- VK_NUMPAD9 / DIK_NUMPAD9
    [0x6E] = 0x53, -- VK_DECIMAL / DIK_DECIMAL
    [0x70] = 0x3B, -- VK_F1 / DIK_F1
    [0x71] = 0x3C, -- VK_F2 / DIK_F2
    [0x72] = 0x3D, -- VK_F3 / DIK_F3
    [0x73] = 0x3E, -- VK_F4 / DIK_F4
    [0x74] = 0x3F, -- VK_F5 / DIK_F5
    [0x75] = 0x40, -- VK_F6 / DIK_F6
    [0x76] = 0x41, -- VK_F7 / DIK_F7
    [0x77] = 0x42, -- VK_F8 / DIK_F8
    [0x78] = 0x43, -- VK_F9 / DIK_F9
    [0x79] = 0x44, -- VK_F10 / DIK_F10
    [0x7A] = 0x57, -- VK_F11 / DIK_F11
    [0x7B] = 0x58, -- VK_F12 / DIK_F12
    [0xA2] = 0x1D, -- VK_LCONTROL / DIK_LCONTROL
    [0xA3] = 0x9D, -- VK_RCONTROL / DIK_RCONTROL
    [0xA4] = 0x38, -- VK_LMENU / DIK_LMENU
    [0xA5] = 0xB8, -- VK_RMENU / DIK_RMENU
}

local function clamp_integer(value, min_value, max_value)
    value = tonumber(value)
    if value == nil then
        return nil
    end

    value = math.floor(value)
    if value < min_value then
        return min_value
    end
    if value > max_value then
        return max_value
    end
    return value
end

local function normalize_macro_set(raw_set)
    raw_set = tonumber(raw_set)
    if raw_set == nil then
        return nil
    end

    raw_set = math.floor(raw_set)
    if raw_set >= 0 and raw_set <= 18 and (raw_set % 2) == 0 then
        return math.floor(raw_set / 2) + 1
    end
    if raw_set >= 1 and raw_set <= 10 then
        return raw_set
    end
    if raw_set == 0 then
        return 1
    end

    return nil
end

local function normalize_macro_book(raw_book)
    raw_book = tonumber(raw_book)
    if raw_book == nil then
        return nil
    end

    raw_book = math.floor(raw_book)
    -- FFXI stores the active book as a zero-based 0..19 value here.
    -- Macro pages nearby use an even-number pattern, so do not apply the page
    -- decoder to this field.
    if raw_book >= 0 and raw_book <= 19 then
        return raw_book + 1
    end

    return nil
end

local function read_uint32(address)
    if not ashita or not ashita.memory or not ashita.memory.read_uint32 then
        return nil
    end

    local ok, value = pcall(ashita.memory.read_uint32, address)
    if ok then
        return value
    end

    return nil
end

local function read_uint16(address)
    if not ashita or not ashita.memory or not ashita.memory.read_uint16 then
        return nil
    end

    local ok, value = pcall(ashita.memory.read_uint16, address)
    if ok then
        return value
    end

    return nil
end

local function read_uint8(address)
    if not ashita or not ashita.memory or not ashita.memory.read_uint8 then
        return nil
    end

    local ok, value = pcall(ashita.memory.read_uint8, address)
    if ok then
        return value
    end

    return nil
end

local function read_normalized_macro_value(macro_obj, offsets, normalizer)
    local zero_value = nil
    local function consider(raw)
        local value = normalizer(raw)
        if value then
            if tonumber(raw) == 0 then
                zero_value = zero_value or value
                return nil
            end
            return value
        end
        return nil
    end

    for _, offset in ipairs(offsets) do
        local address = macro_obj + offset
        local value = consider(read_uint8(address))
        if value then
            return value
        end

        value = consider(read_uint16(address))
        if value then
            return value
        end

        value = consider(read_uint32(address))
        if value then
            return value
        end
    end

    return zero_value
end

local function read_macro_name(index)
    if not macro_lib or not macro_lib.get_name then
        return ''
    end

    local ok, name = pcall(macro_lib.get_name, index)
    if not ok or type(name) ~= 'string' then
        return ''
    end

    name = name:gsub('%z', ''):gsub('^%s+', ''):gsub('%s+$', '')
    name = shiftjis_to_utf8_if_needed(name)
    return name
end

local function read_macro_names()
    local names = {}
    for index = 0, 19 do
        names[index + 1] = read_macro_name(index)
    end
    return names
end

local function read_macro_needs_target(index)
    if not macro_lib or not macro_lib.get_line then
        return false
    end

    for line = 0, 5 do
        local ok, text = pcall(macro_lib.get_line, index, line)
        if ok and type(text) == 'string' then
            text = text:gsub('%z', ''):lower()
            if text:find('<stpc>', 1, true) then
                return true
            end
        end
    end

    return false
end

local function read_macro_target_flags()
    local flags = {}
    for index = 0, 19 do
        flags[index + 1] = read_macro_needs_target(index)
    end
    return flags
end

local function read_macro_metadata()
    local now = os.clock()
    local key = ('%d:%d'):format(active_macro_book, active_macro_set)
    if macro_metadata_cache.key ~= key or now >= macro_metadata_cache.expires_at then
        macro_metadata_cache.key = key
        macro_metadata_cache.expires_at = now + macro_metadata_refresh_interval
        macro_metadata_cache.names = read_macro_names()
        macro_metadata_cache.needsTarget = read_macro_target_flags()
    end

    return macro_metadata_cache.names, macro_metadata_cache.needsTarget
end

local function update_active_macro_state()
    if macro_lib and macro_lib.get_fsmacro then
        local ok, macro_obj = pcall(macro_lib.get_fsmacro)
        if ok and macro_obj and macro_obj ~= 0 then
            local book = read_normalized_macro_value(
                macro_obj,
                { 0x1DC0 },
                normalize_macro_book)
            local set = read_normalized_macro_value(
                macro_obj,
                { 0x1DC1, 0x1DC4, 0x1DC5, 0x1DB5, 0x1DB8, 0x1DBC },
                normalize_macro_set)

            if book then
                active_macro_book = book
            end
            if set then
                active_macro_set = set
            end
        end
    end

    local names, needsTarget = read_macro_metadata()
    return {
        activeBook = active_macro_book,
        activeSet = active_macro_set,
        names = names,
        needsTarget = needsTarget,
    }
end

local function focus_game_window()
    pcall(function()
        local hwnd = AshitaCore:GetProperties():GetFinalFantasyHwnd()
        AshitaCore:SetFocus(hwnd)
        AshitaCore:SetForegroundWindow(hwnd)
    end)
end

local function get_ashita_input_manager()
    if ashita_input_manager ~= nil then
        return ashita_input_manager
    end

    local ok, manager = pcall(function()
        return AshitaCore:GetInputManager()
    end)

    if ok and manager ~= nil then
        ashita_input_manager = manager
        return manager
    end

    return nil
end

local function get_ashita_xinput()
    if ashita_xinput_supported == false then
        return nil
    end

    local manager = get_ashita_input_manager()
    if not manager then
        return nil
    end

    local ok, xinputManager = pcall(function()
        return manager:GetXInput()
    end)

    if ok and xinputManager ~= nil then
        return xinputManager
    end

    return nil
end

local function set_xinput_button(button, state)
    button = tonumber(button)
    state = tonumber(state)
    if button == nil or state == nil then
        return false
    end

    local xinputManager = get_ashita_xinput()
    if not xinputManager then
        return false
    end

    local ok = pcall(function()
        xinputManager:QueueButtonData(button, state)
    end)

    if not ok then
        ashita_xinput_supported = false
        return false
    end

    ashita_xinput_supported = true
    return true
end

local function send_xinput_button(button)
    focus_game_window()
    if not set_xinput_button(button, 1) then
        return false
    end

    table.insert(pending_xinput_button_ups, {
        button = button,
        release_at = os.clock() + 0.08,
    })
    return true
end

local function release_pending_xinput_buttons()
    if #pending_xinput_button_ups == 0 then
        return
    end

    local now = os.clock()
    for index = #pending_xinput_button_ups, 1, -1 do
        local pending = pending_xinput_button_ups[index]
        if pending.release_at <= now then
            set_xinput_button(pending.button, 0)
            table.remove(pending_xinput_button_ups, index)
        end
    end
end

local function virtual_key_to_dik(vk)
    local dik = virtual_key_dik_codes[vk]
    if dik then
        return dik
    end

    local manager = get_ashita_input_manager()
    if not manager then
        return nil
    end

    local ok, converted = pcall(function()
        local keyboard = manager:GetKeyboard()
        if keyboard and keyboard.V2D then
            return keyboard:V2D(vk)
        end
        return nil
    end)

    converted = ok and tonumber(converted) or nil
    if converted and converted > 0 then
        return converted
    end

    return nil
end

local function set_ashita_key(dik, down)
    if ashita_send_key_supported == false then
        return false
    end

    dik = tonumber(dik)
    if dik == nil then
        return false
    end

    local manager = get_ashita_input_manager()
    if not manager then
        return false
    end

    local ok = pcall(function()
        manager:SendKey(dik, down)
    end)

    if not ok then
        ashita_send_key_supported = false
        return false
    end

    ashita_send_key_supported = true
    return true
end

local function send_ashita_key(dik)
    focus_game_window()
    if not set_ashita_key(dik, true) then
        return false
    end

    table.insert(pending_ashita_key_ups, {
        dik = dik,
        release_at = os.clock() + 0.05,
    })
    return true
end

local function release_pending_ashita_keys()
    if #pending_ashita_key_ups == 0 then
        return
    end

    local now = os.clock()
    for index = #pending_ashita_key_ups, 1, -1 do
        local pending = pending_ashita_key_ups[index]
        if pending.release_at <= now then
            set_ashita_key(pending.dik, false)
            table.remove(pending_ashita_key_ups, index)
        end
    end
end

local function send_ashita_key_combo(modifier_vk, key_vk)
    local modifier_dik = virtual_key_to_dik(modifier_vk)
    local key_dik = virtual_key_to_dik(key_vk)
    if not modifier_dik or not key_dik then
        return false
    end

    focus_game_window()
    if not set_ashita_key(modifier_dik, true) then
        return false
    end

    local key_down = set_ashita_key(key_dik, true)
    if key_down then
        set_ashita_key(key_dik, false)
    end
    set_ashita_key(modifier_dik, false)
    return key_down
end

local function send_scancode(scan)
    if not key_ffi or not key_user32 or not scan then
        return false
    end

    local flags = keyeventf_scancode
    if type(scan) == 'table' then
        if scan.extended then
            flags = flags + keyeventf_extendedkey
        end
        scan = scan.scan
    end

    local ok, sent = pcall(function()
        local inputs = key_ffi.new('INPUT[2]')
        inputs[0].type = key_input_type_keyboard
        inputs[0].ki.wVk = 0
        inputs[0].ki.wScan = scan
        inputs[0].ki.dwFlags = flags
        inputs[0].ki.time = 0
        inputs[0].ki.dwExtraInfo = 0

        inputs[1].type = key_input_type_keyboard
        inputs[1].ki.wVk = 0
        inputs[1].ki.wScan = scan
        inputs[1].ki.dwFlags = flags + keyeventf_keyup
        inputs[1].ki.time = 0
        inputs[1].ki.dwExtraInfo = 0

        return key_user32.SendInput(2, inputs, key_ffi.sizeof('INPUT'))
    end)

    return ok and sent == 2
end

local function send_virtual_key(vk)
    local dik = virtual_key_to_dik(vk)
    if dik and send_ashita_key(dik) then
        return true
    end

    if not key_user32 then
        return false
    end

    focus_game_window()

    local scan = virtual_key_scancodes[vk]
    if scan and send_scancode(scan) then
        return true
    end

    key_user32.keybd_event(vk, 0, 0, 0)
    key_user32.keybd_event(vk, 0, 0x0002, 0)
    return true
end

local function send_confirm_input()
    if send_ashita_key(0x1C) then
        return true
    end
    if send_ashita_key(0x9C) then
        return true
    end

    if not key_user32 then
        return false
    end

    focus_game_window()
    local sent = false
    sent = send_scancode(0x1C) or sent -- Main Enter
    sent = send_scancode({ scan = 0x1C, extended = true }) or sent -- Numpad Enter
    key_user32.keybd_event(0x0D, 0, 0, 0)
    key_user32.keybd_event(0x0D, 0, 0x0002, 0)
    sent = true
    return sent
end

local function send_cancel_input()
    if send_ashita_key(0x01) then
        return true
    end

    if not key_user32 then
        return false
    end

    focus_game_window()
    local sent = false
    sent = send_scancode(0x01) or sent -- Escape
    key_user32.keybd_event(0x1B, 0, 0, 0)
    key_user32.keybd_event(0x1B, 0, 0x0002, 0)
    sent = true
    return sent
end

local function send_confirm_action()
    if send_xinput_button(xinput_button_a) then
        return true
    end

    return send_confirm_input()
end

local function send_cancel_action()
    if send_xinput_button(xinput_button_b) then
        return true
    end

    return send_cancel_input()
end

local function send_key_combo(modifier_vk, key_vk)
    if send_ashita_key_combo(modifier_vk, key_vk) then
        return true
    end

    if not key_user32 then
        return false
    end

    focus_game_window()
    key_user32.keybd_event(modifier_vk, 0, 0, 0)
    key_user32.keybd_event(key_vk, 0, 0, 0)
    key_user32.keybd_event(key_vk, 0, 0x0002, 0)
    key_user32.keybd_event(modifier_vk, 0, 0x0002, 0)
    return true
end

local function send_text_input(text)
    if not key_user32 or type(text) ~= 'string' or text == '' then
        return false
    end

    focus_game_window()
    local sent = false
    for index = 1, #text do
        local byte = text:byte(index)
        local scan = tonumber(key_user32.VkKeyScanA(byte))
        if scan and scan ~= -1 then
            local vk = bit.band(scan, 0xFF)
            local shift_state = bit.band(bit.rshift(scan, 8), 0xFF)
            local modifiers = {}
            if bit.band(shift_state, 1) ~= 0 then
                table.insert(modifiers, 0x10) -- VK_SHIFT
            end
            if bit.band(shift_state, 2) ~= 0 then
                table.insert(modifiers, 0x11) -- VK_CONTROL
            end
            if bit.band(shift_state, 4) ~= 0 then
                table.insert(modifiers, 0x12) -- VK_MENU/ALT
            end

            for _, modifier_vk in ipairs(modifiers) do
                key_user32.keybd_event(modifier_vk, 0, 0, 0)
            end
            key_user32.keybd_event(vk, 0, 0, 0)
            key_user32.keybd_event(vk, 0, 0x0002, 0)
            for modifier_index = #modifiers, 1, -1 do
                key_user32.keybd_event(modifiers[modifier_index], 0, 0x0002, 0)
            end
            sent = true
        end
    end
    return sent
end

local named_key_vks = {
    enter = 0x0D,
    ['return'] = 0x0D,
    backspace = 0x08,
    bksp = 0x08,
    escape = 0x1B,
    esc = 0x1B,
    tab = 0x09,
    space = 0x20,
    dpad_up = 0x26,
    up = 0x26,
    dpad_down = 0x28,
    down = 0x28,
    dpad_left = 0x25,
    left = 0x25,
    dpad_right = 0x27,
    right = 0x27,
}

local function send_named_key(name)
    if type(name) ~= 'string' then
        return false
    end

    local vk = named_key_vks[name:lower()]
    if not vk then
        return false
    end
    return send_virtual_key(vk)
end

local function send_numpad_key(name)
    if type(name) ~= 'string' then
        return false
    end

    name = name:lower()
    if name == 'dot' or name == '.' then
        return send_virtual_key(0x6E)
    end
    if name == 'enter' then
        return send_confirm_input()
    end

    local digit = tonumber(name)
    if digit == nil or digit < 0 or digit > 9 then
        return false
    end
    return send_virtual_key(0x60 + math.floor(digit))
end

local function step_macro_book(direction)
    active_macro_book = active_macro_book + direction
    if active_macro_book < 1 then
        active_macro_book = 20
    elseif active_macro_book > 20 then
        active_macro_book = 1
    end
end

local function step_macro_set(direction)
    active_macro_set = active_macro_set + direction
    if active_macro_set < 1 then
        active_macro_set = 10
    elseif active_macro_set > 10 then
        active_macro_set = 1
    end
end

local function macro_slot_to_index(modifier, slot)
    slot = tonumber(slot)
    if slot == nil then
        return nil
    end

    slot = math.floor(slot)
    local macro_index = nil
    if slot >= 1 and slot <= 9 then
        macro_index = slot - 1
    elseif slot == 0 then
        macro_index = 9
    end

    if macro_index == nil then
        return nil
    end

    if modifier == 'ctrl' then
        return macro_index, 1, 0x11
    end
    if modifier == 'alt' then
        return macro_index, 2, 0x12
    end

    return nil
end

local function read_macro_lines(index)
    local lines = {}
    if not macro_lib or not macro_lib.get_line then
        return lines
    end

    for line = 0, 5 do
        local ok, text = pcall(macro_lib.get_line, index, line)
        if ok and type(text) == 'string' then
            text = text:gsub('%z', ''):gsub('^%s+', ''):gsub('%s+$', '')
            if text ~= '' then
                lines[#lines + 1] = text
            end
        end
    end

    return lines
end

local function replace_stpc_target(command, party_index)
    local token = ('<p%d>'):format(party_index)
    return command:gsub('<[sS][tT][pP][cC]>', token)
end

local function queue_macro_command(command)
    if type(command) ~= 'string' then
        return false
    end

    command = command:gsub('^%s+', ''):gsub('%s+$', '')
    if command == '' then
        return false
    end

    local chatManager = AshitaCore:GetChatManager()
    if not chatManager then
        return false
    end

    chatManager:QueueCommand(2, command)
    return true
end

local function wait_delay_for_line(line)
    local delay = line:match('^/[wW][aA][iI][tT]%s*(%d*%.?%d*)') or
        line:match('^/[pP][aA][uU][sS][eE]%s*(%d*%.?%d*)') or
        line:match('^/[sS][lL][eE][eE][pP]%s*(%d*%.?%d*)')
    if delay ~= nil then
        delay = tonumber(delay)
        return delay and delay > 0 and delay or 1
    end
    return nil
end

local function strip_inline_wait(line)
    local delay = line:match('%s*<[wW][aA][iI][tT]%s+(%d*%.?%d+)>%s*$')
    if delay == nil then
        return line, nil
    end

    local stripped = line:gsub('%s*<[wW][aA][iI][tT]%s+%d*%.?%d+>%s*$', '')
    return stripped, tonumber(delay)
end

local function start_targeted_macro(modifier, slot, party_index)
    party_index = clamp_integer(party_index, 0, 5)
    if party_index == nil then
        return false
    end

    local base_index = macro_slot_to_index(modifier, slot)
    if base_index == nil then
        return false
    end

    local macro_index = modifier == 'alt' and base_index + 10 or base_index
    local lines = read_macro_lines(macro_index)
    if #lines == 0 then
        return false
    end

    targeted_macro_sequence = targeted_macro_sequence + 1
    pending_targeted_macro = {
        id = targeted_macro_sequence,
        lines = lines,
        party_index = party_index,
        index = 1,
        next_at = os.clock(),
    }
    return true
end

local function process_pending_targeted_macro()
    local macro = pending_targeted_macro
    if macro == nil then
        return
    end

    local now = os.clock()
    if now < macro.next_at then
        return
    end

    local line = macro.lines[macro.index]
    if line == nil then
        pending_targeted_macro = nil
        return
    end

    macro.index = macro.index + 1
    local wait_delay = wait_delay_for_line(line)
    if wait_delay ~= nil then
        macro.next_at = now + wait_delay
        return
    end

    line = replace_stpc_target(line, macro.party_index)
    line, wait_delay = strip_inline_wait(line)
    queue_macro_command(line)
    if wait_delay ~= nil and wait_delay > 0 then
        macro.next_at = now + wait_delay
    else
        macro.next_at = now + 0.05
    end
end

local function run_macro_input(modifier, slot)
    local macro_index, modifier_index, modifier_vk = macro_slot_to_index(modifier, slot)
    if macro_index == nil then
        return
    end

    slot = tonumber(slot) or 0
    local slot_vk = slot == 0 and 0x30 or 0x30 + slot

    if modifier_index and macro_lib and macro_lib.run then
        pcall(macro_lib.run, modifier_index, macro_index)
        return
    end

    if modifier_vk then
        send_key_combo(modifier_vk, slot_vk)
    end
end

local function change_macro_page(direction)
    if macro_lib and macro_lib.set_page then
        step_macro_set(direction)
        pcall(macro_lib.set_page, active_macro_set - 1)
        return
    end

    local key_vk = direction < 0 and 0x26 or 0x28
    send_key_combo(0x11, key_vk)
end

local function handle_macro_input(command)
    if command:sub(1, #macro_input_prefix) ~= macro_input_prefix then
        return false
    end

    local action = command:sub(#macro_input_prefix + 1)
    if action == 'page_up' then
        change_macro_page(-1)
        return true
    end
    if action == 'page_down' then
        change_macro_page(1)
        return true
    end
    if action == 'confirm' then
        send_confirm_action()
        return true
    end
    if action == 'cancel' then
        send_cancel_action()
        return true
    end

    local targeted_modifier, targeted_slot, targeted_party = action:match('^targeted:(%a+):(%d+):(%d+)$')
    if targeted_modifier and targeted_slot and targeted_party then
        start_targeted_macro(targeted_modifier, targeted_slot, targeted_party)
        return true
    end

    local text = action:match('^text:(.*)$')
    if text then
        send_text_input(text)
        return true
    end

    local named_key = action:match('^key:(.+)$')
    if named_key then
        send_named_key(named_key)
        return true
    end

    local numpad_key = action:match('^numpad:(.+)$')
    if numpad_key then
        send_numpad_key(numpad_key)
        return true
    end

    local modifier, slot = action:match('^(%a+):(%d+)$')
    if modifier and slot then
        run_macro_input(modifier, slot)
    end
    return true
end

local job_names = {
    '---', 'WAR', 'MNK', 'WHM', 'BLM', 'RDM', 'THF', 'PLD', 'DRK', 'BST',
    'BRD', 'RNG', 'SAM', 'NIN', 'DRG', 'SMN', 'BLU', 'COR', 'PUP', 'DNC',
    'SCH', 'GEO', 'RUN', '??', '??', '??', '??', '??', '??', '??', '??', '??'
}

local function get_job_name(id)
    id = tonumber(id) or 0
    return job_names[id + 1] or ('JOB_' .. tostring(id))
end

local function get_status_icon_name(resourceManager, id)
    if not resourceManager then
        return nil
    end

    local ok, icon = pcall(function()
        return resourceManager:GetStatusIconById(id)
    end)
    if not ok or not icon then
        return nil
    end

    local description = nil
    if icon.Description then
        if type(icon.Description) == 'table' then
            description = icon.Description[3] or icon.Description[2] or icon.Description[1]
        else
            local descriptionOk, value = pcall(function()
                return icon.Description[2]
            end)
            if descriptionOk then
                description = value
            end
        end
    end

    if not description then
        return nil
    end

    local name = tostring(description)
    if name == '' or name == 'nil' then
        return nil
    end

    return name
end

local function build_active_buffs(player, resourceManager)
    local activeBuffs = {}
    if not player then
        return activeBuffs
    end

    local ok, buffs = pcall(function()
        return player:GetBuffs()
    end)
    if not ok or not buffs then
        return activeBuffs
    end

    for index = 0, 31 do
        local valueOk, buffId = pcall(function()
            return tonumber(buffs[index])
        end)
        if valueOk and buffId and buffId > 0 then
            local buff = { id = buffId }
            local name = get_status_icon_name(resourceManager, buffId)
            if name then
                buff.name = name
            end
            table.insert(activeBuffs, buff)
        end
    end

    return activeBuffs
end

local function call_object_method(object, method_name, ...)
    if not object or not method_name then
        return nil
    end

    local args = { ... }
    local ok, value = pcall(function()
        return object[method_name](object, unpack(args))
    end)
    if ok then
        return value
    end

    return nil
end

local function read_object_field(object, field_name)
    if not object or not field_name then
        return nil
    end

    local ok, value = pcall(function()
        return object[field_name]
    end)
    if ok then
        return value
    end

    return nil
end

local function read_player_experience(player)
    if not player then
        return 0, 0, 0
    end

    local currentExp = tonumber(call_object_method(player, 'GetExpCurrent')) or 0
    local expNeeded = tonumber(call_object_method(player, 'GetExpNeeded')) or 0

    if currentExp <= 0 then
        currentExp =
            tonumber(call_object_method(player, 'GetEXPCurrent')) or
            tonumber(call_object_method(player, 'GetExperience')) or
            tonumber(call_object_method(player, 'GetEXP')) or
            tonumber(read_object_field(player, 'EXPCurrent')) or
            tonumber(read_object_field(player, 'ExpCurrent')) or
            tonumber(read_object_field(player, 'Experience')) or
            tonumber(read_object_field(player, 'EXP')) or
            0
    end

    if expNeeded <= 0 then
        expNeeded =
            tonumber(call_object_method(player, 'GetEXPNeeded')) or
            tonumber(call_object_method(player, 'GetExpMax')) or
            tonumber(call_object_method(player, 'GetEXPMax')) or
            tonumber(read_object_field(player, 'EXPNeeded')) or
            tonumber(read_object_field(player, 'ExpNeeded')) or
            tonumber(read_object_field(player, 'EXPMax')) or
            0
    end

    local expToNext =
        tonumber(call_object_method(player, 'GetEXPToNextLevel')) or
        tonumber(call_object_method(player, 'GetExpToNextLevel')) or
        tonumber(call_object_method(player, 'GetEXPNext')) or
        tonumber(call_object_method(player, 'GetExpNext')) or
        tonumber(call_object_method(player, 'GetTNL')) or
        tonumber(read_object_field(player, 'EXPToNextLevel')) or
        tonumber(read_object_field(player, 'ExpToNextLevel')) or
        tonumber(read_object_field(player, 'EXPNext')) or
        tonumber(read_object_field(player, 'TNL'))

    if expToNext == nil and expNeeded > 0 then
        expToNext = expNeeded - currentExp
    end
    expToNext = math.max(0, tonumber(expToNext) or 0)

    return math.floor(currentExp), math.floor(expToNext), math.floor(expNeeded)
end

local function close_connection()
    if client then
        pcall(function() client:close() end)
        client = nil
    end
end

local function connect_client()
    if client then
        return true
    end
    if not socket then
        return false
    end

    local s, err = socket.tcp()
    if not s then
        return false
    end

    s:settimeout(1.0)
    local ok, connect_err = s:connect(host, port)
    if not ok then
        pcall(function() s:close() end)
        return false
    end

    s:settimeout(0)
    client = s
    if not was_connected then
        print(('VanaDeck addon: connected to app on %s:%d.'):format(host, port))
        was_connected = true
    end
    return true
end

local function queue_game_command(command)
    if type(command) ~= 'string' then
        return
    end

    command = command:gsub('^%s+', ''):gsub('%s+$', '')
    if command == '' or #command > max_command_length then
        return
    end

    local handled = false
    local ok, err = pcall(function()
        handled = handle_macro_input(command)
    end)
    if not ok then
        print(('VanaDeck addon: macro input failed: %s'):format(tostring(err)))
        return
    end
    if handled then
        return
    end

    if text_encoding then
        command = text_encoding.utf8_to_shiftjis(command)
    end

    local chatManager = AshitaCore:GetChatManager()
    if chatManager then
        chatManager:QueueCommand(1, command)
    end
end

local function normalize_chat_mode(mode)
    mode = tonumber(mode) or 0
    if bit and bit.band then
        return bit.band(mode, 0x000000FF)
    end
    return mode
end

local function normalize_chat_color(color)
    color = tonumber(color)
    if color == nil or color <= 0 then
        return nil
    end
    color = math.floor(color)
    if color <= 0xFFFFFF then
        return 0xFF000000 + color
    end
    return color
end

local function first_nonzero_number(...)
    for index = 1, select('#', ...) do
        local candidate = select(index, ...)
        local value = tonumber(candidate)
        if value ~= nil and value ~= 0 then
            return value
        end
    end
    return nil
end

local function clean_chat_message(message)
    if type(message) ~= 'string' then
        return nil
    end

    message = message:gsub('^%s+', ''):gsub('%s+$', '')
    if message == '' then
        return nil
    end

    local chatManager = AshitaCore:GetChatManager()
    if chatManager then
        local ok, parsed = pcall(function()
            return chatManager:ParseAutoTranslate(message, true)
        end)
        if ok and type(parsed) == 'string' then
            message = parsed
        end
    end

    if message.strip_colors then
        message = message:strip_colors()
    end
    if message.strip_translate then
        message = message:strip_translate(true)
    end

    message = message:gsub(string.char(0x07), '\n')
    message = shiftjis_to_utf8_if_needed(message)
    message = message:gsub('^%s+', ''):gsub('%s+$', '')
    if message == '' then
        return nil
    end

    return message
end

local function append_chat_message(mode, message, direction, blocked, color)
    message = clean_chat_message(message)
    if not message then
        return
    end

    mode = normalize_chat_mode(mode)
    direction = direction or 'in'
    local now = os.clock()
    local duplicate_key = table.concat({
        direction,
        message,
    }, '\31')
    if duplicate_key == last_chat_message_key and
        (now - last_chat_message_at) <= chat_duplicate_window then
        return
    end
    last_chat_message_key = duplicate_key
    last_chat_message_at = now

    chat_sequence = chat_sequence + 1
    table.insert(chat_messages, {
        id = chat_sequence,
        mode = mode,
        text = message,
        color = normalize_chat_color(color),
        time = os.time(),
        direction = direction,
        blocked = blocked and true or false,
    })

    while #chat_messages > max_chat_messages do
        table.remove(chat_messages, 1)
    end
end

local function copy_chat_messages()
    local messages = {}
    for index = 1, #chat_messages do
        local message = chat_messages[index]
        messages[index] = {
            id = message.id,
            mode = message.mode,
            text = message.text,
            color = message.color,
            time = message.time,
            direction = message.direction,
            blocked = message.blocked,
        }
    end
    return messages
end

local function capture_text_event(e, direction)
    if not e then
        return
    end

    local message = e.message_modified
    if type(message) ~= 'string' or message == '' then
        message = e.message
    end

    if type(message) == 'string' then
        local visibleMessage = clean_chat_message(message)
        if not visibleMessage then
            return
        end

        local trimmed = visibleMessage:gsub('^%s+', ''):gsub('%s+$', '')
        if trimmed:sub(1, #macro_input_prefix) == macro_input_prefix then
            return
        end
        if direction == 'out' and trimmed:sub(1, 1) == '/' then
            return
        end
        message = visibleMessage
    end

    append_chat_message(
        first_nonzero_number(e.mode_modified, e.mode) or 0,
        message,
        direction,
        e.blocked,
        first_nonzero_number(
            e.color_modified,
            e.color,
            e.text_color,
            e.textColor,
            e.message_color,
            e.messageColor))
end

local function receive_commands()
    if not client or not client.receive then
        return
    end

    for _ = 1, max_commands_per_frame do
        local line, err = client:receive('*l')
        if not line then
            if err == 'closed' then
                was_connected = false
                close_connection()
            end
            return
        end

        queue_game_command(line)
    end
end

local function normalize_coordinate(value, scale)
    local v = tonumber(value) or 0
    if type(v) ~= 'number' then
        v = 0
    end
    return math.max(0, math.min(1, v / scale))
end

local function estimate_max(current, percent)
    if type(current) ~= 'number' or type(percent) ~= 'number' or percent <= 0 then
        return 0
    end

    return math.floor((current * 100 / percent) + 0.5)
end

local function get_entity_coordinates(entity, mapScale)
    if not entity or not entity.Movement or not entity.Movement.LocalPosition then
        return 0, 0, 0, 0, 0, 0
    end

    local position = entity.Movement.LocalPosition
    local worldX = tonumber(position.X) or 0
    local worldY = tonumber(position.Y) or 0
    local worldZ = tonumber(position.Z) or 0
    local heading = tonumber(position.Yaw) or 0

    return normalize_coordinate(worldX, mapScale),
        normalize_coordinate(worldY, mapScale),
        worldX,
        worldY,
        worldZ,
        heading
end

local function get_sub_map_num(player)
    if not player then
        return 0
    end

    local ok, subMapNum = pcall(function()
        return player:GetSubMapNum()
    end)
    if not ok then
        return 0
    end

    return tonumber(subMapNum) or 0
end

local function build_party_member(party, entityInterface, mapScale, index, zoneName, zoneId, subMapNum)
    if not party or not entityInterface then
        return nil
    end

    if party:GetMemberIsActive(index) == 0 or party:GetMemberServerId(index) == 0 then
        return nil
    end

    local targetIndex = party:GetMemberTargetIndex(index)
    if not targetIndex or targetIndex < 0 then
        return nil
    end

    local entity = GetEntity(targetIndex)
    local name = party:GetMemberName(index) or ''
    if name == '' and entity then
        name = entity.Name or ''
    end
    if name == '' then
        return nil
    end

    local currentHp = party:GetMemberHP(index) or 0
    local currentMp = party:GetMemberMP(index) or 0
    local locationX, locationY, worldX, worldY, worldZ, heading = get_entity_coordinates(entity, mapScale)

    return {
        name = name,
        job = get_job_name(party:GetMemberMainJob(index) or 0),
        subjob = get_job_name(party:GetMemberSubJob(index) or 0),
        location = zoneName,
        zoneId = zoneId,
        subMapNum = subMapNum,
        locationX = locationX,
        locationY = locationY,
        worldX = worldX,
        worldY = worldY,
        worldZ = worldZ,
        heading = heading,
        level = party:GetMemberMainJobLevel(index) or 0,
        currentHp = currentHp,
        maxHp = estimate_max(currentHp, party:GetMemberHPPercent(index) or 0),
        currentMp = currentMp,
        maxMp = estimate_max(currentMp, party:GetMemberMPPercent(index) or 0),
    }
end

local town_zones = {
    ["southern san d'oria"] = true,
    ["northern san d'oria"] = true,
    ["port san d'oria"] = true,
    ["chateau d'oraguille"] = true,
    ["bastok mines"] = true,
    ["bastok markets"] = true,
    ["port bastok"] = true,
    ["metalworks"] = true,
    ["windurst waters"] = true,
    ["windurst walls"] = true,
    ["port windurst"] = true,
    ["windurst woods"] = true,
    ["heavens tower"] = true,
    ["ru'lude gardens"] = true,
    ["upper jeuno"] = true,
    ["lower jeuno"] = true,
    ["port jeuno"] = true,
    ["aht urhgan whitegate"] = true,
    ["al zahbi"] = true,
    ["nashmau"] = true,
    ["western adoulin"] = true,
    ["eastern adoulin"] = true,
    ["mog garden"] = true,
    ["leafallia"] = true,
    ["selbina"] = true,
    ["mhaura"] = true,
    ["rabao"] = true,
    ["norg"] = true,
    ["kazham"] = true,
    ["tavnazian safehold"] = true,
}

local function is_town_zone(zoneName)
    if type(zoneName) ~= 'string' then
        return false
    end

    return town_zones[string.lower(zoneName)] == true
end

local function build_npc_data(entityInterface, mapScale, zoneName, zoneId, subMapNum, zoneIsTown)
    local npcs = {}
    if not entityInterface then
        return npcs
    end

    local entityCount = entityInterface:GetEntityMapSize() or 2048
    for idx = 0, entityCount - 1 do
        local entity = GetEntity(idx)
        if entity and entity.Name and entity.Name ~= '' then
            local entityType = tonumber(entity.Type) or -1
            if entityType == 1 or entityType == 2 then
                local locationX, locationY, worldX, worldY, worldZ, heading = get_entity_coordinates(entity, mapScale)
                local hpPercent = tonumber(entity.HPPercent) or 0
                local kind = 'npc'
                if entityType == 2 and not zoneIsTown then
                    kind = 'mob'
                end
                npcs[#npcs + 1] = {
                    name = entity.Name,
                    type = entityType,
                    kind = kind,
                    hpPercent = hpPercent,
                    status = tonumber(entity.Status) or 0,
                    claimStatus = tonumber(entity.ClaimStatus) or 0,
                    location = zoneName,
                    zoneId = zoneId,
                    subMapNum = subMapNum,
                    locationX = locationX,
                    locationY = locationY,
                    worldX = worldX,
                    worldY = worldY,
                    worldZ = worldZ,
                    heading = heading,
                }
            end
        end
    end

    return npcs
end

local function get_active_party_count(party)
    if not party then
        return 0
    end

    local count = 0
    for idx = 0, 5 do
        if party:GetMemberIsActive(idx) ~= 0 and party:GetMemberServerId(idx) ~= 0 then
            count = count + 1
        end
    end
    return count
end

local function normalize_party_index(party, index)
    local count = get_active_party_count(party)
    if count <= 0 then
        return nil
    end

    index = tonumber(index) or 0
    index = math.floor(index)
    while index < 0 do
        index = index + count
    end
    while index >= count do
        index = index - count
    end
    return index
end

local function is_subtarget_active()
    local memory = AshitaCore:GetMemoryManager()
    if not memory then
        return false
    end

    local targetInterface = memory:GetTarget()
    if not targetInterface then
        return false
    end

    local ok, active = pcall(function()
        return targetInterface:GetIsSubTargetActive()
    end)
    return ok and tonumber(active) ~= 0
end

local function build_party_target_data(party, partyIndex, zoneName, zoneId, subMapNum, source)
    partyIndex = normalize_party_index(party, partyIndex)
    if partyIndex == nil then
        return nil
    end

    local currentHp = party:GetMemberHP(partyIndex) or 0
    local currentMp = party:GetMemberMP(partyIndex) or 0
    local targetIndex = party:GetMemberTargetIndex(partyIndex)
    return {
        name = party:GetMemberName(partyIndex) or '',
        type = nil,
        kind = 'party',
        hpPercent = party:GetMemberHPPercent(partyIndex) or 0,
        targetIndex = targetIndex,
        partyIndex = partyIndex,
        targetSource = source,
        location = zoneName,
        zoneId = zoneId,
        subMapNum = subMapNum,
        currentHp = currentHp,
        maxHp = estimate_max(currentHp, party:GetMemberHPPercent(partyIndex) or 0),
        currentMp = currentMp,
        maxMp = estimate_max(currentMp, party:GetMemberMPPercent(partyIndex) or 0),
    }
end

local function build_active_target(memory, party, zoneName, zoneId, subMapNum, zoneIsTown)
    if not memory or not party then
        return nil
    end

    local targetInterface = memory:GetTarget()
    if not targetInterface then
        return nil
    end

    local function read_target_index(slot)
        local ok, value = pcall(function()
            return targetInterface:GetTargetIndex(slot)
        end)
        if ok then
            value = tonumber(value) or 0
            if value > 0 then
                return value
            end
        end
        return nil
    end

    local function read_subtarget_index()
        local okActive, active = pcall(function()
            return targetInterface:GetIsSubTargetActive()
        end)
        if okActive then
            local okDynamic, dynamicValue = pcall(function()
                return targetInterface:GetTargetIndex(active)
            end)
            if okDynamic then
                dynamicValue = tonumber(dynamicValue) or 0
                if dynamicValue > 0 then
                    return dynamicValue, 'dynamic_subtarget'
                end
            end
        end

        local ok, value = pcall(function()
            return targetInterface:GetSubTargetIndex()
        end)
        if ok then
            value = tonumber(value) or 0
            if value > 0 then
                return value, 'subtarget'
            end
        end
        return nil
    end

    local function read_entity(targetIndex)
        if not targetIndex then
            return nil
        end

        local entity = GetEntity(targetIndex)
        if entity and entity.Name and entity.Name ~= '' then
            return entity
        end

        local entityInterface = memory:GetEntity()
        if entityInterface then
            local ok, targetEntity = pcall(function()
                return entityInterface:GetTargetByIndex(targetIndex)
            end)
            if ok and targetEntity and targetEntity.Name and targetEntity.Name ~= '' then
                return targetEntity
            end
        end

        return entity
    end

    local function find_party_index(targetIndex)
        if not targetIndex then
            return nil
        end

        for idx = 0, 5 do
            local memberTargetIndex = party:GetMemberTargetIndex(idx)
            if memberTargetIndex and tonumber(memberTargetIndex) == targetIndex then
                return idx
            end
        end

        return nil
    end

    local targetIndex = nil
    local targetSlot = nil
    local subTargetOk, subTargetActive = pcall(function()
        return targetInterface:GetIsSubTargetActive()
    end)
    local subTargetIsActive = subTargetOk and tonumber(subTargetActive) ~= 0
    if subTargetIsActive
        and manual_subtarget_party_index ~= nil
        and os.clock() <= manual_subtarget_expires_at then
        return build_party_target_data(
            party,
            manual_subtarget_party_index,
            zoneName,
            zoneId,
            subMapNum,
            'app_subtarget')
    end

    if subTargetIsActive then
        targetIndex, targetSlot = read_subtarget_index()

        for slot = 1, 8 do
            local candidateIndex = read_target_index(slot)
            if candidateIndex and find_party_index(candidateIndex) then
                targetIndex = candidateIndex
                targetSlot = slot
                break
            end
            if not targetIndex and candidateIndex then
                targetIndex = candidateIndex
                targetSlot = slot
            end
        end
    end
    if not targetIndex then
        targetIndex = read_target_index(0)
        targetSlot = targetIndex and 0 or nil
    end
    if not targetIndex then
        if subTargetIsActive and manual_subtarget_party_index ~= nil then
            return build_party_target_data(
                party,
                manual_subtarget_party_index,
                zoneName,
                zoneId,
                subMapNum,
                'manual_subtarget')
        end
        return nil
    end

    if subTargetIsActive and targetSlot == 0 and manual_subtarget_party_index ~= nil then
        return build_party_target_data(
            party,
            manual_subtarget_party_index,
            zoneName,
            zoneId,
            subMapNum,
            'xinput_subtarget')
    end

    local entity = read_entity(targetIndex)
    if not entity or not entity.Name or entity.Name == '' then
        return nil
    end

    local kind = 'unknown'
    local partyIndex = find_party_index(targetIndex)
    if subTargetIsActive and partyIndex == nil and manual_subtarget_party_index ~= nil then
        return build_party_target_data(
            party,
            manual_subtarget_party_index,
            zoneName,
            zoneId,
            subMapNum,
            'manual_subtarget')
    end

    if partyIndex then
        kind = 'party'
        manual_subtarget_party_index = subTargetIsActive and partyIndex or manual_subtarget_party_index
        if subTargetIsActive then
            manual_subtarget_expires_at = 0
        end
    end

    local entityType = tonumber(entity.Type) or -1
    if kind == 'unknown' then
        if entityType == 2 and not zoneIsTown then
            kind = 'mob'
        elseif entityType == 1 or entityType == 2 then
            kind = 'npc'
        end
    end

    local targetData = {
        name = entity.Name,
        type = entityType,
        kind = kind,
        hpPercent = tonumber(entity.HPPercent) or 0,
        status = tonumber(entity.Status) or 0,
        claimStatus = tonumber(entity.ClaimStatus) or 0,
        targetIndex = targetIndex,
        targetSlot = targetSlot,
        isSubTargetActive = subTargetIsActive,
        location = zoneName,
        zoneId = zoneId,
        subMapNum = subMapNum,
    }

    if partyIndex then
        local currentHp = party:GetMemberHP(partyIndex) or 0
        local currentMp = party:GetMemberMP(partyIndex) or 0
        targetData.currentHp = currentHp
        targetData.maxHp = estimate_max(currentHp, party:GetMemberHPPercent(partyIndex) or 0)
        targetData.currentMp = currentMp
        targetData.maxMp = estimate_max(currentMp, party:GetMemberMPPercent(partyIndex) or 0)
    end

    return targetData
end

local function build_status()
    local memory = AshitaCore:GetMemoryManager()
    if not memory then
        return nil
    end

    local player = memory:GetPlayer()
    local party = memory:GetParty()
    if not player or not party then
        return nil
    end

    local resourceManager = AshitaCore:GetResourceManager()
    local zoneId = party:GetMemberZone(0) or 0
    local zoneName = ''
    if resourceManager then
        zoneName = resourceManager:GetString('zones.names', zoneId) or ''
    end
    local zoneIsTown = is_town_zone(zoneName)
    local subMapNum = get_sub_map_num(player)
    local activeBuffs = build_active_buffs(player, resourceManager)

    local entityInterface = memory:GetEntity()
    local mapScale = 2048.0
    if entityInterface then
        local entityMapSize = entityInterface:GetEntityMapSize()
        if type(entityMapSize) == 'number' and entityMapSize > 0 then
            mapScale = entityMapSize
        end
    end

    local playerEntity = GetPlayerEntity()
    local playerX, playerY, playerWorldX, playerWorldY, playerWorldZ, playerHeading = get_entity_coordinates(playerEntity, mapScale)
    local playerName = party:GetMemberName(0) or ''
    if playerName == '' and playerEntity then
        playerName = playerEntity.Name or ''
    end
    local playerHp = party:GetMemberHP(0) or 0
    local playerMp = party:GetMemberMP(0) or 0
    local playerMaxHp = player:GetHPMax() or estimate_max(playerHp, party:GetMemberHPPercent(0) or 0)
    local playerMaxMp = player:GetMPMax() or estimate_max(playerMp, party:GetMemberMPPercent(0) or 0)
    local macroState = update_active_macro_state()
    local subTargetActive = is_subtarget_active()
    local activeTarget = build_active_target(memory, party, zoneName, zoneId, subMapNum, zoneIsTown)
    local currentExp, expToNextLevel, expNeeded = read_player_experience(player)
    local playerLevel = player:GetMainJobLevel() or 0

    local status = {
        player = {
            name = playerName,
            job = get_job_name(player:GetMainJob()),
            subjob = get_job_name(player:GetSubJob()),
            level = playerLevel,
            currentHp = playerHp,
            maxHp = playerMaxHp,
            currentMp = playerMp,
            maxMp = playerMaxMp,
            tp = party:GetMemberTP(0) or 0,
            currentExp = currentExp,
            expToNextLevel = expToNextLevel,
            expNeeded = expNeeded,
            activeBuffs = activeBuffs,
            location = zoneName,
            zoneId = zoneId,
            subMapNum = subMapNum,
            locationX = playerX,
            locationY = playerY,
            worldX = playerWorldX,
            worldY = playerWorldY,
            worldZ = playerWorldZ,
            heading = playerHeading,
            activeMacroBook = macroState.activeBook,
            activeMacroSet = macroState.activeSet,
            isSubTargetActive = subTargetActive,
            activeTarget = activeTarget,
        },
        partyMembers = {},
        party = {},
        npcs = {},
        target = activeTarget,
        isSubTargetActive = subTargetActive,
        macro = macroState,
        chatMessages = copy_chat_messages(),
        level = playerLevel,
        currentExp = currentExp,
        expToNextLevel = expToNextLevel,
        expNeeded = expNeeded,
        zone = zoneName,
        zoneId = zoneId,
        subMapNum = subMapNum,
    }

    local playerData = {
        name = playerName,
        job = get_job_name(player:GetMainJob()),
        subjob = get_job_name(player:GetSubJob()),
        location = zoneName,
        zoneId = zoneId,
        subMapNum = subMapNum,
        locationX = playerX,
        locationY = playerY,
        worldX = playerWorldX,
        worldY = playerWorldY,
        worldZ = playerWorldZ,
        heading = playerHeading,
        level = playerLevel,
        currentHp = playerHp,
        maxHp = playerMaxHp,
        currentMp = playerMp,
        maxMp = playerMaxMp,
    }
    status.partyMembers[#status.partyMembers + 1] = playerData
    status.party[#status.party + 1] = playerData

    for idx = 1, 5 do
        local memberData = build_party_member(party, entityInterface, mapScale, idx, zoneName, zoneId, subMapNum)
        if memberData then
            status.partyMembers[#status.partyMembers + 1] = memberData
            status.party[#status.party + 1] = memberData
        end
    end

    status.npcs = build_npc_data(entityInterface, mapScale, zoneName, zoneId, subMapNum, zoneIsTown)

    return status
end

local function send_status()
    if not json then
        return
    end

    local payload = build_status()
    if not payload then
        return
    end

    local connected = connect_client()
    if not connected then
        close_connection()
        return
    end

    local encoded = json.encode(payload) .. '\n'
    local success, err = client:send(encoded)
    if not success then
        if was_connected then
            print('VanaDeck addon: app connection lost.')
        end
        was_connected = false
        close_connection()
    end
end

ashita.events.register('command', 'command_cb', function(e)
    local args = e.command:args()
    if #args < 3 or not args[1]:ieq('/macro') then
        return
    end

    if args[2]:ieq('book') then
        active_macro_book = clamp_integer(args[3], 1, 20) or active_macro_book
        return
    end

    if args[2]:ieq('set') then
        active_macro_set = clamp_integer(args[3], 1, 10) or active_macro_set
    end
end)

ashita.events.register('key', 'key_cb', function(e)
    local key_down = not (bit.band(e.lparam, bit.lshift(0x8000, 0x10)) == bit.lshift(0x8000, 0x10))
    local key = tonumber(e.wparam) or 0

    -- VK_CONTROL, VK_LCONTROL, VK_RCONTROL
    if key == 0x11 or key == 0xA2 or key == 0xA3 then
        ctrl_down = key_down
        return
    end

    if key_down and not ctrl_down and is_subtarget_active() then
        local memory = AshitaCore:GetMemoryManager()
        local party = memory and memory:GetParty()
        if party then
            manual_subtarget_party_index = normalize_party_index(
                party,
                manual_subtarget_party_index or 0)

            if key == 0x26 then -- VK_UP
                manual_subtarget_party_index = normalize_party_index(
                    party,
                    (manual_subtarget_party_index or 0) - 1)
                return
            elseif key == 0x28 then -- VK_DOWN
                manual_subtarget_party_index = normalize_party_index(
                    party,
                    (manual_subtarget_party_index or 0) + 1)
                return
            end
        end
    elseif key_down and not is_subtarget_active() then
        manual_subtarget_party_index = nil
    end

    if not key_down or not ctrl_down then
        return
    end

    -- Mirror the common in-game macro navigation keys so the app title stays
    -- in step when the player changes pages outside of the companion app.
    if key == 0x26 then -- VK_UP
        step_macro_set(-1)
    elseif key == 0x28 then -- VK_DOWN
        step_macro_set(1)
    elseif key == 0x25 or key == 0x21 then -- VK_LEFT or VK_PRIOR/PageUp
        step_macro_book(-1)
    elseif key == 0x27 or key == 0x22 then -- VK_RIGHT or VK_NEXT/PageDown
        step_macro_book(1)
    end
end)

ashita.events.register('text_in', 'text_in_cb', function(e)
    capture_text_event(e, 'in')
end)

ashita.events.register('text_out', 'text_out_cb', function(e)
    capture_text_event(e, 'out')
end)

ashita.events.register('load', 'load_cb', function()
    if not socket then
        print(('VanaDeck addon: socket transport unavailable (%s).'):format(socket_source or 'unknown error'))
        return
    end

    print(('VanaDeck addon: sending status to %s:%d using %s.'):format(host, port, socket_source or 'socket'))
    last_send = os.clock()
end)

ashita.events.register('d3d_present', 'present_cb', function()
    local now = os.clock()
    release_pending_ashita_keys()
    release_pending_xinput_buttons()
    process_pending_targeted_macro()
    receive_commands()
    local subtarget_active = is_subtarget_active()
    local subtarget_changed = subtarget_active ~= last_subtarget_active
    last_subtarget_active = subtarget_active
    local effective_send_interval = subtarget_active and subtarget_send_interval or send_interval
    if subtarget_changed or (now - last_send) >= effective_send_interval then
        send_status()
        last_send = now
    end
end)

ashita.events.register('unload', 'unload_cb', function()
    was_connected = false
    close_connection()
end)
