
`ifndef BP_FE_PC_GEN_PKGDEF_SVH
`define BP_FE_PC_GEN_PKGDEF_SVH

  import bp_common_pkg::*;

  typedef struct packed
  {
    logic any;
    logic br;
    logic jal;
    logic jalr;
    logic call;
    logic _return;
    logic full1;
    logic full2;
    logic comp;
    logic [38:0] imm;
  }  bp_fe_decode_s;

  /*
   * bp_fe_instr_scan_s specifies metadata about the instruction, including FE-special opcodes
   *   and the calculated branch target
   */
  typedef struct packed
  {
    logic branch;
    logic jal;
    logic jalr;
    logic call;
    logic _return;
    logic full;
    logic clow;
    logic chigh;
  }  bp_fe_instr_scan_s;

`endif

