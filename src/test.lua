local Arguments = require "argparse"
local Copas     = require "copas"
local Json      = require "cjson"
local Websocket = require "websocket"

local parser = Arguments () {
  name        = "test-ws-inotify",
  description = "Test inotify with websocket",
}
parser:option "--port" {
  description = "port",
  convert     = tonumber,
  default     = 8080,
}
local arguments = parser:parse ()

Copas.addthread (function ()
  local client = Websocket.client.copas {}
  print (client:connect "ws://localhost:" .. tostring (arguments.port))
  client:send (Json.encode {
    type = "list",
  })
  while true do
    print (client:receive ())
  end
end)

Copas.loop ()
