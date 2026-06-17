#[
    | wash.exe - Windows Advanced Shell
    | Copyright (c) segf4ultk1nger, SIFWARE 2026
    | Licensed under AGPL-3.
]#

import std/os

# keep this stupid prompt function
proc wash_prompting*() =
  stdout.write(getCurrentDir()&">")
