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

module tb_skip_unit 

    #(
        parameter BLOCK_SIZE = 16, 
        parameter exponent_bit = 8, 
        parameter mantissa_bit= 23, 
        parameter precision = 32,
        parameter gaussian_inputs = 4,
        parameter GID_bit = 24
    )
    ();
    
    //input
    reg clk, rst_n;

    reg [15:0] block_id;
    reg i_valid [gaussian_inputs-1:0];

    reg [( 2 * precision )-1:0] mean2D [gaussian_inputs-1:0];
    reg [(4 * precision) - 1:0] conic_opacity [gaussian_inputs-1:0];
    reg [(2 * $clog2(BLOCK_SIZE) - 1):0] pixel_id;
    reg [GID_bit-1:0] gaussian_id [gaussian_inputs-1:0];
    reg [precision-1:0] gaussian_depth [gaussian_inputs-1:0];
    reg [(3 * precision) - 1:0] gaussian_color [gaussian_inputs-1:0];

    reg last_input [gaussian_inputs-1:0];

    wire skip_out [gaussian_inputs-1:0];
    wire [precision-1:0] alpha_out [gaussian_inputs-1:0];

    wire [precision-1:0] G_out [gaussian_inputs-1:0];
    wire [( 2 * precision )-1:0] d_out [gaussian_inputs-1:0];

    wire skip_and_alpha_done_out [gaussian_inputs-1:0];

    wire [(4 * precision) - 1:0] conic_opacity_out [gaussian_inputs-1:0];

    wire last_input_done [gaussian_inputs-1:0];
    wire [GID_bit - 1:0] gaussian_id_out [gaussian_inputs-1:0];
    wire [(3 * precision) - 1:0] gaussian_color_out [gaussian_inputs-1:0];
    wire [precision - 1:0] gaussian_depth_out [gaussian_inputs-1:0];

    wire grant_from_arbiter [gaussian_inputs-1:0];

    localparam latency = 9;

    integer file_size = 85;

    parameter N_TEST = 1024;

    reg start;
    reg started;

    wire stall;
    integer reference_index ;

    // Input Mem
    reg [precision -1:0] mem_conic_opacity [4 * N_TEST - 1 :0];
    reg [precision -1:0] mem_gaussian_color [3 * N_TEST -1 : 0];
    reg [precision -1:0] mem_gaussian_depth [N_TEST - 1:0];
    // reg [precision -1:0] mem_T_in [N_TEST -1 :0];
    
    // reg [precision -1:0] mem_dL_dpixel [3 * N_TEST - 1:0];
    // reg [precision -1:0] mem_dL_dpixel_depth [N_TEST-1:0];
    reg [precision -1:0] mem_d [2 * N_TEST -1 :0];
    reg [precision -1:0] mem_G [N_TEST -1 :0];

    reg [precision -1:0] mem_alpha [N_TEST -1 :0];
    reg mem_skip [N_TEST -1 :0];
    reg [precision -1:0] mem_mean2D [2 * N_TEST - 1:0];


    reg [15:0] mem_block_id [1:0];
    reg [(2 * $clog2(BLOCK_SIZE) - 1):0] mem_pixel_id [0:0];
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

    reg [precision - 1:0] ref_alpha [gaussian_inputs-1:0];
    reg [precision - 1:0] ref_G [gaussian_inputs-1:0];
    reg [(2 * precision) - 1:0] ref_d [gaussian_inputs-1:0];
    reg ref_skip [gaussian_inputs-1:0];

    initial begin
        $fsdbDumpfile("../output_shared_submodules/shared_submodules_dump.fsdb");
        $fsdbDumpvars(0, tb_skip_unit, "+all");
    end

    // Instantiate the DUT (Device Under Test)
    Backward_skip_unit #( .BLOCK_SIZE(BLOCK_SIZE), .exponent_bit(exponent_bit), .mantissa_bit(mantissa_bit), .precision(precision), .gaussian_inputs(gaussian_inputs)) 
    skip_unit_inst (
        .clk(clk),
        .rst_n(rst_n),

        .start(start),
        .block_id(block_id),

        .mean2D(mean2D),
        .conic_opacity(conic_opacity),
        .pixel_id(pixel_id),

        .gaussian_id_in(gaussian_id),
        .gaussian_color_in(gaussian_color),
        .gaussian_depth_in(gaussian_depth),

        .i_valid(i_valid),
        .stall(stall),

        .last_input(last_input),

        .skip_out(skip_out),
        
        .G_out(G_out),
        .d_out(d_out),

        .alpha_out(alpha_out),        
        .conic_opacity_out(conic_opacity_out),

        .gaussian_id_out(gaussian_id_out),
        .gaussian_color_out(gaussian_color_out),
        .gaussian_depth_out(gaussian_depth_out),

        .skip_and_alpha_done_out(skip_and_alpha_done_out),

        .last_input_done(last_input_done),

        .grant_from_arbiter(grant_from_arbiter)
    );


    initial begin
        //for FP 16
        if (precision == 16 && mantissa_bit == 7) begin
            $readmemh("../HEX_TB/hex/fp16/conic_opacity.hex", mem_conic_opacity);
            $readmemh("../HEX_TB/hex/fp16/d.hex", mem_d);
            $readmemh("../HEX_TB/hex/fp16/G.hex", mem_G);
            $readmemh("../HEX_TB/hex/fp16/alpha.hex", mem_alpha);
            $readmemh("../HEX_TB/hex/fp16/skip.hex", mem_skip);
            $readmemh("../HEX_TB/hex/fp16/mean2D.hex", mem_mean2D);        

            $readmemh("../HEX_TB/hex/fp16/pixel_id.hex", mem_pixel_id);        
            $readmemh("../HEX_TB/hex/fp16/block_id.hex", mem_block_id);    
        end

        //for FP 32
        if (precision == 32 && mantissa_bit == 23) begin
            $readmemh("../HEX_TB/hex/fp32/conic_opacity.hex", mem_conic_opacity);

            $readmemh("../HEX_TB/hex/fp32/gaussian_color.hex", mem_gaussian_color);
            $readmemh("../HEX_TB/hex/fp32/gaussian_depth.hex", mem_gaussian_depth);
            // $readmemh("../HEX_TB/hex/fp24/gaussian_id.hex", mem_gaussian_id);
            $readmemh("../HEX_TB/hex/fp32/d.hex", mem_d);
            $readmemh("../HEX_TB/hex/fp32/G.hex", mem_G);            
            $readmemh("../HEX_TB/hex/fp32/alpha.hex", mem_alpha);
            $readmemh("../HEX_TB/hex/fp32/skip.hex", mem_skip);
            $readmemh("../HEX_TB/hex/fp32/mean2D.hex", mem_mean2D);

            $readmemh("../HEX_TB/hex/fp32/pixel_id.hex", mem_pixel_id);        
            $readmemh("../HEX_TB/hex/fp32/block_id.hex", mem_block_id);        
        end

        //for FP 24
        if (precision == 24 && mantissa_bit == 15) begin
            $readmemh("../HEX_TB/hex/fp24/conic_opacity.hex", mem_conic_opacity);
            $readmemh("../HEX_TB/hex/fp24/gaussian_color.hex", mem_gaussian_color);
            $readmemh("../HEX_TB/hex/fp24/gaussian_depth.hex", mem_gaussian_depth);
            // $readmemh("../HEX_TB/hex/fp24/gaussian_id.hex", mem_gaussian_id);
            $readmemh("../HEX_TB/hex/fp24/d.hex", mem_d);
            $readmemh("../HEX_TB/hex/fp24/G.hex", mem_G);
            $readmemh("../HEX_TB/hex/fp24/alpha.hex", mem_alpha);
            $readmemh("../HEX_TB/hex/fp24/skip.hex", mem_skip);
            $readmemh("../HEX_TB/hex/fp24/mean2D.hex", mem_mean2D);

            $readmemh("../HEX_TB/hex/fp24/pixel_id.hex", mem_pixel_id);        
            $readmemh("../HEX_TB/hex/fp24/block_id.hex", mem_block_id);        
        end
    end
    

    // Initial reg example
    // uut.T0 = 32'h1;
    always begin
        #5 clk = !clk;  // Toggle clock every half period
    end    

    integer clk_cnt = 0;

    always @(posedge clk) begin
        clk_cnt <= clk_cnt + 1;
        if (clk_cnt == 10000) $finish;
    end


    initial begin
        file_handle = $fopen("../simulation_output/Skip_unit_Testbench_output.txt", "w");
        if (file_handle == 0) begin
            $display("Error: Could not open file for writing!");
            $finish;
        end

        clk <= 1'b0;
        rst_n <= 1'b0;
        block_id <= 'h0;
        

        pixel_id <= 'b0;
        // pixel_id = 8'h00; // 0 , 0

        for (int i=0 ; i < gaussian_inputs ; i++) begin
            i_valid[i] <= 1'b0;
            mean2D[i] <= 'b0;
            conic_opacity[i] <= 'b0;    
            gaussian_id[i] <= 'b0;
            gaussian_depth[i] <= 'b0;
            gaussian_color[i] <= 'b0;

            ref_G[i] <= 'h0;
            ref_d[i] <= 'h0;
            ref_alpha[i] <= 'h0;
            ref_skip[i] <= 'h0;
            last_input[i] <= 1'b0;

        end
        counter <= 0;
        start <= 0;
        started <= 1'b0;

        @(posedge clk);
        rst_n <= 1'b1;
        // pixel_id <= mem_pixel_id[0];
        // block_id <= {mem_block_id[0], mem_block_id[1]};
        pixel_id <= 'd200;
        block_id <= 'h0c11;
        start <= 1'b1;
        started <= 1'b1;

        @(posedge clk);
        start <= 1'b0;
        

    end

    always @(posedge clk) begin

        if (counter <= file_size * gaussian_inputs + latency + 1 && started) begin
            // conic_opacity <= {mem_conic_opacity[4 * counter + 0], mem_conic_opacity[4 * counter + 1], mem_conic_opacity[4 * counter + 2], mem_conic_opacity[4 * counter + 3]};
            // // i_valid <= !mem_skip[counter];
            // mean2D <= {mem_mean2D[2* counter + 0], mem_mean2D[2* counter + 1]};
            counter <= counter + gaussian_inputs;

            for (int i = 0 ; i < gaussian_inputs ; i++) begin

                if (counter + i < file_size) begin
                    conic_opacity[i] <= {mem_conic_opacity[4 * (counter + i) + 0], mem_conic_opacity[4 * (counter + i) + 1], mem_conic_opacity[4 * (counter + i) + 2], mem_conic_opacity[4 * (counter + i) + 3]};
                    // i_valid[i] <= !mem_skip[counter + i];
                    i_valid[i] <= 1'b1;
                    mean2D[i] <= {mem_mean2D[2 * (counter + i) + 0], mem_mean2D[2 * (counter + i) + 1]};

                    gaussian_id[i] <= counter + i;
                    gaussian_depth[i] <= mem_gaussian_depth[counter + i];
                    gaussian_color[i] <= {mem_gaussian_color[3 * (counter + i) + 0], mem_gaussian_color[3 * (counter + i) + 1], mem_gaussian_color[3 * (counter + i) + 2]};

                    if (counter + i == file_size - 1) begin
                        last_input[i] <= 1'b1;
                    end
                end

                else begin
                    conic_opacity[i] <= 'h0;
                    i_valid[i] <= 1'b0;
                    mean2D[i] <= 'h0;
                    gaussian_id[i] <= 'h0;
                    gaussian_depth[i] <= 'h0;
                    gaussian_color[i] <= 'h0;
                end
            end
        end

        else if (counter >= latency + file_size * gaussian_inputs + 2) begin
            for (int i = 0; i < gaussian_inputs; i++) begin
                i_valid[i] <= 1'b0;
            end
            $fclose(file_handle); // Close the file when simulation is done
            $finish;
        end
    end


    always @ (posedge clk) begin

            if (counter >= latency * gaussian_inputs) begin

                for (int i = 0; i < gaussian_inputs; i++) begin
                    ref_skip[i] <= mem_skip[reference_index + i ];
                    ref_d[i] <= {mem_d[2 * (reference_index + i) + 0], mem_d[2 * (reference_index + i) +1]};
                    ref_G[i] <= mem_G[reference_index + i];
                    ref_alpha[i] <= mem_alpha[reference_index + i];
                


                if ( // 둘다 11인데 값이 다르거나, 둘의 valid 값이 다른경우
                    skip_and_alpha_done_out[i] &&
                    (((!ref_skip[i] && !skip_out[i]) && (alpha_out[i] != ref_alpha[i] || G_out[i] != ref_G[i] || d_out[i] != ref_d[i]))
                    || ((ref_skip[i] && skip_out[i]) != (ref_skip[i] || skip_out[i]))) 
                ) begin
                        // Write comparison results to the text file
                        $fwrite(file_handle, "##############################################################################################################\n");
                        $fwrite(file_handle, "At clk cnt %0d: counter %0d i : %0d, skip : %h ref skip %h\n\n", clk_cnt, counter, i, skip_out[i], ref_skip[i]);
                        $fwrite(file_handle, "alpha : alpha = %0d, alpha_ref = %0d, difference = %0d\n", alpha_out[i][(precision)-1: 0], ref_alpha[i][(precision)-1: 0], $signed(alpha_out[i][(precision)-1: 0]) - $signed(ref_alpha[i][(precision)-1: 0]));
                        $fwrite(file_handle, "G : G = %0d, G_ref = %0d, difference = %0d\n", G_out[i][(precision)-1: 0], ref_G[i][(precision)-1: 0], $signed(G_out[i][(precision)-1: 0]) - $signed(ref_G[i][(precision)-1: 0]));
                        $fwrite(file_handle, "d X: d.x = %0d, d.x_ref = %0d, difference = %0d\n", d_out[i][(2*precision)-1: precision], ref_d[i][(2*precision)-1: precision], $signed(d_out[i][(2*precision)-1: precision]) - $signed(ref_d[i][(2*precision)-1: precision]));
                        $fwrite(file_handle, "d Y: d.y = %0d, d.y_ref = %0d, difference = %0d\n", d_out[i][(precision)-1: 0], ref_d[i][(precision)-1: 0], $signed(d_out[i][(precision)-1: 0]) - $signed(ref_d[i][(precision)-1: 0]));
                        $fwrite(file_handle, "##############################################################################################################\n\n");
                    end
                end
            end
    end

    always @ (posedge clk) begin
        for (int i = 0; i < gaussian_inputs; i++) begin
            if (last_input_done[i]) begin
                $fclose(file_handle);
                $finish;
            end
        end
    end

    assign stall = 1'b0;
    assign reference_index = counter - (latency * gaussian_inputs);
    endmodule
