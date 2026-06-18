#[
    | wash.exe - Windows Advanced Shell
    | Copyright (c) segf4ultk1nger, SIFWARE 2026
    | Licensed under AGPL-3.
]#

import strutils, osproc, std/unicode, std/[os, ospaths, strformat]
import winim/mean
import wash_conutils
import wash_readline
import wash_prompting
import wash_env

var ctrlcInterrupted {.volatile.}: bool = false
var promptPrinted {.volatile.}: bool = false

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


# repl module
proc wash_repl() =
  # firstly handle ctrl keys
  wash_handlectrl(true)
  enableUTF8ConsoleCP()

  var t: Thread[void]
  createThread(t, envListenerThread)

  const WashVersion {.strdefine.}: string = "0.0.1-dev"

  # welcome messages, hard-coded just for my laziness LOL.
  stdout.writeLine("wash.exe " & WashVersion)
  stdout.writeLine("`wash.exe` is highly unstable. Use with caution.")
  stdout.writeLine("")

  while true:

    ctrlcInterrupted = false

    if promptPrinted:
      promptPrinted = false
    else:
      wash_prompting()
      flushFile(stdout)

    # let's readline XD
    let result = wash_readline(ctrlcInterrupted)
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
    elif cmd == "fuck":
      if (args.len>0 and args[0] == "you"):
        echo "fuck segf4ultk1nger"
    elif cmd == "cd":
      if (args.len>0 and args[0].strip != ""):
        let path = args[0].strip
        let normalizedPath = path.normalizedPath()
        let targetDir = if normalizedPath.isEmptyOrWhitespace: getHomeDir() else: normalizedPath
        try:
          if not dirExists(targetDir):
            echo fmt"No such file or directory: {targetDir}"
            continue
          setCurrentDir(targetDir)
        except OSError as e:
          echo fmt"OSError: {e.msg}"
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
  restoreUTF8ConsoleCP()
