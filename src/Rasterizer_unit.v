//////////////////////////////////////////////////////////////////////////////////
// Company: Sungkyunkwan Univ. IDS LAB  
// Engineer: Kweon Hyuk Jun 
// 
// Create Date: 2024/08/23 18:02:07
// Design Name: Rasterizer
// Module Name: Rasterizer
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


// One Unit for One pixel
module Rasterizer_unit
    #(
        parameter BLOCK_SIZE = 16,
        parameter exponent_bit = 8,
        parameter mantissa_bit = 23,
        parameter precision = 32
    )
(

    //reset and clock
    input wire clk,
    input wire rst_n,
    
    // // Backward input and output << move up to block controller
    // input wire [(2 * precision) - 1 : 0] block_gaussian_range, // int32 x and y
    // input wire [precision - 1 : 0] block_point_list,

    input wire done, // pixel worker group controller에서 일하는 여부를 내려준다고 가정 (last contributor 이런것도 포함)

    input wire [31:0] W,
    input wire [31:0] H,

    input wire i_valid,
    
    // For Test
    // input wire [ (precision - 1) :0] Test_T,
    // input wire [ (3 * precision) - 1:0] Test_last_color,
    // input wire [(precision - 1):0] Test_last_depth,
    // input wire [(precision - 1):0] Test_last_alpha,
    // input wire [(3 * precision) - 1:0] Test_rec_accum,
    // input wire [(precision - 1):0] Test_rec_accum_depth,



    input wire [63:0] block_id , // block index x at [0] y at [1]
    
    // input wire [(3 * precision) - 1 : 0] background_color, //fp32 | R | G | B |

    input wire [(2 * precision) - 1:0] mean2D, //fp32 | X | Y | 
    input wire [(4 * precision) - 1:0] conic_opacity, // fp32 | X | Y | Z | W |

    input wire [(2 * $clog2(BLOCK_SIZE) - 1): 0] pixel_id,

    // input wire [31:0] gaussian_id,
    input wire [(3 * precision) - 1:0] gaussian_color, //fp32 | R | G | B |
    input wire [precision - 1 : 0] gaussian_depth, //fp32

    // input wire [precision - 1 : 0] final_T, //fp32 // 이거 픽셀 데이터인데 어떻게 하지? 스타트에 관한 신호를 넣어야 하나

    // input wire [precision - 1 : 0] n_contrib, //int32

    input wire [(3 * precision) - 1:0] dL_dpixel, //fp32 | R | G | B |
    input wire [precision - 1:0] dL_dpixel_depth, //fp32



    output reg [(2 * precision) - 1:0] dL_dmean2D, // fp32 | X | Y |
    output reg [(4 * precision) - 1:0] dL_dconic, // fp32 | X | Y | Z | W |
    output reg [precision - 1:0] dL_dopacity, // fp32 
    output reg [(3 * precision) - 1:0] dL_dcolor, // fp32 | R | G | B |
    output reg [precision - 1:0] dL_ddepth, // fp32

    output reg gradient_valid_out
    
    
    //output test
    
    
    

    // ,output reg [precision - 1 : 0] T_current_out,
    // output reg [precision - 1 : 0] dL_dalpha_output,

    // output reg skip_alpha_done,
    // output reg dL_dalpha_done,
    // output reg gradient_done,


    // output reg [(2 * precision) - 1 : 0] d_output,
    // output reg [precision - 1 : 0] G_output


    );

    // gaussian ID 기록해서 Gradient 계산 후 반환해야함

    // | ---------------->>>> forward path  ---------------->>>> |
    // | <<<<---------------- backward path <<<<---------------- |
    //         | (next)
    //             | (current)

    //T_final을 어떻게 관리하는가 (그건 이전단계 컨트롤러)
    
    // FFs

    reg [precision - 1 : 0] T_current;
    reg [(3 * precision) - 1 : 0] color_current;
    reg [precision - 1 : 0] depth_current;
    reg [precision - 1 : 0] alpha_current;

    reg [(3 * precision) - 1 : 0] accum_rec_current;
    reg [precision - 1 : 0] accum_rec_depth_current;

    reg [precision - 1 : 0] G;
    reg [(2* precision) - 1 : 0] d;

    reg [precision - 1 : 0] dL_dalpha;
    
    // reg [1:0] state_next;
    reg skip_and_alpha_i_valid, gradient_depth_color_i_valid, gradient_gaussians_i_valid;

    wire skip;
    wire dL_dalpha_valid;
    wire gradient_valid_temp;

    wire [precision - 1 : 0] T_next;
    wire [(3 * precision) - 1 : 0] color_next;
    wire [precision - 1 : 0] depth_next;
    wire [precision - 1 : 0] alpha_next;

    wire [(3 * precision) - 1 : 0] accum_rec_next;
    wire [precision - 1 : 0] accum_rec_depth_next;

    wire [precision - 1 : 0] dL_dalpha_out;
    
    wire [precision - 1 : 0] alpha_calculated;

    wire [precision - 1 : 0] T_current_in;
    wire [precision - 1 : 0] dL_dopacity_temp, dL_ddepth_temp;
    wire [(3 * precision) - 1 : 0] dL_dcolor_temp;
    wire [(4 * precision) - 1 : 0] dL_dconic_temp;
    wire [(2* precision) - 1 : 0] dL_dmean2D_temp; 

    wire skip_and_alpha_done, gradient_depth_color_done;

    wire [precision - 1 : 0] G_out;
    wire [(2 * precision) - 1 : 0] d_out;
    
    //skip and alpha module
    // Phase 1 alpha and skip Logic
    skip_and_alpha #( .BLOCK_SIZE(BLOCK_SIZE), .exponent_bit(exponent_bit), .mantissa_bit(mantissa_bit), .precision(precision)) 
    skip_and_alpha_unit (.block_id(block_id), .mean2D(mean2D), .i_valid(skip_and_alpha_i_valid),
    .conic_opacity(conic_opacity), .pixel_id(pixel_id), .T_before(T_current),

    .skip(skip), .G(G_out), .d(d_out), .T(T_next), .alpha(alpha_calculated), .skip_and_alpha_done(skip_and_alpha_done));


    // Phase 2, Gradient Logic 1 (depth, color) & dL_dalpha
    // background 추가 처리 필요 (이거를 있다고 해야되나)
    gradient_depth_color #( .BLOCK_SIZE(BLOCK_SIZE), .exponent_bit(exponent_bit), .mantissa_bit(mantissa_bit), .precision(precision))
    gradient_depth_color_unit (.alpha_before(alpha_current), .color_before(color_current), .depth_before(depth_current), .accum_rec_before(accum_rec_current), .accum_rec_depth_before(accum_rec_depth_current),
    .alpha_in(alpha_calculated), .T_in(T_current), .gaussian_color(gaussian_color), .gaussian_depth(gaussian_depth), .i_valid(gradient_depth_color_i_valid), // .background_color(background_color),

    // gradient data input
    .dL_dpixel(dL_dpixel), .dL_dpixel_depth(dL_dpixel_depth), 
    
    //data for gradient
    .dL_dalpha(dL_dalpha_out), 

    // gradient of gaussians (will be used for update gaussians)
    .dL_dcolor(dL_dcolor_temp), .dL_ddepth(dL_ddepth_temp),

    // data for next stage
    .alpha_out(alpha_next), .color_out(color_next), .depth_out(depth_next), .accum_rec(accum_rec_next), .accum_rec_depth(accum_rec_depth_next), .dL_dalpha_valid(dL_dalpha_valid)
    );



    // Phase 3, Gradient Logic 2 dL_dmean2D, dL_dconic, dL_dopacity
    gradient_gaussians #( .BLOCK_SIZE(BLOCK_SIZE), .exponent_bit(exponent_bit), .mantissa_bit(mantissa_bit), .precision(precision))
    gradient_gaussians_unit (.W(W), .H(H), .G(G), .d(d), .dL_dalpha(dL_dalpha), .conic_opacity(conic_opacity), .i_valid(gradient_gaussians_i_valid),
    
    // gradient output
    .dL_dmean2D(dL_dmean2D_temp), .dL_dconic(dL_dconic_temp), .dL_dopacity(dL_dopacity_temp),
    
    //valid signal
    .gradient_valid(gradient_valid_temp)
    );


    // clock
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            {gradient_gaussians_i_valid, gradient_depth_color_i_valid, skip_and_alpha_i_valid} <= 3'b000;
            G <= 'h0;
            d <= 'h0;
            T_current <= 'h0;
            color_current <= 'h0;
            alpha_current <= 'h0;
            depth_current <= 'h0;
            accum_rec_current <= 'h0;
            accum_rec_depth_current <= 'h0;
            dL_dalpha <= 'h0;
            dL_dcolor <= 'h0;
            dL_ddepth <= 'h0;
            dL_dmean2D <= 'h0;
            dL_dconic <= 'h0;
            dL_dopacity <= 'h0;
            gradient_valid_out <= 'b0;
        end


        if (!stall) begin

        end

        // // Phase 4 condition 
        // else if (gradient_valid_temp) begin 
        //     {gradient_gaussians_i_valid, gradient_depth_color_i_valid, skip_and_alpha_i_valid} <= 3'b000;
        //     dL_dmean2D              <= dL_dmean2D_temp;
        //     dL_dconic               <= dL_dconic_temp;
        //     dL_dopacity             <= dL_dopacity_temp;
        //     gradient_valid_out      <= gradient_valid_temp;
        // end

        // // Phase 3 condition skip인 경우 처리할거 생각해야함
        // else if (dL_dalpha_valid) begin 
        //     {gradient_gaussians_i_valid, gradient_depth_color_i_valid, skip_and_alpha_i_valid} <= 3'b100;
        //     color_current           <= color_next;
        //     alpha_current           <= alpha_next;
        //     depth_current           <= depth_current;
        //     accum_rec_current       <= accum_rec_next;
        //     accum_rec_depth_current <= accum_rec_depth_next;
        //     dL_dalpha               <= dL_dalpha_out;
        //     dL_dcolor               <= dL_dcolor_temp;
        //     dL_ddepth               <= dL_ddepth_temp;
        // end

        // //Phase 2 condition , skip 인 경우 외부에 줄 신호 추후에 생성해야 함
        // else if (skip_and_alpha_done) begin // skip이어도 done이 뜨는 신호를 고려해서 제작해야 함
        //     {gradient_gaussians_i_valid, gradient_depth_color_i_valid, skip_and_alpha_i_valid} <= 3'b010;
        //     G <= G_out;
        //     d <= d_out;
        //     T_current <= T_next; 
        // end

        // //Phase 1 condition
        // else if (i_valid & !done) begin
        //     {gradient_gaussians_i_valid, gradient_depth_color_i_valid, skip_and_alpha_i_valid} <= 3'b001;
        //     dL_dalpha <= 'h0;
        //     dL_dcolor <= 'h0;
        //     dL_ddepth <= 'h0;
        //     dL_dmean2D <= 'h0;
        //     dL_dconic <= 'h0;
        //     dL_dopacity <= 'h0;
        //     gradient_valid_out <= 'b0;
        // end
    end



    // //Test initial value 
    // always @ (*) begin
    //     T_current <= Test_T; 
    //     color_current <= Test_last_color;
    //     alpha_current <= Test_last_alpha;
    //     depth_current <= Test_last_depth;
    //     accum_rec_current <= Test_rec_accum;
    //     accum_rec_depth_current <= Test_rec_accum_depth;
    // end  

    // //output Test
    // always @ (*) begin
    //     dL_dalpha_output = dL_dalpha;
    //     G_output = G;
    //     d_output = d;
    //     gradient_valid_out = gradient_valid_temp;
    //     skip_alpha_done = skip_and_alpha_done;
    //     dL_dalpha_done = dL_dalpha_valid;
    //     gradient_done = gradient_valid_temp;
    //     T_current_out = T_current;
    // end

