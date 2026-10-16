`timescale 1ns/1ps
interface pcie_if (input logic clk, input logic rst_n);
  logic        valid;
  logic        ready;
  logic        sop;
  logic        eop;
  logic [31:0] data;

  clocking drv_cb @(posedge clk);
    default input #1step output #1;
    output valid, sop, eop, data;
    input  ready;
  endclocking

  clocking mon_cb @(posedge clk);
    default input #1step;
    input valid, ready, sop, eop, data;
  endclocking
endinterface