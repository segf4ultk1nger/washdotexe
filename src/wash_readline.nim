#[
    | wash.exe - Windows Advanced Shell
    | Copyright (c) segf4ultk1nger, SIFWARE 2026
    | Licensed under AGPL-3.
]#

import winim/lean, std/unicode
import wash_textarea, wash_conutils

# redraw a whole prompt line
proc redrawLine(hStdout: HANDLE, startCoord: COORD, ta: wash_textarea) =
  var csbi: CONSOLE_SCREEN_BUFFER_INFO
  if GetConsoleScreenBufferInfo(hStdout, addr csbi) == 0: return

  hStdout.showConsoleCursor(false)
  SetConsoleCursorPosition(hStdout, startCoord)

  # fill right space to the blank
  let consoleWidth = csbi.dwSize.X - startCoord.X
  var dwCharsWritten: DWORD
  FillConsoleOutputCharacter(hStdout, ' '.ord.TCHAR, consoleWidth.int32, 
    startCoord, addr dwCharsWritten)

  # output blank text
  var fullText = ""
  for r in ta.text:
    fullText.add(r.toUTF8)
  stdout.write(fullText)
  stdout.flushFile()

  # caculating textarea cursor position with runes caculations.
  var targetX = startCoord.X
  for i in 0 ..< ta.cursor:
    # cjk is 2 colums size
    if ta.text[i].toUTF8.len >= 3:
      targetX += 2
    else:
      targetX += 1

  # set cursor pos to textarea cursor pos.
  let targetCoord = COORD(X: targetX, Y: startCoord.Y)
  SetConsoleCursorPosition(hStdout, targetCoord)

  hStdout.showConsoleCursor(true)

#readline module
proc wash_readline*(ctrlcInterrupted:bool): tuple[ok: bool, line: string] =
  var hStdin = GetStdHandle(STD_INPUT_HANDLE)
  var hStdout = GetStdHandle(STD_OUTPUT_HANDLE)
  var inputRecord: INPUT_RECORD
  var numRead: DWORD
  
  # wash textarea module
  var ta = wash_textarea(text: @[], cursor: 0)
  var pendingHighSurrogate: int = -1

  # get cursur position
  var csbi: CONSOLE_SCREEN_BUFFER_INFO
  var startCoord = COORD(X: 5, Y: 0) # fallback, because wash> is 5 characters
  if GetConsoleScreenBufferInfo(hStdout, addr csbi):
    startCoord = csbi.dwCursorPosition

  while true:
    if ctrlcInterrupted:
      # drop all remaining input events
      FlushConsoleInputBuffer(hStdin)
      return (false, "")

    if ReadConsoleInput(hStdin, addr inputRecord, 1, addr numRead) == 0:
      return (false, "")

    # ignore non-key-input events (but mouse support will added in future)
    if inputRecord.EventType != KEY_EVENT:
      continue

    let keyEvent = inputRecord.Event.KeyEvent
    if keyEvent.bKeyDown == 0:
      continue

    let keyCode = keyEvent.wVirtualKeyCode
    let keyChar = keyEvent.uChar.UnicodeChar

    # key event handle
    if keyCode == VK_RETURN: # new line with prompt when user hit Enter.
      stdout.writeLine("")
      var line = ""
      for r in ta.text:
        line.add(r.toUTF8)
      return (true, line)

    elif keyCode == VK_BACK: # backspace
      pendingHighSurrogate = -1
      ta.deleteBackward()
      redrawLine(hStdout, startCoord, ta)

    elif keyCode == VK_DELETE: # delete
      pendingHighSurrogate = -1
      ta.deleteForward()
      redrawLine(hStdout, startCoord, ta)

    elif keyCode == VK_LEFT: # left key to move left
      pendingHighSurrogate = -1
      ta.move(-1)
      redrawLine(hStdout, startCoord, ta)

    elif keyCode == VK_RIGHT: # right key to move right
      pendingHighSurrogate = -1
      ta.move(1)
      redrawLine(hStdout, startCoord, ta)

    elif keyCode == VK_HOME: # move to home
      pendingHighSurrogate = -1
      ta.moveHome()
      redrawLine(hStdout, startCoord, ta)

    elif keyCode == VK_END: # move to end
      pendingHighSurrogate = -1
      ta.moveEnd()
      redrawLine(hStdout, startCoord, ta)

    # you must have a VK_CONTROL or VK_MENU or VK_SHIFT wrapped by WORD caster 
    # to unify the types.
    elif keyCode in [WORD(VK_CONTROL), VK_MENU, VK_SHIFT]:
      continue

    elif keyChar == 0:
      pendingHighSurrogate = -1
      continue

    # fuking utf-16.
    # because calling readconsoleinputw gets utf-16 chars.
    # and utf-16 needs to handle surrogate pairs, which is fking annoying
    elif keyChar >= 0xD800 and keyChar <= 0xDBFF:
      pendingHighSurrogate = int(keyChar)
    elif keyChar >= 0xDC00 and keyChar <= 0xDFFF:
      if pendingHighSurrogate >= 0:
        let codePoint = 0x10000 + 
          (((pendingHighSurrogate - 0xD800) shl 10) or (int(keyChar) - 0xDC00))
        ta.insertRune(Rune(codePoint))
        pendingHighSurrogate = -1
        redrawLine(hStdout, startCoord, ta)
    elif keyChar >= 32:
      pendingHighSurrogate = -1
      ta.insertRune(Rune(int(keyChar)))
      redrawLine(hStdout, startCoord, ta)