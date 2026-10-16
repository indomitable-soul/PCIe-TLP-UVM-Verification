class pcie_monitor extends uvm_monitor;
  `uvm_component_utils(pcie_monitor)

  virtual pcie_if               vif;
  uvm_analysis_port #(pcie_tlp) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db#(virtual pcie_if)::get(this, "", "vif", vif))
      `uvm_fatal("MON", "virtual interface not set")
  endfunction

  task run_phase(uvm_phase phase);
    bit [31:0] b[$];
    wait (vif.rst_n === 1'b1);
    forever begin
      @(vif.mon_cb);
      if (vif.mon_cb.valid && vif.mon_cb.ready) begin
        if (vif.mon_cb.sop) b.delete();
        b.push_back(vif.mon_cb.data);
        if (vif.mon_cb.eop) ap.write(decode(b));
      end
    end
  endtask

  function pcie_tlp decode(bit [31:0] b[$]);
    pcie_tlp  t = pcie_tlp::type_id::create("obs");
    bit [2:0] fmt;
    bit [4:0] typ;
    int       hdr_dws;
    bit       has_data;

    fmt      = b[0][31:29];
    typ      = b[0][28:24];
    hdr_dws  = fmt[0] ? 4 : 3;
    has_data = fmt[1];

    if (b.size() < hdr_dws) begin
      `uvm_error("MON", $sformatf("Packet has %0d DWs, header needs %0d", b.size(), hdr_dws))
      return t;
    end

    t.raw_hdr   = b[0:hdr_dws-1];
    t.tc        = b[0][22:20];
    t.td        = b[0][15];
    t.ep        = b[0][14];
    t.attr      = b[0][13:12];
    t.length_dw = (b[0][9:0] == 0) ? 11'd1024 : b[0][9:0];

    if (typ == 5'b00000) begin                       // memory request
      t.kind         = has_data ? MWR : MRD;
      t.requester_id = b[1][31:16];
      t.tag          = b[1][15:8];
      t.last_be      = b[1][7:4];
      t.first_be     = b[1][3:0];
      t.addr         = fmt[0] ? {b[2], b[3][31:2], 2'b00}
                              : {32'h0, b[2][31:2], 2'b00};
    end else if (typ == 5'b01010) begin              // completion
      t.kind         = has_data ? CPLD : CPL;
      t.completer_id = b[1][31:16];
      t.cpl_status   = b[1][15:13];
      t.byte_count   = b[1][11:0];
      t.requester_id = b[2][31:16];
      t.tag          = b[2][15:8];
      t.lower_addr   = b[2][6:0];
      if (!has_data) t.length_dw = 1;                // Cpl: length field not meaningful
    end else begin
      `uvm_error("MON", $sformatf("Unknown Fmt/Type %b/%b", fmt, typ))
    end

    for (int i = hdr_dws; i < b.size(); i++) t.payload.push_back(b[i]);

    if (has_data && t.payload.size() != t.length_dw)
      `uvm_error("MON_LEN", $sformatf("Payload %0d DW but header length %0d",
                                      t.payload.size(), t.length_dw))
    return t;
  endfunction
endclass