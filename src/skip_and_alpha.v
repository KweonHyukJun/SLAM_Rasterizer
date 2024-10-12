module skip_and_alpha
    #(
        parameter BLOCK_SIZE = 16,
        parameter exponent_bit = 8,
        parameter mantissa_bit = 15,
        parameter precision = 24
    )
    (
    input wire clk,
    input wire rst_n,

    input wire [15:0] block_id, // block id | X | Y |

    input wire [( 2 * precision ) - 1 : 0] mean2D , // fp32 | X | Y | 
    input wire [(4 * precision) - 1:0] conic_opacity, // fp32 | X | Y | Z | W |
    input wire [(2 * $clog2(BLOCK_SIZE) - 1): 0] pixel_id, // int 0 ~ 255 

    // input wire [precision - 1 : 0] T_before, 
    input wire i_valid,

    output reg skip_out, // can be work as valid
    output reg [precision - 1 : 0] G_out,
    output reg [( 2 * precision ) - 1 : 0] d_out,
    output reg [precision - 1 : 0] alpha_out,
    output reg [(4 * precision) - 1:0] conic_opacity_out, // fp32 | X | Y | Z | W |

    output wire skip_and_alpha_done_out
    
    );
    // synopsys template
    localparam ieee_compliance = 1'b0;
    localparam [2:0] inst_rnd [1:15] = {3'b0, 3'b0, 3'b0, 3'b0, 3'b0, 3'b0, 3'b0, 3'b0, 3'b0, 3'b0, 3'b0, 3'b0, 3'b0, 3'b0, 3'b0};

    // register declaration

    reg [( 2 * precision ) - 1 : 0] d1, d2, d3, d4, d5;
    reg [precision - 1 : 0] G4, G5;
    reg [precision - 1 : 0] dxx2, dxy2, dyy2;
    reg skip3, skip4, skip5;

    reg i_valid0, i_valid1, i_valid2, i_valid3, i_valid4, i_valid5;
    reg [( 2 * precision ) - 1 : 0] mean2D0, mean2D1, mean2D2, mean2D3, mean2D4, mean2D5;
    reg [( 4 * precision ) - 1 : 0] conic_opacity0, conic_opacity1, conic_opacity2, conic_opacity3, conic_opacity4, conic_opacity5;
    reg [(2 * $clog2(BLOCK_SIZE) - 1): 0] pixel_id0, pixel_id1, pixel_id2, pixel_id3, pixel_id4, pixel_id5;



    // // Intermediate variables
    wire [( 2 * precision ) - 1 : 0] d_temp; // fp32 (int32 calculations needed) | X | Y |
    wire [precision - 1 : 0] power;
    
    wire [(2 * precision) - 1 : 0] current_pixel;
    wire [precision - 1 : 0] temp1, temp2, temp3, temp4;
    wire [( 2 * precision ) - 1 : 0] current_pixel_fp;
    
    wire [precision - 1 : 0] d_xx, d_yy, d_xy;
    wire [precision - 1 : 0] max_alpha; // 0.99 in fp32
    wire [precision - 1 : 0] min_alpha; // 1/255 in fp32
    wire [precision - 1 : 0] One;

    wire [precision - 1 : 0] alpha_temp1, alpha_temp;

    wire aeqb_inst1, aeqb_inst2, altb_inst, agtb_inst1, agtb_inst2, unordered_inst1, unordered_inst2;

    wire [precision - 1 : 0] not_used_alpha1, not_used_alpha2, not_used_alpha3;
    wire [7:0] status_flag_0, status_flag_1, status_flag_2, status_flag_3;

    wire [7:0] status_inst[1:14];
    wire skip_from_alpha;
    wire [precision - 1 : 0] One_minus_alpha;
    wire [precision - 1 : 0] G_temp;

    wire skip_temp;

    generate
        if (precision == 32 && mantissa_bit == 23) begin
            // FP32 values
            assign max_alpha = 32'h3f7d_70a4; // 0.99 in FP32
            assign min_alpha = 32'h3b80_0000; // 1/256 in FP32
        end
        else if (precision == 16 && mantissa_bit == 7) begin
            // FP16 values
            assign max_alpha = 16'h3f7d;      // 0.99 in FP16 // 이거 바꿔야함
            assign min_alpha = 16'h3b80;      // 1/256 in FP16 // 이거도
        end
        else if (precision == 24 && mantissa_bit == 15) begin
            // FP24 values
            assign max_alpha = 24'h3f7d_70;      // 0.99 in FP16 // 이거 바꿔야함
            assign min_alpha = 24'h3b80_00;      // 1/256 in FP16 // 이거도
        end
        else begin
            // Default case: all zeros (or you can choose to produce an error/warning)
            assign max_alpha = {precision{1'b0}};
            assign min_alpha = {precision{1'b0}};
        end
    endgenerate


    assign current_pixel = {{(precision-11){1'b0}}, block_id[14 : 8], pixel_id[$clog2(BLOCK_SIZE)-1:0], {(precision-11){1'b0}}, block_id[6:0], pixel_id[(2 * $clog2(BLOCK_SIZE))-1:$clog2(BLOCK_SIZE)] }; // 16bit int | X | Y |

    // Instance of DW_fp_i2flt
    // 32 for int size 
    DW_fp_i2flt #(mantissa_bit, exponent_bit, precision, 1)
	  fp_pixel_x ( .a(current_pixel[(2 * precision) - 1: precision]), .rnd(inst_rnd[1]), .z(current_pixel_fp[(2 * precision) - 1: precision]), .status(status_inst[1]));
    // Instance of DW_fp_i2flt
    DW_fp_i2flt #(mantissa_bit, exponent_bit, precision, 1)
	  fp_pixel_y ( .a(current_pixel[precision - 1 : 0]), .rnd(inst_rnd[2]), .z(current_pixel_fp[precision - 1 : 0]), .status(status_inst[2]) );


    // Instance of DW_fp_add
    DW_fp_add #(mantissa_bit, exponent_bit, 0)
	  d_x ( .a(mean2D[(2 * precision) - 1: precision]), .b({!current_pixel_fp[(2 * precision) - 1] ,current_pixel_fp[(2 * precision) - 2 : precision]}), .rnd(inst_rnd[3]), .z(d_temp[(2 * precision) - 1: precision]), .status(status_inst[3]) );
    // Instance of DW_fp_add
    DW_fp_add #(mantissa_bit, exponent_bit, 0)
	  d_y ( .a(mean2D[precision - 1 : 0]), .b({!current_pixel_fp[(precision-1)] ,current_pixel_fp[precision - 2 :0]}), .rnd(inst_rnd[4]), .z(d_temp[precision - 1 : 0]), .status(status_inst[4]) );
    
    
    // Instance of DW_fp_mult
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
	  dxx ( .a(d_temp[(2 * precision) - 1: precision]), .b(d_temp[(2 * precision) - 1: precision]), .rnd(inst_rnd[5]), .z(d_xx), .status(status_inst[5]) );

    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
	  dyy ( .a(d_temp[precision - 1 : 0]), .b(d_temp[precision - 1 : 0]), .rnd(inst_rnd[6]), .z(d_yy), .status(status_inst[6]) );

    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
	  dxy ( .a(d_temp[(2 * precision) - 1: precision]), .b(d_temp[precision - 1 : 0]), .rnd(inst_rnd[7]), .z(d_xy), .status(status_inst[7]) );


	// const float power = -0.5f * (con_o.x * d.x * d.x + con_o.z * d.y * d.y) - con_o.y * d.x * d.y;
    // connected to exponent
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
	  t1 ( .a(d_xx), .b(conic_opacity[(4 * precision)-1 : (3 * precision)]), .rnd(inst_rnd[8]), .z(temp1), .status(status_inst[8]) );

    // connected to exponent
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
	  t2 ( .a(d_yy), .b(conic_opacity[(2 * precision) - 1: precision]), .rnd(inst_rnd[9]), .z(temp2), .status(status_inst[9]) );
    
    // connected to exponent
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
	  t3 ( .a(d_xy), .b(conic_opacity[(3 * precision) - 1 : 2 * precision]), .rnd(inst_rnd[10]), .z(temp3), .status(status_inst[10]) );

    DW_fp_add #(mantissa_bit, exponent_bit, 0)
	  t4 ( .a(temp1), .b(temp2), .rnd(inst_rnd[11]), .z(temp4), .status(status_inst[11]) );


    DW_fp_add #(mantissa_bit, exponent_bit, 0)
	  power_maker ( .a({!temp4[precision-1], temp4[precision - 2 : mantissa_bit] - 8'b1, temp4[mantissa_bit-1:0]}), .b({!temp3[precision-1], temp3[precision-2:0]}), .rnd(inst_rnd[12]), .z(power), .status(status_inst[12]) );



    // Instance of DW_fp_exp
    DW_fp_exp #(mantissa_bit, exponent_bit, 1, 0) 
     exponent_power ( .a(power), .z(G_temp), .status(status_inst[13]));


    // alpha connection conflict should be cared
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
	 alpha_temp_maker   ( .a(G_temp), .b(conic_opacity[precision - 1 : 0]), .rnd(inst_rnd[13]), .z(alpha_temp1), .status(status_inst[14]));

    // Instance of DW_fp_cmp
    DW_fp_cmp #(mantissa_bit, exponent_bit, 0)
	  alpha_comp ( .a(alpha_temp1), .b(max_alpha), .zctr(1'b0), .aeqb(aeqb_inst1), 
		.altb(altb_inst), .agtb(agtb_inst1), .unordered(unordered_inst1), 
		.z0(alpha_temp), .z1(not_used_alpha1), .status0(status_flag_0), 
		.status1(status_flag_1));


    // Instance of DW_fp_cmp
    DW_fp_cmp #(mantissa_bit, exponent_bit, 0)
	  alpha_skip_comp ( .a(alpha_temp), .b(min_alpha), .zctr(1'b0), .aeqb(aeqb_inst2), 
		.altb(skip_from_alpha), .agtb(agtb_inst2), .unordered(unordered_inst2), 
		.z0(not_used_alpha2), .z1(not_used_alpha3), .status0(status_flag_2), 
		.status1(status_flag_3));

    assign skip = !power[precision-1] ||  skip_from_alpha;
    assign d = d_temp;
    assign G = G_temp;
    assign alpha = alpha_temp;

    // Capture before out 
    always @ (posedge clk) begin
        if (!rst_n) begin

            skip3 <= 'b0;
            skip4 <= 'b0;
            skip5 <= 'b0;
            skip_out <= 'b0;

            G_out <= 'h0;
            G4 <= 'h0;
            G5 <= 'h0;

            d_out <= 'h0;
            d1 <= 'h0;
            d2 <= 'h0;
            d3 <= 'h0;
            d4 <= 'h0;
            d5 <= 'h0;

            alpha_out <= 'h0;

            dxx2 <= 'h0;
            dxy2 <= 'h0;
            dyy2 <= 'h0;

            i_valid0 <= 'b0;
            i_valid1 <= 'b0;
            i_valid2 <= 'b0;
            i_valid3 <= 'b0;
            i_valid4 <= 'b0;
            i_valid5 <= 'b0;
            skip_and_alpha_done <= 'b0;

            mean2D0 <= 'h0;
            pixel_id0 <= 'h0;

            conic_opacity0 <= 'h0;
            conic_opacity1 <= 'h0;
            conic_opacity2 <= 'h0;
            conic_opacity3 <= 'h0;
            conic_opacity4 <= 'h0;
            conic_opacity5 <= 'h0;
            conic_opacity_out <= 'h0;

        end

        else begin

                ////////////////////////////////////////////////////////////////////
                ///////////////////////// Clock 0 Data Input ///////////////////////
                ////////////////////////////////////////////////////////////////////

                i_valid0 <= i_valid;
                mean2D0 <= mean2D;
                conic_opacity0 <= conic_opacity;
                pixel_id0 <= pixel_id;

                ////////////////////////////////////////////////////////////////////
                ///////////////////////// Clock 1 Data Flow ///////////////////////
                ////////////////////////////////////////////////////////////////////

                i_valid1 <= i_valid0;
                conic_opacity1 <= conic_opacity0;
                d1 <= d_temp;

                ////////////////////////////////////////////////////////////////////
                ///////////////////////// Clock 2 Data Flow ///////////////////////
                ////////////////////////////////////////////////////////////////////

                i_valid2 <= i_valid1;
                conic_opacity2 <= conic_opacity1;
                d2 <= d1;
                dxx2 <= dxx_temp;
                dxy2 <= dxy_temp;
                dyy2 <= dyy_temp;
                
                ////////////////////////////////////////////////////////////////////
                ///////////////////////// Clock 3 Data Flow ///////////////////////
                ////////////////////////////////////////////////////////////////////

                i_valid3 <= i_valid2;
                conic_opacity3 <= conic_opacity2;
                d3 <= d2;

                power3 <= power_temp;
                skip3 <= skip_temp1;

                ////////////////////////////////////////////////////////////////////
                ///////////////////////// Clock 4 Data Flow ///////////////////////
                ////////////////////////////////////////////////////////////////////

                i_valid4 <= i_valid3;
                conic_opacity4 <= conic_opacity3;
                d4 <= d3;

                G4 <= G_temp;
                skip4 <= skip3;

                ////////////////////////////////////////////////////////////////////
                ///////////////////////// Clock 5 Data Flow ///////////////////////
                ////////////////////////////////////////////////////////////////////

                i_valid5 <= i_valid4;
                conic_opacity5 <= conic_opacity4;
                d5 <= d4;
                G5 <= G4;
                skip5 <= skip_temp2;

                ////////////////////////////////////////////////////////////////////
                /////////////////// Clock 6 & Final Out Data Flow //////////////////
                ////////////////////////////////////////////////////////////////////                

                skip_and_alpha_done_out <= i_valid5;
                conic_opacity_out <= conic_opacity5;
                d_out <= d5;
                G_out <= G5;
                skip_out <= skip5;
                alpha_out <= alpha_temp;
        end


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