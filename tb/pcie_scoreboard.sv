`uvm_analysis_imp_decl(_sent)
`uvm_analysis_imp_decl(_obs)

class pcie_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(pcie_scoreboard)

  uvm_analysis_imp_sent #(pcie_tlp, pcie_scoreboard) sent_export;
  uvm_analysis_imp_obs  #(pcie_tlp, pcie_scoreboard) obs_export;

  pcie_ref_model ref_model;
  pcie_tlp       exp_q[$];
  int unsigned   n_pass, n_fail;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    sent_export = new("sent_export", this);
    obs_export  = new("obs_export",  this);
    ref_model   = pcie_ref_model::type_id::create("ref_model");
  endfunction

  // Stimulus side: run the golden model
  function void write_sent(pcie_tlp t);
    exp_q.push_back(ref_model.predict(t));
  endfunction

  // Single-field check helper
  function bit chk(string name, longint unsigned e, longint unsigned a);
    if (e !== a) begin
      `uvm_error("SB_FLD", $sformatf("%s mismatch: exp=0x%0h act=0x%0h", name, e, a))
      return 0;
    end
    return 1;
  endfunction

  // DUT/wire side: compare
  function void write_obs(pcie_tlp a);
    pcie_tlp e;
    bit      ok = 1;

    if (exp_q.size() == 0) begin
      `uvm_error("SB", $sformatf("Unexpected TLP observed:\n%s", a.sprint()))
      n_fail++;
      return;
    end
    e = exp_q.pop_front();

    // 1) raw header DWs (catches packing errors)
    if (e.raw_hdr.size() != a.raw_hdr.size()) begin
      `uvm_error("SB_HDR", $sformatf("Header DW count exp=%0d act=%0d",
                                     e.raw_hdr.size(), a.raw_hdr.size()))
      ok = 0;
    end else begin
      foreach (e.raw_hdr[i])
        if (e.raw_hdr[i] !== a.raw_hdr[i]) begin
          `uvm_error("SB_HDR", $sformatf("DW%0d exp=0x%08h act=0x%08h",
                                         i, e.raw_hdr[i], a.raw_hdr[i]))
          ok = 0;
        end
    end

    // 2) decoded fields (readable messages, catches decode errors)
    ok &= chk("kind",      int'(e.kind), int'(a.kind));
    ok &= chk("tc",        e.tc,         a.tc);
    ok &= chk("attr",      e.attr,       a.attr);
    ok &= chk("td",        e.td,         a.td);
    ok &= chk("ep",        e.ep,         a.ep);
    ok &= chk("length_dw", e.length_dw,  a.length_dw);
    if (e.is_req()) begin
      ok &= chk("requester_id", e.requester_id, a.requester_id);
      ok &= chk("tag",          e.tag,          a.tag);
      ok &= chk("addr",         e.addr,         a.addr);
      ok &= chk("first_be",     e.first_be,     a.first_be);
      ok &= chk("last_be",      e.last_be,      a.last_be);
    end else begin
      ok &= chk("completer_id", e.completer_id, a.completer_id);
      ok &= chk("requester_id", e.requester_id, a.requester_id);
      ok &= chk("tag",          e.tag,          a.tag);
      ok &= chk("cpl_status",   e.cpl_status,   a.cpl_status);
      ok &= chk("byte_count",   e.byte_count,   a.byte_count);
      ok &= chk("lower_addr",   e.lower_addr,   a.lower_addr);
    end

    // 3) payload
    if (e.payload != a.payload) begin
      `uvm_error("SB_DATA", "payload mismatch")
      ok = 0;
    end

    if (ok) n_pass++;
    else begin
      n_fail++;
      `uvm_info("SB", $sformatf("EXPECTED:\n%sACTUAL:\n%s", e.sprint(), a.sprint()), UVM_LOW)
    end
  endfunction

  function void check_phase(uvm_phase phase);
    if (exp_q.size() != 0)
      `uvm_error("SB", $sformatf("%0d expected TLPs never observed", exp_q.size()))
    if (n_pass + n_fail == 0)
      `uvm_error("SB", "Scoreboard checked nothing - environment is not wired correctly")
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("SB", $sformatf("RESULT: PASS=%0d FAIL=%0d", n_pass, n_fail), UVM_NONE)
  endfunction
endclass