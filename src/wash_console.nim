#[
    | wash.exe - Windows Advanced Shell
    | Copyright (c) segf4ultk1nger, SIFWARE 2026
    | Licensed under AGPL-3.
]#

import winim/lean

type WashBrushColor* = enum
  Black = 0
  DarkBlue = 1
  DarkGreen = 2
  DarkCyan = 3
  DarkRed = 4
  Magenta = 5
  Brown = 6
  LightGray = 7
  DarkGray = 8
  BrightBlue = 9
  BrightGreen = 10
  BrightCyan = 11
  BrightRed = 12
  BrightMagenta = 13
  BrightYellow = 14
  White = 15

type WashConsoleState = object
  cursorPos: tuple[x: int, y: int]
  brushForeground: WashBrushColor
  brushBackground: WashBrushColor
  brushUnderScore: bool
  brushReverse: bool
  cursorIsVisible: bool
  consoleOutputCP: int
  consoleInputCP: int

type WashConsole* = ref object
  hStdout: HANDLE
  hStdin: HANDLE
  stateStack: seq[WashConsoleState]
  isConsoleClean: bool = false

var washConsoleSingleton* = WashConsole(
    hStdout: GetStdHandle(STD_OUTPUT_HANDLE),
    hStdin: GetStdHandle(STD_INPUT_HANDLE),
    stateStack: @[]
)

proc hStdout*(self: WashConsole): HANDLE = self.hStdout
proc hStdin*(self: WashConsole): HANDLE = self.hStdin

proc processList*(self: WashConsole): seq[DWORD] =
  var pids = newSeq[DWORD](32)
  var count = GetConsoleProcessList(addr pids[0], 32)
  if count > 32:
    pids.setLen(count)
    count = GetConsoleProcessList(addr pids[0], count)
  pids.setLen(count)
  return pids

proc cursorPos*(self: WashConsole): tuple[x: int, y: int] =
  var csbi: CONSOLE_SCREEN_BUFFER_INFO
  if GetConsoleScreenBufferInfo(self.hStdout, addr csbi):
    return (x: csbi.dwCursorPosition.X.int, y: csbi.dwCursorPosition.Y.int)
  return (x: 0, y: 0)

proc `cursorPos=`*(self: WashConsole, pos: tuple[x: int, y: int]) =
  let coord = COORD(X: pos.x.SHORT, Y: pos.y.SHORT)
  SetConsoleCursorPosition(self.hStdout, coord)

proc bufferSize*(self: WashConsole): tuple[w: int, h: int] =
  var csbi: CONSOLE_SCREEN_BUFFER_INFO
  if GetConsoleScreenBufferInfo(self.hStdout, addr csbi):
    return (w: csbi.dwSize.X.int, h: csbi.dwSize.Y.int)
  return (w: 0, h: 0)

proc `bufferSize=`*(self: WashConsole, size: tuple[w: int, h: int]) =
  let coord = COORD(X: size.w.SHORT, Y: size.h.SHORT)
  # warning: buffer size can't smaller than current viewport size
  SetConsoleScreenBufferSize(self.hStdout, coord)

proc viewportRect*(self: WashConsole): tuple[left: int, top: int, right: int, bottom: int] =
  var csbi: CONSOLE_SCREEN_BUFFER_INFO
  if GetConsoleScreenBufferInfo(self.hStdout, addr csbi):
    return (left: csbi.srWindow.Left.int, top: csbi.srWindow.Top.int,
            right: csbi.srWindow.Right.int, bottom: csbi.srWindow.Bottom.int)
  return (left: 0, top: 0, right: 0, bottom: 0)

proc `viewportRect=`*(self: WashConsole, rect: tuple[left: int, top: int, right: int, bottom: int]) =
  var sr = SMALL_RECT(
    Left: rect.left.SHORT, Top: rect.top.SHORT,
    Right: rect.right.SHORT, Bottom: rect.bottom.SHORT
  )
  # TRUE 表示如果窗口大小改变，同时调整物理窗口位置
  SetConsoleWindowInfo(self.hStdout, TRUE, addr sr)

# 辅助私有函数：获取当前底层的全局属性
proc getRawAttributes(self: WashConsole): WORD =
  var csbi: CONSOLE_SCREEN_BUFFER_INFO
  if GetConsoleScreenBufferInfo(self.hStdout, addr csbi):
    return csbi.wAttributes
  return 0x0007 # 默认黑底白字

proc brushForeground*(self: WashConsole): WashBrushColor =
  return WashBrushColor(self.getRawAttributes() and 0x000F)

proc `brushForeground=`*(self: WashConsole, color: WashBrushColor) =
  let current = self.getRawAttributes()
  let nextAttr = (current and 0xFFF0) or color.WORD
  SetConsoleTextAttribute(self.hStdout, nextAttr)

proc brushBackground*(self: WashConsole): WashBrushColor =
  return WashBrushColor((self.getRawAttributes() and 0x00F0) shr 4)

proc `brushBackground=`*(self: WashConsole, color: WashBrushColor) =
  let current = self.getRawAttributes()
  let nextAttr = (current and 0xFF0F) or (color.WORD shl 4)
  SetConsoleTextAttribute(self.hStdout, nextAttr)

# 下划线控制
proc brushUnderScore*(self: WashConsole): bool =
  return (self.getRawAttributes() and COMMON_LVB_UNDERSCORE) != 0

