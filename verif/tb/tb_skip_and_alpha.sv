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
    wire [31:0] power_output,alpha_output;

    wire [31:0] temporary_output;
    
   
    // initial begin
    //     $fsdbDumpfile("../output/dump.fsdb");
    //     $fsdbDumpvars(0, tb_skip_and_alpha, "+all");
    // end

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

        .temporary_output(temporary_output),
        .power_output(power_output),
        .alpha_output(alpha_output)
    );
    
    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        block_id = 64'b0;
        mean2D = 64'b0;
        conic_opacity = 128'b0;    
        pixel_id = 8'b0;
        done = 1'b0;
        
        conic_opacity = 128'h4020_0000_4060_0000_3fc0_0000_0000_0000 ; // x: 2.5 , y: 3.5, z: 1.5
        pixel_id = 8'h0F; // 15
        #10;
        
        pixel_id = 8'h1F; // 31
        #10;

        pixel_id = 8'h55; // 255
        #10;

        
        conic_opacity = 128'h4020_0000_4060_0000_3fc0_0000_0000_0000 ; // x: 2.5 , y: 3.5, z: 1.5
        mean2D = 64'h431B_C7AE_4304_91EC; // 155.78
        block_id = 64'h0000_000F_0000_000D; // 16, 13
        pixel_id = 8'h0F; //15
        #10;
        
        pixel_id = 8'h1F; //31 
        #10;
        
        pixel_id = 8'h55; //255
        #10;


        $display("Test is finished without Error!\n");


        $finish;
    end

endmodule
