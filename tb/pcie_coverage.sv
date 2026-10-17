class pcie_coverage extends uvm_subscriber #(pcie_tlp);
  `uvm_component_utils(pcie_coverage)

  int unsigned n_samples = 0;                       // NEW

  covergroup cg with function sample(tlp_kind_e k, int unsigned len, bit four_dw,
                                     bit [3:0] fbe, bit [3:0] lbe, bit [11:0] off);
    option.per_instance = 1;                        // NEW
    cp_kind : coverpoint k;
    cp_len  : coverpoint len {
      bins one     = {1};
      bins s2_4    = {[2:4]};
      bins s5_16   = {[5:16]};
      bins s17_max = {[17:1024]};
    }
    cp_4dw  : coverpoint four_dw;
    cp_fbe  : coverpoint fbe {
      bins none    = {0};
      bins legal[] = {1,2,3,4,6,7,8,12,14,15};
    }
    cp_lbe  : coverpoint lbe {
      bins none    = {0};
      bins legal[] = {1,3,7,15};
    }
    cp_off  : coverpoint off {
      bins start = {[0:63]};
      bins mid   = {[64:4031]};
      bins edge_bin  = {[4032:4095]};
    }
    x_kind_len : cross cp_kind, cp_len {
      ignore_bins cpl_long = binsof(cp_kind) intersect {CPL} &&
                             binsof(cp_len)  intersect {[2:1024]};
    }
    x_kind_4dw : cross cp_kind, cp_4dw {
      ignore_bins cpl_4dw = binsof(cp_kind) intersect {CPL, CPLD} &&
                            binsof(cp_4dw)  intersect {1};
    }
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    cg = new();
  endfunction

  function void write(pcie_tlp t);                  // REPLACED
    n_samples++;
    cg.sample(t.kind, t.length_dw, t.is_4dw(), t.first_be, t.last_be, t.addr[11:0]);
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("COV", $sformatf("samples taken = %0d", n_samples), UVM_NONE)   // NEW
    `uvm_info("COV", $sformatf("TOTAL coverage = %0.2f%%", cg.get_inst_coverage()), UVM_NONE)
    `uvm_info("COV", $sformatf("  cp_kind=%0.1f cp_len=%0.1f cp_4dw=%0.1f cp_fbe=%0.1f cp_lbe=%0.1f cp_off=%0.1f",
              cg.cp_kind.get_inst_coverage(), cg.cp_len.get_inst_coverage(),
              cg.cp_4dw.get_inst_coverage(),  cg.cp_fbe.get_inst_coverage(),
              cg.cp_lbe.get_inst_coverage(),  cg.cp_off.get_inst_coverage()), UVM_NONE)
    `uvm_info("COV", $sformatf("  x_kind_len=%0.1f x_kind_4dw=%0.1f",
              cg.x_kind_len.get_inst_coverage(), cg.x_kind_4dw.get_inst_coverage()), UVM_NONE)
  endfunction
endclass