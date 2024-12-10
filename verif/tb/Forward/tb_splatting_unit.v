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

module tb_splatting_unit #(exponent_bit = 8, mantissa_bit= 23, precision = 32, GID_bit = 32)();
    
    //input
    reg clk, rst_n;
    
    reg stall;
    reg last_input;

    reg start;

    reg [precision-1:0] alpha_in;

    reg [GID_bit-1:0] gaussian_id_in;

    reg [(3 * precision)-1:0] gaussian_color; // | R | G | B |
    reg [precision-1:0] gaussian_depth;

    reg i_valid;

    wire [GID_bit-1:0] gaussian_id_out;
    wire [(3 * precision)-1:0] pixel_color;
    wire [precision-1:0] pixel_depth;
    wire [11:0] n_contrib;
    wire [precision-1:0] pixel_opacity;
    wire [precision-1:0] T_first;
    wire pixel_valid_out;

    reg data_in;
 

    localparam latency = 9;
    integer i = 0;
    integer start_ready;
    
    parameter file_size = 33;
    parameter N_TEST = 1024;
    integer stall_cnt = 0;

    // Input Mem
    reg [precision -1:0] mem_gaussian_color [3 * N_TEST -1 : 0];
    reg [precision -1:0] mem_gaussian_depth [N_TEST - 1:0];


    reg [precision -1:0] mem_alpha [N_TEST -1 :0];
    reg mem_skip [N_TEST -1 :0];
    reg mem_i_valid [N_TEST -1 :0];
    reg mem_last_input [N_TEST -1 :0];

    // Output Mem
    reg [31:0] mem_gaussian_id [N_TEST - 1:0];
    
    integer counter;

    integer file_handle;

    reg ref_valid;
    reg [31:0] ref_gaussian_id;
    



    initial begin
        $fsdbDumpfile("./output/dump.fsdb");
        $fsdbDumpvars(0, tb_splatting_unit, "+all");
    end

    // Instantiate the DUT (Device Under Test)
    // Instantiate the DUT (Device Under Test)
    splatting_unit #(  .exponent_bit(exponent_bit), .mantissa_bit(mantissa_bit), .precision(precision)) 
    uut (
        .clk(clk),
        .rst_n(rst_n),

        .alpha_in(alpha_in),
        .stall(stall),
        .last_input(last_input),

        .start(start),

        .gaussian_id_in(gaussian_id_in),
        .gaussian_color(gaussian_color),
        .gaussian_depth(gaussian_depth),
        
        .i_valid(i_valid),

        .gaussian_id_out(gaussian_id_out),
        .pixel_color(pixel_color),
        .pixel_depth(pixel_depth),
        .n_contrib(n_contrib),
        .pixel_opacity(pixel_opacity),
        .T_first(T_first),
        .pixel_valid_out(pixel_valid_out)

    );
    

    // Initial reg example
    // uut.T0 = 32'h1;
    always begin
        #5 clk = !clk;  // Toggle clock every half period
    end    

    integer clk_cnt = 0;

    always @(posedge clk) begin
        clk_cnt <= clk_cnt + 1;
        if (clk_cnt == 1000) $finish;
    end


    initial begin
        //for FP 16
        if (precision == 16 && mantissa_bit == 7) begin
            $readmemh("../HEX_TB/hex/fp16/gaussian_color.hex", mem_gaussian_color);
            $readmemh("../HEX_TB/hex/fp16/gaussian_depth.hex", mem_gaussian_depth);

            $readmemh("../HEX_TB/hex/fp16/alpha.hex", mem_alpha);
            $readmemh("../HEX_TB/hex/fp16/skip.hex", mem_skip);

            $readmemh("../HEX_TB/hex/fp16/i_valid.hex", mem_i_valid);
            $readmemh("../HEX_TB/hex/fp16/last_input.hex", mem_last_input);
            $readmemh("../HEX_TB/hex/fp16/gaussian_id.hex", mem_gaussian_id);
        end

        //for FP 32
        if (precision == 32 && mantissa_bit == 23) begin

            $readmemh("../HEX_TB/hex/fp32/gaussian_color.hex", mem_gaussian_color);
            $readmemh("../HEX_TB/hex/fp32/gaussian_depth.hex", mem_gaussian_depth);
            $readmemh("../HEX_TB/hex/fp32/alpha.hex", mem_alpha);
            $readmemh("../HEX_TB/hex/fp32/skip.hex", mem_skip);

            $readmemh("../HEX_TB/hex/fp32/i_valid.hex", mem_i_valid);
            $readmemh("../HEX_TB/hex/fp32/last_input.hex", mem_last_input);
            $readmemh("../HEX_TB/hex/fp32/gaussian_id.hex", mem_gaussian_id);
        end
    end
    
    initial begin
        file_handle = $fopen("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/output/Testbench_output.txt", "w");
        if (file_handle == 0) begin
            $display("Error: Could not open file for writing!");
            $finish;
        end

        clk <= 1'b0;
        rst_n <= 1'b0;
        i_valid <= 1'b0;

        start <= 1'b0;

        alpha_in <= 'h0;  // Example: 0.5 in IEEE 754
        gaussian_color <= 'h0;  // Example: RGB = 1.0
        gaussian_depth <= 'h0;  // Example: 0.5
        last_input <= 'h0;
        gaussian_id_in <= 'h0;

        stall <= 1'b0;
        counter <= 0;
        data_in <= 1'b0;
        @(posedge clk);
        rst_n <= 1'b1;
        start <= 1'b1;
        data_in <= 1'b1;


        @(posedge clk);
        start <= 1'b0;


    end


    always @(posedge clk) begin

            // 데이터만 계속 준다라는거고 
            if (!pixel_valid_out && data_in) begin
                    if (clk_cnt == 20) begin
                        stall <= 1'b1;
                    end

                    if (clk_cnt == 23) begin
                        stall <= 1'b0;
                    end


                    if (stall) begin
                        stall_cnt <= stall_cnt + 'd1;
                    end

                    else if (!stall) begin
                    gaussian_color <= {mem_gaussian_color[3 * counter + 0], mem_gaussian_color[3 * counter + 1], mem_gaussian_color[3 * counter + 2]};
                    gaussian_depth <= mem_gaussian_depth[counter];

                    alpha_in <= mem_alpha[counter];
                    i_valid <= (mem_i_valid[counter] && !mem_skip[counter]);
                    gaussian_id_in <= mem_gaussian_id[counter];
                    last_input <= mem_last_input[counter];
                    counter <= counter + 1;
            end
        end

            else if (pixel_valid_out) begin
                i_valid <= 1'b0;  // Stop sending inputs
                data_in <= 1'b0;
                repeat (5) @(posedge clk);
                $fclose(file_handle);  // Close the file
                $finish;  // End simulation
            end
        end

endmodule
