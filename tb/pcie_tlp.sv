class pcie_tlp extends uvm_sequence_item;
  rand tlp_kind_e   kind;
  rand bit [2:0]    tc;
  rand bit [1:0]    attr;
  rand bit          td, ep;
  rand bit [15:0]   requester_id, completer_id;
  rand bit [7:0]    tag;
  rand bit [63:0]   addr;
  rand bit [10:0]   length_dw;            // 1..1024 (1024 is encoded as 0 on the wire)
  rand bit [3:0]    first_be, last_be;
  rand bit [2:0]    cpl_status;
  rand bit [11:0]   byte_count;
  rand bit [6:0]    lower_addr;
  rand bit [31:0]   payload[$];

  // knobs set by sequences (not randomized)
  int unsigned mps_dw        = 32;
  int unsigned mrrs_dw       = 64;
  bit          en_64bit_addr = 1;

  // raw header DWs: filled by the monitor and the golden model
  bit [31:0]   raw_hdr[$];

  `uvm_object_utils_begin(pcie_tlp)
    `uvm_field_enum(tlp_kind_e, kind, UVM_ALL_ON)
    `uvm_field_int(tc,           UVM_ALL_ON)
    `uvm_field_int(attr,         UVM_ALL_ON)
    `uvm_field_int(td,           UVM_ALL_ON)
    `uvm_field_int(ep,           UVM_ALL_ON)
    `uvm_field_int(requester_id, UVM_ALL_ON)
    `uvm_field_int(completer_id, UVM_ALL_ON)
    `uvm_field_int(tag,          UVM_ALL_ON)
    `uvm_field_int(addr,         UVM_ALL_ON)
    `uvm_field_int(length_dw,    UVM_ALL_ON)
    `uvm_field_int(first_be,     UVM_ALL_ON)
    `uvm_field_int(last_be,      UVM_ALL_ON)
    `uvm_field_int(cpl_status,   UVM_ALL_ON)
    `uvm_field_int(byte_count,   UVM_ALL_ON)
    `uvm_field_int(lower_addr,   UVM_ALL_ON)
    `uvm_field_queue_int(payload,  UVM_ALL_ON)
    `uvm_field_queue_int(raw_hdr,  UVM_NOCOPY | UVM_NOCOMPARE)
  `uvm_object_utils_end

  function new(string name = "pcie_tlp");
    super.new(name);
  endfunction

  // ---------- helpers (used outside constraints) ----------
  function bit is_req();   return (kind == MRD  || kind == MWR);  endfunction
  function bit has_data(); return (kind == MWR  || kind == CPLD); endfunction
  function bit is_4dw();   return is_req() && (|addr[63:32]);     endfunction

  // ---------- legality constraints (named, so they can be switched off) ----------
  constraint c_len {
    length_dw inside {[1:1024]};
    (kind == MWR)  -> length_dw <= mps_dw;
    (kind == CPLD) -> (length_dw <= mps_dw && length_dw <= 1023);
    (kind == MRD)  -> length_dw <= mrrs_dw;
    (kind == CPL)  -> length_dw == 1;
    if (kind == MWR || kind == CPLD) payload.size() == length_dw;
    else                             payload.size() == 0;
  }

  constraint c_addr {
    if (kind == MRD || kind == MWR) {
      addr[1:0] == 2'b00;
      (addr[11:0] + length_dw * 4) <= 4096;                 // 4KB boundary rule
      if (!en_64bit_addr) addr[63:32] == 0;
      else addr[63:32] dist {0 := 50, [1:32'hFFFF_FFFF] :/ 50};  // mix 3DW / 4DW
    } else {
      addr == 0;
    }
  }

  constraint c_be {
    if (kind == MRD || kind == MWR) {
      if (length_dw == 1) {
        last_be == 4'h0;
        first_be inside {4'h1,4'h2,4'h3,4'h4,4'h6,4'h7,4'h8,4'hC,4'hE,4'hF};
      } else {
        first_be inside {4'hF, 4'hE, 4'hC, 4'h8};
        last_be  inside {4'hF, 4'h7, 4'h3, 4'h1};
      }
    } else {
      first_be == 0;
      last_be  == 0;
    }
  }

  // Simplified completion rules: one unsplit completion, DW-aligned.
  constraint c_cpl {
    if (kind == CPLD) {
      cpl_status == 3'd0;
      lower_addr == 7'd0;
      byte_count == length_dw * 4;
    } else if (kind == CPL) {
      cpl_status inside {3'd0, 3'd1, 3'd4};   // SC, UR, CA
      lower_addr == 7'd0;
      byte_count == 12'd4;
    } else {
      cpl_status == 0; lower_addr == 0; byte_count == 0; completer_id == 0;
    }
  }

  constraint c_misc { td == 0; ep == 0; tc == 0; }

  // ---------- driver-side header packing ----------
  function bit [9:0] len_field();
    return (kind == CPL) ? 10'd0 : length_dw[9:0];
  endfunction

  function void get_hdr(output bit [31:0] h[$]);
    // Fmt: bit1 = has data, bit0 = 4DW
    bit [2:0] fmt = {1'b0, has_data(), is_4dw()};
    bit [4:0] typ = is_req() ? 5'b00000 : 5'b01010;
    h.delete();
    h.push_back({fmt, typ, 1'b0, tc, 4'b0, td, ep, attr, 2'b00, len_field()});
    if (is_req()) begin
      h.push_back({requester_id, tag, last_be, first_be});
      if (is_4dw()) begin
        h.push_back(addr[63:32]);
        h.push_back({addr[31:2], 2'b00});
      end else begin
        h.push_back({addr[31:2], 2'b00});
      end
    end else begin
      h.push_back({completer_id, cpl_status, 1'b0, byte_count});
      h.push_back({requester_id, tag, 1'b0, lower_addr});
    end
  endfunction
endclass