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
`define MAX_CLOCK_COUNT 2000

module tb_Forward_Rasterizer_group_unit #(BLOCK_SIZE = 16, exponent_bit = 8, precision = 32 , mantissa_bit = 23, target_block = 257, gaussian_inputs = 4, num_pixels = 16, GID_bit = 24) ();

    integer max_clock_count = `MAX_CLOCK_COUNT;
    // Input
    reg clk;
    reg rst_n;

    reg i_valid [gaussian_inputs * num_pixels - 1:0];

    reg start [num_pixels-1:0];


    reg [15:0] block_id ; // block index x at [0] y at [1]
    reg [(2 * $clog2(BLOCK_SIZE) - 1): 0] pixel_id [num_pixels-1:0];
    
    reg stall_backpressure [num_pixels-1:0];

    reg last_input [gaussian_inputs * num_pixels - 1:0];

    reg [(2 * precision) -1:0] mean2D [gaussian_inputs * num_pixels - 1:0]; //fp32 | X | Y | 
    reg [(4 * precision) -1:0] conic_opacity [gaussian_inputs * num_pixels - 1:0]; // fp32 | X | Y | Z | W |

    reg [GID_bit-1:0] gaussian_id_in [gaussian_inputs * num_pixels - 1:0];
    reg [(3 * precision) -1:0] gaussian_color [gaussian_inputs * num_pixels - 1:0]; //fp32 | R | G | B |
    reg [precision -1:0] gaussian_depth [gaussian_inputs * num_pixels - 1:0]; //fp32


    //Output 
    wire [GID_bit-1:0] gaussian_id_out [num_pixels-1:0];
    wire pixel_valid_out [num_pixels-1:0];

    wire stall_to_controller [num_pixels-1:0];

    wire [(3 * precision)-1:0] pixel_color_out [num_pixels-1:0];
    wire [precision-1:0] pixel_depth_out [num_pixels-1:0];
    wire [precision-1:0] pixel_opacity_out [num_pixels-1:0];
    wire [precision-1:0] T_first_out [num_pixels-1:0];

    wire [11:0] n_contrib_out [num_pixels-1:0];

    reg controller_ready_to_start;


    reg [11:0] current_n_contrib [num_pixels-1:0];


    // Expected Output
    reg [3 * precision -1:0] expected_color [num_pixels-1:0];
    reg [precision -1:0] expected_depth [num_pixels-1:0];
    reg [precision -1:0] expected_opacity [num_pixels-1:0];


    // Frame size에 따라 바꿔야 함..
    parameter W_BLOCK = 40;
    parameter H_BLOCK = 30;

    // 이거 왜 안되지
    reg [7:0] target_block_x = target_block % W_BLOCK;
    reg [7:0] target_block_y = target_block / W_BLOCK;

    // reg [7:0] target_block_x = 'd20;
    // reg [7:0] target_block_y = 'd15;


    integer stall_cnt = 0;

    reg started_flag [num_pixels-1:0];
    reg all_last_input_done_before;
    reg all_last_input_done;
    

    integer j;
    integer i;

    integer all_done;


    parameter N_GAUSSIANS = 32744;
    parameter DUPLICATE_GAUSSIANS = 182564;
    parameter N_BLOCKS = 1200;
    parameter N_PIXELS = 307200;

    reg [precision -1:0] mem_conic_opacity [(4 * N_GAUSSIANS) -1 : 0];
    reg [precision -1:0] mem_gaussian_color [(3 * N_GAUSSIANS) -1 : 0];
    reg [precision -1:0] mem_gaussian_depth [N_GAUSSIANS -1 : 0];
    reg [precision -1:0] mem_mean2D [(2 * N_GAUSSIANS) -1 : 0];


    

    // reg [16:0] mem_n_contrib [255:0];
    reg [23:0] mem_range [(2 * N_BLOCKS) -1 :0];

    reg [GID_bit-1:0] mem_gaussian_id_in [DUPLICATE_GAUSSIANS -1 : 0];


    integer out_color_file[num_pixels-1:0];
    integer out_depth_file[num_pixels-1:0];
    integer out_opacity_file[num_pixels-1:0];

    initial begin
        $fsdbDumpfile("./output_forward/forward_dump.fsdb");
        $fsdbDumpvars(0, tb_Forward_Rasterizer_group_unit, "+all");
    end

    // Instantiate the DUT (Device Under Test)
    Forward_Rasterizer_group_unit #( 
        .BLOCK_SIZE(BLOCK_SIZE), 
        .exponent_bit(exponent_bit), 
        .mantissa_bit(mantissa_bit), 
        .precision(precision), 
        .gaussian_inputs(gaussian_inputs), 
        .num_pixels(num_pixels),
        .GID_bit(GID_bit)
        ) 
    uut  (
        .clk(clk),
        .rst_n(rst_n),

        .i_valid(i_valid),

        .start(start),
        
        .block_id(block_id),
        .pixel_id(pixel_id),

        .stall_backpressure(stall_backpressure),
        
        .last_input(last_input),
        
        .mean2D(mean2D),
        .conic_opacity(conic_opacity),

        .gaussian_id_in(gaussian_id_in),
        .gaussian_color(gaussian_color),
        .gaussian_depth(gaussian_depth),

        .gaussian_id_out(gaussian_id_out),

        .pixel_valid_out(pixel_valid_out),

        .stall_to_controller(stall_to_controller),

        .pixel_color_out(pixel_color_out),
        .pixel_depth_out(pixel_depth_out),
        .pixel_opacity_out(pixel_opacity_out),
        .T_first_out(T_first_out),

        .n_contrib_out(n_contrib_out)
    );


    // Initial reg example
    // uut.T0 = 32'h1;
    always begin
        #5 clk = !clk;  // Toggle clock every half period
    end

    integer clk_cnt = 0;

    always @(posedge clk) begin
        clk_cnt <= clk_cnt + 1;
        if (clk_cnt == max_clock_count) $finish;
    end


    initial begin
        $readmemh($sformatf("../HEX_TB/hex/Combined/Forward_Test/Forward_Block_and_Frame_rgbd_dataset_freiburg1_desk_15000_fp%0d/conic_opacity.hex", precision), mem_conic_opacity);
        $readmemh($sformatf("../HEX_TB/hex/Combined/Forward_Test/Forward_Block_and_Frame_rgbd_dataset_freiburg1_desk_15000_fp%0d/mean2D.hex", precision), mem_mean2D);

        $readmemh($sformatf("../HEX_TB/hex/Combined/Forward_Test/Forward_Block_and_Frame_rgbd_dataset_freiburg1_desk_15000_fp%0d/gaussian_color.hex", precision), mem_gaussian_color);
        $readmemh($sformatf("../HEX_TB/hex/Combined/Forward_Test/Forward_Block_and_Frame_rgbd_dataset_freiburg1_desk_15000_fp%0d/gaussian_depth.hex", precision), mem_gaussian_depth);

        $readmemh($sformatf("../HEX_TB/hex/Combined/Forward_Test/Forward_Block_and_Frame_rgbd_dataset_freiburg1_desk_15000_fp%0d/point_list.hex", precision), mem_gaussian_id_in);
        // $readmemh($sformatf("../HEX_TB/hex/Combined/Forward_Test/Forward_Block_and_Frame_rgbd_dataset_freiburg1_desk_15000_fp%0d/n_contrib.hex", precision), mem_n_contrib);
        $readmemh($sformatf("../HEX_TB/hex/Combined/Forward_Test/Forward_Block_and_Frame_rgbd_dataset_freiburg1_desk_15000_fp%0d/ranges.hex", precision), mem_range);


        

    end


    initial begin
        
        for (int j = 0; j < num_pixels; j = j + 1) begin
            out_color_file[j] = $fopen($sformatf("./output_forward/color_out_by_testbench_%0d.hex", j), "w");    
            if (out_color_file[j] == 0) $display("Error opening out_color_file[%0d]", j);

            out_depth_file[j] = $fopen($sformatf("./output_forward/depth_out_by_testbench_%0d.hex", j), "w");
            if (out_depth_file[j] == 0) $display("Error opening out_depth_file[%0d]", j);

            out_opacity_file[j] = $fopen($sformatf("./output_forward/opacity_out_by_testbench_%0d.hex", j), "w");
            if (out_opacity_file[j] == 0) $display("Error opening out_opacity_file[%0d]", j);
        end

        clk <= 1'b0;
        rst_n <= 1'b0;

        all_done <= 'd0;

        for (j = 0 ; j < gaussian_inputs * num_pixels ; j = j + 1) begin
            mean2D[j] <= 'h0;
            conic_opacity[j] <= 'h0;    
            i_valid[j] <= 1'b0;
            gaussian_id_in[j] <= 'h0;
            gaussian_color[j] <= 'h0;
            gaussian_depth[j] <= 'h0;
            last_input[j] <= 1'b0;
        end


        for (j = 0 ; j < num_pixels ; j = j + 1) begin
            start[j] <= 1'b0;

            pixel_id[j] <= 'h0;
            stall_backpressure[j] <= 1'b0;
            started_flag[j] <= 1'b0;
            current_n_contrib[j] <= 'h0;
            last_input[j] <= 1'b0;
            
        end

        controller_ready_to_start <= 1'b0;

        block_id <= 'h0;
        
        // data_in <= 1'b0;
        // done_for_work <= 1'b0;
        // data_in <= 1'b0;

        @(posedge clk);
            rst_n <= 1'b1;
        
        @(posedge clk);
            // data_in <= 1'b1;
            block_id <= {target_block_x, target_block_y};

            for (j = 0 ; j < num_pixels ; j = j + 1) begin
                pixel_id[j] <= j;
                start[j] <= 1'b1;
                started_flag[j] <= 1'b1;
            end
        

        @(posedge clk);
            block_id <= 'h0;
            for (j = 0 ; j < num_pixels ; j = j + 1) begin
                start[j] <= 1'b0;
                pixel_id[j] <= 'h0;
                
            end
            controller_ready_to_start <= 1'b1;
    end



    always @ (posedge clk) begin

        // if (!stall_backpressure) begin // stall backpressure는 pixel group unit 에서는 얘가 주는 거임 (컨트롤러 + FIFO 단에서의 stall 신호까지 준다고 생각)

        for (int j = 0; j < num_pixels; j = j + 1) begin

            if (started_flag[j]) begin  
                start[j] <= 1'b0;


                if (!stall_to_controller[j]) begin
                    
                    if (!pixel_valid_out[j]) begin
                        // for (int i = 0; i < gaussian_inputs; i = i + 1) begin
                            // if ( (mem_range[2 * target_block] + current_n_contrib[j] + i) < mem_range[2 * target_block + 1] ) begin

                        // 전체 블락의 Gaussian Range가 + gaussian_input 보다 작은 경우 (다른 블락 레인지를 안넘는경우)
                        if ( (mem_range[2 * target_block] + current_n_contrib[j] + gaussian_inputs) < mem_range[2 * target_block + 1]) begin

                            
                            for (int i = 0; i < gaussian_inputs; i = i + 1) begin

                                gaussian_id_in[j * gaussian_inputs + i] <= mem_gaussian_id_in[mem_range[2 * target_block] + current_n_contrib[j] + i];

                                conic_opacity[j * gaussian_inputs + i] <= {mem_conic_opacity[4 * mem_gaussian_id_in[mem_range[2 * target_block] + current_n_contrib[j] + i]  + 0], mem_conic_opacity[4 * (mem_gaussian_id_in[mem_range[2 * target_block] + current_n_contrib[j] + i] )  + 1], mem_conic_opacity[4 * (mem_gaussian_id_in[mem_range[2 * target_block] + current_n_contrib[j] + i] ) + 2], mem_conic_opacity[4 * (mem_gaussian_id_in[mem_range[2 * target_block] + current_n_contrib[j] + i] )  + 3]};
                                mean2D[j * gaussian_inputs + i] <= {mem_mean2D[2 * (mem_gaussian_id_in[mem_range[2 * target_block] + current_n_contrib[j] + i] )  + 0], mem_mean2D[2 * (mem_gaussian_id_in[mem_range[2 * target_block] + current_n_contrib[j] + i] ) + 1]};
                                gaussian_color[j * gaussian_inputs + i] <= {mem_gaussian_color[3 * (mem_gaussian_id_in[mem_range[2 * target_block] + current_n_contrib[j] + i] ) + 0], mem_gaussian_color[3 * (mem_gaussian_id_in[mem_range[2 * target_block] + current_n_contrib[j] + i] )  + 1], mem_gaussian_color[3 * (mem_gaussian_id_in[mem_range[2 * target_block] + current_n_contrib[j] + i] )  + 2]};
                                gaussian_depth[j * gaussian_inputs + i] <= mem_gaussian_depth[(mem_gaussian_id_in[mem_range[2 * target_block] + current_n_contrib[j] + i] ) ];


                                i_valid[j * gaussian_inputs + i] <= 1'b1;
                                last_input[j * gaussian_inputs + i] <= 1'b0;

                            end

                            current_n_contrib[j] <= current_n_contrib[j] + gaussian_inputs;
                        end

                        // 내 블럭 레인지 값을 넘어가는 경우 && 넘어가려는 경우
                        else begin

                                for (int i = 0; i < gaussian_inputs; i = i + 1) begin

                                    if ( (mem_range[2 * target_block] + current_n_contrib[j] + i) < mem_range[2 * target_block + 1] - 1) begin

                                        gaussian_id_in[j * gaussian_inputs + i] <= mem_gaussian_id_in[mem_range[2 * target_block] + current_n_contrib[j] + i];

                                        conic_opacity[j * gaussian_inputs + i] <= {mem_conic_opacity[4 * (mem_gaussian_id_in[mem_range[2 * target_block] + current_n_contrib[j] + i] )  + 0], mem_conic_opacity[4 * (mem_gaussian_id_in[mem_range[2 * target_block] + current_n_contrib[j] + i] )  + 1], mem_conic_opacity[4 * (mem_gaussian_id_in[mem_range[2 * target_block] + current_n_contrib[j] + i] ) + 2], mem_conic_opacity[4 * (mem_gaussian_id_in[mem_range[2 * target_block] + current_n_contrib[j] + i] )  + 3]};
                                        mean2D[j * gaussian_inputs + i] <= {mem_mean2D[2 * (mem_gaussian_id_in[mem_range[2 * target_block] + current_n_contrib[j] + i] ) + 0], mem_mean2D[2 * (mem_gaussian_id_in[mem_range[2 * target_block] + current_n_contrib[j] + i] ) + 1]};

                                        gaussian_color[j * gaussian_inputs + i] <= {mem_gaussian_color[3 * (mem_gaussian_id_in[mem_range[2 * target_block] + current_n_contrib[j] + i] ) + 0], mem_gaussian_color[3 * (mem_gaussian_id_in[mem_range[2 * target_block] + current_n_contrib[j] + i] ) + 1], mem_gaussian_color[3 * (mem_gaussian_id_in[mem_range[2 * target_block] + current_n_contrib[j] + i] ) + 2]};
                                        gaussian_depth[j * gaussian_inputs + i] <= mem_gaussian_depth[(mem_gaussian_id_in[mem_range[2 * target_block] + current_n_contrib[j] + i] ) ];
                                        i_valid[j * gaussian_inputs + i] <= 1'b1;
                                        last_input[j * gaussian_inputs + i] <= 1'b0;

                                    end                                

                                    else if ( (mem_range[2 * target_block] + current_n_contrib[j] + i) ==  mem_range[2 * target_block + 1] - 1) begin

                                        gaussian_id_in[j * gaussian_inputs + i] <= mem_gaussian_id_in[mem_range[2 * target_block] + current_n_contrib[j] + i];

                                        conic_opacity[j * gaussian_inputs + i] <= {mem_conic_opacity[4 * (mem_gaussian_id_in[mem_range[2 * target_block] + current_n_contrib[j] + i] )  + 0], mem_conic_opacity[4 * (mem_gaussian_id_in[mem_range[2 * target_block] + current_n_contrib[j] + i] )  + 1], mem_conic_opacity[4 * (mem_gaussian_id_in[mem_range[2 * target_block] + current_n_contrib[j] + i] ) + 2], mem_conic_opacity[4 * (mem_gaussian_id_in[mem_range[2 * target_block] + current_n_contrib[j] + i] )  + 3]};
                                        mean2D[j * gaussian_inputs + i] <= {mem_mean2D[2 * (mem_gaussian_id_in[mem_range[2 * target_block] + current_n_contrib[j] + i] )  + 0], mem_mean2D[2 * (mem_gaussian_id_in[mem_range[2 * target_block] + current_n_contrib[j] + i] )  + 1]};

                                        gaussian_color[j * gaussian_inputs + i] <= {mem_gaussian_color[3 * (mem_gaussian_id_in[mem_range[2 * target_block] + current_n_contrib[j] + i] )  + 0], mem_gaussian_color[3 * (mem_gaussian_id_in[mem_range[2 * target_block] + current_n_contrib[j] + i] )  + 1], mem_gaussian_color[3 * (mem_gaussian_id_in[mem_range[2 * target_block] + current_n_contrib[j] + i] )  + 2]};
                                        gaussian_depth[j * gaussian_inputs + i] <= mem_gaussian_depth[(mem_gaussian_id_in[mem_range[2 * target_block] + current_n_contrib[j] + i] ) ];
                                        i_valid[j * gaussian_inputs + i] <= 1'b1;
                                        last_input[j * gaussian_inputs + i] <= 1'b1;
                                        current_n_contrib[j] <= current_n_contrib[j] + i + 1;

                                    end

                                    else begin
                                        gaussian_id_in[j * gaussian_inputs + i] <= 'h0;
                                        conic_opacity[j * gaussian_inputs + i] <= 'h0;
                                        mean2D[j * gaussian_inputs + i] <= 'h0;
                                        gaussian_id_in[j * gaussian_inputs + i] <= 'h0;
                                        i_valid[j * gaussian_inputs + i] <= 1'b0;
                                        gaussian_color[j * gaussian_inputs + i] <= 'h0;
                                        gaussian_depth[j * gaussian_inputs + i] <= 'h0;
                                        last_input[j * gaussian_inputs + i] <= 1'b0;

                                    end
                            end
                        end

                    end

                        // current_n_contrib[j] <= current_n_contrib[j] + gaussian_inputs;
                end

                // else begin
                    
                //     for (int i = 0; i < gaussian_inputs; i = i + 1) begin

                //         conic_opacity[j * gaussian_inputs + i] <= 'h0;
                //         mean2D[j * gaussian_inputs + i] <= 'h0;
                //         gaussian_id_in[j * gaussian_inputs + i] <= 'h0;
                //         i_valid[j * gaussian_inputs + i] <= 1'b0;
                //         gaussian_color[j * gaussian_inputs + i] <= 'h0;
                //         gaussian_depth[j * gaussian_inputs + i] <= 'h0;
                //         last_input[j * gaussian_inputs + i] <= 1'b0;
                //     end
                // end

                if (pixel_valid_out[j]) begin
                    started_flag[j] <= 1'b0;
                end


            end


            // end
            else begin

                if (pixel_valid_out[j] && start[j]) begin
                    started_flag[j] <= 1'b1;
                end
            end

        end
    end


    always @ (posedge clk) begin
        if (all_last_input_done_before && controller_ready_to_start) begin
            for (int j = 0; j < num_pixels; j = j + 1) begin
                start[j] <= 1'b1;
                    
                current_n_contrib[j] <= 0;

                block_id <= {target_block_x, target_block_y};
                pixel_id[j] <= num_pixels * all_done + j;
            end

            all_done <= all_done + 1;


            controller_ready_to_start <= 1'b0;


            end
        end


    always @ (posedge clk) begin
        if (all_last_input_done_before && controller_ready_to_start) begin
            for (int j = 0; j < num_pixels; j = j + 1) begin
                start[j] <= 1'b1;
                block_id <= {target_block_x, target_block_y};
            end

            all_done <= all_done + 1;


            controller_ready_to_start <= 1'b0;


            end
        end


    always_comb begin
        all_last_input_done_before = 1'b0; // Start with 0
        for (int i = 0; i < num_pixels; i++) begin
            if (i == 0) begin
                all_last_input_done_before = pixel_valid_out[0];
            end
            else begin
                all_last_input_done_before &= pixel_valid_out[i]; // AND with each bit
            end
        end
    end


    always @ (posedge clk) begin
        all_last_input_done <= all_last_input_done_before;
    end

    always @ (posedge clk) begin
        if (all_done == 16 && all_last_input_done_before) begin
            
            controller_ready_to_start <= 1'b0;
            
            @(posedge clk);

            $finish;
        end
    end

    always @ (negedge all_last_input_done_before) begin
        repeat(5) @(posedge clk);
            
            controller_ready_to_start <= 1'b1;
        
            
        end


    always @ (posedge clk) begin

        for (int j = 0; j < num_pixels; j = j + 1) begin
            if (!stall_backpressure[j] && pixel_valid_out[j] && all_last_input_done_before) begin
                $fwrite(out_color_file[j], "%h %h %h\n", pixel_color_out[j][(3 * precision)-1: 2 * precision], pixel_color_out[j][(2 * precision)-1: precision], pixel_color_out[j][precision-1: 0]);
                $fwrite(out_depth_file[j], "%h\n", pixel_depth_out[j]);
                $fwrite(out_opacity_file[j], "%h\n", pixel_opacity_out[j]);
            end
        end

    end

    // // // save per clock
    // always @ (posedge clk) begin

    //     if (clk_cnt >= 18 && clk_cnt <= 46) begin
    //         out_gaussian_file = $fopen($sformatf("../HEX_TB/hex/pixel_group/rgbd_dataset_freiburg1_desk_fp32/gid_result/cycle_%0d.hex", clk_cnt), "w");
    //         out_gaussian_file = $fopen($sformatf("../HEX_TB/hex/pixel_group/rgbd_dataset_freiburg1_desk_fp32/gid_resout_valid_file", clk_cnt), "w");
    



    //         for (int j = 0; j < num_pixels; j = j + 1) begin
    //             $fwrite(out_gaussian_file, "%h\n", gaussian_id_out[j]);
    //             $fwrite(out_gaussianout_valid_fileussian_id_out[j]);


    //         end

    //     end
    // end


    // // // Save for Merge sort data
    // always @ (posedge clk) begin
        

    //     if (clk_cnt >= 18 && clk_cnt <= 50) begin
    //         for (int j = 0; j < num_pixels; j = j + 1) begin
    //             $fwrite(out_gaussian_file[j], "%h\n", gaussian_id_out[j]);
    //             $fwrite(out_valid_file[j], "%h\n", gradient_valid_out[j]);
    //             $fwrite(out_dL_dcolor_file[j], "%h %h %h\n", dL_dcolor_out[j][(3 * precision)-1: 2 * precision], dL_dcolor_out[j][(2 * precision)-1: precision], dL_dcolor_out[j][precision-1: 0]);
    //             $fwrite(out_dL_ddepth_file[j], "%h\n", dL_ddepth_out[j]);
    //             $fwrite(out_dL_dopacity_file[j], "%h\n", dL_dopacity_out[j]);
    //             $fwrite(out_dL_dmean2D_file[j], "%h %h\n", dL_dmean2D_out[j][(2 * precision)-1: precision], dL_dmean2D_out[j][precision-1: 0]);
    //             $fwrite(out_dL_dconic_file[j], "%h %h %h %h\n", dL_dconic_out[j][(4 * precision)-1: 3 * precision], dL_dconic_out[j][(3 * precision)-1: 2 * precision],  dL_dconic_out[j][(2 * precision)-1: precision], dL_dconic_out[j][precision-1:0]);
    //         end
    //     end

    //     if (clk_cnt == 51) begin
    //         for (int j = 0; j < num_pixels; j = j + 1) begin
    //             $fclose(out_gaussian_file[j]);
    //             $fclose(out_valid_file[j]);
    //             $fclose(out_dL_dcolor_file[j]);
    //             $fclose(out_dL_ddepth_file[j]);
    //             $fclose(out_dL_dopacity_file[j]);
    //             $fclose(out_dL_dmean2D_file[j]);
    //             $fclose(out_dL_dconic_file[j]);
    //         end
    //         $finish;
    //     end
    // end


endmodule

