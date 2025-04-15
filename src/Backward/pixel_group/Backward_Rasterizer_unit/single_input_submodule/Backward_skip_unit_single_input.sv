module Backward_skip_unit_single_input
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
    integer j;

    logic [( 2 * precision ) - 1 : 0]  d2 , d3 , d4 , d5 , d6 , d7 ;
    logic [precision - 1 : 0] G6 , G7 ;
    logic [precision - 1 : 0] dxx3 , dxy3 , dyy3 ;
    logic skip6 , skip7 ;

    logic i_valid0 , i_valid1 , i_valid2 , i_valid3 , i_valid4 , i_valid5 , i_valid6 , i_valid7 ;
    logic [( 2 * precision ) - 1 : 0] mean2D0 , mean2D1 ;
    logic [( 4 * precision ) - 1 : 0] conic_opacity0 , conic_opacity1 , conic_opacity2 , conic_opacity3 , conic_opacity4 , conic_opacity5 , conic_opacity6 , conic_opacity7 ;
    logic [(2 * $clog2(BLOCK_SIZE) - 1): 0] pixel_id0;
    logic [precision - 1 : 0] power5 ;
    logic [precision - 1 : 0] alpha7 ;

    logic [GID_bit-1:0] gaussian_id0 , gaussian_id1 , gaussian_id2 , gaussian_id3 , gaussian_id4 , gaussian_id5 , gaussian_id6 , gaussian_id7 ;
    logic [(3 * precision) - 1:0] gaussian_color0 , gaussian_color1 , gaussian_color2 , gaussian_color3 , gaussian_color4 , gaussian_color5 , gaussian_color6 , gaussian_color7 ;
    logic [precision - 1:0] gaussian_depth0 , gaussian_depth1 , gaussian_depth2 , gaussian_depth3 , gaussian_depth4 , gaussian_depth5 , gaussian_depth6 , gaussian_depth7 ;

    logic last_input0 , last_input1 , last_input2 , last_input3 , last_input4 , last_input5 , last_input6 , last_input7 ;

    logic [15:0] block_id0;

    logic [(2 * precision) - 1 : 0] current_pixel_fp1;

    logic start1;
    logic [precision - 1 : 0] exp_temp1, exp_temp2, exp_temp3;


    /////////////////////////////////////////
    ///////////// wire declaration //////////
    /////////////////////////////////////////
    logic [( 2 * precision ) - 1 : 0] d_temp ; // fp32 (int32 calculations needed) | X | Y |
    logic [precision - 1 : 0] power_temp ;
    
    logic skip_temp1 , skip_temp2 ;
    // logic [(2 * precision) - 1 : 0] current_pixel ;
    logic [precision - 1 : 0] temp1 , temp2 , temp3 ;
    // logic [( 2 * precision ) - 1 : 0] current_pixel_fp ;
    logic [( 2 * precision ) - 1 : 0] current_pixel_fp ;
    
    logic [precision - 1 : 0] dxx_temp , dyy_temp , dxy_temp ;
    logic [precision - 1 : 0] max_alpha; // 0.99 in fp32
    logic [precision - 1 : 0] min_alpha; // 1/255 in fp32
    logic [precision - 1 : 0] One;

    logic [precision - 1 : 0] alpha_temp1 , alpha_temp ;

    logic aeqb_inst1 , aeqb_inst2 , altb_inst , agtb_inst1 , agtb_inst2 ,  unordered_inst1 , unordered_inst2 ;

    logic [precision - 1 : 0] not_used_alpha1 ,  not_used_alpha2 , not_used_alpha3 ;
    logic [7:0] status_flag_0 , status_flag_1 , status_flag_2 , status_flag_3 , status_flag_4 , status_flag_5 ;

    logic [7:0] status_inst [1:11];
    logic [7:0] status_inst_pixel [1:2];
    // logic [7:0] status_inst_pixel [1:2];


    logic skip_from_alpha ;
    logic [precision - 1 : 0] G_temp ;

    logic [precision - 1: 0] power_th;
    // logic early_skip_temp ;
    logic [precision - 1: 0] not_used_power1 , not_used_power2 ;

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


    DW_fp_i2flt #(mantissa_bit, exponent_bit, precision, 1)
      fp_pixel_x_inst_i ( 
        .a({{(precision-11){1'b0}}, block_id0[14:8], pixel_id0[$clog2(BLOCK_SIZE)-1:0]}), 
        .rnd(3'b0), 
        .z(current_pixel_fp[(2 * precision) - 1: precision]), 
        .status(status_inst_pixel[1])
      );

    // Instance of DW_fp_i2flt for pixel_y
    DW_fp_i2flt #(mantissa_bit, exponent_bit, precision, 1)
      fp_pixel_y_inst_i ( 
        .a({{(precision-11){1'b0}}, block_id0[6:0], pixel_id0[(2 * $clog2(BLOCK_SIZE))-1:$clog2(BLOCK_SIZE)]}), 
        .rnd(3'b0), 
        .z(current_pixel_fp[precision - 1 : 0]), 
        .status(status_inst_pixel[2])
      );

   ////////////////////////////////////////////////////////////////////
    //////////////////////////// Clock Step 2 //////////////////////////
    ////////////////////////////////////////////////////////////////////
  

    // Instance of DW_fp_add for d_x
    DW_fp_add #(mantissa_bit, exponent_bit, 0)
      d_x_inst_i (
        .a(mean2D1[(2 * precision) - 1: precision]), 
        .b({!current_pixel_fp1[(2 * precision) - 1], current_pixel_fp1[(2 * precision) - 2 : precision]}), 
        .rnd(3'b0), 
        .z(d_temp[(2 * precision) - 1: precision]), 
        .status(status_inst[1])
      );

    // Instance of DW_fp_add for d_y
    DW_fp_add #(mantissa_bit, exponent_bit, 0)
      d_y_inst_i (
        .a(mean2D1[precision - 1 : 0]), 
        .b({!current_pixel_fp1[precision - 1], current_pixel_fp1[precision - 2 : 0]}), 
        .rnd(3'b0), 
        .z(d_temp[precision - 1 : 0]), 
        .status(status_inst[2])
      );

    ////////////////////////////////////////////////////////////////////
    //////////////////////////// Clock Step 3 //////////////////////////
    ////////////////////////////////////////////////////////////////////

    // Instance of DW_fp_mult for dxx
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
      dxx_inst_i (
        .a(d2[(2 * precision) - 1: precision]), 
        .b(d2[(2 * precision) - 1: precision]), 
        .rnd(3'b0), 
        .z(dxx_temp), 
        .status(status_inst[3])
      );

    // Instance of DW_fp_mult for dyy
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
      dyy_inst_i (
        .a(d2[precision - 1 : 0]), 
        .b(d2[precision - 1 : 0]), 
        .rnd(3'b0), 
        .z(dyy_temp), 
        .status(status_inst[4])
      );

    // Instance of DW_fp_mult for dxy
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
      dxy_inst_i (
        .a(d2[(2 * precision) - 1: precision]), 
        .b(d2[precision - 1 : 0]), 
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
        .b(conic_opacity3[(4 * precision) - 1 : (3 * precision)]), 
        .rnd(3'b0), 
        .z(temp1), 
        .status(status_inst[6])
      );

    // Instance of DW_fp_mult for t2
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
      t2_inst_i (
        .a(dyy3), 
        .b(conic_opacity3[(2 * precision) - 1 : precision]), 
        .rnd(3'b0), 
        .z(temp2), 
        .status(status_inst[7])
      );

    // Instance of DW_fp_mult for t3
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
      t3_inst_i (
        .a(dxy3), 
        .b(conic_opacity3[(3 * precision) - 1 : 2 * precision]), 
        .rnd(3'b0), 
        .z(temp3), 
        .status(status_inst[8])
      );


        ////////////////////////////////////////////////////////////////////
        //////////////////////////// Clock Step 4 //////////////////////////
        ////////////////////////////////////////////////////////////////////
    // Instance of DW_fp_sum3 for power_maker
    DW_fp_sum3 #(mantissa_bit, exponent_bit, ieee_compliance, 0)
      power_maker_inst_i (
        .a({!exp_temp1[precision - 1], exp_temp1[precision - 2 : mantissa_bit] - 8'd1, exp_temp1[mantissa_bit - 1 : 0]}), 
        .b({!exp_temp2[precision - 1], exp_temp2[precision - 2 : mantissa_bit] - 8'd1, exp_temp2[mantissa_bit - 1 : 0]}), 
        .c({!exp_temp3[precision - 1], exp_temp3[precision - 2 : 0]}), 
        .rnd(3'b0), 
        .z(power_temp), 
        .status(status_inst[9])
      );

    ////////////////////////////////////////////////////////////////////
    //////////////////////////// Clock Step 5 //////////////////////////
    ////////////////////////////////////////////////////////////////////

    // Instance of DW_fp_exp for exponent_power
    DW_fp_exp #(mantissa_bit, exponent_bit, 1, 0)
      exponent_power_inst_i (
        .a(power5), 
        .z(G_temp), 
        .status(status_inst[10])
      );

    ////////////////////////////////////////////////////////////////////
    //////////////////////////// Clock Step 6 //////////////////////////
    ////////////////////////////////////////////////////////////////////

    // Instance of DW_fp_mult for alpha_temp_maker
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
      alpha_temp_maker_inst_i (
        .a(G6), 
        .b(conic_opacity6[precision - 1 : 0]), 
        .rnd(3'b0), 
        .z(alpha_temp1), 
        .status(status_inst[11])
      );

    ////////////////////////////////////////////////////////////////////
    /////////////////////////// Clock Step 6 ///////////////////////////
    ////////////////////////////////////////////////////////////////////

    // Instance of DW_fp_cmp for alpha_comp
    DW_fp_cmp #(mantissa_bit, exponent_bit, 0)
      alpha_comp_inst_i (
        .a(alpha7), 
        .b(max_alpha), 
        .zctr(1'b0), 
        .aeqb(aeqb_inst1), 
        .altb(altb_inst), 
        .agtb(agtb_inst1), 
        .unordered(unordered_inst1), 
        .z0(alpha_temp), 
        .z1(not_used_alpha1), 
        .status0(status_flag_0), 
        .status1(status_flag_1)
      );

    // Instance of DW_fp_cmp for alpha_skip_comp
    DW_fp_cmp #(mantissa_bit, exponent_bit, 0)
      alpha_skip_comp_inst_i (
        .a(alpha_temp), 
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

    assign skip_temp1 = !power5[precision - 1];
    assign skip_temp2 = (skip_from_alpha || skip7);

    ////////////////////////////////////////////////////////////////////
    //////////////////////// Clock Step 7 (Out) ////////////////////////
    ////////////////////////////////////////////////////////////////////

    // Capture before out 
    always_ff @ (posedge clk) begin
        if (!rst_n || start) begin

          if (!rst_n) begin
            block_id0 <= 'h0;
            pixel_id0 <= 'h0;
            start1 <= 1'b0;
          end
          else begin
            block_id0 <= block_id;
            pixel_id0 <= pixel_id;
            start1 <= start;
          end

            
            skip6 <= 'b0;
            skip7 <= 'b0;
            skip_out <= 'b0;

            G_out <= 'h0;
            G6 <= 'h0;
            G7 <= 'h0;

            d_out <= 'h0;
            d2 <= 'h0;
            d3 <= 'h0;
            d4 <= 'h0;
            d5 <= 'h0;
            d6 <= 'h0;
            d7 <= 'h0;
            alpha_out <= 'h0;

            dxx3 <= 'h0;
            dxy3 <= 'h0;
            dyy3 <= 'h0;

            power5 <= {1'b1, {(precision-1){1'b0}}};

            i_valid0 <= 'b0;
            i_valid1 <= 'b0;
            i_valid2 <= 'b0;
            i_valid3 <= 'b0;
            i_valid4 <= 'b0;
            i_valid5 <= 'b0;
            i_valid6 <= 'b0;
            i_valid7 <= 'b0;

            skip_and_alpha_done_out <= 'b0;

            mean2D0 <= 'h0;
            mean2D1 <= 'h0;

            conic_opacity0 <= 'h0;
            conic_opacity1 <= 'h0;
            conic_opacity2 <= 'h0;
            conic_opacity3 <= 'h0;
            conic_opacity4 <= 'h0;
            conic_opacity5 <= 'h0;
            conic_opacity6 <= 'h0;
            conic_opacity7 <= 'h0;
            conic_opacity_out <= 'h0;


            alpha7 <= 'h0;
            // early_skip <= 'b0;

            gaussian_id0 <= 'h0;
            gaussian_id1 <= 'h0;
            gaussian_id2 <= 'h0;
            gaussian_id3 <= 'h0;
            gaussian_id4 <= 'h0;
            gaussian_id5 <= 'h0;
            gaussian_id6 <= 'h0;
            gaussian_id7 <= 'h0;
            gaussian_id_out <= 'h0;

            gaussian_color0 <= 'h0;
            gaussian_color1 <= 'h0;
            gaussian_color2 <= 'h0;
            gaussian_color3 <= 'h0;
            gaussian_color4 <= 'h0;
            gaussian_color5 <= 'h0;
            gaussian_color6 <= 'h0;
            gaussian_color7 <= 'h0;
            gaussian_color_out <= 'h0;
            
            gaussian_depth0 <= 'h0;
            gaussian_depth1 <= 'h0;
            gaussian_depth2 <= 'h0;
            gaussian_depth3 <= 'h0;
            gaussian_depth4 <= 'h0;
            gaussian_depth5 <= 'h0;
            gaussian_depth6 <= 'h0;
            gaussian_depth7 <= 'h0;
            gaussian_depth_out <= 'h0;

            last_input0 <= 'b0;
            last_input1 <= 'b0;
            last_input2 <= 'b0;
            last_input3 <= 'b0;
            last_input4 <= 'b0;
            last_input5 <= 'b0;
            last_input6 <= 'b0;
            last_input7 <= 'b0;
            last_input_done <= 'b0;

            exp_temp1 <= 'h0;
            exp_temp2 <= 'h0;
            exp_temp3 <= 'h0;

        end


        else begin

            start1 <= start;

            if (start1) begin
              current_pixel_fp1 <= current_pixel_fp;
            end
              

            if (!stall) begin


                ////////////////////////////////////////////////////////////////////
                ///////////////////////// Clock 1 Data Input ///////////////////////
                ////////////////////////////////////////////////////////////////////

                i_valid0 <= i_valid;
                mean2D0 <= mean2D;
                conic_opacity0 <= conic_opacity;
                // pixel_id0 <= pixel_id;

                gaussian_id0 <= gaussian_id_in;
                gaussian_color0 <= gaussian_color_in;
                gaussian_depth0 <= gaussian_depth_in;
                last_input0 <= last_input;
                ////////////////////////////////////////////////////////////////////
                ///////////////////////// Clock 2 Data Flow ///////////////////////
                ////////////////////////////////////////////////////////////////////

                i_valid1 <= i_valid0;
                conic_opacity1 <= conic_opacity0;
                gaussian_id1 <= gaussian_id0;
                mean2D1 <= mean2D0;
                // gaussian_id1 <= gaussian_id0;
                gaussian_color1 <= gaussian_color0;
                gaussian_depth1 <= gaussian_depth0;
                last_input1 <= last_input0;

                ////////////////////////////////////////////////////////////////////
                ///////////////////////// Clock 3 Data Flow ///////////////////////
                ////////////////////////////////////////////////////////////////////

                i_valid2 <= i_valid1;
                conic_opacity2 <= conic_opacity1;
                d2 <= d_temp;
                gaussian_id2 <= gaussian_id1;

                // gaussian_id2 <= gaussian_id1;
                gaussian_color2 <= gaussian_color1;
                gaussian_depth2 <= gaussian_depth1;
                last_input2 <= last_input1;
                ////////////////////////////////////////////////////////////////////
                ///////////////////////// Clock 4 Data Flow ///////////////////////
                ////////////////////////////////////////////////////////////////////

                i_valid3 <= i_valid2;
                conic_opacity3 <= conic_opacity2;
                d3 <= d2;  

                dxx3 <= dxx_temp;
                dxy3 <= dxy_temp;
                dyy3 <= dyy_temp;

                gaussian_id3 <= gaussian_id2;

                // gaussian_id3 <= gaussian_id2;
                gaussian_color3 <= gaussian_color2;
                gaussian_depth3 <= gaussian_depth2;
                last_input3 <= last_input2;

                ////////////////////////////////////////////////////////////////////
                ///////////////////////// Clock 5 Data Flow ///////////////////////
                ////////////////////////////////////////////////////////////////////

                i_valid4 <= i_valid3;
                conic_opacity4 <= conic_opacity3;
                d4 <= d3;

                // early_skip <= early_skip_temp;
                gaussian_id4 <= gaussian_id3;

                // gaussian_id4 <= gaussian_id3
                gaussian_color4 <= gaussian_color3;
                gaussian_depth4 <= gaussian_depth3;
                last_input4 <= last_input3;

                exp_temp1 <= temp1;
                exp_temp2 <= temp2;
                exp_temp3 <= temp3;

                ////////////////////////////////////////////////////////////////////
                ///////////////////////// Clock 6 Data Flow ///////////////////////
                ////////////////////////////////////////////////////////////////////

                i_valid5 <= i_valid4;
                conic_opacity5 <= conic_opacity4;
                d5 <= d4;
                

                gaussian_id5 <= gaussian_id4;
                gaussian_color5 <= gaussian_color4;
                gaussian_depth5 <= gaussian_depth4;
                last_input5 <= last_input4;

                power5 <= power_temp;

                ////////////////////////////////////////////////////////////////////
                /////////////////// Clock 7 & Final Out Data Flow //////////////////
                ////////////////////////////////////////////////////////////////////           


                i_valid6 <= i_valid5;
                skip6 <= skip_temp1;

                conic_opacity6 <= conic_opacity5;
                d6 <= d5;
                G6 <= G_temp;

                gaussian_id6 <= gaussian_id5;
                gaussian_color6 <= gaussian_color5;
                gaussian_depth6 <= gaussian_depth5;
                last_input6 <= last_input5;

                ////////////////////////////////////////////////////////////////////
                /////////////////// Clock 7 & Final Out Data Flow //////////////////
                ////////////////////////////////////////////////////////////////////           

                i_valid7 <= i_valid6;

                conic_opacity7 <= conic_opacity6;
                d7 <= d6;
                G7 <= G6;
                alpha7 <= alpha_temp1;

                skip7 <= skip6;

                gaussian_id7 <= gaussian_id6;
                gaussian_color7 <= gaussian_color6;
                gaussian_depth7 <= gaussian_depth6;
                last_input7 <= last_input6;


                ////////////////////////////////////////////////////////////////////
                /////////////////// Clock 7 & Final Out Data Flow //////////////////
                ////////////////////////////////////////////////////////////////////                 

                skip_and_alpha_done_out <= i_valid7;
                conic_opacity_out <= conic_opacity7;
                d_out <= d7;
                G_out <= G7;
                skip_out <= skip7;
                alpha_out <= alpha7;
                gaussian_id_out <= gaussian_id7;
                gaussian_color_out <= gaussian_color7;
                gaussian_depth_out <= gaussian_depth7;

                last_input_done <= last_input7;

            end

            else begin // stall == 1'b1
                if (ready_from_arbiter && skip_and_alpha_done_out) begin
                    skip_and_alpha_done_out <= 1'b0;
                end
            end
        end
        
    end
endmodule