#[
    | wash_commands.nim - Command handler for Windows Advanced Shell
]#

import strutils, osproc, std/[os, ospaths, strformat, tables]
import winim/mean
import wash_prompting
import wash_termdetect

type
  CommandResult* = object
    shouldExit*: bool
    promptPrinted*: bool
    # exitCode*: int
    # errorMsg*: string

  CmdType* = enum
    shellBuiltin,
    generalBuiltin

  CmdHandler* = proc(args: seq[string]): CommandResult {.nimcall.}

  BuiltinCommand* = object
    description*: string
    cmdType*: CmdType
    handler*: CmdHandler

var builtinRegistry* = initTable[string, BuiltinCommand]()

proc wash_help(args: seq[string]): CommandResult =
  echo "\nFor more information on a specific command, type `help <command-name>`."
  echo "Using the `--chm` parameter will directly open a visual help manual.\n"
  for name, cmd in builtinRegistry:
    echo fmt"  {name:<15} - {cmd.description} [{cmd.cmdType}]"
  echo ""
  return CommandResult(shouldExit: false, promptPrinted: false)

proc wash_clear_screen(): CommandResult =
  result = CommandResult(shouldExit: false, promptPrinted: false)
  let hStdout = GetStdHandle(STD_OUTPUT_HANDLE)
  if hStdout == INVALID_HANDLE_VALUE: return

  var csbi: CONSOLE_SCREEN_BUFFER_INFO
  if GetConsoleScreenBufferInfo(hStdout, addr csbi) == 0: return

  let dwSize = csbi.dwSize.X.int32 * csbi.dwSize.Y.int32
  var dwCharsWritten: DWORD
  let coord0 = COORD(X: 0, Y: 0)

  FillConsoleOutputCharacter(hStdout, ' '.ord.TCHAR, dwSize, coord0, addr dwCharsWritten)
  FillConsoleOutputAttribute(hStdout, csbi.wAttributes, dwSize, coord0, addr dwCharsWritten)
  SetConsoleCursorPosition(hStdout, coord0)

  wash_prompting()
  result.promptPrinted = true

proc wash_cd(args: seq[string]): CommandResult =
  result = CommandResult(shouldExit: false, promptPrinted: false)
  if args.len > 0 and args[0].strip != "":
    let path = args[0].strip
    let normalizedPath = path.normalizedPath()
    let targetDir = if normalizedPath.isEmptyOrWhitespace: getHomeDir() else: normalizedPath
    try:
      if not dirExists(targetDir):
        echo fmt"No such file or directory: {targetDir}"
      else:
        setCurrentDir(targetDir)
    except OSError as e:
      echo fmt"OSError: {e.msg}"

proc wash_echo(args: seq[string]): CommandResult =
  echo args.join(" ")
  return CommandResult(shouldExit: false, promptPrinted: false)

proc wash_fuck(args: seq[string]): CommandResult =
  if args.len > 0 and args[0] == "you":
    echo "fuck segf4ultk1nger"
  return CommandResult(shouldExit: false, promptPrinted: false)

proc wash_exit(args: seq[string]): CommandResult =
  return CommandResult(shouldExit: true, promptPrinted: false)

