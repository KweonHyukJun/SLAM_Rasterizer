module Backward_skip_unit
    #(
        parameter BLOCK_SIZE = 16,
        parameter exponent_bit = 8,
        parameter mantissa_bit = 7,
        parameter precision = 16,
        parameter gaussian_inputs = 4,
        parameter GID_bit = 24
    )
    (
    input logic clk,
    input logic rst_n,

    input logic start,
    input logic [15:0] block_id, // block id | X | Y |

    input logic [( 2 * precision ) - 1 : 0] mean2D [gaussian_inputs-1:0], // fp32 | X | Y | 
    input logic [(4 * precision) - 1:0] conic_opacity [gaussian_inputs-1:0], // fp32 | X | Y | Z | W |
    input logic [(2 * $clog2(BLOCK_SIZE) - 1): 0] pixel_id, // int 0 ~ 255 

    input logic [GID_bit-1:0] gaussian_id_in [gaussian_inputs-1:0], // gaussian id

    input logic [precision -1 :0] gaussian_depth_in [gaussian_inputs-1:0], // gaussian depth
    input logic [(3 * precision) - 1:0] gaussian_color_in [gaussian_inputs-1:0], // gaussian color
 
    input logic i_valid [gaussian_inputs-1:0],

    input logic stall, // wire

    input logic grant_from_arbiter [gaussian_inputs-1:0],

    input logic last_input [gaussian_inputs-1:0],
    

    output logic skip_out [gaussian_inputs-1:0], // can be work as valid
    output logic [precision - 1 : 0] G_out [gaussian_inputs-1:0],
    output logic [( 2 * precision ) - 1 : 0] d_out [gaussian_inputs-1:0],
    output logic [precision - 1 : 0] alpha_out [gaussian_inputs-1:0],
    output logic [(4 * precision) - 1:0] conic_opacity_out [gaussian_inputs-1:0], // fp32 | X | Y | Z | W |

    output logic [GID_bit-1:0] gaussian_id_out [gaussian_inputs-1:0],
    output logic [(3*precision) - 1:0] gaussian_color_out [gaussian_inputs-1:0],
    output logic [precision - 1:0] gaussian_depth_out [gaussian_inputs-1:0],

    output logic skip_and_alpha_done_out [gaussian_inputs-1:0],

    output logic last_input_done [gaussian_inputs-1:0]
    );
    // synopsys template
    
    localparam ieee_compliance = 1'b0;
    // localparam [2:0] inst_rnd [1:12] = {3'b0, 3'b0, 3'b0, 3'b0, 3'b0, 3'b0, 3'b0, 3'b0, 3'b0, 3'b0, 3'b0, 3'b0};


    /////////////////////////////////////////
    /////////// register declaration ////////
    /////////////////////////////////////////

    logic [( 2 * precision ) - 1 : 0] d2 [gaussian_inputs-1:0], d3 [gaussian_inputs-1:0], d4 [gaussian_inputs-1:0], d5 [gaussian_inputs-1:0], d6 [gaussian_inputs-1:0], d7 [gaussian_inputs-1:0];
    logic [precision - 1 : 0] G5 [gaussian_inputs-1:0], G6 [gaussian_inputs-1:0] , G7 [gaussian_inputs-1:0];
    logic [precision - 1 : 0] dxx3 [gaussian_inputs-1:0], dxy3 [gaussian_inputs-1:0], dyy3 [gaussian_inputs-1:0];
    logic skip6 [gaussian_inputs-1:0], skip7 [gaussian_inputs-1:0];

    logic i_valid0 [gaussian_inputs-1:0], i_valid1 [gaussian_inputs-1:0], i_valid2 [gaussian_inputs-1:0], i_valid3 [gaussian_inputs-1:0], i_valid4 [gaussian_inputs-1:0], i_valid5 [gaussian_inputs-1:0], i_valid6 [gaussian_inputs-1:0], i_valid7 [gaussian_inputs-1:0];
    logic [( 2 * precision ) - 1 : 0] mean2D0 [gaussian_inputs-1:0] , mean2D1 [gaussian_inputs-1:0];
    logic [( 4 * precision ) - 1 : 0] conic_opacity0 [gaussian_inputs-1:0], conic_opacity1 [gaussian_inputs-1:0], conic_opacity2 [gaussian_inputs-1:0], conic_opacity3 [gaussian_inputs-1:0], conic_opacity4 [gaussian_inputs-1:0], conic_opacity5 [gaussian_inputs-1:0], conic_opacity6 [gaussian_inputs-1:0], conic_opacity7 [gaussian_inputs-1:0];
    logic [(2 * $clog2(BLOCK_SIZE) - 1): 0] pixel_id0;
    logic [precision - 1 : 0] power5 [gaussian_inputs-1:0];
    logic [precision - 1 : 0] alpha7 [gaussian_inputs-1:0];
    logic [15:0] block_id0;

    logic [GID_bit-1:0] gaussian_id0 [gaussian_inputs-1:0], gaussian_id1 [gaussian_inputs-1:0], gaussian_id2 [gaussian_inputs-1:0], gaussian_id3 [gaussian_inputs-1:0], gaussian_id4 [gaussian_inputs-1:0], gaussian_id5 [gaussian_inputs-1:0], gaussian_id6 [gaussian_inputs-1:0], gaussian_id7 [gaussian_inputs-1:0];
    logic [(3 * precision) - 1:0] gaussian_color0 [gaussian_inputs-1:0], gaussian_color1 [gaussian_inputs-1:0], gaussian_color2 [gaussian_inputs-1:0], gaussian_color3 [gaussian_inputs-1:0], gaussian_color4 [gaussian_inputs-1:0], gaussian_color5 [gaussian_inputs-1:0], gaussian_color6 [gaussian_inputs-1:0], gaussian_color7 [gaussian_inputs-1:0];
    logic [precision - 1:0] gaussian_depth0 [gaussian_inputs-1:0], gaussian_depth1 [gaussian_inputs-1:0], gaussian_depth2 [gaussian_inputs-1:0], gaussian_depth3 [gaussian_inputs-1:0], gaussian_depth4 [gaussian_inputs-1:0], gaussian_depth5 [gaussian_inputs-1:0], gaussian_depth6 [gaussian_inputs-1:0], gaussian_depth7 [gaussian_inputs-1:0];

    logic last_input0 [gaussian_inputs-1:0], last_input1 [gaussian_inputs-1:0], last_input2 [gaussian_inputs-1:0], last_input3 [gaussian_inputs-1:0], last_input4 [gaussian_inputs-1:0], last_input5 [gaussian_inputs-1:0], last_input6 [gaussian_inputs-1:0], last_input7 [gaussian_inputs-1:0];
    logic [( 2 * precision ) - 1 : 0] current_pixel_fp1;
    logic start1;


    /////////////////////////////////////////
    ///////////// wire declaration //////////
    /////////////////////////////////////////
    logic [( 2 * precision ) - 1 : 0] d_temp [gaussian_inputs-1:0]; // fp32 (int32 calculations needed) | X | Y |
    logic [precision - 1 : 0] power_temp [gaussian_inputs-1:0];
    
    logic skip_temp1 [gaussian_inputs-1:0], skip_temp2 [gaussian_inputs-1:0];
    // logic [(2 * precision) - 1 : 0] current_pixel [gaussian_inputs-1:0];
    logic [precision - 1 : 0] temp1 [gaussian_inputs-1:0], temp2 [gaussian_inputs-1:0], temp3 [gaussian_inputs-1:0];
    logic [precision - 1 : 0] exp_temp1 [gaussian_inputs-1:0], exp_temp2 [gaussian_inputs-1:0], exp_temp3 [gaussian_inputs-1:0];
    // logic [( 2 * precision ) - 1 : 0] current_pixel_fp [gaussian_inputs-1:0];
    logic [( 2 * precision ) - 1 : 0] current_pixel_fp;
    
    logic [precision - 1 : 0] dxx_temp [gaussian_inputs-1:0], dyy_temp [gaussian_inputs-1:0], dxy_temp [gaussian_inputs-1:0];
    logic [precision - 1 : 0] max_alpha; // 0.99 in fp32
    logic [precision - 1 : 0] min_alpha; // 1/255 in fp32
    logic [precision - 1 : 0] One;

    logic [precision - 1 : 0] alpha_temp1 [gaussian_inputs-1:0], alpha_temp2 [gaussian_inputs-1:0];

    logic aeqb_inst1[gaussian_inputs-1:0], aeqb_inst2[gaussian_inputs-1:0], altb_inst[gaussian_inputs-1:0] , agtb_inst1[gaussian_inputs-1:0] , agtb_inst2[gaussian_inputs-1:0],  unordered_inst1[gaussian_inputs-1:0] , unordered_inst2[gaussian_inputs-1:0];

    logic [precision - 1 : 0] not_used_alpha1 [gaussian_inputs-1:0],  not_used_alpha2 [gaussian_inputs-1:0], not_used_alpha3 [gaussian_inputs-1:0];
    logic [7:0] status_flag_0 [gaussian_inputs-1:0], status_flag_1 [gaussian_inputs-1:0], status_flag_2 [gaussian_inputs-1:0], status_flag_3 [gaussian_inputs-1:0];

    logic [7:0] status_inst [gaussian_inputs-1:0][1:11];
    logic [7:0] status_inst_pixel [1:2];
    // logic [7:0] status_inst_pixel [gaussian_inputs-1:0][1:2];


    logic skip_from_alpha [gaussian_inputs-1:0];
    logic [precision - 1 : 0] G_temp [gaussian_inputs-1:0];

    logic [precision - 1: 0] power_th;
    // logic early_skip_temp [gaussian_inputs-1:0];
    logic [precision - 1: 0] not_used_power1[gaussian_inputs-1:0], not_used_power2 [gaussian_inputs-1:0];

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

    
    // 가를거면 이거 갈라야함

    genvar i;

    generate
      for (i = 0; i < gaussian_inputs; i = i + 1) begin : inputs_dimension

        // Instance of DW_fp_add for d_x
        DW_fp_add #(mantissa_bit, exponent_bit, 0)
          d_x_inst_i (
            .a(mean2D1[i][(2 * precision) - 1: precision]), 
            .b({!current_pixel_fp1[(2 * precision) - 1], current_pixel_fp1[(2 * precision) - 2 : precision]}), 
            .rnd(3'b0), 
            .z(d_temp[i][(2 * precision) - 1: precision]), 
            .status(status_inst[i][1])
          );

        // Instance of DW_fp_add for d_y
        DW_fp_add #(mantissa_bit, exponent_bit, 0)
          d_y_inst_i (
            .a(mean2D1[i][precision - 1 : 0]), 
            .b({!current_pixel_fp1[precision - 1], current_pixel_fp1[precision - 2 : 0]}), 
            .rnd(3'b0), 
            .z(d_temp[i][precision - 1 : 0]), 
            .status(status_inst[i][2])
          );

        ////////////////////////////////////////////////////////////////////
        //////////////////////////// Clock Step 2 //////////////////////////
        ////////////////////////////////////////////////////////////////////

        // Instance of DW_fp_mult for dxx
        DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
          dxx_inst_i (
            .a(d2[i][(2 * precision) - 1: precision]), 
            .b(d2[i][(2 * precision) - 1: precision]), 
            .rnd(3'b0), 
            .z(dxx_temp[i]), 
            .status(status_inst[i][3])
          );

        // Instance of DW_fp_mult for dyy
        DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
          dyy_inst_i (
            .a(d2[i][precision - 1 : 0]), 
            .b(d2[i][precision - 1 : 0]), 
            .rnd(3'b0), 
            .z(dyy_temp[i]), 
            .status(status_inst[i][4])
          );

        // Instance of DW_fp_mult for dxy
        DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
          dxy_inst_i (
            .a(d2[i][(2 * precision) - 1: precision]), 
            .b(d2[i][precision - 1 : 0]), 
            .rnd(3'b0), 
            .z(dxy_temp[i]), 
            .status(status_inst[i][5])
          );

        ////////////////////////////////////////////////////////////////////
        //////////////////////////// Clock Step 3 //////////////////////////
        ////////////////////////////////////////////////////////////////////

        // Instance of DW_fp_mult for t1
        DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
          t1_inst_i (
            .a(dxx3[i]), 
            .b(conic_opacity3[i][(4 * precision) - 1 : (3 * precision)]), 
            .rnd(3'b0), 
            .z(temp1[i]), 
            .status(status_inst[i][6])
          );

        // Instance of DW_fp_mult for t2
        DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
          t2_inst_i (
            .a(dyy3[i]), 
            .b(conic_opacity3[i][(2 * precision) - 1 : precision]), 
            .rnd(3'b0), 
            .z(temp2[i]), 
            .status(status_inst[i][7])
          );

        // Instance of DW_fp_mult for t3
        DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
          t3_inst_i (
            .a(dxy3[i]), 
            .b(conic_opacity3[i][(3 * precision) - 1 : 2 * precision]), 
            .rnd(3'b0), 
            .z(temp3[i]), 
            .status(status_inst[i][8])
          );



        ////////////////////////////////////////////////////////////////////
        //////////////////////////// Clock Step 4 //////////////////////////
        ////////////////////////////////////////////////////////////////////



        // Instance of DW_fp_sum3 for power_maker
        DW_fp_sum3 #(mantissa_bit, exponent_bit, ieee_compliance, 0)
          power_maker_inst_i (
            .a({!exp_temp1[i][precision - 1], exp_temp1[i][precision - 2 : mantissa_bit] - 8'd1, exp_temp1[i][mantissa_bit - 1 : 0]}), 
            .b({!exp_temp2[i][precision - 1], exp_temp2[i][precision - 2 : mantissa_bit] - 8'd1, exp_temp2[i][mantissa_bit - 1 : 0]}), 
            .c({!exp_temp3[i][precision - 1], exp_temp3[i][precision - 2 : 0]}), 
            .rnd(3'b0), 
            .z(power_temp[i]), 
            .status(status_inst[i][9])
          );

        ////////////////////////////////////////////////////////////////////
        //////////////////////////// Clock Step 5 //////////////////////////
        ////////////////////////////////////////////////////////////////////

        // Instance of DW_fp_exp for exponent_power
        DW_fp_exp #(mantissa_bit, exponent_bit, 1, 0)
          exponent_power_inst_i (
            .a(power5[i]), 
            .z(G_temp[i]), 
            .status(status_inst[i][10])
          );

        ////////////////////////////////////////////////////////////////////
        //////////////////////////// Clock Step 6 //////////////////////////
        ////////////////////////////////////////////////////////////////////

        // Instance of DW_fp_mult for alpha_temp_maker
        DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
          alpha_temp_maker_inst_i (
            .a(G6[i]), 
            .b(conic_opacity6[i][precision - 1 : 0]), 
            .rnd(3'b0), 
            .z(alpha_temp1[i]), 
            .status(status_inst[i][11])
          );

        ////////////////////////////////////////////////////////////////////
        /////////////////////////// Clock Step 7 ///////////////////////////
        ////////////////////////////////////////////////////////////////////

        // Instance of DW_fp_cmp for alpha_comp
        DW_fp_cmp #(mantissa_bit, exponent_bit, 0)
          alpha_comp_inst_i (
            .a(alpha7[i]), 
            .b(max_alpha), 
            .zctr(1'b0), 
            .aeqb(aeqb_inst1[i]), 
            .altb(altb_inst[i]), 
            .agtb(agtb_inst1[i]), 
            .unordered(unordered_inst1[i]), 
            .z0(alpha_temp2[i]), 
            .z1(not_used_alpha1[i]), 
            .status0(status_flag_0[i]), 
            .status1(status_flag_1[i])
          );

        // Instance of DW_fp_cmp for alpha_skip_comp
        DW_fp_cmp #(mantissa_bit, exponent_bit, 0)
          alpha_skip_comp_inst_i (
            .a(alpha_temp2[i]), 
            .b(min_alpha), 
            .zctr(1'b0), 
            .aeqb(aeqb_inst2[i]), 
            .altb(skip_from_alpha[i]), 
            .agtb(agtb_inst2[i]), 
            .unordered(unordered_inst2[i]), 
            .z0(not_used_alpha2[i]), 
            .z1(not_used_alpha3[i]), 
            .status0(status_flag_2[i]), 
            .status1(status_flag_3[i])
          );

    assign skip_temp1[i] = !power5[i][precision - 1];
    assign skip_temp2[i] = (skip_from_alpha[i] || skip7[i]);

      end
    endgenerate

    ////////////////////////////////////////////////////////////////////
    //////////////////////// Clock Step 7 (Out) ////////////////////////
    ////////////////////////////////////////////////////////////////////

    // Capture before out 
    always_ff @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin

            block_id0 <= 'h0;
            pixel_id0 <= 'h0;
            current_pixel_fp1 <= 'h0;

            start1 <= 'b0;
            
            for (int j = 0; j < gaussian_inputs; j = j + 1) begin


              skip6[j] <= 'b0;
              skip7[j] <= 'b0;
              skip_out[j] <= 'b0;

              

              G_out[j] <= 'h0;
              G6[j] <= 'h0;
              G7[j] <= 'h0;

              d_out[j] <= 'h0;
              
              d2[j] <= 'h0;
              d3[j] <= 'h0;
              d4[j] <= 'h0;
              d5[j] <= 'h0;
              d6[j] <= 'h0;
              d7[j] <= 'h0;
              alpha_out[j] <= 'h0;

              dxx3[j] <= 'h0;
              dxy3[j] <= 'h0;
              dyy3[j] <= 'h0;

              power5[j] <= {1'b1, {(precision-1){1'b0}}};

              i_valid0[j] <= 'b0;
              i_valid1[j] <= 'b0;
              i_valid2[j] <= 'b0;
              i_valid3[j] <= 'b0;
              i_valid4[j] <= 'b0;
              i_valid5[j] <= 'b0;
              i_valid6[j] <= 'b0;
              i_valid7[j] <= 'b0;

              skip_and_alpha_done_out[j] <= 'b0;

              mean2D0[j] <= 'h0;
              mean2D1[j] <= 'h0;
              conic_opacity0[j] <= 'h0;
              conic_opacity1[j] <= 'h0;
              conic_opacity2[j] <= 'h0;
              conic_opacity3[j] <= 'h0;
              conic_opacity4[j] <= 'h0;
              conic_opacity5[j] <= 'h0;
              conic_opacity6[j] <= 'h0;
              conic_opacity7[j] <= 'h0;

              conic_opacity_out[j] <= 'h0;

              alpha7[j] <= 'h0;
              // early_skip[j] <= 'b0;

              gaussian_id0[j] <= 'h0;
              gaussian_id1[j] <= 'h0;
              gaussian_id2[j] <= 'h0;
              gaussian_id3[j] <= 'h0;
              gaussian_id4[j] <= 'h0;
              gaussian_id5[j] <= 'h0;
              gaussian_id6[j] <= 'h0;
              gaussian_id7[j] <= 'h0;

              gaussian_id_out[j] <= 'h0;

              gaussian_color0[j] <= 'h0;
              gaussian_color1[j] <= 'h0;
              gaussian_color2[j] <= 'h0;
              gaussian_color3[j] <= 'h0;
              gaussian_color4[j] <= 'h0;
              gaussian_color5[j] <= 'h0;
              gaussian_color6[j] <= 'h0;
              gaussian_color7[j] <= 'h0;
              gaussian_color_out[j] <= 'h0;
              
              gaussian_depth0[j] <= 'h0;
              gaussian_depth1[j] <= 'h0;
              gaussian_depth2[j] <= 'h0;
              gaussian_depth3[j] <= 'h0;
              gaussian_depth4[j] <= 'h0;
              gaussian_depth5[j] <= 'h0;
              gaussian_depth6[j] <= 'h0;
              gaussian_depth7[j] <= 'h0;
              gaussian_depth_out[j] <= 'h0;

              last_input0[j] <= 'b0;
              last_input1[j] <= 'b0;
              last_input2[j] <= 'b0;
              last_input3[j] <= 'b0;
              last_input4[j] <= 'b0;
              last_input5[j] <= 'b0;
              last_input6[j] <= 'b0;
              last_input7[j] <= 'b0;
              last_input_done[j] <= 'b0;

              exp_temp1[j] <= 'h0;
              exp_temp2[j] <= 'h0;
              exp_temp3[j] <= 'h0;

    

            end
        end


        else begin
            start1 <= start;

            if (start1) begin
              current_pixel_fp1 <= current_pixel_fp;
            end

            
            if (start) begin
              block_id0 <= block_id;
              pixel_id0 <= pixel_id;
            end
            
            // if (start1) begin
            //   current_pixel_fp1 <= current_pixel_fp;
            // end
              

            // if (!stall) begin
            if (!stall) begin

                // if (start) begin
                //   block_id0 <= block_id;
                //   pixel_id0 <= pixel_id;
                // end
                
                // if (start1) begin
                //   current_pixel_fp1 <= current_pixel_fp;
                // end


                // start1 <= start;

                for (int j = 0; j < gaussian_inputs; j = j + 1) begin
                  ////////////////////////////////////////////////////////////////////
                  ///////////////////////// Clock 1 Data Input ///////////////////////
                  ////////////////////////////////////////////////////////////////////

                  

                  i_valid0[j] <= i_valid[j];
                  mean2D0[j] <= mean2D[j];
                  conic_opacity0[j] <= conic_opacity[j];
                  // pixel_id0[j] <= pixel_id[j];

                  gaussian_id0[j] <= gaussian_id_in[j];
                  gaussian_color0[j] <= gaussian_color_in[j];
                  gaussian_depth0[j] <= gaussian_depth_in[j];
                  last_input0[j] <= last_input[j];

                  ////////////////////////////////////////////////////////////////////
                  ///////////////////////// Clock 2 Data Flow ///////////////////////
                  ////////////////////////////////////////////////////////////////////

                  mean2D1[j] <= mean2D0[j];

                  i_valid1[j] <= i_valid0[j];
                  conic_opacity1[j] <= conic_opacity0[j];
                  
                  gaussian_id1[j] <= gaussian_id0[j];

                  // gaussian_id1[j] <= gaussian_id0[j];
                  gaussian_color1[j] <= gaussian_color0[j];
                  gaussian_depth1[j] <= gaussian_depth0[j];
                  last_input1[j] <= last_input0[j];

                  ////////////////////////////////////////////////////////////////////
                  ///////////////////////// Clock 3 Data Flow ///////////////////////
                  ////////////////////////////////////////////////////////////////////

                  i_valid2[j] <= i_valid1[j];
                  conic_opacity2[j] <= conic_opacity1[j];

                  d2[j] <= d_temp[j];
                  gaussian_id2[j] <= gaussian_id1[j];

                  // gaussian_id2[j] <= gaussian_id1[j];
                  gaussian_color2[j] <= gaussian_color1[j];
                  gaussian_depth2[j] <= gaussian_depth1[j];
                  last_input2[j] <= last_input1[j];

                  ////////////////////////////////////////////////////////////////////
                  ///////////////////////// Clock 4 Data Flow ///////////////////////
                  ////////////////////////////////////////////////////////////////////

                  i_valid3[j] <= i_valid2[j];
                  conic_opacity3[j] <= conic_opacity2[j];
                  d3[j] <= d2[j];

                  dxx3[j] <= dxx_temp[j];
                  dxy3[j] <= dxy_temp[j];
                  dyy3[j] <= dyy_temp[j];
                  
                  
                  gaussian_id3[j] <= gaussian_id2[j];

                  // gaussian_id3[j] <= gaussian_id2[j];
                  gaussian_color3[j] <= gaussian_color2[j];
                  gaussian_depth3[j] <= gaussian_depth2[j];
                  last_input3[j] <= last_input2[j];


                  ////////////////////////////////////////////////////////////////////
                  ///////////////////////// Clock 5 Data Flow ///////////////////////
                  ////////////////////////////////////////////////////////////////////



                  i_valid4[j] <= i_valid3[j];
                  conic_opacity4[j] <= conic_opacity3[j];
                  d4[j] <= d3[j];
                  
                  
                  // early_skip[j] <= early_skip_temp[j];
                  gaussian_id4[j] <= gaussian_id3[j];


                  // gaussian_id4[j] <= gaussian_id3[j]
                  gaussian_color4[j] <= gaussian_color3[j];
                  gaussian_depth4[j] <= gaussian_depth3[j];
                  last_input4[j] <= last_input3[j];

                  exp_temp1[j] <= temp1[j];
                  exp_temp2[j] <= temp2[j];
                  exp_temp3[j] <= temp3[j];




                  ////////////////////////////////////////////////////////////////////
                  ///////////////////////// Clock 6 Data Flow ///////////////////////
                  ////////////////////////////////////////////////////////////////////

                  i_valid5[j] <= i_valid4[j];
                  conic_opacity5[j] <= conic_opacity4[j];
                  d5[j] <= d4[j];
                  
                  

                  gaussian_id5[j] <= gaussian_id4[j];
                  gaussian_color5[j] <= gaussian_color4[j];
                  gaussian_depth5[j] <= gaussian_depth4[j];
                  last_input5[j] <= last_input4[j];

                  power5[j] <= power_temp[j];

                  ////////////////////////////////////////////////////////////////////
                  ///////////////////////// Clock 7 Data Flow ///////////////////////
                  ////////////////////////////////////////////////////////////////////
                  
                  i_valid6[j] <= i_valid5[j];

                  
                  skip6[j] <= skip_temp1[j];

                  conic_opacity6[j] <= conic_opacity5[j];
                  d6[j] <= d5[j];
                  G6[j] <= G_temp[j];

                  gaussian_id6[j] <= gaussian_id5[j];
                  gaussian_color6[j] <= gaussian_color5[j];
                  gaussian_depth6[j] <= gaussian_depth5[j];
                  last_input6[j] <= last_input5[j];

                  ////////////////////////////////////////////////////////////////////
                  /////////////////// Clock 8 & Final Out Data Flow //////////////////
                  ////////////////////////////////////////////////////////////////////                

                  i_valid7[j] <= i_valid6[j];
                  conic_opacity7[j] <= conic_opacity6[j];
                  d7[j] <= d6[j];
                  G7[j] <= G6[j];
                  alpha7[j] <= alpha_temp1[j];

                  skip7[j] <= skip6[j];

                  gaussian_id7[j] <= gaussian_id6[j];
                  gaussian_color7[j] <= gaussian_color6[j];
                  gaussian_depth7[j] <= gaussian_depth6[j];

                  last_input7[j] <= last_input6[j];

                  ////////////////////////////////////////////////////////////////////
                  /////////////////// Clock 8 & Final Out Data Flow //////////////////
                  ////////////////////////////////////////////////////////////////////        

                  skip_and_alpha_done_out[j] <= i_valid7[j];
                  conic_opacity_out[j] <= conic_opacity7[j];

                  d_out[j] <= d7[j];
                  G_out[j] <= G7[j];

                  skip_out[j] <= skip_temp2[j];
                  alpha_out[j] <= alpha_temp2[j];

                  gaussian_id_out[j] <= gaussian_id7[j];
                  gaussian_color_out[j] <= gaussian_color7[j];
                  gaussian_depth_out[j] <= gaussian_depth7[j];

                  last_input_done[j] <= last_input7[j];
              
                end                
            end

            else begin // stall == 1'b1
              for (int j = 0; j < gaussian_inputs; j = j + 1) begin
                  if (grant_from_arbiter[j] && skip_and_alpha_done_out[j]) begin
                      skip_and_alpha_done_out[j] <= 1'b0;
                  end
              end
            end
        end
        
    end
endmodule