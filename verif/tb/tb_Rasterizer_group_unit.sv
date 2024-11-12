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

module tb_Rasterizer_group_unit #(BLOCK_SIZE = 16, exponent_bit = 8, precision = 32 , mantissa_bit = 23, gaussian_inputs = 4, num_pixels = 16) ();

    // Input

    reg clk;
    reg rst_n;

    reg i_valid [gaussian_inputs * num_pixels - 1:0];

    reg [11:0] W;
    reg [11:0] H;

    reg start [num_pixels-1:0];

    reg [(3 * precision) -1:0] dL_dpixel [num_pixels-1:0]; //fp32 | R | G | B |
    reg [precision -1:0] dL_dpixel_depth [num_pixels-1:0]; //fp32
    reg [precision - 1:0] T_first [num_pixels-1:0];

    reg [15:0] block_id ; // block index x at [0] y at [1]
    reg [(2 * $clog2(BLOCK_SIZE) - 1): 0] pixel_id [num_pixels-1:0];
    
    reg stall_backpressure [num_pixels-1:0];


    reg [(2 * precision) -1:0] mean2D [gaussian_inputs * num_pixels - 1:0]; //fp32 | X | Y | 
    reg [(4 * precision) -1:0] conic_opacity [gaussian_inputs * num_pixels - 1:0]; // fp32 | X | Y | Z | W |

    reg [31:0] gaussian_id_in [gaussian_inputs * num_pixels - 1:0];
    reg [(3 * precision) -1:0] gaussian_color [gaussian_inputs * num_pixels - 1:0]; //fp32 | R | G | B |
    reg [precision -1:0] gaussian_depth [gaussian_inputs * num_pixels - 1:0]; //fp32


    //Output 

    reg [(3 * precision) -1:0] dL_dcolor_out[num_pixels-1:0]; // fp32 | R | G | B |
    reg [precision -1:0] dL_ddepth_out[num_pixels-1:0]; // fp32
    reg [precision -1:0] dL_dopacity_out[num_pixels-1:0]; // fp32 
    reg [(2 * precision) -1:0] dL_dmean2D_out[num_pixels-1:0]; // fp32 | X | Y |
    reg [(4 * precision) -1:0] dL_dconic_out[num_pixels-1:0]; // fp32 | X | Y | Z | W |
    reg [31:0] gaussian_id_out [num_pixels-1:0];
    
    reg gradient_valid_out [num_pixels-1:0];
    reg stall_to_controller [num_pixels-1:0];
    
    parameter N_TEST = 1024;
    integer stall_cnt = 0;

    reg data_in;
    reg done_for_work;


    // Input Mem
    reg [precision -1:0] mem_conic_opacity [num_pixels-1:0][4 * N_TEST - 1 :0];
    reg [precision -1:0] mem_gaussian_color [num_pixels-1:0][3 * N_TEST -1 : 0];
    reg [precision -1:0] mem_gaussian_depth [num_pixels-1:0][N_TEST - 1:0];
    reg [precision -1:0] mem_mean2D [num_pixels-1:0][2 * N_TEST -1 :0];

    reg [precision -1:0] mem_T_in [num_pixels-1:0][0:0];
    reg [precision -1:0] mem_dL_dpixel [num_pixels-1:0][2:0];
    reg [precision -1:0] mem_dL_dpixel_depth [num_pixels-1:0][0:0];


    reg [31:0] mem_gaussian_id_in [num_pixels-1:0][N_TEST -1 :0];
    reg [31:0] mem_gaussian_id_out [num_pixels-1:0][N_TEST -1 :0];


    reg mem_i_valid [num_pixels-1:0][N_TEST - 1:0];
    
    reg [7:0] mem_block_id [1:0];
    reg [(2 * $clog2(BLOCK_SIZE) - 1):0] mem_pixel_id [0:0];

    integer j;
    integer i;

    // Output Mem
    // reg [precision -1:0] mem_dL_dcolor [3 * N_TEST -1 :0];
    // reg [precision -1:0] mem_dL_ddepth [N_TEST - 1:0];
    // reg [precision -1:0] mem_dL_dopacity [N_TEST - 1:0];
    // reg [precision -1:0] mem_dL_dmean2D [2 * N_TEST - 1:0];
    // reg [precision -1:0] mem_dL_dconic [4 * N_TEST - 1:0];
    // reg mem_skip [N_TEST -1 :0];
    
    integer counter [num_pixels-1:0];
    integer file_handle;
    // integer file_dL_dcolor;
    // integer file_dL_ddepth;
    // integer file_dL_dopacity;
    // integer file_dL_dmean2D;
    // integer file_dL_dconic;

    // reg [(3 * precision) -1:0] ref_dL_dcolor;
    // reg [precision -1:0] ref_dL_ddepth;
    // reg [precision -1:0] ref_dL_dopacity;
    // reg [(2 * precision) -1:0] ref_dL_dmean2D;
    // reg [(4 * precision) -1:0] ref_dL_dconic;
    // reg ref_valid;

    localparam stage1_latency = 7;
    localparam stage2_latency = 9;
    localparam arbiter_latency = 1;
    integer latency = stage1_latency + stage2_latency + arbiter_latency;

    integer file_size = 72;


    initial begin
        $fsdbDumpfile("./output/dump.fsdb");
        $fsdbDumpvars(0, tb_Rasterizer_group_unit, "+all");
    end

    // Instantiate the DUT (Device Under Test)
    Rasterizer_group_unit #( 
        .BLOCK_SIZE(BLOCK_SIZE), 
        .exponent_bit(exponent_bit), 
        .mantissa_bit(mantissa_bit), 
        .precision(precision), 
        .gaussian_inputs(gaussian_inputs), 
        .num_pixels(num_pixels)) 
    uut  (
        .clk(clk),
        .rst_n(rst_n),

        .W(W),
        .H(H),

        .i_valid(i_valid),

        .start(start),
        .dL_dpixel(dL_dpixel),
        .dL_dpixel_depth(dL_dpixel_depth),
        .T_first(T_first),
        
        .block_id(block_id),
        .pixel_id(pixel_id),

        .stall_backpressure(stall_backpressure),
        
        .mean2D(mean2D),
        .conic_opacity(conic_opacity),

        .gaussian_id_in(gaussian_id_in),
        .gaussian_color(gaussian_color),
        .gaussian_depth(gaussian_depth),

        .gaussian_id_out(gaussian_id_out),
        .dL_dmean2D_out(dL_dmean2D_out),
        .dL_dconic_out(dL_dconic_out),
        .dL_dopacity_out(dL_dopacity_out),
        .dL_dcolor_out(dL_dcolor_out),
        .dL_ddepth_out(dL_ddepth_out),

        .gradient_valid_out(gradient_valid_out),
        .stall_to_controller(stall_to_controller)
    );


    // Initial reg example
    // uut.T0 = 32'h1;
    always begin
        #5 clk = !clk;  // Toggle clock every half period
    end

    integer clk_cnt = 0;

    always @(posedge clk) begin
        clk_cnt <= clk_cnt + 1;
        if (clk_cnt == 300) $finish;
    end


    initial begin

        //for FP 32
        if (precision == 32 && mantissa_bit == 23) begin
            for (int i = 0; i < num_pixels; i++) begin
                string skip_file, conic_file, gid_in_file, gid_out_file, gcolor_file, gdepth_file, mean2D_file, T_in_file, dL_dpixel_file, dL_dpixel_depth_file, pixel_id_file, i_valid_file;
                // skip_file = $sformatf("../verif/hex/skip_%0d.hex", i);
                conic_file = $sformatf("./verif/hex/pixel_group/rgbd_dataset_freiburg1_desk_fp32/conic_opacity_%0d.hex", i);
                gid_in_file = $sformatf("./verif/hex/pixel_group/rgbd_dataset_freiburg1_desk_fp32/gaussian_id_in_%0d.hex", i);
                gid_out_file = $sformatf("./verif/hex/pixel_group/rgbd_dataset_freiburg1_desk_fp32/gaussian_id_out_%0d.hex", i);
                gcolor_file = $sformatf("./verif/hex/pixel_group/rgbd_dataset_freiburg1_desk_fp32/gaussian_color_%0d.hex", i);
                gdepth_file = $sformatf("./verif/hex/pixel_group/rgbd_dataset_freiburg1_desk_fp32/gaussian_depth_%0d.hex", i);
                mean2D_file = $sformatf("./verif/hex/pixel_group/rgbd_dataset_freiburg1_desk_fp32/mean2D_%0d.hex", i);
                T_in_file = $sformatf("./verif/hex/pixel_group/rgbd_dataset_freiburg1_desk_fp32/T_in_%0d.hex", i);

                dL_dpixel_file = $sformatf("./verif/hex/pixel_group/rgbd_dataset_freiburg1_desk_fp32/dL_dpixel_%0d.hex", i);
                dL_dpixel_depth_file = $sformatf("./verif/hex/pixel_group/rgbd_dataset_freiburg1_desk_fp32/dL_dpixel_depth_%0d.hex", i);
                // pixel_id_file = $sformatf("./verif/hex/pixel_group/rgbd_dataset_freiburg1_desk_fp32/pixel_id_%0d.hex", i);
                i_valid_file = $sformatf("./verif/hex/pixel_group/rgbd_dataset_freiburg1_desk_fp32/i_valid_%0d.hex", i);



                $readmemh(conic_file, mem_conic_opacity[i]);
                $readmemh(gid_in_file, mem_gaussian_id_in[i]);
                $readmemh(gid_out_file, mem_gaussian_id_out[i]);
                $readmemh(gcolor_file, mem_gaussian_color[i]);
                $readmemh(gdepth_file, mem_gaussian_depth[i]);
                $readmemh(mean2D_file, mem_mean2D[i]);
                $readmemh(T_in_file, mem_T_in[i]);
                $readmemh(dL_dpixel_file, mem_dL_dpixel[i]);
                $readmemh(dL_dpixel_depth_file, mem_dL_dpixel_depth[i]);
                // $readmemh(pixel_id_file, mem_pixel_id);
                $readmemh(i_valid_file, mem_i_valid[i]);

            end
            $readmemh("./verif/hex/pixel_group/rgbd_dataset_freiburg1_desk_fp32/pixel_id.hex", mem_pixel_id);
            $readmemh("./verif/hex/pixel_group/rgbd_dataset_freiburg1_desk_fp32/block_id.hex", mem_block_id);
        end

    end


    initial begin

        clk <= 1'b0;
        rst_n <= 1'b0;

        H <= 'd0;
        W <= 'd0;

        for (j = 0 ; j < gaussian_inputs * num_pixels ; j = j + 1) begin
            mean2D[j] <= 'h0;
            conic_opacity[j] <= 'h0;    
            i_valid[j] <= 1'b0;
            gaussian_id_in[j] <= 'h0;
            gaussian_color[j] <= 'h0;
            gaussian_depth[j] <= 'h0;
        end

        for (j = 0 ; j < num_pixels ; j = j + 1) begin
            start[j] <= 1'b0;
            dL_dpixel[j] <= 'h0;
            dL_dpixel_depth[j] <= 'h0;
            T_first[j] <= 'h0;
            pixel_id[j] <= 'h0;
            stall_backpressure[j] <= 1'b0;
            counter[j] <= 0;
        end


        block_id <= 16'h0;
        
        // data_in <= 1'b0;
        done_for_work <= 1'b0;
        data_in <= 1'b0;

        @(posedge clk);

            rst_n <= 1'b1;
            H <= 'd480;
            W <= 'd640;
            data_in <= 1'b1;
            block_id <= {mem_block_id[0], mem_block_id[1]};

            for (j = 0 ; j < num_pixels ; j = j + 1) begin
                T_first[j] <= mem_T_in[j][0];
                dL_dpixel[j] <= {mem_dL_dpixel[j][0], mem_dL_dpixel[j][1], mem_dL_dpixel[j][2]};
                dL_dpixel_depth[j] <= mem_dL_dpixel_depth[j][0];
                pixel_id[j] <= mem_pixel_id[0] + j;
                
                start[j] <= 1'b1;
            end
        

        @(posedge clk);

            
            block_id <= 'h0;
            for (j = 0 ; j < num_pixels ; j = j + 1) begin
                T_first[j] <= 'h0;
                dL_dpixel[j] <= 'h0;
                dL_dpixel_depth[j] <= 'h0;
                pixel_id[j] <= 'h0;
                
                start[j] <= 1'b0;
            end

    end



    always @(posedge clk) begin

        if (data_in) begin

            // if (!stall_backpressure) begin // stall backpressure는 pixel group unit 에서는 얘가 주는 거임

                    for (int j = 0; j < num_pixels; j = j + 1) begin
                        if (!stall_to_controller[j]) begin
                            
                            for (int i = 0; i < gaussian_inputs; i = i + 1) begin

                                conic_opacity[j * gaussian_inputs + i] <= {mem_conic_opacity[j][4 * (counter[j] + i) + 0], mem_conic_opacity[j][4 * (counter[j] + i) + 1], mem_conic_opacity[j][4 * (counter[j] + i) + 2], mem_conic_opacity[j][4 * (counter[j] + i) + 3]};
                                mean2D[j * gaussian_inputs + i] <= {mem_mean2D[j][2 * (counter[j] + i) + 0], mem_mean2D[j][2 * (counter[j] + i) + 1]};
                                gaussian_id_in[j * gaussian_inputs + i] <= mem_gaussian_id_in[j][counter[j] + i];
                                i_valid[j * gaussian_inputs + i] <= mem_i_valid[j][counter[j] + i];
                                gaussian_color[j * gaussian_inputs + i] <= {mem_gaussian_color[j][3 * (counter[j] + i) + 0], mem_gaussian_color[j][3 * (counter[j] + i) + 1], mem_gaussian_color[j][3 * (counter[j] + i) + 2]};
                                gaussian_depth[j * gaussian_inputs + i] <= mem_gaussian_depth[j][counter[j] + i];

                            end

                            // conic_opacity[j] <= {mem_conic_opacity[4 * (counter + j) + 0], mem_conic_opacity[4 * (counter + j) + 1], mem_conic_opacity[4 * (counter + j) + 2], mem_conic_opacity[4 * (counter + j) + 3]};
                            // mean2D[j] <= {mem_mean2D[2 * (counter + j) + 0], mem_mean2D[2* (counter + j) + 1]};
                            // gaussian_id_in[j] <= mem_gaussian_id_in[counter + j];
                            // i_valid[j] <= mem_i_valid[counter + j];
                            // gaussian_color[j] <= {mem_gaussian_color[3 * (counter + j) + 0], mem_gaussian_color[3 * (counter + j) + 1], mem_gaussian_color[3 * (counter + j) + 2]};
                            // gaussian_depth[j] <= mem_gaussian_depth[counter + j];
                            counter[j] <= counter[j] + gaussian_inputs;
                        end
                    end
                    
                end

            //     if (!stall_to_controller) begin
                    
            //         for (int j = 0; j < gaussian_inputs; j = j + 1) begin
            //             conic_opacity[j] <= {mem_conic_opacity[4 * (counter + j) + 0], mem_conic_opacity[4 * (counter + j) + 1], mem_conic_opacity[4 * (counter + j) + 2], mem_conic_opacity[4 * (counter + j) + 3]};
            //             mean2D[j] <= {mem_mean2D[2 * (counter + j) + 0], mem_mean2D[2* (counter + j) + 1]};
            //             gaussian_id_in[j] <= mem_gaussian_id_in[counter + j];
            //             i_valid[j] <= mem_i_valid[counter + j];
            //             gaussian_color[j] <= {mem_gaussian_color[3 * (counter + j) + 0], mem_gaussian_color[3 * (counter + j) + 1], mem_gaussian_color[3 * (counter + j) + 2]};
            //             gaussian_depth[j] <= mem_gaussian_depth[counter + j];
            //         end
            //         counter <= counter + gaussian_inputs;
            //     end
            // end

        // end

        // else if (counter > file_size) begin
        //     for (int j = 0 ; j < gaussian_inputs ; j = j + 1 ) begin
        //         i_valid[j] <= 1'b0;
        //     end
        //     data_in <= 1'b0;

        //     repeat (60) @(posedge clk);
            
        //     done_for_work <= 1'b1;

        //     $fclose(file_handle); // Close the file when simulation is done
        //     $finish;
        // end

    end

    // always @ (posedge clk) begin
    //     if (!done_for_work) begin
    //         if (gradient_valid_out) begin
    //             $fwrite(file_handle, "%h\n", gaussian_id_out);
    //             $fwrite(file_dL_dcolor, "%h %h %h\n", dL_dcolor_out[3*precision-1:2*precision], dL_dcolor_out[2*precision-1:precision], dL_dcolor_out[precision-1:0]);
    //             $fwrite(file_dL_ddepth, "%h\n", dL_ddepth_out);
    //             $fwrite(file_dL_dopacity, "%h\n", dL_dopacity_out);
    //             $fwrite(file_dL_dmean2D, "%h %h\n", dL_dmean2D_out[2*precision-1:precision], dL_dmean2D_out[precision-1:0]);
    //             $fwrite(file_dL_dconic, "%h %h %h %h\n", dL_dconic_out[4*precision-1:3*precision], dL_dconic_out[3*precision-1:2*precision], dL_dconic_out[2*precision-1:precision], dL_dconic_out[precision-1:0]);
    //         end

    //     end
    // end

endmodule
