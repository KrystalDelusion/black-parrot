`ifdef __DLATCH_P_CELL_TYPE
module \$_DLATCH_P_ (input E, input D, output Q);
    `__DLATCH_P_CELL_TYPE _TECHMAP_REPLACE_ (.`__DLATCH_P_D_PIN(D), .`__DLATCH_P_E_PIN(E), .`__DLATCH_P_Q_PIN(Q));
endmodule
`endif

`ifdef __DLATCH_N_CELL_TYPE
module \$_DLATCH_N_ (input E, input D, output Q);
    `__DLATCH_N_CELL_TYPE _TECHMAP_REPLACE_ (.`__DLATCH_N_D_PIN(D), .`__DLATCH_N_E_PIN(E), .`__DLATCH_N_Q_PIN(Q));
endmodule
`endif
