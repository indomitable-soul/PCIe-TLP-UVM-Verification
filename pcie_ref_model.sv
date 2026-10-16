class pcie_ref_model extends uvm_object;
  `uvm_object_utils(pcie_ref_model)

  function new(string name = "pcie_ref_model");
    super.new(name);
  endfunction

  function pcie_tlp predict(pcie_tlp in);
    pcie_tlp   exp = pcie_tlp::type_id::create("exp");
    bit [31:0] dw0, dw1, dw2, dw3;
    bit [2:0]  fmt;
    bit [4:0]  typ;
    bit        four_dw;
    bit        wd;

    four_dw = (in.kind == MRD || in.kind == MWR) && (|in.addr[63:32]);
    wd      = (in.kind == MWR || in.kind == CPLD);

    // Fmt: 000 = 3DW no data, 001 = 4DW no data, 010 = 3DW data, 011 = 4DW data
    if (wd) fmt = four_dw ? 3'b011 : 3'b010;
    else    fmt = four_dw ? 3'b001 : 3'b000;
    typ = (in.kind == CPL || in.kind == CPLD) ? 5'b01010 : 5'b00000;

    dw0 = '0; dw1 = '0; dw2 = '0; dw3 = '0;
    dw0[31:29] = fmt;
    dw0[28:24] = typ;
    dw0[22:20] = in.tc;
    dw0[15]    = in.td;
    dw0[14]    = in.ep;
    dw0[13:12] = in.attr;
    dw0[9:0]   = (in.kind == CPL) ? 10'd0 : in.length_dw[9:0];

    if (in.kind == MRD || in.kind == MWR) begin
      dw1[31:16] = in.requester_id;
      dw1[15:8]  = in.tag;
      dw1[7:4]   = in.last_be;
      dw1[3:0]   = in.first_be;
      if (four_dw) begin
        dw2        = in.addr[63:32];
        dw3[31:2]  = in.addr[31:2];
      end else begin
        dw2[31:2]  = in.addr[31:2];
      end
    end else begin
      dw1[31:16] = in.completer_id;
      dw1[15:13] = in.cpl_status;
      dw1[12]    = 1'b0;                 // BCM
      dw1[11:0]  = in.byte_count;
      dw2[31:16] = in.requester_id;
      dw2[15:8]  = in.tag;
      dw2[6:0]   = in.lower_addr;
    end

    exp.copy(in);                        // expected decoded fields + payload
    exp.raw_hdr.delete();
    exp.raw_hdr.push_back(dw0);
    exp.raw_hdr.push_back(dw1);
    exp.raw_hdr.push_back(dw2);
    if (four_dw) exp.raw_hdr.push_back(dw3);
    return exp;
  endfunction
endclass