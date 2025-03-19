module synopsys_cmp2
    #(
        parameter mantissa_bit = 7,
        parameter exponent_bit = 8,
        parameter precision = 16,
        parameter gaussian_inputs= 4
    )
    (
        input wire clk,
        input wire rst_n,

        input wire [15:0] block_id,
        input wire [11:0] pixel_id,

        input wire [2 * precision-1:0] mean2D [gaussian_inputs-1:0],

        output reg [2 * precision-1:0] d [gaussian_inputs-1:0]
    );



    reg [15:0] block_id0;
    reg [11:0] pixel_id0;

    reg [2 * precision-1:0] mean2D0 [gaussian_inputs-1:0];


    wire [2 * precision - 1:0] current_pixel_fp;

    wire [7:0] status_inst_pixel [1:2];

    wire [7:0] status_inst [gaussian_inputs-1:0][2:1];

    wire [2 * precision - 1:0] d_temp [gaussian_inputs-1:0];

    DW_fp_i2flt #(mantissa_bit, exponent_bit, precision, 1)
      fp_pixel_x_inst_i ( 
        .a({{(precision-11){1'b0}}, block_id0[14:8], pixel_id0[3:0]}), 
        .rnd(3'b0), 
        .z(current_pixel_fp[(2 * precision) - 1: precision]), 
        .status(status_inst_pixel[1])
      );

    // Instance of DW_fp_i2flt for pixel_y
    DW_fp_i2flt #(mantissa_bit, exponent_bit, precision, 1)
      fp_pixel_y_inst_i ( 
        .a({{(precision-11){1'b0}}, block_id0[6:0], pixel_id0[7:4]}), 
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
            .a(mean2D0[i][(2 * precision) - 1: precision]), 
            .b({!current_pixel_fp[(2 * precision) - 1], current_pixel_fp[(2 * precision) - 2 : precision]}), 
            .rnd(3'b0), 
            .z(d_temp[i][(2 * precision) - 1: precision]), 
            .status(status_inst[i][1])
          );

        // Instance of DW_fp_add for d_y
        DW_fp_add #(mantissa_bit, exponent_bit, 0)
          d_y_inst_i (
            .a(mean2D0[i][precision - 1 : 0]), 
            .b({!current_pixel_fp[precision - 1], current_pixel_fp[precision - 2 : 0]}), 
            .rnd(3'b0), 
            .z(d_temp[i][precision - 1 : 0]), 
            .status(status_inst[i][2])
          );
      end

    endgenerate

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            block_id0 <= '0;
            pixel_id0 <= '0;

            for (int k = 0; k < gaussian_inputs; k = k + 1) begin
                mean2D0[k] <= '0;
                d[k] <= '0;

            end

        end
        else begin
            block_id0 <= block_id;
            pixel_id0 <= pixel_id;

            for (int k = 0; k < gaussian_inputs; k = k + 1) begin
                mean2D0[k] <= mean2D[k];
                d[k] <= d_temp[k];
            end
        end
    end

endmodule