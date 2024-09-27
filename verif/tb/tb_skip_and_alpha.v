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
    reg done;
    reg [63:0] block_id;
    
    reg [63:0] mean2D;
    reg [127:0] conic_opacity;
    reg [7:0] pixel_id;

    reg [31:0] T_before;
    
    wire skip;
    wire [31:0] alpha;

    wire [31:0] G;
    wire [63:0] d;
    wire [31:0] T;
    
   
    initial begin
        $fsdbDumpfile("./output/dump.fsdb");
        $fsdbDumpvars(0, tb_skip_and_alpha, "+all");
    end

    // Instantiate the DUT (Device Under Test)
    skip_and_alpha uut (
        .block_id(block_id),
        .done(done),
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
        block_id = 64'h0000_0014_0000_000F;
        mean2D = 64'b0;
        conic_opacity = 128'b0;    
        pixel_id = 8'b0;
        done = 1'b0;
        T_before = 32'h0;
        // pixel_id = 8'h00; // 0 , 0
        #30;


        

        // xy 328.515717 273.968689
        mean2D = 64'h43a44203_4388fbfe;
        // con_o 0.024017 -0.001695 0.022108 0.667107
        conic_opacity = 128'h3cc4bf4d_bade2ac3_3cb51bd6_3f2ac786;
        T_before = 32'h3ee8a7e7;
        // G : 0.000352
        // T : 0.454406
        // alpha: 0.000235
        // skip = 1
        #10;



        
        //xy 335.039948 256.801331
        mean2D = 64'h43a7851d_43806692;
        // conic opacity : 0.0069 0.0063 0.0083 0.9328
        T_before = 32'h3ee8a7e7;
        conic_opacity = 128'h3be21965_3bce703b_3c07fcb9_3f6ecbfb;
        // G : 0.064827
        // T : 0.475214
        // alpha: 0.043787
        // skip : 0
        #10;

        done = 1'b1;
        #10;

        $display("Test is finished without Error!\n");


        $finish;
    end

endmodule
