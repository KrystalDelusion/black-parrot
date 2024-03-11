/*
 * bp_fe_instr_scan.v
 *
 * Instr scan check if the intruction is aligned, compressed, or normal instruction.
 * The entire block is implemented in combinational logic, achieved within one cycle.
*/

`include "bp_common_defines.svh"
`include "bp_fe_defines.svh"

module bp_fe_scan
 import bp_common_pkg::*;
 import bp_fe_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , localparam decode_width_lp = $bits(bp_fe_decode_s)
   , localparam scan_width_lp = $bits(bp_fe_scan_s)
   )
  (input                                              v_i
   , input [vaddr_width_p-1:0]                        pc_i
   , input [fetch_cinstr_gp-1:0][cinstr_width_gp-1:0] instr_i
   , input [fetch_ptr_gp-1:0]                         count_i
   , input [fetch_ptr_gp-1:0]                         partial_i
   , output logic [fetch_ptr_gp-1:0]                  yumi_o

   , output logic                                     instr_v_o
   , output logic [vaddr_width_p-1:0]                 pc_o
   , output logic [fetch_width_gp-1:0]                instr_o
   , output logic [scan_width_lp-1:0]                 scan_o
   , output logic [fetch_ptr_gp-1:0]                  count_o
   , input                                            taken_i
   , input                                            ready_then_i
   );

  `bp_cast_o(bp_fe_scan_s, scan);

  bp_fe_decode_s [fetch_cinstr_gp-1:0] decode_lo;
  logic [fetch_cinstr_gp-1:-1][cinstr_width_gp-1:0] instr;
  logic [fetch_cinstr_gp-1:-1] full1;
  logic [fetch_cinstr_gp-1:0] branch;

  assign instr = {instr_i, 16'b0};
  assign full1[-1] = 1'b0;
  for (genvar i = 0; i < fetch_cinstr_gp; i++)
    begin : scan
      rv64_instr_rtype_s curr_instr;

      wire is_full1 = full1[i];
      wire is_full2 = full1[i-1];
      wire is_comp  = !full1[i] & !full1[i-1];

      assign curr_instr = is_full2 ? {instr[i], instr[i-1]} : instr[i];
      wire is_br = is_full2 && curr_instr inside {`RV64_BRANCH};
      wire is_jal = is_full2 && curr_instr inside {`RV64_JAL};
      wire is_jalr = is_full2 && curr_instr inside {`RV64_JALR};

      wire is_link_dest = curr_instr.rd_addr inside {5'h1, 5'h5};
      wire is_link_src  = curr_instr.rs1_addr inside {5'h1, 5'h5};
      wire is_link_match = is_link_src & is_link_dest & (curr_instr.rd_addr == curr_instr.rs1_addr);
      wire is_call = (is_jal | is_jalr) & is_link_dest;
      wire is_return = is_jalr & is_link_src & !is_link_match;

      wire is_cbr = is_comp && curr_instr inside {`RV64_CBEQZ, `RV64_CBNEZ};
      wire is_cj = is_comp && curr_instr inside {`RV64_CJ};
      wire is_cjr = is_comp && curr_instr inside {`RV64_CJR};
      wire is_cjalr = is_comp && curr_instr inside {`RV64_CJALR};

      wire is_clink_dest  = is_cjalr;
      wire is_clink_src   = curr_instr.rd_addr inside {5'h1, 5'h5};
      wire is_clink_match = is_clink_src & is_clink_dest & {curr_instr.rd_addr == 5'h1};
      wire is_ccall = (is_cj | is_cjr | is_cjalr) & is_clink_dest;
      wire is_creturn = (is_cjr | is_cjalr) & is_clink_src & !is_clink_match;

      wire is_any = is_br | is_jal | is_jalr | is_cbr | is_cj | is_cjr | is_cjalr;

      logic [vaddr_width_p-1:0] imm;
      always_comb
               if (is_br ) imm = `rv64_signext_b_imm(curr_instr ) + ((i - 1'b1) << 1'b1);
        else   if (is_jal) imm = `rv64_signext_j_imm(curr_instr ) + ((i - 1'b1) << 1'b1);
        else   if (is_cj ) imm = `rv64_signext_cj_imm(curr_instr) + ((i - 1'b0) << 1'b1);
        else   // if (is_cbr )
                           imm = `rv64_signext_cb_imm(curr_instr) + ((i - 1'b0) << 1'b1);

      assign full1[i] = &curr_instr[0+:2] && !full1[i-1];
      assign branch[i] = is_any & (i < count_i);
      assign decode_lo[i] =
       '{br      : is_br | is_cbr
         ,jal    : is_jal | is_cj
         ,jalr   : is_jalr | is_cjr | is_cjalr
         ,call   : is_call | is_ccall
         ,_return: is_return | is_creturn
         ,imm    : imm
         ,full1  : is_full1
         ,full2  : is_full2
         ,comp   : is_comp
         };
    end

  logic [`BSG_SAFE_CLOG2(fetch_cinstr_gp)-1:0] first_branch;
  logic any_branch;
  bsg_priority_encode
   #(.width_p(fetch_cinstr_gp), .lo_to_hi_p(1))
   first_pe
    (.i(branch)
     ,.addr_o(first_branch)
     ,.v_o(any_branch)
     );
  wire offsite_branch = (first_branch > '0);

  bp_fe_decode_s br_decode_lo;
  bsg_mux
   #(.width_p(decode_width_lp), .els_p(fetch_cinstr_gp))
   decode_mux
    (.data_i(decode_lo)
     ,.sel_i(first_branch)
     ,.data_o(br_decode_lo)
     );
  wire [vaddr_width_p-1:0] taken_imm  = br_decode_lo.imm;
  wire [vaddr_width_p-1:0] rebase_imm = ((first_branch + 1'b1) << 3'b1);
  wire [vaddr_width_p-1:0] linear_imm = (fetch_cinstr_gp << 3'b1);
  // TODO: These immediates are actually based off of 1f2, not fetch

  always_comb
    begin
      scan_cast_o = '0;

      scan_cast_o.br = br_decode_lo.br;
      scan_cast_o.jal = br_decode_lo.jal;
      scan_cast_o.jalr = br_decode_lo.jalr;
      scan_cast_o.call = br_decode_lo.call;
      scan_cast_o._return = br_decode_lo._return;
      scan_cast_o.linear = '0; // TODO: Other case

      // TODO: Should rebase whenever there are instructions past the first branch....!!!!!s
      scan_cast_o.rebase = offsite_branch & ~taken_i; // TODO: Other cases

      scan_cast_o.taken_imm = taken_imm;
      scan_cast_o.rebase_imm = rebase_imm;
      scan_cast_o.linear_imm = linear_imm;
    end

  wire [fetch_ptr_gp-1:0] branch_count = first_branch + 1'b1;
  wire [fetch_ptr_gp-1:0] linear_count = `BSG_MIN(count_i, fetch_cinstr_gp); // TODO: Subtract high full1

  assign pc_o = pc_i;
  assign instr_o = instr_i;
  assign count_o = v_i ? any_branch ? branch_count : linear_count : partial_i;
  assign instr_v_o = ready_then_i & v_i; // always valid except for edge case of high compressed

  // TODO: If rebase, flush pipe????
  assign yumi_o = instr_v_o ? (taken_i | offsite_branch) ? count_i : count_o : '0;

endmodule

