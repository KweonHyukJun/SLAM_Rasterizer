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

module tb_skip_and_alpha #(BLOCK_SIZE = 16, exponent_bit = 8, mantissa_bit= 23, precision = 32)();
    
    //input
    reg clk, rst_n;

    reg [15:0] block_id;
    reg i_valid;

    reg [( 2 * precision )-1:0] mean2D;
    reg [(4 * precision) - 1:0] conic_opacity;
    reg [(2 * $clog2(BLOCK_SIZE) - 1):0] pixel_id;

    wire skip_out;
    wire [precision-1:0] alpha_out;

    wire [precision-1:0] G_out;
    wire [( 2 * precision )-1:0] d_out;

    wire skip_and_alpha_done_out;

    localparam latency = 6;
    integer i = 0;
    
    initial begin
        $fsdbDumpfile("./output/dump.fsdb");
        $fsdbDumpvars(0, tb_skip_and_alpha, "+all");
    end

    // Instantiate the DUT (Device Under Test)
    skip_and_alpha #( .BLOCK_SIZE(BLOCK_SIZE), .exponent_bit(exponent_bit), .mantissa_bit(mantissa_bit), .precision(precision)) 
    uut (
        .clk(clk),
        .rst_n(rst_n),
        .i_valid(i_valid),

        .block_id(block_id),

        .mean2D(mean2D),
        .conic_opacity(conic_opacity),
        .pixel_id(pixel_id),

        .skip_out(skip_out),
        .alpha_out(alpha_out),        

        .G_out(G_out),
        .d_out(d_out),

        .conic_opacity_out(conic_opacity_out),


        .skip_and_alpha_done_out(skip_and_alpha_done_out)
    );

    // Initial reg example
    // uut.T0 = 32'h1;
    always begin
        #5 clk = !clk;  // Toggle clock every half period
    end    

    initial begin
        clk = 1'b0;
        rst_n = 1'b1;
        block_id = 'h0;
        mean2D = 'b0;
        conic_opacity = 'b0;    
        pixel_id = 'b0;
        // pixel_id = 8'h00; // 0 , 0
        i_valid = 1'b0;
        
        uut.skip_out = 1'b0;

        uut.G_out = 'h0;
        uut.d_out = 'h0;
        uut.alpha_out = 'h0;
        uut.conic_opacity_out = 'h0;

        uut.skip_and_alpha_done_out = 'b0;

        uut.d1 = 'h0;
        uut.d2 = 'h0;
        uut.d3 = 'h0;
        uut.d4 = 'h0;
        uut.d5 = 'h0;

        uut.G4 = 'h0;
        uut.G5 = 'h0;

        uut.dxx2 = 'h0;
        uut.dxy2 = 'h0;
        uut.dyy2 = 'h0;

        uut.skip3 = 'b0;
        uut.skip4 = 'b0;
        uut.skip5 = 'b0;

        uut.pixel_id0 = 'h0;
        uut.power3 = 'h0;
        uut.alpha5 = 'h0;

        uut.block_id0 = 'h0;

        uut.conic_opacity0 = 'h0;
        uut.conic_opacity1 = 'h0;
        uut.conic_opacity2 = 'h0;
        uut.conic_opacity3 = 'h0;
        uut.conic_opacity4 = 'h0;
        uut.conic_opacity5 = 'h0;

        uut.i_valid0 = 'b0;
        uut.i_valid1 = 'b0;
        uut.i_valid2 = 'b0;
        uut.i_valid3 = 'b0;
        uut.i_valid4 = 'b0;
        uut.i_valid5 = 'b0;

        uut.mean2D0 = 'h0;


        @(posedge clk);
        @(posedge clk);

        // rst_n = 1'b1;
        i_valid = 1'b1;
        block_id = 'h140F;
        pixel_id = 'd128;
        // xy 320.685150 250.713623
        // mean2D = 64'h43a057b3_437ab6b0;
        // mean2D = 64'h43a057b3_437ab6b0;
        mean2D = 64'h43a057b3_437ab6b0;
        // con_o 1.024899 -0.008134 1.010511 0.957676
        conic_opacity = 128'h3f832fe4_bc054478_3f81586d_3f752a41;
        // G : 0.019332 //0.019331647
        // alpha: 0.018513 // 0.018513454
        // skip = 0
        // d : 0.685150 2.713623 // 0.68515015 2.713623
        

        //additional input
        @(posedge clk);
        i_valid = 1'b1;
        block_id = 'h140F;
        pixel_id = 'd128;
        //xy 321.492554 246.537949
        mean2D = 64'h43a0bf0c_437689b7;
        conic_opacity = 128'h3f89ac71_3c171c11_3f8c00c1_3f75207d;
        //1.075575 0.009223 1.093773 0.957527

        // d : 1.492554 -1.462051 // 1.4924011 -1.4620514
        // G : 0.095662 // 0.09566207
        // alpha: 0.091599 // 0.09159902

        // skip = 0


        @(posedge clk);
        i_valid = 1'b1;
        block_id = 'h140F;
        pixel_id = 'd128;
        // xy 334.753540 262.335297
        mean2D = 64'h43a76074_43832aeb;
        // con_o 0.052369 0.000959 0.053576 0.992907
        conic_opacity = 128'h3d5680e0_3a7b6567_3d5b7282_3f7e2f27;
        // d : 14.753540 14.335297 // 14.75061 14.335297
        // G : 0.000011 // 0.000011114289
        // alpha: 0.000011 // 0
        // skip = 1


        @(posedge clk);
        i_valid = 1'b1;
        block_id = 'h140F;
        pixel_id = 'd128;
        // xy 323.035248 266.635742
        mean2D = 64'h43a18483_43855160;
        // con_o 0.091709 -0.001959 0.049807 0.950240
        conic_opacity = 128'h3dbbd1ee_bb006291_3d4c026d_3f7342ee;

        // d : 3.035248 18.635742 // 3.0353088 18.635742
        // G : 0.000128 // 0.00012839555 
        // alpha: 0.000122 
        // skip 1 
        @(posedge clk);
        i_valid = 1'b0;

        for (i = 0; i < latency; i = i + 1) begin
          @(posedge clk);  // Wait for a positive edge of the clock
        end

        @(posedge clk);
        @(posedge clk);
        $display("Test is finished without Error!\n");


        $finish;
    end

endmodule
