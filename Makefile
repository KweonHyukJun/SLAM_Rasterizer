
FORWARD_SRC_DIR = ../SLAM_Rasterizer/src
FORWARD_SRC_FILES = $(addprefix $(FORWARD_SRC_DIR)/, \
	Forward/pixel_group/Forward_Rasterizer_group_unit.sv \
	Forward/pixel_group/Forward_Rasterizer_unit/Forward_Rasterizer_unit.sv \
	Forward/pixel_group/Forward_Rasterizer_unit/submodule/Forward_skip_unit.sv \
	shared_submodules/fixed_arbiter.sv \
	Forward/pixel_group/Forward_Rasterizer_unit/submodule/splatting_unit.sv \
)

FORWARD_SIM_DIR = ../SLAM_Rasterizer/verif/tb
FORWARD_SIM_FILES = $(addprefix $(FORWARD_SIM_DIR)/, \
	Forward/tb_Forward_Rasterizer_group_unit_to_frame.sv \
)

BACKWARD_SRC_DIR = ../SLAM_Rasterizer/src
BACKWARD_SRC_FILES = $(addprefix $(BACKWARD_SRC_DIR)/, \
Backward/pixel_group/Backward_Pixel_group_controller_before_SRAM.sv \
)

BACKWARD_SIM_DIR = ../SLAM_Rasterizer/verif/tb
BACKWARD_SIM_FILES = $(addprefix $(BACKWARD_SIM_DIR)/, \
	Backward/tb_Backward_Rasterizer_pixel_controller_before_SRAM.sv \
)

BACKWARD_GRAD_MERGE_SRC_DIR = ../SLAM_Rasterizer/src
BACKWARD_GRAD_MERGE_SRC_FILES = $(addprefix $(BACKWARD_GRAD_MERGE_SRC_DIR)/, \
	Backward/pixel_group/Backward_Pixel_group_controller.sv \
)

BACKWARD_GRAD_MERGE_SIM_DIR = ../SLAM_Rasterizer/verif/tb
BACKWARD_GRAD_MERGE_SIM_FILES = $(addprefix $(BACKWARD_GRAD_MERGE_SIM_DIR)/, \
	Backward/tb_Backward_Rasterizer_pixel_controller.sv \
)


# BACKWARD_GRAD_MERGE_SRC_DIR = ../src
# BACKWARD_GRAD_MERGE_SRC_FILES = $(addprefix $(BACKWARD_GRAD_MERGE_SRC_DIR)/, \
# 	Backward/pixel_group/Pixel_group_with_merge_unit_and_cache.sv \
# 	Backward/pixel_group/Gradient_merge_unit/Gradient_merge_unit_by_majority.sv \
# 	Backward/pixel_group/Gradient_merge_unit/submodule/majority_voter.sv \
# 	Backward/pixel_group/Gradient_merge_unit/submodule/majority_adder.sv \
# 	shared_submodules/push_pop_FIFO.sv \
# 	shared_submodules/priority_encoder.sv \
# 	shared_submodules/serializer.sv \
# 	shared_submodules/dp_ram.v \
# )

# BACKWARD_GRAD_MERGE_SIM_DIR = ../verif/tb
# BACKWARD_GRAD_MERGE_SIM_FILES = $(addprefix $(BACKWARD_GRAD_MERGE_SIM_DIR)/, \
# 	Backward/tb_Pixel_group_with_merge_unit_and_cache.sv \
# )

SHARED_SUBMODULES_SRC_DIR = ../SLAM_Rasterizer/src
SHARED_SUBMODULES_SRC_FILES = $(addprefix $(SHARED_SUBMODULES_SRC_DIR)/, \
	shared_submodules/serializer.sv \
)

SHARED_SUBMODULES_SIM_DIR = ../SLAM_Rasterizer/verif/tb
SHARED_SUBMODULES_SIM_FILES = $(addprefix $(SHARED_SUBMODULES_SIM_DIR)/, \
	shared_submodules/tb_serializer.v \
)

