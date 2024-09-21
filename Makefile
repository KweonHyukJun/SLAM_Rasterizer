SRC_DIR = ../src
SRC_FILES = $(addprefix $(SRC_DIR)/, \
	skip_and_alpha.sv \
)

SIM_DIR = ../verif/tb
SIM_FILES = $(addprefix $(SIM_DIR)/, \
	tb_skip_and_alpha.sv \
)

SYN_DIR = ../syn
SYN_FILES = $(addprefix $(SYN_DIR)/, \
	top.syn.tcl \
)


RUN_DIR = ./output

SYNOPSYS = /ids/tools/SYNOPSYS/syn/S-2021.06-SP4

DW_DIR = /ids/tools/SYNOPSYS/syn/S-2021.06-SP4/dw/sim_ver

DW_FILES = $(addprefix $(DW_DIR)/, \
	DW_fp_i2flt.v \
	DW_fp_add.v \
	DW_fp_mult.v \
)


VV = vcs -full64
VVOPTS =-o simv -notice -line +lint=all,noVCDE,noUI +v2k -timescale=1ns/10ps -quiet \
	+define+DEBUG -debug_access+all -sverilog -kdb \
	+incdir+$(SRC_DIR) -Mdirectory=$(SIM_DIR)/csrc \
	+vc+list -CC "-I$(VCS_HOME)/include" \
	+incdir+$(SYNOPSYS)/dw/sim_ver -y $(SYNOPSYS)/dw/sim_ver/*.v \
	-l vcs_compile.log

nWave = nWave

Verdi = Verdi
VerdiOPTS = ""

DC = dc_shell-xg-t -64bit
DCOPTS = ""

${RUN_DIR}/simv : clean
	@cd ${RUN_DIR} && $(VV) $(VVOPTS) $(SRC_FILES) $(SIM_FILES);
	@./$@;

${RUN_DIR}/waveform : ${RUN_DIR}/simv
	cd ${RUN_DIR} && ${nWave} dump.fsdb

${RUN_DIR}/verdi: ${RUN_DIR}/simv
	cd ${RUN_DIR} && ${Verdi} -sv $(SRC_FILES) $(SIM_FILES);

${RUN_DIR}/syn:
	mkdir -p ${RUN_DIR}
	cd ${RUN_DIR} && ${DC} -f $(SYN_FILES);

clean:
	@rm -rf ${RUN_DIR}/*
	@echo "Make Clean"