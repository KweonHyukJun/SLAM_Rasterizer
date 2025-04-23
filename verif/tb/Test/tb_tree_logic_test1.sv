`define MAX_CLOCK_COUNT 100

module tb_tree_logic_test1;

    parameter Banks = 16;
    parameter Encoder_outs = 4;

    integer max_clock_count = `MAX_CLOCK_COUNT;

    reg clk;
    reg rst_n;

    reg last_input_done_from_encoder_out [Banks * Encoder_outs-1:0];  // 16 banks, 4 encoder_outs per bank

    wire last_input_done_to_4x_fifo_valid_comb [Banks-1:0];  // One output per bank
    integer count [Banks-1:0];

    initial begin
        $fsdbDumpfile("../output_shared_submodules/shared_submodules_dump.fsdb");
        $fsdbDumpvars(0, tb_tree_logic_test1, "+all");
    end

    // Instantiate the unit under test (UUT)
    tree_logic_test1 #(
        .Banks(Banks),
        .Encoder_outs(Encoder_outs)
    )
    tree_logic_wire_inst (
        .last_input_done_from_encoder_out(last_input_done_from_encoder_out),
        .last_input_done_to_4x_fifo_valid_comb(last_input_done_to_4x_fifo_valid_comb)
    );

    // Clock generation
    always #5 clk = ~clk;

    integer clk_cnt = 0;
    always @(posedge clk) begin
        clk_cnt <= clk_cnt + 1;
        if (clk_cnt == max_clock_count) $finish;
    end

    // Initial block for stimulus generation
    initial begin
        clk <= 0;
        rst_n <= 0;

        // Initialize the inputs
        for (int i = 0; i < Banks * Encoder_outs; i++) begin
            last_input_done_from_encoder_out[i] <= 1'b0;  // Set all outputs to 0 initially
        end

        @(posedge clk);
        rst_n <= 1;  // Release reset

        @(posedge clk);

        // Test Case 1: Set multiple encoder outputs in different banks to 1
        // Bank 0: Set encoder_outs 0 and 1 to 1
        last_input_done_from_encoder_out[0] <= 1'b1;
        last_input_done_from_encoder_out[1] <= 1'b1;

        // Bank 1: Set encoder_outs 2 and 3 to 1
        last_input_done_from_encoder_out[4] <= 1'b1;
        last_input_done_from_encoder_out[5] <= 1'b1;

        // Bank 2: Set encoder_outs 0 and 2 to 1
        last_input_done_from_encoder_out[8] <= 1'b1;
        last_input_done_from_encoder_out[10] <= 1'b1;

        // Bank 3: Set encoder_outs 1 and 3 to 1
        last_input_done_from_encoder_out[12] <= 1'b1;
        last_input_done_from_encoder_out[15] <= 1'b1;

        @(posedge clk);

        // Check if the bank output is 1 if more than one encoder output is 1 for a bank
        // Check the logic for each bank
        for (int bank = 0; bank < Banks; bank = bank + 1) begin
            count[bank] = 0;
            for (int encoder_out = 0; encoder_out < Encoder_outs; encoder_out = encoder_out + 1) begin
                if (last_input_done_from_encoder_out[bank * Encoder_outs + encoder_out]) begin
                    count[bank] = count[bank] + 1;  // Count number of 1's for this bank
                end
            end

            // If more than one `encoder_out` is 1, the bank output should be 1
            if (count[bank] > 1) begin
                if (last_input_done_to_4x_fifo_valid_comb[bank] != 1'b1) begin
                    $display("ERROR: clk_cnt %0d, Bank %0d should return 1, but it returned %b", clk_cnt, bank, last_input_done_to_4x_fifo_valid_comb[bank]);
                end
            end else begin
                if (last_input_done_to_4x_fifo_valid_comb[bank] != 1'b0) begin
                    $display("ERROR: clk_cnt %0d, Bank %0d should return 0, but it returned %b", clk_cnt, bank, last_input_done_to_4x_fifo_valid_comb[bank]);
                end
            end
        end

        @(posedge clk);

        // Test Case 2: Set only one encoder output to 1 in each bank
        for (int bank = 0; bank < Banks; bank = bank + 1) begin
            last_input_done_from_encoder_out[bank * Encoder_outs] <= 1'b1;  // Set first encoder_out to 1 for each bank
        end

        @(posedge clk);

        // Check if the bank output is 0 (since only one encoder output is 1)
        for (int bank = 0; bank < Banks; bank = bank + 1) begin
            if (last_input_done_to_4x_fifo_valid_comb[bank] != 1'b0) begin
                $display("ERROR: clk_cnt %0d, Bank %0d should return 0, but it returned %b", clk_cnt, bank, last_input_done_to_4x_fifo_valid_comb[bank]);
            end
        end

        $finish;
    end

endmodule
