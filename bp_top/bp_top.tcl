# Based on yosys_synth.tcl
yosys -import

set design           wrapper
set lib_file         $::env(TIMING_LIB)
set flist_vcs        $::env(FLIST)
set synth_v_file     $::env(WRAPPER_SYNTH)

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

# elaborate design hierarchy & do coarse-grain synth
synth -run :fine -top ${design}

# ??
chformal -remove

# do fine-grain synth
synth -run fine:check
stat

# map to cell lib
dfflibmap -liberty ${lib_file}
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
check -mapped -noinit
stat -top ${design} -liberty ${lib_file} -tech cmos -width -json

# write synthesized design
write_verilog -nostr -noattr -noexpr -nohex -nodec ${synth_v_file}
