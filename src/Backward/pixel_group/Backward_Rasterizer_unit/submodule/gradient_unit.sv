module gradient_unit
    #(
        parameter BLOCK_SIZE = 16,
        parameter exponent_bit = 8,
        parameter mantissa_bit = 23,
        parameter precision = 32,
        parameter GID_bit = 12
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
    logic [precision - 1 : 0] T2, T3, T4, T5, T6;

    logic [precision - 1 : 0] last_alpha2;
    logic [precision - 1 : 0] last_depth2;

    logic [precision - 1:0] last_color2_R, last_color2_G, last_color2_B;
    logic [precision-1:0] accum_rec2_R, accum_rec2_G, accum_rec2_B;
    logic [precision - 1 : 0] accum_rec_depth2;


    logic [precision-1:0] One_minus_last_alpha1;


    logic [precision - 1 : 0] G0, G1, G2, G3, G4, G5, G6, G7;
    logic [precision - 1 : 0] d0_x, d0_y, d1_x, d1_y, d2_x, d2_y;
    logic [11:0] W0, H0;
    

    logic [precision - 1:0] conic_opacity0_x, conic_opacity1_x, conic_opacity2_x, conic_opacity3_x, conic_opacity4_x, conic_opacity5_x, conic_opacity6_x, conic_opacity7_x;
    logic [precision - 1:0] conic_opacity0_y, conic_opacity1_y, conic_opacity2_y, conic_opacity3_y, conic_opacity4_y, conic_opacity5_y, conic_opacity6_y, conic_opacity7_y;
    logic [precision - 1:0] conic_opacity0_z, conic_opacity1_z, conic_opacity2_z, conic_opacity3_z, conic_opacity4_z, conic_opacity5_z, conic_opacity6_z, conic_opacity7_z;
    logic [precision - 1:0] conic_opacity0_w, conic_opacity1_w, conic_opacity2_w, conic_opacity3_w, conic_opacity4_w, conic_opacity5_w, conic_opacity6_w, conic_opacity7_w;

    logic [precision - 1:0] gaussian_color0_R, gaussian_color0_G, gaussian_color0_B, gaussian_color1_R, gaussian_color1_G, gaussian_color1_B, gaussian_color2_R, gaussian_color2_G, gaussian_color2_B;
    logic [precision - 1 : 0] gaussian_depth0, gaussian_depth1, gaussian_depth2;

    logic [precision - 1:0] dL_dpixel3_R, dL_dpixel3_G, dL_dpixel3_B;
    logic [precision - 1 : 0] dL_dpixel_depth3;

    logic [precision-1:0] dchannel_dcolor3;
    logic [precision-1:0] dL_dalpha7;

    logic [precision-1:0] ddelx_dx1, ddelx_dx2, ddelx_dx3;
    logic [precision-1:0] ddely_dy1, ddely_dy2, ddely_dy3;

    logic i_valid0, i_valid1, i_valid2, i_valid3, i_valid4, i_valid5, i_valid6, i_valid7 ,i_valid8;

    logic [precision - 1:0] diff_color3_R, diff_color3_G, diff_color3_B;
    logic [precision-1:0] diff_depth3;
    
    logic [precision - 1:0] dL_ddepth4, dL_ddepth5, dL_ddepth6, dL_ddepth7, dL_ddepth8, dL_ddepth9;
    logic [precision - 1:0] dL_dcolor4_R, dL_dcolor4_G, dL_dcolor4_B, dL_dcolor5_R, dL_dcolor5_G, dL_dcolor5_B, dL_dcolor6_R, dL_dcolor6_G, dL_dcolor6_B, dL_dcolor7_R, dL_dcolor7_G, dL_dcolor7_B, dL_dcolor8_R, dL_dcolor8_G, dL_dcolor8_B, dL_dcolor9_R, dL_dcolor9_G, dL_dcolor9_B;

    logic [precision-1:0] One_minus_alpha1;
    // 이 두개 신호는 독립적임
    

    logic [precision-1:0] gdx1, gdx2;
    logic [precision-1:0] gdy1, gdy2;

    logic [precision-1:0] dG_ddelx2_1, dG_ddely2_1;
    logic [precision-1:0] dG_ddelx2_2, dG_ddely2_2;
    logic [precision-1:0] dG_ddelx3, dG_ddely3;

    logic [precision-1:0] d_x_gdx2, d_x_gdx3, d_x_gdx4, d_x_gdx5, d_x_gdx6, d_x_gdx7, d_x_gdx8;
    logic [precision-1:0] d_y_gdx2, d_y_gdx3, d_y_gdx4, d_y_gdx5, d_y_gdx6, d_y_gdx7, d_y_gdx8;
    logic [precision-1:0] d_y_gdy2, d_y_gdy3, d_y_gdy4, d_y_gdy5, d_y_gdy6, d_y_gdy7, d_y_gdy8;

    logic [precision-1:0] dG_dx4, dG_dx5, dG_dx6, dG_dx7, dG_dx8;
    logic [precision-1:0] dG_dy4, dG_dy5, dG_dy6, dG_dy7, dG_dy8;

    logic [precision-1:0] dL_dalpha_added4_1, dL_dalpha_added4_2, dL_dalpha_added4_3, dL_dalpha_added4_4;    

    logic [precision-1:0] dL_dalpha_added5_1, dL_dalpha_added5_2;
    logic [precision-1:0] dL_dalpha_added6;

    logic [precision-1:0] dL_dG8;
    logic [precision-1:0] dL_dopacity8;

    logic [precision-1:0] One0, One1;

    logic [GID_bit-1:0] gaussian_id0, gaussian_id1, gaussian_id2, gaussian_id3, gaussian_id4, gaussian_id5, gaussian_id6, gaussian_id7, gaussian_id8;

    logic last_input0, last_input1, last_input2, last_input3, last_input4, last_input5, last_input6, last_input7, last_input8;

    logic [precision-1:0] R_prediction2, G_prediction2, B_prediction2, depth_prediction2;

    // dL_dpixel, dL_ddepth = 0 Signal
    reg both_pixel_grad_zero;


    // Wire 선언
    logic [precision-1:0] One_minus_alpha_temp;
    logic [precision-1:0] gdx_temp, gdy_temp;
    logic [precision-1:0] T2_temp, T2_final;

    logic [precision-1:0] ddelx_dx1_temp, ddely_dy1_temp;

    logic [precision - 1:0] accum_rec2_temp_R, accum_rec2_final_R, last_color2_final_R, diff_color3_temp_R;
    logic [precision - 1:0] accum_rec2_temp_G, accum_rec2_final_G, last_color2_final_G, diff_color3_temp_G;
    logic [precision - 1:0] accum_rec2_temp_B, accum_rec2_final_B, last_color2_final_B, diff_color3_temp_B;

    logic [precision - 1:0] accum_rec_depth2_temp, accum_rec_depth2_final;
    logic [precision - 1:0] last_depth2_final, last_alpha2_final;

    logic [precision-1:0] dG_ddelx2_temp1, dG_ddelx2_temp2, dG_ddely2_temp1, dG_ddely2_temp2;
    logic [precision-1:0] dG_ddelx2_calc1, dG_ddelx2_calc2, dG_ddely2_calc1, dG_ddely2_calc2;

    logic [precision-1:0] dG_ddelx3_temp, dG_ddely3_temp;
    logic [precision-1:0] dG_ddelx3_calc, dG_ddely3_calc;
    
    logic [precision-1:0] dchannel_dcolor3_temp;

    logic [precision-1:0] diff_depth3_temp;
    logic [precision-1:0] dL_dalpha_added4_temp1, dL_dalpha_added4_temp2, dL_dalpha_added4_temp3, dL_dalpha_added4_temp4;

    logic [precision-1:0] dL_dalpha_added5_temp1, dL_dalpha_added5_temp2;
    logic [precision-1:0] dL_dalpha_added6_temp;

    logic [precision - 1:0] dL_dcolor_temp4_R, dL_dcolor_temp4_G, dL_dcolor_temp4_B;

    
    logic [precision-1:0] dL_dalpha7_temp;
    logic [precision-1:0] dL_ddepth_temp4;
    logic [precision-1:0] dL_dG8_temp;    
    
    logic [precision-1:0] dL_ddepth_calc4;
    logic [precision - 1:0] dL_dcolor_calc4_R, dL_dcolor_calc4_G, dL_dcolor_calc4_B;
    

    logic [precision-1:0] d_x_gdx2_temp, d_y_gdx2_temp, d_y_gdy2_temp;

    logic [precision-1:0] dG_dx4_temp, dG_dy4_temp;

    logic [precision -1 : 0] dL_dmean2D9_x_temp, dL_dmean2D9_y_temp;
    logic [precision -1 : 0] dL_dconic9_x_temp, dL_dconic9_y_temp, dL_dconic9_z_temp, dL_dconic9_w_temp;

    logic [precision -1 : 0] dL_dmean2D9_x_calc, dL_dmean2D9_y_calc;
    logic [precision -1 : 0] dL_dconic9_x_calc, dL_dconic9_y_calc, dL_dconic9_w_calc;
    logic [precision-1:0] One;

    logic [precision-1:0] dL_dopacity8_temp;
    logic [precision-1:0] dL_dopacity8_calc;

    logic [precision-1:0] d_x_gdx2_calc, d_y_gdx2_calc, d_y_gdy2_calc;

    logic [precision-1:0] R_prediction_valid, R_prediction_invalid, G_prediction_valid, G_prediction_invalid, B_prediction_valid, B_prediction_invalid, depth_prediction_valid, depth_prediction_invalid;
    logic [precision-1:0] R_prediction_temp, G_prediction_temp, B_prediction_temp, depth_prediction_temp; 


    assign One = (precision == 32 && mantissa_bit == 23) ? 32'h3f80_0000 :
                    (precision == 16 && mantissa_bit == 7) ? 16'h3f80 :
                    (precision == 24 && mantissa_bit == 15) ? 24'h3f80_00 :
                    {precision{1'b0}};
    

    logic [7:0] status_inst [1:56]; 

    // logic [precision-1:0] One_minus_last_alpha1_temp;
    logic [precision-1:0] One_minus_last_alpha1_valid_case_temp;
    logic [precision-1:0] One_minus_last_alpha1_invalid_case_temp;

    wire [precision - 1:0] One_minus_last_alpha1_temp;
    


    ////////////////////////////////////////////////////////////////////
    //////////////////////////// Clock Step 1 //////////////////////////
    ////////////////////////////////////////////////////////////////////

    // 1 - alpha
    DW_fp_add #(mantissa_bit, exponent_bit, 0)
	  One_minus_alpha_maker ( .a(One0), .b({!alpha0[precision-1] ,alpha0[precision-2:0]}), .rnd(3'b0), .z(One_minus_alpha_temp), .status(status_inst[1]) );

    // gdx = G * d.x
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
	  gdx_maker ( .a(G0), .b(d0_x), .rnd(3'b0), .z(gdx_temp), .status(status_inst[2]) );

    // gdy = G * d.y
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
	  gdy_maker ( .a(G0), .b(d0_y), .rnd(3'b0), .z(gdy_temp), .status(status_inst[3]) );

    // ddelx_dx = W/2 
    DW_fp_i2flt #(mantissa_bit, exponent_bit, precision, 1)
	  ddelx_dx_maker ( .a({{(precision-12){1'b0}}, W0[11:0]} ), .rnd(3'b0), .z(ddelx_dx1_temp), .status(status_inst[4]));

    // ddely_dy = H/2 
    DW_fp_i2flt #(mantissa_bit, exponent_bit, precision, 1)
	  ddely_dy_maker ( .a({{(precision-12){1'b0}}, H0[11:0]} ), .rnd(3'b0), .z(ddely_dy1_temp), .status(status_inst[5]));



    // 1 - last_alpha
    // i_valid == 1일때 처리 할거
    DW_fp_add #(mantissa_bit, exponent_bit, 0)
	  One_minus_last_alpha_maker_for_valid ( .a(One0), .b({!alpha1[precision-1], alpha1[precision-2:0]}), .rnd(3'b0), .z(One_minus_last_alpha1_valid_case_temp), .status(status_inst[6]) );

    // 1 - last_alpha
    // i_valid == 0일때 처리할 거
    DW_fp_add #(mantissa_bit, exponent_bit, 0)
	  One_minus_last_alpha_maker_for_nonvalid ( .a(One0), .b({!last_alpha2[precision-1], last_alpha2[precision-2:0]}), .rnd(3'b0), .z(One_minus_last_alpha1_invalid_case_temp), .status(status_inst[7]) );

    assign One_minus_last_alpha1_temp = i_valid1? One_minus_last_alpha1_valid_case_temp : One_minus_last_alpha1_invalid_case_temp;




    // Last alpha, last color predictions

    // R channel prediction
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
      R_valid_prediction_maker ( .a(alpha1), .b(gaussian_color1_R), .rnd(3'b0), .z(R_prediction_valid), .status(status_inst[8]) );

    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
      R_invalid_prediction_maker ( .a(last_alpha2), .b(last_color2_R), .rnd(3'b0), .z(R_prediction_invalid), .status(status_inst[9]) );


    // G channel prediction
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
      G_valid_prediction_maker ( .a(alpha1), .b(gaussian_color1_G), .rnd(3'b0), .z(G_prediction_valid), .status(status_inst[10]) );
    
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
      G_invalid_prediction_maker ( .a(last_alpha2), .b(last_color2_G), .rnd(3'b0), .z(G_prediction_invalid), .status(status_inst[11]) );


    // B channel prediction
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
      B_valid_prediction_maker ( .a(alpha1), .b(gaussian_color1_B), .rnd(3'b0), .z(B_prediction_valid), .status(status_inst[12]) );

    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
      B_invalid_prediction_maker ( .a(last_alpha2), .b(last_color2_B), .rnd(3'b0), .z(B_prediction_invalid), .status(status_inst[13]) );


    // depth prediction
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
      depth_valid_prediction_maker ( .a(alpha1), .b(gaussian_depth1), .rnd(3'b0), .z(depth_prediction_valid), .status(status_inst[14]) );

    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
      depth_invalid_prediction_maker ( .a(last_alpha2), .b(last_depth2), .rnd(3'b0), .z(depth_prediction_invalid), .status(status_inst[15]) );


    assign R_prediction_temp = i_valid1 ? R_prediction_valid : R_prediction_invalid;
    assign G_prediction_temp = i_valid1 ? G_prediction_valid : G_prediction_invalid;
    assign B_prediction_temp = i_valid1 ? B_prediction_valid : B_prediction_invalid;
    assign depth_prediction_temp = i_valid1 ? depth_prediction_valid : depth_prediction_invalid;
  



    ////////////////////////////////////////////////////////////////////
    //////////////////////////// Clock Step 2 //////////////////////////
    ////////////////////////////////////////////////////////////////////


    // Clock 1 ~ 2 Stage is for not to delay additional clocks 
    // So can be possible weakness

    // // 1 - last_alpha
    // DW_fp_add #(mantissa_bit, exponent_bit, 0)
	//   One_minus_last_alpha_maker ( .a(One1), .b({!last_alpha2[precision-1], last_alpha2[precision-2:0]}), .rnd(3'b0), .z(One_minus_last_alpha1_temp), .status(status_inst[6]) );

    // T = skip ? T : T / (1 - alpha)
    DW_fp_div #(mantissa_bit, exponent_bit, ieee_compliance, 1'b0, 1'b0)
     T_temp_maker ( .a(T2), .b(One_minus_alpha1), .rnd(3'b0), .z(T2_temp), .status(status_inst[16]));


    DW_fp_mac #(mantissa_bit, exponent_bit, ieee_compliance) 
     accum_rec_R_maker ( .a(One_minus_last_alpha1), .b(accum_rec2_R), .c(R_prediction2), .rnd(3'b0), .z(accum_rec2_temp_R), .status(status_inst[17]) );

    DW_fp_mac #(mantissa_bit, exponent_bit, ieee_compliance) 
     accum_rec_G_maker ( .a(One_minus_last_alpha1), .b(accum_rec2_G), .c(G_prediction2), .rnd(3'b0), .z(accum_rec2_temp_G), .status(status_inst[18]) );

    DW_fp_mac #(mantissa_bit, exponent_bit, ieee_compliance) 
     accum_rec_B_maker ( .a(One_minus_last_alpha1), .b(accum_rec2_B), .c(B_prediction2), .rnd(3'b0), .z(accum_rec2_temp_B), .status(status_inst[19]) );

    // accum_rec_depth = skip ? accum_rec_depth : last_alpha * last_depth + (1.f - last_alpha) * accum_rec_depth;
    DW_fp_mac #(mantissa_bit, exponent_bit, ieee_compliance) 
     accum_rec_depth_maker ( .a(One_minus_last_alpha1), .b(accum_rec_depth2), .c(depth_prediction2), .rnd(3'b0), .z(accum_rec_depth2_temp), .status(status_inst[20]) );

    // DW_fp_dp2 #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
    //  accum_rec_R_maker ( .a(last_alpha2), .b(last_color2_R), .c(One_minus_last_alpha1), .d(accum_rec2_R), .rnd(3'b0), .z(accum_rec2_temp_R), .status(status_inst[9]) );

    // DW_fp_dp2 #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
    //  accum_rec_G_maker ( .a(last_alpha2), .b(last_color2_G), .c(One_minus_last_alpha1), .d(accum_rec2_G), .rnd(3'b0), .z(accum_rec2_temp_G), .status(status_inst[10]) );

    // DW_fp_dp2 #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
    //  accum_rec_B_maker ( .a(last_alpha2), .b(last_color2_B), .c(One_minus_last_alpha1), .d(accum_rec2_B), .rnd(3'b0), .z(accum_rec2_temp_B), .status(status_inst[11]) );

    // // accum_rec_depth = skip ? accum_rec_depth : last_alpha * last_depth + (1.f - last_alpha) * accum_rec_depth;
    // DW_fp_dp2 #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
    //  accum_rec_depth_maker ( .a(last_alpha2), .b(last_depth2), .c(One_minus_last_alpha1), .d(accum_rec_depth2), .rnd(3'b0), .z(accum_rec_depth2_temp), .status(status_inst[12]) );

    assign T2_final = i_valid1 ? T2_temp : T2;

    assign last_alpha2_final = i_valid1 ? alpha1 : last_alpha2;

    assign last_color2_final_R = i_valid1 ? gaussian_color1_R : last_color2_R;
    assign last_color2_final_G = i_valid1 ? gaussian_color1_G : last_color2_G;
    assign last_color2_final_B = i_valid1 ? gaussian_color1_B : last_color2_B;

    assign last_depth2_final = i_valid1 ? gaussian_depth1 : last_depth2;

    assign accum_rec2_final_R = i_valid1 ? accum_rec2_temp_R : accum_rec2_R;
    assign accum_rec2_final_G = i_valid1 ? accum_rec2_temp_G : accum_rec2_G;
    assign accum_rec2_final_B = i_valid1 ? accum_rec2_temp_B : accum_rec2_B;

    assign accum_rec_depth2_final = i_valid1 ? accum_rec_depth2_temp : accum_rec_depth2;

    // const float dG_ddelx = -gdx * con_o.x - gdy * con_o.y;
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
     dG_ddelx_maker_1st_term ( .a(gdx1), .b(conic_opacity1_x), .rnd(3'b0), .z(dG_ddelx2_calc1), .status(status_inst[21]) );

    // const float dG_ddelx = -gdx * con_o.x - gdy * con_o.y;
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
     dG_ddelx_maker_2nd_term ( .a(gdy1), .b(conic_opacity1_y), .rnd(3'b0), .z(dG_ddelx2_calc2), .status(status_inst[22]) );

    // const float dG_ddely = -gdy * con_o.z - gdx * con_o.y;
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
     dG_ddely_maker_1st_term ( .a(gdy1), .b(conic_opacity1_z), .rnd(3'b0), .z(dG_ddely2_calc1), .status(status_inst[23]) );

    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
     dG_ddely_maker_2nd_term ( .a(gdx1), .b(conic_opacity1_y), .rnd(3'b0), .z(dG_ddely2_calc2), .status(status_inst[24]) );



     assign dG_ddely2_temp1 = (dG_ddely2_calc1 == 'h0) ? 'h0 : {!dG_ddely2_calc1[precision-1], dG_ddely2_calc1[precision-2:0]};
     assign dG_ddely2_temp2 = (dG_ddely2_calc2 == 'h0) ? 'h0 : {!dG_ddely2_calc2[precision-1], dG_ddely2_calc2[precision-2:0]};

     assign dG_ddelx2_temp1 = (dG_ddelx2_calc1 == 'h0) ? 'h0 : {!dG_ddelx2_calc1[precision-1], dG_ddelx2_calc1[precision-2:0]};
     assign dG_ddelx2_temp2 = (dG_ddelx2_calc2 == 'h0) ? 'h0 : {!dG_ddelx2_calc2[precision-1], dG_ddelx2_calc2[precision-2:0]};



    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
	  d_x_gdx_maker ( .a({!gdx1[precision-1], (gdx1[precision-2:mantissa_bit] - 8'd1), gdx1[mantissa_bit-1:0]}), .b(d1_x), .rnd(3'b0), .z(d_x_gdx2_calc), .status(status_inst[25]) );

    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
	  d_y_gdx_maker ( .a({!gdx1[precision-1], (gdx1[precision-2:mantissa_bit] - 8'd1), gdx1[mantissa_bit-1:0]}), .b(d1_y), .rnd(3'b0), .z(d_y_gdx2_calc), .status(status_inst[26]) );

    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
	  d_y_gdy_maker ( .a({!gdy1[precision-1], (gdy1[precision-2:mantissa_bit] - 8'd1), gdy1[mantissa_bit-1:0]}), .b(d1_y), .rnd(3'b0), .z(d_y_gdy2_calc), .status(status_inst[27]) );


    assign d_x_gdx2_temp = (gdx1[precision-2:0] == {(precision-1){1'b0}}) ? 'h0 : d_x_gdx2_calc;
    assign d_y_gdx2_temp = (gdx1[precision-2:0] == {(precision-1){1'b0}}) ? 'h0 : d_y_gdx2_calc;
    assign d_y_gdy2_temp = (gdy1[precision-2:0] == {(precision-1){1'b0}}) ? 'h0 : d_y_gdy2_calc;


    ////////////////////////////////////////////////////////////////////
    //////////////////////////// Clock Step 3 //////////////////////////
    ////////////////////////////////////////////////////////////////////
    // logicister T, last and accum_rec series are stored in Clock Step 2

    // const float dchannel_dcolor = alpha * T;
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)  
	  dL_dch_dcolor ( .a(T2), .b(alpha2), .rnd(3'b0), .z(dchannel_dcolor3_temp), .status(status_inst[56]) );

    // (c - accum_rec[ch])
    DW_fp_add #(mantissa_bit, exponent_bit, 0)
	  diff_color_R_maker ( .a(gaussian_color2_R), .b({!accum_rec2_R[precision- 1], accum_rec2_R[precision - 2:0]}), .rnd(3'b0), .z(diff_color3_temp_R), .status(status_inst[28]) );

    DW_fp_add #(mantissa_bit, exponent_bit, 0)
	  diff_color_G_maker ( .a(gaussian_color2_G), .b({!accum_rec2_G[precision-1], accum_rec2_G[precision - 2:0]}), .rnd(3'b0), .z(diff_color3_temp_G), .status(status_inst[29]) );

    DW_fp_add #(mantissa_bit, exponent_bit, 0)
	  diff_color_B_maker ( .a(gaussian_color2_B), .b({!accum_rec2_B[precision - 1], accum_rec2_B[precision - 2:0]}), .rnd(3'b0), .z(diff_color3_temp_B), .status(status_inst[30]) );

    // (depth - accum_rec_depth)
    DW_fp_add #(mantissa_bit, exponent_bit, 0)
	  diff_depth_maker ( .a(gaussian_depth2), .b({!accum_rec_depth2[precision-1], accum_rec_depth2[precision-2:0]}), .rnd(3'b0), .z(diff_depth3_temp), .status(status_inst[31]) );


    DW_fp_add #(mantissa_bit, exponent_bit, 0)
      dG_dx_making_adder ( .a(dG_ddelx2_1), .b(dG_ddelx2_2), .rnd(3'b0), .z(dG_ddelx3_calc), .status(status_inst[32]) );

    DW_fp_add #(mantissa_bit, exponent_bit, 0)
      dG_dy_making_adder ( .a(dG_ddely2_1), .b(dG_ddely2_2), .rnd(3'b0), .z(dG_ddely3_calc), .status(status_inst[33]) );

    
    assign dG_ddelx3_temp = (dG_ddelx3_calc == 'h0) ? 'h0 : dG_ddelx3_calc;
    assign dG_ddely3_temp = (dG_ddely3_calc == 'h0) ? 'h0 :dG_ddely3_calc;
      

   

    ////////////////////////////////////////////////////////////////////
    //////////////////////////// Clock Step 4 //////////////////////////
    ////////////////////////////////////////////////////////////////////

    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
     dL_dalpha_maker1_1st_term ( .a(diff_color3_R), .b(dL_dpixel3_R), .rnd(3'b0), .z(dL_dalpha_added4_temp1), .status(status_inst[34]) );

    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
     dL_dalpha_maker1_2nd_term ( .a(diff_color3_G), .b(dL_dpixel3_G), .rnd(3'b0), .z(dL_dalpha_added4_temp2), .status(status_inst[35]) );


    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
     dL_dalpha_maker2_1st_term ( .a(diff_color3_B), .b(dL_dpixel3_B), .rnd(3'b0), .z(dL_dalpha_added4_temp3), .status(status_inst[36]) );

    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
     dL_dalpha_maker2_2nd_term ( .a(diff_depth3), .b(dL_dpixel_depth3), .rnd(3'b0), .z(dL_dalpha_added4_temp4), .status(status_inst[37]) );




    // dL_dcolors[ch] = skip ? 0.0f : dchannel_dcolor * dL_dchannel; 
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
	  dL_dcolor_temp_R ( .a(dL_dpixel3_R), .b(dchannel_dcolor3), .rnd(3'b0), .z(dL_dcolor_calc4_R), .status(status_inst[38]) );

    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
	  dL_dcolor_temp_G ( .a(dL_dpixel3_G), .b(dchannel_dcolor3), .rnd(3'b0), .z(dL_dcolor_calc4_G), .status(status_inst[39]) );

    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
	  dL_dcolor_temp_B ( .a(dL_dpixel3_B), .b(dchannel_dcolor3), .rnd(3'b0), .z(dL_dcolor_calc4_B), .status(status_inst[40]) );
 
    // dL_ddepths_shared[tid] = skip ? 0.f : dchannel_dcolor * dL_dpixel_depth;
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
	  dL_ddepth_maker ( .a(dL_dpixel_depth3), .b(dchannel_dcolor3), .rnd(3'b0), .z(dL_ddepth_calc4), .status(status_inst[54]) );



    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
      dG_dx_maker ( .a(dG_ddelx3), .b(ddelx_dx3), .rnd(3'b0), .z(dG_dx4_temp), .status(status_inst[41]) );

    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
      dG_dy_maker ( .a(dG_ddely3), .b(ddely_dy3), .rnd(3'b0), .z(dG_dy4_temp), .status(status_inst[42]) );


    
    assign dL_ddepth_temp4 = (dL_ddepth_calc4[precision - 2: 0] == {(precision - 1){1'b0}}) ? {precision{1'b0}} : dL_ddepth_calc4;

    assign dL_dcolor_temp4_R =  (dL_dcolor_calc4_R == {(precision - 1){1'b0}}) ? {precision{1'b0}} : dL_dcolor_calc4_R;
    assign dL_dcolor_temp4_G =  (dL_dcolor_calc4_G == {(precision - 1){1'b0}}) ? {precision{1'b0}} : dL_dcolor_calc4_G;
    assign dL_dcolor_temp4_B =  (dL_dcolor_calc4_B == {(precision - 1){1'b0}}) ? {precision{1'b0}} : dL_dcolor_calc4_B;



    ////////////////////////////////////////////////////////////////////
    //////////////////////////// Clock Step 5 //////////////////////////
    ////////////////////////////////////////////////////////////////////




    // 사이클 하나 더 늘리자... 
    DW_fp_add #(mantissa_bit, exponent_bit, 0)
	  dL_dalpha_adder ( .a(dL_dalpha_added4_1), .b(dL_dalpha_added4_2), .rnd(3'b0), .z(dL_dalpha_added5_temp1), .status(status_inst[43]) );

    
    DW_fp_add #(mantissa_bit, exponent_bit, 0)
      dL_dalpha_adder2 ( .a(dL_dalpha_added4_3), .b(dL_dalpha_added4_4), .rnd(3'b0), .z(dL_dalpha_added5_temp2), .status(status_inst[44]) );


    
    ////////////////////////////////////////////////////////////////////
    //////////////////////////// Clock Step 6 //////////////////////////
    ////////////////////////////////////////////////////////////////////
    
    DW_fp_add #(mantissa_bit, exponent_bit, 0)
      dL_dalpha_adder_final ( .a(dL_dalpha_added5_1), .b(dL_dalpha_added5_2), .rnd(3'b0), .z(dL_dalpha_added6_temp), .status(status_inst[45]) );
    

    ////////////////////////////////////////////////////////////////////
    //////////////////////////// Clock Step 7 //////////////////////////
    ////////////////////////////////////////////////////////////////////
    
    // dL_dalpha *= T;
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
	  dL_dalpha_maker_from_T ( .a(dL_dalpha_added6), .b(T6), .rnd(3'b0), .z(dL_dalpha7_temp), .status(status_inst[46]) );


    ////////////////////////////////////////////////////////////////////
    //////////////////////////// Clock Step 8 //////////////////////////
    ////////////////////////////////////////////////////////////////////

    // const float dL_dG = con_o.w * dL_dalpha;
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
	  dL_dG_maker ( .a(dL_dalpha7), .b(conic_opacity7_w), .rnd(3'b0), .z(dL_dG8_temp), .status(status_inst[47]) );

    // const float dL_dopacity = G * dL_dalpha;
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
	  dL_dopacity_maker ( .a(dL_dalpha7), .b(G7), .rnd(3'b0), .z(dL_dopacity8_calc), .status(status_inst[48]) );
    
    assign dL_dopacity8_temp = (dL_dopacity8_calc[precision - 2: 0] == {(precision - 1){1'b0}}) ? {precision{1'b0}} : dL_dopacity8_calc[precision - 1: 0];


    ////////////////////////////////////////////////////////////////////
    //////////////////////////// Clock Step 9 //////////////////////////
    ////////////////////////////////////////////////////////////////////

    // 	dL_dmean2D_shared[tid].x = skip ? 0.f : dL_dG * dG_ddelx * ddelx_dx;  전단계 계산 가능
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
	  dL_dmean2D_x_maker ( .a(dL_dG8), .b(dG_dx8), .rnd(3'b0), .z(dL_dmean2D9_x_calc), .status(status_inst[49]) );
    
    // 	dL_dmean2D_shared[tid].y = skip ? 0.f : dL_dG * dG_ddely * ddely_dy;  전단계 계산 가능
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
	  dL_dmean2D_y_maker ( .a(dL_dG8), .b(dG_dy8), .rnd(3'b0), .z(dL_dmean2D9_y_calc), .status(status_inst[50]) );


    assign dL_dmean2D9_x_temp = (dL_dmean2D9_x_calc[precision - 2 : 0] == {(precision-1){1'b0}}) ? {precision{1'b0}} : dL_dmean2D9_x_calc;
    assign dL_dmean2D9_y_temp = (dL_dmean2D9_y_calc[precision - 2 : 0] == {(precision-1){1'b0}}) ? {precision{1'b0}} : dL_dmean2D9_y_calc;


    //	dL_dconic2D_shared[tid].x = skip ? 0.f : -0.5f * gdx * d.x * dL_dG;
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
	  dL_dconic_x_maker ( .a(dL_dG8), .b(d_x_gdx8), .rnd(3'b0), .z(dL_dconic9_x_calc), .status(status_inst[51]) );

    // 	dL_dconic2D_shared[tid].y = skip ? 0.f : -0.5f * gdx * d.y * dL_dG;
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
	  dL_dconic_y_maker ( .a(dL_dG8), .b(d_y_gdx8), .rnd(3'b0), .z(dL_dconic9_y_calc), .status(status_inst[52]) );

    // 	dL_dconic2D_shared[tid].w = skip ? 0.f : -0.5f * gdy * d.y * dL_dG;
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
	  dL_dconic_w_maker ( .a(dL_dG8), .b(d_y_gdy8), .rnd(3'b0), .z(dL_dconic9_w_calc), .status(status_inst[53]) );

    assign dL_dconic9_z_temp = {precision{1'b0}}; 

    assign dL_dconic9_x_temp = (dL_dconic9_x_calc[precision - 2 : 0] == {(precision-1){1'b0}}) ? {precision{1'b0}} : dL_dconic9_x_calc;
    assign dL_dconic9_y_temp = (dL_dconic9_y_calc[precision - 2 : 0] == {(precision-1){1'b0}}) ? {precision{1'b0}} : dL_dconic9_y_calc;
    assign dL_dconic9_w_temp = (dL_dconic9_w_calc[precision - 2 : 0] == {(precision - 1){1'b0}}) ? {precision{1'b0}} : dL_dconic9_w_calc;


    ////////////////////////////////////////////////////////////////////
    //////////////////////////// Clock Step 10 //////////////////////////
    ////////////////////////////////////////////////////////////////////


    always_ff @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin


            // Reset all scalar and multi-bit logicisters to 'h0


            alpha0 <= 'h0; alpha1 <= 'h0; alpha2 <= 'h0;
            T2 <= 'h0; T3 <= 'h0; T4 <= 'h0; T5 <= 'h0; T6 <= 'h0;
            One0 <= One; One1 <= One;

            i_valid0 <= 1'b0; i_valid1 <= 1'b0; i_valid2 <= 1'b0; 
            i_valid3 <= 1'b0; i_valid4 <= 1'b0; i_valid5 <= 1'b0; i_valid6 <= 1'b0; i_valid7 <= 'b0; i_valid8 <= 'b0;

            last_alpha2 <= 'h0;
            last_depth2 <= 'h0;
            last_color2_R <= 'h0; last_color2_G <= 'h0; last_color2_B <= 'h0;

            accum_rec2_R <= 'h0; accum_rec2_G <= 'h0; accum_rec2_B <= 'h0;
            accum_rec_depth2 <= 'h0;

            G0 <= 'h0; G1 <= 'h0; G2 <= 'h0; 
            G3 <= 'h0; G4 <= 'h0; G5 <= 'h0; G6 <= 'h0;
            G7 <= 'h0;

            d0_x <= 'h0; d0_y <= 'h0; d1_x <= 'h0; d1_y <= 'h0; d2_x <= 'h0; d2_y <= 'h0;

            W0 <= 12'h0; H0 <= 12'h0;

            conic_opacity0_x <= 'h0; conic_opacity0_y <= 'h0; conic_opacity0_z <= 'h0; conic_opacity0_w <= 'h0;
            conic_opacity1_x <= 'h0; conic_opacity1_y <= 'h0; conic_opacity1_z <= 'h0; conic_opacity1_w <= 'h0;
            conic_opacity2_x <= 'h0; conic_opacity2_y <= 'h0; conic_opacity2_z <= 'h0; conic_opacity2_w <= 'h0;
            conic_opacity3_x <= 'h0; conic_opacity3_y <= 'h0; conic_opacity3_z <= 'h0; conic_opacity3_w <= 'h0;
            conic_opacity4_x <= 'h0; conic_opacity4_y <= 'h0; conic_opacity4_z <= 'h0; conic_opacity4_w <= 'h0;
            conic_opacity5_x <= 'h0; conic_opacity5_y <= 'h0; conic_opacity5_z <= 'h0; conic_opacity5_w <= 'h0;
            conic_opacity6_x <= 'h0; conic_opacity6_y <= 'h0; conic_opacity6_z <= 'h0; conic_opacity6_w <= 'h0;
            conic_opacity7_x <= 'h0; conic_opacity7_y <= 'h0; conic_opacity7_z <= 'h0; conic_opacity7_w <= 'h0;
            
            gaussian_color0_R <= 'h0; gaussian_color0_G <= 'h0; gaussian_color0_B <= 'h0;
            gaussian_color1_R <= 'h0; gaussian_color1_G <= 'h0; gaussian_color1_B <= 'h0;
            gaussian_color2_R <= 'h0; gaussian_color2_G <= 'h0; gaussian_color2_B <= 'h0;

            gaussian_depth0 <= 'h0; gaussian_depth1 <= 'h0; gaussian_depth2 <= 'h0;
            


            dL_dpixel3_R <= 'h0; dL_dpixel3_G <= 'h0; dL_dpixel3_B <= 'h0;

            dL_dpixel_depth3 <= 'h0;

            dchannel_dcolor3 <= 'h0;
            dL_dalpha7 <= 'h0;
    

            dL_dcolor4_R <= 'h0; dL_dcolor4_G <= 'h0; dL_dcolor4_B <= 'h0;
            dL_dcolor5_R <= 'h0; dL_dcolor5_G <= 'h0; dL_dcolor5_B <= 'h0; 
            dL_dcolor6_R <= 'h0; dL_dcolor6_G <= 'h0; dL_dcolor6_B <= 'h0;
            dL_dcolor7_R <= 'h0; dL_dcolor7_G <= 'h0; dL_dcolor7_B <= 'h0;
            dL_dcolor8_R <= 'h0; dL_dcolor8_G <= 'h0; dL_dcolor8_B <= 'h0;
            dL_dcolor9_R <= 'h0; dL_dcolor9_G <= 'h0; dL_dcolor9_B <= 'h0;

            dL_ddepth4 <= 'h0; dL_ddepth5 <= 'h0; 
            dL_ddepth6 <= 'h0; dL_ddepth7 <= 'h0;
            dL_ddepth8 <= 'h0;
            dL_ddepth9 <= 'h0;

            dL_dopacity <= 'h0;
            dL_dconic <= 'h0;
            dL_dmean2D <= 'h0;

            One_minus_alpha1 <= 'h0;
            One_minus_last_alpha1 <= 'h0;
            
            // One_minus_last_alpha1_temp <= 'h0;

            gdx1 <= 'h0; gdx2 <= 'h0;
            gdy1 <= 'h0; gdy2 <= 'h0;

            ddelx_dx1 <= 'h0; ddelx_dx2 <= 'h0; ddelx_dx3 <= 'h0;
            ddely_dy1 <= 'h0; ddely_dy2 <= 'h0; ddely_dy3 <= 'h0;

            dG_ddelx2_1 <= 'h0; dG_ddelx2_2 <= 'h0;
            dG_ddely2_1 <= 'h0; dG_ddely2_2 <= 'h0;

            dG_ddelx3 <= 'h0; dG_ddely3 <= 'h0;


            d_x_gdx2 <= 'h0; d_x_gdx3 <= 'h0; d_x_gdx4 <= 'h0;
            d_x_gdx5 <= 'h0; d_x_gdx6 <= 'h0; d_x_gdx7 <= 'h0;
            d_x_gdx8 <= 'h0;

            d_y_gdx2 <= 'h0; d_y_gdx3 <= 'h0; d_y_gdx4 <= 'h0;
            d_y_gdx5 <= 'h0; d_y_gdx6 <= 'h0; d_y_gdx7 <= 'h0;
            d_y_gdx8 <= 'h0;

            d_y_gdy2 <= 'h0; d_y_gdy3 <= 'h0; d_y_gdy4 <= 'h0;
            d_y_gdy5 <= 'h0; d_y_gdy6 <= 'h0; d_y_gdy7 <= 'h0;
            d_y_gdy8 <= 'h0;

            dG_dx4 <= 'h0; dG_dx5 <= 'h0; dG_dx6 <= 'h0; dG_dx7 <= 'h0; dG_dx8 <= 'h0;
            dG_dy4 <= 'h0; dG_dy5 <= 'h0; dG_dy6 <= 'h0; dG_dy7 <= 'h0; dG_dy8 <= 'h0;

            dL_dalpha_added4_1 <= 'h0; dL_dalpha_added4_2 <= 'h0;
            dL_dalpha_added4_3 <= 'h0; dL_dalpha_added4_4 <= 'h0;

            dL_dalpha_added5_1 <= 'h0; dL_dalpha_added5_2 <= 'h0;


            dL_dalpha_added6 <= 'h0;
            dL_dG8 <= 'h0;
            dL_dopacity8 <= 'h0;
            
            diff_color3_R <= 'h0; diff_color3_G <= 'h0; diff_color3_B <= 'h0;
            diff_depth3 <= 'h0;


            gaussian_id0 <= 'h0;
            gaussian_id1 <= 'h0;
            gaussian_id2 <= 'h0;
            gaussian_id3 <= 'h0;
            gaussian_id4 <= 'h0;
            gaussian_id5 <= 'h0;
            gaussian_id6 <= 'h0;
            gaussian_id7 <= 'h0;
            gaussian_id8 <= 'h0;
            gaussian_id_out <= 'h0;

            // Reset output logicisters
            dL_dcolor <= 'h0;
            dL_ddepth <= 'h0;
            dL_dmean2D <= 'h0;
            dL_dconic <= 'h0;
            dL_dopacity <= 'h0;

            gradient_valid_out <= 1'b0;
            

            last_input0 <= 'b0;
            last_input1 <= 'b0;
            last_input2 <= 'b0;
            last_input3 <= 'b0;
            last_input4 <= 'b0;
            last_input5 <= 'b0;
            last_input6 <= 'b0;
            last_input7 <= 'b0;
            last_input8 <= 'b0;
            last_input_done <= 'b0;

            both_pixel_grad_zero <= 'b0;

            R_prediction2 <= 'h0;
            G_prediction2 <= 'h0;
            B_prediction2 <= 'h0;
            depth_prediction2 <= 'h0;

        end


        else begin

            if (start) begin
                T2 <= T_first;
                {dL_dpixel3_R, dL_dpixel3_G, dL_dpixel3_B} <= dL_dpixel;
                dL_dpixel_depth3 <= dL_dpixel_depth;
                W0 <= (W >> 1);
                H0 <= (H >> 1);
                
                accum_rec2_R <= 'h0; accum_rec2_G <= 'h0; accum_rec2_B <= 'h0;
                accum_rec_depth2 <= 'h0;
                last_color2_R <= 'h0; last_color2_G <= 'h0; last_color2_B <= 'h0;
                last_depth2 <= 'h0;
                last_alpha2 <= 'h0;

                R_prediction2 <= 'h0;
                G_prediction2 <= 'h0;
                B_prediction2 <= 'h0;
                depth_prediction2 <= 'h0;

                if (dL_dpixel == 'h0 && dL_dpixel_depth == 'h0) begin
                    both_pixel_grad_zero <= 'b1;
                    // last_input_done <= 1'b1;
                end

                else begin
                    both_pixel_grad_zero <= 'b0;
                end

                // last_input_done <= 'b0;
            end            

            else if (!stall) begin

                accum_rec2_R <= accum_rec2_final_R;
                accum_rec2_G <= accum_rec2_final_G;
                accum_rec2_B <= accum_rec2_final_B;
                accum_rec_depth2 <= accum_rec_depth2_final;

                last_color2_R <= last_color2_final_R;
                last_color2_G <= last_color2_final_G;
                last_color2_B <= last_color2_final_B;
                last_depth2 <= last_depth2_final;
                last_alpha2 <= last_alpha2_final;
                T2 <= T2_final;

                // if (last_input_done) begin
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
                {d0_x, d0_y} <= d;
                {conic_opacity0_x, conic_opacity0_y, conic_opacity0_z, conic_opacity0_w} <= conic_opacity;

                alpha0 <= alpha_in;
                
                {gaussian_color0_R, gaussian_color0_G, gaussian_color0_B} <= gaussian_color;
                gaussian_depth0 <= gaussian_depth;

                i_valid0 <= i_valid;

                One0 <= One; One1 <= One;

                gaussian_id0 <= gaussian_id_in;

                last_input0 <= last_input;

                ////////////////////////////////////////////////////////////////////
                ///////////////////////// Clock 1 Data Flow ///////////////////////
                ////////////////////////////////////////////////////////////////////

                G1 <= G0;
                {d1_x, d1_y} <= {d0_x, d0_y};
                {conic_opacity1_x, conic_opacity1_y, conic_opacity1_z, conic_opacity1_w} <= {conic_opacity0_x, conic_opacity0_y, conic_opacity0_z, conic_opacity0_w};

                alpha1 <= alpha0;


                i_valid1 <= i_valid0;
                
                
                // additional logicisters
                One_minus_alpha1 <= One_minus_alpha_temp;
                One_minus_last_alpha1 <= One_minus_last_alpha1_temp;

                gdx1 <= gdx_temp;
                gdy1 <= gdy_temp;

                ddelx_dx1 <= ddelx_dx1_temp;
                ddely_dy1 <= ddely_dy1_temp;

                {gaussian_color1_R, gaussian_color1_G, gaussian_color1_B} <= {gaussian_color0_R, gaussian_color0_G, gaussian_color0_B};
                gaussian_depth1 <= gaussian_depth0;

                gaussian_id1 <= gaussian_id0;

                last_input1 <= last_input0;


                R_prediction2 <= R_prediction_temp;
                G_prediction2 <= G_prediction_temp;
                B_prediction2 <= B_prediction_temp;
                depth_prediction2 <= depth_prediction_temp;

                ////////////////////////////////////////////////////////////////////
                ///////////////////////// Clock 2 Data Flow ///////////////////////
                ////////////////////////////////////////////////////////////////////
                // logicister last and accum_rec series store at Clock 2

                G2 <= G1;
                {d2_x, d2_y} <= {d1_x, d1_y};
                {conic_opacity2_x, conic_opacity2_y, conic_opacity2_z, conic_opacity2_w} <= {conic_opacity1_x, conic_opacity1_y, conic_opacity1_z, conic_opacity1_w};

                // last_alpha2 <= last_alpha2_final;
                // last_color2 <= last_color2_final;
                // last_depth2 <= last_depth2_final;
                
                // accum_rec2 <= accum_rec2_final;
                // accum_rec_depth2 <= accum_rec_depth2_final;

                alpha2 <= alpha1;

                dG_ddelx2_1 <= dG_ddelx2_temp1;
                dG_ddelx2_2 <= dG_ddelx2_temp2;

                dG_ddely2_1 <= dG_ddely2_temp1;
                dG_ddely2_2 <= dG_ddely2_temp2;

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


                {gaussian_color2_R, gaussian_color2_G, gaussian_color2_B} <= {gaussian_color1_R, gaussian_color1_G, gaussian_color1_B};
                gaussian_depth2 <= gaussian_depth1;            

                gaussian_id2 <= gaussian_id1;

                last_input2 <= last_input1;


                ////////////////////////////////////////////////////////////////////
                ///////////////////////// Clock 3 Data Flow ///////////////////////
                ////////////////////////////////////////////////////////////////////

                G3 <= G2;
                {conic_opacity3_x, conic_opacity3_y, conic_opacity3_z, conic_opacity3_w} <= {conic_opacity2_x, conic_opacity2_y, conic_opacity2_z, conic_opacity2_w};

                T3 <= T2;

                ddelx_dx3 <= ddelx_dx2;
                ddely_dy3 <= ddely_dy2;

                dG_ddelx3 <= dG_ddelx3_temp;
                dG_ddely3 <= dG_ddely3_temp;

                i_valid3 <= i_valid2;
                dchannel_dcolor3 <= dchannel_dcolor3_temp;
                {diff_color3_R, diff_color3_G, diff_color3_B} <= {diff_color3_temp_R, diff_color3_temp_G, diff_color3_temp_B};
                diff_depth3 <= diff_depth3_temp;

                
                d_x_gdx3 <= d_x_gdx2;
                d_y_gdx3 <= d_y_gdx2;
                d_y_gdy3 <= d_y_gdy2;

                gaussian_id3 <= gaussian_id2;

                last_input3 <= last_input2;


                ////////////////////////////////////////////////////////////////////
                ///////////////////////// Clock 4 Data Flow ///////////////////////
                ////////////////////////////////////////////////////////////////////

                G4 <= G3;
                {conic_opacity4_x, conic_opacity4_y, conic_opacity4_z, conic_opacity4_w} <= {conic_opacity3_x, conic_opacity3_y, conic_opacity3_z, conic_opacity3_w};

                T4 <= T3;

                i_valid4 <= i_valid3;
                dL_dalpha_added4_1 <= dL_dalpha_added4_temp1;
                dL_dalpha_added4_2 <= dL_dalpha_added4_temp2;
                dL_dalpha_added4_3 <= dL_dalpha_added4_temp3;
                dL_dalpha_added4_4 <= dL_dalpha_added4_temp4;
                
                {dL_dcolor4_R, dL_dcolor4_G, dL_dcolor4_B} <= {dL_dcolor_temp4_R, dL_dcolor_temp4_G, dL_dcolor_temp4_B};
                dL_ddepth4 <= dL_ddepth_temp4;


                dG_dx4 <= dG_dx4_temp;
                dG_dy4 <= dG_dy4_temp;

                d_x_gdx4 <= d_x_gdx3;
                d_y_gdx4 <= d_y_gdx3;
                d_y_gdy4 <= d_y_gdy3;
        
                gaussian_id4 <= gaussian_id3;

                last_input4 <= last_input3;


                ////////////////////////////////////////////////////////////////////
                ///////////////////////// Clock 5 Data Flow ///////////////////////
                ////////////////////////////////////////////////////////////////////

                G5 <= G4;

                T5 <= T4;
                {conic_opacity5_x, conic_opacity5_y, conic_opacity5_z, conic_opacity5_w} <= {conic_opacity4_x, conic_opacity4_y, conic_opacity4_z, conic_opacity4_w};
                
                i_valid5 <= i_valid4;

                {dL_dcolor5_R, dL_dcolor5_G, dL_dcolor5_B} <= {dL_dcolor4_R, dL_dcolor4_G, dL_dcolor4_B};
                dL_ddepth5 <= dL_ddepth4;

                dG_dx5 <= dG_dx4;
                dG_dy5 <= dG_dy4;

                d_x_gdx5 <= d_x_gdx4;
                d_y_gdx5 <= d_y_gdx4;
                d_y_gdy5 <= d_y_gdy4;

                dL_dalpha_added5_1 <= dL_dalpha_added5_temp1;
                dL_dalpha_added5_2 <= dL_dalpha_added5_temp2;

                gaussian_id5 <= gaussian_id4;

                last_input5 <= last_input4;


                ////////////////////////////////////////////////////////////////////
                ///////////////////////// Clock 6 Data Flow ///////////////////////
                ////////////////////////////////////////////////////////////////////

                
                G6 <= G5;
                T6 <= T5;

                i_valid6 <= i_valid5;
                {dL_dcolor6_R, dL_dcolor6_G, dL_dcolor6_B} <= {dL_dcolor5_R, dL_dcolor5_G, dL_dcolor5_B};
                dL_ddepth6 <= dL_ddepth5;
                {conic_opacity6_x, conic_opacity6_y, conic_opacity6_z, conic_opacity6_w} <= {conic_opacity5_x, conic_opacity5_y, conic_opacity5_z, conic_opacity5_w};

                dG_dx6 <= dG_dx5;
                dG_dy6 <= dG_dy5;

                d_x_gdx6 <= d_x_gdx5;
                d_y_gdx6 <= d_y_gdx5;
                d_y_gdy6 <= d_y_gdy5;
                
                     
                dL_dalpha_added6 <= dL_dalpha_added6_temp;

                gaussian_id6 <= gaussian_id5;

                last_input6 <= last_input5;


                ////////////////////////////////////////////////////////////////////
                ///////////////////////// Clock 7 Data Flow ///////////////////////
                ////////////////////////////////////////////////////////////////////

                G7 <= G6;

                i_valid7 <= i_valid6;

                {conic_opacity7_x, conic_opacity7_y, conic_opacity7_z, conic_opacity7_w} <= {conic_opacity6_x, conic_opacity6_y, conic_opacity6_z, conic_opacity6_w};

                {dL_dcolor7_R, dL_dcolor7_G, dL_dcolor7_B} <= {dL_dcolor6_R, dL_dcolor6_G, dL_dcolor6_B};
                dL_ddepth7 <= dL_ddepth6;

                dL_dalpha7 <= dL_dalpha7_temp;

                
                dG_dx7 <= dG_dx6;
                dG_dy7 <= dG_dy6;

                d_x_gdx7 <= d_x_gdx6;
                d_y_gdx7 <= d_y_gdx6;
                d_y_gdy7 <= d_y_gdy6;

                gaussian_id7 <= gaussian_id6;

                last_input7 <= last_input6;

                ////////////////////////////////////////////////////////////////////
                ///////////////////////// Clock 8 Data Flow ///////////////////////
                ////////////////////////////////////////////////////////////////////


                i_valid8 <= i_valid7;

                dL_dG8 <= dL_dG8_temp;
                d_x_gdx8 <= d_x_gdx7;
                d_y_gdx8 <= d_y_gdx7;
                d_y_gdy8 <= d_y_gdy7;

                dG_dx8 <= dG_dx7;
                dG_dy8 <= dG_dy7;

                {dL_dcolor8_R, dL_dcolor8_G, dL_dcolor8_B} <= {dL_dcolor7_R, dL_dcolor7_G, dL_dcolor7_B};
                dL_ddepth8 <= dL_ddepth7;
                dL_dopacity8 <= dL_dopacity8_temp;

                gaussian_id8 <= gaussian_id7;

                last_input8 <= last_input7;
                
    


                ////////////////////////////////////////////////////////////////////
                ///////////////////////// Clock 10 Data Out ///////////////////////
                ////////////////////////////////////////////////////////////////////



                if (!both_pixel_grad_zero) begin

                    gradient_valid_out <= i_valid8;
                    dL_dcolor <= {dL_dcolor8_R, dL_dcolor8_G, dL_dcolor8_B};
                    dL_ddepth <= dL_ddepth8;

                    dL_dopacity <= dL_dopacity8;

                    dL_dmean2D <= {dL_dmean2D9_x_temp, dL_dmean2D9_y_temp};
                    dL_dconic <= {dL_dconic9_x_temp, dL_dconic9_y_temp, dL_dconic9_z_temp, dL_dconic9_w_temp};
                    
                    gaussian_id_out <= gaussian_id8;
                    last_input_done <= last_input8;
                end

                else begin
                    gradient_valid_out <= 'b0;
                    dL_dcolor <= 'h0;
                    dL_ddepth <= 'h0;
                    dL_dopacity <= 'h0;
                    dL_dmean2D <= 'h0;
                    dL_dconic <= 'h0;
                    gaussian_id_out <= 'h0;
                    last_input_done <= 'h0;
                end

            end
        end
    end

endmodule
