import winim/lean

proc showConsoleCursor*(hStdout: HANDLE, show: bool) =
  var cursorInfo: CONSOLE_CURSOR_INFO
  # get cursor info
  if GetConsoleCursorInfo(hStdout, addr cursorInfo) != 0:
    # bVisible is WINBOOL, int32, 1=TRUE and 0=FALSE
    cursorInfo.bVisible = if show: TRUE else: FALSE
    discard SetConsoleCursorInfo(hStdout, addr cursorInfo)

# console cps
var originalConsoleCP: UINT = 0
var originalConsoleOutputCP: UINT = 0

proc enableUTF8ConsoleCP*() =
  originalConsoleCP = GetConsoleCP()
  originalConsoleOutputCP = GetConsoleOutputCP()
  discard SetConsoleCP(CP_UTF8)
  discard SetConsoleOutputCP(CP_UTF8)

proc restoreUTF8ConsoleCP*() =
  if originalConsoleCP != 0:
    discard SetConsoleCP(originalConsoleCP)
  if originalConsoleOutputCP != 0:
    discard SetConsoleOutputCP(originalConsoleOutputCP)
