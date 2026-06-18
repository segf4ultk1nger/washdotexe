import winim/lean
import winim/inc/tlhelp32
import std/os, strutils, strformat

proc getParentProcessName(): string =
  result = "unknown"
  let currentPid = GetCurrentProcessId()
  var parentPid: DWORD = 0

  let hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0)
  if hSnapshot == INVALID_HANDLE_VALUE: return

  var pe: PROCESSENTRY32
  pe.dwSize = sizeof(PROCESSENTRY32).DWORD

  if Process32First(hSnapshot, addr pe) != 0:
    while true:
      if pe.th32ProcessID == currentPid:
        parentPid = pe.th32ParentProcessID
        break
      if Process32Next(hSnapshot, addr pe) == 0: break

  if parentPid != 0 and Process32First(hSnapshot, addr pe) != 0:
    while true:
      if pe.th32ProcessID == parentPid:
        # $$ convert array[WCHAR] to string
        result = nullTerminated($$pe.szExeFile).toLowerAscii()
        break
      if Process32Next(hSnapshot, addr pe) == 0: break

  CloseHandle(hSnapshot)

proc detectTerminalEmulator*(): string =
  if existsEnv("WT_SESSION"):
    return "Windows Terminal"
  elif existsEnv("WEZTERM_UNIX_SOCKET") or existsEnv("WEZTERM_EXECUTABLE"):
    return "WezTerm"
  elif existsEnv("ALACRITTY_LOG") or existsEnv("ALACRITTY_WINDOW_ID"):
    return "Alacritty"
  elif existsEnv("WARP_CLIENT_VERSION") or existsEnv("WARP_FOCUS_URL") or existsEnv("WARP_TERMINAL_SESSION_UUID"):
    return "Warp"
  elif existsEnv("VSCODE_GIT_IPC_HANDLE") or existsEnv("VSCODE_INJECTION"):
    return "VS Code Built-in Terminal"
  
  if existsEnv("TERM_PROGRAM"):
    let tp = getEnv("TERM_PROGRAM").toLowerAscii()
    if tp == "WarpTerminal": return "Warp"
    if tp == "vscode": return "VS Code Built-in Terminal"
    if tp == "wezterm": return "WezTerm"
    if tp == "alacritty": return "Alacritty"

  let parentExe = getParentProcessName()
  if parentExe.contains("windows_terminal") or parentExe.contains("openconsole"):
    return "Windows Terminal"
  elif parentExe.contains("conhost"):
    return "Classic Windows Console (conhost.exe)"
  elif parentExe.contains("wezterm"):
    return "WezTerm"
  elif parentExe.contains("alacritty"):
    return "Alacritty"
  elif parentExe.contains("warp"):
    return "Warp"
  
  if parentExe != "unknown":
    return fmt"Unknown (Parent Process: {parentExe})"
  else:
    return "Unknown Terminal"