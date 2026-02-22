local M = {}

local uv = vim.uv or vim.loop

--- Log levels
local LOG_LEVELS = { debug = 1, info = 2, warn = 3, error = 4 }

local current_log_level = "warn"

--- Set the log level
--- @param level string
function M.set_log_level(level)
  current_log_level = level
end

--- Log a message at the given level
--- @param level string
--- @param fmt string
--- @param ... any
function M.log(level, fmt, ...)
  if LOG_LEVELS[level] < LOG_LEVELS[current_log_level] then
    return
  end
  local msg = string.format(fmt, ...)
  local vim_level = ({
    debug = vim.log.levels.DEBUG,
    info = vim.log.levels.INFO,
    warn = vim.log.levels.WARN,
    error = vim.log.levels.ERROR,
  })[level]
  vim.schedule(function()
    vim.notify("[claude-code] " .. msg, vim_level)
  end)
end

function M.log_debug(fmt, ...) M.log("debug", fmt, ...) end
function M.log_info(fmt, ...)  M.log("info", fmt, ...)  end
function M.log_warn(fmt, ...)  M.log("warn", fmt, ...)  end
function M.log_error(fmt, ...) M.log("error", fmt, ...) end

--- Generate UUID v4
--- @return string
function M.generate_uuid()
  -- Seed with high-resolution time
  local seed = uv.hrtime()
  math.randomseed(seed)

  local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
  return (template:gsub("[xy]", function(c)
    local v = (c == "x") and math.random(0, 15) or (math.random(0, 3) + 8)
    return string.format("%x", v)
  end))
end

-------------------------------------------------------------------------------
-- Pure Lua SHA-1 (arithmetic-based bit operations for Lua 5.1 compatibility)
-------------------------------------------------------------------------------

-- 32-bit arithmetic helpers (no bit library needed)
local MOD = 2 ^ 32

local function band(a, b)
  local result = 0
  local bit = 1
  for _ = 0, 31 do
    if a % 2 == 1 and b % 2 == 1 then
      result = result + bit
    end
    a = math.floor(a / 2)
    b = math.floor(b / 2)
    bit = bit * 2
  end
  return result
end

local function bor(a, b)
  local result = 0
  local bit = 1
  for _ = 0, 31 do
    if a % 2 == 1 or b % 2 == 1 then
      result = result + bit
    end
    a = math.floor(a / 2)
    b = math.floor(b / 2)
    bit = bit * 2
  end
  return result
end

local function bxor(a, b)
  local result = 0
  local bit = 1
  for _ = 0, 31 do
    local aa = a % 2
    local bb = b % 2
    if aa ~= bb then
      result = result + bit
    end
    a = math.floor(a / 2)
    b = math.floor(b / 2)
    bit = bit * 2
  end
  return result
end

local function bnot(a)
  return MOD - 1 - a
end

local function lshift(a, n)
  return (a * (2 ^ n)) % MOD
end

local function rshift(a, n)
  return math.floor(a / (2 ^ n)) % MOD
end

local function lrotate(a, n)
  return bor(lshift(a, n), rshift(a, 32 - n))
end

