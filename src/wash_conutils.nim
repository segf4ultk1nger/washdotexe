#[
    | wash.exe - Windows Advanced Shell
    | Copyright (c) segf4ultk1nger, SIFWARE 2026
    | Licensed under AGPL-3.
]#

# this module is obsolete, but external calls to it have not yet been fully 
# migrated to new `wash_console.nim` module.

import winim/lean

proc showConsoleCursor*(hStdout: HANDLE, show: bool) =
  var cursorInfo: CONSOLE_CURSOR_INFO
  # get cursor info
  if GetConsoleCursorInfo(hStdout, addr cursorInfo) != 0:
    # bVisible is WINBOOL, int32, 1=TRUE and 0=FALSE
    cursorInfo.bVisible = if show: TRUE else: FALSE
    discard SetConsoleCursorInfo(hStdout, addr cursorInfo)

# console cps
var originalConsoleCP: UINT = GetConsoleCP()
var originalConsoleOutputCP: UINT = GetConsoleOutputCP()

proc enableUTF8ConsoleCP*() =
  discard SetConsoleCP(CP_UTF8)
  discard SetConsoleOutputCP(CP_UTF8)

proc restoreUTF8ConsoleCP*() =
  if originalConsoleCP != 0:
    discard SetConsoleCP(originalConsoleCP)
  if originalConsoleOutputCP != 0:
    discard SetConsoleOutputCP(originalConsoleOutputCP)