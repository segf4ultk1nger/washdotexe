#[  
    | wash.exe - Windows Advanced Shell
    | Copyright (c) segf4ultk1nger, SIFWARE 2026
    | Licensed under AGPL-3.
]#

import strutils, osproc, std/unicode
import winim/lean

var ctrlcInterrupted {.volatile.}: bool = false
var promptPrinted {.volatile.}: bool = false

# console cps
var originalConsoleCP: UINT = 0
var originalConsoleOutputCP: UINT = 0

# keep this stupid prompt function
proc wash_prompting() =
  stdout.write("wash>")

# handle ctrl key for SetConsoleCtrlHandler
proc wash_ctrl_handler_native(ctrl_type: DWORD): WINBOOL {.stdcall.} =
  if ctrl_type in [CTRL_C_EVENT, CTRL_BREAK_EVENT]:
    stdout.write("^C\r\n")
    wash_prompting() # immediately display prompt text so that there is no extra
                     # delay for the prompt display.
    flushFile(stdout)
    ctrlcInterrupted = true
    promptPrinted = true
    return TRUE
  return FALSE

# wrapper for SetConsoleCtrlHandler
proc wash_handlectrl(is_handle: bool)=
  discard SetConsoleCtrlHandler(wash_ctrl_handler_native, TRUE)

proc wash_enable_utf8_console() =
  originalConsoleCP = GetConsoleCP()
  originalConsoleOutputCP = GetConsoleOutputCP()
  discard SetConsoleCP(CP_UTF8)
  discard SetConsoleOutputCP(CP_UTF8)

proc wash_restore_console_cp() =
  if originalConsoleCP != 0:
    discard SetConsoleCP(originalConsoleCP)
  if originalConsoleOutputCP != 0:
    discard SetConsoleOutputCP(originalConsoleOutputCP)

# builtin command: clear
proc wash_clear_screen() =
  # get stdout handle
  let hStdout = GetStdHandle(STD_OUTPUT_HANDLE)
  if hStdout == INVALID_HANDLE_VALUE: return

  # get console screen buffer info
  var csbi: CONSOLE_SCREEN_BUFFER_INFO
  if GetConsoleScreenBufferInfo(hStdout, addr csbi) == 0: return

  # caculate rect buffer size
  let dwSize = csbi.dwSize.X.int32 * csbi.dwSize.Y.int32
  var dwCharsWritten: DWORD
  let coord0 = COORD(X: 0, Y: 0)

  FillConsoleOutputCharacter(hStdout, ' '.ord.TCHAR, dwSize, coord0,
    addr dwCharsWritten) # fill the whole buffer with void
  FillConsoleOutputAttribute(hStdout, csbi.wAttributes, dwSize, coord0,
    addr dwCharsWritten) # also reset the attributes
  SetConsoleCursorPosition(hStdout, coord0) # set cursor pos to (0,0)

  # immediately display prompt to remove extra delay.
  wash_prompting()
  promptPrinted = true

proc wash_readline(): tuple[ok: bool, line: string] =
  var hStdin = GetStdHandle(STD_INPUT_HANDLE)
  var inputRecord: INPUT_RECORD
  var numRead: DWORD
  var lineRunes: seq[Rune] = @[]
  var pendingHighSurrogate: int = -1

  # handle runes instead of chars ensures unicode input works
  proc appendRune(r: Rune) =
    lineRunes.add(r)
    let utf8 = r.toUTF8
    stdout.write(utf8)
    flushFile(stdout)
  proc dropLastRune() =
    if lineRunes.len > 0:
      discard lineRunes.pop()
      stdout.write("\x08 \x08")
      flushFile(stdout)

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

    # super simple and stupid basic text input area implemetion
    if keyCode == VK_RETURN: # new line with prompt when user hit Enter.
      stdout.writeLine("")
      var line = ""
      for r in lineRunes:
        line.add(r.toUTF8)
      return (true, line)
    elif keyCode == VK_BACK: # backspace
      pendingHighSurrogate = -1
      dropLastRune()
    elif keyCode == VK_CONTROL or keyCode == VK_MENU or keyCode == VK_SHIFT:
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
        appendRune(Rune(codePoint))
        pendingHighSurrogate = -1
    elif keyChar >= 32:
      pendingHighSurrogate = -1
      appendRune(Rune(int(keyChar)))

# repl module
proc wash_repl() =
  # firstly handle ctrl keys
  wash_handlectrl(true)
  wash_enable_utf8_console()

  # welcome messages, hard-coded just for my laziness LOL.
  stdout.writeLine("washdotexe-alpha0.0.1")
  stdout.writeLine("Type 'exit' to close, Ctrl+C to interrupt")
  stdout.writeLine("")

  while true:
    ctrlcInterrupted = false

    if promptPrinted:
      promptPrinted = false
    else:
      wash_prompting()
      flushFile(stdout)

    # let's readline XD
    let result = wash_readline()
    if not result.ok:
      if ctrlcInterrupted:
        ctrlcInterrupted = false
        continue

    var line = result.line
    line = line.strip
    if line.len == 0:
      continue

    let parts = strutils.splitWhitespace(line)
    let cmd = parts[0]
    let args: seq[string] = if parts.len > 1: parts[1..^1] else: @[]

    # some fucking stupid hard-coded builtins
    if cmd == "exit":
      break
    elif cmd == "echo":
      echo args.join(" ")
    elif cmd == "clear":
      wash_clear_screen()
    else:
      try:
        wash_handlectrl(false) # firstly disable ctrl handler for wash

        let p = startProcess(
          cmd,
          args = args,
          options = {poUsePath, poParentStreams} # use wash's stdio handles
        )

        discard p.waitForExit()
        p.close()

        wash_handlectrl(true) # recover the ctrl handle
      except OSError:
        echo "wash: command not found: ", cmd


# main entry
when isMainModule:
  wash_repl()
  wash_restore_console_cp()
