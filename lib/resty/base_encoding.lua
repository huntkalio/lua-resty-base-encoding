local error = error
local tostring = tostring
local type = type
local floor = math.floor
local base = require "resty.core.base"
local get_string_buf = base.get_string_buf
local ffi = require "ffi"
local ffi_string = ffi.string


local _M = { version = "0.1"}


local function load_shared_lib(so_name)
    local tried_paths = {}
    local i = 1

    for k, _ in package.cpath:gmatch("[^;]+") do
        local fpath = k:match("(.*/)")
        fpath = fpath .. so_name
        local f = io.open(fpath)
        if f ~= nil then
            io.close(f)
            return ffi.load(fpath)
        end
        tried_paths[i] = fpath
        i = i + 1
    end

    tried_paths[#tried_paths + 1] =
        'tried above paths but can not load ' .. so_name
    error(table.concat(tried_paths, '\r\n', 1, #tried_paths))
end
local encoding = load_shared_lib("librestybaseencoding.so")


ffi.cdef([[
size_t modp_b64_encode(char* dest, const char* str, size_t len,
    uint32_t no_padding);
size_t modp_b64_decode(char* dest, const char* src, size_t len);
]])


local function base64_encoded_length(len, no_padding)
    return no_padding and floor((len * 8 + 5) / 6) or
           floor((len + 2) / 3) * 4
end


function _M.encode_base64(s, no_padding)
    if type(s) ~= 'string' then
        if not s then
            s = ''
        else
            s = tostring(s)
        end
    end

    local slen = #s
    local no_padding_bool = false
    local no_padding_int  = 0

    if no_padding then
        if no_padding ~= true then
            return error("boolean argument only")
        end

        no_padding_bool = true
        no_padding_int  = 1
    end

    local dlen = base64_encoded_length(slen, no_padding_bool)
    local dst = get_string_buf(dlen)
    local r_dlen = encoding.modp_b64_encode(dst, s, slen, no_padding_int)
    return ffi_string(dst, r_dlen)
end


local function base64_decoded_length(len)
    return floor((len + 3) / 4) * 3
end


function _M.decode_base64(s)
    if type(s) ~= 'string' then
        return error("string argument only")
    end

    local slen = #s
    local dlen = base64_decoded_length(slen)
    local dst = get_string_buf(dlen)
    local r_dlen = encoding.modp_b64_decode(dst, s, slen)
    if r_dlen == -1 then
        return nil
    end
    return ffi_string(dst, r_dlen)
end


return _M