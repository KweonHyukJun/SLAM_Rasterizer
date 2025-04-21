
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



FORWARD_CONTROL_SRC_DIR = ../SLAM_Rasterizer/src
FORWARD_CONTROL_SRC_FILES = $(addprefix $(FORWARD_CONTROL_SRC_DIR)/, \
	Forward/Block/Forward_Block_controller_with_SRAM.sv \
	Forward/Block/Forward_Block_controller.sv \
	Forward/pixel_group/Forward_Rasterizer_group_unit.sv \
	Forward/pixel_group/Forward_Rasterizer_unit/Forward_Rasterizer_unit.sv \
	shared_submodules/fixed_arbiter.sv \
	Forward/pixel_group/Forward_Rasterizer_unit/submodule/Forward_skip_unit.sv \
	Forward/pixel_group/Forward_Rasterizer_unit/submodule/splatting_unit.sv \
	shared_submodules/dp_ram.v \
)

FORWARD_CONTROL_SIM_DIR = ../SLAM_Rasterizer/verif/tb
FORWARD_CONTROL_SIM_FILES = $(addprefix $(FORWARD_CONTROL_SIM_DIR)/, \
	Forward/tb_Forward_Block_controller_with_SRAM.sv \
)


BACKWARD_SRC_DIR = ../SLAM_Rasterizer/src
BACKWARD_SRC_FILES = $(addprefix $(BACKWARD_SRC_DIR)/, \
	Backward/Block/Backward_Block_controller_with_SRAM.sv \
	Backward/Block/Backward_Block_controller.sv \
	Backward/pixel_group/Combined_Raster_and_Grad_merge/Combined_Backward_Rasterizer_and_merge.sv \
	Backward/pixel_group/Backward_Rasterizer_group_unit.sv \
	Backward/pixel_group/Backward_Rasterizer_unit/Backward_Rasterizer_unit.sv \
	Backward/pixel_group/Backward_Rasterizer_unit/submodule/Backward_skip_unit.sv \
	shared_submodules/fixed_arbiter.sv \
	Backward/pixel_group/Backward_Rasterizer_unit/submodule/gradient_unit.sv \
	Backward/pixel_group/Gradient_merge_unit/Gradient_merge_unit_by_majority_with_add.sv \
	Backward/pixel_group/Gradient_merge_unit/submodule/majority_voter.sv \
	Backward/pixel_group/Gradient_merge_unit/submodule/majority_adder.sv \
	shared_submodules/push_pop_FIFO.sv \
	shared_submodules/priority_encoder.sv \
	shared_submodules/serializer.sv \
	shared_submodules/dp_ram.v \
)
BACKWARD_SIM_DIR = ../SLAM_Rasterizer/verif/tb
BACKWARD_SIM_FILES = $(addprefix $(BACKWARD_SIM_DIR)/, \
	Backward/tb_Backward_Block_controller_with_SRAM.sv \
)

# Best condition
BACKWARD_SYSTEM_SRC_DIR = ../SLAM_Rasterizer/src
BACKWARD_SYSTEM_SRC_FILES = $(addprefix $(BACKWARD_SYSTEM_SRC_DIR)/, \
	Backward/Top/Backward_system_AXI4_fetching.sv \
	Backward/Top/Backward_top_controller_AXI4_fetching.sv \
	shared_submodules/Gaussian_Range_Block_RAM.v \
	shared_submodules/Point_list_Block_RAM.v \
	shared_submodules/Gaussian_Block_RAM.v \
	shared_submodules/Pixel_Block_RAM.v \
	shared_submodules/Gradient_Block_RAM.v \
	shared_submodules/blk_mem_gen_v8_4_8_Gaussian.v \
	shared_submodules/blk_mem_gen_v8_4_8_Range.v \
	shared_submodules/blk_mem_gen_v8_4_8_Pixel.v \
	shared_submodules/blk_mem_gen_v8_4_8_Point_list.v \
	shared_submodules/blk_mem_gen_v8_4_8_Gradient.v \
	Backward/Block/Backward_Block_controller_pipelining_controller.sv \
	Backward/pixel_group/Combined_Raster_and_Grad_merge/Combined_Backward_Rasterizer_and_merge_pipelining_controller.sv \
	Backward/pixel_group/Backward_Rasterizer_group_unit.sv \
	Backward/pixel_group/Backward_Rasterizer_unit/Backward_Rasterizer_unit.sv \
	Backward/pixel_group/Backward_Rasterizer_unit/submodule/Backward_skip_unit.sv \
	shared_submodules/fixed_arbiter.sv \
	Backward/pixel_group/Backward_Rasterizer_unit/submodule/gradient_unit.sv \
	Backward/pixel_group/Gradient_merge_unit/Gradient_merge_unit_by_majority_with_add.sv \
	Backward/pixel_group/Gradient_merge_unit/submodule/majority_voter.sv \
	Backward/pixel_group/Gradient_merge_unit/submodule/majority_adder.sv \
	shared_submodules/push_pop_FIFO.sv \
	shared_submodules/priority_encoder.sv \
	shared_submodules/serializer.sv \
	shared_submodules/dp_ram.v \
)
BACKWARD_SYSTEM_SIM_DIR = ../SLAM_Rasterizer/verif/tb
BACKWARD_SYSTEM_SIM_FILES = $(addprefix $(BACKWARD_SYSTEM_SIM_DIR)/, \
	Backward/tb_Backward_system_AXI4_fetching.sv \
)

# Near pixel만 없는 다음 best
BACKWARD_SYSTEM_WO_NEAR_PIXEL_SRC_DIR = ../SLAM_Rasterizer/src
BACKWARD_SYSTEM_WO_NEAR_PIXEL_SRC_FILES = $(addprefix $(BACKWARD_SYSTEM_WO_NEAR_PIXEL_SRC_DIR)/, \
	Backward/Top/Backward_system_AXI4_fetching_wo_near_pixel.sv \
	Backward/Top/Backward_top_controller_AXI4_fetching_row_fetching.sv \
	shared_submodules/Gaussian_Range_Block_RAM.v \
	shared_submodules/Point_list_Block_RAM.v \
	shared_submodules/Gaussian_Block_RAM.v \
	shared_submodules/Pixel_Block_RAM.v \
	shared_submodules/Gradient_Block_RAM.v \
	shared_submodules/blk_mem_gen_v8_4_8_Gaussian.v \
	shared_submodules/blk_mem_gen_v8_4_8_Range.v \
	shared_submodules/blk_mem_gen_v8_4_8_Pixel.v \
	shared_submodules/blk_mem_gen_v8_4_8_Point_list.v \
	shared_submodules/blk_mem_gen_v8_4_8_Gradient.v \
	Backward/Block/Backward_Block_controller_pipelining_controller_wo_near_pixel.sv \
	Backward/pixel_group/Combined_Raster_and_Grad_merge/Combined_Backward_Rasterizer_and_merge_pipelining_controller.sv \
	Backward/pixel_group/Backward_Rasterizer_group_unit.sv \
	Backward/pixel_group/Backward_Rasterizer_unit/Backward_Rasterizer_unit.sv \
	Backward/pixel_group/Backward_Rasterizer_unit/submodule/Backward_skip_unit.sv \
	shared_submodules/fixed_arbiter.sv \
	Backward/pixel_group/Backward_Rasterizer_unit/submodule/gradient_unit.sv \
	Backward/pixel_group/Gradient_merge_unit/Gradient_merge_unit_by_majority_with_add.sv \
	Backward/pixel_group/Gradient_merge_unit/submodule/majority_voter.sv \
	Backward/pixel_group/Gradient_merge_unit/submodule/majority_adder.sv \
	shared_submodules/push_pop_FIFO.sv \
	shared_submodules/priority_encoder.sv \
	shared_submodules/serializer.sv \
	shared_submodules/dp_ram.v \
)
BACKWARD_SYSTEM_WO_NEAR_PIXEL_SIM_DIR = ../SLAM_Rasterizer/verif/tb
BACKWARD_SYSTEM_WO_NEAR_PIXEL_SIM_FILES = $(addprefix $(BACKWARD_SYSTEM_WO_NEAR_PIXEL_SIM_DIR)/, \
	Backward/tb_Backward_system_AXI4_fetching_wo_near_pixel.sv \
)


