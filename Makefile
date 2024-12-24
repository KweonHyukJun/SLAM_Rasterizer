SRC_DIR = ../src/
SRC_FILES = $(addprefix $(SRC_DIR)/, \
	Backward/pixel_group/Backward_Rasterizer_group_unit.sv \
	Backward/pixel_group/Backward_Rasterizer_unit/Backward_Rasterizer_unit.sv \
	Backward/pixel_group/Backward_Rasterizer_unit/submodule/Backward_skip_unit.sv \
	shared_submodules/fixed_arbiter.sv \
	Backward/pixel_group/Backward_Rasterizer_unit/submodule/gradient_unit.sv \
)

SIM_DIR = ../verif/tb
SIM_FILES = $(addprefix $(SIM_DIR)/, \
	Backward/tb_Backward_Rasterizer_group_unit_to_frame.sv \
)


SYN_DIR = ../../SLAM_Rasterizer/syn
SYN_FILES = $(addprefix $(SYN_DIR)/, \
	top.syn.tcl \
)

SIM_RUN_DIR = ./output
FORWARD_SIM_RUN_DIR = ./output_forward
BACKWARD_SIM_RUN_DIR = ./output_backward
BACKWARD_GRAD_MERGE_SIM_RUN_DIR = ./output_backward_grad_merge
LOSS_SIM_RUN_DIR = ./output_loss

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
	DW_fp_mac.v \
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
${FORWARD_SIM_RUN_DIR}/simv : ${FORWARD_SIM_RUN_DIR}/clean
	@mkdir -p ${FORWARD_SIM_RUN_DIR}
	@cd ${FORWARD_SIM_RUN_DIR} && $(VV) $(VVOPTS) $(SRC_FILES) $(SIM_FILES);
	@./$@;

${BACKWARD_SIM_RUN_DIR}/simv : ${BACKWARD_SIM_RUN_DIR}/clean
	@mkdir -p ${BACKWARD_SIM_RUN_DIR}
	@cd ${BACKWARD_SIM_RUN_DIR} && $(VV) $(VVOPTS) $(SRC_FILES) $(SIM_FILES);
	@./$@;

${BACKWARD_GRAD_MERGE_SIM_RUN_DIR}/simv : ${BACKWARD_GRAD_MERGE_SIM_RUN_DIR}/clean
	@mkdir -p ${BACKWARD_GRAD_MERGE_SIM_RUN_DIR}
	@cd ${BACKWARD_GRAD_MERGE_SIM_RUN_DIR} && $(VV) $(VVOPTS) $(SRC_FILES) $(SIM_FILES);
	@./$@;

${FORWARD_SIM_RUN_DIR}/waveform : ${FORWARD_SIM_RUN_DIR}/simv
	cd ${FORWARD_SIM_RUN_DIR} && ${nWave} dump.fsdb

${BACKWARD_SIM_RUN_DIR}/waveform : ${BACKWARD_SIM_RUN_DIR}/simv
	cd ${BACKWARD_SIM_RUN_DIR} && ${nWave} dump.fsdb

${BACKWARD_GRAD_MERGE_SIM_RUN_DIR}/waveform : ${BACKWARD_GRAD_MERGE_SIM_RUN_DIR}/simv
	cd ${BACKWARD_GRAD_MERGE_SIM_RUN_DIR} && ${nWave} dump.fsdb



${FORWARD_SIM_RUN_DIR}/verdi : ${FORWARD_SIM_RUN_DIR}/simv
	cd ${FORWARD_SIM_RUN_DIR} && ${Verdi} $(DW_FILES) $(SRC_FILES) $(SIM_FILES);

${BACKWARD_SIM_RUN_DIR}/verdi : ${BACKWARD_SIM_RUN_DIR}/simv
	cd ${BACKWARD_SIM_RUN_DIR} && ${Verdi} $(DW_FILES) $(SRC_FILES) $(SIM_FILES);

${BACKWARD_GRAD_MERGE_SIM_RUN_DIR}/verdi : ${BACKWARD_GRAD_MERGE_SIM_RUN_DIR}/simv
	cd ${BACKWARD_GRAD_MERGE_SIM_RUN_DIR} && ${Verdi} $(DW_FILES) $(SRC_FILES) $(SIM_FILES);



# Target for synthesis
${SYN_RUN_DIR}/syn:
	mkdir -p ${SYN_RUN_DIR}
	cd ${SYN_RUN_DIR} && ${DC} -f $(SYN_FILES) ${DCOPTS} | tee ./dc_shell.log
	echo "Synthesis Completed"





# Clean target to remove simulation files only
${SIM_RUN_DIR}/clean:
	@rm -rf novas.*
	@rm -rf ucli.key
	@rm -rf verdiLog
	@rm -rf *.log
	@rm -rf ${SIM_RUN_DIR}/*
	@echo "Simulation Clean Completed"
	@rm -rf csrc

${FORWARD_SIM_RUN_DIR}/clean:
	@rm -rf novas.*
	@rm -rf ucli.key
	@rm -rf *.log
	@rm -rf ${FORWARD_SIM_RUN_DIR}/*
	@echo "Simulation Clean Completed"
	@rm -rf csrc

${BACKWARD_SIM_RUN_DIR}/clean:
	@rm -rf novas.*
	@rm -rf ucli.key
	@rm -rf *.log
	@rm -rf ${BACKWARD_SIM_RUN_DIR}/*
	@echo "Simulation Clean Completed"
	@rm -rf csrc

${BACKWARD_GRAD_MERGE_SIM_RUN_DIR}/clean:
	@rm -rf novas.*
	@rm -rf ucli.key
	@rm -rf *.log
	@rm -rf ${BACKWARD_GRAD_MERGE_SIM_RUN_DIR}/*
	@echo "Simulation Clean Completed"
	@rm -rf csrc
