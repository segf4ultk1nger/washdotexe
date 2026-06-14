task dev, "Builds the project in debug mode":
  echo "--- Starting Dev Build ---"
  exec "nim c -g --opt:none --out:build/washdev.exe src/wash.nim"

task drun, "Build and run the project in debug mod":
  echo "--- Starting Dev Build ---"
  exec "nim c -g --opt:none --run --out:build/washdev.exe src/wash.nim"

task release, "Builds the project in release mode":
  echo "--- Starting Release Build ---"
  exec "nim c -d:release --opt:size --strip:on --out:build/wash.exe src/wash.nim"