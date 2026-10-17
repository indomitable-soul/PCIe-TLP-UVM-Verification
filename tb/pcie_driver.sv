class pcie_driver extends uvm_driver #(pcie_tlp);
  `uvm_component_utils(pcie_driver)

  virtual pcie_if               vif;
  uvm_analysis_port #(pcie_tlp) ap;

  int unsigned corrupt_every = 0;     // 0 = never; N = corrupt every Nth packet
  int unsigned n_sent        = 0;
  int unsigned n_corrupted   = 0;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db#(virtual pcie_if)::get(this, "", "vif", vif))
      `uvm_fatal("DRV", "virtual interface not set")
    void'(uvm_config_db#(int unsigned)::get(this, "", "corrupt_every", corrupt_every));
  endfunction

  task run_phase(uvm_phase phase);
    vif.drv_cb.valid <= 0;
    vif.drv_cb.sop   <= 0;
    vif.drv_cb.eop   <= 0;
    vif.drv_cb.data  <= '0;
    wait (vif.rst_n === 1'b1);
    forever begin
      seq_item_port.get_next_item(req);
      drive_item(req);
      seq_item_port.item_done();
    end
  endtask

  task drive_item(pcie_tlp t);
    bit [31:0] beats[$];
    bit [31:0] h[$];

    ap.write(t);                      // publish first, so the expected queue is filled before the monitor sees it
    t.get_hdr(h);
    beats = h;
    foreach (t.payload[i]) beats.push_back(t.payload[i]);

    n_sent++;
    if (corrupt_every != 0 && (n_sent % corrupt_every) == 0) begin
      beats[1][8] = ~beats[1][8];     // flip one bit in DW1 (after the expected header was published)
      n_corrupted++;
      `uvm_info("DRV", $sformatf("Corrupted packet #%0d (DW1 bit 8)", n_sent), UVM_MEDIUM)
    end

    @(vif.drv_cb);                    // align to a clock edge
    foreach (beats[i]) begin
      vif.drv_cb.valid <= 1;
      vif.drv_cb.data  <= beats[i];
      vif.drv_cb.sop   <= (i == 0);
      vif.drv_cb.eop   <= (i == beats.size() - 1);
      @(vif.drv_cb);
      while (!vif.drv_cb.ready) @(vif.drv_cb);
    end
    vif.drv_cb.valid <= 0;
    vif.drv_cb.sop   <= 0;
    vif.drv_cb.eop   <= 0;
  endtask
endclass