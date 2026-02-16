import std/[strformat, osproc, uri]
import ../src/finitestate

let expr = stdin.readAll()

if expr == "":
  echo static(staticRead("info.html"))

else:
  try:
    let svg = execCmdEx("dot -Tsvg", input = expr.toFSM.toDot).output
    echo &"""<img src="{svg.getDataUri("image/svg+xml")}">"""

  except SyntaxError as e:
    echo &"""<div id="error">{e.pos}: {e.msg}</div>"""