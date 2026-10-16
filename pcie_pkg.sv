`timescale 1ns/1ps
package pcie_pkg;
  `include "uvm_macros.svh"
  import uvm_pkg::*;
  

  typedef enum {MRD, MWR, CPL, CPLD} tlp_kind_e;

  `include "pcie_tlp.sv"
  `include "pcie_ref_model.sv"
  `include "pcie_seqs.sv"
  `include "pcie_driver.sv"
  `include "pcie_monitor.sv"
  `include "pcie_agent.sv"
  `include "pcie_coverage.sv"
  `include "pcie_scoreboard.sv"
  `include "pcie_env.sv"
  `include "pcie_tests.sv"
endpackage