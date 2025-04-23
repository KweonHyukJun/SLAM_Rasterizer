
`define MAX_CLOCK_COUNT 100


module tb_tree_logic_wire_last_input_add;

    parameter precision = 16;
    parameter num_pixels = 16;

    integer max_clock_count = `MAX_CLOCK_COUNT;

    reg clk;
    reg rst_n;

    reg last_input_done [num_pixels-1:0];

    wire [$clog2(num_pixels):0] last_input_done_out;


    initial begin
        $fsdbDumpfile("../output_shared_submodules/shared_submodules_dump.fsdb");
        $fsdbDumpvars(0, tb_tree_logic_wire_last_input_add, "+all");
    end

    tree_logic_wire_last_input_add #(
        .num_pixels(num_pixels)
    )
    tree_logic_wire_inst (
        .clk(clk),
        .rst_n(rst_n),

        .last_input_done(last_input_done),

        .last_input_done_out(last_input_done_out)
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
            last_input_done[i] <= 1'b0;
        end

        @(posedge clk);
        rst_n <= 1;

        @(posedge clk);

        for (int i = 0; i < num_pixels; i++) begin
            last_input_done[i] <= 1'b1;
        end

        @(posedge clk);


        for (int i = 0; i < num_pixels; i++) begin
            last_input_done[i] <= 1'b1;
        end

        @(posedge clk);

        for (int i = 0; i < num_pixels; i++) begin
            last_input_done[i] <= 1'b0;
        end


        @(posedge clk);

        for (int i = 0; i < num_pixels; i = i + 2) begin
            last_input_done[i] <= 1'b1;
        end

        @(posedge clk);

        for (int i = 0; i < num_pixels; i = i + 1) begin
            last_input_done[i] <= 1'b0;
        end

        @(posedge clk);

        last_input_done[0] <= 1'b1;

        @(posedge clk);


        $finish;


        
        

        
        
        

    end



    
endmodule