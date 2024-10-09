module gradient_depth_color
    #(
        parameter BLOCK_SIZE = 16,
        parameter exponent_bit = 8,
        parameter mantissa_bit = 23,
        parameter precision = 32
    )
    (
    // input wire clk,
    // input wire rst_n,
    // input wire skip,

    input wire [31:0] alpha_before, // last_alpha 픽셀에서 유지하는 값
    input wire [95:0] color_before, // last_color
    input wire [31:0] depth_before, // last_depth
    input wire [95:0] accum_rec_before, // accum_rec_before
    input wire [31:0] accum_rec_depth_before,

    input wire [31:0] alpha_in, // alpha_i (이전 step에서 계산한거)
    input wire [31:0] T_in, // T_i
    
    // input wire [63:0] gaussian_id,
    input wire [95:0] gaussian_color, // | R | G | B |
    input wire [31:0] gaussian_depth,

    input wire i_valid, // !skip signal
    // input wire [95:0] background_color,

    input wire [95:0] dL_dpixel, // dL_dpixel
    input wire [31:0] dL_dpixel_depth,

    output wire [31:0] dL_dalpha,
    output wire [95:0] dL_dcolor,
    output wire [31:0] dL_ddepth,

    output wire [31:0] alpha_out, // last alpha
    output wire [95:0] color_out, //last color out
    output wire [31:0] depth_out, // last depth
    output wire [95:0] accum_rec,
    output wire [31:0] accum_rec_depth

    // output wire dL_dalpha_valid
    // output reg gradient_depth_color_done
    );
 
    localparam ieee_compliance = 1'b0;
    localparam [2:0] inst_rnd = 3'b0;

    wire [31:0] dchannel_dcolor;
    wire [31:0] dL_dalpha_temp1 = 32'h0;
    wire [31:0] dL_dalpha_skip_temp1 = 32'h0;
    
    wire [95:0] dL_dalpha_color_temp, dL_dalpha_color_skip_temp;
    wire [31:0] dL_dalpha_depth_temp, dL_dalpha_depth_skip_temp;

    wire [31:0] One = 32'h3f80_0000;
    wire [31:0] One_minus_alpha;


    
    wire [95:0] accum_rec_temp, accum_rec_skip_temp;
    
    wire [31:0] accum_rec_depth_temp;
    wire [95:0] local_dL_dcolors_temp; // skip이 아닌 경우 값 임시 저장
    wire [7:0] status_inst [1:28]; 

    wire [31:0] dL_dalpha_temp, dL_dalpha_temp2, dL_dalpha_temp3, dL_dalpha_temp4, dL_dalpha_temp5, dL_dalpha_temp6;
    wire [31:0] dL_dalpha_skip_temp, dL_dalpha_skip_temp2, dL_dalpha_skip_temp3, dL_dalpha_skip_temp4, dL_dalpha_skip_temp5, dL_dalpha_skip_temp6;

    

    wire [31:0] dL_ddepth_temp;

    // const float dchannel_dcolor = alpha * T;
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
	  dL_dch_dcolor ( .a(T_in), .b(alpha_in), .rnd(inst_rnd), .z(dchannel_dcolor), .status(status_inst[1]) );
    

    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0) // 	local_dL_dcolors[ch] = skip ? 0.0f : dchannel_dcolor * dL_dchannel;
	  local_dL_dcolors_temp_R ( .a(dchannel_dcolor), .b(dL_dpixel[95:64]), .rnd(inst_rnd), .z(local_dL_dcolors_temp[95:64]), .status(status_inst[2]) );

    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0) // 	local_dL_dcolors[ch] = skip ? 0.0f : dchannel_dcolor * dL_dchannel;
	  local_dL_dcolors_temp_G ( .a(dchannel_dcolor), .b(dL_dpixel[63:32]), .rnd(inst_rnd), .z(local_dL_dcolors_temp[63:32]), .status(status_inst[3]) );

    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0) // 	local_dL_dcolors[ch] = skip ? 0.0f : dchannel_dcolor * dL_dchannel;
	  local_dL_dcolors_temp_B ( .a(dchannel_dcolor), .b(dL_dpixel[31:0]), .rnd(inst_rnd), .z(local_dL_dcolors_temp[31:0]), .status(status_inst[4]) );


    // Instance of DW_fp_add
    // 	accum_rec[ch] = skip ? accum_rec[ch] : last_alpha * last_color[ch] + (1.f - last_alpha) * accum_rec[ch];
    DW_fp_add #(mantissa_bit, exponent_bit, 0)
	  One_alpha_R ( .a(One), .b({!alpha_before[31] ,alpha_before[30:0]}), .rnd(inst_rnd), .z(One_minus_alpha), .status(status_inst[5]) );
    

    // accum_rec[ch] = skip ? accum_rec[ch] : last_alpha * last_color[ch] + (1.f - last_alpha) * accum_rec[ch];
    DW_fp_dp2 #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
     accum_rec_temp_maker_R ( .a(alpha_before), .b(color_before[95:64]), .c(One_minus_alpha), .d(accum_rec_before[95:64]), .rnd(inst_rnd), .z(accum_rec_temp[95:64]), .status(status_inst[6]) );

    DW_fp_dp2 #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
     accum_rec_temp_maker_G ( .a(alpha_before), .b(color_before[63:32]), .c(One_minus_alpha), .d(accum_rec_before[63:32]), .rnd(inst_rnd), .z(accum_rec_temp[63:32]), .status(status_inst[7]) );

    DW_fp_dp2 #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
     accum_rec_temp_maker_B ( .a(alpha_before), .b(color_before[31:0]), .c(One_minus_alpha), .d(accum_rec_before[31:0]), .rnd(inst_rnd), .z(accum_rec_temp[31:0]), .status(status_inst[8]) );


	// 	const float dL_dchannel = dL_dpixel[ch];
	// 	dL_dalpha += (c - accum_rec[ch]) * dL_dchannel;
    DW_fp_add #(mantissa_bit, exponent_bit, 0)
	  dL_dalpha_temp_R ( .a(gaussian_color[95:64]), .b({!accum_rec_temp[95], accum_rec_temp[94:64]}), .rnd(inst_rnd), .z(dL_dalpha_color_temp[95:64]), .status(status_inst[9]) );

    DW_fp_add #(mantissa_bit, exponent_bit, 0)
	  dL_dalpha_temp_G ( .a(gaussian_color[63:32]), .b({!accum_rec_temp[63], accum_rec_temp[62:32]}), .rnd(inst_rnd), .z(dL_dalpha_color_temp[63:32]), .status(status_inst[10]) );

    DW_fp_add #(mantissa_bit, exponent_bit, 0)
	  dL_dalpha_temp_B ( .a(gaussian_color[31:0]), .b({!accum_rec_temp[31], accum_rec_temp[30:0]}), .rnd(inst_rnd), .z(dL_dalpha_color_temp[31:0]), .status(status_inst[11]) );


	// 	const float dL_dchannel = dL_dpixel[ch];
	// 	dL_dalpha += (c - accum_rec[ch]) * dL_dchannel;
    //  dL_dalpha from color in skip process (needs to change at final)
    // DW_fp_add #(mantissa_bit, exponent_bit, 0)
	//   dL_dalpha_skip_temp_R ( .a(gaussian_color[95:64]), .b({!accum_rec_before[95], accum_rec_before[94:64]}), .rnd(inst_rnd), .z(dL_dalpha_color_skip_temp[95:64]), .status(status_inst[12]) );

    // DW_fp_add #(mantissa_bit, exponent_bit, 0)
	//   dL_dalpha_skip_temp_G ( .a(gaussian_color[63:32]), .b({!accum_rec_before[63], accum_rec_before[62:32]}), .rnd(inst_rnd), .z(dL_dalpha_color_skip_temp[63:32]), .status(status_inst[13]) );

    // DW_fp_add #(mantissa_bit, exponent_bit, 0)
	//   dL_dalpha_skip_temp_B ( .a(gaussian_color[31:0]), .b({!accum_rec_before[31], accum_rec_before[30:0]}), .rnd(inst_rnd), .z(dL_dalpha_color_skip_temp[31:0]), .status(status_inst[14]) );


    // dL_dalpha += (c - accum_rec[ch]) * dL_dchannel;
    DW_fp_dp3 #(mantissa_bit, exponent_bit, ieee_compliance, 0)  
     dL_dalpha_maker_from_color ( .a(dL_dalpha_color_temp[95:64]), .b(dL_dpixel[95:64]), .c(dL_dalpha_color_temp[63:32]), .d(dL_dpixel[63:32]), .e(dL_dalpha_color_temp[31:0]), .f(dL_dpixel[31:0]), .rnd(inst_rnd), .z(dL_dalpha_temp2), .status(status_inst[15]) );   

    DW_fp_add #(mantissa_bit, exponent_bit, 0) 
	  dL_dalpha_color_temporary1 ( .a(dL_dalpha_temp1), .b(dL_dalpha_temp2), .rnd(inst_rnd), .z(dL_dalpha_temp3), .status(status_inst[16]) );


    // // dL_alpha for skip
    // // dL_dalpha += (c - accum_rec[ch]) * dL_dchannel;
    // DW_fp_dp3 #(mantissa_bit, exponent_bit, ieee_compliance, 0)  
    //  dL_dalpha_skip_maker_from_color ( .a(dL_dalpha_color_skip_temp[95:64]), .b(dL_dpixel[95:64]), .c(dL_dalpha_color_skip_temp[63:32]), .d(dL_dpixel[63:32]), .e(dL_dalpha_color_skip_temp[31:0]), .f(dL_dpixel[31:0]), .rnd(inst_rnd), .z(dL_dalpha_skip_temp2), .status(status_inst[17]) );   

    // DW_fp_add #(mantissa_bit, exponent_bit, 0) 
	//   dL_dalpha_color_skip_temporary1 ( .a(dL_dalpha_skip_temp1), .b(dL_dalpha_skip_temp2), .rnd(inst_rnd), .z(dL_dalpha_skip_temp3), .status(status_inst[18]) );



    // accum_rec_depth = skip ? accum_rec_depth : last_alpha * last_depth + (1.f - last_alpha) * accum_rec_depth;
    DW_fp_dp2 #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
     accum_rec_depth_temp_maker ( .a(alpha_before), .b(depth_before), .c(One_minus_alpha), .d(accum_rec_depth_before), .rnd(inst_rnd), .z(accum_rec_depth_temp), .status(status_inst[19]) );

    // dL_dalpha += (depth - accum_rec_depth) * dL_dpixel_depth;
    DW_fp_add #(mantissa_bit, exponent_bit, 0)
	  dL_dalpha_maker_from_depth1 ( .a(gaussian_depth), .b({!accum_rec_depth_temp[31], accum_rec_depth_temp[30:0]}), .rnd(inst_rnd), .z(dL_dalpha_depth_temp), .status(status_inst[20]) );
    
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
	  dL_dalpha_maker_from_depth2 ( .a(dL_dalpha_depth_temp), .b(dL_dpixel_depth), .rnd(inst_rnd), .z(dL_dalpha_temp4), .status(status_inst[21]) );


    // for dL_dalpha from skip
    // accum_rec_depth = skip ? accum_rec_depth : last_alpha * last_depth + (1.f - last_alpha) * accum_rec_depth;
    // dL_dalpha += (depth - accum_rec_depth) * dL_dpixel_depth;

    // DW_fp_add #(mantissa_bit, exponent_bit, 0)
	//   dL_dalpha_skip_maker_from_depth1 ( .a(gaussian_depth), .b({!accum_rec_depth_before[31], accum_rec_depth_before[30:0]}), .rnd(inst_rnd), .z(dL_dalpha_depth_skip_temp), .status(status_inst[22]) );
    
    // DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
	//   dL_dalpha_skip_maker_from_depth2 ( .a(dL_dalpha_depth_skip_temp), .b(dL_dpixel_depth), .rnd(inst_rnd), .z(dL_dalpha_skip_temp4), .status(status_inst[23]) );



    DW_fp_add #(mantissa_bit, exponent_bit, 0) // dL_dalpha_temp3 is for color dL_dalpha
	  dL_dalpha_depth_temporary2 ( .a(dL_dalpha_temp3), .b(dL_dalpha_temp4), .rnd(inst_rnd), .z(dL_dalpha_temp5), .status(status_inst[24]) );

    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0) // dL_dalpha *= T;
	  dL_dalpha_maker_from_T ( .a(dL_dalpha_temp5), .b(T_in), .rnd(inst_rnd), .z(dL_dalpha_temp), .status(status_inst[25]) );

    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
	  dL_ddepth_maker ( .a(dchannel_dcolor), .b(dL_dpixel_depth), .rnd(inst_rnd), .z(dL_ddepth_temp), .status(status_inst[26]) );


    // // for dL_dalpha from skip
    // DW_fp_add #(mantissa_bit, exponent_bit, 0) // dL_dalpha_temp3 is for color dL_dalpha
	//   dL_dalpha_depth_skip_temporary2 ( .a(dL_dalpha_skip_temp3), .b(dL_dalpha_skip_temp4), .rnd(inst_rnd), .z(dL_dalpha_skip_temp5), .status(status_inst[27]) );

    // DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0) // dL_dalpha *= T;
	//   dL_dalpha_skip_maker_from_T ( .a(dL_dalpha_skip_temp5), .b(T_in), .rnd(inst_rnd), .z(dL_dalpha_skip_temp), .status(status_inst[28]) );


    //backgruond color 
    

    assign dL_dalpha = i_valid ? dL_dalpha_temp : 32'h0; 
    assign dL_dcolor = i_valid ? local_dL_dcolors_temp : 96'h0;
    assign dL_ddepth = i_valid? dL_ddepth_temp : 32'h0;

    assign alpha_out = i_valid ? alpha_in : alpha_before; // alpha 받는거 생각
    assign color_out = i_valid ? gaussian_color : color_before;
    assign depth_out = i_valid ? gaussian_depth : depth_before;
    assign accum_rec = i_valid ? accum_rec_temp : accum_rec_before;
    assign accum_rec_depth = i_valid ? accum_rec_depth_temp : accum_rec_depth_before;

    // assign dL_dalpha_valid = i_valid; 

    // always @ (posedge clk) begin
        
    //     if (!rst_n) begin
    //         //check for reset value
    //         dL_dalpha <= 32'h0;
    //         dL_dcolor <= 96'h0;
    //         dL_ddepth <= 32'h0;

    //         accum_rec <= 96'h0;
    //         color_out <= 96'h0;
    //         accum_rec_depth <= 32'h0;
    //         depth_out <= 32'h0;
    //         alpha_out <= 32'h0;
    //         dL_dalpha_valid <= 1'b0;
    //         gradient_depth_color_done <= 1'b0;
    //     end

    //     else if (i_valid) begin
    //         accum_rec <=  accum_rec_temp;
    //         color_out <= gaussian_color;
    //         dL_dcolor <= local_dL_dcolors_temp;
    //         accum_rec_depth <= accum_rec_depth_temp;
    //         depth_out <= gaussian_depth;
    //         alpha_out <= alpha_in;
    //         dL_ddepth <= dL_ddepth_temp;
    //         dL_dalpha <= dL_dalpha_temp;
    //         dL_dalpha_valid <= 1'b1;
    //         gradient_depth_color_done <= 1'b1;
    //     end

    //     else begin 
    //         dL_dalpha <= 32'h0;
    //         dL_dcolor <= 96'h0;
    //         dL_ddepth <= 32'h0;

    //         accum_rec <= 96'h0;
    //         color_out <= 96'h0;
    //         accum_rec_depth <= 32'h0;
    //         depth_out <= 32'h0;
    //         alpha_out <= 32'h0;
    //         dL_dalpha_valid <= 1'b0;
    //         gradient_depth_color_done <= 1'b0;
    //     end
    // end
