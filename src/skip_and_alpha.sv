module skip_and_alpha
    #(
        parameter BLOCK_SIZE = 16,
        parameter exponenet_bit = 8,
        parameter mantissa_bit = 23,
        parameter precision = 32
    )
    (
    input wire clk,
    input wire rst_n,

    input wire [63:0] block_id, // block id | X | Y |

    input wire done,

    input wire [63:0] mean2D , // fp32 | X | Y | 
    input wire [127:0] conic_opacity, // fp32 | X | Y | Z | W |
    input wire [(2 * $clog2(BLOCK_SIZE) - 1): 0] pixel_id, // int 0 ~ 255 

    output reg skip, // can be work as valid
    output reg [31:0] alpha,

    // for test
    output reg [31:0] temporary_output // float 32
    );

    
    localparam ieee_compliance = 1'b0;
    localparam [2:0] inst_rnd = 3'b0;

    // Intermediate variables
    reg [63:0] d; // fp32 (int32 calculations needed) | X | Y |
    reg [31:0] power;
    
    
    wire [7:0] current_pixel_helper;
    wire [63:0] current_pixel;
    wire [31:0] temp1, temp2, temp3, temp4, temp5;
    wire [63:0] current_pixel_fp32;
    wire [7:0] status_inst;
    wire [31:0] d_xx, d_yy, d_xy;


    assign current_pixel = {block_id[(63-$clog2(BLOCK_SIZE)):32], pixel_id[$clog2(BLOCK_SIZE)-1:0], block_id[(31-$clog2(BLOCK_SIZE)):0], pixel_id[(2*$clog2(BLOCK_SIZE))-1:$clog2(BLOCK_SIZE)]}; // 32bit int | X | Y |

    // Instance of DW_fp_i2flt
    DW_fp_i2flt #(mantissa_bit, exponenet_bit, precision, 1)
	  fp_pixel_x ( .a(current_pixel[63:32]), .rnd(inst_rnd), .z(current_pixel_fp32[63:32]), .status(status_inst) );
    // Instance of DW_fp_i2flt
    DW_fp_i2flt #(mantissa_bit, exponenet_bit, precision, 1)
	  fp_pixel_y ( .a(current_pixel[31:0]), .rnd(inst_rnd), .z(current_pixel_fp32[31:0]), .status(status_inst) );


    // Instance of DW_fp_add
    DW_fp_add #(mantissa_bit, exponenet_bit, 0)
	  d_x ( .a(mean2D[63:32]), .b({!current_pixel_fp32[63] ,current_pixel_fp32[62:32]}), .rnd(inst_rnd), .z(d[63:32]), .status(status_inst) );
    // Instance of DW_fp_add
    DW_fp_add #(mantissa_bit, exponenet_bit, 0)
	  d_y ( .a(mean2D[31:0]), .b({!current_pixel_fp32[31] ,current_pixel_fp32[30:0]}), .rnd(inst_rnd), .z(d[31:0]), .status(status_inst) );
    
    
    // Instance of DW_fp_mult
    DW_fp_mult #(mantissa_bit, exponenet_bit, ieee_compliance, 0)
	  dxx ( .a(d[63:32]), .b(d[63:32]), .rnd(inst_rnd), .z(d_xx), .status(status_inst) );

    DW_fp_mult #(mantissa_bit, exponenet_bit, ieee_compliance, 0)
	  dyy ( .a(d[31:0]), .b(d[31:0]), .rnd(inst_rnd), .z(d_yy), .status(status_inst) );

    DW_fp_mult #(mantissa_bit, exponenet_bit, ieee_compliance, 0)
	  dxy ( .a(d[63:32]), .b(d[31:0]), .rnd(inst_rnd), .z(d_xy), .status(status_inst) );


    // connected to exponent
    DW_fp_mult #(mantissa_bit, exponenet_bit, ieee_compliance, 0)
	  t1 ( .a(d_xx), .b(conic_opacity[127:96]), .rnd(inst_rnd), .z(temp1), .status(status_inst) );

    // connected to exponent
    DW_fp_mult #(mantissa_bit, exponenet_bit, ieee_compliance, 0)
	  t2 ( .a(d_yy), .b(conic_opacity[63:32]), .rnd(inst_rnd), .z(temp2), .status(status_inst) );
    
    // connected to exponent
    DW_fp_mult #(mantissa_bit, exponenet_bit, ieee_compliance, 0)
	  t3 ( .a(d_xy), .b(conic_opacity[95:64]), .rnd(inst_rnd), .z(temp3), .status(status_inst) );

    DW_fp_add #(mantissa_bit, exponenet_bit, 0)
	  t4 ( .a(temp1), .b(temp2), .rnd(inst_rnd), .z(temp4), .status(status_inst) );



    DW_fp_add #(mantissa_bit, exponenet_bit, 0)
	  exp ( .a({!temp4[31], temp4[30:23] - 8'b1, temp4[22:0]}), .b({!temp3[31],temp3[30:0]}), .rnd(inst_rnd), .z(power), .status(status_inst) );



    



    // Combinational logic
    always_comb begin
        alpha = 32'b0;
        skip = done;

        temporary_output = power;
    end
endmodule


	// const float2 xy = collected_xy[j];
	// const float2 d = { xy.x - pixf.x, xy.y - pixf.y };
	// const float4 con_o = collected_conic_opacity[j];
	// const float power = -0.5f * (con_o.x * d.x * d.x + con_o.z * d.y * d.y) - con_o.y * d.x * d.y;
	// skip |= power > 0.0f;

	// const float G = exp(power);
	// const float alpha = min(0.99f, con_o.w * G);
	// skip |= alpha < 1.0f / 255.0f;