import ./finitestate

try:
  echo stdin.readAll().toFSM.toDot
except SyntaxError as e:
  quit $e.pos & ": " & e.msg