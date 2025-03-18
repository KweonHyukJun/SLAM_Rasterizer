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
`define MAX_MEMBER_SIZE 400000
// `define MAX_CLOCK_COUNT 100000000 // 천만
// `define MAX_CLOCK_COUNT 7000000
`define MAX_CLOCK_COUNT 3500000
// `define MAX_CLOCK_COUNT 1000000



module tb_Backward_system 
    #(
        BLOCK_SIZE = 16,
        exponent_bit = 8, 
        precision = 16, 
        mantissa_bit = 7, 
        gaussian_inputs = 4, 
        num_pixels = 16, 
        GID_bit = 12,
        WINDOW_SIZE = 32,
        GRADIENT_MERGE_TO_TOP_WIDTH = 11 * precision,
        target_count = 15000,
        Banks = 16
    ) ();

    integer max_clock_count = `MAX_CLOCK_COUNT;


    // Input
    reg clk;
    reg rst_n;

    reg backward_start;
    wire backward_ready;

    wire backward_done;

    reg [11:0] W_in;
    reg [11:0] H_in;

    

    
    // integer stall_by_encoder = 0;
    // integer stall_by_4x_fifo = 0;

    // integer stall_report;

    // integer dL_dcolor_out_file;
    // integer dL_ddepth_out_file;
    // integer dL_dopacity_out_file;
    // integer dL_dmean2D_out_file;
    // integer dL_dconic_out_file;
    // integer original_gaussian_file;

    initial begin
        $fsdbDumpfile("../output_backward_system/backward_system_dump.fsdb");
        $fsdbDumpvars(0, tb_Backward_system, "+all");
    end


    // Instantiate the DUT (Device Under Test)
    Backward_system #( 
        .BLOCK_SIZE(BLOCK_SIZE), 
        .exponent_bit(exponent_bit), 
        .mantissa_bit(mantissa_bit), 
        .precision(precision), 
        .gaussian_inputs(gaussian_inputs), 
        .num_pixels(num_pixels),
        .GID_bit(GID_bit),
        .WINDOW_SIZE(WINDOW_SIZE),
        .Banks(Banks),
        .GRADIENT_MERGE_TO_TOP_WIDTH(GRADIENT_MERGE_TO_TOP_WIDTH)
        ) 
    Backward_system_inst (
        .clk(clk),
        .rst_n(rst_n),
    
        .backward_start(backward_start),
        .backward_ready(backward_ready),

        .backward_done(backward_done),

        .W_in(W_in),
        .H_in(H_in)
    );

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


    // initial begin

    //     $readmemh($sformatf("../HEX_TB/hex/Combined/Forward_and_Backward_Test/TUM1_%0d_fp%0d/conic_opacity.hex", target_count, precision), mem_conic_opacity);
    //     $readmemh($sformatf("../HEX_TB/hex/Combined/Forward_and_Backward_Test/TUM1_%0d_fp%0d/mean2D.hex", target_count, precision), mem_mean2D);

    //     $readmemh($sformatf("../HEX_TB/hex/Combined/Forward_and_Backward_Test/TUM1_%0d_fp%0d/gaussian_color.hex", target_count, precision), mem_gaussian_color);
    //     $readmemh($sformatf("../HEX_TB/hex/Combined/Forward_and_Backward_Test/TUM1_%0d_fp%0d/gaussian_depth.hex", target_count, precision), mem_gaussian_depth);

    //     $readmemh($sformatf("../HEX_TB/hex/Combined/Forward_and_Backward_Test/TUM1_%0d_fp%0d/point_list.hex", target_count, precision), mem_gaussian_id_in);


    //     $readmemh($sformatf("../HEX_TB/hex/Combined/Forward_and_Backward_Test/TUM1_%0d_fp%0d/final_T.hex", target_count, precision), mem_T_in);
    //     $readmemh($sformatf("../HEX_TB/hex/Combined/Forward_and_Backward_Test/TUM1_%0d_fp%0d/dL_dpixel.hex", target_count, precision), mem_dL_dpixel);
    //     $readmemh($sformatf("../HEX_TB/hex/Combined/Forward_and_Backward_Test/TUM1_%0d_fp%0d/dL_dpixel_depth.hex", target_count, precision), mem_dL_dpixel_depth);
    //     $readmemh($sformatf("../HEX_TB/hex/Combined/Forward_and_Backward_Test/TUM1_%0d_fp%0d/n_contrib.hex", target_count, precision), mem_n_contrib);

    //     $readmemh($sformatf("../HEX_TB/hex/Combined/Forward_and_Backward_Test/TUM1_%0d_fp%0d/ranges.hex", target_count, precision), mem_range);      

    // end

    initial begin
        
        // // file_handle = $fopen("../simulation_output/Testbench_output_from_block_controller_new_encoder_with_%0d.txt", "w");
        
        // file_handle = $fopen($sformatf("../simulation_output/Backward_results/target_count_%0d/Testbench_output_from_block_controller_new_encoder_with_%0d.txt", target_count, gaussian_inputs), "w");

        // if (file_handle == 0) begin
        //     $display("Error: Could not open file for writing!");
        //     $finish;
        // end

        // state_report = $fopen($sformatf("../simulation_output/Backward_results/target_count_%0d/Block_controller_state_time_with_fp%0d_gaussian_inputs%0d.txt", target_count, precision, gaussian_inputs), "w");
        // if (state_report == 0) begin
        //     $display("Error: Could not open file for writing!");
        //     $finish;
        // end

        // dL_dcolor_out_file = $fopen($sformatf("../simulation_output/Backward_results/target_count_%0d/dL_dcolor_out_new_encoder_with_fp%0d_gaussian_inputs%0d.txt", target_count, precision, gaussian_inputs), "w");
        // dL_ddepth_out_file = $fopen($sformatf("../simulation_output/Backward_results/target_count_%0d/dL_ddepth_out_new_encoder_with_fp%0d_gaussian_inputs%0d.txt", target_count, precision, gaussian_inputs), "w");
        // dL_dopacity_out_file = $fopen($sformatf("../simulation_output/Backward_results/target_count_%0d/dL_dopacity_out_new_encoder_with_fp%0d_gaussian_inputs%0d.txt", target_count, precision, gaussian_inputs), "w");
        // dL_dmean2D_out_file = $fopen($sformatf("../simulation_output/Backward_results/target_count_%0d/dL_dmean2D_out_new_encoder_with_fp%0d_gaussian_inputs%0d.txt", target_count, precision, gaussian_inputs), "w");
        // dL_dconic_out_file = $fopen($sformatf("../simulation_output/Backward_results/target_count_%0d/dL_dconic_out_new_encoder_with_fp%0d_gaussian_inputs%0d.txt", target_count, precision, gaussian_inputs), "w");
        // original_gaussian_file = $fopen($sformatf("../simulation_output/Backward_results/target_count_%0d/original_gaussian_id_new_encoder_with_fp%0d_gaussian_inputs%0d.txt", target_count, precision, gaussian_inputs), "w");

        // if (dL_dcolor_out_file == 0 || dL_ddepth_out_file == 0 || dL_dopacity_out_file == 0 || dL_dmean2D_out_file == 0 || dL_dconic_out_file == 0) begin
        //     $display("Error: Could not open file for writing!");
        //     $finish;
        // end

        // stall_report = $fopen($sformatf("../simulation_output/Backward_results/target_count_%0d/stall_report_from_block_controller_new_encoder_with_fp%0d_gaussian_inputs%0d.txt", target_count, precision, gaussian_inputs), "w");

        // if (stall_report == 0) begin
        //     $display("Error: Could not open file for writing!");
        //     $finish;
        // end


        $display("Entire system test data %0d, gaussian inputs %0d, precision %0d", target_count, gaussian_inputs, precision);

        clk <= 1'b0;
        rst_n <= 1'b0;

        H_in <= 'd0;
        W_in <= 'd0;

        @(posedge clk);

            // First Start cycles

            rst_n <= 1'b1;
            W_in <= 'd640;
            H_in <= 'd480;

        
    end

    always_ff @ (posedge clk) begin
        if (!rst_n) begin
            clk_cnt <= 0;
        end

        else begin

        end     
    end

    always_ff @ (posedge clk) begin
       if (backward_done) begin
            $display("Backward done");
            $finish;
       end 
    end
endmodule

