

`define MAX_MEMBER_SIZE 400000
// `define MAX_CLOCK_COUNT 2000000
`define MAX_CLOCK_COUNT 5000
// `define MAX_CLOCK_COUNT 300000


module tb_Pixel_group_with_merge_unit_and_cache #(
    parameter BLOCK_SIZE = 16, 
    parameter exponent_bit = 8, 
    parameter precision = 16, 
    parameter mantissa_bit = 7, 
    parameter num_pixels = 16, 
    parameter GID_bit = 24,
    parameter First_FIFO_depth = 4,
    parameter Last_FIFO_depth = 8,
    parameter Banks = 8,
    parameter Encoder_outs = 4
    ) 
    ();

    integer max_clock_count = `MAX_CLOCK_COUNT;
    integer max_member_size = `MAX_MEMBER_SIZE;

    localparam arbiter_and_fifo_data_size = 11 * precision + GID_bit;

    // Input
    reg clk;
    reg rst_n;

    reg [GID_bit-1:0] gaussian_id_in [num_pixels-1:0];
    reg [(3*precision)-1:0] dL_dcolor_in [num_pixels-1:0];
    reg [precision-1:0] dL_ddepth_in [num_pixels-1:0];
    reg [(2*precision)-1:0] dL_dmean2D_in [num_pixels-1:0];
    reg [(4*precision)-1:0] dL_dconic_in [num_pixels-1:0];
    reg [precision-1:0] dL_dopacity_in [num_pixels-1:0];
    reg last_input_done_in [num_pixels-1:0];

    reg stall_backpressure;

    reg GID_valid_in [num_pixels-1:0];


    // Output
    wire FIFO_pop_ready_out [Banks-1:0];
    // wire [GID_bit-1:0] FIFO_GID_out [Banks-1:0];
    // wire [arbiter_and_fifo_data_size-GID_bit-1:0] FIFO_pop_out [Banks-1:0];
    wire stall_to_controller;

    wire last_input_done_out [Banks-1:0];

    wire [GID_bit-1:0] Read_address_before_add [Banks-1:0];


    // SRAM Control Signal
    // reg SRAM_WEB [Banks-1:0];
    // reg SRAM_WEB_temp [Banks-1:0];
    // reg SRAM_REB [Banks-1:0];

    wire SRAM_WEB [Banks-1:0];
    reg SRAM_WEB_temp [Banks-1:0];
    wire SRAM_REB [Banks-1:0];


    reg start;

    wire FIFO_pop_valid_in [Banks-1:0];

    // 비교용 + 다음 주소
    reg [GID_bit-1:0] Write_address_FF [Banks-1:0];

    

    // Internal Signal
    reg [$clog2(BLOCK_SIZE)<<$clog2(BLOCK_SIZE):0] last_input_done_counter_next;
    reg [$clog2(BLOCK_SIZE)<<$clog2(BLOCK_SIZE):0] last_input_done_counter_FF;
    

    // parameter N_INPUTS = 850;
    // parameter N_INPUTS = 834;
    // parameter N_INPUTS = 570;
    parameter N_INPUTS = 961;

    // memory 
    reg [GID_bit-1:0] mem_gaussian_id [num_pixels-1:0][N_INPUTS-1:0];
    reg [precision-1:0] mem_dL_dcolor [num_pixels-1:0][3 * N_INPUTS-1:0];
    reg [precision-1:0] mem_dL_ddepth [num_pixels-1:0][N_INPUTS-1:0];
    reg [precision-1:0] mem_dL_dmean2D [num_pixels-1:0][2 * N_INPUTS-1:0];
    reg [precision-1:0] mem_dL_dconic [num_pixels-1:0][4 * N_INPUTS-1:0];
    reg [precision-1:0] mem_dL_dopacity [num_pixels-1:0][N_INPUTS-1:0];
    reg mem_gradient_valid [num_pixels-1:0][N_INPUTS-1:0];
    reg mem_last_input_done_out [num_pixels-1:0][N_INPUTS-1:0];



    integer input_count = 0;

    integer stall_by_encoder = 0;
    integer stall_by_1x_fifo = 0;
    integer stall_by_4x_fifo = 0;
    integer stall_by_serializer = 0;
    integer total_gradient_valid = 0;

    integer total_rest_gradient_valid = 0;
    integer stall_to_controller_count = 0;
    integer stall_by_encoder_output_valid_full = 0;

    integer bank_conflict_count[Banks-1:0];

    reg any_GID_valid;

    reg done;

    integer report_file;

    initial begin
        $fsdbDumpfile("./output_backward_grad_merge/backward_grad_merge_dump.fsdb");
        $fsdbDumpvars(0, tb_Pixel_group_with_merge_unit_and_cache, "+all");
    end

    Pixel_group_with_merge_unit_and_cache #(
        .BLOCK_SIZE(BLOCK_SIZE), 
        .exponent_bit(exponent_bit), 
        .precision(precision), 
        .mantissa_bit(mantissa_bit), 
        .num_pixels(num_pixels),
        .GID_bit(GID_bit),
        .First_FIFO_depth(First_FIFO_depth),
        .Last_FIFO_depth(Last_FIFO_depth),
        .arbiter_and_fifo_data_size(arbiter_and_fifo_data_size),
        .Banks(Banks),
        .Encoder_outs(Encoder_outs)
    ) 

    Pixel_group_with_merge_unit_and_cache_inst (
        .clk(clk),
        .rst_n(rst_n),

        .gaussian_id_in(gaussian_id_in),

        .dL_dcolor_in(dL_dcolor_in),
        .dL_ddepth_in(dL_ddepth_in),
        .dL_dmean2D_in(dL_dmean2D_in),
        .dL_dconic_in(dL_dconic_in),
        .dL_dopacity_in(dL_dopacity_in),

        
        .GID_valid_in(GID_valid_in),
        .last_input_done_in(last_input_done_in),

        .stall_backpressure(stall_backpressure),

        .stall_to_controller(stall_to_controller),
        
        // SRAM Control Signal
        
        // To FIFO
        .FIFO_pop_valid_in(FIFO_pop_valid_in),

        // To SRAM
        .SRAM_WEB(SRAM_WEB),
        .SRAM_REB(SRAM_REB),

        // from FIFO
        .Read_address_before_add(Read_address_before_add),
        .FIFO_pop_ready_out(FIFO_pop_ready_out),

        .last_input_done_out(last_input_done_out)


        );


    initial begin        
        for (int j = 0; j < num_pixels; j = j + 1) begin
            // $readmemh($sformatf("../HEX_TB/hex/Gradient_merge_with_zero_valid/dL_dcolor_out_by_testbench_%0d.hex", j), mem_dL_dcolor[j]);
            // $readmemh($sformatf("../HEX_TB/hex/Gradient_merge_with_zero_valid/dL_ddepth_out_by_testbench_%0d.hex", j), mem_dL_ddepth[j]);
            // $readmemh($sformatf("../HEX_TB/hex/Gradient_merge_with_zero_valid/dL_dmean2D_out_by_testbench_%0d.hex", j), mem_dL_dmean2D[j]);
            // $readmemh($sformatf("../HEX_TB/hex/Gradient_merge_with_zero_valid/dL_dconic_out_by_testbench_%0d.hex", j), mem_dL_dconic[j]);
            // $readmemh($sformatf("../HEX_TB/hex/Gradient_merge_with_zero_valid/dL_dopacity_out_by_testbench_%0d.hex", j), mem_dL_dopacity[j]);
            // $readmemh($sformatf("../HEX_TB/hex/Gradient_merge_with_zero_valid/gaussian_id_out_by_testbench_%0d.hex", j), mem_gaussian_id[j]);
            // $readmemh($sformatf("../HEX_TB/hex/Gradient_merge_with_zero_valid/gradient_valid_out_by_testbench_%0d.hex", j), mem_gradient_valid[j]);

            // $readmemh($sformatf("../HEX_TB/hex/Gradient_merge_without_zero_valid/dL_dcolor_out_by_testbench_%0d.hex", j), mem_dL_dcolor[j]);
            // $readmemh($sformatf("../HEX_TB/hex/Gradient_merge_without_zero_valid/dL_ddepth_out_by_testbench_%0d.hex", j), mem_dL_ddepth[j]);
            // $readmemh($sformatf("../HEX_TB/hex/Gradient_merge_without_zero_valid/dL_dmean2D_out_by_testbench_%0d.hex", j), mem_dL_dmean2D[j]);
            // $readmemh($sformatf("../HEX_TB/hex/Gradient_merge_without_zero_valid/dL_dconic_out_by_testbench_%0d.hex", j), mem_dL_dconic[j]);
            // $readmemh($sformatf("../HEX_TB/hex/Gradient_merge_without_zero_valid/dL_dopacity_out_by_testbench_%0d.hex", j), mem_dL_dopacity[j]);
            // $readmemh($sformatf("../HEX_TB/hex/Gradient_merge_without_zero_valid/gaussian_id_out_by_testbench_%0d.hex", j), mem_gaussian_id[j]);
            // $readmemh($sformatf("../HEX_TB/hex/Gradient_merge_without_zero_valid/gradient_valid_out_by_testbench_%0d.hex", j), mem_gradient_valid[j]);

            $readmemh($sformatf("../HEX_TB/hex/Gradient_merge_testbench/Gradient_merge_block_246_without_zero_valid/dL_dcolor_out_by_testbench_%0d.hex", j), mem_dL_dcolor[j]);
            $readmemh($sformatf("../HEX_TB/hex/Gradient_merge_testbench/Gradient_merge_block_246_without_zero_valid/dL_ddepth_out_by_testbench_%0d.hex", j), mem_dL_ddepth[j]);
            $readmemh($sformatf("../HEX_TB/hex/Gradient_merge_testbench/Gradient_merge_block_246_without_zero_valid/dL_dmean2D_out_by_testbench_%0d.hex", j), mem_dL_dmean2D[j]);
            $readmemh($sformatf("../HEX_TB/hex/Gradient_merge_testbench/Gradient_merge_block_246_without_zero_valid/dL_dconic_out_by_testbench_%0d.hex", j), mem_dL_dconic[j]);
            $readmemh($sformatf("../HEX_TB/hex/Gradient_merge_testbench/Gradient_merge_block_246_without_zero_valid/dL_dopacity_out_by_testbench_%0d.hex", j), mem_dL_dopacity[j]);
            $readmemh($sformatf("../HEX_TB/hex/Gradient_merge_testbench/Gradient_merge_block_246_without_zero_valid/gaussian_id_out_by_testbench_%0d.hex", j), mem_gaussian_id[j]);
            $readmemh($sformatf("../HEX_TB/hex/Gradient_merge_testbench/Gradient_merge_block_246_without_zero_valid/gradient_valid_out_by_testbench_%0d.hex", j), mem_gradient_valid[j]);
            $readmemh($sformatf("../HEX_TB/hex/Gradient_merge_testbench/Gradient_merge_block_246_without_zero_valid/last_input_done_by_testbench_%0d.hex", j), mem_last_input_done_out[j]);

        end
    end

    always begin
        #5 clk = !clk;  // Toggle clock every half period
    end

    integer clk_cnt = 0;

    always @(posedge clk) begin
        clk_cnt <= clk_cnt + 1;
        if (clk_cnt == max_clock_count) $finish;
    end


    initial begin

        report_file = $fopen($sformatf("../simulation_output/16to%0d_4xFIFO%0d_1xFIFO%0d_Bank%0d.txt", Encoder_outs, First_FIFO_depth, Last_FIFO_depth, Banks), "w");

        clk <= 1'b0;
        rst_n <= 1'b0;
        stall_backpressure <= 1'b0;
        done <= 1'b0;
        last_input_done_counter_FF <= 0;
        start <= 1'b0;
        input_count <= 0;
        

        for (int i = 0; i < num_pixels; i++) begin
            gaussian_id_in[i] <= 32'h0;
            GID_valid_in[i] <= 1'b0;
            last_input_done_in[i] <= 1'b0;

            dL_dcolor_in[i] <= 48'h0;
            dL_ddepth_in[i] <= 16'h0;
            dL_dmean2D_in[i] <= 32'h0;
            dL_dconic_in[i] <= 64'h0;
            dL_dopacity_in[i] <= 16'h0;

            GID_valid_in[i] <= 1'b0;
        end

        for (int j= 0; j < Banks; j++) begin
            // FIFO_pop_valid_in[j] <= 1'b0;
            // SRAM_REB[j] <= 1'b1;
            // SRAM_WEB[j] <= 1'b1;
            Write_address_FF[j] <= 32'h0;
            SRAM_WEB_temp[j] <= 1'b1;
            bank_conflict_count[j] <= 0;
        end
        
        @(posedge clk);
        rst_n <= 1'b1;

        @(posedge clk);
        start <= 1'b1;
    end        


    // Data input Control
    always @ (posedge clk) begin

        if (!stall_to_controller && start) begin

            if (input_count < N_INPUTS) begin

                for (int i = 0; i < num_pixels; i++) begin
                    gaussian_id_in[i] <= mem_gaussian_id[i][input_count];
                    dL_dcolor_in[i] <= {mem_dL_dcolor[i][3 * input_count + 0],  mem_dL_dcolor[i][3 * input_count + 1], mem_dL_dcolor[i][3 * input_count + 2] } ;
                    dL_ddepth_in[i] <= mem_dL_ddepth[i][input_count];
                    dL_dmean2D_in[i] <= {mem_dL_dmean2D[i][2 * input_count] , mem_dL_dmean2D[i][2 * input_count + 1]};
                    dL_dconic_in[i] <= {mem_dL_dconic[i][4 * input_count + 0], mem_dL_dconic[i][4 * input_count + 1], mem_dL_dconic[i][4 * input_count + 2], mem_dL_dconic[i][4 * input_count + 3]};
                    dL_dopacity_in[i] <= mem_dL_dopacity[i][input_count];
                    GID_valid_in[i] <= mem_gradient_valid[i][input_count];
                    last_input_done_in[i] <= mem_last_input_done_out[i][input_count];

                    // if (input_count == N_INPUTS - 1) begin
                    //     last_input_done_in[i] <= 1'b1;
                    // end
                end

                input_count <= input_count + 1;
            end

            else begin

                // done <= 1'b1;
                for (int i = 0; i < num_pixels; i++) begin
                    gaussian_id_in[i] <= 'h0;
                    dL_dcolor_in[i] <= 'h0;
                    dL_ddepth_in[i] <= 'h0;
                    dL_dmean2D_in[i] <= 'h0;
                    dL_dconic_in[i] <= 'h0;
                    dL_dopacity_in[i] <= 'h0;
                    GID_valid_in[i] <= 1'b0;
                    last_input_done_in[i] <= 1'b0;
                end

                input_count <= input_count + 1;   
            end
        end

        else begin
        // stall to controller
            for (int i = 0; i < num_pixels; i++) begin

                GID_valid_in[i] <= 1'b0;
            end
        end
    end


    genvar k;
    generate 
        for (k = 0; k < Banks; k++) begin : SRAM_WEB_gen
            assign SRAM_WEB[k] = SRAM_WEB_temp[k];
            assign SRAM_REB[k] = FIFO_pop_ready_out[k] && (Write_address_FF[k] != Read_address_before_add[k]) ? 1'b0 : 1'b1;
            // assign FIFO_pop_valid_in[k] = FIFO_pop_ready_out[k] && (Write_address_FF[k] != Read_address_before_add[k]) ? 1'b1 : 1'b0;
            assign FIFO_pop_valid_in[k] = (FIFO_pop_ready_out[k]) && ((Write_address_FF[k] != Read_address_before_add[k]) || Read_address_before_add[k] == 0) ? 1'b1 : 1'b0;
        end
    endgenerate


    // FIFO read control
    always @ (posedge clk) begin

        if (!stall_backpressure) begin

            for (int j = 0; j < Banks; j++) begin

                // FIFO_pop_valid_in[j] <= 1'b1;
                // SRAM_WEB[j] <= SRAM_WEB_temp[j];
                
                // 충돌 확인 후 다음 사이클에 데이터 전송
                // if (FIFO_pop_ready_out[j] && FIFO_pop_valid_in[j]) begin
                if (FIFO_pop_ready_out[j]) begin

                    if (Write_address_FF[j] != Read_address_before_add[j]) begin
                        // SRAM_REB[j] <= 1'b0; // Active low
                        SRAM_WEB_temp[j] <= 1'b0;
                        Write_address_FF[j] <= Read_address_before_add[j];
                        // FIFO_pop_valid_in[j] <= 1'b1;
                    end

                    // 충돌시 REB를 안띄우는 대신 Write Addr도 삭제
                    // Bank Conflict 카운트
                    else begin
                        bank_conflict_count[j] <= bank_conflict_count[j] + 1;
                        // SRAM_REB[j] <= 1'b1;
                        SRAM_WEB_temp[j] <= 1'b1;
                        Write_address_FF[j] <= 'h0;
                        // FIFO_pop_valid_in[j] <= 1'b0;
                    end

                    
                end

                // 새로 들어오는 신호와 이전 신호가 같으면 Read / Write 충돌

                else begin
                    // SRAM_REB[j] <= 1'b1;
                    SRAM_WEB_temp[j] <= 1'b1;
                    Write_address_FF[j] <= 'h0;
                    // FIFO_pop_valid_in[j] <= 1'b0;
                end
            end
        end
    end

    // Stall 기록용
    always @ (posedge clk) begin
        if (Pixel_group_with_merge_unit_and_cache_inst.Gradient_merge_unit_by_majority_inst.stall_from_encoder_comb) begin
            stall_by_encoder <= stall_by_encoder + 1;
        end

        if (Pixel_group_with_merge_unit_and_cache_inst.Gradient_merge_unit_by_majority_inst.stall_from_1x_fifo_comb) begin
            stall_by_1x_fifo <= stall_by_1x_fifo + 1;
        end

        if (Pixel_group_with_merge_unit_and_cache_inst.Gradient_merge_unit_by_majority_inst.stall_from_4x_fifo_comb) begin
            stall_by_4x_fifo <= stall_by_4x_fifo + 1;
        end

        if (Pixel_group_with_merge_unit_and_cache_inst.Gradient_merge_unit_by_majority_inst.stall_from_serializer_comb) begin
            stall_by_serializer <= stall_by_serializer + 1;
        end

        // Cannot use reduction operator on memory array
        // Check each bit individually
        if (any_GID_valid && !stall_to_controller) begin
            total_gradient_valid <= total_gradient_valid + 1;
        end

        if (!any_GID_valid && !stall_to_controller) begin
            total_rest_gradient_valid <= total_rest_gradient_valid + 1;
        end

        if (stall_to_controller) begin
            stall_to_controller_count <= stall_to_controller_count + 1;
        end

    end

    always @ (posedge clk) begin
        last_input_done_counter_FF <= last_input_done_counter_next;
        done <= (last_input_done_counter_next == (BLOCK_SIZE << $clog2(BLOCK_SIZE)));
    end

    always_comb begin

        // GID Valid input
        any_GID_valid = 1'b0;
        for (int i = 0; i < num_pixels; i++) begin
            any_GID_valid = any_GID_valid || GID_valid_in[i];
        end

        // last input done counter
        last_input_done_counter_next = last_input_done_counter_FF;

        for (int i = 0; i < Banks; i++) begin
            if (last_input_done_out[i] && FIFO_pop_ready_out[i]) begin
                last_input_done_counter_next = last_input_done_counter_next + 1;
            end
        end
    end


    always @ (posedge done) begin

        
        // repeat(5) begin
        //     $display("\n");
        // end
        // $display("----------------------------------------------------------------------------------------------------");
        // $display("End Time : %0d", clk_cnt);
        // $display("Total Input : %0d", N_INPUTS);
        // $display("total_gradient_valid: %0d", total_gradient_valid);
        // $display("total_rest_gradient_valid: %0d", total_rest_gradient_valid);
        // $display("stall_by_encoder: %0d", stall_by_encoder);
        // $display("stall_by_1x_fifo: %0d", stall_by_1x_fifo);
        // $display("stall_by_4x_fifo: %0d", stall_by_4x_fifo);
        // $display("stall_by_serializer: %0d", stall_by_serializer);
        // $display("stall_to_controller_count: %0d", stall_to_controller_count);

        // for (int i = 0; i < Banks; i++) begin
        //     $display("bank_conflict_count[%0d]: %0d", i, bank_conflict_count[i]);
        // end

        // $display("----------------------------------------------------------------------------------------------------");
        // repeat(5) begin
        //     $display("\n");
        // end
        

        $fwrite(report_file, "First_FIFO_depth: %0d\n", First_FIFO_depth);
        $fwrite(report_file, "Last_FIFO_depth: %0d\n", Last_FIFO_depth);
        $fwrite(report_file, "Bank: %0d\n", Banks);
        $fwrite(report_file, "Encoder_outs: %0d\n", Encoder_outs);
        
        $fwrite(report_file, "\n\n\n\n\n");
        $fwrite(report_file, "----------------------------------------------------------------------------------------------------\n");
        $fwrite(report_file, "End Time : %0d\n\n", clk_cnt);
        $fwrite(report_file, "Total Input : %0d\n", N_INPUTS);
        $fwrite(report_file, "Total Valid input : %0d\n", total_gradient_valid);
        $fwrite(report_file, "Total invalid input time (all GID_valid is zero): %0d\n\n", total_rest_gradient_valid);

        $fwrite(report_file, "encoder stall time (Too much valid output or 4X FIFO full): %0d\n", stall_by_encoder);
        $fwrite(report_file, "4X stall time  (4X FIFO Full): %0d\n\n", stall_by_4x_fifo);


        for (int i = 0; i < Banks; i++) begin
            $fwrite(report_file, "Bank[%0d] conflict time: %0d\n", i, bank_conflict_count[i]);
        end
        $fwrite(report_file, "\n");


        $fwrite(report_file, "stall_by_1x_fifo: %0d\n", stall_by_1x_fifo);
        $fwrite(report_file, "stall_by_serializer: %0d\n", stall_by_serializer);
        $fwrite(report_file, "stall_to_controller_count: %0d\n", stall_to_controller_count);

        $fwrite(report_file, "----------------------------------------------------------------------------------------------------\n");
        $fwrite(report_file, "\n\n\n\n\n");
        
        $display("Simulation completed. Results saved in %s", report_file);

        $finish;
    end

    initial begin
        // Set composite fast draw member size
        $value$plusargs("SET_COMPOSITE_FAST_DRAW_MEMBER_SIZE=%d", max_member_size);
    end



endmodule
