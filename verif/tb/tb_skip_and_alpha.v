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
    reg [63:0] block_id;
    reg i_valid;

    reg [63:0] mean2D;
    reg [127:0] conic_opacity;
    reg [7:0] pixel_id;

    reg [31:0] T_before;
    
    reg skip;
    reg [31:0] alpha;

    reg [31:0] G;
    reg [63:0] d;
    reg [31:0] T;
    
    
   
    initial begin
        $fsdbDumpfile("./output/dump.fsdb");
        $fsdbDumpvars(0, tb_skip_and_alpha, "+all");
    end

    // Instantiate the DUT (Device Under Test)
    skip_and_alpha uut (
        // .clk(clk),
        // .rst_n(rst_n),
        .i_valid(i_valid),

        .block_id(block_id),
        .mean2D(mean2D),
        .conic_opacity(conic_opacity),
        .pixel_id(pixel_id),
        .T_before(T_before),

        .skip(skip),
        .alpha(alpha),        

        .G(G),
        .d(d),
        .T(T)
    );
    

    initial begin
        // clk = 1'b0;
        // rst_n = 1'b0;
        block_id = 64'h0;
        mean2D = 64'b0;
        conic_opacity = 128'b0;    
        pixel_id = 8'b0;
        T_before = 32'h0;
        // pixel_id = 8'h00; // 0 , 0
        i_valid = 1'b0;
        #10;


        i_valid = 1'b1;
        // rst_n = 1'b1;
        block_id = 64'h0000_0014_0000_000F;
        pixel_id = 8'd128;
        // xy 320.685150 250.713623
        mean2D = 64'h43a057b3_437ab6b0;
        // con_o 1.024899 -0.008134 1.010511 0.957676
        conic_opacity = 128'h3f832fe4_bc054478_3f81586d_3f752a41;
        T_before = 32'h3f643ec9; // 0.891583
        // G : 0.019332 //0.019331647
        // T : 0.908401 // 0.90840065
        // alpha: 0.018513 // 0.018513454
        // skip = 0
        // d : 0.685150 2.713623 // 0.68515015 2.713623
        #15;



        
        //xy 321.492554 246.537949
        mean2D = 64'h43a0bf0c_437689b7;

        T_before = 32'h3f688cf8; // 0.908401
        conic_opacity = 128'h3f89ac71_3c171c11_3f8c00c1_3f75207d;
        //1.075575 0.009223 1.093773 0.957527

        // d : 1.492554 -1.462051 // 1.4924011 -1.4620514
        // G : 0.095662 // 0.09566207
        // T : 1.000000 // 1. 00 
        // alpha: 0.091599 // 0.09159902

        // skip = 0
        #15;


        // T before: 0.935672
        T_before = 32'h3f6f8833;
        // xy 334.753540 262.335297
        mean2D = 64'h43a76074_43832aeb;

        // con_o 0.052369 0.000959 0.053576 0.992907
        conic_opacity = 128'h3d5680e0_3a7b6567_3d5b7282_3f7e2f27;
        // d : 14.753540 14.335297 // 14.75061 14.335297
        // G : 0.000011 // 0.000011114289
        // T : 0.935672 // 0.935672
        // alpha: 0.000011 // 0
        // skip = 1

        #15;

        // T before: 0.935672
        T_before = 32'h3f6f8833;
        // xy 323.035248 266.635742
        mean2D = 64'h43a18483_43855160;
        // con_o 0.091709 -0.001959 0.049807 0.950240
        conic_opacity = 128'h3dbbd1ee_bb006291_3d4c026d_3f7342ee;


        // d : 3.035248 18.635742 // 3.0353088 18.635742
        // G : 0.000128 // 0.00012839555 
        // T : 0.935672 
        // alpha: 0.000122 
        // skip 1 


        #15;
        $display("Test is finished without Error!\n");


        $finish;
    end

endmodule
