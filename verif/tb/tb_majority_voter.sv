module tb_majority_voter #(parameter num_pixels = 4, parameter GID_bit = 24) ();

    // Input
    reg clk;
    reg rst_n;

    reg GID_valid [num_pixels-1:0];
    reg [GID_bit-1:0] gaussian_id [num_pixels-1:0];

    reg stall_backpressure;

    wire is_majority_gid [num_pixels-1:0];



    initial begin
        $fsdbDumpfile("./output/dump.fsdb");
        $fsdbDumpvars(0, tb_majority_voter, "+all");
    end

    majority_voter #(.num_pixels(num_pixels), .GID_bit(GID_bit)) 
        majority_voter_inst (
            .clk(clk),
            .rst_n(rst_n),
            .GID_valid(GID_valid),
            .gaussian_id(gaussian_id),
            .stall_backpressure(stall_backpressure),

            .is_majority_gid(is_majority_gid)
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
            GID_valid[i] <= 1'b0;
            gaussian_id[i] <= 24'h0;
        end

        // Test case 1: Different gaussian IDs with valid signals
        @(posedge clk);
        GID_valid[0] <= 1'b1;
        GID_valid[1] <= 1'b1; 
        GID_valid[2] <= 1'b1;
        GID_valid[3] <= 1'b1;
        gaussian_id[0] <= 24'hAA0011;  // Different IDs
        gaussian_id[1] <= 24'hAA0011;  // Same as [0]
        gaussian_id[2] <= 24'hBB2233;  // Different
        gaussian_id[3] <= 24'hAA0011;  // Same as [0,1]

        @(posedge clk);
        // Test case 2: More pixels with majority ID
        for (int i = 0; i < num_pixels; i++) begin
            GID_valid[i] <= 1'b1;
            gaussian_id[i] <= 24'hAA0011; // Set all to majority ID
        end

        @(posedge clk);
        // Reset some valid signals
        for (int i = 0; i < num_pixels-1; i+=2) begin
            GID_valid[i] <= 1'b0;
        end

        @(posedge clk);
        // Test stall
        stall_backpressure <= 1'b1;
        for (int i = 0; i < num_pixels; i++) begin
            gaussian_id[i] <= 24'hBB2233; // Change IDs during stall
        end
        
        @(posedge clk);
        stall_backpressure <= 1'b0;
        for (int i = 0; i < num_pixels; i++) begin
            GID_valid[i] <= 1'b0;
            gaussian_id[i] <= 'h0; // Set all to majority ID
        end

        @(posedge clk);


        @(posedge clk);
        @(posedge clk);
        $finish;
    end


endmodule