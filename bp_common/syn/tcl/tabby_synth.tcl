# Based on yosys_synth.tcl
yosys -import

set design           wrapper
set lib_file         $::env(TIMING_LIB)
set flist_vcs        $::env(FLIST)
set elab_v_file      $::env(WRAPPER_ELAB)
set coarse_v_file    $::env(WRAPPER_COARSE)
set fine_v_file      $::env(WRAPPER_FINE)
set map_v_file       $::env(WRAPPER_MAP)
set synth_v_file     $::env(WRAPPER_SYNTH)
set stat_file        stats.json
set check_file       checks.txt

set tiehi_cell       sky130_fd_sc_hd__conb
set tiehi_pin        HI
set tielo_cell       sky130_fd_sc_hd__conb
set tielo_pin        LO
set clkbuf_cell      sky130_fd_sc_hd__clkbuf
set clkbuf_pin       X
set buf_cell         sky130_fd_sc_hd__buf
set buf_ipin         A
set buf_opin         X


# read design
verific -f -sv ${flist_vcs}

# elaborate design hierarchy
synth -run begin:coarse -top ${design}
write_verilog -nostr -noattr -noexpr -nohex -nodec ${elab_v_file}

# coarse synth
synth -run coarse:fine
write_verilog -nostr -noattr -noexpr -nohex -nodec ${coarse_v_file}

# fine synth
synth -run fine:check
write_verilog -nostr -noattr -noexpr -nohex -nodec ${fine_v_file}

# mapping to cell lib
dfflibmap -liberty ${lib_file}
write_verilog -nostr -noattr -noexpr -nohex -nodec ${map_v_file}

# mapping logic to cell lib
abc -liberty ${lib_file}

# Set X to zero
setundef -zero

# mapping constants and clock buffers to cell lib
hilomap -hicell ${tiehi_cell} ${tiehi_pin} -locell ${tielo_cell} ${tielo_pin}
clkbufmap -buf ${clkbuf_cell} ${clkbuf_pin}

# Split nets to single bits and map to buffers
splitnets
insbuf -buf ${buf_cell} ${buf_ipin} ${buf_opin}

# Clean up the design
opt_clean -purge

# Check and print statistics
tee -o ${check_file} check -mapped -noinit
tee -o ${stat_file} stat -top ${design} -liberty ${lib_file} -tech cmos -width -json

# write synthesized design
write_verilog -nostr -noattr -noexpr -nohex -nodec ${synth_v_file}
