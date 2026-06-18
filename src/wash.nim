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
import wash_commands
import wash_console

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

# repl module
proc wash_repl() =
  # firstly handle ctrl keys
  wash_handlectrl(true)
  washConsoleSingleton.withState do():
    washConsoleSingleton.consoleOutputCP = 65001
    var t: Thread[void]
    createThread(t, envListenerThread)

    const WashVersion {.strdefine.}: string = "0.0.1-dev"

    # welcome messages, hard-coded just for my laziness LOL.
    stdout.writeLine("washell[wash.exe] " & WashVersion & 
      (if washConsoleSingleton.isConsoleClean: " *c" else: " *d"))
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

      let res = handle_command(cmd, args, wash_handlectrl)
      
      if res.shouldExit:
        break
      
      if res.promptPrinted:
        promptPrinted = true


# main entry
when isMainModule:
  wash_repl()