proc wash_console_info(args: seq[string]): CommandResult =
  result = CommandResult(shouldExit: false, promptPrinted: false)
  
  let inputCP = GetConsoleCP()
  let outputCP = GetConsoleOutputCP()

  let termEmulator = detectTerminalEmulator()
  echo "=== Terminal Environment ==="
  echo fmt"  Detected Terminal: {termEmulator}"
  echo ""
  
  echo "=== Console Code Page ==="
  echo fmt"  Input Code Page  : {inputCP}"
  echo fmt"  Output Code Page : {outputCP}"
  echo ""

  let hStdin = GetStdHandle(STD_INPUT_HANDLE)
  let hStdout = GetStdHandle(STD_OUTPUT_HANDLE)

  if hStdin != INVALID_HANDLE_VALUE:
    var inMode: DWORD
    if GetConsoleMode(hStdin, addr inMode) != 0:
      echo "=== Input Console Mode ==="
      echo fmt"  Raw Mode Hex: 0x{inMode.int:08X}"
      echo fmt"  ENABLE_ECHO_INPUT             : {(inMode and ENABLE_ECHO_INPUT) != 0}"
      echo fmt"  ENABLE_INSERT_MODE            : {(inMode and ENABLE_INSERT_MODE) != 0}"
      echo fmt"  ENABLE_LINE_INPUT             : {(inMode and ENABLE_LINE_INPUT) != 0}"
      echo fmt"  ENABLE_MOUSE_INPUT            : {(inMode and ENABLE_MOUSE_INPUT) != 0}"
      echo fmt"  ENABLE_PROCESSED_INPUT        : {(inMode and ENABLE_PROCESSED_INPUT) != 0}"
      echo fmt"  ENABLE_QUICK_EDIT_MODE        : {(inMode and ENABLE_QUICK_EDIT_MODE) != 0}"
      echo fmt"  ENABLE_WINDOW_INPUT           : {(inMode and ENABLE_WINDOW_INPUT) != 0}"
      echo fmt"  ENABLE_VIRTUAL_TERMINAL_INPUT : {(inMode and 0x0200) != 0}"
      echo ""
    else:
      echo "Failed to get Input Console Mode."
  
  if hStdout != INVALID_HANDLE_VALUE:
    var outMode: DWORD
    if GetConsoleMode(hStdout, addr outMode) != 0:
      echo "=== Output Console Mode ==="
      echo fmt"  Raw Mode Hex: 0x{outMode.int:08X}"
      echo fmt"  ENABLE_PROCESSED_OUTPUT            : {(outMode and ENABLE_PROCESSED_OUTPUT) != 0}"
      echo fmt"  ENABLE_WRAP_AT_EOL_OUTPUT          : {(outMode and ENABLE_WRAP_AT_EOL_OUTPUT) != 0}"
      echo fmt"  ENABLE_VIRTUAL_TERMINAL_PROCESSING : {(outMode and 0x0004) != 0}"
      echo fmt"  DISABLE_NEWLINE_AUTO_RETURN        : {(outMode and 0x0008) != 0}"
      echo fmt"  ENABLE_LVB_GRID_WORLDWIDE          : {(outMode and 0x0010) != 0}"
      echo ""
    else:
      echo "Failed to get Output Console Mode."

  return result

proc registerBuiltins() =
  builtinRegistry["help"] = BuiltinCommand(
    description: "Provides Help information for `wash.exe` commands.",
    cmdType: shellBuiltin,
    handler: wash_help
  )
  builtinRegistry["cd"] = BuiltinCommand(
    description: "Displays the name of or changes the current directory.",
    cmdType: shellBuiltin,
    handler: wash_cd
  )
  builtinRegistry["clear"] = BuiltinCommand(
    description: "Clears the screen.",
    cmdType: shellBuiltin,
    handler: proc(args: seq[string]): CommandResult = wash_clear_screen()
  )
  builtinRegistry["echo"] = BuiltinCommand(
    description: "Displays messages.",
    cmdType: generalBuiltin,
    handler: wash_echo
  )
  builtinRegistry["exit"] = BuiltinCommand(
    description: "Quits the `wash.exe` program (only in `washell`).",
    cmdType: shellBuiltin,
    handler: wash_exit
  )
  builtinRegistry["fuck"] = BuiltinCommand(
    description: "...Just a funny egg, don't be serious",
    cmdType: generalBuiltin,
    handler: wash_fuck
  )
  builtinRegistry["coninfo"] = BuiltinCommand(
    description: "Displays current Console Code Page and Console Modes.",
    cmdType: shellBuiltin,
    handler: wash_console_info
  )

registerBuiltins()

proc handle_command*(cmd: string, args: seq[string], wash_handlectrl: proc(is_handle: bool)): CommandResult =
  result = CommandResult(shouldExit: false, promptPrinted: false)

  if builtinRegistry.contains(cmd):
    let builtin = builtinRegistry[cmd]
    return builtin.handler(args)
  else:
    try:
      wash_handlectrl(false)
      let p = startProcess(cmd, args = args, options = {poUsePath, poParentStreams})
      discard p.waitForExit()
      p.close()
      wash_handlectrl(true)
    except OSError:
      echo "wash: command not found: ", cmd