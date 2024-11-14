SRC_DIR = ../src
SRC_FILES = $(addprefix $(SRC_DIR)/, \
	gaussian_id_merge_sort.sv \
)

SIM_DIR = ../verif/tb
SIM_FILES = $(addprefix $(SIM_DIR)/, \
	tb_gaussian_id_merge_sort.sv \
)

SYN_DIR = ../../SLAM_Rasterizer/syn
SYN_FILES = $(addprefix $(SYN_DIR)/, \
	top.syn.tcl \
)

SIM_RUN_DIR = ./output
SYN_RUN_DIR = ./output_{Hz}


SYNOPSYS = /ids/tools/SYNOPSYS/syn/S-2021.06-SP4

DW_DIR = /ids/tools/SYNOPSYS/syn/S-2021.06-SP4/dw/sim_ver

DW_FILES = $(addprefix $(DW_DIR)/, \
	DW_fp_add.v \
	DW_fp_i2flt.v \
	DW_fp_mult.v \
	DW_fp_sum3.v \
	DW_fp_cmp.v \
	DW_fp_exp.v \
	DW_fp_div.v \
	DW_fp_dp2.v \
)


VV = vcs -full64
VVOPTS =-o simv -notice -line +lint=all,noVCDE,noUI +v2k -timescale=1ns/10ps -quiet \
	+define+DEBUG -debug_access+all -sverilog -kdb \
	+incdir+$(SRC_DIR) -Mdirectory=../$(RUN_DIR)/csrc \
	+vc+list -CC "-I$(VCS_HOME)/include" \
	+incdir+$(SYNOPSYS)/dw/sim_ver -y $(SYNOPSYS)/dw/sim_ver/*.v \
	-l vcs_compile.log

nWave = nWave

Verdi = Verdi
VerdiOPTS = ""

DC = dc_shell-xg-t -64bit
DCOPTS = ""

# Targets for simulation
${SIM_RUN_DIR}/simv : clean
	@mkdir -p ${SIM_RUN_DIR}
	@cd ${SIM_RUN_DIR} && $(VV) $(VVOPTS) $(SRC_FILES) $(SIM_FILES);
	@./$@;

${SIM_RUN_DIR}/waveform : ${SIM_RUN_DIR}/simv
	cd ${SIM_RUN_DIR} && ${nWave} dump.fsdb

${SIM_RUN_DIR}/verdi : ${SIM_RUN_DIR}/simv
	cd ${SIM_RUN_DIR} && ${Verdi} $(DW_FILES) $(SRC_FILES) $(SIM_FILES);

# Target for synthesis
${SYN_RUN_DIR}/syn:
	mkdir -p ${SYN_RUN_DIR}
	cd ${SYN_RUN_DIR} && ${DC} -f $(SYN_FILES) ${DCOPTS} | tee ./dc_shell.log
	echo "Synthesis Completed"

# Clean target to remove simulation files only
clean:
	@rm -rf novas.*
	@rm -rf ucli.key
	@rm -rf verdiLog
	@rm -rf *.log
	@rm -rf ${SIM_RUN_DIR}/*
	@echo "Simulation Clean Completed"