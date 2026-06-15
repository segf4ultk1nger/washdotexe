#[
    | wash.exe - Windows Advanced Shell
    | Copyright (c) segf4ultk1nger, SIFWARE 2026
    | Licensed under AGPL-3.
]#

import std/unicode, std/sequtils, winim/lean

type wash_textarea* = ref object
  text*: seq[Rune] = @[]
  cursor*: int = 0 # your cursor pos
  anchor*: int = 0 # you selection's starting pos
  # quick brown |fox jumps| over the lazy dog
  #             |   <==   |
  #       cursor|         |anchor
  hasSelection*:bool = false

# ensure cursor index is always safe
proc guardCursor(ta: wash_textarea) =
  if ta.cursor < 0: ta.cursor = 0
  if ta.cursor > ta.text.len: ta.cursor = ta.text.len

# TODO: wait readline selection implementation
proc selLeft*(ta: wash_textarea): int =
  if not ta.hasSelection: return ta.cursor
  return min(ta.anchor, ta.cursor)

# TODO: wait readline selection implementation
proc selRight*(ta: wash_textarea): int =
  if not ta.hasSelection: return ta.cursor
  return max(ta.anchor, ta.cursor)

# TODO: wait readline selection implementation
proc selLen*(ta: wash_textarea): int =
  return ta.selRight() - ta.selLeft()

proc clearSelection*(ta: wash_textarea) =
  ta.hasSelection = false
  ta.anchor = ta.cursor

proc deleteSelection*(ta: wash_textarea): bool =
  if not ta.hasSelection or ta.selLen() == 0: 
    return false
  let left = ta.selLeft()
  ta.text.delete(left ..< ta.selRight())
  ta.cursor = left
  ta.clearSelection()
  return true

proc insertRune*(ta: wash_textarea, rune: Rune) = 
  discard ta.deleteSelection()
  ta.text.insert(rune, ta.cursor)
  ta.cursor += 1

proc deleteBackward*(ta: wash_textarea) =
  if ta.deleteSelection(): return
  if ta.cursor <= 0: return
  ta.text.delete(ta.cursor - 1)
  ta.cursor -= 1

proc deleteForward*(ta: wash_textarea) =
  if ta.cursor >= ta.text.len: return
  ta.text.delete(ta.cursor)

proc move*(ta: wash_textarea, steps: int) =
  ta.cursor += steps
  ta.guardCursor()

proc moveHome*(ta: wash_textarea) =
  ta.cursor = 0

proc moveEnd*(ta: wash_textarea) =
  ta.cursor = ta.text.len

proc selectAll*(ta: wash_textarea) =
  if ta.text.len == 0: return
  ta.anchor = 0
  ta.cursor = ta.text.len
  ta.hasSelection = true

# i dont know why i want to write this shit function
proc copy*(ta: wash_textarea) =
  if not ta.hasSelection or ta.selLen() == 0: return

  # convert seq[Rune] to UTF-8 string
  let selectedRunes = ta.text[ta.selLeft() ..< ta.selRight()]
  var utf8Str = ""
  for r in selectedRunes: utf8Str.add($r)

  let wstr: WideCString = newWideCString(utf8Str) # convert UTF-8 to UTF-16
  let byteCount = (wstr.len + 1) * sizeof(WCHAR) # caculate spaces
  #[                          |
    you need to preserve a byte for \0, so why len + 1
    `* sizeof(WCHAR)` , because every WCHAR is 2 byte
  ]#

  # open the clipboard
  if OpenClipboard(0):
    defer: CloseClipboard() # ensure to close the clipboard
    EmptyClipboard()
    
    # alloc memory for copied strings
    let hMem = # firstly alloc, but dynamic, cant pour into data
        GlobalAlloc(GMEM_MOVEABLE, byteCount) 
    if hMem != 0:
      let pMem = GlobalLock(hMem) # lock the seat, the area become static
      if pMem != nil:
        copyMem(pMem, wstr, byteCount) # write string into memory
        GlobalUnlock(hMem) # unlock
        # fuking windows uses UTF-16, not UTF-8
        SetClipboardData(CF_UNICODETEXT, hMem)

# i dont know why i want to write this shit function
proc paste*(ta: wash_textarea) =
  if OpenClipboard(0):
    defer: CloseClipboard()
    
    # same, get a memory
    let hMem = GetClipboardData(CF_UNICODETEXT)
    if hMem != 0:
      let pMem = GlobalLock(hMem) # lock to access it
      if pMem != nil:
        # firstly convert to WideCString 
        # and use "$" operator to convert to string
        let pastedStr = $cast[WideCString](pMem)
        GlobalUnlock(hMem) # unlock the mem.

        discard ta.deleteSelection()
        var insertedCount = 0
        for r in pastedStr.runes:
          ta.text.insert(r, ta.cursor + insertedCount)
          insertedCount += 1
        ta.cursor += insertedCount