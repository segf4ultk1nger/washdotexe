task dev, "Builds the project in debug mode":
  echo "--- Starting Dev Build ---"
  exec "nim c -g --opt:none --out:build/washdev.exe src/wash.nim"

task drun, "Build and run the project in debug mod":
  echo "--- Starting Dev Build ---"
  exec "nim c -g --opt:none --run --out:build/washdev.exe src/wash.nim"

task release_minx, "Builds the project in release-minx mode":
  echo "--- Starting release-minx Build ---"
  exec "nim c --mm:arc -d:release --opt:size --d:strip --passC:\"-Oz -ffunction-sections -fdata-sections -fno-asynchronous-unwind-tables -flto\" --passL:\"-Wl,--gc-sections -s -flto\" --out:build/wash.exe src/wash.nim"

task release_min, "Builds the project in release-min mode":
  echo "--- Starting release-min Build ---"
  exec "nim c --mm:arc -d:release --opt:size --d:strip --passC:\"-flto\" --passL:\"-flto\" --out:build/wash.exe src/wash.nim"

task release, "Builds the project in release-minx mode":
  echo "--- Starting release Build ---"
  exec "nim c --mm:arc -d:release --out:build/wash.exe src/wash.nim"

task release_speed, "Builds the project in release-speed mode":
  echo "--- Starting release-speed Build ---"
  exec "nim c --mm:arc -d:release --opt:speed --out:build/wash.exe src/wash.nim"