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
    
   
    initial begin
        $fsdbDumpfile("./output/dump.fsdb");
        $fsdbDumpvars(0, tb_skip_and_alpha, "+all");
    end

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
        .alpha(alpha)
    );
    
    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        block_id = 64'h0000_0014_0000_000F;
        mean2D = 64'b0;
        conic_opacity = 128'b0;    
        pixel_id = 8'b0;
        done = 1'b0;


        // pixel_id = 8'h00; // 0 , 0
        #30;


        
        // xy : 354.3882 230.3951
        mean2D = 64'h43b131b1_43666525;
        //conic opacity : 0.0146 0.0146 0.0203 0.9768
        conic_opacity = 128'h3c6f34d7_3c6f34d7_3ca64c30_3f7a0f91;

        $display("Expected power %h\n",32'hc0989e1b);
        $display("Expected alpha %h\n",32'h3c07fcb9);
        $display("Result alpha %h\n\n",alpha);
        #10;



        
        // xy : 320.0527 232.1980
        mean2D = 64'h43a006bf_436832b0;
        // conic opacity : 0.0069 0.0063 0.0083 0.9328
        conic_opacity =128'h3be21965_3bce703b_3c07fcb9_3f6ecbfb;

        $display("Expected alpha %h\n",32'h3f3a0f91);
        $display("Result alpha %h\n\n",alpha);
        #10;



        $display("Test is finished without Error!\n");


        $finish;
    end

endmodule
