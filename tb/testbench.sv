`timescale 1ns/1ps
`include "uvm_macros.svh"
import uvm_pkg::*;

`include "pcie_pkg.sv"
import pcie_pkg::*;


module tb_top;
  
  logic clk   = 0;
  logic rst_n = 0;
  always #5 clk = ~clk;

  initial begin
    repeat (5) @(posedge clk);
    rst_n = 1;
  end

  pcie_if vif (clk, rst_n);
  assign vif.ready = 1'b1;            // loopback: the receiver is always ready

  initial begin
    uvm_config_db#(virtual pcie_if)::set(null, "*", "vif", vif);
    run_test("pcie_golden_unit_test");                       // test name comes from +UVM_TESTNAME
  end

initial begin
  $dumpfile("dump.vcd");
  $dumpvars;
end

endmodule