## RegExp2Automaton

a little cli tool to generate automata graphs (graphviz dot) from simple regular expressions.

it supports
- `*`, `+`, `?` and `{`..`}` qualifiers
- `.` wildcard
- `(`..`)` grouping
- `[`..`]` char-sets (including `^` complement)

### use online
https://chol.foo/regexp2automaton

### build cli tool

- install nim compiler
- build with nimble
```bash
nimble build
```

### use cli tool

the program reads the regexp from `stdin` and writes the `dot` definition to stdout.

so you can generate a `.svg` image for example with:
```bash
echo "ab*c" | ./regexp2automaton | dot -Tsvg >> automata.svg
```