

`define MAX_MEMBER_SIZE 400000
// `define MAX_CLOCK_COUNT 2000000
`define MAX_CLOCK_COUNT 2000
// `define MAX_CLOCK_COUNT 300000


module tb_Gradient_merge_unit_by_majority #(
    parameter BLOCK_SIZE = 16, 
    parameter exponent_bit = 8, 
    parameter precision = 16, 
    parameter mantissa_bit = 7, 
    parameter num_pixels = 16, 
    parameter GID_bit = 24,
    parameter FIFO_depth = 16,
    parameter Banks = 16
    ) 
    ();

    integer max_clock_count = `MAX_CLOCK_COUNT;
    integer max_member_size = `MAX_MEMBER_SIZE;

    localparam arbiter_and_fifo_data_size = 11 * precision + GID_bit;

    // Input
    reg clk;
    reg rst_n;

    reg [GID_bit-1:0] gaussian_id [num_pixels-1:0];
    reg [(3*precision)-1:0] dL_dcolor [num_pixels-1:0];
    reg [precision-1:0] dL_ddepth [num_pixels-1:0];
    reg [(2*precision)-1:0] dL_dmean2D [num_pixels-1:0];
    reg [(4*precision)-1:0] dL_dconic [num_pixels-1:0];
    reg [precision-1:0] dL_dopacity [num_pixels-1:0];

    reg stall_backpressure;

    reg GID_valid [num_pixels-1:0];

    reg FIFO_pop_valid_in [Banks-1:0];

    // Output
    wire FIFO_pop_ready_out [Banks-1:0];
    wire [GID_bit-1:0] FIFO_GID_out [Banks-1:0];
    wire [arbiter_and_fifo_data_size-1:0] FIFO_pop_out [Banks-1:0];
    wire stall_to_controller;



    
    // parameter N_INPUTS = 850;
    parameter N_INPUTS = 834;

    // memory 
    reg [GID_bit-1:0] mem_gaussian_id [num_pixels-1:0][N_INPUTS-1:0];
    reg [precision-1:0] mem_dL_dcolor [num_pixels-1:0][3 * N_INPUTS-1:0];
    reg [precision-1:0] mem_dL_ddepth [num_pixels-1:0][N_INPUTS-1:0];
    reg [precision-1:0] mem_dL_dmean2D [num_pixels-1:0][2 * N_INPUTS-1:0];
    reg [precision-1:0] mem_dL_dconic [num_pixels-1:0][4 * N_INPUTS-1:0];
    reg [precision-1:0] mem_dL_dopacity [num_pixels-1:0][N_INPUTS-1:0];
    reg mem_gradient_valid [num_pixels-1:0][N_INPUTS-1:0];


    integer input_count = 0;

    integer stall_by_arbiter = 0;
    integer stall_by_fifo = 0;
    integer total_gradient_valid = 0;

    integer total_rest_gradient_valid = 0;

    reg any_GID_valid;

    reg done;

    initial begin
        $fsdbDumpfile("./output_backward_grad_merge/backward_grad_merge_dump.fsdb");
        $fsdbDumpvars(0, tb_Gradient_merge_unit_by_majority, "+all");
    end

    Gradient_merge_unit_by_majority #(
        .BLOCK_SIZE(BLOCK_SIZE), 
        .exponent_bit(exponent_bit), 
        .precision(precision), 
        .mantissa_bit(mantissa_bit), 
        .num_pixels(num_pixels),
        .GID_bit(GID_bit),
        .FIFO_depth(FIFO_depth),
        .arbiter_and_fifo_data_size(arbiter_and_fifo_data_size),
        .Banks(Banks)
    ) 

    Gradient_merge_unit_by_majority_inst (
        .clk(clk),
        .rst_n(rst_n),

        .gaussian_id(gaussian_id),

        .dL_dcolor(dL_dcolor),
        .dL_ddepth(dL_ddepth),
        .dL_dmean2D(dL_dmean2D),
        .dL_dconic(dL_dconic),
        .dL_dopacity(dL_dopacity),

        
        .GID_valid(GID_valid),

        .stall_backpressure(stall_backpressure),

        .FIFO_pop_valid_in(FIFO_pop_valid_in),

        .FIFO_pop_ready_out(FIFO_pop_ready_out),
        .FIFO_GID_out(FIFO_GID_out),

        .FIFO_pop_out(FIFO_pop_out),
        .stall_to_controller(stall_to_controller)
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

            $readmemh($sformatf("../HEX_TB/hex/Gradient_merge_without_zero_valid/dL_dcolor_out_by_testbench_%0d.hex", j), mem_dL_dcolor[j]);
            $readmemh($sformatf("../HEX_TB/hex/Gradient_merge_without_zero_valid/dL_ddepth_out_by_testbench_%0d.hex", j), mem_dL_ddepth[j]);
            $readmemh($sformatf("../HEX_TB/hex/Gradient_merge_without_zero_valid/dL_dmean2D_out_by_testbench_%0d.hex", j), mem_dL_dmean2D[j]);
            $readmemh($sformatf("../HEX_TB/hex/Gradient_merge_without_zero_valid/dL_dconic_out_by_testbench_%0d.hex", j), mem_dL_dconic[j]);
            $readmemh($sformatf("../HEX_TB/hex/Gradient_merge_without_zero_valid/dL_dopacity_out_by_testbench_%0d.hex", j), mem_dL_dopacity[j]);
            $readmemh($sformatf("../HEX_TB/hex/Gradient_merge_without_zero_valid/gaussian_id_out_by_testbench_%0d.hex", j), mem_gaussian_id[j]);
            $readmemh($sformatf("../HEX_TB/hex/Gradient_merge_without_zero_valid/gradient_valid_out_by_testbench_%0d.hex", j), mem_gradient_valid[j]);

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
        clk <= 1'b0;
        rst_n <= 1'b0;
        stall_backpressure <= 1'b0;
        done <= 1'b0;

        for (int i = 0; i < num_pixels; i++) begin
            gaussian_id[i] <= 32'h0;
            GID_valid[i] <= 1'b0;
        end

        for (int j= 0;j < Banks; j++) begin
            FIFO_pop_valid_in[j] <= 1'b0;
        end
        
        @(posedge clk);
        rst_n <= 1'b1;
    end        


    // Data input Control
    always @ (posedge clk) begin

        if (!stall_to_controller) begin

            if (input_count < N_INPUTS) begin
                for (int i = 0; i < num_pixels; i++) begin
                    gaussian_id[i] <= mem_gaussian_id[i][input_count];
                    dL_dcolor[i] <= {mem_dL_dcolor[i][3 * input_count + 0],  mem_dL_dcolor[i][3 * input_count + 1], mem_dL_dcolor[i][3 * input_count + 2] } ;
                    dL_ddepth[i] <= mem_dL_ddepth[i][input_count];
                    dL_dmean2D[i] <= {mem_dL_dmean2D[i][2 * input_count] , mem_dL_dmean2D[i][2 * input_count + 1]};
                    dL_dconic[i] <= {mem_dL_dconic[i][4 * input_count + 0], mem_dL_dconic[i][4 * input_count + 1], mem_dL_dconic[i][4 * input_count + 2], mem_dL_dconic[i][4 * input_count + 3]};
                    dL_dopacity[i] <= mem_dL_dopacity[i][input_count];
                    GID_valid[i] <= mem_gradient_valid[i][input_count];
                end

                input_count <= input_count + 1;
            end

            else begin
                done <= 1'b1;
                for (int i = 0; i < num_pixels; i++) begin
                    gaussian_id[i] <= 'h0;
                    dL_dcolor[i] <= 'h0;
                    dL_ddepth[i] <= 'h0;
                    dL_dmean2D[i] <= 'h0;
                    dL_dconic[i] <= 'h0;
                    dL_dopacity[i] <= 'h0;
                    GID_valid[i] <= 1'b0;
                end
            end


        end
    end

    // FIFO read control
    always @ (posedge clk) begin
        if (!stall_backpressure) begin

            repeat(5) @(posedge clk);

            for (int j = 0; j < Banks; j++) begin
                FIFO_pop_valid_in[j] <= 1'b1;
            end

            repeat(5) @(posedge clk);

            for (int j = 0; j < Banks; j++) begin
                FIFO_pop_valid_in[j] <= 1'b0;
            end

        end
    end


    always @ (posedge clk) begin
        if (Gradient_merge_unit_by_majority_inst.stall_from_arbiter_comb) begin
            stall_by_arbiter <= stall_by_arbiter + 1;
        end

        if (Gradient_merge_unit_by_majority_inst.stall_from_fifo_comb) begin
            stall_by_fifo <= stall_by_fifo + 1;
        end

        // Cannot use reduction operator on memory array
        // Check each bit individually
        if (any_GID_valid && !stall_to_controller) begin
            total_gradient_valid <= total_gradient_valid + 1;
        end

        if (!any_GID_valid && !stall_to_controller) begin
            total_rest_gradient_valid <= total_rest_gradient_valid + 1;
        end

    end

    always_comb begin
        any_GID_valid = 1'b0;
        for (int i = 0; i < num_pixels; i++) begin
            any_GID_valid = any_GID_valid || GID_valid[i];
        end
    end

    always @ (posedge done) begin
        $display("End Time : %d", clk_cnt);
        $display("total_gradient_valid: %d", total_gradient_valid);
        $display("total_rest_gradient_valid: %d", total_rest_gradient_valid);
        $display("stall_by_arbiter: %d", stall_by_arbiter);
        $display("stall_by_fifo: %d", stall_by_fifo);
    end

    initial begin
        // Set composite fast draw member size
        $value$plusargs("SET_COMPOSITE_FAST_DRAW_MEMBER_SIZE=%d", max_member_size);
    end



endmodule
