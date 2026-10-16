// ---------- base: weighted random mix ----------
class pcie_rand_seq extends uvm_sequence #(pcie_tlp);
  `uvm_object_utils(pcie_rand_seq)

  int unsigned n             = 100;
  int unsigned mps_dw        = 32;
  int unsigned mrrs_dw       = 64;
  bit          en_64bit_addr = 1;
  int          w_mrd = 40, w_mwr = 40, w_cpl = 10, w_cpld = 10;

  function new(string name = "pcie_rand_seq");
    super.new(name);
  endfunction

  task body();
    repeat (n) begin
      pcie_tlp t = pcie_tlp::type_id::create("t");
      t.mps_dw = mps_dw; t.mrrs_dw = mrrs_dw; t.en_64bit_addr = en_64bit_addr;
      start_item(t);
      if (!t.randomize() with {
            kind dist {MRD := local::w_mrd, MWR := local::w_mwr,
                       CPL := local::w_cpl, CPLD := local::w_cpld}; })
        `uvm_fatal("SEQ", "randomize failed")
      finish_item(t);
    end
  endtask
endclass

// ---------- corner: request ends exactly at the 4KB boundary ----------
class pcie_edge_4k_seq extends pcie_rand_seq;
  `uvm_object_utils(pcie_edge_4k_seq)
  function new(string name = "pcie_edge_4k_seq"); super.new(name); endfunction
  task body();
    repeat (n) begin
      pcie_tlp t = pcie_tlp::type_id::create("t");
      t.mps_dw = mps_dw; t.mrrs_dw = mrrs_dw; t.en_64bit_addr = en_64bit_addr;
      start_item(t);
      if (!t.randomize() with {
            kind inside {MRD, MWR};
            (addr[11:0] + length_dw * 4) == 4096; })
        `uvm_fatal("SEQ", "randomize failed")
      finish_item(t);
    end
  endtask
endclass

// ---------- corner: maximum payload (MPS) and the 1024-DW "length = 0" encoding ----------
class pcie_max_len_seq extends pcie_rand_seq;
  `uvm_object_utils(pcie_max_len_seq)
  function new(string name = "pcie_max_len_seq"); super.new(name); endfunction
  task body();
    pcie_tlp t;
    repeat (n) begin                           // length == MPS
      t = pcie_tlp::type_id::create("t");
      t.mps_dw = mps_dw; t.mrrs_dw = mrrs_dw; t.en_64bit_addr = en_64bit_addr;
      start_item(t);
      if (!t.randomize() with { kind == MWR; length_dw == mps_dw; })
        `uvm_fatal("SEQ", "randomize failed")
      finish_item(t);
    end
    repeat (10) begin                          // 1024 DW (wire encoding 0)
      t = pcie_tlp::type_id::create("t");
      t.mps_dw = 1024; t.mrrs_dw = 1024; t.en_64bit_addr = en_64bit_addr;
      start_item(t);
      if (!t.randomize() with { kind inside {MRD, MWR}; length_dw == 1024; addr[11:0] == 0; })
        `uvm_fatal("SEQ", "randomize failed")
      finish_item(t);
    end
  endtask
endclass

// ---------- corner: every legal first_be for single-DW requests ----------
class pcie_be_sweep_seq extends pcie_rand_seq;
  `uvm_object_utils(pcie_be_sweep_seq)
  function new(string name = "pcie_be_sweep_seq"); super.new(name); endfunction
  task body();
    repeat (n) begin
      pcie_tlp t = pcie_tlp::type_id::create("t");
      t.mps_dw = mps_dw; t.mrrs_dw = mrrs_dw; t.en_64bit_addr = en_64bit_addr;
      start_item(t);
      if (!t.randomize() with { kind inside {MRD, MWR}; length_dw == 1; })
        `uvm_fatal("SEQ", "randomize failed")
      finish_item(t);
    end
  endtask
endclass

// Completions at every length bucket
class pcie_cpl_len_seq extends pcie_rand_seq;
  `uvm_object_utils(pcie_cpl_len_seq)
  function new(string name = "pcie_cpl_len_seq"); super.new(name); endfunction
  task body();
    int unsigned lens[4] = '{1, 3, 10, 24};   // buckets: 1, 2-4, 5-16, 17+
    foreach (lens[i]) repeat (n) begin
      pcie_tlp t = pcie_tlp::type_id::create("t");
      t.mps_dw = mps_dw; t.mrrs_dw = mrrs_dw; t.en_64bit_addr = en_64bit_addr;
      start_item(t);
      if (!t.randomize() with { kind == CPLD; length_dw == lens[i]; })
        `uvm_fatal("SEQ", "randomize failed")
      finish_item(t);
    end
  endtask
endclass