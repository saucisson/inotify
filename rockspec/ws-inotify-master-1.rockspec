package = "ws-inotify"
version = "master-1"
source  = {
  url    = "git+https://github.com/saucisson/ws-inotify.git",
  branch = "master",
}

description = {
  summary    = "Inotify with Websocket",
  detailed   = [[]],
  homepage   = "https://github.com/saucisson/ws-inotify",
  license    = "MIT/X11",
  maintainer = "Alban Linard <alban@linard.fr>",
}

dependencies = {
  "lua >= 5.1",
  "argparse",
  "copas",
  "inotify",
  "luafilesystem",
  "lua-cjson",
  "lua-websockets",
  "magic",
  "md5",
}

build = {
  type    = "builtin",
  modules = {},
  install = {
    bin = {
      ["ws-inotify"] = "src/ws-inotify.lua",
    },
  },
}
