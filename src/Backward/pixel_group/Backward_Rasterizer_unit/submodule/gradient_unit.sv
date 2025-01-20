module gradient_unit
    #(
        parameter BLOCK_SIZE = 16,
        parameter exponent_bit = 8,
        parameter mantissa_bit = 7,
        parameter precision = 16,
        parameter GID_bit = 24
    )
    (
    input logic clk,
    input logic rst_n,

    input logic [11:0] W, // int32
    input logic [11:0] H, // int32 

    input logic [precision - 1:0] G,
    input logic [(2 * precision) - 1:0] d,
    input logic [(4 * precision) - 1:0] conic_opacity, // | X | Y | Z | W |

    input logic [precision-1:0] alpha_in, // alpha_i (이전 step에서 계산한거)
    input logic stall,

    input logic last_input,


    // 초기 T값 정의 용
    input logic [precision-1:0] T_first,
    input logic start,
    input logic [(3 * precision)-1:0] dL_dpixel, // dL_dpixel
    input logic [precision-1:0] dL_dpixel_depth,

    input logic [GID_bit-1:0] gaussian_id_in,
    input logic [(3 * precision)-1:0] gaussian_color, // | R | G | B |
    input logic [precision-1:0] gaussian_depth,

    input logic i_valid, // !skip signal


    output logic [GID_bit-1:0] gaussian_id_out,
    output logic [(3 * precision)-1:0] dL_dcolor,
    output logic [precision-1:0] dL_ddepth,
    output logic [(2 * precision) - 1:0] dL_dmean2D,
    output logic [(4 * precision) - 1:0] dL_dconic,
    output logic [precision - 1:0] dL_dopacity, //tracking시 불필요

    output logic gradient_valid_out,

    output logic last_input_done 

    );
    // synopsys template

    localparam ieee_compliance = 1'b0;
    
    // Register declaration
    logic [precision - 1 : 0] alpha0, alpha1, alpha2;
    logic [precision - 1 : 0] T2, T3, T4, T5;

    logic [precision - 1 : 0] last_alpha2;
    logic [precision - 1 : 0] last_depth2;
    logic [(3 * precision) - 1:0] last_color2;
    logic [(3 * precision)-1:0] accum_rec2;
    logic [precision - 1 : 0] accum_rec_depth2;


    logic [precision - 1 : 0] G0, G1, G2, G3, G4, G5, G6;
    logic [(2 * precision) - 1 : 0] d0, d1, d2;
    logic [11:0] W0, H0;
    logic [(4 * precision) - 1:0] conic_opacity0, conic_opacity1, conic_opacity2, conic_opacity3, conic_opacity4, conic_opacity5, conic_opacity6;

    logic [(3 * precision) - 1:0] gaussian_color0, gaussian_color1, gaussian_color2;
    logic [precision - 1 : 0] gaussian_depth0, gaussian_depth1, gaussian_depth2;

    logic [(3 * precision) - 1:0] dL_dpixel3;
    logic [precision - 1 : 0] dL_dpixel_depth3;

    logic [precision-1:0] dchannel_dcolor3;
    logic [precision-1:0] dL_dalpha6;

    logic [precision-1:0] ddelx_dx1, ddelx_dx2;
    logic [precision-1:0] ddely_dy1, ddely_dy2;

    logic i_valid0, i_valid1, i_valid2, i_valid3, i_valid4, i_valid5, i_valid6, i_valid7;

    logic [(3 * precision) - 1:0] diff_color3;
    logic [precision-1:0] diff_depth3;
    
    logic [precision - 1:0] dL_ddepth4, dL_ddepth5, dL_ddepth6, dL_ddepth7;
    logic [(3 * precision) - 1:0] dL_dcolor4, dL_dcolor5, dL_dcolor6, dL_dcolor7;

    logic [precision-1:0] One_minus_alpha1;

    logic [precision-1:0] gdx1, gdx2;
    logic [precision-1:0] gdy1, gdy2;

    logic [precision-1:0] dG_ddelx2, dG_ddely2;
    logic [precision-1:0] d_x_gdx2, d_x_gdx3, d_x_gdx4, d_x_gdx5, d_x_gdx6, d_x_gdx7;
    logic [precision-1:0] d_y_gdx2, d_y_gdx3, d_y_gdx4, d_y_gdx5, d_y_gdx6, d_y_gdx7;
    logic [precision-1:0] d_y_gdy2, d_y_gdy3, d_y_gdy4, d_y_gdy5, d_y_gdy6, d_y_gdy7;

    logic [precision-1:0] dG_dx3, dG_dx4, dG_dx5, dG_dx6, dG_dx7;
    logic [precision-1:0] dG_dy3, dG_dy4, dG_dy5, dG_dy6, dG_dy7;

    logic [precision-1:0] dL_dalpha_added4_1, dL_dalpha_added4_2, dL_dalpha_added5;    
    logic [precision-1:0] dL_dG7;
    logic [precision-1:0] dL_dopacity7;

    logic [precision-1:0] One0, One1;

    logic [GID_bit-1:0] gaussian_id0, gaussian_id1, gaussian_id2, gaussian_id3, gaussian_id4, gaussian_id5, gaussian_id6, gaussian_id7;

    logic last_input0, last_input1, last_input2, last_input3, last_input4, last_input5, last_input6, last_input7;

    // dL_dpixel, dL_ddepth = 0 Signal
    reg both_pixel_grad_zero;


    // Wire 선언
    logic [precision-1:0] One_minus_alpha_temp;
    logic [precision-1:0] gdx_temp, gdy_temp;
    logic [precision-1:0] T2_temp, T2_final;

    logic [precision-1:0] ddelx_dx1_temp, ddely_dy1_temp;

    logic [(3 * precision) - 1:0] accum_rec2_temp, accum_rec2_final, last_color2_final, diff_color3_temp;
    logic [precision - 1:0] accum_rec_depth2_temp, accum_rec_depth2_final;
    logic [precision - 1:0] last_depth2_final, last_alpha2_final;

    logic [precision-1:0] dG_ddelx2_temp, dG_ddely2_temp;
    logic [precision-1:0] dG_ddelx2_calc, dG_ddely2_calc;
    
    logic [precision-1:0] dchannel_dcolor3_temp;

    logic [precision-1:0] diff_depth3_temp;
    logic [precision-1:0] dL_dalpha_added4_temp1, dL_dalpha_added4_temp2, dL_dalpha_added5_temp;

    logic [(3 * precision) - 1:0] dL_dcolor_temp4;

    logic [precision-1:0] dL_dalpha6_temp;
    logic [precision-1:0] dL_ddepth_temp4;
    logic [precision-1:0] dL_dG7_temp;    
    
    logic [precision-1:0] dL_ddepth_calc4;
    logic [(3 * precision) - 1:0] dL_dcolor_calc4;
    

    logic [precision-1:0] d_x_gdx2_temp, d_y_gdx2_temp, d_y_gdy2_temp;

    logic [precision-1:0] dG_dx3_temp, dG_dy3_temp;

    logic [(2 * precision) -1 : 0] dL_dmean2D8_temp;
    logic [(4 * precision) - 1:0] dL_dconic8_temp;

    logic [(2 * precision) -1 : 0] dL_dmean2D8_calc;
    logic [(3 * precision) - 1:0] dL_dconic8_calc;
    logic [precision-1:0] One;

    logic [precision-1:0] dL_dopacity7_temp;
    logic [precision-1:0] dL_dopacity7_calc;

    logic [precision-1:0] d_x_gdx2_calc, d_y_gdx2_calc, d_y_gdy2_calc;


    assign One = (precision == 32 && mantissa_bit == 23) ? 32'h3f80_0000 :
                    (precision == 16 && mantissa_bit == 7) ? 16'h3f80 :
                    (precision == 24 && mantissa_bit == 15) ? 24'h3f80_00 :
                    {precision{1'b0}};
    

    // logic [(3 * precision)-1:0] accum_rec_temp, accum_rec_skip_temp;
    logic [7:0] status_inst [1:38]; 

    // logic [precision-1:0] dL_dalpha_temp, dL_dalpha_temp2, dL_dalpha_temp3, dL_dalpha_temp4, dL_dalpha_temp5, dL_dalpha_temp6;
    // logic [precision-1:0] dL_dalpha_skip_temp, dL_dalpha_skip_temp2, dL_dalpha_skip_temp3, dL_dalpha_skip_temp4, dL_dalpha_skip_temp5, dL_dalpha_skip_temp6;

    logic [precision-1:0] One_minus_last_alpha1_temp;


    ////////////////////////////////////////////////////////////////////
    //////////////////////////// Clock Step 0 //////////////////////////
    ////////////////////////////////////////////////////////////////////

    // 1 - alpha
    DW_fp_add #(mantissa_bit, exponent_bit, 0)
	  One_minus_alpha_maker ( .a(One0), .b({!alpha0[precision-1] ,alpha0[precision-2:0]}), .rnd(3'b0), .z(One_minus_alpha_temp), .status(status_inst[1]) );

    // gdx = G * d.x
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
	  gdx_maker ( .a(G0), .b(d0[(2 * precision) -1 : precision]), .rnd(3'b0), .z(gdx_temp), .status(status_inst[2]) );

    // gdy = G * d.y
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
	  gdy_maker ( .a(G0), .b(d0[ precision - 1 : 0]), .rnd(3'b0), .z(gdy_temp), .status(status_inst[3]) );

    // ddelx_dx = W/2 
    DW_fp_i2flt #(mantissa_bit, exponent_bit, precision, 1)
	  ddelx_dx_maker ( .a({{(precision-12){1'b0}}, W0[11:0]} ), .rnd(3'b0), .z(ddelx_dx1_temp), .status(status_inst[4]));

    // ddely_dy = H/2 
    DW_fp_i2flt #(mantissa_bit, exponent_bit, precision, 1)
	  ddely_dy_maker ( .a({{(precision-12){1'b0}}, H0[11:0]} ), .rnd(3'b0), .z(ddely_dy1_temp), .status(status_inst[5]));


    ////////////////////////////////////////////////////////////////////
    //////////////////////////// Clock Step 1 //////////////////////////
    ////////////////////////////////////////////////////////////////////
    // Clock 1 ~ 2 Stage is for not to delay additional clocks 
    // So can be possible weakness

    // 1 - last_alpha
    DW_fp_add #(mantissa_bit, exponent_bit, 0)
	  One_minus_last_alpha_maker ( .a(One1), .b({!last_alpha2[precision-1], last_alpha2[precision-2:0]}), .rnd(3'b0), .z(One_minus_last_alpha1_temp), .status(status_inst[6]) );

    // T = skip ? T : T / (1 - alpha)
    DW_fp_div #(mantissa_bit, exponent_bit, ieee_compliance, 1'b0, 1'b0)
     T_temp_maker ( .a(T2), .b(One_minus_alpha1), .rnd(3'b0), .z(T2_temp), .status(status_inst[7]));

    // 	accum_rec[ch] = skip ? accum_rec[ch] : last_alpha * last_color[ch] + (1.f - last_alpha) * accum_rec[ch];
    DW_fp_dp2 #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
     accum_rec_R_maker ( .a(last_alpha2), .b(last_color2[(3 * precision) - 1 : 2 * precision]), .c(One_minus_last_alpha1_temp), .d(accum_rec2[(3 * precision) - 1 : 2 * precision]), .rnd(3'b0), .z(accum_rec2_temp[(3 * precision) - 1 : 2 * precision]), .status(status_inst[8]) );

    DW_fp_dp2 #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
     accum_rec_G_maker ( .a(last_alpha2), .b(last_color2[(2 * precision) - 1 : precision]), .c(One_minus_last_alpha1_temp), .d(accum_rec2[(2 * precision) - 1 : precision]), .rnd(3'b0), .z(accum_rec2_temp[(2 * precision) - 1 : precision]), .status(status_inst[9]) );

    DW_fp_dp2 #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
     accum_rec_B_maker ( .a(last_alpha2), .b(last_color2[precision - 1 : 0]), .c(One_minus_last_alpha1_temp), .d(accum_rec2[precision - 1 : 0]), .rnd(3'b0), .z(accum_rec2_temp[precision - 1 : 0]), .status(status_inst[10]) );

    // accum_rec_depth = skip ? accum_rec_depth : last_alpha * last_depth + (1.f - last_alpha) * accum_rec_depth;
    DW_fp_dp2 #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
     accum_rec_depth_maker ( .a(last_alpha2), .b(last_depth2), .c(One_minus_last_alpha1_temp), .d(accum_rec_depth2), .rnd(3'b0), .z(accum_rec_depth2_temp), .status(status_inst[11]) );


    // assign T2_final = T1_first_valid ? T1_first : (i_valid1 ? T2_temp : T2);
    // assign T2_final = started ? T2 : (i_valid1 ? T2_temp : T2);
    assign T2_final = i_valid1 ? T2_temp : T2;

    assign last_alpha2_final = i_valid1 ? alpha1 : last_alpha2;
    assign last_color2_final = i_valid1 ? gaussian_color1 : last_color2;
    assign last_depth2_final = i_valid1 ? gaussian_depth1 : last_depth2;
    assign accum_rec2_final = i_valid1 ? accum_rec2_temp : accum_rec2;
    assign accum_rec_depth2_final = i_valid1 ? accum_rec_depth2_temp : accum_rec_depth2;

    // const float dG_ddelx = -gdx * con_o.x - gdy * con_o.y;
    DW_fp_dp2 #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
     dG_ddelx_maker ( .a(gdx1), .b(conic_opacity1[(4 * precision) - 1: (3 * precision) ]), .c(gdy1), .d(conic_opacity1[(3*precision)-1:(2*precision)]), .rnd(3'b0), .z(dG_ddelx2_calc), .status(status_inst[12]) );

    // const float dG_ddely = -gdy * con_o.z - gdx * con_o.y;
    DW_fp_dp2 #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
     dG_ddely_maker ( .a(gdy1), .b(conic_opacity1[(2 * precision) - 1:precision]), .c(gdx1), .d(conic_opacity1[(3*precision)-1:(2*precision)]), .rnd(3'b0), .z(dG_ddely2_calc), .status(status_inst[13]) );

     assign dG_ddely2_temp = (dG_ddelx2_calc == 'h0) ? 'h0 : dG_ddely2_calc;
     assign dG_ddelx2_temp = (dG_ddelx2_calc == 'h0) ? 'h0 : dG_ddelx2_calc;


    // 	dL_dconic2D_shared[tid].x = skip ? 0.f : -0.5f * gdx * d.x * dL_dG; 
    // 	dL_dconic2D_shared[tid].y = skip ? 0.f : -0.5f * gdx * d.y * dL_dG;
    // 	dL_dconic2D_shared[tid].w = skip ? 0.f : -0.5f * gdy * d.y * dL_dG;
    // DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
	//   d_x_gdx_maker ( .a({!gdx1[precision-1], (gdx1[precision-2:mantissa_bit] - 8'd1), gdx1[mantissa_bit-1:0]}), .b(d1[(2 * precision)-1 : precision]), .rnd(3'b0), .z(d_x_gdx2_temp), .status(status_inst[14]) );

    // DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
	//   d_y_gdx_maker ( .a({!gdx1[precision-1], (gdx1[precision-2:mantissa_bit] - 8'd1), gdx1[mantissa_bit-1:0]}), .b(d1[precision - 1 : 0]), .rnd(3'b0), .z(d_y_gdx2_temp), .status(status_inst[15]) );

    // DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
	//   d_y_gdy_maker ( .a({!gdy1[precision-1], (gdy1[precision-2:mantissa_bit] - 8'd1), gdy1[mantissa_bit-1:0]}), .b(d1[precision - 1 : 0]), .rnd(3'b0), .z(d_y_gdy2_temp), .status(status_inst[16]) );


    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
	  d_x_gdx_maker ( .a({!gdx1[precision-1], (gdx1[precision-2:mantissa_bit] - 8'd1), gdx1[mantissa_bit-1:0]}), .b(d1[(2 * precision)-1 : precision]), .rnd(3'b0), .z(d_x_gdx2_calc), .status(status_inst[14]) );

    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
	  d_y_gdx_maker ( .a({!gdx1[precision-1], (gdx1[precision-2:mantissa_bit] - 8'd1), gdx1[mantissa_bit-1:0]}), .b(d1[precision - 1 : 0]), .rnd(3'b0), .z(d_y_gdx2_calc), .status(status_inst[15]) );

    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
	  d_y_gdy_maker ( .a({!gdy1[precision-1], (gdy1[precision-2:mantissa_bit] - 8'd1), gdy1[mantissa_bit-1:0]}), .b(d1[precision - 1 : 0]), .rnd(3'b0), .z(d_y_gdy2_calc), .status(status_inst[16]) );

    
    // assign d_x_gdx2_temp = (d_x_gdx2_calc[precision-2:0] == {(precision-1){1'b0}}) ? 'h0 : d_x_gdx2_calc;
    // assign d_y_gdx2_temp = (d_y_gdx2_calc[precision-2:0] == {(precision-1){1'b0}}) ? 'h0 : d_y_gdx2_calc;
    // assign d_y_gdy2_temp = (d_y_gdy2_calc[precision-2:0] == {(precision-1){1'b0}}) ? 'h0 : d_y_gdy2_calc;

    assign d_x_gdx2_temp = (gdx1[precision-2:0] == {(precision-1){1'b0}}) ? 'h0 : d_x_gdx2_calc;
    assign d_y_gdx2_temp = (gdx1[precision-2:0] == {(precision-1){1'b0}}) ? 'h0 : d_y_gdx2_calc;
    assign d_y_gdy2_temp = (gdy1[precision-2:0] == {(precision-1){1'b0}}) ? 'h0 : d_y_gdy2_calc;



    // gdx == 'h0, gdx 는 걍 0 으로 처리해야 함
    // gdy == 'h0, gdy 는 걍 0 으로 처리해야 함

    ////////////////////////////////////////////////////////////////////
    //////////////////////////// Clock Step 2 //////////////////////////
    ////////////////////////////////////////////////////////////////////
    // logicister T, last and accum_rec series are stored in Clock Step 2

    // const float dchannel_dcolor = alpha * T;
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
	  dL_dch_dcolor ( .a(T2), .b(alpha2), .rnd(3'b0), .z(dchannel_dcolor3_temp), .status(status_inst[17]) );

    // (c - accum_rec[ch])
    DW_fp_add #(mantissa_bit, exponent_bit, 0)
	  diff_color_R_maker ( .a(gaussian_color2[(3 * precision) - 1 : (2 * precision)]), .b({!accum_rec2[(3 * precision) - 1], accum_rec2[(3 * precision) - 2:(2 * precision)]}), .rnd(3'b0), .z(diff_color3_temp[(3 * precision) - 1 : (2 * precision)]), .status(status_inst[18]) );

    DW_fp_add #(mantissa_bit, exponent_bit, 0)
	  diff_color_G_maker ( .a(gaussian_color2[(2 * precision) - 1 : precision]), .b({!accum_rec2[(2 * precision) - 1], accum_rec2[(2 * precision) - 2: precision]}), .rnd(3'b0), .z(diff_color3_temp[(2 * precision) - 1 : precision]), .status(status_inst[19]) );

    DW_fp_add #(mantissa_bit, exponent_bit, 0)
	  diff_color_B_maker ( .a(gaussian_color2[precision - 1 : 0]), .b({!accum_rec2[precision - 1], accum_rec2[precision - 2:0]}), .rnd(3'b0), .z(diff_color3_temp[precision - 1 : 0]), .status(status_inst[20]) );

    // (depth - accum_rec_depth)
    DW_fp_add #(mantissa_bit, exponent_bit, 0)
	  diff_depth_maker ( .a(gaussian_depth2), .b({!accum_rec_depth2[precision-1], accum_rec_depth2[precision-2:0]}), .rnd(3'b0), .z(diff_depth3_temp), .status(status_inst[21]) );

    // dG_ddelx * ddelx_dx; for dL_dmean2D.x
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
	  dG_dx_maker ( .a(dG_ddelx2), .b(ddelx_dx2), .rnd(3'b0), .z(dG_dx3_temp), .status(status_inst[22]) );
    
    // dG_ddely * ddely_dy; for dL_dmean2D.y
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
	  dG_dy_maker ( .a(dG_ddely2), .b(ddely_dy2), .rnd(3'b0), .z(dG_dy3_temp), .status(status_inst[23]) );
    
    // assign T3_final = T1_first_valid ? T1_first : T2;
    ////////////////////////////////////////////////////////////////////
    //////////////////////////// Clock Step 3 //////////////////////////
    ////////////////////////////////////////////////////////////////////
    
    // // dL_dalpha += (c - accum_rec[ch]) * dL_dpixel[ch];
    // // dL_dalpha += (depth - accum_rec_depth) * dL_dpixel_depth;
    // DW_fp_dp4 #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
    //  dL_dalpha_adder ( .a(diff_color3[(3 * precision) - 1 : (2 * precision)]), .b(dL_dpixel3[(3 * precision) - 1 : (2 * precision)]), .c(diff_color3[(2 * precision) - 1 : precision]), .d(dL_dpixel3[(2 * precision) - 1 : precision]), 
    //  .e(diff_color3[precision - 1 : 0]), .f(dL_dpixel3[precision - 1 : 0]), .g(diff_depth3), .h(dL_dpixel_depth3), .rnd(3'b0), .z(dL_dalpha_added4_temp), .status(status_inst[23]) );

    // dL_dalpha += (c - accum_rec[ch]) * dL_dpixel[ch];
    // dL_dalpha += (depth - accum_rec_depth) * dL_dpixel_depth;
    DW_fp_dp2 #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
     dL_dalpha_maker1 ( .a(diff_color3[(3 * precision) - 1 : (2 * precision)]), .b(dL_dpixel3[(3 * precision) - 1 : (2 * precision)]), .c(diff_color3[(2 * precision) - 1 : precision]), .d(dL_dpixel3[(2 * precision) - 1 : precision]), .rnd(3'b0), .z(dL_dalpha_added4_temp1), .status(status_inst[24]) );

    DW_fp_dp2 #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
     dL_dalpha_maker2 ( .a(diff_color3[precision - 1 : 0]), .b(dL_dpixel3[precision - 1 : 0]), .c(diff_depth3), .d(dL_dpixel_depth3), .rnd(3'b0), .z(dL_dalpha_added4_temp2), .status(status_inst[25]) );

    // // 사이클 하나 더 늘리자... 
    // DW_fp_add #(mantissa_bit, exponent_bit, 0)
	//   dL_dalpha_adder ( .a(dL_dalpha_added4_temp1), .b(dL_dalpha_added4_temp2), .rnd(3'b0), .z(dL_dalpha_added4_temp), .status(status_inst[37]) );

    // dividing dp4 (critical path)



    // dL_dcolors[ch] = skip ? 0.0f : dchannel_dcolor * dL_dchannel; 
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
	  dL_dcolor_temp_R ( .a(dL_dpixel3[(3 * precision)-1: 2*precision]), .b(dchannel_dcolor3), .rnd(3'b0), .z(dL_dcolor_calc4[(3 * precision)-1: 2 * precision]), .status(status_inst[26]) );

    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
	  dL_dcolor_temp_G ( .a(dL_dpixel3[(2 * precision)-1:precision]), .b(dchannel_dcolor3), .rnd(3'b0), .z(dL_dcolor_calc4[(2 * precision)-1:precision]), .status(status_inst[27]) );

    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
	  dL_dcolor_temp_B ( .a(dL_dpixel3[precision-1:0]), .b(dchannel_dcolor3), .rnd(3'b0), .z(dL_dcolor_calc4[precision-1:0]), .status(status_inst[28]) );
 

    // dL_ddepths_shared[tid] = skip ? 0.f : dchannel_dcolor * dL_dpixel_depth;
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
	  dL_ddepth_maker ( .a(dL_dpixel_depth3), .b(dchannel_dcolor3), .rnd(3'b0), .z(dL_ddepth_calc4), .status(status_inst[29]) );


    
    assign dL_ddepth_temp4 = (dL_ddepth_calc4[precision - 2: 0] == {(precision - 1){1'b0}}) ? {precision{1'b0}} : dL_ddepth_calc4[precision - 1: 0];

    assign dL_dcolor_temp4[(3 * precision) - 1: (2 * precision)] =  (dL_dcolor_calc4[(3 * precision) - 2: (2 * precision)] == {(precision - 1){1'b0}}) ? {precision{1'b0}} : dL_dcolor_calc4[(3 * precision) - 1: (2 * precision)];
    assign dL_dcolor_temp4[(2 * precision) - 1: precision] =        (dL_dcolor_calc4[(2 * precision) - 2: precision] == {(precision - 1){1'b0}}) ? {precision{1'b0}} : dL_dcolor_calc4[(2 * precision) - 1: precision];
    assign dL_dcolor_temp4[precision - 1: 0] =                      (dL_dcolor_calc4[precision - 2: 0] == {(precision - 1){1'b0}}) ? {precision{1'b0}} : dL_dcolor_calc4[precision - 1: 0];



    ////////////////////////////////////////////////////////////////////
    //////////////////////////// Clock Step 4 //////////////////////////
    ////////////////////////////////////////////////////////////////////


    // 사이클 하나 더 늘리자... 
    DW_fp_add #(mantissa_bit, exponent_bit, 0)
	  dL_dalpha_adder ( .a(dL_dalpha_added4_1), .b(dL_dalpha_added4_2), .rnd(3'b0), .z(dL_dalpha_added5_temp), .status(status_inst[30]) );
    

    ////////////////////////////////////////////////////////////////////
    //////////////////////////// Clock Step 5 //////////////////////////
    ////////////////////////////////////////////////////////////////////
    
    // dL_dalpha *= T;
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
	  dL_dalpha_maker_from_T ( .a(dL_dalpha_added5), .b(T5), .rnd(3'b0), .z(dL_dalpha6_temp), .status(status_inst[31]) );


    ////////////////////////////////////////////////////////////////////
    //////////////////////////// Clock Step 6 //////////////////////////
    ////////////////////////////////////////////////////////////////////

    // const float dL_dG = con_o.w * dL_dalpha;
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
	  dL_dG_maker ( .a(dL_dalpha6), .b(conic_opacity6[precision - 1: 0]), .rnd(3'b0), .z(dL_dG7_temp), .status(status_inst[32]) );

    // const float dL_dopacity = G * dL_dalpha;
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
	  dL_dopacity_maker ( .a(dL_dalpha6), .b(G6), .rnd(3'b0), .z(dL_dopacity7_calc), .status(status_inst[33]) );
    
    assign dL_dopacity7_temp = (dL_dopacity7_calc[precision - 2: 0] == {(precision - 1){1'b0}}) ? {precision{1'b0}} : dL_dopacity7_calc[precision - 1: 0];


    ////////////////////////////////////////////////////////////////////
    //////////////////////////// Clock Step 7 //////////////////////////
    ////////////////////////////////////////////////////////////////////

    // 	dL_dmean2D_shared[tid].x = skip ? 0.f : dL_dG * dG_ddelx * ddelx_dx;  전단계 계산 가능
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
	  dL_dmean2D_x_maker ( .a(dL_dG7), .b(dG_dx7), .rnd(3'b0), .z(dL_dmean2D8_calc[(2 * precision) - 1 : precision]), .status(status_inst[34]) );
    
    // 	dL_dmean2D_shared[tid].y = skip ? 0.f : dL_dG * dG_ddely * ddely_dy;  전단계 계산 가능
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
	  dL_dmean2D_y_maker ( .a(dL_dG7), .b(dG_dy7), .rnd(3'b0), .z(dL_dmean2D8_calc[precision - 1 : 0]), .status(status_inst[35]) );


    assign dL_dmean2D8_temp[(2 * precision) - 1 : precision] = (dL_dmean2D8_calc[(2 * precision - 2) : precision] == {(precision - 1){1'b0}}) ? {precision{1'b0}} : dL_dmean2D8_calc[(2 * precision) - 1 : precision];
    assign dL_dmean2D8_temp[precision - 1 : 0] = (dL_dmean2D8_calc[precision - 2: 0] == {(precision - 1){1'b0}}) ? {precision{1'b0}} : dL_dmean2D8_calc[precision - 1: 0];


    //	dL_dconic2D_shared[tid].x = skip ? 0.f : -0.5f * gdx * d.x * dL_dG;
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
	  dL_dconic_x_maker ( .a(dL_dG7), .b(d_x_gdx7), .rnd(3'b0), .z(dL_dconic8_calc[(3 * precision) - 1 : (2 * precision)]), .status(status_inst[36]) );

    // 	dL_dconic2D_shared[tid].y = skip ? 0.f : -0.5f * gdx * d.y * dL_dG;
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
	  dL_dconic_y_maker ( .a(dL_dG7), .b(d_y_gdx7), .rnd(3'b0), .z(dL_dconic8_calc[(2 * precision) - 1 : precision]), .status(status_inst[37]) );

    // 	dL_dconic2D_shared[tid].w = skip ? 0.f : -0.5f * gdy * d.y * dL_dG;
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
	  dL_dconic_w_maker ( .a(dL_dG7), .b(d_y_gdy7), .rnd(3'b0), .z(dL_dconic8_calc[precision - 1 : 0]), .status(status_inst[38]) );

    assign dL_dconic8_temp[(2 * precision) - 1: precision] = {precision{1'b0}}; 

    assign dL_dconic8_temp[(4 * precision) - 1 : (3 * precision)] = (dL_dconic8_calc[(3 * precision) - 2 : (2 * precision)] == {(precision-1){1'b0}}) ? {precision{1'b0}} : dL_dconic8_calc[(3 * precision) - 1 : (2 * precision)];
    assign dL_dconic8_temp[(3 * precision) - 1 : (2 * precision)] = (dL_dconic8_calc[(2 * precision) - 2 : precision] == {(precision-1){1'b0}}) ? {precision{1'b0}} : dL_dconic8_calc[(2 * precision) - 1 : precision];
    assign dL_dconic8_temp[precision - 1: 0] = (dL_dconic8_calc[precision - 2: 0] == {(precision - 1){1'b0}}) ? {precision{1'b0}} : dL_dconic8_calc[precision - 1: 0];


    ////////////////////////////////////////////////////////////////////
    //////////////////////////// Clock Step 8 //////////////////////////
    ////////////////////////////////////////////////////////////////////


    always_ff @ (posedge clk) begin
        if (!rst_n) begin
            // Reset all scalar and multi-bit logicisters to 'h0
            alpha0 <= 'h0; alpha1 <= 'h0; alpha2 <= 'h0;
            T2 <= 'h0; T3 <= 'h0; T4 <= 'h0; T5 <= 'h0;
            One0 <= One; One1 <= One;

            i_valid0 <= 1'b0; i_valid1 <= 1'b0; i_valid2 <= 1'b0; 
            i_valid3 <= 1'b0; i_valid4 <= 1'b0; i_valid5 <= 1'b0; i_valid6 <= 1'b0; i_valid7 <= 'b0;

            last_alpha2 <= 'h0;
            last_depth2 <= 'h0;
            last_color2 <= 'h0;

            accum_rec2 <= 'h0;
            accum_rec_depth2 <= 'h0;

            G0 <= 'h0; G1 <= 'h0; G2 <= 'h0; 
            G3 <= 'h0; G4 <= 'h0; G5 <= 'h0; G6 <= 'h0;

            d0 <= 'h0; d1 <= 'h0; d2 <= 'h0;

            W0 <= 12'h0; H0 <= 12'h0;

            conic_opacity0 <= 'h0; conic_opacity1 <= 'h0;
            conic_opacity2 <= 'h0; conic_opacity3 <= 'h0;
            conic_opacity4 <= 'h0; conic_opacity5 <= 'h0; conic_opacity6 <= 'h0;

            gaussian_color0 <= 'h0; gaussian_color1 <= 'h0; gaussian_color2 <= 'h0;
            gaussian_depth0 <= 'h0; gaussian_depth1 <= 'h0; gaussian_depth2 <= 'h0;


            dL_dpixel3 <= 'h0;

            dL_dpixel_depth3 <= 'h0;

            dchannel_dcolor3 <= 'h0;
            dL_dalpha6 <= 'h0;
    

            dL_dcolor4 <= 'h0; dL_dcolor5 <= 'h0; 
            dL_dcolor6 <= 'h0; dL_dcolor7 <= 'h0;
            dL_dcolor <= 'h0;

            dL_ddepth4 <= 'h0; dL_ddepth5 <= 'h0; 
            dL_ddepth6 <= 'h0; dL_ddepth7 <= 'h0;
            dL_ddepth <= 'h0;

            dL_dopacity <= 'h0;
            dL_dconic <= 'h0;
            dL_dmean2D <= 'h0;

            One_minus_alpha1 <= 'h0;
            // One_minus_last_alpha1_temp <= 'h0;

            gdx1 <= 'h0; gdx2 <= 'h0;
            gdy1 <= 'h0; gdy2 <= 'h0;

            ddelx_dx1 <= 'h0; ddelx_dx2 <= 'h0;
            ddely_dy1 <= 'h0; ddely_dy2 <= 'h0;

            dG_ddelx2 <= 'h0; dG_ddely2 <= 'h0;
            d_x_gdx2 <= 'h0; d_x_gdx3 <= 'h0; d_x_gdx4 <= 'h0;
            d_x_gdx5 <= 'h0; d_x_gdx6 <= 'h0; d_x_gdx7 <= 'h0;

            d_y_gdx2 <= 'h0; d_y_gdx3 <= 'h0; d_y_gdx4 <= 'h0;
            d_y_gdx5 <= 'h0; d_y_gdx6 <= 'h0; d_y_gdx7 <= 'h0;

            d_y_gdy2 <= 'h0; d_y_gdy3 <= 'h0; d_y_gdy4 <= 'h0;
            d_y_gdy5 <= 'h0; d_y_gdy6 <= 'h0; d_y_gdy7 <= 'h0;

            dG_dx3 <= 'h0; dG_dx4 <= 'h0; dG_dx5 <= 'h0; dG_dx6 <= 'h0; dG_dx7 <= 'h0;
            dG_dy3 <= 'h0; dG_dy4 <= 'h0; dG_dy5 <= 'h0; dG_dy6 <= 'h0; dG_dy7 <= 'h0;

            dL_dalpha_added4_1 <= 'h0; dL_dalpha_added4_2 <= 'h0;
            dL_dalpha_added5 <= 'h0;
            dL_dG7 <= 'h0;
            dL_dopacity7 <= 'h0;

            diff_color3 <= 'h0;
            diff_depth3 <= 'h0;


            gaussian_id0 <= 'h0;
            gaussian_id1 <= 'h0;
            gaussian_id2 <= 'h0;
            gaussian_id3 <= 'h0;
            gaussian_id4 <= 'h0;
            gaussian_id5 <= 'h0;
            gaussian_id6 <= 'h0;
            gaussian_id7 <= 'h0;

            // Reset output logicisters
            dL_dcolor <= 'h0;
            dL_ddepth <= 'h0;
            dL_dmean2D <= 'h0;
            dL_dconic <= 'h0;
            dL_dopacity <= 'h0;
            gradient_valid_out <= 1'b0;
            gaussian_id_out <= 'h0;

            last_input0 <= 'b0;
            last_input1 <= 'b0;
            last_input2 <= 'b0;
            last_input3 <= 'b0;
            last_input4 <= 'b0;
            last_input5 <= 'b0;
            last_input6 <= 'b0;
            last_input7 <= 'b0;
            last_input_done <= 'b0;

            both_pixel_grad_zero <= 'b0;

        end


        else begin

            if (!stall) begin

                if (start) begin
                    T2 <= T_first;
                    dL_dpixel3 <= dL_dpixel;
                    dL_dpixel_depth3 <= dL_dpixel_depth;
                    W0 <= (W >> 1);
                    H0 <= (H >> 1);
                    
                    accum_rec2 <= 'h0;
                    accum_rec_depth2 <= 'h0;
                    last_color2 <= 'h0;
                    last_depth2 <= 'h0;
                    last_alpha2 <= 'h0;

                    if (dL_dpixel == 'h0 && dL_dpixel_depth == 'h0) begin
                        both_pixel_grad_zero <= 'b1;
                        // last_input_done <= 1'b1;
                    end

                    else begin
                        both_pixel_grad_zero <= 'b0;
                    end


                end


                //start 신호가 들어오지 않은 경우 정상 작동
                else begin
                    accum_rec2 <= accum_rec2_final; 
                    accum_rec_depth2 <= accum_rec_depth2_final;
                    last_color2 <= last_color2_final;
                    last_depth2 <= last_depth2_final;
                    last_alpha2 <= last_alpha2_final;
                    T2 <= T2_final;

                end

                // 이전 last_input_done 처리 방식
                if (start) begin
                    last_input_done <= 1'b0;
                end

                else if (last_input7) begin
                    last_input_done <= 1'b1;
                end

                // 변경 last_input_done 처리 방식
                // if (start || last_input_done) begin
                //     last_input_done <= 1'b0;
                // end

                // else begin
                //     last_input_done <= last_input7;
                // end

                ////////////////////////////////////////////////////////////////////
                //////////////////// Start 신호시 초기값 입력 ////////////////////////
                ////////////////////////////////////////////////////////////////////



                ////////////////////////////////////////////////////////////////////
                ///////////////////////// Clock 0 Data Input ///////////////////////
                ////////////////////////////////////////////////////////////////////

                // Example assignments for logicister updates
                G0 <= G;
                d0 <= d;
                conic_opacity0 <= conic_opacity;

                alpha0 <= alpha_in;
                
                gaussian_color0 <= gaussian_color;
                gaussian_depth0 <= gaussian_depth;

                i_valid0 <= i_valid;

                One0 <= One; One1 <= One;

                gaussian_id0 <= gaussian_id_in;

                last_input0 <= last_input;
                ////////////////////////////////////////////////////////////////////
                ///////////////////////// Clock 1 Data Flow ///////////////////////
                ////////////////////////////////////////////////////////////////////

                G1 <= G0;
                d1 <= d0;
                conic_opacity1 <= conic_opacity0;

                alpha1 <= alpha0;


                i_valid1 <= i_valid0;
                
                
                // additional logicisters
                One_minus_alpha1 <= One_minus_alpha_temp;
                // One_minus_last_alpha1 <= One_minus_last_alpha_temp;

                gdx1 <= gdx_temp;
                gdy1 <= gdy_temp;

                ddelx_dx1 <= ddelx_dx1_temp;
                ddely_dy1 <= ddely_dy1_temp;

                gaussian_color1 <= gaussian_color0;
                gaussian_depth1 <= gaussian_depth0;

                gaussian_id1 <= gaussian_id0;

                last_input1 <= last_input0;
                ////////////////////////////////////////////////////////////////////
                ///////////////////////// Clock 2 Data Flow ///////////////////////
                ////////////////////////////////////////////////////////////////////
                // logicister last and accum_rec series store at Clock 2

                G2 <= G1;
                d2 <= d1;
                conic_opacity2 <= conic_opacity1;

                // last_alpha2 <= last_alpha2_final;
                // last_color2 <= last_color2_final;
                // last_depth2 <= last_depth2_final;
                
                // accum_rec2 <= accum_rec2_final;
                // accum_rec_depth2 <= accum_rec_depth2_final;

                alpha2 <= alpha1;

                dG_ddelx2 <= dG_ddelx2_temp;
                dG_ddely2 <= dG_ddely2_temp;

                ddelx_dx2 <= ddelx_dx1;
                ddely_dy2 <= ddely_dy1;

                gdx2 <= gdx1;
                gdy2 <= gdy1;


                // Need to change
                // T2 <= T2_final;


                i_valid2 <= i_valid1;

                d_x_gdx2 <= d_x_gdx2_temp;
                d_y_gdx2 <= d_y_gdx2_temp;
                d_y_gdy2 <= d_y_gdy2_temp;


                gaussian_color2 <= gaussian_color1;
                gaussian_depth2 <= gaussian_depth1;            

                gaussian_id2 <= gaussian_id1;

                last_input2 <= last_input1;
                ////////////////////////////////////////////////////////////////////
                ///////////////////////// Clock 3 Data Flow ///////////////////////
                ////////////////////////////////////////////////////////////////////

                G3 <= G2;
                conic_opacity3 <= conic_opacity2;

                T3 <= T2;

                i_valid3 <= i_valid2;
                dchannel_dcolor3 <= dchannel_dcolor3_temp;
                diff_color3 <= diff_color3_temp;
                diff_depth3 <= diff_depth3_temp;


                dG_dx3 <= dG_dx3_temp;
                dG_dy3 <= dG_dy3_temp;
                
                d_x_gdx3 <= d_x_gdx2;
                d_y_gdx3 <= d_y_gdx2;
                d_y_gdy3 <= d_y_gdy2;

                gaussian_id3 <= gaussian_id2;

                last_input3 <= last_input2;
                ////////////////////////////////////////////////////////////////////
                ///////////////////////// Clock 4 Data Flow ///////////////////////
                ////////////////////////////////////////////////////////////////////

                G4 <= G3;
                conic_opacity4 <= conic_opacity3;

                T4 <= T3;

                i_valid4 <= i_valid3;
                dL_dalpha_added4_1 <= dL_dalpha_added4_temp1;
                dL_dalpha_added4_2 <= dL_dalpha_added4_temp2;
                dL_dcolor4 <= dL_dcolor_temp4;
                dL_ddepth4 <= dL_ddepth_temp4;

                dG_dx4 <= dG_dx3;
                dG_dy4 <= dG_dy3;

                d_x_gdx4 <= d_x_gdx3;
                d_y_gdx4 <= d_y_gdx3;
                d_y_gdy4 <= d_y_gdy3;
        
                gaussian_id4 <= gaussian_id3;

                last_input4 <= last_input3;
                ////////////////////////////////////////////////////////////////////
                ///////////////////////// Clock 5 Data Flow ///////////////////////
                ////////////////////////////////////////////////////////////////////

                G6 <= G5;

                T5 <= T4;
                conic_opacity5 <= conic_opacity4;
                
                i_valid5 <= i_valid4;

                dL_dcolor5 <= dL_dcolor4;
                dL_ddepth5 <= dL_ddepth4;

                dG_dx5 <= dG_dx4;
                dG_dy5 <= dG_dy4;

                d_x_gdx5 <= d_x_gdx4;
                d_y_gdx5 <= d_y_gdx4;
                d_y_gdy5 <= d_y_gdy4;

                dL_dalpha_added5 <= dL_dalpha_added5_temp;

                gaussian_id5 <= gaussian_id4;

                last_input5 <= last_input4;
                ////////////////////////////////////////////////////////////////////
                ///////////////////////// Clock 6 Data Flow ///////////////////////
                ////////////////////////////////////////////////////////////////////

                G5 <= G4;

                i_valid6 <= i_valid5;
                dL_dcolor6 <= dL_dcolor5;
                dL_ddepth6 <= dL_ddepth5;
                conic_opacity6 <= conic_opacity5;

                dG_dx6 <= dG_dx5;
                dG_dy6 <= dG_dy5;

                d_x_gdx6 <= d_x_gdx5;
                d_y_gdx6 <= d_y_gdx5;
                d_y_gdy6 <= d_y_gdy5;
                
                dL_dalpha6 <= dL_dalpha6_temp;     

                gaussian_id6 <= gaussian_id5;

                last_input6 <= last_input5;
                ////////////////////////////////////////////////////////////////////
                ////////////////////// Clock 7 Final Data Out //////////////////////
                ////////////////////////////////////////////////////////////////////
                i_valid7 <= i_valid6;
                dL_dopacity7 <= dL_dopacity7_temp;

                dL_dcolor7 <= dL_dcolor6;
                dL_ddepth7 <= dL_ddepth6;


                dL_dG7 <= dL_dG7_temp;
                dG_dx7 <= dG_dx6;
                dG_dy7 <= dG_dy6;

                d_x_gdx7 <= d_x_gdx6;
                d_y_gdx7 <= d_y_gdx6;
                d_y_gdy7 <= d_y_gdy6;

                gaussian_id7 <= gaussian_id6;

                last_input7 <= last_input6;
                ////////////////////////////////////////////////////////////////////
                ////////////////////// Clock 8 Final Data Out //////////////////////
                ////////////////////////////////////////////////////////////////////

                
                if (!both_pixel_grad_zero) begin

                    gradient_valid_out <= i_valid7;
                    dL_dcolor <= dL_dcolor7;
                    dL_ddepth <= dL_ddepth7;

                    dL_dopacity <= dL_dopacity7;

                    dL_dmean2D <= dL_dmean2D8_temp;
                    dL_dconic <= dL_dconic8_temp;
                    gaussian_id_out <= gaussian_id7;
                end

                else begin
                    gradient_valid_out <= 'b0;
                    dL_dcolor <= 'h0;
                    dL_ddepth <= 'h0;
                    dL_dopacity <= 'h0;
                    dL_dmean2D <= 'h0;
                    dL_dconic <= 'h0;
                    gaussian_id_out <= 'h0;
                end

            end
        end
    end

endmodule
