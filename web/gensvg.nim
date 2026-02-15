import std/[strformat, osproc, uri]
import ../src/finitestate

let expr = stdin.readAll()

if expr == "":
  quit 0

try:
  let svg = execCmdEx("dot -Tsvg", input = expr.toFSM.toDot).output
  echo &"""<img src="{svg.getDataUri("image/svg+xml")}">"""

except SyntaxError as e:
  echo &"""<div class="error">{e.pos}: {e.msg}</div>"""