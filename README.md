# ASCON Hardware Implementation

![License](https://img.shields.io/badge/License-MIT-blue.svg)
![Language](https://img.shields.io/badge/Language-Verilog%20%2F%20SystemVerilog-orange.svg)

## 📌 Overview
This repository contains the Register-Transfer Level (RTL) hardware implementation of the **ASCON** lightweight cryptographic algorithm. The project focuses on designing a highly efficient hardware accelerator IP core optimized for integration into System-on-Chip (SoC) architectures.

The core successfully executes all ASCON operational phases:
1. **Initialization**
2. **Processing Associated Data (AD)**
3. **Plaintext / Ciphertext Processing**
4. **Finalization**

## 🏗️ Architecture & Block Diagram
The hardware architecture is divided into two main components:
* **Datapath:** Handles the 320-bit permutation state, substitution layer (S-box), and linear diffusion layer.
* **Control Unit:** A Finite State Machine (FSM) that orchestrates the data flow across the different ASCON phases and manages the communication interface.

*(You can add an image of your block diagram here)*
> `![ASCON Block Diagram](docs/block_diagram.png)`

## 📂 Repository Structure
To maintain a clean and scalable project, the repository is organized as follows:

```text
Ascon_Hardware_Implementation/
├── rtl/                # Verilog/SystemVerilog source files for the ASCON core
│   ├── datapath.v
│   ├── control_unit.v
│   └── ascon_top.v
├── tb/                 # Verification environment (UVM/SystemVerilog testbenches)
│   ├── agents/
│   ├── sequences/
│   └── ascon_tb_top.sv
├── sim/                # Simulation scripts (e.g., ModelSim, VCS)
├── syn/                # Synthesis scripts and constraints (ASIC Flow / Design Compiler)
├── docs/               # Datasheets, block diagrams, and project documentation
└── README.md