COMBINED_BACKWARD_SRC_DIR = ../SLAM_Rasterizer/src
COMBINED_BACKWARD_SRC_FILES = $(addprefix $(COMBINED_BACKWARD_SRC_DIR)/, \
	Backward/pixel_group/Combined_Raster_and_Grad_merge/Combined_Backward.sv \
	Backward/pixel_group/Backward_Rasterizer_group_unit.sv \
	Backward/pixel_group/Backward_Rasterizer_unit/Backward_Rasterizer_unit.sv \
	Backward/pixel_group/Backward_Rasterizer_unit/submodule/Backward_skip_unit.sv \
	shared_submodules/fixed_arbiter.sv \
	Backward/pixel_group/Backward_Rasterizer_unit/submodule/gradient_unit.sv \
	Backward/pixel_group/Pixel_group_with_merge_unit_and_cache.sv \
	Backward/pixel_group/Gradient_merge_unit/Gradient_merge_unit_by_majority.sv \
	Backward/pixel_group/Gradient_merge_unit/submodule/majority_voter.sv \
	Backward/pixel_group/Gradient_merge_unit/submodule/majority_adder.sv \
	shared_submodules/push_pop_FIFO.sv \
	shared_submodules/priority_encoder.sv \
	shared_submodules/serializer.sv \
	shared_submodules/dp_ram.v \
)

COMBINED_BACKWARD_SIM_DIR = ../SLAM_Rasterizer/verif/tb
COMBINED_BACKWARD_SIM_FILES = $(addprefix $(COMBINED_BACKWARD_SIM_DIR)/, \
	Backward/tb_Combined_Backward.sv \
)


SYN_DIR = ../../SLAM_Rasterizer/syn
SYN_FILES = $(addprefix $(SYN_DIR)/, \
	top.syn.tcl \
)

