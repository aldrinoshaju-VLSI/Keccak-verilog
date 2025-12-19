# Keccak‑Verilog

A **Verilog hardware implementation of the Keccak cryptographic function** (the core permutation used in SHA‑3 and related sponge constructions). This repository contains RTL modules, testbenches, and auxiliary files to simulate, synthesize, and experiment with Keccak designs.

> **Note:** This project currently does not include formal documentation — this README serves as a starting point to understand and work with the code.

## 🧠 What is Keccak?

Keccak is the cryptographic permutation that forms the basis of the SHA‑3 family of hash functions standardized by NIST. It uses a sponge construction and a 5×5 state array to produce flexible‑length outputs. :contentReference[oaicite:0]{index=0}

## 📁 Repository Contents

| Directory / File | Description |
|------------------|-------------|
| `keccak.v` | Top‑level Verilog module defining the core Keccak permutation |
| `f_permutation.v` | Implementation of the internal Keccak‑f transformation |
| `padder*.v` | Padding logic used for message preparation |
| `round2in1*.v` | Round combinational/pipelined logic |
| `keccak_test*.v` | Testbench files for functional validation |
| `simulation/questa` | QuestaSim simulation setup files |
| `output_files`, `db`, `incremental_db` | Tool‑generated output and project metadata |

## 🔧 Supported Hardware Language

- **Verilog HDL** (RTL design)
- Compatible with common synthesis tools (e.g., Yosys, Synopsys) and simulators (e.g., QuestaSim, ModelSim)

## 🚀 Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/aldrinoshaju‑VLSI/Keccak‑verilog.git
cd Keccak‑verilog
