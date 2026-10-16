// ---------- base test: env, objection, drain ----------
class pcie_base_test extends uvm_test;
  `uvm_component_utils(pcie_base_test)

  pcie_env     env;
  int unsigned num_pkts = 300;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    void'($value$plusargs("NUM_PKTS=%d", num_pkts));
    env = pcie_env::type_id::create("env", this);
  endfunction

  virtual task run_seqs();
  endtask

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    run_seqs();
    drain();
    phase.drop_objection(this);
  endtask

  task drain();
    fork
      begin wait (env.sb.exp_q.size() == 0); end
      begin #1ms; `uvm_error("TEST", "drain timeout: expected TLPs never arrived") end
    join_any
    disable fork;
    #50ns;
  endtask
endclass

// ---------- random mix ----------
class pcie_rand_test extends pcie_base_test;
  `uvm_component_utils(pcie_rand_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  task run_seqs();
    pcie_rand_seq s = pcie_rand_seq::type_id::create("s");
    s.n = num_pkts;
    s.start(env.agent.sequencer);
  endtask
endclass

// ---------- corners, then random ----------
class pcie_corner_test extends pcie_base_test;
  `uvm_component_utils(pcie_corner_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  task run_seqs();
    pcie_edge_4k_seq  s1 = pcie_edge_4k_seq ::type_id::create("s1");
    pcie_max_len_seq  s2 = pcie_max_len_seq ::type_id::create("s2");
    pcie_be_sweep_seq s3 = pcie_be_sweep_seq::type_id::create("s3");
    pcie_rand_seq     s4 = pcie_rand_seq    ::type_id::create("s4");
    pcie_cpl_len_seq s5 = pcie_cpl_len_seq::type_id::create("s5");
    s1.n = 100; s2.n = 30; s3.n = 200; s4.n = num_pkts;
    s1.start(env.agent.sequencer);
    s2.start(env.agent.sequencer);
    s3.start(env.agent.sequencer);
    s4.start(env.agent.sequencer);
    s5.start(env.agent.sequencer);
    s5.n = 5;
   
  endtask
endclass

// ---------- negative test: the checker MUST catch injected corruption ----------
class pcie_neg_test extends pcie_base_test;
  `uvm_component_utils(pcie_neg_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    uvm_config_db#(int unsigned)::set(this, "env.agent.driver", "corrupt_every", 7);
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    // Expected mismatches are demoted so the log does not fail on them;
    // check_phase below judges the test instead.
    env.sb.set_report_severity_id_override(UVM_ERROR, "SB_HDR", UVM_WARNING);
    env.sb.set_report_severity_id_override(UVM_ERROR, "SB_FLD", UVM_WARNING);
  endfunction

  task run_seqs();
    pcie_rand_seq s = pcie_rand_seq::type_id::create("s");
    s.n = num_pkts;
    s.start(env.agent.sequencer);
  endtask

  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if (env.agent.driver.n_corrupted == 0)
      `uvm_error("NEG", "No packets were corrupted - test is meaningless")
    else if (env.sb.n_fail != env.agent.driver.n_corrupted)
      `uvm_error("NEG", $sformatf("Checker caught %0d of %0d injected errors",
                                  env.sb.n_fail, env.agent.driver.n_corrupted))
    else
      `uvm_info("NEG", $sformatf("Checker caught all %0d injected errors",
                                 env.sb.n_fail), UVM_NONE)
  endfunction
endclass

// ---------- golden-model unit test: hand-computed headers, no DUT, no stimulus ----------
class pcie_golden_unit_test extends uvm_test;
  `uvm_component_utils(pcie_golden_unit_test)
  int unsigned errors = 0;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task check_hdr(string nm, pcie_tlp t, pcie_ref_model m, bit [31:0] e[$]);
    pcie_tlp   x = m.predict(t);
    bit [31:0] pk[$];
    t.get_hdr(pk);
    if (x.raw_hdr.size() != e.size() || pk.size() != e.size()) begin
      `uvm_error("UNIT", $sformatf("%s: size model=%0d pack=%0d exp=%0d",
                                   nm, x.raw_hdr.size(), pk.size(), e.size()))
      errors++;
      return;
    end
    foreach (e[i]) begin
      if (x.raw_hdr[i] !== e[i]) begin
        `uvm_error("UNIT", $sformatf("%s: MODEL DW%0d got=%08h exp=%08h", nm, i, x.raw_hdr[i], e[i]))
        errors++;
      end
      if (pk[i] !== e[i]) begin
        `uvm_error("UNIT", $sformatf("%s: PACK  DW%0d got=%08h exp=%08h", nm, i, pk[i], e[i]))
        errors++;
      end
    end
    `uvm_info("UNIT", $sformatf("%s checked", nm), UVM_LOW)
  endtask

  task run_phase(uvm_phase phase);
    pcie_ref_model m = pcie_ref_model::type_id::create("m");
    pcie_tlp t;
    phase.raise_objection(this);

    // 1) MWr, 3DW, 1 DW, addr 0x1000, req 0x0100, tag 0x05, BE 0xF
    t = pcie_tlp::type_id::create("t");
    t.kind = MWR; t.requester_id = 16'h0100; t.tag = 8'h05; t.addr = 64'h1000;
    t.length_dw = 1; t.first_be = 4'hF; t.last_be = 4'h0; t.payload = {32'hDEADBEEF};
    check_hdr("MWR_3DW", t, m, '{32'h40000001, 32'h0100050F, 32'h00001000});

    // 2) MRd, 4DW, 4 DW, addr 0x1_2345_6780, req 0x0200, tag 0x1A, BE F/F
    t = pcie_tlp::type_id::create("t");
    t.kind = MRD; t.requester_id = 16'h0200; t.tag = 8'h1A; t.addr = 64'h1_2345_6780;
    t.length_dw = 4; t.first_be = 4'hF; t.last_be = 4'hF;
    check_hdr("MRD_4DW", t, m, '{32'h20000004, 32'h02001AFF, 32'h00000001, 32'h23456780});

    // 3) CplD, 2 DW, completer 0x0008, status SC, byte_count 8, req 0x0100, tag 0x05
    t = pcie_tlp::type_id::create("t");
    t.kind = CPLD; t.completer_id = 16'h0008; t.cpl_status = 0; t.byte_count = 12'd8;
    t.requester_id = 16'h0100; t.tag = 8'h05; t.lower_addr = 0; t.length_dw = 2;
    t.payload = {32'h1111_1111, 32'h2222_2222};
    check_hdr("CPLD", t, m, '{32'h4A000002, 32'h00080008, 32'h01000500});

    // 4) Cpl (no data), status UR (1), byte_count 4, req 0x0100, tag 0x07
    t = pcie_tlp::type_id::create("t");
    t.kind = CPL; t.completer_id = 16'h0008; t.cpl_status = 3'd1; t.byte_count = 12'd4;
    t.requester_id = 16'h0100; t.tag = 8'h07; t.lower_addr = 0; t.length_dw = 1;
    check_hdr("CPL_UR", t, m, '{32'h0A000000, 32'h00082004, 32'h01000700});

    if (errors == 0) `uvm_info("UNIT", "GOLDEN UNIT TEST PASSED", UVM_NONE)
    phase.drop_objection(this);
  endtask
endclass