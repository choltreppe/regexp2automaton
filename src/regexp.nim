import std/[unicode, strutils, strformat, sequtils, parseutils, tables, setutils, options]
import fusion/matching


type
  RegExpKind* = enum rkChar, rkConcat, rkStar, rkOpt, rkAlt
  RegExp* = ref object
    case kind*: RegExpKind
    of rkChar:
      c*: char
    of rkConcat, rkAlt:
      elems*: array[2, RegExp]
    of rkStar, rkOpt:
      elem*: RegExp

  SyntaxError* = ref object of CatchableError
    pos*: Natural


template raiseSyntaxError {.dirty.} =
  raise SyntaxError(msg: "syntax error", pos:
    if Some(@token) ?= token: token.pos
    else: 0
  )


func `$`*(re: RegExp): string =
  case re.kind
  of rkChar: $re.c
  of rkConcat: fmt"{re.elems[0]}{re.elems[1]}"
  of rkAlt: fmt"({re.elems[0]}|{re.elems[1]})"
  of rkStar: $re.elem & "*"
  of rkOpt: $re.elem & "?"


func newChar(c: char): RegExp =
  RegExp(kind: rkChar, c: c)

func newConcat(elems: array[2, RegExp]): RegExp =
  RegExp(kind: rkConcat, elems: elems)

func newConcat(elems: varargs[RegExp]): RegExp = elems.toSeq.foldl(newConcat([a, b]))

func newAlt(elems: array[2, RegExp]): RegExp =
  RegExp(kind: rkAlt, elems: elems)

func newAlt(elems: varargs[RegExp]): RegExp = elems.toSeq.foldl(newAlt([a, b]))

func newStar(elem: RegExp): RegExp =
  RegExp(kind: rkStar, elem: elem)

func newOpt(elem: RegExp): RegExp =
  RegExp(kind: rkOpt, elem: elem)


proc parseRegExp*(code: string): RegExp =
  var i = 0

  proc syntaxError(msg: string) {.noreturn.} =
    raise SyntaxError(pos: i, msg: msg)

  proc parseRegExp: RegExp =
    let startIdx = i
    var altElems, concatElems: seq[RegExp]

    proc checkLhsNotEmpty(sym: string) =
      if len(concatElems) == 0:
        syntaxError &"LHS of '{sym}' is empty"

    proc checkNotEol(sym: string) =
      if i >= len(code):
        syntaxError &"unexpected EOL. expected {sym}"

    while i < len(code):
      case code[i]
      of '(':
        inc i
        concatElems &= parseRegExp()

      of ')':
        if startIdx == 0:
          syntaxError "closing parentheses was not opened"
        inc i
        break

      of '|':
        checkLhsNotEmpty "|"
        altElems &= newConcat(concatElems)
        concatElems = @[]
        inc i

      of '*':
        checkLhsNotEmpty "*"
        concatElems[^1] = newStar(concatElems[^1])
        inc i

      of '+':
        checkLhsNotEmpty "+"
        concatElems &= newStar(concatElems[^1])
        inc i

      of '?':
        checkLhsNotEmpty "?"
        concatElems[^1] = newOpt(concatElems[^1])
        inc i

      of '{':
        inc i
        var s: string
        i += code.parseUntil(s, '}', i) + 1
        checkNotEol "'}'"
        let n: int =
          try: parseInt(s)
          except ValueError: syntaxError &"unexpected '{s}' inside {{}}. only integers allowed"
        checkLhsNotEmpty "{" & s & "}"

      of '[':
        inc i
        checkNotEol "a charater set"
        var isNegated = false
        if code[i] == '^':
          inc i
          isNegated = true
        var s: string
        i += code.parseUntil(s, ']', i) + 1
        checkNotEol "']'"
        var chars = s.toSet
        if isNegated:
          chars = complement(chars)
        concatElems &= newAlt(chars.toSeq.mapIt(newChar(it)))

      of '.':
        concatElems &= newAlt(fullSet(char).toSeq.mapIt(newChar(it)))
        inc i

      of '\\':
        inc i
        checkNotEol "a charater to escape"
        concatElems &= newChar(code[i])
        inc i

      else:
        concatElems &= newChar(code[i])
        inc i

    if len(concatElems) == 0:
      syntaxError:
        if len(altElems) == 0: "empty (sub-)expression"
        else: "RHS of '|' is empty"

    newAlt(altElems & newConcat(concatElems))

  parseRegExp()


func eliminateOptionals*(regex: RegExp): RegExp =
  case regex.kind
  of rkChar: regex

  of rkOpt:
    let elem = eliminateOptionals(regex.elem)
    if elem.kind == rkStar: elem
    else: newOpt(elem)

  of rkConcat:
    let elems = regex.elems.map(eliminateOptionals)
    if elems[0].kind != rkOpt and elems[1].kind != rkOpt:
      newConcat(elems)
    elif elems[0].kind != rkOpt:
      newAlt(elems[0], newConcat(elems[0], elems[1].elem))
    elif elems[1].kind != rkOpt:
      newAlt(newConcat(elems[0].elem, elems[1]), elems[1])
    else:
      newOpt(newAlt(
        elems[0].elem,
        elems[1].elem,
        newConcat(elems[0].elem, elems[1].elem)
      ))

  of rkAlt:
    var hasOpt = false
    let elems = regex.elems.map do (it: RegExp) -> RegExp:
      let it = eliminateOptionals(it)
      if it.kind == rkOpt:
        hasOpt = true
        it.elem
      else: it
    if hasOpt: newOpt(newAlt(elems))
    else:             newAlt(elems)

  of rkStar:
    let elem = eliminateOptionals(regex.elem)
    if elem.kind == rkOpt:
      newStar(elem.elem)
    else: regex