# Majority buffer + Near pixel 없는 경우
BACKWARD_SYSTEM_WO_NEAR_PIXEL_WO_MAJORITY_SRC_DIR = ../SLAM_Rasterizer/src
BACKWARD_SYSTEM_WO_NEAR_PIXEL_WO_MAJORITY_SRC_FILES = $(addprefix $(BACKWARD_SYSTEM_WO_NEAR_PIXEL_WO_MAJORITY_SRC_DIR)/, \
	Backward/Top/Backward_system_AXI4_fetching_wo_majority_wo_near_pixel.sv \
	Backward/Top/Backward_top_controller_AXI4_fetching_row_fetching.sv \
	shared_submodules/Gaussian_Range_Block_RAM.v \
	shared_submodules/Point_list_Block_RAM.v \
	shared_submodules/Gaussian_Block_RAM.v \
	shared_submodules/Pixel_Block_RAM.v \
	shared_submodules/Gradient_Block_RAM.v \
	shared_submodules/blk_mem_gen_v8_4_8_Gaussian.v \
	shared_submodules/blk_mem_gen_v8_4_8_Range.v \
	shared_submodules/blk_mem_gen_v8_4_8_Pixel.v \
	shared_submodules/blk_mem_gen_v8_4_8_Point_list.v \
	shared_submodules/blk_mem_gen_v8_4_8_Gradient.v \
	Backward/Block/Backward_Block_controller_pipelining_controller_wo_near_pixel.sv \
	Backward/pixel_group/Combined_Raster_and_Grad_merge/Combined_Backward_Rasterizer_and_merge_pipelining_controller_wo_majority_and_buffer.sv \
	Backward/pixel_group/Backward_Rasterizer_group_unit.sv \
	Backward/pixel_group/Backward_Rasterizer_unit/Backward_Rasterizer_unit.sv \
	Backward/pixel_group/Backward_Rasterizer_unit/submodule/Backward_skip_unit.sv \
	shared_submodules/fixed_arbiter.sv \
	Backward/pixel_group/Backward_Rasterizer_unit/submodule/gradient_unit.sv \
	Backward/pixel_group/Gradient_merge_unit/Gradient_merge_unit_by_majority_with_add_baseline.sv \
	Backward/pixel_group/Gradient_merge_unit/submodule/majority_voter.sv \
	Backward/pixel_group/Gradient_merge_unit/submodule/majority_adder.sv \
	shared_submodules/push_pop_FIFO.sv \
	shared_submodules/priority_encoder_single_out.sv \
	shared_submodules/dp_ram.v \
)
BACKWARD_SYSTEM_WO_NEAR_PIXEL_WO_MAJORITY_SIM_DIR = ../SLAM_Rasterizer/verif/tb
BACKWARD_SYSTEM_WO_NEAR_PIXEL_WO_MAJORITY_SIM_FILES = $(addprefix $(BACKWARD_SYSTEM_WO_NEAR_PIXEL_WO_MAJORITY_SIM_DIR)/, \
	Backward/tb_Backward_system_AXI4_fetching_wo_majority_wo_near_pixel.sv \
)


# 1 input + majority + near pixel
BACKWARD_SYSTEM_SINGLE_INPUT_SRC_DIR = ../SLAM_Rasterizer/src
BACKWARD_SYSTEM_SINGLE_INPUT_SRC_FILES = $(addprefix $(BACKWARD_SYSTEM_SINGLE_INPUT_SRC_DIR)/, \
	Backward/Top/Backward_system_AXI4_fetching_single_input.sv \
	Backward/Top/Backward_top_controller_AXI4_fetching_single_input.sv \
	shared_submodules/Gaussian_Range_Block_RAM.v \
	shared_submodules/Point_list_Block_RAM.v \
	shared_submodules/Gaussian_Block_RAM.v \
	shared_submodules/Pixel_Block_RAM.v \
	shared_submodules/Gradient_Block_RAM.v \
	shared_submodules/blk_mem_gen_v8_4_8_Gaussian.v \
	shared_submodules/blk_mem_gen_v8_4_8_Range.v \
	shared_submodules/blk_mem_gen_v8_4_8_Pixel.v \
	shared_submodules/blk_mem_gen_v8_4_8_Point_list.v \
	shared_submodules/blk_mem_gen_v8_4_8_Gradient.v \
	Backward/Block/Backward_Block_controller_pipelining_controller_single_input.sv \
	Backward/pixel_group/Combined_Raster_and_Grad_merge/Combined_Backward_Rasterizer_and_merge_pipelining_controller_single_input.sv \
	Backward/pixel_group/Backward_Rasterizer_group_unit_single_input.sv \
	Backward/pixel_group/Backward_Rasterizer_unit/Backward_Rasterizer_unit_single_input.sv \
	Backward/pixel_group/Backward_Rasterizer_unit/single_input_submodule/Backward_skip_unit_single_input.sv \
	Backward/pixel_group/Backward_Rasterizer_unit/submodule/gradient_unit.sv \
	Backward/pixel_group/Gradient_merge_unit/Gradient_merge_unit_by_majority_with_add.sv \
	Backward/pixel_group/Gradient_merge_unit/submodule/majority_voter.sv \
	Backward/pixel_group/Gradient_merge_unit/submodule/majority_adder.sv \
	shared_submodules/push_pop_FIFO.sv \
	shared_submodules/priority_encoder.sv \
	shared_submodules/serializer.sv \
	shared_submodules/dp_ram.v \
)
BACKWARD_SYSTEM_SINGLE_INPUT_SIM_DIR = ../SLAM_Rasterizer/verif/tb
BACKWARD_SYSTEM_SINGLE_INPUT_SIM_FILES = $(addprefix $(BACKWARD_SYSTEM_SINGLE_INPUT_SIM_DIR)/, \
	Backward/tb_Backward_system_AXI4_fetching_single_input.sv \
)

# 1 input + no majority + no near pixel
BACKWARD_SYSTEM_SINGLE_INPUT_WO_MAJORITY_AND_NEAR_PIXEL_SRC_DIR = ../SLAM_Rasterizer/src
BACKWARD_SYSTEM_SINGLE_INPUT_WO_MAJORITY_AND_NEAR_PIXEL_SRC_FILES = $(addprefix $(BACKWARD_SYSTEM_SINGLE_INPUT_WO_MAJORITY_AND_NEAR_PIXEL_SRC_DIR)/, \
	Backward/Top/Backward_system_AXI4_fetching_wo_majority_wo_near_pixel_single_input.sv \
	Backward/Top/Backward_top_controller_AXI4_fetching_single_input_row_fetching.sv \
	shared_submodules/Gaussian_Range_Block_RAM.v \
	shared_submodules/Point_list_Block_RAM.v \
	shared_submodules/Gaussian_Block_RAM.v \
	shared_submodules/Pixel_Block_RAM.v \
	shared_submodules/Gradient_Block_RAM.v \
	shared_submodules/blk_mem_gen_v8_4_8_Gaussian.v \
	shared_submodules/blk_mem_gen_v8_4_8_Range.v \
	shared_submodules/blk_mem_gen_v8_4_8_Pixel.v \
	shared_submodules/blk_mem_gen_v8_4_8_Point_list.v \
	shared_submodules/blk_mem_gen_v8_4_8_Gradient.v \
	Backward/Block/Backward_Block_controller_pipelining_controller_wo_near_pixel_single_input.sv \
	Backward/pixel_group/Combined_Raster_and_Grad_merge/Combined_Backward_Rasterizer_and_merge_pipelining_controller_wo_majority_and_buffer_single_input.sv \
	Backward/pixel_group/Backward_Rasterizer_group_unit_single_input.sv \
	Backward/pixel_group/Backward_Rasterizer_unit/Backward_Rasterizer_unit_single_input.sv \
	Backward/pixel_group/Backward_Rasterizer_unit/single_input_submodule/Backward_skip_unit_single_input.sv \
	Backward/pixel_group/Backward_Rasterizer_unit/submodule/gradient_unit.sv \
	Backward/pixel_group/Gradient_merge_unit/Gradient_merge_unit_by_majority_with_add_baseline.sv \
	Backward/pixel_group/Gradient_merge_unit/submodule/majority_voter.sv \
	Backward/pixel_group/Gradient_merge_unit/submodule/majority_adder.sv \
	shared_submodules/push_pop_FIFO.sv \
	shared_submodules/priority_encoder_single_out.sv \
	shared_submodules/serializer.sv \
	shared_submodules/dp_ram.v \
)
BACKWARD_SYSTEM_SINGLE_INPUT_WO_MAJORITY_AND_NEAR_PIXEL_SIM_DIR = ../SLAM_Rasterizer/verif/tb
BACKWARD_SYSTEM_SINGLE_INPUT_WO_MAJORITY_AND_NEAR_PIXEL_SIM_FILES = $(addprefix $(BACKWARD_SYSTEM_SINGLE_INPUT_WO_MAJORITY_AND_NEAR_PIXEL_SIM_DIR)/, \
	Backward/tb_Backward_system_AXI4_fetching_wo_majority_wo_near_pixel_single_input.sv \
)






