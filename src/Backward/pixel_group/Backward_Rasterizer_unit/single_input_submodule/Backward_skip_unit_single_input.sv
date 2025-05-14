module Backward_skip_unit_single_input
    #(
        parameter BLOCK_SIZE = 16,
        parameter exponent_bit = 8,
        parameter mantissa_bit = 23,
        parameter precision = 32,
        parameter GID_bit = 24
    )
    (
    input logic clk,
    input logic rst_n,

    input logic start,
    input logic [15:0] block_id, // block id | X | Y |

    input logic [( 2 * precision ) - 1 : 0] mean2D , // fp32 | X | Y | 
    input logic [(4 * precision) - 1:0] conic_opacity , // fp32 | X | Y | Z | W |
    input logic [(2 * $clog2(BLOCK_SIZE) - 1): 0] pixel_id, // int 0 ~ 255 

    input logic [GID_bit-1:0] gaussian_id_in , // gaussian id

    input logic [precision -1 :0] gaussian_depth_in , // gaussian depth
    input logic [(3 * precision) - 1:0] gaussian_color_in , // gaussian color
 
    input logic i_valid ,

    input logic stall, // wire

    input logic ready_from_arbiter ,

    input logic last_input ,
    

    output logic skip_out , // can be work as valid
    output logic [precision - 1 : 0] G_out ,
    output logic [( 2 * precision ) - 1 : 0] d_out ,
    output logic [precision - 1 : 0] alpha_out ,
    output logic [(4 * precision) - 1:0] conic_opacity_out , // fp32 | X | Y | Z | W |

    output logic [GID_bit-1:0] gaussian_id_out ,
    output logic [(3*precision) - 1:0] gaussian_color_out ,
    output logic [precision - 1:0] gaussian_depth_out ,

    output logic skip_and_alpha_done_out ,

    output logic last_input_done 
    );
    // synopsys template

    
    localparam ieee_compliance = 1'b0;
    // localparam [2:0] inst_rnd [1:12] = {3'b0, 3'b0, 3'b0, 3'b0, 3'b0, 3'b0, 3'b0, 3'b0, 3'b0, 3'b0, 3'b0, 3'b0};


    /////////////////////////////////////////
    /////////// register declaration ////////
    /////////////////////////////////////////

    // logic [( 2 * precision ) - 1 : 0] d2 , d3 , d4 , d5 , d6 , d7 ;

    logic [precision - 1 : 0] d2_x , d2_y , d3_x , d3_y , d4_x , d4_y , d5_x , d5_y , d6_x , d6_y , d7_x , d7_y , d8_x , d8_y ;

    logic [precision - 1 : 0] G7  , G8 ;
    logic [precision - 1 : 0] dxx3 , dxy3 , dyy3 ;
    logic skip7 , skip8 ;

    logic i_valid0 , i_valid1 , i_valid2 , i_valid3 , i_valid4 , i_valid5 , i_valid6 , i_valid7 , i_valid8 ;
    
    logic [precision - 1 : 0] mean2D0_x  , mean2D0_y  , mean2D1_x  , mean2D1_y ;

    logic [precision - 1:0] conic_opacity0_x , conic_opacity0_y , conic_opacity0_z , conic_opacity0_w ;
    logic [precision - 1:0] conic_opacity1_x , conic_opacity1_y , conic_opacity1_z , conic_opacity1_w ;
    logic [precision - 1:0] conic_opacity2_x , conic_opacity2_y , conic_opacity2_z , conic_opacity2_w ;
    logic [precision - 1:0] conic_opacity3_x , conic_opacity3_y , conic_opacity3_z , conic_opacity3_w ;
    logic [precision - 1:0] conic_opacity4_x , conic_opacity4_y , conic_opacity4_z , conic_opacity4_w ;
    logic [precision - 1:0] conic_opacity5_x , conic_opacity5_y , conic_opacity5_z , conic_opacity5_w ;
    logic [precision - 1:0] conic_opacity6_x , conic_opacity6_y , conic_opacity6_z , conic_opacity6_w ;
    logic [precision - 1:0] conic_opacity7_x , conic_opacity7_y , conic_opacity7_z , conic_opacity7_w ;
    logic [precision - 1:0] conic_opacity8_x , conic_opacity8_y , conic_opacity8_z , conic_opacity8_w ;


    logic [(2 * $clog2(BLOCK_SIZE) - 1): 0] pixel_id0;
    logic [precision - 1 : 0] power6 ;
    logic [precision - 1 : 0] alpha8 ;
    logic [15:0] block_id0;

    logic [GID_bit-1:0] gaussian_id0 , gaussian_id1 , gaussian_id2 , gaussian_id3 , gaussian_id4 , gaussian_id5 , gaussian_id6 , gaussian_id7 , gaussian_id8 ;

    logic [precision-1:0] gaussian_color0_R , gaussian_color0_G , gaussian_color0_B ;
    logic [precision-1:0] gaussian_color1_R , gaussian_color1_G , gaussian_color1_B ;
    logic [precision-1:0] gaussian_color2_R , gaussian_color2_G , gaussian_color2_B ;
    logic [precision-1:0] gaussian_color3_R , gaussian_color3_G , gaussian_color3_B ;
    logic [precision-1:0] gaussian_color4_R , gaussian_color4_G , gaussian_color4_B ;
    logic [precision-1:0] gaussian_color5_R , gaussian_color5_G , gaussian_color5_B ;
    logic [precision-1:0] gaussian_color6_R , gaussian_color6_G , gaussian_color6_B ;
    logic [precision-1:0] gaussian_color7_R , gaussian_color7_G , gaussian_color7_B ;
    logic [precision-1:0] gaussian_color8_R , gaussian_color8_G , gaussian_color8_B ;

    logic [precision - 1:0] gaussian_depth0 , gaussian_depth1 , gaussian_depth2 , gaussian_depth3 , gaussian_depth4 , gaussian_depth5 , gaussian_depth6 , gaussian_depth7 , gaussian_depth8 ;

    logic last_input0 , last_input1 , last_input2 , last_input3 , last_input4 , last_input5 , last_input6 , last_input7 , last_input8 ;
    logic [precision - 1 : 0] current_pixel_fp1_x, current_pixel_fp1_y;
    logic start1;

    logic [precision - 1 : 0] exp_temp4_1 , exp_temp4_2 , exp_temp4_3 ;
    logic [precision - 1 : 0] exp_temp5_1 , exp_temp5_2 ;

    /////////////////////////////////////////
    ///////////// wire declaration //////////
    /////////////////////////////////////////
    logic [precision - 1 : 0] d_x_temp ;
    logic [precision - 1 : 0] d_y_temp ;

    logic [precision - 1 : 0] power_temp ;
    
    logic skip_temp1 , skip_temp2 ;
    // logic [(2 * precision) - 1 : 0] current_pixel ;
    logic [precision - 1 : 0] exp_temp4_1_wire , exp_temp4_2_wire , exp_temp4_3_wire ;
    logic [precision - 1 : 0] exp_temp5_1_wire ;

    
    logic [precision - 1 : 0] current_pixel_fp_x, current_pixel_fp_y;
    
    logic [precision - 1 : 0] dxx_temp , dyy_temp , dxy_temp ;
    logic [precision - 1 : 0] max_alpha; // 0.99 in fp32
    logic [precision - 1 : 0] min_alpha; // 1/255 in fp32
    logic [precision - 1 : 0] One;

    logic [precision - 1 : 0] alpha_temp1 , alpha_temp2 ;

    logic aeqb_inst1, aeqb_inst2, altb_inst , agtb_inst1 , agtb_inst2,  unordered_inst1 , unordered_inst2;

    logic [precision - 1 : 0] not_used_alpha1 ,  not_used_alpha2 , not_used_alpha3 ;
    logic [7:0] status_flag_0 , status_flag_1 , status_flag_2 , status_flag_3 ;

    logic [7:0] status_inst [1:12];
    logic [7:0] status_inst_pixel [1:2];
    // logic [7:0] status_inst_pixel [1:2];


    logic skip_from_alpha ;
    logic [precision - 1 : 0] G_temp ;

    logic [precision - 1: 0] power_th;
    // logic early_skip_temp ;
    logic [precision - 1: 0] not_used_power1, not_used_power2 ;

    assign max_alpha = (precision == 32 && mantissa_bit == 23) ? 32'h3f7d_70a4 :
                    (precision == 16 && mantissa_bit == 7) ? 16'h3f7d :
                    (precision == 24 && mantissa_bit == 15) ? 24'h3f7d_70 :
                    {precision{1'b0}};

    assign min_alpha = (precision == 32 && mantissa_bit == 23) ? 32'h3b80_0000 :
                    (precision == 16 && mantissa_bit == 7) ? 16'h3b80 :
                    (precision == 24 && mantissa_bit == 15) ? 24'h3b80_00 :
                    {precision{1'b0}};
    
    assign power_th = (precision == 32 && mantissa_bit == 23) ? 32'hc0c0_0000 :
                    (precision == 16 && mantissa_bit == 7) ? 16'hc0c0 :
                    (precision == 24 && mantissa_bit == 15) ? 24'hc0c0_00 :
                    {precision{1'b0}};

    assign One = (precision == 32 && mantissa_bit == 23) ? 32'h3f80_0000 :
              (precision == 16 && mantissa_bit == 7) ? 16'h3f80 :
              (precision == 24 && mantissa_bit == 15) ? 24'h3f80_00 :
              {precision{1'b0}};


    ////////////////////////////////////////////////////////////////////
    //////////////////////////// Clock Step 1 //////////////////////////
    ////////////////////////////////////////////////////////////////////

    // put directly to input
    // assign current_pixel = {{(precision-11){1'b0}}, block_id0[14 : 8], pixel_id0[$clog2(BLOCK_SIZE)-1:0], {(precision-11){1'b0}}, block_id0[6:0], pixel_id0[(2 * $clog2(BLOCK_SIZE))-1:$clog2(BLOCK_SIZE)] }; // 16bit int | X | Y |

    // Instance of DW_fp_i2flt
    // 32 for int size 

    // 
    DW_fp_i2flt #(mantissa_bit, exponent_bit, precision, 1)
      fp_pixel_x_inst_i ( 
        .a({{(precision-11){1'b0}}, block_id0[14:8], pixel_id0[$clog2(BLOCK_SIZE)-1:0]}), 
        .rnd(3'b0), 
        .z(current_pixel_fp_x), 
        .status(status_inst_pixel[1])
      );

    // Instance of DW_fp_i2flt for pixel_y
    DW_fp_i2flt #(mantissa_bit, exponent_bit, precision, 1)
      fp_pixel_y_inst_i ( 
        .a({{(precision-11){1'b0}}, block_id0[6:0], pixel_id0[(2 * $clog2(BLOCK_SIZE))-1:$clog2(BLOCK_SIZE)]}), 
        .rnd(3'b0), 
        .z(current_pixel_fp_y), 
        .status(status_inst_pixel[2])
      );

    
    // 가를거면 이거 갈라야함
        // Instance of DW_fp_add for d_x
        DW_fp_add #(mantissa_bit, exponent_bit, 0)
          d_x_inst_i (
            .a(mean2D1_x), 
            .b({!current_pixel_fp1_x[precision - 1], current_pixel_fp1_x[precision - 2 : 0]}), 
            .rnd(3'b0), 
            .z(d_x_temp), 
            .status(status_inst[1])
          );

        // Instance of DW_fp_add for d_y
        DW_fp_add #(mantissa_bit, exponent_bit, 0)
          d_y_inst_i (
            .a(mean2D1_y), 
            .b({!current_pixel_fp1_y[precision - 1], current_pixel_fp1_y[precision - 2 : 0]}), 
            .rnd(3'b0), 
            .z(d_y_temp), 
            .status(status_inst[2])
          );

        ////////////////////////////////////////////////////////////////////
        //////////////////////////// Clock Step 2 //////////////////////////
        ////////////////////////////////////////////////////////////////////

        // Instance of DW_fp_mult for dxx
        DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
          dxx_inst_i (
            .a(d2_x), 
            .b(d2_x), 
            .rnd(3'b0), 
            .z(dxx_temp), 
            .status(status_inst[3])
          );

        // Instance of DW_fp_mult for dyy
        DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
          dyy_inst_i (
            .a(d2_y), 
            .b(d2_y), 
            .rnd(3'b0), 
            .z(dyy_temp), 
            .status(status_inst[4])
          );

        // Instance of DW_fp_mult for dxy
        DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
          dxy_inst_i (
            .a(d2_x), 
            .b(d2_y), 
            .rnd(3'b0), 
            .z(dxy_temp), 
            .status(status_inst[5])
          );

        ////////////////////////////////////////////////////////////////////
        //////////////////////////// Clock Step 3 //////////////////////////
        ////////////////////////////////////////////////////////////////////

        // Instance of DW_fp_mult for t1
        DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
          t1_inst_i (
            .a(dxx3), 
            .b(conic_opacity3_x), 
            .rnd(3'b0), 
            .z(exp_temp4_1_wire), 
            .status(status_inst[6])
          );

        // Instance of DW_fp_mult for t2
        DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
          t2_inst_i (
            .a(dyy3), 
            .b(conic_opacity3_z), 
            .rnd(3'b0), 
            .z(exp_temp4_2_wire), 
            .status(status_inst[7])
          );

        // Instance of DW_fp_mult for t3
        DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
          t3_inst_i (
            .a(dxy3), 
            .b(conic_opacity3_y), 
            .rnd(3'b0), 
            .z(exp_temp4_3_wire), 
            .status(status_inst[8])
          );



        ////////////////////////////////////////////////////////////////////
        //////////////////////////// Clock Step 4 //////////////////////////
        ////////////////////////////////////////////////////////////////////



        // // Instance of DW_fp_sum3 for power_maker
        // DW_fp_sum3 #(mantissa_bit, exponent_bit, ieee_compliance, 0)
        //   power_maker_inst_i (
        //     .a({!exp_temp1[precision - 1], exp_temp1[precision - 2 : mantissa_bit] - 8'd1, exp_temp1[mantissa_bit - 1 : 0]}), 
        //     .b({!exp_temp2[precision - 1], exp_temp2[precision - 2 : mantissa_bit] - 8'd1, exp_temp2[mantissa_bit - 1 : 0]}), 
        //     .c({!exp_temp3[precision - 1], exp_temp3[precision - 2 : 0]}), 
        //     .rnd(3'b0), 
        //     .z(power_temp), 
        //     .status(status_inst[9])
        //   );

        // Instance of DW_fp_add for power_maker
        DW_fp_add #(mantissa_bit, exponent_bit, 0)
          power_maker_inst1_i (
            .a({!exp_temp4_1[precision - 1], exp_temp4_1[precision - 2 : mantissa_bit] - 8'd1, exp_temp4_1[mantissa_bit - 1 : 0]}), 
            .b({!exp_temp4_2[precision - 1], exp_temp4_2[precision - 2 : mantissa_bit] - 8'd1, exp_temp4_2[mantissa_bit - 1 : 0]}), 
            .rnd(3'b0), 
            .z(exp_temp5_1_wire), 
            .status(status_inst[9])
          );

        ////////////////////////////////////////////////////////////////////
        //////////////////////////// Clock Step 5 //////////////////////////
        ////////////////////////////////////////////////////////////////////

        // Instance of DW_fp_add for power_maker
        DW_fp_add #(mantissa_bit, exponent_bit,  0)
          power_maker_inst2_i (
            .a(exp_temp5_1), 
            .b({!exp_temp5_2[precision - 1], exp_temp5_2[precision - 2 : 0]}),
            .rnd(3'b0),
            .z(power_temp), 
            .status(status_inst[12])
          );      

        ////////////////////////////////////////////////////////////////////
        //////////////////////////// Clock Step 6 //////////////////////////
        ////////////////////////////////////////////////////////////////////

        // Instance of DW_fp_exp for exponent_power
        DW_fp_exp #(mantissa_bit, exponent_bit, 1, 0)
          exponent_power_inst_i (
            .a(power6), 
            .z(G_temp), 
            .status(status_inst[10])
          );

        ////////////////////////////////////////////////////////////////////
        //////////////////////////// Clock Step 7 //////////////////////////
        ////////////////////////////////////////////////////////////////////

        // Instance of DW_fp_mult for alpha_temp_maker
        DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
          alpha_temp_maker_inst_i (
            .a(G7), 
            .b(conic_opacity7_w), 
            .rnd(3'b0), 
            .z(alpha_temp1), 
            .status(status_inst[11])
          );

        ////////////////////////////////////////////////////////////////////
        /////////////////////////// Clock Step 8 ///////////////////////////
        ////////////////////////////////////////////////////////////////////

        // Instance of DW_fp_cmp for alpha_comp
        DW_fp_cmp #(mantissa_bit, exponent_bit, 0)
          alpha_comp_inst_i (
            .a(alpha8), 
            .b(max_alpha), 
            .zctr(1'b0), 
            .aeqb(aeqb_inst1), 
            .altb(altb_inst), 
            .agtb(agtb_inst1), 
            .unordered(unordered_inst1), 
            .z0(alpha_temp2), 
            .z1(not_used_alpha1), 
            .status0(status_flag_0), 
            .status1(status_flag_1)
          );

        // Instance of DW_fp_cmp for alpha_skip_comp
        DW_fp_cmp #(mantissa_bit, exponent_bit, 0)
          alpha_skip_comp_inst_i (
            // .a(alpha_temp2), 
            .a(alpha8), 
            .b(min_alpha), 
            .zctr(1'b0), 
            .aeqb(aeqb_inst2), 
            .altb(skip_from_alpha), 
            .agtb(agtb_inst2), 
            .unordered(unordered_inst2), 
            .z0(not_used_alpha2), 
            .z1(not_used_alpha3), 
            .status0(status_flag_2), 
            .status1(status_flag_3)
          );

    assign skip_temp1 = !power6[precision - 1];
    assign skip_temp2 = (skip_from_alpha || skip8);


    ////////////////////////////////////////////////////////////////////
    //////////////////////// Clock Step 7 (Out) ////////////////////////
    ////////////////////////////////////////////////////////////////////

    // Capture before out 
    always_ff @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin

          
            block_id0 <= 'h0;
            pixel_id0 <= 'h0;

            current_pixel_fp1_x <= 'h0;
            current_pixel_fp1_y <= 'h0;

            start1 <= 'b0;
        
            
            


            skip7 <= 'b0;
            skip8 <= 'b0;
            skip_out <= 'b0;

            

            G_out <= 'h0;
            G7 <= 'h0;
            G8 <= 'h0;

            d_out <= 'h0;
            
            d2_x <= 'h0;
            d2_y <= 'h0;
            d3_x <= 'h0;
            d3_y <= 'h0;
            d4_x <= 'h0;
            d4_y <= 'h0;
            d5_x <= 'h0;
            d5_y <= 'h0;
            d6_x <= 'h0;
            d6_y <= 'h0;
            d7_x <= 'h0;
            d7_y <= 'h0;
            d8_x <= 'h0;
            d8_y <= 'h0;
            alpha_out <= 'h0;

            dxx3 <= 'h0;
            dxy3 <= 'h0;
            dyy3 <= 'h0;

            // power6 <= {1'b1, {(precision-1){1'b0}}};
            power6 <= 'h0;

            i_valid0 <= 'b0;
            i_valid1 <= 'b0;
            i_valid2 <= 'b0;
            i_valid3 <= 'b0;
            i_valid4 <= 'b0;
            i_valid5 <= 'b0;
            i_valid6 <= 'b0;
            i_valid7 <= 'b0;
            i_valid8 <= 'b0;

            skip_and_alpha_done_out <= 'b0;

            mean2D0_x <= 'h0;
            mean2D0_y <= 'h0;
            mean2D1_x <= 'h0;
            mean2D1_y <= 'h0;

            conic_opacity0_x <= 'h0;
            conic_opacity0_y <= 'h0;
            conic_opacity0_z <= 'h0;
            conic_opacity0_w <= 'h0;

            conic_opacity1_x <= 'h0;
            conic_opacity1_y <= 'h0;
            conic_opacity1_z <= 'h0;
            conic_opacity1_w <= 'h0;

            conic_opacity2_x <= 'h0;
            conic_opacity2_y <= 'h0;
            conic_opacity2_z <= 'h0;
            conic_opacity2_w <= 'h0;

            conic_opacity3_x <= 'h0;
            conic_opacity3_y <= 'h0;
            conic_opacity3_z <= 'h0;
            conic_opacity3_w <= 'h0;

            conic_opacity4_x <= 'h0;
            conic_opacity4_y <= 'h0;
            conic_opacity4_z <= 'h0;
            conic_opacity4_w <= 'h0;

            conic_opacity5_x <= 'h0;
            conic_opacity5_y <= 'h0;
            conic_opacity5_z <= 'h0;
            conic_opacity5_w <= 'h0;

            conic_opacity6_x <= 'h0;
            conic_opacity6_y <= 'h0;
            conic_opacity6_z <= 'h0;
            conic_opacity6_w <= 'h0;

            conic_opacity7_x <= 'h0;
            conic_opacity7_y <= 'h0;
            conic_opacity7_z <= 'h0;
            conic_opacity7_w <= 'h0;

            conic_opacity8_x <= 'h0;
            conic_opacity8_y <= 'h0;
            conic_opacity8_z <= 'h0;
            conic_opacity8_w <= 'h0;

            conic_opacity_out <= 'h0;

            alpha8 <= 'h0;
            // early_skip <= 'b0;

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

            gaussian_color0_R <= 'h0;
            gaussian_color0_G <= 'h0;
            gaussian_color0_B <= 'h0;
            gaussian_color1_R <= 'h0;
            gaussian_color1_G <= 'h0;
            gaussian_color1_B <= 'h0;
            gaussian_color2_R <= 'h0;
            gaussian_color2_G <= 'h0;
            gaussian_color2_B <= 'h0;
            gaussian_color3_R <= 'h0;
            gaussian_color3_G <= 'h0;
            gaussian_color3_B <= 'h0;
            gaussian_color4_R <= 'h0;
            gaussian_color4_G <= 'h0;
            gaussian_color4_B <= 'h0;
            gaussian_color5_R <= 'h0;
            gaussian_color5_G <= 'h0;
            gaussian_color5_B <= 'h0;
            gaussian_color6_R <= 'h0;
            gaussian_color6_G <= 'h0;
            gaussian_color6_B <= 'h0;
            gaussian_color7_R <= 'h0;
            gaussian_color7_G <= 'h0;
            gaussian_color7_B <= 'h0;
            gaussian_color8_R <= 'h0;
            gaussian_color8_G <= 'h0;
            gaussian_color8_B <= 'h0;
            gaussian_color_out <= 'h0;
            
            gaussian_depth0 <= 'h0;
            gaussian_depth1 <= 'h0;
            gaussian_depth2 <= 'h0;
            gaussian_depth3 <= 'h0;
            gaussian_depth4 <= 'h0;
            gaussian_depth5 <= 'h0;
            gaussian_depth6 <= 'h0;
            gaussian_depth7 <= 'h0;
            gaussian_depth8 <= 'h0;
            gaussian_depth_out <= 'h0;

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

            exp_temp4_1 <= 'h0;
            exp_temp4_2 <= 'h0;
            exp_temp4_3 <= 'h0;

            exp_temp5_1 <= 'h0;
            exp_temp5_2 <= 'h0;

  
        end

        else if (start) begin

              block_id0 <= block_id;
              pixel_id0 <= pixel_id;
              start1 <= start;


              skip7 <= 'b0;
              skip8 <= 'b0;
              skip_out <= 'b0;

              

              G_out <= 'h0;
              G7 <= 'h0;
              G8 <= 'h0;

              d_out <= 'h0;
              
              d2_x <= 'h0;
              d2_y <= 'h0;
              d3_x <= 'h0;
              d3_y <= 'h0;
              d4_x <= 'h0;
              d4_y <= 'h0;
              d5_x <= 'h0;
              d5_y <= 'h0;
              d6_x <= 'h0;
              d6_y <= 'h0;
              d7_x <= 'h0;
              d7_y <= 'h0;
              d8_x <= 'h0;
              d8_y <= 'h0;
              alpha_out <= 'h0;

              dxx3 <= 'h0;
              dxy3 <= 'h0;
              dyy3 <= 'h0;

              // power6 <= {1'b1, {(precision-1){1'b0}}};
              power6 <= 'h0;

              i_valid0 <= 'b0;
              i_valid1 <= 'b0;
              i_valid2 <= 'b0;
              i_valid3 <= 'b0;
              i_valid4 <= 'b0;
              i_valid5 <= 'b0;
              i_valid6 <= 'b0;
              i_valid7 <= 'b0;
              i_valid8 <= 'b0;
              skip_and_alpha_done_out <= 'b0;

              mean2D0_x <= 'h0;
              mean2D0_y <= 'h0;
              mean2D1_x <= 'h0;
              mean2D1_y <= 'h0;

              conic_opacity0_x <= 'h0;
              conic_opacity0_y <= 'h0;
              conic_opacity0_z <= 'h0;
              conic_opacity0_w <= 'h0;

              conic_opacity1_x <= 'h0;
              conic_opacity1_y <= 'h0;
              conic_opacity1_z <= 'h0;
              conic_opacity1_w <= 'h0;

              conic_opacity2_x <= 'h0;
              conic_opacity2_y <= 'h0;
              conic_opacity2_z <= 'h0;
              conic_opacity2_w <= 'h0;

              conic_opacity3_x <= 'h0;
              conic_opacity3_y <= 'h0;
              conic_opacity3_z <= 'h0;
              conic_opacity3_w <= 'h0;

              conic_opacity4_x <= 'h0;
              conic_opacity4_y <= 'h0;
              conic_opacity4_z <= 'h0;
              conic_opacity4_w <= 'h0;

              conic_opacity5_x <= 'h0;
              conic_opacity5_y <= 'h0;
              conic_opacity5_z <= 'h0;
              conic_opacity5_w <= 'h0;

              conic_opacity6_x <= 'h0;
              conic_opacity6_y <= 'h0;
              conic_opacity6_z <= 'h0;
              conic_opacity6_w <= 'h0;

              conic_opacity7_x <= 'h0;
              conic_opacity7_y <= 'h0;
              conic_opacity7_z <= 'h0;
              conic_opacity7_w <= 'h0;

              conic_opacity8_x <= 'h0;
              conic_opacity8_y <= 'h0;
              conic_opacity8_z <= 'h0;
              conic_opacity8_w <= 'h0;

              conic_opacity_out <= 'h0;

              alpha8 <= 'h0;
              // early_skip <= 'b0;

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

              gaussian_color0_R <= 'h0;
              gaussian_color0_G <= 'h0;
              gaussian_color0_B <= 'h0;
              gaussian_color1_R <= 'h0;
              gaussian_color1_G <= 'h0;
              gaussian_color1_B <= 'h0;
              gaussian_color2_R <= 'h0;
              gaussian_color2_G <= 'h0;
              gaussian_color2_B <= 'h0;
              gaussian_color3_R <= 'h0;
              gaussian_color3_G <= 'h0;
              gaussian_color3_B <= 'h0;
              gaussian_color4_R <= 'h0;
              gaussian_color4_G <= 'h0;
              gaussian_color4_B <= 'h0;
              gaussian_color5_R <= 'h0;
              gaussian_color5_G <= 'h0;
              gaussian_color5_B <= 'h0;
              gaussian_color6_R <= 'h0;
              gaussian_color6_G <= 'h0;
              gaussian_color6_B <= 'h0;
              gaussian_color7_R <= 'h0;
              gaussian_color7_G <= 'h0;
              gaussian_color7_B <= 'h0;
              gaussian_color8_R <= 'h0;
              gaussian_color8_G <= 'h0;
              gaussian_color8_B <= 'h0;
              gaussian_color_out <= 'h0;
              
              gaussian_depth0 <= 'h0;
              gaussian_depth1 <= 'h0;
              gaussian_depth2 <= 'h0;
              gaussian_depth3 <= 'h0;
              gaussian_depth4 <= 'h0;
              gaussian_depth5 <= 'h0;
              gaussian_depth6 <= 'h0;
              gaussian_depth7 <= 'h0;
              gaussian_depth8 <= 'h0;
              gaussian_depth_out <= 'h0;

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

              exp_temp4_1 <= 'h0;
              exp_temp4_2 <= 'h0;
              exp_temp4_3 <= 'h0;

              exp_temp5_1 <= 'h0;
              exp_temp5_2 <= 'h0;

    

            
        end


        else begin
            start1 <= start;

            if (start1) begin
              current_pixel_fp1_x <= current_pixel_fp_x;
              current_pixel_fp1_y <= current_pixel_fp_y;
            end

            if (!stall) begin

                
                  ////////////////////////////////////////////////////////////////////
                  ///////////////////////// Clock 1 Data Input ///////////////////////
                  ////////////////////////////////////////////////////////////////////

                  

                  i_valid0 <= i_valid;
                  {mean2D0_x, mean2D0_y} <= mean2D;
                  {conic_opacity0_x, conic_opacity0_y, conic_opacity0_z, conic_opacity0_w} <= conic_opacity;
                  

                  gaussian_id0 <= gaussian_id_in;
                  {gaussian_color0_R, gaussian_color0_G, gaussian_color0_B} <= gaussian_color_in;
                  gaussian_depth0 <= gaussian_depth_in;
                  last_input0 <= last_input;

                  ////////////////////////////////////////////////////////////////////
                  ///////////////////////// Clock 2 Data Flow ///////////////////////
                  ////////////////////////////////////////////////////////////////////

                  {mean2D1_x, mean2D1_y} <= {mean2D0_x, mean2D0_y};

                  i_valid1 <= i_valid0;
                  {conic_opacity1_x, conic_opacity1_y, conic_opacity1_z, conic_opacity1_w} <= {conic_opacity0_x, conic_opacity0_y, conic_opacity0_z, conic_opacity0_w};
                  
                  gaussian_id1 <= gaussian_id0;

                  // gaussian_id1 <= gaussian_id0;
                  {gaussian_color1_R, gaussian_color1_G, gaussian_color1_B} <= {gaussian_color0_R, gaussian_color0_G, gaussian_color0_B};
                  gaussian_depth1 <= gaussian_depth0;
                  last_input1 <= last_input0;

                  ////////////////////////////////////////////////////////////////////
                  ///////////////////////// Clock 3 Data Flow ///////////////////////
                  ////////////////////////////////////////////////////////////////////

                  i_valid2 <= i_valid1;
                  {conic_opacity2_x, conic_opacity2_y, conic_opacity2_z, conic_opacity2_w} <= {conic_opacity1_x, conic_opacity1_y, conic_opacity1_z, conic_opacity1_w};

                  {d2_x, d2_y} <= {d_x_temp, d_y_temp};
                  gaussian_id2 <= gaussian_id1;

                  // gaussian_id2 <= gaussian_id1;
                  {gaussian_color2_R, gaussian_color2_G, gaussian_color2_B} <= {gaussian_color1_R, gaussian_color1_G, gaussian_color1_B};
                  gaussian_depth2 <= gaussian_depth1;
                  last_input2 <= last_input1;

                  ////////////////////////////////////////////////////////////////////
                  ///////////////////////// Clock 4 Data Flow ///////////////////////
                  ////////////////////////////////////////////////////////////////////

                  i_valid3 <= i_valid2;
                  {conic_opacity3_x, conic_opacity3_y, conic_opacity3_z, conic_opacity3_w} <= {conic_opacity2_x, conic_opacity2_y, conic_opacity2_z, conic_opacity2_w};
                  {d3_x, d3_y} <= {d2_x, d2_y};

                  dxx3 <= dxx_temp;
                  dxy3 <= dxy_temp;
                  dyy3 <= dyy_temp;
                  
                  
                  gaussian_id3 <= gaussian_id2;

                  // gaussian_id3 <= gaussian_id2;
                  {gaussian_color3_R, gaussian_color3_G, gaussian_color3_B} <= {gaussian_color2_R, gaussian_color2_G, gaussian_color2_B};
                  gaussian_depth3 <= gaussian_depth2;
                  last_input3 <= last_input2;


                  ////////////////////////////////////////////////////////////////////
                  ///////////////////////// Clock 5 Data Flow ///////////////////////
                  ////////////////////////////////////////////////////////////////////



                  i_valid4 <= i_valid3;
                  {conic_opacity4_x, conic_opacity4_y, conic_opacity4_z, conic_opacity4_w} <= {conic_opacity3_x, conic_opacity3_y, conic_opacity3_z, conic_opacity3_w};
                  {d4_x, d4_y} <= {d3_x, d3_y};
                  
                  
                  // early_skip <= early_skip_temp;
                  gaussian_id4 <= gaussian_id3;


                  // gaussian_id4 <= gaussian_id3
                  {gaussian_color4_R, gaussian_color4_G, gaussian_color4_B} <= {gaussian_color3_R, gaussian_color3_G, gaussian_color3_B};
                  gaussian_depth4 <= gaussian_depth3;
                  last_input4 <= last_input3;

                  exp_temp4_1 <= exp_temp4_1_wire;
                  exp_temp4_2 <= exp_temp4_2_wire;
                  exp_temp4_3 <= exp_temp4_3_wire;






                  ////////////////////////////////////////////////////////////////////
                  ///////////////////////// Clock 6 Data Flow ///////////////////////
                  ////////////////////////////////////////////////////////////////////

                  exp_temp5_1 <= exp_temp5_1_wire;
                  exp_temp5_2 <= exp_temp4_3;

                  i_valid5 <= i_valid4;
                  {conic_opacity5_x, conic_opacity5_y, conic_opacity5_z, conic_opacity5_w} <= {conic_opacity4_x, conic_opacity4_y, conic_opacity4_z, conic_opacity4_w};
                  {d5_x, d5_y} <= {d4_x, d4_y};
                  
                  

                  gaussian_id5 <= gaussian_id4;
                  {gaussian_color5_R, gaussian_color5_G, gaussian_color5_B} <= {gaussian_color4_R, gaussian_color4_G, gaussian_color4_B};
                  gaussian_depth5 <= gaussian_depth4;
                  last_input5 <= last_input4;

                  

                  ////////////////////////////////////////////////////////////////////
                  ///////////////////////// Clock 7 Data Flow ///////////////////////
                  ////////////////////////////////////////////////////////////////////

                  power6 <= power_temp;
                  
                  i_valid6 <= i_valid5;


                  {conic_opacity6_x, conic_opacity6_y, conic_opacity6_z, conic_opacity6_w} <= {conic_opacity5_x, conic_opacity5_y, conic_opacity5_z, conic_opacity5_w};
                  {d6_x, d6_y} <= {d5_x, d5_y};
                  

                  gaussian_id6 <= gaussian_id5;
                  {gaussian_color6_R, gaussian_color6_G, gaussian_color6_B} <= {gaussian_color5_R, gaussian_color5_G, gaussian_color5_B};
                  gaussian_depth6 <= gaussian_depth5;
                  last_input6 <= last_input5;

                  

                  ////////////////////////////////////////////////////////////////////
                  /////////////////// Clock 8  Data Flow //////////////////
                  ////////////////////////////////////////////////////////////////////                

                  i_valid7 <= i_valid6;
                  {conic_opacity7_x, conic_opacity7_y, conic_opacity7_z, conic_opacity7_w} <= {conic_opacity6_x, conic_opacity6_y, conic_opacity6_z, conic_opacity6_w};
                  {d7_x, d7_y} <= {d6_x, d6_y};
                  G7 <= G_temp;
                  

                  skip7 <= skip_temp1;
                  

                  gaussian_id7 <= gaussian_id6;
                  {gaussian_color7_R, gaussian_color7_G, gaussian_color7_B} <= {gaussian_color6_R, gaussian_color6_G, gaussian_color6_B};
                  gaussian_depth7 <= gaussian_depth6;

                  last_input7 <= last_input6;

                  ////////////////////////////////////////////////////////////////////
                  /////////////////// Clock 9  Data Flow //////////////////
                  ////////////////////////////////////////////////////////////////////            

                  i_valid8 <= i_valid7;
                  {conic_opacity8_x, conic_opacity8_y, conic_opacity8_z, conic_opacity8_w} <= {conic_opacity7_x, conic_opacity7_y, conic_opacity7_z, conic_opacity7_w};

                  {d8_x, d8_y} <= {d7_x, d7_y};
                  G8 <= G7;
                  

                  skip8 <= skip7;
                  alpha8 <= alpha_temp1;

                  gaussian_id8 <= gaussian_id7;
                  {gaussian_color8_R, gaussian_color8_G, gaussian_color8_B} <= {gaussian_color7_R , gaussian_color7_G , gaussian_color7_B};
                  gaussian_depth8 <= gaussian_depth7;

                  last_input8 <= last_input7;

                  ////////////////////////////////////////////////////////////////////
                  /////////////////// Clock 10 & Final Out Data Flow //////////////////
                  //////////////////////////////////////////////////////////////////// 

                  

                  skip_and_alpha_done_out <= i_valid8;
                  conic_opacity_out <= {conic_opacity8_x, conic_opacity8_y, conic_opacity8_z, conic_opacity8_w};

                  d_out <= {d8_x, d8_y};
                  G_out <= G8;
                  

                  skip_out <= skip_temp2;
                  alpha_out <= alpha_temp2;

                  gaussian_id_out <= gaussian_id8;
                  gaussian_color_out <= {gaussian_color8_R , gaussian_color8_G , gaussian_color8_B};
                  gaussian_depth_out <= gaussian_depth8;

                  last_input_done <= last_input8;              
                           
            end

            else begin // stall == 1'b1
              
                if (ready_from_arbiter && skip_and_alpha_done_out) begin
                    skip_and_alpha_done_out <= 1'b0;
                end
              
            end
        end
        
    end
endmodule