proc `brushUnderScore=`*(self: WashConsole, enable: bool) =
  let current = self.getRawAttributes()
  let nextAttr = if enable: current or COMMON_LVB_UNDERSCORE.WORD
                 else: current and (not COMMON_LVB_UNDERSCORE.WORD)
  SetConsoleTextAttribute(self.hStdout, nextAttr)

# 反色控制
proc brushReverse*(self: WashConsole): bool =
  return (self.getRawAttributes() and COMMON_LVB_REVERSE_VIDEO) != 0

proc `brushReverse=`*(self: WashConsole, enable: bool) =
  let current = self.getRawAttributes()
  let nextAttr = if enable: current or COMMON_LVB_REVERSE_VIDEO.WORD
                 else: current and (not COMMON_LVB_REVERSE_VIDEO.WORD)
  SetConsoleTextAttribute(self.hStdout, nextAttr)

proc cursorIsVisible*(self: WashConsole): bool =
  var cci: CONSOLE_CURSOR_INFO
  if GetConsoleCursorInfo(self.hStdout, addr cci):
    return cci.bVisible == TRUE
  return true

proc `cursorIsVisible=`*(self: WashConsole, visible: bool) =
  var cci: CONSOLE_CURSOR_INFO
  if GetConsoleCursorInfo(self.hStdout, addr cci):
    cci.bVisible = if visible: TRUE else: FALSE
    SetConsoleCursorInfo(self.hStdout, addr cci)

proc cursorSize*(self: WashConsole): int =
  var cci: CONSOLE_CURSOR_INFO
  if GetConsoleCursorInfo(self.hStdout, addr cci):
    return cci.dwSize.int
  return 100

proc `cursorSize=`*(self: WashConsole, size: int) =
  var cci: CONSOLE_CURSOR_INFO
  if GetConsoleCursorInfo(self.hStdout, addr cci):
    # Windows 限定大小在 1 到 100 之间
    cci.dwSize = clamp(size, 1, 100).DWORD
    SetConsoleCursorInfo(self.hStdout, addr cci)

proc consoleHwnd*(self: WashConsole): HWND =
  return GetConsoleWindow()

proc consoleTitle*(self: WashConsole): string =
  var buffer = newString(512)
  let len = GetConsoleTitleA(cstring(buffer), 512)
  buffer.setLen(len)
  return buffer

proc `consoleTitle=`*(self: WashConsole, title: string) =
  SetConsoleTitleA(title.cstring)

proc consoleInputCP*(self: WashConsole): int =
  return GetConsoleCP().int

proc `consoleInputCP=`*(self: WashConsole, cp: int) =
  SetConsoleCP(cp.UINT)

proc consoleOutputCP*(self: WashConsole): int =
  return GetConsoleOutputCP().int

proc `consoleOutputCP=`*(self: WashConsole, cp: int) =
  SetConsoleOutputCP(cp.UINT)

proc isConsoleClean*(self: WashConsole): bool = self.isConsoleClean

# firstly check is console clean
let bufSize = washConsoleSingleton.bufferSize
let totalCharsToRead = bufSize.w * bufSize.h

if totalCharsToRead <= 0:
  washConsoleSingleton.isConsoleClean = true
else:
  var buf = newSeq[WCHAR](totalCharsToRead)
  var charsRead: DWORD
  let startCoord = COORD(X: 0, Y: 0)

  washConsoleSingleton.isConsoleClean = true
  if ReadConsoleOutputCharacterW(washConsoleSingleton.hStdout, addr buf[0], totalCharsToRead.DWORD, startCoord, addr charsRead) != 0:
    for i in 0 ..< charsRead.int:
      let c = buf[i].int
      if c != 32 and c != 0: 
        washConsoleSingleton.isConsoleClean = false
        break

# 辅助私有：导出快照
proc save(self: WashConsole): WashConsoleState =
  return WashConsoleState(
    cursorPos: self.cursorPos,
    brushForeground: self.brushForeground,
    brushBackground: self.brushBackground,
    brushUnderScore: self.brushUnderScore,
    brushReverse: self.brushReverse,
    cursorIsVisible: self.cursorIsVisible,
    consoleOutputCP: self.consoleOutputCP,
    consoleInputCP: self.consoleInputCP
  )

# 辅助私有：应用快照
proc restore(self: WashConsole, state: WashConsoleState) =
  self.consoleOutputCP = state.consoleOutputCP
  self.consoleInputCP = state.consoleInputCP
  self.brushForeground = state.brushForeground
  self.brushBackground = state.brushBackground
  self.brushUnderScore = state.brushUnderScore
  self.brushReverse = state.brushReverse
  self.cursorIsVisible = state.cursorIsVisible
  self.cursorPos = state.cursorPos

# --- 方案 B: 显式栈操作 ---
proc pushState*(self: WashConsole) =
  ## 将当前控制台的所有属性压入内部备份栈中
  self.stateStack.add(self.save())

proc popState*(self: WashConsole) =
  ## 弹出并恢复上一次压入栈中的控制台属性
  if self.stateStack.len > 0:
    let lastState = self.stateStack.pop()
    self.restore(lastState)

# --- 方案 C: 闭包生命周期控制器 ---
proc withState*(self: WashConsole, body: proc()) =
  ## [高级] 自动管理控制台生命周期状态。
  ## 进入块时自动记住当前状态，退出块（即使发生异常）也会确保自动恢复原样。
  self.pushState()
  try:
    body()
  finally:
    self.popState() # 利用 finally 充当终极安全锁