BACKWARD_UNIT_SRC_DIR = ../SLAM_Rasterizer/src
BACKWARD_UNIT_SRC_FILES = $(addprefix $(BACKWARD_UNIT_SRC_DIR)/, \
	Backward/pixel_group/Backward_Rasterizer_group_unit.sv \
	Backward/pixel_group/Backward_Rasterizer_unit/Backward_Rasterizer_unit.sv \
	Backward/pixel_group/Backward_Rasterizer_unit/submodule/Backward_skip_unit.sv \
	shared_submodules/fixed_arbiter.sv \
	Backward/pixel_group/Backward_Rasterizer_unit/submodule/gradient_unit.sv \
)
BACKWARD_UNIT_SIM_DIR = ../SLAM_Rasterizer/verif/tb
BACKWARD_UNIT_SIM_FILES = $(addprefix $(BACKWARD_UNIT_SIM_DIR)/, \
	Backward/tb_Backward_Rasterizer_group_unit_to_frame_for_test.sv \
)



BACKWARD_NEW_CONTROL_SRC_DIR = ../SLAM_Rasterizer/src
BACKWARD_NEW_CONTROL_SRC_FILES = $(addprefix $(BACKWARD_NEW_CONTROL_SRC_DIR)/, \
	Backward/Block/Backward_Block_controller_with_SRAM_pipelining_controller.sv \
	Backward/Block/Backward_Block_controller_pipelining_controller.sv \
	Backward/pixel_group/Combined_Raster_and_Grad_merge/Combined_Backward_Rasterizer_and_merge_pipelining_controller.sv \
	Backward/pixel_group/Backward_Rasterizer_group_unit.sv \
	Backward/pixel_group/Backward_Rasterizer_unit/Backward_Rasterizer_unit.sv \
	Backward/pixel_group/Backward_Rasterizer_unit/submodule/Backward_skip_unit.sv \
	shared_submodules/fixed_arbiter.sv \
	Backward/pixel_group/Backward_Rasterizer_unit/submodule/gradient_unit.sv \
	Backward/pixel_group/Gradient_merge_unit/Gradient_merge_unit_by_majority_with_add.sv \
	Backward/pixel_group/Gradient_merge_unit/submodule/majority_voter.sv \
	Backward/pixel_group/Gradient_merge_unit/submodule/majority_adder.sv \
	shared_submodules/push_pop_FIFO.sv \
	shared_submodules/priority_encoder.sv \
	shared_submodules/serializer.sv \
	shared_submodules/dp_ram.v \
)
BACKWARD_NEW_CONTROL_SIM_DIR = ../SLAM_Rasterizer/verif/tb
BACKWARD_NEW_CONTROL_SIM_FILES = $(addprefix $(BACKWARD_NEW_CONTROL_SIM_DIR)/, \
	Backward/tb_Backward_Block_controller_with_SRAM_pipelining_controller.sv \
)

BACKWARD_NEW_CONTROL_SINGLE_INPUT_SRC_DIR = ../SLAM_Rasterizer/src
BACKWARD_NEW_CONTROL_SINGLE_INPUT_SRC_FILES = $(addprefix $(BACKWARD_NEW_CONTROL_SINGLE_INPUT_SRC_DIR)/, \
	Backward/Block/Backward_Block_controller_with_SRAM_pipelining_controller_single_input.sv \
	Backward/Block/Backward_Block_controller_pipelining_controller_single_input.sv \
	Backward/pixel_group/Combined_Raster_and_Grad_merge/Combined_Backward_Rasterizer_and_merge_pipelining_controller_single_input.sv \
	Backward/pixel_group/Backward_Rasterizer_group_unit_single_input.sv \
	Backward/pixel_group/Backward_Rasterizer_unit/Backward_Rasterizer_unit_single_input.sv \
	Backward/pixel_group/Backward_Rasterizer_unit/single_input_submodule/Backward_skip_unit_single_input.sv \
	Backward/pixel_group/Backward_Rasterizer_unit/submodule/gradient_unit.sv \
	Backward/pixel_group/Gradient_merge_unit/Gradient_merge_unit_by_majority_with_add.sv \
	Backward/pixel_group/Gradient_merge_unit/submodule/majority_voter.sv \
	Backward/pixel_group/Gradient_merge_unit/submodule/majority_adder.sv \
	shared_submodules/push_pop_FIFO.sv \
	shared_submodules/priority_encoder.sv \
	shared_submodules/serializer.sv \
	shared_submodules/dp_ram.v \
)
BACKWARD_NEW_CONTROL_SINGLE_INPUT_SIM_DIR = ../SLAM_Rasterizer/verif/tb
BACKWARD_NEW_CONTROL_SINGLE_INPUT_SIM_FILES = $(addprefix $(BACKWARD_NEW_CONTROL_SINGLE_INPUT_SIM_DIR)/, \
	Backward/tb_Backward_Block_controller_with_SRAM_pipelining_controller_single_input.sv \
)

AXI4_TEST_SRC_DIR = ../SLAM_Rasterizer/src
AXI4_TEST_SRC_FILES = $(addprefix $(AXI4_TEST_SRC_DIR)/, \
	Block_RAM_Test/Block_RAM_AXI4_test.sv \
	shared_submodules/Gradient_Block_RAM.v \
	shared_submodules/blk_mem_gen_v8_4_8_Gradient.v \
)

AXI4_TEST_SIM_DIR = ../SLAM_Rasterizer/verif/tb
AXI4_TEST_SIM_FILES = $(addprefix $(AXI4_TEST_SIM_DIR)/, \
	Backward/tb_Block_RAM_AXI4_test.sv \
)

