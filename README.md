# PCIe Transaction Layer Packet (TLP) Generator & UVM Verification Environment

A complete SystemVerilog/UVM verification environment designed to generate, drive, and verify PCI Express (PCIe) Transaction Layer Packets (TLPs). The testbench verifies protocol compliance, corner-case addressing boundaries, payload limits, and achieves 100% functional coverage using a combination of constrained-random verification (CRV) and directed sequences.



## Architecture Overview

The verification environment follows standard UVM component hierarchy:

- **Agent (pcie_agent)**: Encapsulates the driver, monitor, and sequencer for modular reuse.
- **Driver (pcie_driver)**: Converts high-level sequence items into cycle-accurate interface pin toggles supporting pipeline handshakes (valid/ready).
- **Monitor (pcie_monitor)**: Samples pin-level interface transactions and broadcasts observed TLPs via analysis ports.
- **Scoreboard (pcie_scoreboard)**: Validates transmitted vs. received packets end-to-end to ensure data integrity and protocol compliance.
- **Reference Model (pcie_ref_model)**: Predicts expected responses and completion status for iCoverage Collector (pcie_coverage)or (pcie_coverage)**: Tracks functional coverage bins across packet types, length buckets, and byte-enable combinations.



## Supported TransacTLP Kindsres

- **TLP Kinds**: Memory Reads (MRd), Memory Writes (MWr), Completions (Cpl), and Completions with Data (CplD).
- **Addressing**: 32-bit (3-DW header) and 64-bit (4-DW hPCIe Constraints & Corner Casestraint4 KB Address Boundary Checksddress Boundary Checks**: Guarantees transactions do not cross 4 KB physical page boundaries ((addr[11:0] + length_dw * 4) <= 4096).
  - **Max Payload Size (MPS)**: Payload saturation and enforcement up to1024-DW Encodinges.
  - **1024-DW Encoding**: Verifies proper 10-bit zero-encoding (10'b00_0000_0000) for Byte-Enable Matrix.
  - **Byte-Enable Matrix**: Comprehensive sweeping of First Byte Enable (FBE) and Last Byte Enable (LBE) patterns.



## Coverage & Regression Results

Functional coverage was measured across multiple random seeds using Synopsys VCS.

| Test Case | Seeds Tested | Transactions / Seed | Error / Fatal Count | Functional Coverage |
| :--- | :--- | :--- | :--- | :--- |
| pcie_corner_test | S100.00% | 640 | 0 / 0 | **100.00%** |
| pcie_rand_test | Seeds 1 – 10 | 300 | 0 / 0 | 87.09% – 96.77% |

### Coverage Closure Strategy
Purely random stimulus (pcie_rand_test) left coverage holes (averaging 90–95%) due to the low statistical probability of hitting rare protocol corners (such as single-DW completions and exact 4KB boundaries). Developing targeted, directed sequences (pcie_edge_4k_seq, pcie_max_len_seq, pcie_be_sweep_seq, and pcie_cpl_len_seq) closed every cross-coverage bin (x_kind_len, cp_fbe, cp_off), achieving **100% deterministic coverage** across all regression seeds.



## Directory Structure

`text
├── design.sv             # Target DUT / loopback interface model
├── testbench.sv          # Top-level testbench module and clock/reset generation
├── pcie_pkg.sv           # Package aggregating all components and sequences
├── pcie_tlp.sv           # Base UVM sequence item defining TLP fields & constraints
├── pcie_seqs.sv          # Constrained-random and corner-case directed sequences
├── pcie_driver.sv        # Pin-level driver
├── pcie_monitor.sv       # Bus monitor and analysis port broadcaster
├── pcie_agent.sv         # UVM Agent
├── pcie_coverage.sv      # Functional covergroups and cross coverage
├── pcie_scoreboard.sv    # Transaction checker and scoreboard
├── pcie_ref_model.sv     # Transaction prediction reference model
├── pcie_env.sv           # UVM Environment connecting agent and subscribers
└── pcie_tests.sv         # Test library containing base and corner test cases
