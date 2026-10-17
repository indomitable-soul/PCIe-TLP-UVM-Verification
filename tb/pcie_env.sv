class pcie_env extends uvm_env;
  `uvm_component_utils(pcie_env)

  pcie_agent      agent;
  pcie_scoreboard sb;
  pcie_coverage   cov;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = pcie_agent     ::type_id::create("agent", this);
    sb    = pcie_scoreboard::type_id::create("sb",    this);
    cov   = pcie_coverage  ::type_id::create("cov",   this);
  endfunction

  function void connect_phase(uvm_phase phase);
    agent.driver.ap.connect(sb.sent_export);        // expected side
    agent.monitor.ap.connect(sb.obs_export);        // actual side
    agent.monitor.ap.connect(cov.analysis_export);  // coverage
  endfunction
endclass