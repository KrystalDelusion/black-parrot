/*
 * bp_fe_realigner.sv
 *
 * 64-bit I$ output buffer which reconstructs 64-bit instructions scaned as two halves.
 * Passes through the input data unmodified when the scan is aligned.
 */
`include "bp_common_defines.svh"
`include "bp_fe_defines.svh"

module bp_fe_realigner
 import bp_common_pkg::*;
 import bp_fe_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , localparam decode_width_lp = $bits(bp_fe_decode_s)
   , localparam fetch_width_lp = $bits(bp_fe_scan_s)
   )
  (input                                              clk_i
   , input                                            reset_i

   // I$ data
   , input                                            icache_data_v_i
   , input [fetch_cinstr_gp-1:0][cinstr_width_gp-1:0] icache_data_i
   , output logic                                     icache_yumi_o

   , input [vaddr_width_p-1:0]                        if2_pc_i

   // Redirection from backend
   //   and whether to restore the instruction data
   //   and PC to resume a scan
   , input                                            redirect_v_i
   , input [vaddr_width_p-1:0]                        redirect_pc_i
   , input [fetch_width_gp-1:0]                       redirect_instr_i
   , input [fetch_ptr_gp-1:0]                         redirect_count_i

   // Assembled instruction, PC and count
   , output logic                                     assembled_v_o
   , output logic [vaddr_width_p-1:0]                 assembled_pc_o
   , output logic [fetch_width_gp-1:0]                assembled_instr_o
   , output logic [fetch_ptr_gp-1:0]                  assembled_count_o
   , output logic [fetch_ptr_gp-1:0]                  assembled_partial_o
   , input [fetch_ptr_gp-1:0]                         assembled_yumi_i
   );

  wire [fetch_sel_gp-1:0] if2_pc_sel = if2_pc_i[1+:fetch_sel_gp];
  wire [fetch_ptr_gp-1:0] if2_count = icache_data_v_i ? (fetch_cinstr_gp - if2_pc_sel) : '0;

  logic assembled_v;
  logic [fetch_ptr_gp-1:0] assembled_count;
  logic [fetch_width_gp-1:0] assembled_shift, assembled_instr;

  logic leftover_v;
  logic [vaddr_width_p-1:0] leftover_pc;
  logic [fetch_width_gp-1:0] leftover_instr;
  logic [fetch_ptr_gp-1:0] leftover_count;

  logic [vaddr_width_p-1:0] partial_pc_n, partial_pc_r;
  logic [fetch_width_gp-1:0] partial_instr_n, partial_instr_r;
  logic [fetch_ptr_gp-1:0] partial_count_n, partial_count_r;

  wire partial_w_v = redirect_v_i | |assembled_yumi_i;
  assign partial_pc_n = redirect_v_i ? redirect_pc_i : leftover_pc;
  assign partial_instr_n = redirect_v_i ? redirect_instr_i : leftover_instr;
  assign partial_count_n = redirect_v_i ? redirect_count_i : leftover_v ? leftover_count : '0;
  bsg_dff_reset_en
   #(.width_p(fetch_ptr_gp+fetch_width_gp+vaddr_width_p))
   partial_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(partial_w_v)

     ,.data_i({partial_count_n, partial_instr_n, partial_pc_n})
     ,.data_o({partial_count_r, partial_instr_r, partial_pc_r})
     );
  wire partial_v = |partial_count_r;

  // CORRECT
  // TODODODODODOD: count == partial count if !if2_instr_v_i
  // Can possibly combine this.....
  assign assembled_count = if2_count + partial_count_r;

  // icache_data_v_i partial_v
  //       0            x       partial_count
  //       1            0       if2_count
  //       1            1       fetch_cinstr_gp

  // if partial, shift
  // fetch_cinstr - partial_count
  // if !partial, shift
  // fetch_cinstr
  assign assembled_shift = (fetch_cinstr_gp - partial_count_r + if2_pc_sel) << 3'd4;
  assign assembled_instr = {icache_data_i, partial_instr_r} >> assembled_shift;

  assign leftover_v = |assembled_yumi_i & |leftover_count;
  assign leftover_pc = assembled_pc_o + (assembled_yumi_i << 1'b1);
  assign leftover_instr = icache_data_i;
  assign leftover_count = assembled_count - assembled_yumi_i;

  // {if2_instr} {partial_instr}
  // O :assembed_pc = if2_pc - (partial_count << 1)
  // O :assembled_count = partial_v_r ? fetch_cinstr_gp : (fetch_cinstr_gp - pc_sel);
  //       assembled shift = fetch_cinstr_gp - partial_count + pc_sel
  // O :assembled instr = {if2_instr, partial_instr} >> assembled shift; // EQUATED
  //   partial_count_n  = assembled count - scan count
  //       partial shift = (partial_count_n << 4)
  //   partial_instr_n  = if2_instr >> partial_shift

  assign assembled_v_o = partial_v ? 1'b1 : icache_data_v_i;
  assign assembled_pc_o = partial_v ? partial_pc_r : if2_pc_i;
  assign assembled_instr_o = assembled_instr;
  assign assembled_count_o = partial_v ? (partial_count_r + if2_count) : if2_count;
  assign assembled_partial_o = partial_count_r;

  // TODO: Only acknowledge I$ if partial is insufficient to fulfill
  assign icache_yumi_o = icache_data_v_i & |assembled_yumi_i;

endmodule

