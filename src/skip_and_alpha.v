module skip_and_alpha
    #(
        parameter BLOCK_SIZE = 16,
        parameter exponent_bit = 8,
        parameter mantissa_bit = 8,
        parameter precision = 16
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

    output reg skip_and_alpha_done_out
    
    );
    localparam ieee_compliance = 1'b0;
    // localparam [2:0] inst_rnd [1:12] = {3'b0, 3'b0, 3'b0, 3'b0, 3'b0, 3'b0, 3'b0, 3'b0, 3'b0, 3'b0, 3'b0, 3'b0};

    // register declaration

    reg [( 2 * precision ) - 1 : 0] d1, d2, d3, d4, d5;
    reg [precision - 1 : 0] G4, G5;
    reg [precision - 1 : 0] dxx2, dxy2, dyy2;
    reg skip3, skip4, skip5;

    reg i_valid0, i_valid1, i_valid2, i_valid3, i_valid4, i_valid5;
    reg [( 2 * precision ) - 1 : 0] mean2D0;
    reg [( 4 * precision ) - 1 : 0] conic_opacity0, conic_opacity1, conic_opacity2, conic_opacity3, conic_opacity4, conic_opacity5;
    reg [(2 * $clog2(BLOCK_SIZE) - 1): 0] pixel_id0;
    reg [precision - 1 : 0] power3;
    reg [precision - 1 : 0] alpha5;
    reg [15:0] block_id0;



    // // Intermediate variables
    wire [( 2 * precision ) - 1 : 0] d_temp; // fp32 (int32 calculations needed) | X | Y |
    wire [precision - 1 : 0] power_temp;
    
    wire skip_temp1, skip_temp2;
    wire [(2 * precision) - 1 : 0] current_pixel;
    wire [precision - 1 : 0] temp1, temp2, temp3;
    wire [( 2 * precision ) - 1 : 0] current_pixel_fp;
    
    wire [precision - 1 : 0] dxx_temp, dyy_temp, dxy_temp;
    wire [precision - 1 : 0] max_alpha; // 0.99 in fp32
    wire [precision - 1 : 0] min_alpha; // 1/255 in fp32
    wire [precision - 1 : 0] One;

    wire [precision - 1 : 0] alpha_temp1, alpha_temp;

    wire aeqb_inst1, aeqb_inst2, altb_inst, agtb_inst1, agtb_inst2, unordered_inst1, unordered_inst2;

    wire [precision - 1 : 0] not_used_alpha1, not_used_alpha2, not_used_alpha3;
    wire [7:0] status_flag_0, status_flag_1, status_flag_2, status_flag_3;

    wire [7:0] status_inst[1:13];
    wire skip_from_alpha;
    wire [precision - 1 : 0] G_temp;

    wire skip_temp;

    assign max_alpha = (precision == 32 && mantissa_bit == 23) ? 32'h3f7d_70a4 :
                    (precision == 16 && mantissa_bit == 7) ? 16'h3f7d :
                    (precision == 24 && mantissa_bit == 15) ? 24'h3f7d_70 :
                    {precision{1'b0}};

    assign min_alpha = (precision == 32 && mantissa_bit == 23) ? 32'h3b80_0000 :
                    (precision == 16 && mantissa_bit == 7) ? 16'h3b80 :
                    (precision == 24 && mantissa_bit == 15) ? 24'h3b80_00 :
                    {precision{1'b0}};
    


    ////////////////////////////////////////////////////////////////////
    //////////////////////////// Clock Step 0 //////////////////////////
    ////////////////////////////////////////////////////////////////////

    // put directly to input
    // assign current_pixel = {{(precision-11){1'b0}}, block_id0[14 : 8], pixel_id0[$clog2(BLOCK_SIZE)-1:0], {(precision-11){1'b0}}, block_id0[6:0], pixel_id0[(2 * $clog2(BLOCK_SIZE))-1:$clog2(BLOCK_SIZE)] }; // 16bit int | X | Y |

    // Instance of DW_fp_i2flt
    // 32 for int size 
    DW_fp_i2flt #(mantissa_bit, exponent_bit, precision, 1)
	  fp_pixel_x ( .a({{(precision-11){1'b0}}, block_id0[14:8], pixel_id0[$clog2(BLOCK_SIZE)-1:0]}), .rnd(3'b0), .z(current_pixel_fp[(2 * precision) - 1: precision]), .status(status_inst[1]));
    // Instance of DW_fp_i2flt
    DW_fp_i2flt #(mantissa_bit, exponent_bit, precision, 1)
	  fp_pixel_y ( .a({{(precision-11){1'b0}}, block_id0[6:0], pixel_id0[(2 * $clog2(BLOCK_SIZE))-1:$clog2(BLOCK_SIZE)]}), .rnd(3'b0), .z(current_pixel_fp[precision - 1 : 0]), .status(status_inst[2]) );


    // Instance of DW_fp_add
    DW_fp_add #(mantissa_bit, exponent_bit, 0)
	  d_x ( .a(mean2D0[(2 * precision) - 1: precision]), .b({!current_pixel_fp[(2 * precision) - 1] ,current_pixel_fp[(2 * precision) - 2 : precision]}), .rnd(3'b0), .z(d_temp[(2 * precision) - 1: precision]), .status(status_inst[3]) );
    // Instance of DW_fp_add
    DW_fp_add #(mantissa_bit, exponent_bit, 0)
	  d_y ( .a(mean2D0[precision - 1 : 0]), .b({!current_pixel_fp[(precision-1)] ,current_pixel_fp[precision - 2 :0]}), .rnd(3'b0), .z(d_temp[precision - 1 : 0]), .status(status_inst[4]) );

    ////////////////////////////////////////////////////////////////////
    //////////////////////////// Clock Step 1 //////////////////////////
    ////////////////////////////////////////////////////////////////////
    
    // Instance of DW_fp_mult
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
	  dxx ( .a(d1[(2 * precision) - 1: precision]), .b(d1[(2 * precision) - 1: precision]), .rnd(3'b0), .z(dxx_temp), .status(status_inst[5]) );

    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
	  dyy ( .a(d1[precision - 1 : 0]), .b(d1[precision - 1 : 0]), .rnd(3'b0), .z(dyy_temp), .status(status_inst[6]) );

    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
	  dxy ( .a(d1[(2 * precision) - 1: precision]), .b(d1[precision - 1 : 0]), .rnd(3'b0), .z(dxy_temp), .status(status_inst[7]) );

    ////////////////////////////////////////////////////////////////////
    //////////////////////////// Clock Step 2 //////////////////////////
    ////////////////////////////////////////////////////////////////////

	// const float power = -0.5f * (con_o.x * d.x * d.x + con_o.z * d.y * d.y) - con_o.y * d.x * d.y;
    // connected to exponent
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
	  t1 ( .a(dxx2), .b(conic_opacity2[(4 * precision)-1 : (3 * precision)]), .rnd(3'b0), .z(temp1), .status(status_inst[8]) );

    // connected to exponent
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
	  t2 ( .a(dyy2), .b(conic_opacity2[(2 * precision) - 1: precision]), .rnd(3'b0), .z(temp2), .status(status_inst[9]) );
    
    // connected to exponent
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
	  t3 ( .a(dxy2), .b(conic_opacity2[(3 * precision) - 1 : 2 * precision]), .rnd(3'b0), .z(temp3), .status(status_inst[10]) );

    DW_fp_sum3 #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
     power_maker ( .a({!temp1[precision-1], temp1[precision - 2 : mantissa_bit] - 8'b1, temp1[mantissa_bit-1:0]}), 
                .b({!temp2[precision-1], temp2[precision - 2 : mantissa_bit] - 8'b1, temp2[mantissa_bit-1:0]}), 
                .c({!temp3[precision-1], temp3[precision-2:0]}), .rnd(3'b0), .z(power_temp), .status(status_inst[11]) );      

    ////////////////////////////////////////////////////////////////////
    //////////////////////////// Clock Step 3 //////////////////////////
    ////////////////////////////////////////////////////////////////////

    // Instance of DW_fp_exp
    DW_fp_exp #(mantissa_bit, exponent_bit, 1, 0) 
     exponent_power ( .a(power3), .z(G_temp), .status(status_inst[12]));

    ////////////////////////////////////////////////////////////////////
    //////////////////////////// Clock Step 4 //////////////////////////
    ////////////////////////////////////////////////////////////////////

    // alpha connection conflict should be cared
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
	 alpha_temp_maker   ( .a(G4), .b(conic_opacity4[precision - 1 : 0]), .rnd(3'b0), .z(alpha_temp1), .status(status_inst[13]));

    ////////////////////////////////////////////////////////////////////
    /////////////////////////// Clock Step 5 ///////////////////////////
    ////////////////////////////////////////////////////////////////////

    // Instance of DW_fp_cmp
    DW_fp_cmp #(mantissa_bit, exponent_bit, 0)
	  alpha_comp ( .a(alpha5), .b(max_alpha), .zctr(1'b0), .aeqb(aeqb_inst1), 
		.altb(altb_inst), .agtb(agtb_inst1), .unordered(unordered_inst1), 
		.z0(alpha_temp), .z1(not_used_alpha1), .status0(status_flag_0), 
		.status1(status_flag_1));

    // Instance of DW_fp_cmp
    DW_fp_cmp #(mantissa_bit, exponent_bit, 0)
	  alpha_skip_comp ( .a(alpha_temp), .b(min_alpha), .zctr(1'b0), .aeqb(aeqb_inst2), 
		.altb(skip_from_alpha), .agtb(agtb_inst2), .unordered(unordered_inst2), 
		.z0(not_used_alpha2), .z1(not_used_alpha3), .status0(status_flag_2), 
		.status1(status_flag_3));

    assign skip_temp2 = skip_from_alpha || skip5;

    ////////////////////////////////////////////////////////////////////
    //////////////////////// Clock Step 6 (Out) ////////////////////////
    ////////////////////////////////////////////////////////////////////

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

            power3 <= 'h0;

            i_valid0 <= 'b0;
            i_valid1 <= 'b0;
            i_valid2 <= 'b0;
            i_valid3 <= 'b0;
            i_valid4 <= 'b0;
            i_valid5 <= 'b0;
            skip_and_alpha_done_out <= 'b0;

            mean2D0 <= 'h0;
            pixel_id0 <= 'h0;

            conic_opacity0 <= 'h0;
            conic_opacity1 <= 'h0;
            conic_opacity2 <= 'h0;
            conic_opacity3 <= 'h0;
            conic_opacity4 <= 'h0;
            conic_opacity5 <= 'h0;
            conic_opacity_out <= 'h0;

            alpha5 <= 'h0;

        end

        else begin

                ////////////////////////////////////////////////////////////////////
                ///////////////////////// Clock 0 Data Input ///////////////////////
                ////////////////////////////////////////////////////////////////////

                i_valid0 <= i_valid;
                mean2D0 <= mean2D;
                conic_opacity0 <= conic_opacity;
                pixel_id0 <= pixel_id;
                block_id0 <= block_id;

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
                alpha5 <= alpha_temp1;

                ////////////////////////////////////////////////////////////////////
                /////////////////// Clock 6 & Final Out Data Flow //////////////////
                ////////////////////////////////////////////////////////////////////                

                skip_and_alpha_done_out <= i_valid5;
                conic_opacity_out <= conic_opacity5;
                d_out <= d5;
                G_out <= G5;
                skip_out <= skip5;
                alpha_out <= alpha5;
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