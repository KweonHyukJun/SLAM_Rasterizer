
`define MAX_CLOCK_COUNT 100


module tb_tree_logic_comb;

    parameter precision = 16;
    parameter num_pixels = 16;

    integer max_clock_count = `MAX_CLOCK_COUNT;

    reg clk;
    reg rst_n;

    reg REB_signal [num_pixels-1:0];

    reg [precision-1:0] next_n_contrib_from_SRAM [num_pixels-1:0];

    wire REB [num_pixels-1:0];

    wire [precision-1:0] max_n_contrib;


    initial begin
        $fsdbDumpfile("../output_shared_submodules/shared_submodules_dump.fsdb");
        $fsdbDumpvars(0, tb_tree_logic_comb, "+all");
    end

    tree_logic_comb #(
        .precision(precision),
        .num_pixels(num_pixels)
    )
    tree_logic_comb_inst (
        .clk(clk),
        .rst_n(rst_n),

        .REB_signal(REB_signal),
        .next_n_contrib_from_SRAM(next_n_contrib_from_SRAM),

        .REB(REB),
        .max_n_contrib(max_n_contrib)
    );

    always #5 clk = ~clk;

    integer clk_cnt = 0;

    always @(posedge clk) begin
        clk_cnt <= clk_cnt + 1;
        if (clk_cnt == max_clock_count) $finish;
    end

    initial begin
        clk <= 0;
        rst_n <= 0;

        for (int i = 0; i < num_pixels; i++) begin
            REB_signal[i] <= 1'b1;
            next_n_contrib_from_SRAM[i] <= 0;
        end

        @(posedge clk);
        rst_n <= 1;

        @(posedge clk);

        for (int i = 0; i < num_pixels; i++) begin
            REB_signal[i] <= 1'b0;
        end

        @(posedge clk);


        for (int i = 0; i < num_pixels; i++) begin
            // REB_signal[i] <= 1'b1;
            next_n_contrib_from_SRAM[i] <= i;
        end

        @(posedge clk);

        for (int i = 0; i < num_pixels; i++) begin
            // REB_signal[i] <= 1'b1;
            next_n_contrib_from_SRAM[i] <= num_pixels - i;
        end

        @(posedge clk);

        for (int i = 0; i < num_pixels; i++) begin
            REB_signal[i] <= 1'b1;
            next_n_contrib_from_SRAM[i] <= num_pixels / 2;
        end

        @ (posedge clk);
        for (int i = 0; i < num_pixels; i++) begin
            next_n_contrib_from_SRAM[i] <= 'd0;
        end

        @(posedge clk);
        @(posedge clk);
        @(posedge clk);

        $finish;


        
        

        
        
        

    end



    
endmodule