BACKWARD_SYSTEM_ORIGINAL_SRC_DIR = ../SLAM_Rasterizer/src
BACKWARD_SYSTEM_ORIGINAL_SRC_FILES = $(addprefix $(BACKWARD_SYSTEM_ORIGINAL_SRC_DIR)/, \
	Backward/Top/Backward_system_AXI4_fetching_original_single_input.sv \
	Backward/Top/Backward_top_controller_AXI4_fetching_single_input.sv \
	shared_submodules/Gaussian_Range_Block_RAM.v \
	shared_submodules/Point_list_Block_RAM.v \
	shared_submodules/Gaussian_Block_RAM.v \
	shared_submodules/Pixel_Block_RAM.v \
	shared_submodules/Gradient_Block_RAM.v \
	shared_submodules/blk_mem_gen_v8_4_8_Gaussian.v \
	shared_submodules/blk_mem_gen_v8_4_8_Range.v \
	shared_submodules/blk_mem_gen_v8_4_8_Pixel.v \
	shared_submodules/blk_mem_gen_v8_4_8_Point_list.v \
	shared_submodules/blk_mem_gen_v8_4_8_Gradient.v \
	Backward/Block/Backward_Block_controller_pipelining_controller_original_single_input.sv \
	Backward/pixel_group/Combined_Raster_and_Grad_merge/Combined_Backward_Rasterizer_and_merge_pipelining_controller_single_input.sv \
	Backward/pixel_group/Backward_Rasterizer_group_unit_single_input.sv \
	Backward/pixel_group/Backward_Rasterizer_unit/Backward_Rasterizer_unit_single_input.sv \
	Backward/pixel_group/Backward_Rasterizer_unit/single_input_submodule/Backward_skip_unit_single_input.sv \
	Backward/pixel_group/Backward_Rasterizer_unit/submodule/gradient_unit.sv \
	Backward/pixel_group/Gradient_merge_unit/Gradient_merge_unit_by_majority_with_add.sv \
	Backward/pixel_group/Gradient_merge_unit/submodule/majority_voter.sv \
	Backward/pixel_group/Gradient_merge_unit/submodule/majority_adder.sv \
	shared_submodules/push_pop_FIFO.sv \
	shared_submodules/priority_encoder.sv \
	shared_submodules/serializer.sv \
	shared_submodules/dp_ram.v \
)
BACKWARD_SYSTEM_ORIGINAL_SIM_DIR = ../SLAM_Rasterizer/verif/tb
BACKWARD_SYSTEM_ORIGINAL_SIM_FILES = $(addprefix $(BACKWARD_SYSTEM_ORIGINAL_SIM_DIR)/, \
	Backward/tb_Backward_system_AXI4_fetching_original_single_input.sv \
)

SHARED_SUBMODULES_SRC_DIR = ../SLAM_Rasterizer/src/
SHARED_SUBMODULES_SRC_FILES = $(addprefix $(SHARED_SUBMODULES_SRC_DIR)/, \
	Test/tree_logic_wire.sv \
)

SHARED_SUBMODULES_SIM_DIR = ../SLAM_Rasterizer/verif/tb
SHARED_SUBMODULES_SIM_FILES = $(addprefix $(SHARED_SUBMODULES_SIM_DIR)/, \
	Test/tb_tree_logic_wire.sv \
)


BACKWARD_MODULE_FUNCTIONALITY_TEST_SRC_DIR = ../SLAM_Rasterizer/src
BACKWARD_MODULE_FUNCTIONALITY_TEST_SRC_FILES = $(addprefix $(BACKWARD_MODULE_FUNCTIONALITY_TEST_SRC_DIR)/, \
	Backward/pixel_group/Backward_Rasterizer_unit/Backward_Rasterizer_unit.sv \
	Backward/pixel_group/Backward_Rasterizer_unit/submodule/Backward_skip_unit.sv \
	shared_submodules/fixed_arbiter.sv \
	Backward/pixel_group/Backward_Rasterizer_unit/submodule/gradient_unit.sv \
)


BACKWARD_MODULE_FUNCTIONALITY_TEST_SIM_DIR = ../SLAM_Rasterizer/verif/tb
BACKWARD_MODULE_FUNCTIONALITY_TEST_SIM_FILES = $(addprefix $(BACKWARD_MODULE_FUNCTIONALITY_TEST_SIM_DIR)/, \
	Backward/tb_Backward_Rasterizer_unit.sv \
)






SYN_DIR = ../../SLAM_Rasterizer/syn
SYN_FILES = $(addprefix $(SYN_DIR)/, \
	top.syn.tcl \
)

SIM_RUN_DIR = ./output
FORWARD_SIM_RUN_DIR = ../output_forward_frame
FORWARD_CONTROL_SIM_RUN_DIR = ../output_forward_control


BACKWARD_SIM_RUN_DIR = ../output_backward
BACKWARD_SYSTEM_SIM_RUN_DIR = ../output_backward_system
BACKWARD_SYSTEM_WO_NEAR_PIXEL_SIM_RUN_DIR = ../output_backward_system_wo_near_pixel
BACKWARD_SYSTEM_WO_NEAR_PIXEL_WO_MAJORITY_SIM_RUN_DIR = ../output_backward_system_wo_near_pixel_wo_majority
BACKWARD_SYSTEM_SINGLE_INPUT_WO_MAJORITY_AND_NEAR_PIXEL_SIM_RUN_DIR = ../output_backward_system_single_input_wo_majority_wo_near_pixel
BACKWARD_SYSTEM_SINGLE_INPUT_SIM_RUN_DIR = ../output_backward_system_single_input
BACKWARD_SYSTEM_SINGLE_INPUT_WO_MAJORITY_AND_NEAR_PIXEL_SIM_RUN_DIR = ../output_backward_system_single_input_wo_majority_wo_near_pixel
BACKWARD_SYSTEM_ORIGINAL_SIM_RUN_DIR = ../output_backward_system_original
BACKWARD_MODULE_FUNCTIONALITY_TEST_SIM_RUN_DIR = ../output_backward_module_functionality_test

BACKWARD_UNIT_SIM_RUN_DIR = ../output_backward_unit

BACKWARD_NEW_CONTROL_SIM_RUN_DIR = ../output_backward_new_control
BACKWARD_NEW_CONTROL_SINGLE_INPUT_SIM_RUN_DIR = ../output_backward_new_control_single_input
SHARED_SUBMODULES_SIM_RUN_DIR = ../output_shared_submodules

