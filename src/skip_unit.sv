module skip_unit
    #(
        parameter BLOCK_SIZE = 16,
        parameter exponent_bit = 8,
        parameter mantissa_bit = 23,
        parameter precision = 32,
        parameter inputs = 2
    )
    (
    input logic clk,
    input logic rst_n,

    input logic start,
    input logic [15:0] block_id, // block id | X | Y |

    input logic [( 2 * precision ) - 1 : 0] mean2D [inputs-1:0], // fp32 | X | Y | 
    input logic [(4 * precision) - 1:0] conic_opacity [inputs-1:0], // fp32 | X | Y | Z | W |
    input logic [(2 * $clog2(BLOCK_SIZE) - 1): 0] pixel_id, // int 0 ~ 255 
    input logic [31:0] gaussian_id_in [inputs-1:0], // gaussian id
 
    input logic i_valid [inputs-1:0],

    input logic stall, // wire

    input logic ready_from_arbiter [inputs-1:0],
    

    output logic skip_out [inputs-1:0], // can be work as valid
    output logic [precision - 1 : 0] G_out [inputs-1:0],
    output logic [( 2 * precision ) - 1 : 0] d_out [inputs-1:0],
    output logic [precision - 1 : 0] alpha_out [inputs-1:0],
    output logic [(4 * precision) - 1:0] conic_opacity_out [inputs-1:0], // fp32 | X | Y | Z | W |

    output logic [31:0] gaussian_id_out [inputs-1:0],

    output logic skip_and_alpha_done_out [inputs-1:0],

    output logic early_skip [inputs-1:0]

    

    );
    localparam ieee_compliance = 1'b0;
    // localparam [2:0] inst_rnd [1:12] = {3'b0, 3'b0, 3'b0, 3'b0, 3'b0, 3'b0, 3'b0, 3'b0, 3'b0, 3'b0, 3'b0, 3'b0};


    /////////////////////////////////////////
    /////////// register declaration ////////
    /////////////////////////////////////////
    integer j;

    logic [( 2 * precision ) - 1 : 0] d1 [inputs-1:0], d2 [inputs-1:0], d3 [inputs-1:0], d4 [inputs-1:0], d5 [inputs-1:0];
    logic [precision - 1 : 0] G4 [inputs-1:0], G5 [inputs-1:0];
    logic [precision - 1 : 0] dxx2 [inputs-1:0], dxy2 [inputs-1:0], dyy2 [inputs-1:0];
    logic skip3 [inputs-1:0], skip4 [inputs-1:0], skip5 [inputs-1:0];

    logic i_valid0 [inputs-1:0], i_valid1 [inputs-1:0], i_valid2 [inputs-1:0], i_valid3 [inputs-1:0], i_valid4 [inputs-1:0], i_valid5 [inputs-1:0];
    logic [( 2 * precision ) - 1 : 0] mean2D0 [inputs-1:0] ;
    logic [( 4 * precision ) - 1 : 0] conic_opacity0 [inputs-1:0], conic_opacity1 [inputs-1:0], conic_opacity2 [inputs-1:0], conic_opacity3 [inputs-1:0], conic_opacity4 [inputs-1:0], conic_opacity5 [inputs-1:0];
    logic [(2 * $clog2(BLOCK_SIZE) - 1): 0] pixel_id0;
    logic [precision - 1 : 0] power3 [inputs-1:0];
    logic [precision - 1 : 0] alpha5 [inputs-1:0];
    logic [15:0] block_id0;

    logic [31:0] gaussian_id0 [inputs-1:0], gaussian_id1 [inputs-1:0], gaussian_id2 [inputs-1:0], gaussian_id3 [inputs-1:0], gaussian_id4 [inputs-1:0], gaussian_id5 [inputs-1:0];


    /////////////////////////////////////////
    ///////////// wire declaration //////////
    /////////////////////////////////////////
    logic [( 2 * precision ) - 1 : 0] d_temp [inputs-1:0]; // fp32 (int32 calculations needed) | X | Y |
    logic [precision - 1 : 0] power_temp [inputs-1:0];
    
    logic skip_temp1 [inputs-1:0], skip_temp2 [inputs-1:0];
    logic [(2 * precision) - 1 : 0] current_pixel [inputs-1:0];
    logic [precision - 1 : 0] temp1 [inputs-1:0], temp2 [inputs-1:0], temp3 [inputs-1:0];
    logic [( 2 * precision ) - 1 : 0] current_pixel_fp [inputs-1:0];
    
    logic [precision - 1 : 0] dxx_temp [inputs-1:0], dyy_temp [inputs-1:0], dxy_temp [inputs-1:0];
    logic [precision - 1 : 0] max_alpha; // 0.99 in fp32
    logic [precision - 1 : 0] min_alpha; // 1/255 in fp32
    logic [precision - 1 : 0] One;

    logic [precision - 1 : 0] alpha_temp1 [inputs-1:0], alpha_temp [inputs-1:0];

    logic aeqb_inst1[inputs-1:0], aeqb_inst2[inputs-1:0],aeqb_inst3[inputs-1:0],  altb_inst[inputs-1:0] , agtb_inst1[inputs-1:0] , agtb_inst2[inputs-1:0] , agtb_inst3[inputs-1:0] ,  unordered_inst1[inputs-1:0] , unordered_inst2[inputs-1:0] , unordered_inst3 [inputs-1:0];

    logic [precision - 1 : 0] not_used_alpha1 [inputs-1:0],  not_used_alpha2 [inputs-1:0], not_used_alpha3 [inputs-1:0];
    logic [7:0] status_flag_0 [inputs-1:0], status_flag_1 [inputs-1:0], status_flag_2 [inputs-1:0], status_flag_3 [inputs-1:0], status_flag_4 [inputs-1:0], status_flag_5 [inputs-1:0];

    logic [7:0] status_inst [inputs-1:0][1:13];
    logic skip_from_alpha [inputs-1:0];
    logic [precision - 1 : 0] G_temp [inputs-1:0];

    logic [precision - 1: 0] power_th;
    logic early_skip_temp [inputs-1:0];
    logic [precision - 1: 0] not_used_power1[inputs-1:0], not_used_power2 [inputs-1:0];

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

    genvar i;

    generate
      for (i = 0; i < inputs; i = i + 1) begin : inputs_dimension

        // Instance of DW_fp_i2flt for pixel_x
        DW_fp_i2flt #(mantissa_bit, exponent_bit, precision, 1)
          fp_pixel_x_inst_i ( 
            .a({{(precision-11){1'b0}}, block_id0[14:8], pixel_id0[$clog2(BLOCK_SIZE)-1:0]}), 
            .rnd(3'b0), 
            .z(current_pixel_fp[i][(2 * precision) - 1: precision]), 
            .status(status_inst[i][1])
          );

        // Instance of DW_fp_i2flt for pixel_y
        DW_fp_i2flt #(mantissa_bit, exponent_bit, precision, 1)
          fp_pixel_y_inst_i ( 
            .a({{(precision-11){1'b0}}, block_id0[6:0], pixel_id0[(2 * $clog2(BLOCK_SIZE))-1:$clog2(BLOCK_SIZE)]}), 
            .rnd(3'b0), 
            .z(current_pixel_fp[i][precision - 1 : 0]), 
            .status(status_inst[i][2])
          );

        // Instance of DW_fp_add for d_x
        DW_fp_add #(mantissa_bit, exponent_bit, 0)
          d_x_inst_i (
            .a(mean2D0[i][(2 * precision) - 1: precision]), 
            .b({!current_pixel_fp[i][(2 * precision) - 1], current_pixel_fp[i][(2 * precision) - 2 : precision]}), 
            .rnd(3'b0), 
            .z(d_temp[i][(2 * precision) - 1: precision]), 
            .status(status_inst[i][3])
          );

        // Instance of DW_fp_add for d_y
        DW_fp_add #(mantissa_bit, exponent_bit, 0)
          d_y_inst_i (
            .a(mean2D0[i][precision - 1 : 0]), 
            .b({!current_pixel_fp[i][precision - 1], current_pixel_fp[i][precision - 2 : 0]}), 
            .rnd(3'b0), 
            .z(d_temp[i][precision - 1 : 0]), 
            .status(status_inst[i][4])
          );

        ////////////////////////////////////////////////////////////////////
        //////////////////////////// Clock Step 2 //////////////////////////
        ////////////////////////////////////////////////////////////////////

        // Instance of DW_fp_mult for dxx
        DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
          dxx_inst_i (
            .a(d1[i][(2 * precision) - 1: precision]), 
            .b(d1[i][(2 * precision) - 1: precision]), 
            .rnd(3'b0), 
            .z(dxx_temp[i]), 
            .status(status_inst[i][5])
          );

        // Instance of DW_fp_mult for dyy
        DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
          dyy_inst_i (
            .a(d1[i][precision - 1 : 0]), 
            .b(d1[i][precision - 1 : 0]), 
            .rnd(3'b0), 
            .z(dyy_temp[i]), 
            .status(status_inst[i][6])
          );

        // Instance of DW_fp_mult for dxy
        DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
          dxy_inst_i (
            .a(d1[i][(2 * precision) - 1: precision]), 
            .b(d1[i][precision - 1 : 0]), 
            .rnd(3'b0), 
            .z(dxy_temp[i]), 
            .status(status_inst[i][7])
          );

        ////////////////////////////////////////////////////////////////////
        //////////////////////////// Clock Step 3 //////////////////////////
        ////////////////////////////////////////////////////////////////////

        // Instance of DW_fp_mult for t1
        DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
          t1_inst_i (
            .a(dxx2[i]), 
            .b(conic_opacity2[i][(4 * precision) - 1 : (3 * precision)]), 
            .rnd(3'b0), 
            .z(temp1[i]), 
            .status(status_inst[i][8])
          );

        // Instance of DW_fp_mult for t2
        DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
          t2_inst_i (
            .a(dyy2[i]), 
            .b(conic_opacity2[i][(2 * precision) - 1 : precision]), 
            .rnd(3'b0), 
            .z(temp2[i]), 
            .status(status_inst[i][9])
          );

        // Instance of DW_fp_mult for t3
        DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
          t3_inst_i (
            .a(dxy2[i]), 
            .b(conic_opacity2[i][(3 * precision) - 1 : 2 * precision]), 
            .rnd(3'b0), 
            .z(temp3[i]), 
            .status(status_inst[i][10])
          );

        // Instance of DW_fp_sum3 for power_maker
        DW_fp_sum3 #(mantissa_bit, exponent_bit, ieee_compliance, 0)
          power_maker_inst_i (
            .a({!temp1[i][precision - 1], temp1[i][precision - 2 : mantissa_bit] - 8'b1, temp1[i][mantissa_bit - 1 : 0]}), 
            .b({!temp2[i][precision - 1], temp2[i][precision - 2 : mantissa_bit] - 8'b1, temp2[i][mantissa_bit - 1 : 0]}), 
            .c({!temp3[i][precision - 1], temp3[i][precision - 2 : 0]}), 
            .rnd(3'b0), 
            .z(power_temp[i]), 
            .status(status_inst[i][11])
          );

        ////////////////////////////////////////////////////////////////////
        //////////////////////////// Clock Step 4 //////////////////////////
        ////////////////////////////////////////////////////////////////////

        // Instance of DW_fp_cmp for early_skip_maker
        DW_fp_cmp #(mantissa_bit, exponent_bit, 0)
          early_skip_maker_inst_i (
            .a(power3[i]), 
            .b(power_th), 
            .zctr(1'b0), 
            .aeqb(aeqb_inst3[i]), 
            .altb(early_skip_temp[i]), 
            .agtb(agtb_inst3[i]), 
            .unordered(unordered_inst3[i]), 
            .z0(not_used_power1[i]), 
            .z1(not_used_power2[i]), 
            .status0(status_flag_4[i]), 
            .status1(status_flag_5[i])
          );

        // Instance of DW_fp_exp for exponent_power
        DW_fp_exp #(mantissa_bit, exponent_bit, 1, 0)
          exponent_power_inst_i (
            .a(power3[i]), 
            .z(G_temp[i]), 
            .status(status_inst[i][12])
          );

        ////////////////////////////////////////////////////////////////////
        //////////////////////////// Clock Step 5 //////////////////////////
        ////////////////////////////////////////////////////////////////////

        // Instance of DW_fp_mult for alpha_temp_maker
        DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
          alpha_temp_maker_inst_i (
            .a(G4[i]), 
            .b(conic_opacity4[i][precision - 1 : 0]), 
            .rnd(3'b0), 
            .z(alpha_temp1[i]), 
            .status(status_inst[i][13])
          );

        ////////////////////////////////////////////////////////////////////
        /////////////////////////// Clock Step 6 ///////////////////////////
        ////////////////////////////////////////////////////////////////////

        // Instance of DW_fp_cmp for alpha_comp
        DW_fp_cmp #(mantissa_bit, exponent_bit, 0)
          alpha_comp_inst_i (
            .a(alpha5[i]), 
            .b(max_alpha), 
            .zctr(1'b0), 
            .aeqb(aeqb_inst1[i]), 
            .altb(altb_inst[i]), 
            .agtb(agtb_inst1[i]), 
            .unordered(unordered_inst1[i]), 
            .z0(alpha_temp[i]), 
            .z1(not_used_alpha1[i]), 
            .status0(status_flag_0[i]), 
            .status1(status_flag_1[i])
          );

        // Instance of DW_fp_cmp for alpha_skip_comp
        DW_fp_cmp #(mantissa_bit, exponent_bit, 0)
          alpha_skip_comp_inst_i (
            .a(alpha_temp[i]), 
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

    assign skip_temp1[i] = !power3[i][precision - 1];
    assign skip_temp2[i] = (skip_from_alpha[i] || skip5[i]);

      end
    endgenerate

    ////////////////////////////////////////////////////////////////////
    //////////////////////// Clock Step 7 (Out) ////////////////////////
    ////////////////////////////////////////////////////////////////////

    // Capture before out 
    always_ff @ (posedge clk) begin
        if (!rst_n) begin

            block_id0 <= 'h0;
            pixel_id0 <= 'h0;
            for (int j = 0; j < inputs; j = j + 1) begin
              skip3[j] <= 'b0;
              skip4[j] <= 'b0;
              skip5[j] <= 'b0;
              skip_out[j] <= 'b0;

              G_out[j] <= 'h0;
              G4[j] <= 'h0;
              G5[j] <= 'h0;

              d_out[j] <= 'h0;
              d1[j] <= 'h0;
              d2[j] <= 'h0;
              d3[j] <= 'h0;
              d4[j] <= 'h0;
              d5[j] <= 'h0;

              alpha_out[j] <= 'h0;

              dxx2[j] <= 'h0;
              dxy2[j] <= 'h0;
              dyy2[j] <= 'h0;

              power3[j] <= {1'b1, {(precision-1){1'b0}}};

              i_valid0[j] <= 'b0;
              i_valid1[j] <= 'b0;
              i_valid2[j] <= 'b0;
              i_valid3[j] <= 'b0;
              i_valid4[j] <= 'b0;
              i_valid5[j] <= 'b0;
              skip_and_alpha_done_out[j] <= 'b0;

              mean2D0[j] <= 'h0;

              conic_opacity0[j] <= 'h0;
              conic_opacity1[j] <= 'h0;
              conic_opacity2[j] <= 'h0;
              conic_opacity3[j] <= 'h0;
              conic_opacity4[j] <= 'h0;
              conic_opacity5[j] <= 'h0;
              conic_opacity_out[j] <= 'h0;

              alpha5[j] <= 'h0;
              early_skip[j] <= 'b0;

              gaussian_id0[j] <= 'h0;
              gaussian_id1[j] <= 'h0;
              gaussian_id2[j] <= 'h0;
              gaussian_id3[j] <= 'h0;
              gaussian_id4[j] <= 'h0;
              gaussian_id5[j] <= 'h0;
              gaussian_id_out[j] <= 'h0;
            end
        end

        else begin

            for (int j = 0; j < inputs; j = j + 1) begin
              if (ready_from_arbiter[j] && skip_and_alpha_done_out[j]) begin
                  skip_and_alpha_done_out[j] <= 1'b0;
              end
            end

            if (!stall) begin

                if (start) begin
                  block_id0 <= block_id;
                  pixel_id0 <= pixel_id;
                end


                for (int j = 0; j < inputs; j = j + 1) begin
                  ////////////////////////////////////////////////////////////////////
                  ///////////////////////// Clock 1 Data Input ///////////////////////
                  ////////////////////////////////////////////////////////////////////

                  i_valid0[j] <= i_valid[j];
                  mean2D0[j] <= mean2D[j];
                  conic_opacity0[j] <= conic_opacity[j];
                  // pixel_id0[j] <= pixel_id[j];
                  gaussian_id0[j] <= gaussian_id_in[j];

                  ////////////////////////////////////////////////////////////////////
                  ///////////////////////// Clock 2 Data Flow ///////////////////////
                  ////////////////////////////////////////////////////////////////////

                  i_valid1[j] <= i_valid0[j];
                  conic_opacity1[j] <= conic_opacity0[j];
                  d1[j] <= d_temp[j];
                  gaussian_id1[j] <= gaussian_id0[j];

                  ////////////////////////////////////////////////////////////////////
                  ///////////////////////// Clock 3 Data Flow ///////////////////////
                  ////////////////////////////////////////////////////////////////////

                  i_valid2[j] <= i_valid1[j];
                  conic_opacity2[j] <= conic_opacity1[j];
                  d2[j] <= d1[j];
                  dxx2[j] <= dxx_temp[j];
                  dxy2[j] <= dxy_temp[j];
                  dyy2[j] <= dyy_temp[j];
                  gaussian_id2[j] <= gaussian_id1[j];
                  
                  ////////////////////////////////////////////////////////////////////
                  ///////////////////////// Clock 4 Data Flow ///////////////////////
                  ////////////////////////////////////////////////////////////////////

                  i_valid3[j] <= i_valid2[j];
                  conic_opacity3[j] <= conic_opacity2[j];
                  d3[j] <= d2[j];

                  power3[j] <= power_temp[j];
                  skip3[j] <= skip_temp1[j];
                  gaussian_id3[j] <= gaussian_id2[j];

                  ////////////////////////////////////////////////////////////////////
                  ///////////////////////// Clock 5 Data Flow ///////////////////////
                  ////////////////////////////////////////////////////////////////////

                  i_valid4[j] <= i_valid3[j];
                  conic_opacity4[j] <= conic_opacity3[j];
                  d4[j] <= d3[j];
                  G4[j] <= G_temp[j];
                  skip4[j] <= skip3[j];
                  early_skip[j] <= early_skip_temp[j];
                  gaussian_id4[j] <= gaussian_id3[j];

                  ////////////////////////////////////////////////////////////////////
                  ///////////////////////// Clock 6 Data Flow ///////////////////////
                  ////////////////////////////////////////////////////////////////////

                  i_valid5[j] <= i_valid4[j];
                  conic_opacity5[j] <= conic_opacity4[j];
                  d5[j] <= d4[j];
                  G5[j] <= G4[j];
                  skip5[j] <= skip4[j];
                  alpha5[j] <= alpha_temp1[j];

                  gaussian_id5[j] <= gaussian_id4[j];

                  ////////////////////////////////////////////////////////////////////
                  /////////////////// Clock 7 & Final Out Data Flow //////////////////
                  ////////////////////////////////////////////////////////////////////                

                  skip_and_alpha_done_out[j] <= i_valid5[j];
                  conic_opacity_out[j] <= conic_opacity5[j];
                  d_out[j] <= d5[j];
                  G_out[j] <= G5[j];
                  skip_out[j] <= skip_temp2[j];
                  alpha_out[j] <= alpha5[j];
                  gaussian_id_out[j] <= gaussian_id5[j];
                end
            end
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