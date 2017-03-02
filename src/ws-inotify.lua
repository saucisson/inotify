#! /usr/bin/env lua

local oldprint = print
_G.print = function (...)
  oldprint (...)
  io.stdout:flush ()
end

local oldexecute = os.execute
_G.os.execute = function (...)
  print (...)
  return oldexecute (...)
end

_G.table.unpack = table.unpack or unpack

local Arguments = require "argparse"
local Bit       = require "bit"
local Copas     = require "copas"
local Inotify   = require "inotify"
local Json      = require "cjson"
local Lfs       = require "lfs"
local Magic     = require "magic"
local Md5       = require "md5"
local Websocket = require "websocket"

local magic = Magic.open (Magic.MIME_TYPE, Magic.NO_CHECK_COMPRESS)
assert (magic:load () == 0)

local inotify = Inotify.init {
  blocking = false,
}
local options = 0
for _, option in ipairs {
  Inotify.IN_ACCESS,
  Inotify.IN_ATTRIB,
  Inotify.IN_CLOSE_WRITE,
  Inotify.IN_CLOSE_NOWRITE,
  Inotify.IN_CREATE,
  Inotify.IN_DELETE,
  Inotify.IN_DELETE_SELF,
  Inotify.IN_MODIFY,
  Inotify.IN_MOVE_SELF,
  Inotify.IN_MOVED_FROM,
  Inotify.IN_MOVED_TO,
  Inotify.IN_OPEN,
} do
  options = Bit.bor (options, option)
end

local parser = Arguments () {
  name        = "ws-inotify",
  description = "Inotify with websocket",
}
parser:option "--port" {
  description = "port",
  convert     = tonumber,
  default     = 8080,
}
parser:option "--directory" {
  description = "directory to watch",
  default     = "/data",
}
local arguments = parser:parse ()

local clients = {}
local info    = {}

local function walk (path)
  path = path or arguments.directory
  if Lfs.attributes (path, "mode") == "directory" then
    info [path] = {
      type    = "directory",
      mime    = magic:file (path),
      path    = path:sub (#arguments.directory+1),
      watcher = info [path]
             and info [path].watcher
              or inotify:addwatch (path, options),
    }
    print ("addwatch", path)
    if info [path].watcher then
      info [info [path].watcher] = info [path]
    end
    for entry in Lfs.dir (path) do
      if entry ~= "." and entry ~= ".." then
        walk (path .. "/" .. entry)
      end
    end
  elseif Lfs.attributes (path, "mode") == "file" then
    local file = io.open (path, "r")
    local md5  = Md5.sumhexa (file:read "*a")
    file:close ()
    info [path] = {
      type = "file",
      mime = magic:file (path),
      path = path:sub (#arguments.directory+1),
      md5  = md5,
    }
  end
end

local copas_addserver = Copas.addserver
Copas.addserver = function (socket, f)
  arguments.last   = os.time ()
  arguments.socket = socket
  arguments.host, arguments.port = socket:getsockname ()
  print ("listening on:", arguments.host, arguments.port)
  copas_addserver (socket, f)
end

Websocket.server.copas.listen {
  port      = arguments.port,
  default   = function (ws)
    print ("connection:", "open")
    clients [ws] = true
    while ws.state == "OPEN" do
      pcall (function ()
        local message = ws:receive ()
        print ("message:", message)
        message = Json.decode (message)
        if message.type == "list" then
          local result = {}
          for key, t in pairs (info) do
            if  type (key) == "string"
            and not result [t.path] then
              result [t.path] = {
                type = t.type,
                mime = t.mime,
                path = t.path,
                md5  = t.md5,
              }
            end
          end
          ws:send (Json.encode (result))
        end
      end)
    end
    clients [ws] = nil
    print ("connection:", "close")
  end,
  protocols = {},
}

Copas.addthread (function ()
  while true do
    Copas.sleep (1)
    for event in inotify:events () do
      local message = {
        path          = info [event.wd].path .. (event.name and "/" .. event.name or ""),
        access        = 0 ~= Bit.band (event.mask, Inotify.IN_ACCESS),
        attrib        = 0 ~= Bit.band (event.mask, Inotify.IN_ATTRIB),
        close_write   = 0 ~= Bit.band (event.mask, Inotify.IN_CLOSE_WRITE),
        close_nowrite = 0 ~= Bit.band (event.mask, Inotify.IN_CLOSE_NOWRITE),
        create        = 0 ~= Bit.band (event.mask, Inotify.IN_CREATE),
        delete        = 0 ~= Bit.band (event.mask, Inotify.IN_DELETE),
        delete_self   = 0 ~= Bit.band (event.mask, Inotify.IN_DELETE_SELF),
        modify        = 0 ~= Bit.band (event.mask, Inotify.IN_MODIFY),
        move_self     = 0 ~= Bit.band (event.mask, Inotify.IN_MOVE_SELF),
        moved_from    = 0 ~= Bit.band (event.mask, Inotify.IN_MOVED_FROM),
        moved_to      = 0 ~= Bit.band (event.mask, Inotify.IN_MOVED_TO),
        open          = 0 ~= Bit.band (event.mask, Inotify.IN_OPEN),
      }
      if message.access
      or message.attrib
      or message.open then
        local _ = false -- do nothing
      elseif message.close_write
          or message.modify then
        walk (message.path)
      elseif message.create then
        walk (message.path)
      elseif message.delete then
        info [event.name] = nil
      elseif message.delete_self then
        info [info [event.wd].path] = nil
        info [event.wd] = nil
        inotify:rmwatch (event.wd)
      elseif message.move_self then
        info [info [event.wd].path] = nil
        info [event.wd] = nil
        inotify:rmwatch (event.wd)
      elseif message.moved_from then
        info [event.name] = nil
      elseif message.moved_to then
        walk (arguments.directory .. "/" .. event.name)
      end
      message = Json.encode (message)
      print (message)
      for ws in pairs (clients) do
        ws:send (message)
      end
    end
  end
end)
Copas.addserver = copas_addserver

walk ()
Copas.loop ()
