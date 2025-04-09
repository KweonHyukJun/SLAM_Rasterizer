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
// `define MAX_CLOCK_COUNT 3500000
`define MAX_CLOCK_COUNT 500



module tb_Backward_system_AXI4_fetching 
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
    integer max_member_size = `MAX_MEMBER_SIZE;

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
        $fsdbDumpvars(0, tb_Backward_system_AXI4_fetching, "+all");
    end


    // Instantiate the DUT (Device Under Test)
    Backward_system_AXI4_fetching #( 
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
    Backward_system_AXI4_fetching_inst (
        .clk(clk),
        .rst_n(rst_n),
    
        .backward_start(backward_start),
        .backward_ready(backward_ready),

        .backward_done(backward_done),

        .W_in(W_in),
        .H_in(H_in)
    );

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
    

        $display("Entire system test data %0d, gaussian inputs %0d, precision %0d", target_count, gaussian_inputs, precision);

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
        
        @(posedge clk);
        backward_start <= 1'b0;


    end


    always_ff @ (posedge clk) begin
       if (backward_done) begin
            $display("Backward done");
            $finish;
       end 
    end
endmodule

