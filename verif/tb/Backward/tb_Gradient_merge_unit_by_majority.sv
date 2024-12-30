module tb_Gradient_merge_unit_by_majority #(
    parameter BLOCK_SIZE = 16, 
    parameter exponent_bit = 8, 
    parameter precision = 32, 
    parameter mantissa_bit = 23, 
    parameter num_pixels = 16, 
    parameter GID_bit = 32,
    parameter FIFO_depth = 16,
    parameter arbiter_and_fifo_data_size = 11 * precision + GID_bit,
    parameter Banks = 16
    ) 
    ();

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

    reg FIFO_read_valid_in [Banks-1:0];

    // Output
    wire FIFO_read_ready_out [Banks-1:0];
    wire [GID_bit-1:0] FIFO_GID_out [Banks-1:0];
    wire [arbiter_and_fifo_data_size-1:0] FIFO_read_out [Banks-1:0];
    wire stall_to_controller;

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

        .FIFO_read_valid_in(FIFO_read_valid_in),

        .FIFO_read_ready_out(FIFO_read_ready_out),
        .FIFO_GID_out(FIFO_GID_out),
        .FIFO_read_out(FIFO_read_out),
        .stall_to_controller(stall_to_controller)
        );


    initial begin
        // 데이터 입수

    end

    always begin
        #5 clk = !clk;  // Toggle clock every half period
    end

    integer clk_cnt = 0;

    always @(posedge clk) begin
        clk_cnt <= clk_cnt + 1;
        if (clk_cnt == 40) $finish;
    end


    initial begin
        clk <= 1'b0;
        rst_n <= 1'b0;
        stall_backpressure <= 1'b0;

        for (int i = 0; i < num_pixels; i++) begin
            gaussian_id[i] <= 32'h0;
            GID_valid[i] <= 1'b0;
        end

        for (int j= 0;j < Banks; j++) begin
            FIFO_read_valid_in[j] <= 1'b0;
        end


        

        @(posedge clk);
        rst_n <= 1'b1;
        

        // Initialize all GID_valid and gaussian_id to 0
        for (int i = 0; i < num_pixels; i++) begin
            GID_valid[i] <= 1'b1;
            gaussian_id[i] <= 32'h0000_000F;

            dL_ddepth[i] <= 32'h3F800000; // IEEE-754 single precision representation of 1.0
            dL_dcolor[i] <= {32'h40000000, 32'h40000000, 32'h40000000}; // IEEE-754 single precision representation of 2.0, 3.0, 4.0
            dL_dmean2D[i] <= {32'h40400000, 32'h40400000};
            dL_dconic[i] <= {32'h40800000, 32'h40800000, 32'h40800000, 32'h40800000};
            dL_dopacity[i] <= 32'h40a00000;
        end

        for (int j= 0;j < Banks; j++) begin
            FIFO_read_valid_in[j] <= 1'b1;
        end

        // // Test case 1: Different gaussian IDs with valid signals
        @(posedge clk);
        for (int i = 0; i < num_pixels; i++) begin
            GID_valid[i] <= 1'b1;
            gaussian_id[i] <= 32'h0000_0001 + i;
            
            dL_ddepth[i] <= 32'h3F800000; // IEEE-754 single precision representation of 1.0
            dL_dcolor[i] <= {32'h40000000, 32'h40000000, 32'h40000000}; // IEEE-754 single precision representation of 2.0, 3.0, 4.0
            dL_dmean2D[i] <= {32'h40400000, 32'h40400000};
            dL_dconic[i] <= {32'h40800000, 32'h40800000, 32'h40800000, 32'h40800000};
            dL_dopacity[i] <= 32'h40a00000;
        end

        // for (int j= 0;j < Banks; j++) begin
        //     FIFO_read_valid_in[j] <= 1'b1;
        // end

        @(posedge clk);
        // Reset some valid signals
        for (int i = 0; i < num_pixels; i++) begin
            GID_valid[i] <= 1'b1;
            gaussian_id[i] <= 32'h0000_0001 + (i / 2);

            dL_ddepth[i] <= 32'h40000000;
            dL_dcolor[i] <= {32'h40e00000, 32'h40e00000, 32'h40e00000}; // IEEE-754 single precision representation of 2.0, 3.0, 4.0
            dL_dmean2D[i] <= {32'h41000000, 32'h41000000};
            dL_dconic[i] <= {32'h41200000, 32'h41200000, 32'h41200000, 32'h41200000};
            dL_dopacity[i] <= 32'h41400000;
        end

        @(posedge clk);
        for (int i = 0; i < num_pixels; i++) begin
            GID_valid[i] <= 1'b1;
            gaussian_id[i] <= 32'h0000_0001 + (i / 2);

            dL_ddepth[i] <= 32'h40c00000; // IEEE-754 single precision representation of 1.0
            dL_dcolor[i] <= {32'h40e00000, 32'h40e00000, 32'h40e00000}; // IEEE-754 single precision representation of 2.0, 3.0, 4.0
            dL_dmean2D[i] <= {32'h41000000, 32'h41000000};
            dL_dconic[i] <= {32'h41200000, 32'h41200000, 32'h41200000, 32'h41200000};
            dL_dopacity[i] <= 32'h41400000;
        end



        @(posedge clk);
        for (int i = 0; i < num_pixels; i++) begin
            GID_valid[i] <= 1'b0;
            gaussian_id[i] <= 32'h0000_0000;
            
            dL_ddepth[i] <= 32'h0; // IEEE-754 single precision representation of 1.0

            dL_dcolor[i] <= 'h0;
            dL_dmean2D[i] <= 64'h0;
            dL_dconic[i] <= 128'h0;
            dL_dopacity[i] <= 32'h0;
        end
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);

        @(posedge clk);
        for (int i = 0; i < num_pixels; i = i + 2) begin
            GID_valid[i] <= 1'b1;
            gaussian_id[i] <= 32'h0000_0010 + i;
        
            dL_ddepth[i] <= 32'h3f800000; // IEEE-754 single precision representation of 1.0
            dL_dcolor[i] <= {32'h3f800000, 32'h3f800000, 32'h3f800000}; // IEEE-754 single precision representation of 2.0, 3.0, 4.0
            dL_dmean2D[i] <= {32'h3f800000, 32'h3f800000};
            dL_dconic[i] <= {32'h3f800000, 32'h3f800000, 32'h3f800000, 32'h3f800000};
            dL_dopacity[i] <= 32'h3f800000;
        end


        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        for (int i = 0; i < num_pixels; i = i + 2) begin
            GID_valid[i] <= 1'b1;
            GID_valid[i+1] <= 1'b1;

            gaussian_id[i] <= 32'h0000_0010;
            gaussian_id[i+1] <= 32'h0000_0011;
        
            dL_ddepth[i] <= 32'h40000000; // IEEE-754 single precision representation of 1.0
            dL_dcolor[i] <= {32'h40000000, 32'h40000000, 32'h40000000}; // IEEE-754 single precision representation of 2.0, 3.0, 4.0
            dL_dmean2D[i] <= {32'h40000000, 32'h40000000};
            dL_dconic[i] <= {32'h40000000, 32'h40000000, 32'h40000000, 32'h40000000};
            dL_dopacity[i] <= 32'h40000000;

            dL_ddepth[i+1] <= 32'h40000000; // IEEE-754 single precision representation of 1.0
            dL_dcolor[i+1] <= {32'h40000000, 32'h40000000, 32'h40000000}; // IEEE-754 single precision representation of 2.0, 3.0, 4.0
            dL_dmean2D[i+1] <= {32'h40000000, 32'h40000000};
            dL_dconic[i+1] <= {32'h40000000, 32'h40000000, 32'h40000000, 32'h40000000};
            dL_dopacity[i+1] <= 32'h40000000;


        end     

        @(posedge clk);

        for (int i = 0; i < num_pixels; i++) begin
            GID_valid[i] <= 1'b1;
            gaussian_id[i] <= i;

            dL_ddepth[i] <= 32'h44c2a000; // IEEE-754 single precision representation of 1.0

            dL_dcolor[i] <= {32'h44c2a000, 32'h44c2a000, 32'h44c2a000};
            dL_dmean2D[i] <= {32'h44c2a000, 32'h44c2a000};
            dL_dconic[i] <= {32'h44c2a000, 32'h44c2a000, 32'h44c2a000, 32'h44c2a000};
            dL_dopacity[i] <= 32'h44c2a000;
        end


        @(posedge clk);

        for (int i = 0; i < num_pixels; i++) begin
            GID_valid[i] <= 1'b0;
            gaussian_id[i] <= 32'h0000_0000;

            dL_ddepth[i] <= 32'h0; // IEEE-754 single precision representation of 1.0

            dL_dcolor[i] <= 'h0;
            dL_dmean2D[i] <= 64'h0;
            dL_dconic[i] <= 128'h0;
            dL_dopacity[i] <= 32'h0;
        end


        repeat (100) @(posedge clk);
        $finish;
    end


    // always @ (posedge clk) begin
    //     for (int j = 0; j< Banks; j++) begin
    //         if (FIFO_read_ready_out[j] && FIFO_read_valid_in[j]) begin
    //             FIFO_read_valid_in[j] <= 1'b0;
    //         end
    //     end
    // end
endmodule
