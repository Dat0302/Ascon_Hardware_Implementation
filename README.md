# ASCON Hardware Implementation

**Languages:** Verilog, C

## Overview
This repository contains the Register-Transfer Level (RTL) hardware implementation of the ASCON lightweight cryptographic algorithm. The project focuses on designing a highly efficient hardware accelerator IP core optimized for integration into System-on-Chip (SoC) architectures.

The core successfully executes all ASCON operational phases:
1. Initialization
2. Processing Associated Data (AD)
3. Plaintext / Ciphertext Processing
4. Finalization

## Architecture & Block Diagram
The hardware architecture is divided into two main components:
* Datapath: Handles the 320-bit permutation state, substitution layer (S-box), and linear diffusion layer.
* Control Unit: A Finite State Machine (FSM) that orchestrates the data flow across the different ASCON phases and manages the communication interface.

## Repository Structure
To maintain a clean project, the repository is organized as follows:

```text
Ascon_Hardware_Implementation/
├── hardware/                # Verilog source files for the ASCON core
│   ├── ascon_aead_128.v
│   ├── ascon_permutation.v
│   └── ascon_wishbone_wrapper.v
├── software/          
├── testbench/                   
└── README.md
