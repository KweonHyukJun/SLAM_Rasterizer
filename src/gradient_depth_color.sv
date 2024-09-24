module grad_depth_and_color
    #(
        parameter BLOCK_SIZE = 16,
        parameter exponent_bit = 8,
        parameter mantissa_bit = 23,
        parameter precision = 32
    )
    (
    input wire clk,
    input wire rst_n,
    input wire skip,

    input wire [31:0] alpha_before, // last alpha
    input wire [95:0] color_before, // last_color
    input wire [95:0] accum_rec_before, // accum_rec_before

    input wire [31:0] alpha, // alpha_i
    input wire [31:0] T, // T_i
    
    input wire [63:0] gaussian_id,
    input wire [95:0] gaussian_color, // | R | G | B |
    input wire [31:0] gaussian_depth,

    input wire [95:0] dL_dpixel,

    output reg [31:0] dL_dalpha,
    output reg [95:0] dL_dcolors,
    output reg [31:0] dL_ddepth,

    output reg [95:0] accum_rec,
    output reg [95:0] color,
    output reg [31:0] alpha
    );

    
    localparam ieee_compliance = 1'b0;
    localparam [2:0] inst_rnd = 3'b0;
    

    reg [31:0] dL_dchannel_dcolor;
    reg [95:0] c;
    reg [31:0] dL_dalpha_temp = 32'h0;
    reg [95:0] accum_rec_temp;
    reg [95:0] accum_rec;
    reg [95:0] dL_dcolor;
    
    wire [95:0] local_dL_dcolors_temp; // skip이 아닌 경우 값 임시 저장
    wire [7:0] status_inst; 

    // Instance of DW_fp_mult
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0) // const float dchannel_dcolor = alpha * T;
	  dL_dch_dcolor ( .a(T), .b(alpha), .rnd(inst_rnd), .z(dL_dchannel_dcolor), .status(status_inst) );
    
    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0) // 	local_dL_dcolors[ch] = skip ? 0.0f : dchannel_dcolor * dL_dchannel;
	  local_dL_dcolors_temp_R ( .a(dL_dchannel_dcolor[95:64]), .b(dL_dpixel[95:64]), .rnd(inst_rnd), .z(local_dL_dcolors_temp[95:64]), .status(status_inst) );

    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0) // 	local_dL_dcolors[ch] = skip ? 0.0f : dchannel_dcolor * dL_dchannel;
	  local_dL_dcolors_temp_G ( .a(dL_dchannel_dcolor[63:32]), .b(dL_dpixel[63:32]), .rnd(inst_rnd), .z(local_dL_dcolors_temp[63:32]), .status(status_inst) );

    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0) // 	local_dL_dcolors[ch] = skip ? 0.0f : dchannel_dcolor * dL_dchannel;
	  local_dL_dcolors_temp_B ( .a(dL_dchannel_dcolor[31:0]), .b(dL_dpixel[31:0]), .rnd(inst_rnd), .z(local_dL_dcolors_temp[31:0]), .status(status_inst) );





    always_comb begin
        c = gaussian_color;
        dL_dcolor = 96'h0;

        if (!skip) begin

            accum_rec_temp = ;
            color = c;
            dL_dcolor = local_dL_dcolors_temp;

        end

        else begin

            acuum_rec = color_before;
            color = color_before;

        end
    end



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

			// // Account for fact that alpha also influences how much of
			// // the background color is added if nothing left to blend
			// float bg_dot_dpixel = 0.f;
			// #pragma unroll
			// for (int i = 0; i < C; i++) {
			// 	bg_dot_dpixel +=  bg_color[i] * dL_dpixel[i];
			// }

			// dL_dalpha += (-T_final / (1.f - alpha)) * bg_dot_dpixel;
