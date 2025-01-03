
FORWARD_SRC_DIR = ../src/
FORWARD_SRC_FILES = $(addprefix $(FORWARD_SRC_DIR)/, \
	Forward/pixel_group/Forward_Rasterizer_group_unit.sv \
	Forward/pixel_group/Forward_Rasterizer_unit/Forward_Rasterizer_unit.sv \
	Forward/pixel_group/Forward_Rasterizer_unit/submodule/Forward_skip_unit.sv \
	shared_submodules/fixed_arbiter.sv \
	Forward/pixel_group/Forward_Rasterizer_unit/submodule/splatting_unit.sv \
)

FORWARD_SIM_DIR = ../verif/tb
FORWARD_SIM_FILES = $(addprefix $(FORWARD_SIM_DIR)/, \
	Forward/tb_Forward_Rasterizer_group_unit.sv \
)

BACKWARD_SRC_DIR = ../src/
BACKWARD_SRC_FILES = $(addprefix $(BACKWARD_SRC_DIR)/, \
	Backward/pixel_group/Backward_Rasterizer_group_unit.sv \
	Backward/pixel_group/Backward_Rasterizer_unit/Backward_Rasterizer_unit.sv \
	Backward/pixel_group/Backward_Rasterizer_unit/submodule/Backward_skip_unit.sv \
	shared_submodules/fixed_arbiter.sv \
	Backward/pixel_group/Backward_Rasterizer_unit/submodule/gradient_unit.sv \
)

BACKWARD_SIM_DIR = ../verif/tb
BACKWARD_SIM_FILES = $(addprefix $(BACKWARD_SIM_DIR)/, \
	Backward/tb_Backward_Rasterizer_group_unit_to_frame.sv \
)


BACKWARD_GRAD_MERGE_SRC_DIR = ../src
BACKWARD_GRAD_MERGE_SRC_FILES = $(addprefix $(BACKWARD_GRAD_MERGE_SRC_DIR)/, \
	Backward/pixel_group/Gradient_merge_unit/Gradient_merge_unit_by_majority.sv \
	Backward/pixel_group/Gradient_merge_unit/submodule/majority_voter.sv \
	Backward/pixel_group/Gradient_merge_unit/submodule/majority_adder.sv \
	shared_submodules/FIFO.sv \
	shared_submodules/round_robin_arbiter.sv \
)

