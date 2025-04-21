//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/09/19 11:25:32
// Design Name: 
// Module Name: tb_INT_tester
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`define MAX_MEMBER_SIZE 40000000
// `define MAX_CLOCK_COUNT 100000000 // 천만
// `define MAX_CLOCK_COUNT 7000000
`define MAX_CLOCK_COUNT 35000000
// `define MAX_CLOCK_COUNT 100000



module tb_Backward_system_AXI4_fetching_wo_majority_wo_near_pixel_single_input
    #(
        BLOCK_SIZE = 16,
        exponent_bit = 8, 
        precision = 16, 
        mantissa_bit = 7, 
        num_pixels = 16, 
        GID_bit = 12,
        WINDOW_SIZE = 32,
        GRADIENT_MERGE_TO_TOP_WIDTH = 11 * precision,
        target_count = 15000,
        Banks = 16
    ) ();

    integer max_clock_count = `MAX_CLOCK_COUNT;
    integer max_member_size = `MAX_MEMBER_SIZE;

    // Input
    reg clk;
    reg rst_n;

    reg backward_start;
    wire backward_ready;

    wire backward_done;

    wire [31:0] base_address;

    reg [11:0] W_in;
    reg [11:0] H_in;


    parameter N_GAUSSIANS = 50000;

    
    integer stall_by_encoder = 0;
    integer stall_by_1x_fifo = 0;

    integer stall_report;

    integer dL_dcolor_file;
    integer dL_ddepth_file;
    integer dL_dopacity_file;
    integer dL_dmean2D_file;
    integer dL_dconic_file;

    integer file_handle;
    
    integer prev_clk_cnt = 0;
    integer prev_block_index = 0;

    initial begin
        $fsdbDumpfile("../output_backward_system_single_input_wo_majority_wo_near_pixel/backward_system_single_input_wo_majority_wo_near_pixel_dump.fsdb");
        $fsdbDumpvars(0, tb_Backward_system_AXI4_fetching_wo_majority_wo_near_pixel_single_input, "+all");
    end


    // Instantiate the DUT (Device Under Test)
    Backward_system_AXI4_fetching_wo_majority_wo_near_pixel_single_input #( 
        .BLOCK_SIZE(BLOCK_SIZE), 
        .exponent_bit(exponent_bit), 
        .mantissa_bit(mantissa_bit), 
        .precision(precision), 
        .num_pixels(num_pixels),
        .GID_bit(GID_bit),
        .WINDOW_SIZE(WINDOW_SIZE),
        .Banks(Banks),
        .GRADIENT_MERGE_TO_TOP_WIDTH(GRADIENT_MERGE_TO_TOP_WIDTH)
        ) 
    Backward_system_AXI4_fetching_inst (
        .clk(clk),
        .rst_n(rst_n),
    
        .backward_start(backward_start),
        .backward_ready(backward_ready),

        .backward_done(backward_done),

        .W_in(W_in),
        .H_in(H_in),

        .base_address(base_address)
    );

    initial begin
        // file_handle = $fopen($sformatf("../simulation_output/Testbench_output_from_pipelining_block_controller_original_encoder_with_near_pixel_fp%0d.txt", gaussian_inputs), "w");
        file_handle = $fopen($sformatf("../MICRO_ICCAD/AXI4/Office0/Block_time_target_count%0d_fp%0d_single_input_wo_majority_wo_near_pixel.txt", target_count, precision), "w");

        dL_dcolor_file = $fopen($sformatf("../MICRO_ICCAD/AXI4/Office0/dL_dcolor_out_target_count%0d_fp%0d_single_input_wo_majority_wo_near_pixel.txt", target_count, precision), "w");
        dL_ddepth_file = $fopen($sformatf("../MICRO_ICCAD/AXI4/Office0/dL_ddepth_out_target_count%0d_fp%0d_single_input_wo_majority_wo_near_pixel.txt", target_count, precision), "w");
        dL_dopacity_file = $fopen($sformatf("../MICRO_ICCAD/AXI4/Office0/dL_dopacity_out_target_count%0d_fp%0d_single_input_wo_majority_wo_near_pixel.txt", target_count, precision), "w");
        dL_dmean2D_file = $fopen($sformatf("../MICRO_ICCAD/AXI4/Office0/dL_dmean2D_out_target_count%0d_fp%0d_single_input_wo_majority_wo_near_pixel.txt", target_count, precision), "w");
        dL_dconic_file = $fopen($sformatf("../MICRO_ICCAD/AXI4/Office0/dL_dconic_out_target_count%0d_fp%0d_single_input_wo_majority_wo_near_pixel.txt", target_count, precision), "w");


        stall_report = $fopen($sformatf("../MICRO_ICCAD/AXI4/Office0/stall_report_from_block_controller_target_count%0d_fp%0d_single_input_wo_majority_wo_near_pixel.txt", target_count, precision), "w");

        if (stall_report == 0) begin
            $display("Error: Could not open file for writing!");
            $finish;
        end

        if (file_handle == 0) begin
            $display("Error: Could not open file for writing!");
            $finish;
        end


        // $display("Data %0d, gaussian inputs %0d, precision %0d starting block index %0d", target_count, gaussian_inputs, precision, Backward_system_AXI4_fetching_inst.Backward_top_controller_inst.block_index_for_control);

    end


    initial begin
        // Set composite fast draw member size
        $value$plusargs("SET_COMPOSITE_FAST_DRAW_MEMBER_SIZE=%d", max_member_size);
    end
    // Initial reg example
    // uut.T0 = 32'h1;
    always begin
        #0.5 clk = !clk;  // Toggle clock every half period
    end

    integer clk_cnt = 0;

    always @(posedge clk) begin
        clk_cnt <= clk_cnt + 1;
        if (clk_cnt == max_clock_count) $finish;
    end


    initial begin

        clk <= 1'b0;
        rst_n <= 1'b0;

        H_in <= 'd0;
        W_in <= 'd0;
        backward_start <= 'd0;



        @(posedge clk);

            // First Start cycles
            backward_start <= 1'b1;
            rst_n <= 1'b1;
            W_in <= 'd640;
            H_in <= 'd480;
            $display("Data Office0 data %0d single input precision %0d", target_count, precision);
        
        @(posedge clk);
        backward_start <= 1'b0;


    end


    always @ (posedge clk) begin
       if (backward_done) begin
    // if (Backward_system_AXI4_fetching_inst.Backward_top_controller_inst.block_index_for_control == 'd100) begin

            repeat(5) begin
                $display("\n");
            end

            $display("----------------------------------------------------------------------------------------------------");
            $display("Until %d", Backward_system_AXI4_fetching_inst.Backward_top_controller_inst.block_index_for_control);
            $display("End Time : %d", clk_cnt);
            
            $display("----------------------------------------------------------------------------------------------------");


            $fwrite(stall_report, "End Time : %0d\n\n", clk_cnt);
        
            $fwrite(stall_report, "encoder stall time (Too much valid output or 4X FIFO full): %0d\n", stall_by_encoder);
            // $fwrite(stall_report, "4X stall time  (4X FIFO Full): %0d\n\n", stall_by_4x_fifo);
            // $fwrite(stall_report, "1X stall time  (1X FIFO Full): %0d\n\n", stall_by_1x_fifo);
            // $fwrite(stall_report, "serializer stall time (Too much valid output or 4X FIFO full): %0d\n", stall_by_serializer);



            for (int i = 0; i < N_GAUSSIANS; i++) begin
                $fwrite(dL_dcolor_file, "%h %h %h\n", Backward_system_AXI4_fetching_inst.Gradient_Block_RAM_inst.inst.axi_mem_module.blk_mem_gen_v8_4_8_inst.memory[i][11 * precision-1:10*precision], Backward_system_AXI4_fetching_inst.Gradient_Block_RAM_inst.inst.axi_mem_module.blk_mem_gen_v8_4_8_inst.memory[i][10 * precision-1:9*precision], Backward_system_AXI4_fetching_inst.Gradient_Block_RAM_inst.inst.axi_mem_module.blk_mem_gen_v8_4_8_inst.memory[i][9 * precision-1:8*precision]);
                $fwrite(dL_ddepth_file, "%h\n", Backward_system_AXI4_fetching_inst.Gradient_Block_RAM_inst.inst.axi_mem_module.blk_mem_gen_v8_4_8_inst.memory[i][8 * precision-1:7*precision]);
                $fwrite(dL_dmean2D_file, "%h %h\n", Backward_system_AXI4_fetching_inst.Gradient_Block_RAM_inst.inst.axi_mem_module.blk_mem_gen_v8_4_8_inst.memory[i][(7 * precision)-1:6 * precision], Backward_system_AXI4_fetching_inst.Gradient_Block_RAM_inst.inst.axi_mem_module.blk_mem_gen_v8_4_8_inst.memory[i][(6 * precision)-1:5 * precision]);
                $fwrite(dL_dconic_file, "%h %h %h %h\n", Backward_system_AXI4_fetching_inst.Gradient_Block_RAM_inst.inst.axi_mem_module.blk_mem_gen_v8_4_8_inst.memory[i][(5 * precision)-1:4 * precision], Backward_system_AXI4_fetching_inst.Gradient_Block_RAM_inst.inst.axi_mem_module.blk_mem_gen_v8_4_8_inst.memory[i][(4 * precision)-1:3 * precision], Backward_system_AXI4_fetching_inst.Gradient_Block_RAM_inst.inst.axi_mem_module.blk_mem_gen_v8_4_8_inst.memory[i][(2 * precision)-1:precision], Backward_system_AXI4_fetching_inst.Gradient_Block_RAM_inst.inst.axi_mem_module.blk_mem_gen_v8_4_8_inst.memory[i][(2 *precision)-1:precision]);
                $fwrite(dL_dopacity_file, "%h\n", Backward_system_AXI4_fetching_inst.Gradient_Block_RAM_inst.inst.axi_mem_module.blk_mem_gen_v8_4_8_inst.memory[i][precision-1:0]);
            end




            $fwrite(stall_report, "\n");
            $fclose(stall_report);
            // $fclose(gradient_file);


            $finish;
       end 
    end

    assign base_address = 32'h00000000;

    always @ (posedge clk) begin
        if (Backward_system_AXI4_fetching_inst.Combined_Backward_Rasterizer_and_merge_inst.Gradient_merge_unit_by_majority_with_add_inst.stall_from_encoder_comb) begin
            stall_by_encoder <= stall_by_encoder + 1;
        end
        if (Backward_system_AXI4_fetching_inst.Combined_Backward_Rasterizer_and_merge_inst.Gradient_merge_unit_by_majority_with_add_inst.stall_from_1x_fifo_comb) begin
            stall_by_1x_fifo <= stall_by_1x_fifo + 1;
        end
    end


    always @ (posedge clk) begin
        if (Backward_system_AXI4_fetching_inst.Backward_top_controller_inst.block_index_for_control != prev_block_index) begin
            $fwrite(file_handle, "Block %0d complete, clock_cycle: %0d\n", prev_block_index, clk_cnt - prev_clk_cnt);
            $fwrite(file_handle, "Block %0d Accumulated_cycle : %0d\n\n", prev_block_index, clk_cnt);
            prev_clk_cnt <= clk_cnt;
            prev_block_index <= Backward_system_AXI4_fetching_inst.Backward_top_controller_inst.block_index_for_control;


            if (Backward_system_AXI4_fetching_inst.Backward_top_controller_inst.block_index_for_control % 50 == 0) begin
                $display("Block %0d complete, clock_cycle: %0d", Backward_system_AXI4_fetching_inst.Backward_top_controller_inst.block_index_for_control - 'd1, clk_cnt);
            end
        end

        if (clk_cnt % 50000  == 0) begin
            $display("Now, Block %0d, clock_cycle: %0d", Backward_system_AXI4_fetching_inst.Backward_top_controller_inst.block_index_for_control, clk_cnt);
        end
    end

endmodule