--- Pure Lua SHA-1
--- @param data string
--- @return string binary 20-byte hash
function M.sha1(data)
  -- Pre-processing: padding
  local len = #data
  local bit_len = len * 8

  -- Append bit '1' (0x80) + zeros + 64-bit length
  data = data .. "\128" -- 0x80
  local pad_len = (56 - (len + 1) % 64) % 64
  data = data .. string.rep("\0", pad_len)

  -- Append original length as 64-bit big-endian
  data = data .. string.char(
    0, 0, 0, 0, -- upper 32 bits (we only handle messages < 2^32 bits)
    math.floor(bit_len / (2 ^ 24)) % 256,
    math.floor(bit_len / (2 ^ 16)) % 256,
    math.floor(bit_len / (2 ^ 8)) % 256,
    bit_len % 256
  )

  -- Initialize hash values
  local h0 = 0x67452301
  local h1 = 0xEFCDAB89
  local h2 = 0x98BADCFE
  local h3 = 0x10325476
  local h4 = 0xC3D2E1F0

  -- Process each 512-bit (64-byte) chunk
  for chunk_start = 1, #data, 64 do
    local w = {}

    -- Break chunk into sixteen 32-bit big-endian words
    for i = 0, 15 do
      local b1, b2, b3, b4 = data:byte(chunk_start + i * 4, chunk_start + i * 4 + 3)
      w[i] = b1 * 0x1000000 + b2 * 0x10000 + b3 * 0x100 + b4
    end

    -- Extend to 80 words
    for i = 16, 79 do
      w[i] = lrotate(bxor(bxor(w[i - 3], w[i - 8]), bxor(w[i - 14], w[i - 16])), 1)
    end

    local a, b, c, d, e = h0, h1, h2, h3, h4

    for i = 0, 79 do
      local f, k
      if i <= 19 then
        f = bor(band(b, c), band(bnot(b), d))
        k = 0x5A827999
      elseif i <= 39 then
        f = bxor(bxor(b, c), d)
        k = 0x6ED9EBA1
      elseif i <= 59 then
        f = bor(bor(band(b, c), band(b, d)), band(c, d))
        k = 0x8F1BBCDC
      else
        f = bxor(bxor(b, c), d)
        k = 0xCA62C1D6
      end

      local temp = (lrotate(a, 5) + f + e + k + w[i]) % MOD
      e = d
      d = c
      c = lrotate(b, 30)
      b = a
      a = temp
    end

    h0 = (h0 + a) % MOD
    h1 = (h1 + b) % MOD
    h2 = (h2 + c) % MOD
    h3 = (h3 + d) % MOD
    h4 = (h4 + e) % MOD
  end

  -- Produce the 20-byte binary digest
  local function to_bytes(n)
    return string.char(
      math.floor(n / 0x1000000) % 256,
      math.floor(n / 0x10000) % 256,
      math.floor(n / 0x100) % 256,
      n % 256
    )
  end

  return to_bytes(h0) .. to_bytes(h1) .. to_bytes(h2) .. to_bytes(h3) .. to_bytes(h4)
end

--- Base64 encode
--- @param data string
--- @return string
function M.base64_encode(data)
  return vim.base64.encode(data)
end

--- Generate WebSocket Sec-WebSocket-Accept key
--- @param client_key string The Sec-WebSocket-Key from client
--- @return string
function M.generate_accept_key(client_key)
  local magic = "258EAFA5-E914-47DA-95CA-5AB5ADF653D0"
  local hash = M.sha1(client_key .. magic)
  return M.base64_encode(hash)
end

--- Parse HTTP request headers
--- @param request string
--- @return table headers, string method, string path
function M.parse_http_headers(request)
  local lines = {}
  for line in request:gmatch("[^\r\n]+") do
    lines[#lines + 1] = line
  end

  if #lines == 0 then
    return {}, "", ""
  end

  -- Parse request line: "GET /path HTTP/1.1"
  local method, path = lines[1]:match("^(%S+)%s+(%S+)")
  method = method or ""
  path = path or ""

  local headers = {}
  for i = 2, #lines do
    local key, value = lines[i]:match("^([^:]+):%s*(.*)")
    if key then
      headers[key:lower()] = value
    end
  end

  return headers, method, path
end

--- Apply XOR mask to data (WebSocket frame unmasking)
--- Optimized: collects raw byte values and converts via string.char in chunks,
--- avoiding per-byte string allocations while respecting Lua's unpack stack limit.
--- @param data string
--- @param mask string 4-byte mask key
--- @return string
function M.apply_mask(data, mask)
  local len = #data
  local bytes = { data:byte(1, len) }
  local m1, m2, m3, m4 = mask:byte(1, 4)
  local mask_bytes = { m1, m2, m3, m4 }
  local result = {}
  for i = 1, len do
    result[i] = bxor(bytes[i], mask_bytes[((i - 1) % 4) + 1])
  end
  -- Convert byte values to string in chunks to avoid unpack stack overflow
  local CHUNK = 4096
  local parts = {}
  for i = 1, len, CHUNK do
    local j = math.min(i + CHUNK - 1, len)
    parts[#parts + 1] = string.char(unpack(result, i, j))
  end
  return table.concat(parts)
end

return M