BACKWARD_GRAD_MERGE_SIM_DIR = ../verif/tb
BACKWARD_GRAD_MERGE_SIM_FILES = $(addprefix $(BACKWARD_GRAD_MERGE_SIM_DIR)/, \
	Backward/tb_Gradient_merge_unit_by_majority.sv \
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
VVOPTS_FORWARD =-o simv -notice -line +lint=all,noVCDE,noUI +v2k -timescale=1ns/10ps -quiet \
	+define+DEBUG -debug_access+all -sverilog -kdb \
	+incdir+$(SRC_DIR) -Mdirectory=../$(FORWARD_SIM_RUN_DIR)/csrc \
	+vc+list -CC "-I$(VCS_HOME)/include" \
	+incdir+$(SYNOPSYS)/dw/sim_ver -y $(SYNOPSYS)/dw/sim_ver/*.v \
	-l vcs_compile.log

VVOPTS_BACKWARD =-o simv -notice -line +lint=all,noVCDE,noUI +v2k -timescale=1ns/10ps -quiet \
	+define+DEBUG -debug_access+all -sverilog -kdb \
	+incdir+$(SRC_DIR) -Mdirectory=../$(BACKWARD_SIM_RUN_DIR)/csrc \
	+vc+list -CC "-I$(VCS_HOME)/include" \
	+incdir+$(SYNOPSYS)/dw/sim_ver -y $(SYNOPSYS)/dw/sim_ver/*.v \
	-l vcs_compile.log

VVOPTS_BACKWARD_GRAD_MERGE =-o simv -notice -line +lint=all,noVCDE,noUI +v2k -timescale=1ns/10ps -quiet \
	+define+DEBUG -debug_access+all -sverilog -kdb \
	+incdir+$(SRC_DIR) -Mdirectory=../$(BACKWARD_GRAD_MERGE_SIM_RUN_DIR)/csrc \
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
	@cd ${FORWARD_SIM_RUN_DIR} && $(VV) $(VVOPTS_FORWARD) $(FORWARD_SRC_FILES) $(FORWARD_SIM_FILES);
	@./$@;

${BACKWARD_SIM_RUN_DIR}/simv : ${BACKWARD_SIM_RUN_DIR}/clean
	@mkdir -p ${BACKWARD_SIM_RUN_DIR}
	@cd ${BACKWARD_SIM_RUN_DIR} && $(VV) $(VVOPTS_BACKWARD) $(BACKWARD_SRC_FILES) $(BACKWARD_SIM_FILES);
	@./$@;

${BACKWARD_GRAD_MERGE_SIM_RUN_DIR}/simv : ${BACKWARD_GRAD_MERGE_SIM_RUN_DIR}/clean
	@mkdir -p ${BACKWARD_GRAD_MERGE_SIM_RUN_DIR}
	@cd ${BACKWARD_GRAD_MERGE_SIM_RUN_DIR} && $(VV) $(VVOPTS_BACKWARD_GRAD_MERGE) $(BACKWARD_GRAD_MERGE_SRC_FILES) $(BACKWARD_GRAD_MERGE_SIM_FILES);
	@./$@;



${FORWARD_SIM_RUN_DIR}/waveform : ${FORWARD_SIM_RUN_DIR}/simv
	cd ${FORWARD_SIM_RUN_DIR} && ${nWave} forward_dump.fsdb

${BACKWARD_SIM_RUN_DIR}/waveform : ${BACKWARD_SIM_RUN_DIR}/simv
	cd ${BACKWARD_SIM_RUN_DIR} && ${nWave} backward_dump.fsdb

${BACKWARD_GRAD_MERGE_SIM_RUN_DIR}/waveform : ${BACKWARD_GRAD_MERGE_SIM_RUN_DIR}/simv
	cd ${BACKWARD_GRAD_MERGE_SIM_RUN_DIR} && ${nWave} backward_grad_merge_dump.fsdb




${FORWARD_SIM_RUN_DIR}/verdi : ${FORWARD_SIM_RUN_DIR}/simv
	cd ${FORWARD_SIM_RUN_DIR} && ${Verdi} $(DW_FILES) $(FORWARD_SRC_FILES) $(FORWARD_SIM_FILES);

${BACKWARD_SIM_RUN_DIR}/verdi : ${BACKWARD_SIM_RUN_DIR}/simv
	cd ${BACKWARD_SIM_RUN_DIR} && ${Verdi} $(DW_FILES) $(BACKWARD_SRC_FILES) $(BACKWARD_SIM_FILES);

${BACKWARD_GRAD_MERGE_SIM_RUN_DIR}/verdi : ${BACKWARD_GRAD_MERGE_SIM_RUN_DIR}/simv
	cd ${BACKWARD_GRAD_MERGE_SIM_RUN_DIR} && ${Verdi} $(DW_FILES) $(BACKWARD_GRAD_MERGE_SRC_FILES) $(BACKWARD_GRAD_MERGE_SIM_FILES);



# Target for synthesis
${SYN_RUN_DIR}/syn:
	mkdir -p ${SYN_RUN_DIR}
	cd ${SYN_RUN_DIR} && ${DC} -f $(SYN_FILES) ${DCOPTS} | tee ./dc_shell.log
	echo "Synthesis Completed"



# Clean target to remove simulation files only
# ${SIM_RUN_DIR}/clean:
# 	@rm -rf novas.*
# 	@rm -rf ucli.key
# 	@rm -rf verdiLog
# 	@rm -rf *.log
# 	@rm -rf ${SIM_RUN_DIR}/*
# 	@echo "Simulation Clean Completed"
# 	@rm -rf csrc

${FORWARD_SIM_RUN_DIR}/clean:
	@rm -rf ${FORWARD_SIM_RUN_DIR}/novas.*
	@rm -rf ${FORWARD_SIM_RUN_DIR}/ucli.key
	@rm -rf ${FORWARD_SIM_RUN_DIR}/*.log
	@rm -rf ${FORWARD_SIM_RUN_DIR}/*
	@echo "Simulation Clean Completed"
	@rm -rf ${FORWARD_SIM_RUN_DIR}/csrc

${BACKWARD_SIM_RUN_DIR}/clean:
	@rm -rf ${BACKWARD_SIM_RUN_DIR}/novas.*
	@rm -rf ${BACKWARD_SIM_RUN_DIR}/ucli.key
	@rm -rf ${BACKWARD_SIM_RUN_DIR}/*.log
	@rm -rf ${BACKWARD_SIM_RUN_DIR}/*
	@echo "Simulation Clean Completed"
	@rm -rf ${BACKWARD_SIM_RUN_DIR}/csrc

${BACKWARD_GRAD_MERGE_SIM_RUN_DIR}/clean:
	@rm -rf ${BACKWARD_GRAD_MERGE_SIM_RUN_DIR}/novas.*
	@rm -rf ${BACKWARD_GRAD_MERGE_SIM_RUN_DIR}/ucli.key
	@rm -rf ${BACKWARD_GRAD_MERGE_SIM_RUN_DIR}/*.log
	@rm -rf ${BACKWARD_GRAD_MERGE_SIM_RUN_DIR}/*
	@echo "Simulation Clean Completed"
	@rm -rf ${BACKWARD_GRAD_MERGE_SIM_RUN_DIR}/csrc
