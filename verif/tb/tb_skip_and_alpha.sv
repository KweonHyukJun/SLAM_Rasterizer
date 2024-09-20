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
    reg [63:0] block_id;
    
    reg [63:0] mean2D;
    reg [127:0] conic_opacity;
    reg [7:0] pixel_id;
    
    wire skip;
    wire [31:0] alpha;
    wire [63:0] pixel_using;
    
   
    
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
        block_id = 64'b0;
        mean2D = 64'b0;
        conic_opacity = 128'b0;    
        pixel_id = 8'b0;
        done = 1'b0;
        

        pixel_id = 8'h0F; // 15
        #10;
        
        pixel_id = 8'h1F; // 31
        #10;

        pixel_id = 8'h55; // 255
        #10;

        
        mean2D = 64'h431b_c7ae_4304_91ec; // 155.78
        block_id = 64'h0000_000F_0000_000D; // 16
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
