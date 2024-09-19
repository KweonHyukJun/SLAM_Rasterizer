module skip_and_alpha
    #(parameter BLOCK_SIZE = 16)
    (
    input wire clk,
    input wire rst_n,

    input wire [31:0] block_id [1:0], // block id x:1 y:0 (int)

    input wire done,

    input wire [31:0] mean2D [1:0], // fp32 {y, x} = {0, 1}
    input wire [31:0] conic_opacity [3:0], // fp32 {w, z, y, x} = {0, 1, 2 ,3}
    input wire [7:0] pixel_id, // int 0 ~ 255 

    output reg skip, // can be work as valid
    output reg [31:0] alpha,

    // for test
    output reg [31:0] pixel_using [1:0] // int 32 x: 1 y:0
    );

    // Intermediate variables
    reg [31:0] d [1:0]; // fp32 (int32 calculations needed)
    reg [31:0] power;
    
    
    wire [7:0] current_pixel_helper;
    wire [31:0] current_pixel [1:0];
    wire [31:0] temp1, temp2, temp3;
    wire [31:0] current_pixel_fp32 [1:0];
    wire [7:0] status_inst;

    assign current_pixel[1] = {block_id[1][(31-$clog2(BLOCK_SIZE)):0], pixel_id[3:0]}; // pixel coordinate x int32
    assign current_pixel[0] = {block_id[0][(31-$clog2(BLOCK_SIZE)):0], pixel_id[7:4]}; // pixel coordinate x int32

    // Instance of DW_fp_i2flt
    DW_fp_i2flt #(23, 8, 32, 1)
	  U1 ( .a(current_pixel[1]), .rnd(1'b0), .z(current_pixel_fp32[1]), .status(status_inst) );
    // Instance of DW_fp_i2flt
    DW_fp_i2flt #(23, 8, 32, 1)
	  U2 ( .a(current_pixel[0]), .rnd(1'b0), .z(current_pixel_fp32[0]), .status(status_inst) );



    // Combinational logic
    always_comb begin
        alpha = 32'b0;

        pixel_using[0] = current_pixel_fp32[0];
        pixel_using[1] = current_pixel_fp32[1];

        // pixel_using[0] = current_pixel[0];
        // pixel_using[1] = current_pixel[1];
        skip = done;
    end

endmodule
