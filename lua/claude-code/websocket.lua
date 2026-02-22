local util = require("claude-code.util")

local M = {}

-- WebSocket opcodes
M.OPCODE = {
  CONTINUATION = 0x0,
  TEXT = 0x1,
  BINARY = 0x2,
  CLOSE = 0x8,
  PING = 0x9,
  PONG = 0xA,
}

--- Validate a WebSocket upgrade request
--- @param request string raw HTTP request
--- @param expected_auth_token string
--- @return boolean ok, table|string result headers or error message
function M.validate_upgrade(request, expected_auth_token)
  local headers, method, _ = util.parse_http_headers(request)

  if method ~= "GET" then
    return false, "Invalid method: " .. method
  end

  local upgrade = headers["upgrade"]
  if not upgrade or upgrade:lower() ~= "websocket" then
    return false, "Missing or invalid Upgrade header"
  end

  local connection = headers["connection"]
  if not connection or not connection:lower():find("upgrade") then
    return false, "Missing or invalid Connection header"
  end

  local version = headers["sec-websocket-version"]
  if version ~= "13" then
    return false, "Unsupported WebSocket version: " .. tostring(version)
  end

  local key = headers["sec-websocket-key"]
  if not key then
    return false, "Missing Sec-WebSocket-Key"
  end

  -- Verify auth token
  local auth = headers["x-claude-code-ide-authorization"]
  if auth ~= expected_auth_token then
    return false, "Unauthorized"
  end

  return true, headers
end

--- Create HTTP 101 Switching Protocols response
--- @param client_key string Sec-WebSocket-Key from client
--- @return string
function M.create_upgrade_response(client_key)
  local accept = util.generate_accept_key(client_key)
  return "HTTP/1.1 101 Switching Protocols\r\n"
    .. "Upgrade: websocket\r\n"
    .. "Connection: Upgrade\r\n"
    .. "Sec-WebSocket-Accept: " .. accept .. "\r\n"
    .. "\r\n"
end

--- Create a 403 Forbidden response
--- @return string
function M.create_forbidden_response()
  return "HTTP/1.1 403 Forbidden\r\n"
    .. "Content-Length: 12\r\n"
    .. "\r\n"
    .. "Unauthorized"
end

--- Parse a WebSocket frame from buffer
--- Returns the parsed frame or nil if not enough data.
--- @param buf string
--- @return table|nil frame { fin, opcode, payload }, number|nil bytes_consumed
function M.parse_frame(buf)
  if #buf < 2 then
    return nil, nil
  end

  local b1, b2 = buf:byte(1, 2)
  local fin = (math.floor(b1 / 128) % 2) == 1
  local opcode = b1 % 16
  local masked = (math.floor(b2 / 128) % 2) == 1
  local payload_len = b2 % 128

  local offset = 2

  -- Extended payload length
  if payload_len == 126 then
    if #buf < 4 then return nil, nil end
    local hi, lo = buf:byte(3, 4)
    payload_len = hi * 256 + lo
    offset = 4
  elseif payload_len == 127 then
    if #buf < 10 then return nil, nil end
    -- 64-bit length; we only support up to ~2GB (Lua number precision)
    payload_len = 0
    for i = 3, 10 do
      payload_len = payload_len * 256 + buf:byte(i)
    end
    offset = 10
  end

  -- Mask key (4 bytes) if masked
  local mask_key
  if masked then
    if #buf < offset + 4 then return nil, nil end
    mask_key = buf:sub(offset + 1, offset + 4)
    offset = offset + 4
  end

  -- Payload
  if #buf < offset + payload_len then return nil, nil end
  local payload = buf:sub(offset + 1, offset + payload_len)

  -- Unmask if needed (client → server frames are always masked)
  if masked and mask_key then
    payload = util.apply_mask(payload, mask_key)
  end

  local bytes_consumed = offset + payload_len

  return {
    fin = fin,
    opcode = opcode,
    payload = payload,
  }, bytes_consumed
end

--- Create a WebSocket frame (server → client, no mask)
--- @param opcode number
--- @param payload string|nil
--- @return string
function M.create_frame(opcode, payload)
  payload = payload or ""
  local len = #payload
  local header

  -- FIN=1, no RSV, opcode
  local b1 = 128 + opcode -- 0x80 | opcode

  if len <= 125 then
    header = string.char(b1, len)
  elseif len <= 65535 then
    header = string.char(b1, 126, math.floor(len / 256), len % 256)
  else
    -- 64-bit length
    local bytes = {}
    bytes[1] = string.char(b1, 127)
    local len_bytes = {}
    local tmp = len
    for i = 8, 1, -1 do
      len_bytes[i] = string.char(tmp % 256)
      tmp = math.floor(tmp / 256)
    end
    header = bytes[1] .. table.concat(len_bytes)
  end

  return header .. payload
end

--- Create a text frame
--- @param text string
--- @return string
function M.create_text_frame(text)
  return M.create_frame(M.OPCODE.TEXT, text)
end

--- Create a close frame
--- @param code number|nil status code (default 1000)
--- @param reason string|nil
--- @return string
function M.create_close_frame(code, reason)
  code = code or 1000
  reason = reason or ""
  local payload = string.char(math.floor(code / 256), code % 256) .. reason
  return M.create_frame(M.OPCODE.CLOSE, payload)
end

--- Create a ping frame
--- @param data string|nil
--- @return string
function M.create_ping_frame(data)
  return M.create_frame(M.OPCODE.PING, data)
end

--- Create a pong frame
--- @param data string|nil
--- @return string
function M.create_pong_frame(data)
  return M.create_frame(M.OPCODE.PONG, data)
end

return M