endmodule



			// const float dchannel_dcolor = alpha * T;

			// // Propagate gradients to per-Gaussian colors and keep
			// // gradients w.r.t. alpha (blending factor for a Gaussian/pixel
			// // pair).
			// float dL_dalpha = 0.0f;
			// float local_dL_dcolors[3];
			// #pragma unroll
			// for (int ch = 0; ch < C; ch++)
			// {
			// 	const float c = collected_colors[ch * BLOCK_SIZE + j];

			// 	// Update last color (to be used in the next iteration)
			// 	accum_rec[ch] = skip ? accum_rec[ch] : last_alpha * last_color[ch] + (1.f - last_alpha) * accum_rec[ch];
			// 	last_color[ch] = skip ? last_color[ch] : c;

			// 	const float dL_dchannel = dL_dpixel[ch];
			// 	dL_dalpha += (c - accum_rec[ch]) * dL_dchannel;


			// 	local_dL_dcolors[ch] = skip ? 0.0f : dchannel_dcolor * dL_dchannel;
			// }

			// dL_dcolors_shared[tid].x = local_dL_dcolors[0];
			// dL_dcolors_shared[tid].y = local_dL_dcolors[1];
			// dL_dcolors_shared[tid].z = local_dL_dcolors[2];

			// const float depth = collected_depths[j];
			// accum_rec_depth = skip ? accum_rec_depth : last_alpha * last_depth + (1.f - last_alpha) * accum_rec_depth;
			// last_depth = skip ? last_depth : depth;

    
			// dL_dalpha += (depth - accum_rec_depth) * dL_dpixel_depth;
			// dL_ddepths_shared[tid] = skip ? 0.f : dchannel_dcolor * dL_dpixel_depth;

    

			// dL_dalpha *= T;
			// // Update last alpha (to be used in the next iteration)

            

			// last_alpha = skip ? last_alpha : alpha;

            //완료, tb 확인 필요

			// // Account for fact that alpha also influences how much of
			// // the background color is added if nothing left to blend
			// float bg_dot_dpixel = 0.f;
			// #pragma unroll
			// for (int i = 0; i < C; i++) {
			// 	bg_dot_dpixel +=  bg_color[i] * dL_dpixel[i];
			// }

			// dL_dalpha += (-T_final / (1.f - alpha)) * bg_dot_dpixel;
