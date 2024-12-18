module tb_majority_adder #(
    parameter BLOCK_SIZE = 16,
    parameter exponent_bit = 8,
    parameter precision = 32,
    parameter mantissa_bit = 23,
    parameter num_pixels = 8
    ) ();

    // Input
    reg clk;
    reg rst_n;

    reg [(3 * precision)-1:0] dL_dcolor [num_pixels-1:0];
    reg [precision-1:0] dL_ddepth [num_pixels-1:0];
    reg [(2 * precision)-1:0] dL_dmean2D [num_pixels-1:0];
    reg [(4 * precision)-1:0] dL_dconic [num_pixels-1:0];
    reg [precision-1:0] dL_dopacity [num_pixels-1:0];

    reg is_majority_gid [num_pixels-1:0];

    reg stall_backpressure;

    wire [(3 * precision)-1:0] majority_dL_dcolor_out;
    wire [precision-1:0] majority_dL_ddepth_out;
    wire [(2 * precision)-1:0] majority_dL_dmean2D_out;
    wire [(4 * precision)-1:0] majority_dL_dconic_out;
    wire [precision-1:0] majority_dL_dopacity_out;
    wire majority_valid_out;


    initial begin
        $fsdbDumpfile("./output/dump.fsdb");
        $fsdbDumpvars(0, tb_majority_adder, "+all");
    end

    majority_adder #(.BLOCK_SIZE(BLOCK_SIZE), .exponent_bit(exponent_bit), .precision(precision), .mantissa_bit(mantissa_bit), .num_pixels(num_pixels)) 
        majority_adder_inst (
            .clk(clk),
            .rst_n(rst_n),

            .dL_dcolor_in(dL_dcolor),
            .dL_ddepth_in(dL_ddepth),
            .dL_dmean2D_in(dL_dmean2D),
            .dL_dconic_in(dL_dconic),
            .dL_dopacity_in(dL_dopacity),

            .is_majority_gid_in(is_majority_gid),

            .stall_backpressure(stall_backpressure),

            .majority_dL_dcolor_out(majority_dL_dcolor_out),
            .majority_dL_ddepth_out(majority_dL_ddepth_out),
            .majority_dL_dmean2D_out(majority_dL_dmean2D_out),
            .majority_dL_dconic_out(majority_dL_dconic_out),
            .majority_dL_dopacity_out(majority_dL_dopacity_out),

            .majority_valid_out(majority_valid_out)
        );


    always begin
        #5 clk = !clk;  // Toggle clock every half period
    end

    integer clk_cnt = 0;

    always @(posedge clk) begin
        clk_cnt <= clk_cnt + 1;
        if (clk_cnt == 100) $finish;
    end


    initial begin
        clk <= 1'b0;
        rst_n <= 1'b0;
        stall_backpressure <= 1'b0;

        @(posedge clk) 
        rst_n <= 1'b1;

        // Initialize all GID_valid and gaussian_id to 0
        for (int i = 0; i < num_pixels; i++) begin
            is_majority_gid[i] <= 1'b0;
            dL_ddepth[i] <= 32'h0; // IEEE-754 single precision representation of 1.0

            dL_dcolor[i] <= 32'h0;
            dL_dmean2D[i] <= 64'h0;
            dL_dconic[i] <= 128'h0;
            dL_dopacity[i] <= 32'h0;
        end

        // Test case 1: Different gaussian IDs with valid signals
        @(posedge clk);
        for (int i = 0; i < num_pixels; i++) begin
            is_majority_gid[i] <= 1'b1;
            dL_ddepth[i] <= 32'h3F800000; // IEEE-754 single precision representation of 1.0
            dL_dcolor[i] <= {32'h40000000, 32'h40000000, 32'h40000000}; // IEEE-754 single precision representation of 2.0, 3.0, 4.0
            dL_dmean2D[i] <= {32'h40400000, 32'h40400000};
            dL_dconic[i] <= {32'h40800000, 32'h40800000, 32'h40800000, 32'h40800000};
            dL_dopacity[i] <= 32'h40a00000;
        end




        // @(posedge clk);
        // // Test case 2: More pixels with majority ID
        // for (int i = 0; i < num_pixels; i++) begin
        //     if (i <= 2) begin
        //         is_majority_gid[i] <= 1'b1;
        //         dL_ddepth[i] <= 32'h40000000; // IEEE-754 single precision representation of 2.0
        //     end else begin
        //         is_majority_gid[i] <= 1'b0;
        //         dL_ddepth[i] <= 32'h3F800000; // IEEE-754 single precision representation of 1.0
        //     end
        // end

        @(posedge clk);
        // Reset some valid signals
        for (int i = 0; i < num_pixels; i++) begin
            is_majority_gid[i] <= 1'b0;
            dL_ddepth[i] <= 32'h0; // IEEE-754 single precision representation of 1.0

            dL_dcolor[i] <= 'h0;
            dL_dmean2D[i] <= 'h0;
            dL_dconic[i] <= 'h0;
            dL_dopacity[i] <= 'h0;
        end

        @(posedge clk);
        for (int i = 0; i < num_pixels; i++) begin
            is_majority_gid[i] <= 1'b1;
            dL_ddepth[i] <= 32'h40c00000; // IEEE-754 single precision representation of 1.0
            dL_dcolor[i] <= {32'h40e00000, 32'h40e00000, 32'h40e00000}; // IEEE-754 single precision representation of 2.0, 3.0, 4.0
            dL_dmean2D[i] <= {32'h41000000, 32'h41000000};
            dL_dconic[i] <= {32'h41200000, 32'h41200000, 32'h41200000, 32'h41200000};
            dL_dopacity[i] <= 32'h41400000;
        end



        @(posedge clk);
        for (int i = 0; i < num_pixels; i++) begin
            is_majority_gid[i] <= 1'b0;
            dL_ddepth[i] <= 32'h0; // IEEE-754 single precision representation of 1.0

            dL_dcolor[i] <= 'h0;
            dL_dmean2D[i] <= 64'h0;
            dL_dconic[i] <= 128'h0;
            dL_dopacity[i] <= 32'h0;
        end

        @(posedge clk);
        @(posedge clk);
        for (int i = 0; i < num_pixels; i = i + 2) begin
            is_majority_gid[i] <= 1'b1;
            dL_ddepth[i] <= 32'h3f800000; // IEEE-754 single precision representation of 1.0

            dL_dcolor[i] <= {32'h3f800000, 32'h3f800000, 32'h3f800000}; // IEEE-754 single precision representation of 2.0, 3.0, 4.0
            dL_dmean2D[i] <= {32'h3f800000, 32'h3f800000};
            dL_dconic[i] <= {32'h3f800000, 32'h3f800000, 32'h3f800000, 32'h3f800000};
            dL_dopacity[i] <= 32'h3f800000;
        end     
        @(posedge clk);
        for (int i = 0; i < num_pixels; i++) begin
            is_majority_gid[i] <= 1'b0;
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
        @(posedge clk);
        @(posedge clk);
        $finish;
    end


endmodule