#[
    | wash.exe - Windows Advanced Shell
    | Copyright (c) segf4ultk1nger, SIFWARE 2026
    | Licensed under AGPL-3.
]#

import std/[os, strutils]
import winim/inc/winuser
import winim/inc/windef
import winim/utils
import winim/com

proc refreshEnvironment*() =
  # read specific registry all kv-pairs
  proc loadEnvFromRegistry(root: HKEY, path: string) =
    var hKey: HKEY
    let wPath = newWideCString(path)
    # open registry with KEY_READ readonly flag
    if RegOpenKeyExW(root, wPath, 0, KEY_READ, &hKey) == ERROR_SUCCESS:
      var 
        index: DWORD = 0                  # registry item index
        valueName = newWideCString(32767) # alloc mem for max name length
        valueData = newWideCString(32767) # alooc men for max data size
        nameLen: DWORD = 32767
        dataLen: DWORD = 32767
        valueType: DWORD

      # because nameLen, valueType, dataLen are ordinary DWORD, so need to 
      # use & operator to get its addr, while WideCString auto handled it.
      while RegEnumValueW(hKey, index, valueName, &nameLen, nil, &valueType, 
        cast[LPBYTE](&valueData[0]), &dataLen) == ERROR_SUCCESS: # fuck windows
        let keyStr = $valueName
        var valStr = $valueData

        if keyStr.strip() != "":
          # if encountered REG_EXPAND_SZ, which has variable to replace
          # like %USERPROFILE%\Desktop, need to replace %USERPROFILE% to the
          # actual user home directory.
          if valueType == REG_EXPAND_SZ:
            var expanded = newWideCString(32767) # alooc mem for max length
            if ExpandEnvironmentStringsW(valueData, expanded, 32767) > 0:
              valStr = $expanded # convert to string
          
          # os path and user path should join together.
          if keyStr.toUpperAscii() == "PATH":
            let currentPath = getEnv("PATH")
            if currentPath.strip() != "" and valStr notin currentPath:
              # we need to ensure the former fetched PATH still exists.
              putEnv("PATH", currentPath & ";" & valStr)
            else:
              putEnv("PATH", valStr)
          else:
            # normal env var just put.
            putEnv(keyStr, valStr)

        # reset name/data length
        nameLen = 32767
        dataLen = 32767
        inc index # index = index + 1

      RegCloseKey(hKey) # don't forget to close the registry!!!

  try:
    # firstly load os environment variables (HKLM)
    loadEnvFromRegistry(HKEY_LOCAL_MACHINE, r"System\CurrentControlSet" &
                        r"\Control\Session Manager\Environment")
    # secondly load user environment variables (HKCU)
    loadEnvFromRegistry(HKEY_CURRENT_USER, r"Environment")

  except:
    echo "Error[wash_env]: ", getCurrentExceptionMsg()

# wndproc to listen WM_SETTINGSCHANGE event to trigger env refresh
proc wndProc(hwnd: HWND, uMsg: UINT, wParam: WPARAM, lParam: LPARAM):
  LRESULT {.stdcall.} =
  case uMsg
  of WM_SETTINGCHANGE:
    if lParam != 0:
      let pStr = cast[WideCString](lParam)
      if $pStr == "Environment":
        refreshEnvironment()
        return 0    
  of WM_DESTROY:
    PostQuitMessage(0)
    return 0
  else:
    discard
    
  return DefWindowProc(hwnd, uMsg, wParam, lParam)

proc initEnvironmentAutoRefresh() =
  let hInstance = GetModuleHandle(nil)
  let className = "washdotexe_env_autorefresh"

  var wndClass: WNDCLASSEXW
  wndClass.cbSize = sizeof(WNDCLASSEXW).UINT
  wndClass.lpfnWndProc = wndProc
  wndClass.hInstance = hInstance
  wndClass.lpszClassName = className
  RegisterClassEx(&wndClass)

  let hwnd = CreateWindowEx(0,className,"EnvListener",WS_OVERLAPPEDWINDOW,
                            0,0,0,0,0,0,hInstance,nil)

  if hwnd == 0:
    # stupid ideas, shell should never echo message directly into stdout.
    # echo "Warning[wash_env]: Unable to create environment variable " &
    #      "listeners, automatic environment variable refresh will " &
    #      "not work properly!"
    return

  var msg: MSG
  while GetMessage(&msg, 0, 0, 0) > 0:
    TranslateMessage(&msg)
    DispatchMessage(&msg)

# new thread to do these shit stuffs
proc envListenerThread*() {.thread.} = initEnvironmentAutoRefresh()