SIM_RUN_DIR = ./output
FORWARD_SIM_RUN_DIR = ./output_forward
BACKWARD_SIM_RUN_DIR = ../output_backward
BACKWARD_GRAD_MERGE_SIM_RUN_DIR = ./output_backward_grad_merge
SHARED_SUBMODULES_SIM_RUN_DIR = ./output_shared_submodules
COMBINED_BACKWARD_SIM_RUN_DIR = ../output_combined_backward
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
	+incdir+$(SRC_DIR) -Mdirectory=$(FORWARD_SIM_RUN_DIR)/csrc \
	+vc+list -CC "-I$(VCS_HOME)/include" \
	+incdir+$(SYNOPSYS)/dw/sim_ver -y $(SYNOPSYS)/dw/sim_ver/*.v \
	-l vcs_compile.log

VVOPTS_BACKWARD =-o simv -notice -line +lint=all,noVCDE,noUI +v2k -timescale=1ns/10ps -quiet \
	+define+DEBUG -debug_access+all -sverilog -kdb \
	+incdir+$(SRC_DIR) -Mdirectory=$(BACKWARD_SIM_RUN_DIR)/csrc \
	+vc+list -CC "-I$(VCS_HOME)/include" \
	+incdir+$(SYNOPSYS)/dw/sim_ver -y $(SYNOPSYS)/dw/sim_ver/*.v \
	-l vcs_compile.log

VVOPTS_BACKWARD_GRAD_MERGE =-o simv -notice -line +lint=all,noVCDE,noUI +v2k -timescale=1ns/10ps -quiet \
	+define+DEBUG -debug_access+all -sverilog -kdb \
	+incdir+$(SRC_DIR) -Mdirectory=$(BACKWARD_GRAD_MERGE_SIM_RUN_DIR)/csrc \
	+vc+list -CC "-I$(VCS_HOME)/include" \
	+incdir+$(SYNOPSYS)/dw/sim_ver -y $(SYNOPSYS)/dw/sim_ver/*.v \
	-l vcs_compile.log


VVOPTS_SHARED_SUBMODULES =-o simv -notice -line +lint=all,noVCDE,noUI +v2k -timescale=1ns/10ps -quiet \
	+define+DEBUG -debug_access+all -sverilog -kdb \
	+incdir+$(SRC_DIR) -Mdirectory=$(SHARED_SUBMODULES_SIM_RUN_DIR)/csrc \
	+vc+list -CC "-I$(VCS_HOME)/include" \
	+incdir+$(SYNOPSYS)/dw/sim_ver -y $(SYNOPSYS)/dw/sim_ver/*.v \
	-l vcs_compile.log

VVOPTS_COMBINED_BACKWARD =-o simv -notice -line +lint=all,noVCDE,noUI +v2k -timescale=1ns/10ps -quiet \
	+define+DEBUG -debug_access+all -sverilog -kdb \
	+incdir+$(SRC_DIR) -Mdirectory=$(COMBINED_BACKWARD_SIM_RUN_DIR)/csrc \
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

${SHARED_SUBMODULES_SIM_RUN_DIR}/simv : ${SHARED_SUBMODULES_SIM_RUN_DIR}/clean
	@mkdir -p ${SHARED_SUBMODULES_SIM_RUN_DIR}
	@cd ${SHARED_SUBMODULES_SIM_RUN_DIR} && $(VV) $(VVOPTS_SHARED_SUBMODULES) $(SHARED_SUBMODULES_SRC_FILES) $(SHARED_SUBMODULES_SIM_FILES);
	@./$@;

${COMBINED_BACKWARD_SIM_RUN_DIR}/simv : ${COMBINED_BACKWARD_SIM_RUN_DIR}/clean
	@mkdir -p ${COMBINED_BACKWARD_SIM_RUN_DIR}
	@cd ${COMBINED_BACKWARD_SIM_RUN_DIR} && $(VV) $(VVOPTS_COMBINED_BACKWARD) $(COMBINED_BACKWARD_SRC_FILES) $(COMBINED_BACKWARD_SIM_FILES);
	@./$@;


${FORWARD_SIM_RUN_DIR}/waveform : ${FORWARD_SIM_RUN_DIR}/simv
	cd ${FORWARD_SIM_RUN_DIR} && ${nWave} forward_dump.fsdb

${BACKWARD_SIM_RUN_DIR}/waveform : ${BACKWARD_SIM_RUN_DIR}/simv
	cd ${BACKWARD_SIM_RUN_DIR} && ${nWave} backward_dump.fsdb

${BACKWARD_GRAD_MERGE_SIM_RUN_DIR}/waveform : ${BACKWARD_GRAD_MERGE_SIM_RUN_DIR}/simv
	cd ${BACKWARD_GRAD_MERGE_SIM_RUN_DIR} && ${nWave} backward_grad_merge_dump.fsdb

${SHARED_SUBMODULES_SIM_RUN_DIR}/waveform : ${SHARED_SUBMODULES_SIM_RUN_DIR}/simv
	cd ${SHARED_SUBMODULES_SIM_RUN_DIR} && ${nWave} shared_submodules_dump.fsdb

${COMBINED_BACKWARD_SIM_RUN_DIR}/waveform : ${COMBINED_BACKWARD_SIM_RUN_DIR}/simv
	cd ${COMBINED_BACKWARD_SIM_RUN_DIR} && ${nWave} combined_backward_dump.fsdb


${FORWARD_SIM_RUN_DIR}/verdi : 
	cd ${FORWARD_SIM_RUN_DIR} && ${Verdi} $(DW_FILES) $(FORWARD_SRC_FILES) $(FORWARD_SIM_FILES);

${BACKWARD_SIM_RUN_DIR}/verdi : 
	cd ${BACKWARD_SIM_RUN_DIR} && ${Verdi} $(DW_FILES) $(BACKWARD_SRC_FILES) $(BACKWARD_SIM_FILES);

${BACKWARD_GRAD_MERGE_SIM_RUN_DIR}/verdi : 
	cd ${BACKWARD_GRAD_MERGE_SIM_RUN_DIR} && ${Verdi} $(DW_FILES) $(BACKWARD_GRAD_MERGE_SRC_FILES) $(BACKWARD_GRAD_MERGE_SIM_FILES);

${SHARED_SUBMODULES_SIM_RUN_DIR}/verdi : 
	cd ${SHARED_SUBMODULES_SIM_RUN_DIR} && ${Verdi} $(DW_FILES) $(SHARED_SUBMODULES_SRC_FILES) $(SHARED_SUBMODULES_SIM_FILES);

${COMBINED_BACKWARD_SIM_RUN_DIR}/verdi : 
	cd ${COMBINED_BACKWARD_SIM_RUN_DIR} && ${Verdi} $(DW_FILES) $(COMBINED_BACKWARD_SRC_FILES) $(COMBINED_BACKWARD_SIM_FILES);


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

${SHARED_SUBMODULES_SIM_RUN_DIR}/clean:
	@rm -rf ${SHARED_SUBMODULES_SIM_RUN_DIR}/novas.*
	@rm -rf ${SHARED_SUBMODULES_SIM_RUN_DIR}/ucli.key
	@rm -rf ${SHARED_SUBMODULES_SIM_RUN_DIR}/*.log
	@rm -rf ${SHARED_SUBMODULES_SIM_RUN_DIR}/*
	@echo "Simulation Clean Completed"
	@rm -rf ${SHARED_SUBMODULES_SIM_RUN_DIR}/csrc

${COMBINED_BACKWARD_SIM_RUN_DIR}/clean:
	@rm -rf ${COMBINED_BACKWARD_SIM_RUN_DIR}/novas.*
	@rm -rf ${COMBINED_BACKWARD_SIM_RUN_DIR}/ucli.key
	@rm -rf ${COMBINED_BACKWARD_SIM_RUN_DIR}/*.log
	@rm -rf ${COMBINED_BACKWARD_SIM_RUN_DIR}/*
	@echo "Simulation Clean Completed"
	@rm -rf ${COMBINED_BACKWARD_SIM_RUN_DIR}/csrc
