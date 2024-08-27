# Package

version       = "0.1.0"
author        = "dirtboll"
srcDir        = "src"
bin           = @["ghostline"]
binDir        = "bin"

# Dependencies

requires "nim >= 2.0.8"
requires "chronos >= 4.0.2"
requires "libp2p#master"
requires "https://github.com/jaar23/tui_widget"
requires "malebolgia >= 0.1.0"