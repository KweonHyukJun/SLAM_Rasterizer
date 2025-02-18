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

module tb_Priority_encoder_FIFO 
    #(
        parameter Encoder_out = 4,
        parameter Encoder_in = 16,
        parameter FIFO_depth = 16,
        parameter DATA_WIDTH = 200
    )
    ();

    parameter N_TEST = 84;
    
    // input
    reg clk, rst_n;
    reg [DATA_WIDTH-1:0] push_data_in [Encoder_in-1:0];
    reg push_valid_in;
    reg push_valid_index_in [Encoder_in-1:0];
    wire pop_valid_in;

    wire [DATA_WIDTH-1:0] pop_data_out [Encoder_out-1:0];

    wire full_out;
    wire empty_out;
    wire pop_valid_out [Encoder_out-1:0];

    wire push_valid_in_grant_out [Encoder_in-1:0];



    initial begin
        $fsdbDumpfile("../output_shared_submodules/shared_submodules_dump.fsdb");
        $fsdbDumpvars(0, tb_Priority_encoder_FIFO, "+all");
    end

    // Instantiate the DUT (Device Under Test)
    Priority_encoder_FIFO #(
        .FIFO_depth(FIFO_depth),
        .DATA_WIDTH(DATA_WIDTH),
        .Encoder_out(Encoder_out),
        .Encoder_in(Encoder_in)
        ) 
    Priority_encoder_FIFO_inst (
        .clk(clk),
        .rst_n(rst_n),

        .push_data_in(push_data_in),
        .push_valid_in(push_valid_in),
        .push_valid_index_in(push_valid_index_in),

        .push_valid_in_grant_out(push_valid_in_grant_out),

        .pop_valid_in(pop_valid_in),
        .pop_data_out(pop_data_out),
        .pop_valid_out(pop_valid_out),

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


        for (int i = 0 ; i < Encoder_in ; i = i + 1) begin
            push_data_in[i] <= 0;
            push_valid_index_in[i] <= 0;
        end



        @(posedge clk);
        rst_n <= 1'b1;


        
        @ (posedge clk);
        for (int i = 0 ; i < Encoder_in ; i = i + 1) begin
            push_data_in[i] <= 'h10 + i;            
            
        end

        for (int i = 0 ; i < Encoder_in / 2 + 6 ; i = i + 1) begin
            push_valid_index_in[i] <= 1'b1;
        end
        push_valid_in <= 1'b1;

        @ (posedge clk);
        for (int i = 0 ; i < Encoder_in ; i = i + 1) begin
            push_data_in[i] <= 'h0;
            push_valid_index_in[i] <= 1'b0;
        end
        push_valid_in <= 1'b0;
        
        @ (posedge clk);
        for (int i = 0 ; i < Encoder_in ; i = i + 1) begin
            push_data_in[i] <= 'h20 + i;
            push_valid_index_in[i] <= 1'b1;
        end
        push_valid_in <= 1'b1;


        // @ (posedge clk);
        // for (int i = 0 ; i < Encoder_in ; i = i + 1) begin
        //     push_data_in[i] <= 'h30 + i;
        // end


        @(posedge clk);
        for (int i=0 ; i < Encoder_in ; i = i + 1) begin
            push_data_in[i] <= 0;
            push_valid_index_in[i] <= 1'b0;
        end
        push_valid_in <= 1'b0;

        repeat(20) @(posedge clk);

        @(posedge clk);

        $finish;
    end

    
    // always @ (posedge clk) begin
    //     if (!rst_n) begin
    //         for (int i = 0 ; i < Encoder_in ; i = i + 1) begin
    //             push_data_in[i] <= i;
    //         end
    //     end 
    //     else begin
    //         if (!full_out) begin
    //             for (int i = 0 ; i < Encoder_in ; i = i + 1) begin
    //                 push_data_in[i] <= clk_cnt * Encoder_in + i;
    //             end
    //         end
    //     end
    // end

    assign pop_valid_in = !empty_out;
    // assign push_valid_in = !full_out;


endmodule
