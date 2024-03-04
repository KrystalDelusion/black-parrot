/*
 * bp_fe_btb.v
 *
 * Branch Target Buffer (BTB) stores the addresses of the branch targets and the
 * corresponding branch sites. Branch happens from the branch sites to the branch
 * targets. In order to save the logic sizes, the BTB is designed to have limited
 * entries for storing the branch sites, branch target pairs. The implementation
 * uses the bsg_mem_1rw_sync_synth RAM design.
 *
 * Notes:
 *   BTB writes are prioritized over BTB reads, since they come on redirections and therefore
 *     the BTB read is most likely for an erroneous instruction, anyway.
 */

`include "bp_common_defines.svh"
`include "bp_fe_defines.svh"

module bp_fe_btb
 import bp_common_pkg::*;
 import bp_fe_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   )
  (input                              clk_i
   , input                            reset_i

   , output logic                     init_done_o

   // Synchronous read
   , input [vaddr_width_p-1:0]          r_addr_i
   , input                              r_v_i
   , output logic [btb_tag_width_p-1:0] tag_o
   , output logic [btb_idx_width_p-1:0] idx_o
   , output logic [vaddr_width_p-1:0]   br_tgt_o
   , output logic                       br_tgt_v_o
   , output logic                       br_tgt_jmp_o

   // Synchronous write
   , input                            w_v_i
   , input                            w_clr_i
   , input                            w_jmp_i
   , input [btb_tag_width_p-1:0]      w_tag_i
   , input [btb_idx_width_p-1:0]      w_idx_i
   , input [vaddr_width_p-1:0]        w_tgt_i
   , input                            w_force_i
   , output logic                     w_yumi_o
   );

  typedef struct packed
  {
    logic                       v;
    logic                       jmp;
    logic [btb_tag_width_p-1:0] tag;
    logic [vaddr_width_p-1:0]   tgt;
  }  bp_btb_entry_s;

  ///////////////////////
  // Initialization state machine
  enum logic [1:0] {e_reset, e_clear, e_run} state_n, state_r;
  wire is_reset = (state_r == e_reset);
  wire is_clear = (state_r == e_clear);
  wire is_run   = (state_r == e_run);

  assign init_done_o = is_run;

  localparam btb_els_lp = 2**btb_idx_width_p;
  logic [`BSG_WIDTH(btb_els_lp)-1:0] init_cnt;
  bsg_counter_clear_up
   #(.max_val_p(btb_els_lp), .init_val_p(0))
   init_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.clear_i(1'b0)
     ,.up_i(is_clear)
     ,.count_o(init_cnt)
     );
  wire finished_init = (init_cnt == btb_els_lp-1'b1);

  always_comb
    case (state_r)
      e_clear: state_n = finished_init ? e_run : e_clear;
      e_run  : state_n = e_run;
      // e_reset
      default: state_n = e_clear;
    endcase

  // synopsys sync_set_reset "reset_i"
  always_ff @(posedge clk_i)
    if (reset_i)
      state_r <= e_reset;
    else
      state_r <= state_n;

  localparam hash_width_lp = fetch_sel_gp;
  wire [hash_width_lp-1:0]  r_hash_li = r_addr_i[1+:fetch_sel_gp];
  wire [btb_idx_width_p-1:0] r_idx_li = r_addr_i[1+fetch_sel_gp+:btb_idx_width_p];
  wire [btb_tag_width_p-1:0] r_tag_li = r_addr_i[1+fetch_sel_gp+btb_idx_width_p+:btb_tag_width_p] ^ r_hash_li;

  logic rw_same_addr;
  wire suppress_read = rw_same_addr & w_force_i;
  wire suppress_write = rw_same_addr & ~w_force_i;

  bp_btb_entry_s data_li;
  wire                          w_v_li = is_clear | (w_v_i & ~suppress_write);
  wire [btb_idx_width_p-1:0] w_addr_li = is_clear ? init_cnt : w_idx_i;
  // Bug in XSIM 2019.2 causes SEGV when assigning to structs with a mux
  bp_btb_entry_s new_btb;
  assign new_btb = '{v: 1'b1, jmp: w_jmp_i, tag: w_tag_i, tgt: w_tgt_i};
  assign data_li = (is_clear | (w_v_i & w_clr_i)) ? '0 : new_btb;

  bp_btb_entry_s data_lo;
  wire                           r_v_li = r_v_i & ~suppress_read;
  wire [btb_idx_width_p-1:0]  r_addr_li = r_idx_li;

  assign rw_same_addr = r_v_i & w_v_i & (r_idx_li == w_idx_i);

  bsg_mem_1r1w_sync
   #(.width_p($bits(bp_btb_entry_s)), .els_p(btb_els_lp), .latch_last_read_p(1))
   tag_mem
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.w_v_i(w_v_li)
     ,.w_addr_i(w_addr_li)
     ,.w_data_i(data_li)

     ,.r_v_i(r_v_li)
     ,.r_addr_i(r_addr_li)
     ,.r_data_o(data_lo)
     );
  assign w_yumi_o = is_run & w_v_li;

  logic suppress_read_r;
  bsg_dff_en
   #(.width_p(btb_tag_width_p+btb_idx_width_p+1))
   addr_reg
    (.clk_i(clk_i)
     ,.en_i(r_v_i)
     ,.data_i({r_tag_li, r_idx_li, suppress_read})
     ,.data_o({tag_o, idx_o, suppress_read_r})
     );

  assign br_tgt_v_o   = data_lo.v & (data_lo.tag == tag_o) & ~suppress_read_r;
  assign br_tgt_jmp_o = data_lo.v & data_lo.jmp;
  assign br_tgt_o     = data_lo.tgt;

endmodule

