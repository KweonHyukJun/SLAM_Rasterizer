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

module tb_FIFO #(
    
    parameter FIFO_depth = 151, 

    parameter precision = 32,
    parameter mantissa_bit = 23,

    parameter input_data_width = 128,
    parameter output_data_width = 32


    ) ();
    
    // input
    reg clk, rst_n;

    reg [input_data_width - 1 : 0] write_data_in;
    reg write_valid_in;
    reg read_valid_in;

    // output
    reg [output_data_width - 1 : 0] read_data_out;
    reg full_out;
    reg empty_out;
    reg valid_out;

    integer file_size = 150;
    integer inputs = 1;
    integer latency = 1;
    integer test_latency = 10;
    
    integer i = 0;
    integer j = 0;

    parameter N_TEST = 1024;

    reg start;
    reg [precision * 3 - 1:0] gaussian_color ;
    reg [precision - 1:0] gaussian_depth ;

    // Input Mem
    reg [precision -1:0] mem_conic_opacity [4 * N_TEST - 1 :0];

    reg [precision -1:0] mem_gaussian_color [3 * N_TEST -1 : 0];
    reg [precision -1:0] mem_gaussian_depth [N_TEST - 1:0];
    // reg [precision -1:0] mem_T_in [N_TEST -1 :0];
    
    // reg [precision -1:0] mem_dL_dpixel [3 * N_TEST - 1:0];
    // reg [precision -1:0] mem_dL_dpixel_depth [N_TEST-1:0];
    // reg [precision -1:0] mem_d [2 * N_TEST -1 :0];
    // reg [precision -1:0] mem_G [N_TEST -1 :0];

    // reg [precision -1:0] mem_alpha [N_TEST -1 :0];
    reg mem_skip [N_TEST -1 :0];
    // reg [precision -1:0] mem_mean2D [2 * N_TEST - 1:0];
    
    // reg [31:0] gaussian_id [N_TEST - 1:0];



    // Output Mem
    // reg [precision -1:0] mem_dL_dcolor [3 * N_TEST -1 :0];
    // reg [precision -1:0] mem_dL_ddepth [N_TEST - 1:0];
    // reg [precision -1:0] mem_dL_dopacity [N_TEST - 1:0];
    // reg [precision -1:0] mem_dL_dmean2D [2 * N_TEST - 1:0];
    // reg [precision -1:0] mem_dL_dconic [4 * N_TEST - 1:0];
    
    
    integer counter;

    integer file_handle;

    // reg [(3 * precision) -1:0] ref_dL_dcolor;
    // reg [precision -1:0] ref_dL_ddepth;
    // reg [precision -1:0] ref_dL_dopacity;
    // reg [(2 * precision) -1:0] ref_dL_dmean2D;
    // reg [(4 * precision) -1:0] ref_dL_dconic;

    
    // reg [precision - 1:0] ref_alpha;
    // reg [precision - 1:0] ref_G;
    // reg [(2 * precision) - 1:0] ref_d;
    // reg [(4 * precision) - 1:0] ref_conic_opacity;
    reg ref_skip;
    reg [precision - 1:0] ref_gaussian_depth;
    reg [precision-1:0] ref_data;
    

    initial begin
        $fsdbDumpfile("./output/dump.fsdb");
        $fsdbDumpvars(0, tb_FIFO, "+all");
    end

    // Instantiate the DUT (Device Under Test)
    FIFO #( .FIFO_depth(FIFO_depth), .input_data_width(10 * precision), .output_data_width(10 * precision)) 
    uut (
        .clk(clk),
        .rst_n(rst_n),

        .write_data_in(write_data_in),
        .write_valid_in(write_valid_in),
        .read_valid_in(read_valid_in),

        .read_data_out(read_data_out),

        .full_out(full_out),
        .empty_out(empty_out)
        // ,.valid_out(valid_out)
    );


    initial begin
        //for FP 16
        if (precision == 16 && mantissa_bit == 7) begin
 
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp16/gaussian_color.hex", mem_gaussian_color);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp16/gaussian_depth.hex", mem_gaussian_depth);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp16/skip.hex", mem_skip);
    // $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp16/block_id.hex", mem_block_id);        
        end

        //for FP 32
        if (precision == 32 && mantissa_bit == 23) begin

            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp32/gaussian_color.hex", mem_gaussian_color);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp32/gaussian_depth.hex", mem_gaussian_depth);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp32/skip.hex", mem_skip);
        // $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp32/block_id.hex", mem_block_id);        
        end

        //for FP 24
        if (precision == 24 && mantissa_bit == 15) begin

            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp24/gaussian_color.hex", mem_gaussian_color);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp24/gaussian_depth.hex", mem_gaussian_depth);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp24/skip.hex", mem_skip);

        end
    end
    

    // Initial reg example
    always begin
        #5 clk = !clk;  // Toggle clock every half period
    end    

    integer clk_cnt = 0;

    always @(posedge clk) begin
        clk_cnt <= clk_cnt + 1;
        if (clk_cnt == ((file_size) + 30)) $finish;
    end


    initial begin
        file_handle = $fopen("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/output/Testbench_output.txt", "w");
        if (file_handle == 0) begin
            $display("Error: Could not open file for writing!");
            $finish;
        end

        clk <= 1'b0;
        rst_n <= 1'b0;


        // mem_gaussian_color = 'h0;
        // mem_gaussian_depth = 'h0;
        // mem_skip = 'h0;

        @(posedge clk);
        rst_n <= 1'b1;
    end


    always_ff @ (posedge clk) begin

        if (!rst_n) begin
            counter <= 0;
            write_valid_in <= 1'b0;
            read_valid_in <= 1'b0;
            valid_out <= 1'b0;
            gaussian_color <= 'h0;
            gaussian_depth <= 'h0;
            start <= 1'b0;
            write_data_in <= 'h0;
            

        end
        else begin
            if (!start) begin
                start <= 1'b1;
            end


            if (counter <= file_size + latency + 1 && start) begin
                write_valid_in <= !mem_skip[counter];
                // gaussian_color <= {mem_gaussian_color[3 * counter + 0], mem_gaussian_color[3 * counter + 1], mem_gaussian_color[3 * counter + 2]};
                // gaussian_depth <= mem_gaussian_depth[counter];
                write_data_in <= {mem_gaussian_color[3 * counter + 0], mem_gaussian_color[3 * counter + 1], mem_gaussian_color[3 * counter + 2], mem_gaussian_depth[counter]};
                
                counter <= counter + inputs;

                
                if (counter - test_latency >= 0) begin
                    read_valid_in <= !mem_skip[counter - test_latency];
                    ref_data <= mem_gaussian_depth[counter - test_latency];

                    if (read_valid_in && (read_data_out != ref_data)) begin
                        $fwrite(file_handle, "read valid : %d,  read_data: %d, ref_data : %d\n", read_valid_in, read_data_out,ref_data);
                    end


                end

                else begin
                    read_valid_in <= 1'b0;
                end
            end


            else if (clk_cnt >= file_size + 10) begin
                write_valid_in <= 1'b0;
                read_valid_in <= 1'b0;
                start <= 1'b0;   
                
                $fclose(file_handle); // Close the file when simulation is done
                $finish;
            end
        end

    end


endmodule
