version       = "0.1.0"
author        = "Joel Lienhard"
description   = "generate automatas from regexp"
license       = "MIT"
srcDir        = "src"
namedBin      = {"main": "regexp2automaton"}.toTable


requires "nim >= 2.2.6"
requires "fusion"


task buildWeb, "build web version":
  withDir "web":
    exec "sassc style.sass html/style.css"
    exec "nim c -o:html/gensvg gensvg.nim"