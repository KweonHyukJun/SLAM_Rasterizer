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

module tb_skip_and_alpha();
    //input
    reg clk, rst_n, done;
    reg [31:0] block_id [1:0];
    
    reg [31:0] mean2D [1:0];
    reg [31:0] conic_opacity [3:0];
    reg [7:0] pixel_id;
    
    wire skip;
    wire [31:0] alpha;
    wire [31:0] pixel_using [1:0];
    
   
    
    // Instantiate the DUT (Device Under Test)
    skip_and_alpha uut (
        .clk(clk),
        .rst_n(rst_n),
        .block_id(block_id),
        .done(done),
        .mean2D(mean2D),
        .conic_opacity(conic_opacity),
        .pixel_id(pixel_id),
        .skip(skip),
        .alpha(alpha),

        .temporary_output(pixel_using)
    );
    
    initial begin
        $fsdbDumpfile("./output/dump.fsdb");
        $fsdbDumpvars(0, tb_skip_and_alpha, "+all");

        clk = 0;
        rst_n = 0;
        block_id[0] = 32'b0;
        block_id[1] = 32'b0;
        mean2D[0] = 32'b0;
        mean2D[1] = 32'b0;
        conic_opacity[0] = 32'b0;    
        conic_opacity[1] = 32'b0;
        conic_opacity[2] = 32'b0;
        conic_opacity[3] = 32'b0;    
        pixel_id = 8'b0;
        done = 1'b0;
        

        pixel_id = 8'h0F; // 15
        #10;
        
        pixel_id = 8'h1F; // 31
        #10;

        pixel_id = 8'h55; // 255
        #10;

        
        mean2D[1] = 32'h431b_c7ae; // 155.78
        mean2D[0] = 32'h4304_91ec; // 132.57
        block_id[1] = 32'h0000_000F; // 16
        block_id[0] = 32'h0000_000D; // 13
        pixel_id = 8'h0F; //15
        #10;
        
        pixel_id = 8'h1F; //31 
        #10;
        
        pixel_id = 8'h55; //255
        #10;


        $display("Test is finished without Error!");


        $finish;
    end

endmodule