endmodule


    // Phase 1, skip logic + alpha return
    //skip Logic 이후에 T가 업데이트되어 배출 가능 및 Phase 2의 Gradient Logic에 사용

    // // Stage 1: Skip and Alpha Calculation
    // always @(posedge clk or negedge rst_n) begin
    //     if (!rst_n) begin
    //         skip_and_alpha_i_valid <= 1'b0;
    //     end 
    //     else if (i_valid) begin
    //         skip_and_alpha_i_valid <= 1'b1;
    //         state_out <= {gradient_gaussians_i_valid, gradient_depth_color_i_valid, skip_and_alpha_i_valid};
    //     end 
    //     else begin
    //         skip_and_alpha_i_valid <= 1'b0;
    //         state_out <= {gradient_gaussians_i_valid, gradient_depth_color_i_valid, skip_and_alpha_i_valid};
    //     end
    // end

    // Stage 2: Gradient Depth and Color Calculation
    // always @(posedge clk or negedge rst_n) begin
    //     if (!rst_n) begin
    //         gradient_depth_color_i_valid <= 1'b0;
    //     end 
    //     else if (skip_and_alpha_done && !skip) begin
    //         // Move to Stage 2 if Skip is False
    //         gradient_depth_color_i_valid <= 1'b1;
    //         // Store intermediate data in pipeline registers
    //         G <= G_out;
    //         d <= d_out;
    //         T_current <= T_next;
    //         color_current <= color_next;
    //         alpha_current <= alpha_next;
    //         depth_current <= depth_next;
    //     end 
    //     else begin
    //         gradient_depth_color_i_valid <= 1'b0;
    //     end
    // end

    // Phase 3, Gradient Logic 2 (mean2D, conic2D, opacity)
    // Stage 3: Gradient Gaussian Calculation
    // always @(posedge clk or negedge rst_n) begin
    //     if (!rst_n) begin
    //         gradient_gaussians_i_valid <= 1'b0;
    //     end 
    //     else if (dL_dalpha_valid) begin
    //         // Move to Stage 3 if Gradient Depth and Color calculation is done
    //         gradient_gaussians_i_valid <= 1'b1;
    //     end 
    //     else begin
    //         gradient_gaussians_i_valid <= 1'b0;
    //     end
    // end