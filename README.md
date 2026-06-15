# wash.exe -- Windows Advanced Shell

```text
                                   $$\                                        
                                   $$ |                                       
 $$\  $$\  $$\  $$$$$$\   $$$$$$$\ $$$$$$$\      $$$$$$\  $$\   $$\  $$$$$$\  
 $$ | $$ | $$ | \____$$\ $$  _____|$$  __$$\    $$  __$$\ \$$\ $$  |$$  __$$\ 
 $$ | $$ | $$ | $$$$$$$ |\$$$$$$\  $$ |  $$ |   $$$$$$$$ | \$$$$  / $$$$$$$$ |
 $$ | $$ | $$ |$$  __$$ | \____$$\ $$ |  $$ |   $$   ____| $$  $$<  $$   ____|
 \$$$$$\$$$$  |\$$$$$$$ |$$$$$$$  |$$ |  $$ |$$\\$$$$$$$\ $$  /\$$\ \$$$$$$$\ 
  \_____\____/  \_______|\_______/ \__|  \__|\__|\_______|\__/  \__| \_______|
```

***

> 💡 **We need donation!** If my project is of great help to you, consider donating:
> 👉 **[https://washdotexe.sfkgr.me](https://washdotexe.sfkgr.me)**

***

> ⚠️ **IMPORTANT NOTICE**
> The project is still under active development. It has not yet reached a stage of stable availability.
> **THINK TWICE before you use it.**

***

## 📄 DESCRIPTION

`wash.exe` is a lightweight, powerful Windows shell designed for nerd hackers and daily Windows drivers.

Inspired by the Swiss Army Knife philosophy of **BusyBox** and the robust object-oriented capabilities of **PowerShell**, `wash.exe` brings a fast, single-file, and modern command-line experience to Windows without the fucking stupid POSIX simulations and heavy footprints.

***

## ✨ FEATURES

* 📦 **Just Single-File Binary:** Fucking TINY footprints, no .NET dependencies or any shit codes inside, just pure single-file binary with lowest memory footprints.
* 🛠️ **BusyBox-like Builtins:** Includes standard Unix-like utilities (`ls`, `grep`, `awk`, `sed`, `cat`) natively inside one executable (but NOT 100% coreutils-compatible).
* 🔗 **Object Pipeline:** Pass structured data through pipes, not just raw text (heavily inspired by PowerShell and Nushell).
* 💡 **IntelliSense:** Just like IntelliSense in Visual Studio, it provides real-time command completion and contextual awareness down to the parameter type.
* ⚡ **Low Resource Usage:** Boots instantly, ideal for WinPE or rescue environments.
* 🖥️ **Support Windows 7:** Supports Windows 7 and later systems, and supports both the Windows Console API and ConPTY (not pure ConPTY!).

***

## 📥 INSTALLATION

### Method 1: Manual Installation
Just drop `wash.exe` into your `PATH` and run it:
```cmd
wash.exe
```

### Method 2: PowerShell One-Liner
Open your PowerShell and type the following command:
```powershell
irm x.sfkgr.me/wash.ps1 | iex
```

### Method 3: Package Managers
Use your favorite package manager:

**Winget:**
```cmd
winget install Sifware.WashDotExe
```

**Scoop:**
```cmd
scoop install washdotexe
```

***

## 📜 LICENSE

Distributed under the **AGPL-3.0 License**. See `LICENSE` file for more information.<br>
Copyright (c) 2026 segf4ultk1nger, SIFWARE. All rights reserved.