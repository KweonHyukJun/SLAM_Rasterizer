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

module tb_push_pop_FIFO 
    #(
        parameter FIFO_depth = 16,
        parameter input_data_width = 176,
        parameter output_data_width = 176
    )
    ();

    parameter N_TEST = 84;
    
    // input
    reg clk, rst_n;
    reg [input_data_width-1:0] push_data_in;
    reg push_valid_in;
    reg pop_valid_in;

    reg [output_data_width-1:0] pop_data_out;

    wire full_out;
    wire empty_out;



    initial begin
        $fsdbDumpfile("./output_shared_submodules/shared_submodules_dump.fsdb");
        $fsdbDumpvars(0, tb_push_pop_FIFO, "+all");
    end

    // Instantiate the DUT (Device Under Test)
    push_pop_FIFO #(
        .FIFO_depth(FIFO_depth),
        .input_data_width(input_data_width),
        .output_data_width(output_data_width)
        ) 
    push_pop_FIFO_inst (
        .clk(clk),
        .rst_n(rst_n),

        .push_data_in(push_data_in),
        .push_valid_in(push_valid_in),

        .pop_valid_in(pop_valid_in),
        .pop_data_out(pop_data_out),

        .full_out(full_out),
        .empty_out(empty_out)
    );

    // Initial reg example
    always begin
        #5 clk = !clk;  // Toggle clock every half period
    end    

    integer clk_cnt = 0;

    always @(posedge clk) begin
        clk_cnt <= clk_cnt + 1;
        if (clk_cnt == 500) $finish;
    end

    initial begin
        clk <= 1'b0;
        rst_n <= 1'b0;
        push_valid_in <= 1'b0;
        push_data_in <= 0;
        pop_valid_in <= 1'b0;

        @(posedge clk);
        rst_n <= 1'b1;
        
        @ (posedge clk);
        for (int i = 0; i < FIFO_depth; i = i + 1) begin

            if (!full_out) begin
                push_valid_in <= 1'b1;
                push_data_in <= 'h10 + i;
                @(posedge clk);
            end

            else begin
                push_valid_in <= 1'b0;
                push_data_in <= 0;
                @(posedge clk);
            end
        end

        @(posedge clk);
        push_valid_in <= 1'b0;

        @(posedge clk);

        
        for (int i = 0; i < FIFO_depth; i = i + 1) begin
            if (!empty_out) begin
                pop_valid_in <= 1'b1;
                @(posedge clk);
            end

            else begin
                pop_valid_in <= 1'b0;
                @(posedge clk);
            end
        end

        @(posedge clk);
        pop_valid_in <= 1'b0;

        @ (posedge clk);
        for (int i = 0; i < FIFO_depth; i = i + 1) begin

            if (!full_out) begin
                push_valid_in <= 1'b1;
                push_data_in <= 'h20 + i;
                @(posedge clk);
            end

            else begin
                push_valid_in <= 1'b0;
                push_data_in <= 0;
                @(posedge clk);
            end
        end

        push_valid_in <= 1'b0;
        push_data_in <= 0;

        @(posedge clk);
        for (int i = 0; i < FIFO_depth; i = i + 1) begin
            if (!empty_out) begin
                pop_valid_in <= 1'b1;
                @(posedge clk);
            end

            else begin
                pop_valid_in <= 1'b0;
                @(posedge clk);
            end
        end

        pop_valid_in <= 1'b0;

        @(posedge clk);


        repeat (10) @(posedge clk);

        for (int i = 0; i < FIFO_depth / 2; i = i + 1) begin
            push_valid_in <= 1'b1;
            push_data_in <= i;
            @(posedge clk);
        end

        
        push_valid_in <= 1'b0;        
        @(posedge clk);

        for (int i = 0; i < FIFO_depth; i = i + 1) begin
            if (!empty_out && !full_out) begin
                pop_valid_in <= 1'b1;
                push_valid_in <= 1'b1;
                push_data_in <= 'h30 + i;
                @(posedge clk);
            end

            else if (!empty_out && full_out) begin
                pop_valid_in <= 1'b1;
                push_valid_in <= 1'b0;
                push_data_in <= 0;
                @(posedge clk);
            end

            else begin // empty and !full
                pop_valid_in <= 1'b0;
                push_valid_in <= 1'b1;
                push_data_in <= 'h30 + i;
                @(posedge clk);
            end


        end




        $finish;





    end



endmodule
