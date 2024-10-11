module skip_and_alpha
    #(
        parameter BLOCK_SIZE = 16,
        parameter exponent_bit = 8,
        parameter mantissa_bit = 23,
        parameter precision = 32
    )
    (
    // input wire clk,
    // input wire rst_n,

    input wire [63:0] block_id, // block id | X | Y |


    input wire [( 2 * precision ) - 1 : 0] mean2D , // fp32 | X | Y | 
    input wire [127:0] conic_opacity, // fp32 | X | Y | Z | W |
    input wire [(2 * $clog2(BLOCK_SIZE) - 1): 0] pixel_id, // int 0 ~ 255 

    input wire [precision - 1 : 0] T_before, 

    input wire i_valid,

    output wire skip, // can be work as valid
    output wire [precision - 1 : 0] G,
    output wire [( 2 * precision ) - 1 : 0] d,
    output wire [precision - 1 : 0] T,
    output wire [precision - 1 : 0] alpha

    // output wire skip_and_alpha_done
    
    );
    // synopsys template
    localparam ieee_compliance = 1'b0;
    localparam [2:0] inst_rnd [1:15] = {3'b0,3'b0,3'b0,3'b0,3'b0,3'b0,3'b0,3'b0,3'b0,3'b0,3'b0,3'b0,3'b0,3'b0,3'b0};

    // // Intermediate variables
    wire [( 2 * precision ) - 1 : 0] d_temp; // fp32 (int32 calculations needed) | X | Y |
    wire [precision - 1 : 0] power;
    
    wire [( 2 * precision ) - 1 : 0] current_pixel;
    wire [precision - 1 : 0] temp1, temp2, temp3, temp4;
    wire [( 2 * precision ) - 1 : 0] current_pixel_fp;
    
    wire [precision - 1 : 0] d_xx, d_yy, d_xy;

    // 이거 고정값은 변경해야됨
    // precision에 따라 1값은 어떻게 처리할까
    // wire [precision - 1 : 0] max_alpha = 32'h3f7d_70a4; // 0.99 in fp32
    // wire [precision - 1 : 0] min_alpha = 32'h3b808081; // 1/255 in fp32
    // wire [precision - 1 : 0] One = 32'h3f80_0000;

    wire [precision - 1 : 0] max_alpha; // 0.99 in fp32
    wire [precision - 1 : 0] min_alpha; // 1/255 in fp32
    wire [precision - 1 : 0] One;

    wire [precision - 1 : 0] alpha_temp1, alpha_temp;

    wire aeqb_inst1, aeqb_inst2, altb_inst, agtb_inst1, agtb_inst2, unordered_inst1, unordered_inst2;

    wire [precision - 1 : 0] not_used_alpha1, not_used_alpha2, not_used_alpha3;
    wire [7:0] status_flag_0, status_flag_1, status_flag_2, status_flag_3;

    wire [7:0] status_inst[1:16];
    wire skip_from_alpha;
    wire [precision - 1 : 0] T_temp, One_minus_alpha;
    wire [precision - 1 : 0] G_temp;

    wire skip_temp;

    generate
        if (precision == 32) begin
            // FP32 values
            assign max_alpha = 32'h3f7d_70a4; // 0.99 in FP32
            assign min_alpha = 32'h3b80_8081; // 1/255 in FP32
            assign One = 32'h3f80_0000;       // 1.0 in FP32
        end
        else if (precision == 16) begin
            // FP16 values
            assign max_alpha = 16'h3C7B;      // 0.99 in FP16 // 이거 바꿔야함
            assign min_alpha = 16'h2481;      // 1/255 in FP16 // 이거도
            assign One = 16'h3C00;            // 1.0 in FP16
        end
        else begin
            // Default case: all zeros (or you can choose to produce an error/warning)
            assign max_alpha = {precision{1'b0}};
            assign min_alpha = {precision{1'b0}};
            assign One = {precision{1'b0}};
        end
    endgenerate
    // assign max_alpha = 32'h3f7d_70a4; // 0.99 in FP32
    // assign min_alpha = 32'h3b80_8081; // 1/255 in FP32
    // assign One = 32'h3f80_0000;       // 1.0 in FP32




    assign current_pixel = {block_id[((2*precision - 1) - $clog2(BLOCK_SIZE)): precision], pixel_id[$clog2(BLOCK_SIZE)-1:0], block_id[((precision-1)-$clog2(BLOCK_SIZE)):0], pixel_id[(2*$clog2(BLOCK_SIZE))-1:$clog2(BLOCK_SIZE)]}; // 32bit int | X | Y |

    //   // Instance of DW_fp_i2flt
    // DW_fp_i2flt #(sig_width, exp_width, isize, isign)
	  // U1 ( .a(inst_a), .rnd(inst_rnd), .z(z_inst), .status(status_inst) );

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
	  d_y ( .a(mean2D[precision - 1 : 0]), .b({!current_pixel_fp[(precision-1)] ,current_pixel_fp[ precision - 2 :0]}), .rnd(inst_rnd[4]), .z(d_temp[precision - 1 : 0]), .status(status_inst[4]) );
    
    
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
	  t1 ( .a(d_xx), .b(conic_opacity[(4*precision)-1 :3*precision]), .rnd(inst_rnd[8]), .z(temp1), .status(status_inst[8]) );

    // connected to exponent
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
	  t2 ( .a(d_yy), .b(conic_opacity[(2 * precision) - 1: precision]), .rnd(inst_rnd[9]), .z(temp2), .status(status_inst[9]) );
    
    // connected to exponent
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
	  t3 ( .a(d_xy), .b(conic_opacity[(3*precision) - 1 : 2 * precision]), .rnd(inst_rnd[10]), .z(temp3), .status(status_inst[10]) );

    DW_fp_add #(mantissa_bit, exponent_bit, 0)
	  t4 ( .a(temp1), .b(temp2), .rnd(inst_rnd[11]), .z(temp4), .status(status_inst[11]) );


    DW_fp_add #(mantissa_bit, exponent_bit, 0)
	  power_maker ( .a({!temp4[precision-1], temp4[precision-2 : mantissa_bit] - 8'b1, temp4[mantissa_bit-1:0]}), .b({!temp3[precision-1], temp3[precision-2:0]}), .rnd(inst_rnd[12]), .z(power), .status(status_inst[12]) );



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


    DW_fp_add #(mantissa_bit, exponent_bit, 0)
	  One_minus_alpha_maker ( .a(One), .b({!alpha_temp[31], alpha_temp[30:0]}), .rnd(inst_rnd[14]), .z(One_minus_alpha), .status(status_inst[15]) );


    DW_fp_div #(mantissa_bit, exponent_bit, ieee_compliance, 1'b0, 1'b0)
     T_temp_maker ( .a(T_before), .b(One_minus_alpha), .rnd(inst_rnd[15]), .z(T_temp), .status(status_inst[16]) );

    // assign skip = !i_valid || (!power[31] || (temp4[30:23] == 8'b0)) || skip_from_alpha;
    assign skip = (!power[precision-1] || (temp4[precision-2:mantissa_bit] == {exponent_bit{1'b0}})) || skip_from_alpha;


    assign d = d_temp;
    assign G = G_temp;
    // assign skip = skip_temp;
    
    assign alpha = alpha_temp;

    assign T = skip ? T_before : T_temp;

    // assign skip_and_alpha_done = !skip ;

    // // Capture before out 
    // always @ (posedge clk) begin    
    //     if (!rst_n) begin
    //         skip <= 1'b0;
    //         d <= 64'h0;
    //         alpha <= 32'h0;
    //         T <= 32'h0;
    //         G <= 32'h0;
    //         skip_and_alpha_done = 1'b0;
    //     end

    //     else if (i_valid) begin
    //         skip <= skip_temp ; //  | (alpha < 1/255 조건)); // done or power > 0 or expected underflow or alpha < 1 / 255
    //         d <= d_temp;
    //         G <= G_temp;
    //         if (!skip_temp) begin
    //             alpha <= alpha_temp;
    //             T <= T_temp;
    //             skip_and_alpha_done = 1'b1;
    //         end
            
    //         else begin
    //             alpha <= 32'h0;
    //             T <= T_before;
    //             skip_and_alpha_done = 1'b1;
    //         end
    //     end

    //     else begin
    //         skip <= 1'b0;
    //         d <= 64'h0;
    //         alpha <= 32'h0;
    //         T <= 32'h0;
    //         G <= 32'h0;
    //         skip_and_alpha_done = 1'b0;
    //     end
    // end


endmodule


	// const float2 xy = collected_xy[j];
	// const float2 d = { xy.x - pixf.x, xy.y - pixf.y };
	// const float4 con_o = collected_conic_opacity[j];
	// const float power = -0.5f * (con_o.x * d.x * d.x + con_o.z * d.y * d.y) - con_o.y * d.x * d.y;
	// skip |= power > 0.0f;

	// const float G = exp(power);
	// const float alpha = min(0.99f, con_o.w * G);
	// skip |= alpha < 1.0f / 255.0f;
    // T = skip ? T : T / (1.f - alpha);