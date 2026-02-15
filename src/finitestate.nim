import std/[sugar, sequtils, strutils, strformat, sets, algorithm, options, osproc, uri, tables]
import ./regexp
export SyntaxError


type
  FiniteState* = object
    states*: seq[string]
    startState*: int
    targetStates*: seq[int]
    transitions*: seq[tuple[
      fromState: int,
      symbol: string,
      toState: int
    ]]


func toDot*(m: FiniteState): string =
  let attrs = "color=\"#ffffff\", fontcolor=\"#ffffff\", fontname=\"hack, monospace\""

  result = "digraph {" &
    "rankdir=LR; bgcolor=\"#00000000\";" &
    fmt"edge [{attrs}]; node[{attrs}];" &
    "\"\" [shape=plaintext, height=0, width=0];" &
    fmt "\"\" -> {m.states[0].escape};"

  for i, state in m.states:
    let shape = if i in m.targetStates: "doublecircle"
                else: "circle"
    result &= fmt"{state.escape} [shape={shape}];"

  var combinedTransitions: Table[tuple[fromState,toState: int], seq[string]]
  for t in m.transitions:
    let states = (t.fromState, t.toState)
    if states in combinedTransitions:
      combinedTransitions[states] &=  t.symbol
    else:
      combinedTransitions[states] = @[t.symbol]
  for t, symbols in combinedTransitions:
    let symbolsStr = symbols.join(",")
    result &= fmt"{m.states[t.fromState].escape} -> {m.states[t.toState].escape} [label={symbolsStr.escape}];"

  result &= "}"


func toFSM(regexp: RegExp): FiniteState =
  
  var
    leafNodes: seq[string]
    followPos: seq[seq[int]]

  proc findFollowPos(regexp: RegExp): tuple[first,last: seq[int], nullable: bool] =
    case regexp.kind
    of rkChar:
      leafNodes &= $regexp.c
      followPos &= @[]
      result.first = @[high(leafNodes)]
      result.last = result.first
      result.nullable = false

    of rkConcat:
      let elems = regexp.elems.map(findFollowPos)
      result.first =
        elems[0].first & (
          if elems[0].nullable: elems[1].first
          else: @[]
        )
      result.last =
        elems[1].last & (
          if elems[1].nullable: elems[0].last
          else: @[]
        )
      result.nullable = elems[0].nullable and elems[1].nullable

      for pos in elems[0].last:
        followPos[pos] &= elems[1].first

    of rkStar:
      result = findFollowPos(regexp.elem)
      result.nullable = true

      for pos in result.last:
        followPos[pos] &= result.first

    of rkAlt:
      let elems = regexp.elems.map(findFollowPos)
      result.first = deduplicate(elems[0].first & elems[1].first)
      result.last  = deduplicate(elems[0].last  & elems[1].last )
      result.nullable = elems[0].nullable or elems[1].nullable

    else:
      raise newException(CatchableError, "I couldn't figure this one out. I'm sorry :/")

  let rootNode = findFollowPos(regexp)
  let endPos = len(leafNodes)
  for pos in rootNode.last:
    followPos[pos] &= endPos

  for f in followPos.mitems: f = deduplicate(f)

  var 
    stateId: Table[seq[int], int]
    nextState = 0
    transitions: seq[(int, string, int)]
    targetStates: seq[int]

  proc genTransitions(statePos: seq[int]): int =
    stateId[statePos] = nextState
    result = nextState
    inc nextState
    var targets: Table[string, seq[int]]
    for pos in statePos:
      if pos == len(leafNodes): # is end node
        targetStates &= result.int
      else:
        let letter = leafNodes[pos]
        if letter in targets:
          targets[letter] &= followPos[pos]
        else:
          targets[letter] = followPos[pos]

    for (letter, pos) in targets.pairs:
      let pos = deduplicate(pos)
      transitions &= (
        result, letter,
        if pos in stateId: stateId[pos]
        else: genTransitions(pos)
      )
  
  result.startState = 0

  discard genTransitions(
    rootNode.first & (
      if rootNode.nullable: @[endPos]
      else: @[]
    )
  )
  result.transitions = transitions
  result.targetStates = targetStates

  for i in 0 ..< nextState:
    result.states &= "S" & $i

proc toFSM*(code: string): FiniteState =
  parseRegExp(code).eliminateOptionals().toFSM()