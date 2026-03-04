# -----------------------------------------------------------------------------
# Copyright (c) 2020-2024 RISC-V Steel contributors
#
# This work is licensed under the MIT License, see LICENSE file for details.
# SPDX-License-Identifier: MIT
# -----------------------------------------------------------------------------

# 🛠️ RVX RISC-V Application Build System

> A lightweight, portable, CMake-based build system designed for bare-metal RISC-V applications.  
> ✅ Enhanced by **Thinh – Faculty of Computer Engineering | UIT | ASIC LAB – University of Information Technology – VNU HCM**

---

## 📌 Overview

This project provides a ready-to-use infrastructure for building **bare-metal RISC-V** applications using the `riscv32-unknown-elf` toolchain, with support for memory configuration, custom linker scripts, and easy integration of third-party libraries like `libsteel`.

---

## 🧰 Features

- Cross-compilation for **RISC-V RV32I or RV32IZicsr**
- Customizable memory layout via linker symbols
- Output formats: `.elf`, `.bin`, `.hex`, `.objdump`, `.map`
- Easy integration of external libraries
- Clean separation of source and build trees
- Minimal CMake requirement: 3.15

---

## 🗂️ Project Structure
your_project/
├── CMakeLists.txt # Main build script
├── main.c # Your application code
├── bootstrap.S # Startup/reset handler
├── link.ld # Linker script
├── external/ # External libraries (manually cloned)
│ └── libsteel/ # Example library
├── build/ # Auto-generated build output
└── README.md # This file


---

## ⚙️ Configurable Build Parameters (in `CMakeLists.txt`)

| Variable         | Description                                               | Example        |
|------------------|-----------------------------------------------------------|----------------|
| `APP_NAME`       | Executable name (applies to `.elf`, `.hex`, etc.)         | `my_app`       |
| `MEMORY_SIZE`    | Total memory to define via linker symbol                  | `8K`, `64K`    |
| `STACK_SIZE`     | Stack size in bytes (0 if unused)                         | `2K`           |
| `HEAP_SIZE`      | Heap size in bytes (0 if unused)                          | `4K`           |
| `APP_ARCH`       | RISC-V ISA features (e.g. `rv32i`, `rv32izicsr`)          | `rv32izicsr`   |
| `APP_ABI`        | ABI used (`ilp32` for RV32)                               | `ilp32`        |
| `LINKER_SCRIPT`  | Path to custom linker script                              | `link.ld`      |

---

## 🚀 Building the Project

### 🧱 Requirements

- RISC-V GCC toolchain (https://github.com/riscv-collab/riscv-gnu-toolchain)
- CMake ≥ 3.15
- GNU Make


###🔧 How to Add a *.h File to libsteel
Copy your header file to:
external/libsteel/libsteel/

Open external/libsteel/libsteel.h and add:
#include <libsteel/your_file.h>

Update the CMakeLists.txt in libsteel to register the new header:
set(HEADERS
  ...
  ${CMAKE_CURRENT_LIST_DIR}/libsteel/your_file.h       # ← add this line
  ${CMAKE_CURRENT_LIST_DIR}/libsteel.h
)

In your application, include it via:
#include <libsteel/libsteel.h>
or
#include <libsteel/your_file.h>

### 🧪 Commands

```bash
make                # Build with Debug mode (default)
make release        # Build with Release optimization
make clean          # Remove build and output files



✍️ Modified By
Thinh – Faculty of Computer Engineering
UIT ASIC LAB – University of Information Technology – VNU HCM