import std/[strformat, strutils]

# [GLOBAL CONFIGS]______________________________________________________________
# ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
const
  Version = "0.0.2-alpha"

  SrcFile = "src/wash.nim"
  OutDir  = "build"
  RcFile  = "assets/app.rc"
  ResFile = "assets/app.res"

--mm:arc

# [HELPER: HANDLE WINDOWS RC]___________________________________________________
proc handleWindowsRes() =
  let pureVersion = strutils.split(Version, '-')[0]
  let rcCommaVersion = pureVersion.replace(".", ",") & ",0"

  if fileExists(RcFile):
    let originalContent = readFile(RcFile)
    var updatedContent = originalContent
    
    updatedContent = updatedContent.replace("#FILE_VERSION#", rcCommaVersion)
    updatedContent = updatedContent.replace("#STR_VERSION#", Version)
    
    let tempRc = "assets/app_compiled.rc"
    writeFile(tempRc, updatedContent)
    
    if defined(res):
      echo "=== Running windres ==="
      exec &"windres {tempRc} -O coff -o {ResFile}"

    rmFile(tempRc)
  else:
    echo &"[Warning] {RcFile} not found, skipped resource compilation."

# [CORE COMPILATION ENGINE]_____________________________________________________
proc runNimCompiler(extraFlags: string) =
  handleWindowsRes()
  
  var cmd = &"c -d:WashVersion={Version}"
  
  if defined(res) and fileExists(ResFile):
    cmd.add &" --passL:\"{ResFile}\""
    
  cmd.add " " & extraFlags
  cmd.add " " & SrcFile
  
  try:
    selfExec(cmd)
  finally:
    if defined(res) and fileExists(ResFile):
      echo "=== Auto cleaning up temporary app.res ==="
      rmFile(ResFile)

# [DEV TASK]____________________________________________________________________
# nim dev [-d:run] [-d:res]
task dev, "Builds wash.exe in debug mode.":
  echo "--- Starting Dev Build ---"
  
  var flags = &"--opt:none -g --out:\"{OutDir}/washdev.exe\""
  if defined(run): 
    flags.add " --run"

  runNimCompiler(flags)

# [RELEASE TASK]________________________________________________________________
# nim release [-d:res] [-d:speed | -d:min | -d:minx]
task release, "Builds wash.exe in release mode.":
  echo "--- Starting Release Build ---"
  
  var flags = &"-d:release --out:\"{OutDir}/wash.exe\""

  if defined(minx):
    echo "-> Mode: minx (Extreme Size Optimization)"
    flags.add " --opt:size -d:strip --passC:\"-Oz -ffunction-sections " &
      "-fdata-sections -fno-asynchronous-unwind-tables -flto\" --passL:\"" &
      "-Wl,--gc-sections -s -flto\""
  elif defined(min):
    echo "-> Mode: min (Size Optimization)"
    flags.add " --opt:size -d:strip --passC:\"-flto\" --passL:\"-flto\""
  elif defined(speed):
    echo "-> Mode: speed (Speed Optimization)"
    flags.add " --opt:speed"
  else:
    echo "-> Mode: default release"

  runNimCompiler(flags)