AXI4_TEST_SIM_RUN_DIR = ../output_axi4_test

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
	+incdir+$(FORWARD_SRC_DIR) -Mdirectory=$(FORWARD_SIM_RUN_DIR)/csrc \
	+vc+list -CC "-I$(VCS_HOME)/include" \
	+incdir+$(SYNOPSYS)/dw/sim_ver -y $(SYNOPSYS)/dw/sim_ver/*.v \
	-l vcs_compile.log

VVOPTS_FORWARD_CONTROL =-o simv -notice -line +lint=all,noVCDE,noUI +v2k -timescale=1ns/10ps -quiet \
	+define+DEBUG -debug_access+all -sverilog -kdb \
	+incdir+$(FORWARD_CONTROL_SRC_DIR) -Mdirectory=$(FORWARD_CONTROL_SIM_RUN_DIR)/csrc \
	+vc+list -CC "-I$(VCS_HOME)/include" \
	+incdir+$(SYNOPSYS)/dw/sim_ver -y $(SYNOPSYS)/dw/sim_ver/*.v \
	-l vcs_compile.log


VVOPTS_BACKWARD =-o simv -notice -line +lint=all,noVCDE,noUI +v2k -timescale=1ns/10ps -quiet \
	+define+DEBUG -debug_access+all -sverilog -kdb \
	+incdir+$(BACKWARD_SRC_DIR) -Mdirectory=$(BACKWARD_SIM_RUN_DIR)/csrc \
	+vc+list -CC "-I$(VCS_HOME)/include" \
	+incdir+$(SYNOPSYS)/dw/sim_ver -y $(SYNOPSYS)/dw/sim_ver/*.v \
	-l vcs_compile.log

VVOPTS_BACKWARD_SYSTEM =-o simv -notice -line +lint=all,noVCDE,noUI +v2k -timescale=1ns/10ps -quiet \
	+define+DEBUG -debug_access+all -sverilog -kdb \
	+incdir+$(BACKWARD_SYSTEM_SRC_DIR) -Mdirectory=$(BACKWARD_SYSTEM_SIM_RUN_DIR)/csrc \
	+vc+list -CC "-I$(VCS_HOME)/include" \
	+incdir+$(SYNOPSYS)/dw/sim_ver -y $(SYNOPSYS)/dw/sim_ver/*.v \
	-l vcs_compile.log

VVOPTS_BACKWARD_SYSTEM_WO_NEAR_PIXEL =-o simv -notice -line +lint=all,noVCDE,noUI +v2k -timescale=1ns/10ps -quiet \
	+define+DEBUG -debug_access+all -sverilog -kdb \
	+incdir+$(BACKWARD_SYSTEM_WO_NEAR_PIXEL_SRC_DIR) -Mdirectory=$(BACKWARD_SYSTEM_WO_NEAR_PIXEL_SIM_RUN_DIR)/csrc \
	+vc+list -CC "-I$(VCS_HOME)/include" \
	+incdir+$(SYNOPSYS)/dw/sim_ver -y $(SYNOPSYS)/dw/sim_ver/*.v \
	-l vcs_compile.log


VVOPTS_BACKWARD_SYSTEM_WO_NEAR_PIXEL_WO_MAJORITY =-o simv -notice -line +lint=all,noVCDE,noUI +v2k -timescale=1ns/10ps -quiet \
	+define+DEBUG -debug_access+all -sverilog -kdb \
	+incdir+$(BACKWARD_SYSTEM_WO_NEAR_PIXEL_WO_MAJORITY_SRC_DIR) -Mdirectory=$(BACKWARD_SYSTEM_WO_NEAR_PIXEL_WO_MAJORITY_SIM_RUN_DIR)/csrc \
	+vc+list -CC "-I$(VCS_HOME)/include" \
	+incdir+$(SYNOPSYS)/dw/sim_ver -y $(SYNOPSYS)/dw/sim_ver/*.v \
	-l vcs_compile.log


VVOPTS_BACKWARD_SYSTEM_ORIGINAL =-o simv -notice -line +lint=all,noVCDE,noUI +v2k -timescale=1ns/10ps -quiet \
	+define+DEBUG -debug_access+all -sverilog -kdb \
	+incdir+$(BACKWARD_SYSTEM_ORIGINAL_SRC_DIR) -Mdirectory=$(BACKWARD_SYSTEM_ORIGINAL_SIM_RUN_DIR)/csrc \
	+vc+list -CC "-I$(VCS_HOME)/include" \
	+incdir+$(SYNOPSYS)/dw/sim_ver -y $(SYNOPSYS)/dw/sim_ver/*.v \
	-l vcs_compile.log


VVOPTS_BACKWARD_SYSTEM_SINGLE_INPUT =-o simv -notice -line +lint=all,noVCDE,noUI +v2k -timescale=1ns/10ps -quiet \
	+define+DEBUG -debug_access+all -sverilog -kdb \
	+incdir+$(BACKWARD_SYSTEM_SINGLE_INPUT_SRC_DIR) -Mdirectory=$(BACKWARD_SYSTEM_SINGLE_INPUT_SIM_RUN_DIR)/csrc \
	+vc+list -CC "-I$(VCS_HOME)/include" \
	+incdir+$(SYNOPSYS)/dw/sim_ver -y $(SYNOPSYS)/dw/sim_ver/*.v \
	-l vcs_compile.log

VVOPTS_BACKWARD_SYSTEM_SINGLE_INPUT_WO_MAJORITY_AND_NEAR_PIXEL =-o simv -notice -line +lint=all,noVCDE,noUI +v2k -timescale=1ns/10ps -quiet \
	+define+DEBUG -debug_access+all -sverilog -kdb \
	+incdir+$(BACKWARD_SYSTEM_SINGLE_INPUT_WO_MAJORITY_AND_NEAR_PIXEL_SRC_DIR) -Mdirectory=$(BACKWARD_SYSTEM_SINGLE_INPUT_WO_MAJORITY_AND_NEAR_PIXEL_SIM_RUN_DIR)/csrc \
	+vc+list -CC "-I$(VCS_HOME)/include" \
	+incdir+$(SYNOPSYS)/dw/sim_ver -y $(SYNOPSYS)/dw/sim_ver/*.v \
	-l vcs_compile.log

VVOPTS_BACKWARD_UNIT =-o simv -notice -line +lint=all,noVCDE,noUI +v2k -timescale=1ns/10ps -quiet \
	+define+DEBUG -debug_access+all -sverilog -kdb \
	+incdir+$(BACKWARD_UNIT_SRC_DIR) -Mdirectory=$(BACKWARD_UNIT_SIM_RUN_DIR)/csrc \
	+vc+list -CC "-I$(VCS_HOME)/include" \
	+incdir+$(SYNOPSYS)/dw/sim_ver -y $(SYNOPSYS)/dw/sim_ver/*.v \
	-l vcs_compile.log

VVOPTS_BACKWARD_NEW_CONTROL =-o simv -notice -line +lint=all,noVCDE,noUI +v2k -timescale=1ns/10ps -quiet \
	+define+DEBUG -debug_access+all -sverilog -kdb \
	+incdir+$(BACKWARD_NEW_CONTROL_SRC_DIR) -Mdirectory=$(BACKWARD_NEW_CONTROL_SIM_RUN_DIR)/csrc \
	+vc+list -CC "-I$(VCS_HOME)/include" \
	+incdir+$(SYNOPSYS)/dw/sim_ver -y $(SYNOPSYS)/dw/sim_ver/*.v \
	-l vcs_compile.log

VVOPTS_SHARED_SUBMODULES =-o simv -notice -line +lint=all,noVCDE,noUI +v2k -timescale=1ns/10ps -quiet \
	+define+DEBUG -debug_access+all -sverilog -kdb \
	+incdir+$(SHARED_SUBMODULES_SRC_DIR) -Mdirectory=$(SHARED_SUBMODULES_SIM_RUN_DIR)/csrc \
	+vc+list -CC "-I$(VCS_HOME)/include" \
	+incdir+$(SYNOPSYS)/dw/sim_ver -y $(SYNOPSYS)/dw/sim_ver/*.v \
	-l vcs_compile.log

VVOPTS_AXI4_TEST =-o simv -notice -line +lint=all,noVCDE,noUI +v2k -timescale=1ns/10ps -quiet \
	+define+DEBUG -debug_access+all -sverilog -kdb \
	+incdir+$(AXI4_TEST_SRC_DIR) -Mdirectory=$(AXI4_TEST_SIM_RUN_DIR)/csrc \
	+vc+list -CC "-I$(VCS_HOME)/include" \
	+incdir+$(SYNOPSYS)/dw/sim_ver -y $(SYNOPSYS)/dw/sim_ver/*.v \
	-l vcs_compile.log

VVOPTS_BACKWARD_MODULE_FUNCTIONALITY_TEST =-o simv -notice -line +lint=all,noVCDE,noUI +v2k -timescale=1ns/10ps -quiet \
	+define+DEBUG -debug_access+all -sverilog -kdb \
	+incdir+$(BACKWARD_MODULE_FUNCTIONALITY_TEST_SRC_DIR) -Mdirectory=$(BACKWARD_MODULE_FUNCTIONALITY_TEST_SIM_RUN_DIR)/csrc \
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

${FORWARD_CONTROL_SIM_RUN_DIR}/simv : ${FORWARD_CONTROL_SIM_RUN_DIR}/clean
	@mkdir -p ${FORWARD_CONTROL_SIM_RUN_DIR}
	@cd ${FORWARD_CONTROL_SIM_RUN_DIR} && $(VV) $(VVOPTS_FORWARD_CONTROL) $(FORWARD_CONTROL_SRC_FILES) $(FORWARD_CONTROL_SIM_FILES);
	@./$@;

${BACKWARD_SIM_RUN_DIR}/simv : ${BACKWARD_SIM_RUN_DIR}/clean
	@mkdir -p ${BACKWARD_SIM_RUN_DIR}
	@cd ${BACKWARD_SIM_RUN_DIR} && $(VV) $(VVOPTS_BACKWARD) $(BACKWARD_SRC_FILES) $(BACKWARD_SIM_FILES);
	@./$@;

${BACKWARD_UNIT_SIM_RUN_DIR}/simv : ${BACKWARD_UNIT_SIM_RUN_DIR}/clean
	@mkdir -p ${BACKWARD_UNIT_SIM_RUN_DIR}
	@cd ${BACKWARD_UNIT_SIM_RUN_DIR} && $(VV) $(VVOPTS_BACKWARD_UNIT) $(BACKWARD_UNIT_SRC_FILES) $(BACKWARD_UNIT_SIM_FILES);
	@./$@;

${BACKWARD_SYSTEM_SIM_RUN_DIR}/simv : ${BACKWARD_SYSTEM_SIM_RUN_DIR}/clean
	@mkdir -p ${BACKWARD_SYSTEM_SIM_RUN_DIR}
	@cd ${BACKWARD_SYSTEM_SIM_RUN_DIR} && $(VV) $(VVOPTS_BACKWARD_SYSTEM) $(BACKWARD_SYSTEM_SRC_FILES) $(BACKWARD_SYSTEM_SIM_FILES);
	@./$@;


${BACKWARD_SYSTEM_WO_NEAR_PIXEL_SIM_RUN_DIR}/simv : ${BACKWARD_SYSTEM_WO_NEAR_PIXEL_SIM_RUN_DIR}/clean
	@mkdir -p ${BACKWARD_SYSTEM_WO_NEAR_PIXEL_SIM_RUN_DIR}
	@cd ${BACKWARD_SYSTEM_WO_NEAR_PIXEL_SIM_RUN_DIR} && $(VV) $(VVOPTS_BACKWARD_SYSTEM_WO_NEAR_PIXEL) $(BACKWARD_SYSTEM_WO_NEAR_PIXEL_SRC_FILES) $(BACKWARD_SYSTEM_WO_NEAR_PIXEL_SIM_FILES);
	@./$@;


${BACKWARD_SYSTEM_WO_NEAR_PIXEL_WO_MAJORITY_SIM_RUN_DIR}/simv : ${BACKWARD_SYSTEM_WO_NEAR_PIXEL_WO_MAJORITY_SIM_RUN_DIR}/clean
	@mkdir -p ${BACKWARD_SYSTEM_WO_NEAR_PIXEL_WO_MAJORITY_SIM_RUN_DIR}
	@cd ${BACKWARD_SYSTEM_WO_NEAR_PIXEL_WO_MAJORITY_SIM_RUN_DIR} && $(VV) $(VVOPTS_BACKWARD_SYSTEM_WO_NEAR_PIXEL_WO_MAJORITY) $(BACKWARD_SYSTEM_WO_NEAR_PIXEL_WO_MAJORITY_SRC_FILES) $(BACKWARD_SYSTEM_WO_NEAR_PIXEL_WO_MAJORITY_SIM_FILES);
	@./$@;


${BACKWARD_SYSTEM_ORIGINAL_SIM_RUN_DIR}/simv : ${BACKWARD_SYSTEM_ORIGINAL_SIM_RUN_DIR}/clean
	@mkdir -p ${BACKWARD_SYSTEM_ORIGINAL_SIM_RUN_DIR}
	@cd ${BACKWARD_SYSTEM_ORIGINAL_SIM_RUN_DIR} && $(VV) $(VVOPTS_BACKWARD_SYSTEM_ORIGINAL) $(BACKWARD_SYSTEM_ORIGINAL_SRC_FILES) $(BACKWARD_SYSTEM_ORIGINAL_SIM_FILES);
	@./$@;


${BACKWARD_NEW_CONTROL_SIM_RUN_DIR}/simv : ${BACKWARD_NEW_CONTROL_SIM_RUN_DIR}/clean
	@mkdir -p ${BACKWARD_NEW_CONTROL_SIM_RUN_DIR}
	@cd ${BACKWARD_NEW_CONTROL_SIM_RUN_DIR} && $(VV) $(VVOPTS_BACKWARD_NEW_CONTROL) $(BACKWARD_NEW_CONTROL_SRC_FILES) $(BACKWARD_NEW_CONTROL_SIM_FILES);
	@./$@;

${BACKWARD_SYSTEM_SINGLE_INPUT_SIM_RUN_DIR}/simv : ${BACKWARD_SYSTEM_SINGLE_INPUT_SIM_RUN_DIR}/clean
	@mkdir -p ${BACKWARD_SYSTEM_SINGLE_INPUT_SIM_RUN_DIR}
	@cd ${BACKWARD_SYSTEM_SINGLE_INPUT_SIM_RUN_DIR} && $(VV) $(VVOPTS_BACKWARD_SYSTEM_SINGLE_INPUT) $(BACKWARD_SYSTEM_SINGLE_INPUT_SRC_FILES) $(BACKWARD_SYSTEM_SINGLE_INPUT_SIM_FILES);
	@./$@;

${BACKWARD_SYSTEM_SINGLE_INPUT_WO_MAJORITY_AND_NEAR_PIXEL_SIM_RUN_DIR}/simv : ${BACKWARD_SYSTEM_SINGLE_INPUT_WO_MAJORITY_AND_NEAR_PIXEL_SIM_RUN_DIR}/clean
	@mkdir -p ${BACKWARD_SYSTEM_SINGLE_INPUT_WO_MAJORITY_AND_NEAR_PIXEL_SIM_RUN_DIR}
	@cd ${BACKWARD_SYSTEM_SINGLE_INPUT_WO_MAJORITY_AND_NEAR_PIXEL_SIM_RUN_DIR} && $(VV) $(VVOPTS_BACKWARD_SYSTEM_SINGLE_INPUT_WO_MAJORITY_AND_NEAR_PIXEL) $(BACKWARD_SYSTEM_SINGLE_INPUT_WO_MAJORITY_AND_NEAR_PIXEL_SRC_FILES) $(BACKWARD_SYSTEM_SINGLE_INPUT_WO_MAJORITY_AND_NEAR_PIXEL_SIM_FILES);
	@./$@;


${SHARED_SUBMODULES_SIM_RUN_DIR}/simv : ${SHARED_SUBMODULES_SIM_RUN_DIR}/clean
	@mkdir -p ${SHARED_SUBMODULES_SIM_RUN_DIR}
	@cd ${SHARED_SUBMODULES_SIM_RUN_DIR} && $(VV) $(VVOPTS_SHARED_SUBMODULES) $(SHARED_SUBMODULES_SRC_FILES) $(SHARED_SUBMODULES_SIM_FILES);
	@./$@;

${AXI4_TEST_SIM_RUN_DIR}/simv : ${AXI4_TEST_SIM_RUN_DIR}/clean
	@mkdir -p ${AXI4_TEST_SIM_RUN_DIR}
	@cd ${AXI4_TEST_SIM_RUN_DIR} && $(VV) $(VVOPTS_AXI4_TEST) $(AXI4_TEST_SRC_FILES) $(AXI4_TEST_SIM_FILES);
	@./$@;

${BACKWARD_MODULE_FUNCTIONALITY_TEST_SIM_RUN_DIR}/simv : ${BACKWARD_MODULE_FUNCTIONALITY_TEST_SIM_RUN_DIR}/clean
	@mkdir -p ${BACKWARD_MODULE_FUNCTIONALITY_TEST_SIM_RUN_DIR}
	@cd ${BACKWARD_MODULE_FUNCTIONALITY_TEST_SIM_RUN_DIR} && $(VV) $(VVOPTS_BACKWARD_MODULE_FUNCTIONALITY_TEST) $(BACKWARD_MODULE_FUNCTIONALITY_TEST_SRC_FILES) $(BACKWARD_MODULE_FUNCTIONALITY_TEST_SIM_FILES);
	@./$@;


${FORWARD_SIM_RUN_DIR}/waveform : ${FORWARD_SIM_RUN_DIR}/simv
	cd ${FORWARD_SIM_RUN_DIR} && ${nWave} forward_frame_dump.fsdb

${FORWARD_CONTROL_SIM_RUN_DIR}/waveform : ${FORWARD_CONTROL_SIM_RUN_DIR}/simv
	cd ${FORWARD_CONTROL_SIM_RUN_DIR} && ${nWave} forward_control_dump.fsdb

${BACKWARD_SIM_RUN_DIR}/waveform : ${BACKWARD_SIM_RUN_DIR}/simv
	cd ${BACKWARD_SIM_RUN_DIR} && ${nWave} backward_dump.fsdb

${BACKWARD_UNIT_SIM_RUN_DIR}/waveform : ${BACKWARD_UNIT_SIM_RUN_DIR}/simv
	cd ${BACKWARD_UNIT_SIM_RUN_DIR} && ${nWave} backward_unit_dump.fsdb

${BACKWARD_SYSTEM_SIM_RUN_DIR}/waveform : ${BACKWARD_SYSTEM_SIM_RUN_DIR}/simv
	cd ${BACKWARD_SYSTEM_SIM_RUN_DIR} && ${nWave} backward_system_dump.fsdb

${BACKWARD_SYSTEM_WO_NEAR_PIXEL_SIM_RUN_DIR}/waveform : ${BACKWARD_SYSTEM_WO_NEAR_PIXEL_SIM_RUN_DIR}/simv
	cd ${BACKWARD_SYSTEM_WO_NEAR_PIXEL_SIM_RUN_DIR} && ${nWave} backward_system_wo_near_pixel_dump.fsdb

${BACKWARD_SYSTEM_WO_NEAR_PIXEL_WO_MAJORITY_SIM_RUN_DIR}/waveform : ${BACKWARD_SYSTEM_WO_NEAR_PIXEL_WO_MAJORITY_SIM_RUN_DIR}/simv
	cd ${BACKWARD_SYSTEM_WO_NEAR_PIXEL_WO_MAJORITY_SIM_RUN_DIR} && ${nWave} backward_system_wo_near_pixel_wo_majority_dump.fsdb


${BACKWARD_SYSTEM_SINGLE_INPUT_SIM_RUN_DIR}/waveform : ${BACKWARD_SYSTEM_SINGLE_INPUT_SIM_RUN_DIR}/simv
	cd ${BACKWARD_SYSTEM_SINGLE_INPUT_SIM_RUN_DIR} && ${nWave} backward_system_single_input_dump.fsdb

${BACKWARD_SYSTEM_SINGLE_INPUT_WO_MAJORITY_AND_NEAR_PIXEL_SIM_RUN_DIR}/waveform : ${BACKWARD_SYSTEM_SINGLE_INPUT_WO_MAJORITY_AND_NEAR_PIXEL_SIM_RUN_DIR}/simv
	cd ${BACKWARD_SYSTEM_SINGLE_INPUT_WO_MAJORITY_AND_NEAR_PIXEL_SIM_RUN_DIR} && ${nWave} backward_system_single_input_wo_majority_wo_near_pixel_dump.fsdb

${BACKWARD_NEW_CONTROL_SIM_RUN_DIR}/waveform : ${BACKWARD_NEW_CONTROL_SIM_RUN_DIR}/simv
	cd ${BACKWARD_NEW_CONTROL_SIM_RUN_DIR} && ${nWave} backward_new_control_dump.fsdb

${SHARED_SUBMODULES_SIM_RUN_DIR}/waveform : ${SHARED_SUBMODULES_SIM_RUN_DIR}/simv
	cd ${SHARED_SUBMODULES_SIM_RUN_DIR} && ${nWave} shared_submodules_dump.fsdb

${AXI4_TEST_SIM_RUN_DIR}/waveform : ${AXI4_TEST_SIM_RUN_DIR}/simv
	cd ${AXI4_TEST_SIM_RUN_DIR} && ${nWave} axi4_test_dump.fsdb

${BACKWARD_SYSTEM_ORIGINAL_SIM_RUN_DIR}/waveform : ${BACKWARD_SYSTEM_ORIGINAL_SIM_RUN_DIR}/simv
	cd ${BACKWARD_SYSTEM_ORIGINAL_SIM_RUN_DIR} && ${nWave} backward_system_original_dump.fsdb

${BACKWARD_NEW_CONTROL_SINGLE_INPUT_SIM_RUN_DIR}/waveform : ${BACKWARD_NEW_CONTROL_SINGLE_INPUT_SIM_RUN_DIR}/simv
	cd ${BACKWARD_NEW_CONTROL_SINGLE_INPUT_SIM_RUN_DIR} && ${nWave} backward_new_control_single_input_dump.fsdb

${BACKWARD_MODULE_FUNCTIONALITY_TEST_SIM_RUN_DIR}/waveform : ${BACKWARD_MODULE_FUNCTIONALITY_TEST_SIM_RUN_DIR}/simv
	cd ${BACKWARD_MODULE_FUNCTIONALITY_TEST_SIM_RUN_DIR} && ${nWave} backward_module_functionality_test_dump.fsdb






${FORWARD_SIM_RUN_DIR}/verdi : 
	cd ${FORWARD_SIM_RUN_DIR} && ${Verdi} $(DW_FILES) $(FORWARD_SRC_FILES) $(FORWARD_SIM_FILES);

${BACKWARD_SIM_RUN_DIR}/verdi : 
	cd ${BACKWARD_SIM_RUN_DIR} && ${Verdi} $(DW_FILES) $(BACKWARD_SRC_FILES) $(BACKWARD_SIM_FILES);

${SHARED_SUBMODULES_SIM_RUN_DIR}/verdi : 
	cd ${SHARED_SUBMODULES_SIM_RUN_DIR} && ${Verdi} $(DW_FILES) $(SHARED_SUBMODULES_SRC_FILES) $(SHARED_SUBMODULES_SIM_FILES);

${COMBINED_BACKWARD_SIM_RUN_DIR}/verdi : 
	cd ${COMBINED_BACKWARD_SIM_RUN_DIR} && ${Verdi} $(DW_FILES) $(COMBINED_BACKWARD_SRC_FILES) $(COMBINED_BACKWARD_SIM_FILES);

${BACKWARD_SYSTEM_SIM_RUN_DIR}/verdi : 
	cd ${BACKWARD_SYSTEM_SIM_RUN_DIR} && ${Verdi} $(DW_FILES) $(BACKWARD_SYSTEM_SRC_FILES) $(BACKWARD_SYSTEM_SIM_FILES);

${AXI4_TEST_SIM_RUN_DIR}/verdi : 
	cd ${AXI4_TEST_SIM_RUN_DIR} && ${Verdi} $(DW_FILES) $(AXI4_TEST_SRC_FILES) $(AXI4_TEST_SIM_FILES);

${BACKWARD_NEW_CONTROL_SINGLE_INPUT_SIM_RUN_DIR}/verdi : 
	cd ${BACKWARD_NEW_CONTROL_SINGLE_INPUT_SIM_RUN_DIR} && ${Verdi} $(DW_FILES) $(BACKWARD_NEW_CONTROL_SINGLE_INPUT_SRC_FILES) $(BACKWARD_NEW_CONTROL_SINGLE_INPUT_SIM_FILES);

${BACKWARD_SYSTEM_SINGLE_INPUT_SIM_RUN_DIR}/verdi : 
	cd ${BACKWARD_SYSTEM_SINGLE_INPUT_SIM_RUN_DIR} && ${Verdi} $(DW_FILES) $(BACKWARD_SYSTEM_SINGLE_INPUT_SRC_FILES) $(BACKWARD_SYSTEM_SINGLE_INPUT_SIM_FILES);

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

${FORWARD_CONTROL_SIM_RUN_DIR}/clean:
	@rm -rf ${FORWARD_CONTROL_SIM_RUN_DIR}/novas.*
	@rm -rf ${FORWARD_CONTROL_SIM_RUN_DIR}/ucli.key
	@rm -rf ${FORWARD_CONTROL_SIM_RUN_DIR}/*.log
	@rm -rf ${FORWARD_CONTROL_SIM_RUN_DIR}/*
	@echo "Simulation Clean Completed"
	@rm -rf ${FORWARD_CONTROL_SIM_RUN_DIR}/csrc

${BACKWARD_SIM_RUN_DIR}/clean:
	@rm -rf ${BACKWARD_SIM_RUN_DIR}/novas.*
	@rm -rf ${BACKWARD_SIM_RUN_DIR}/ucli.key
	@rm -rf ${BACKWARD_SIM_RUN_DIR}/*.log
	@rm -rf ${BACKWARD_SIM_RUN_DIR}/*
	@echo "Simulation Clean Completed"
	@rm -rf ${BACKWARD_SIM_RUN_DIR}/csrc


${BACKWARD_UNIT_SIM_RUN_DIR}/clean:
	@rm -rf ${BACKWARD_UNIT_SIM_RUN_DIR}/novas.*
	@rm -rf ${BACKWARD_UNIT_SIM_RUN_DIR}/ucli.key
	@rm -rf ${BACKWARD_UNIT_SIM_RUN_DIR}/*.log
	@rm -rf ${BACKWARD_UNIT_SIM_RUN_DIR}/*
	@echo "Simulation Clean Completed"
	@rm -rf ${BACKWARD_UNIT_SIM_RUN_DIR}/csrc


${BACKWARD_SYSTEM_SIM_RUN_DIR}/clean:
	@rm -rf ${BACKWARD_SYSTEM_SIM_RUN_DIR}/novas.*
	@rm -rf ${BACKWARD_SYSTEM_SIM_RUN_DIR}/ucli.key
	@rm -rf ${BACKWARD_SYSTEM_SIM_RUN_DIR}/*.log
	@rm -rf ${BACKWARD_SYSTEM_SIM_RUN_DIR}/*
	@echo "Simulation Clean Completed"
	@rm -rf ${BACKWARD_SYSTEM_SIM_RUN_DIR}/csrc

${BACKWARD_NEW_CONTROL_SIM_RUN_DIR}/clean:
	@rm -rf ${BACKWARD_NEW_CONTROL_SIM_RUN_DIR}/novas.*
	@rm -rf ${BACKWARD_NEW_CONTROL_SIM_RUN_DIR}/ucli.key
	@rm -rf ${BACKWARD_NEW_CONTROL_SIM_RUN_DIR}/*.log
	@rm -rf ${BACKWARD_NEW_CONTROL_SIM_RUN_DIR}/*
	@echo "Simulation Clean Completed"
	@rm -rf ${BACKWARD_NEW_CONTROL_SIM_RUN_DIR}/csrc


${SHARED_SUBMODULES_SIM_RUN_DIR}/clean:
	@rm -rf ${SHARED_SUBMODULES_SIM_RUN_DIR}/novas.*
	@rm -rf ${SHARED_SUBMODULES_SIM_RUN_DIR}/ucli.key
	@rm -rf ${SHARED_SUBMODULES_SIM_RUN_DIR}/*.log
	@rm -rf ${SHARED_SUBMODULES_SIM_RUN_DIR}/*
	@echo "Simulation Clean Completed"
	@rm -rf ${SHARED_SUBMODULES_SIM_RUN_DIR}/csrc

${AXI4_TEST_SIM_RUN_DIR}/clean:
	@rm -rf ${AXI4_TEST_SIM_RUN_DIR}/novas.*
	@rm -rf ${AXI4_TEST_SIM_RUN_DIR}/ucli.key
	@rm -rf ${AXI4_TEST_SIM_RUN_DIR}/*.log
	@rm -rf ${AXI4_TEST_SIM_RUN_DIR}/*
	@echo "Simulation Clean Completed"
	@rm -rf ${AXI4_TEST_SIM_RUN_DIR}/csrc

${BACKWARD_NEW_CONTROL_SINGLE_INPUT_SIM_RUN_DIR}/clean:
	@rm -rf ${BACKWARD_NEW_CONTROL_SINGLE_INPUT_SIM_RUN_DIR}/novas.*
	@rm -rf ${BACKWARD_NEW_CONTROL_SINGLE_INPUT_SIM_RUN_DIR}/ucli.key
	@rm -rf ${BACKWARD_NEW_CONTROL_SINGLE_INPUT_SIM_RUN_DIR}/*.log
	@rm -rf ${BACKWARD_NEW_CONTROL_SINGLE_INPUT_SIM_RUN_DIR}/*
	@echo "Simulation Clean Completed"
	@rm -rf ${BACKWARD_NEW_CONTROL_SINGLE_INPUT_SIM_RUN_DIR}/csrc

${BACKWARD_SYSTEM_SINGLE_INPUT_SIM_RUN_DIR}/clean:
	@rm -rf ${BACKWARD_SYSTEM_SINGLE_INPUT_SIM_RUN_DIR}/novas.*
	@rm -rf ${BACKWARD_SYSTEM_SINGLE_INPUT_SIM_RUN_DIR}/ucli.key
	@rm -rf ${BACKWARD_SYSTEM_SINGLE_INPUT_SIM_RUN_DIR}/*.log
	@rm -rf ${BACKWARD_SYSTEM_SINGLE_INPUT_SIM_RUN_DIR}/*
	@echo "Simulation Clean Completed"
	@rm -rf ${BACKWARD_SYSTEM_SINGLE_INPUT_SIM_RUN_DIR}/csrc

${BACKWARD_SYSTEM_SINGLE_INPUT_WO_MAJORITY_AND_NEAR_PIXEL_SIM_RUN_DIR}/clean:
	@rm -rf ${BACKWARD_SYSTEM_SINGLE_INPUT_WO_MAJORITY_AND_NEAR_PIXEL_SIM_RUN_DIR}/novas.*
	@rm -rf ${BACKWARD_SYSTEM_SINGLE_INPUT_WO_MAJORITY_AND_NEAR_PIXEL_SIM_RUN_DIR}/ucli.key
	@rm -rf ${BACKWARD_SYSTEM_SINGLE_INPUT_WO_MAJORITY_AND_NEAR_PIXEL_SIM_RUN_DIR}/*.log
	@rm -rf ${BACKWARD_SYSTEM_SINGLE_INPUT_WO_MAJORITY_AND_NEAR_PIXEL_SIM_RUN_DIR}/*
	@echo "Simulation Clean Completed"
	@rm -rf ${BACKWARD_SYSTEM_SINGLE_INPUT_WO_MAJORITY_AND_NEAR_PIXEL_SIM_RUN_DIR}/csrc

${BACKWARD_SYSTEM_WO_NEAR_PIXEL_SIM_RUN_DIR}/clean:
	@rm -rf ${BACKWARD_SYSTEM_WO_NEAR_PIXEL_SIM_RUN_DIR}/novas.*
	@rm -rf ${BACKWARD_SYSTEM_WO_NEAR_PIXEL_SIM_RUN_DIR}/ucli.key
	@rm -rf ${BACKWARD_SYSTEM_WO_NEAR_PIXEL_SIM_RUN_DIR}/*.log
	@rm -rf ${BACKWARD_SYSTEM_WO_NEAR_PIXEL_SIM_RUN_DIR}/*
	@echo "Simulation Clean Completed"

${BACKWARD_SYSTEM_WO_NEAR_PIXEL_WO_MAJORITY_SIM_RUN_DIR}/clean:
	@rm -rf ${BACKWARD_SYSTEM_WO_NEAR_PIXEL_WO_MAJORITY_SIM_RUN_DIR}/novas.*
	@rm -rf ${BACKWARD_SYSTEM_WO_NEAR_PIXEL_WO_MAJORITY_SIM_RUN_DIR}/ucli.key
	@rm -rf ${BACKWARD_SYSTEM_WO_NEAR_PIXEL_WO_MAJORITY_SIM_RUN_DIR}/*.log
	@rm -rf ${BACKWARD_SYSTEM_WO_NEAR_PIXEL_WO_MAJORITY_SIM_RUN_DIR}/*
	@echo "Simulation Clean Completed"

${BACKWARD_SYSTEM_ORIGINAL_SIM_RUN_DIR}/clean:
	@rm -rf ${BACKWARD_SYSTEM_ORIGINAL_SIM_RUN_DIR}/novas.*
	@rm -rf ${BACKWARD_SYSTEM_ORIGINAL_SIM_RUN_DIR}/ucli.key
	@rm -rf ${BACKWARD_SYSTEM_ORIGINAL_SIM_RUN_DIR}/*.log
	@rm -rf ${BACKWARD_SYSTEM_ORIGINAL_SIM_RUN_DIR}/*
	@echo "Simulation Clean Completed"

${BACKWARD_MODULE_FUNCTIONALITY_TEST_SIM_RUN_DIR}/clean:
	@rm -rf ${BACKWARD_MODULE_FUNCTIONALITY_TEST_SIM_RUN_DIR}/novas.*
	@rm -rf ${BACKWARD_MODULE_FUNCTIONALITY_TEST_SIM_RUN_DIR}/ucli.key
	@rm -rf ${BACKWARD_MODULE_FUNCTIONALITY_TEST_SIM_RUN_DIR}/*.log
	@rm -rf ${BACKWARD_MODULE_FUNCTIONALITY_TEST_SIM_RUN_DIR}/*
	@echo "Simulation Clean Completed"

