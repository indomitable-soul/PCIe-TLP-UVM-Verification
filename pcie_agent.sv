class pcie_agent extends uvm_agent;
  `uvm_component_utils(pcie_agent)

  uvm_sequencer #(pcie_tlp) sequencer;
  pcie_driver               driver;
  pcie_monitor              monitor;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    sequencer = uvm_sequencer#(pcie_tlp)::type_id::create("sequencer", this);
    driver    = pcie_driver ::type_id::create("driver",  this);
    monitor   = pcie_monitor::type_id::create("monitor", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction
endclass