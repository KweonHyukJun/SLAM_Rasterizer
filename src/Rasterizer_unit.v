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
    // input wire [63:0] block_gaussian_range, // int32 x and y
    // input wire [31:0] block_point_list,

    input wire done, // pixel worker group controller에서 일하는 여부를 내려준다고 가정 (last contributor 이런것도 포함)

    input wire [31:0] W,
    input wire [31:0] H,

    input wire i_valid,

    input wire [ precision-1 :0] Test_T,
    input wire [ (3 * precision) - 1:0] Test_last_color,
    input wire [31:0] Test_last_depth,
    input wire [31:0] Test_last_alpha,
    input wire [95:0] Test_rec_accum,
    input wire [31:0] Test_rec_accum_depth,



    input wire [63:0] block_id , // block index x at [0] y at [1]
    
    // input wire [95:0] background_color, //fp32 | R | G | B |

    input wire [63:0] mean2D, //fp32 | X | Y | 
    input wire [127:0] conic_opacity, // fp32 | X | Y | Z | W |

    input wire [(2 * $clog2(BLOCK_SIZE) - 1): 0] pixel_id,

    // input wire [31:0] gaussian_id,
    input wire [95:0] gaussian_color, //fp32 | R | G | B |
    input wire [31:0] gaussian_depth, //fp32

    // input wire [31:0] final_T, //fp32 // 이거 픽셀 데이터인데 어떻게 하지? 스타트에 관한 신호를 넣어야 하나

    // input wire [31:0] n_contrib, //int32

    input wire [95:0] dL_dpixel, //fp32 | R | G | B |
    input wire [31:0] dL_dpixel_depth, //fp32

    output reg [63:0] dL_dmean2D, // fp32 | X | Y |
    output reg [127:0] dL_dconic, // fp32 | X | Y | Z | W |
    output reg [31:0] dL_dopacity, // fp32 
    output reg [95:0] dL_dcolor, // fp32 | R | G | B |
    output reg [31:0] dL_ddepth, // fp32
    
    output reg [31:0] dL_dalpha_out,

    output reg [1:0] state_current
    );

    localparam [1:0]    IDLE = 2'b00,
                        SKIP_ALPHA_CALC = 2'b01,
                        GRADIENT_DEPTH_COLOR_CALC = 2'b10,
                        GRADIENT_GAUSSIANS_CALC = 2'b11;


    // gaussian ID 기록해서 Gradient 계산 후 반환해야함

    // | ---------------->>>> forward path  ---------------->>>> |
    // | <<<<---------------- backward path <<<<---------------- |
    //         | (next)
    //             | (current)

    //T_final을 어떻게 관리하는가 (그건 이전단계 컨트롤러)

    reg [31:0] T_current;
    reg [95:0] color_current;
    reg [31:0] depth_current;
    reg [31:0] alpha_current;

    reg [95:0] accum_rec_current;
    reg [31:0] accum_rec_depth_current;

    reg [31:0] G;
    reg [63:0] d;
    

    
    reg [1:0] state_next;
    reg skip_and_alpha_i_valid, gradient_depth_color_i_valid, gradient_gaussians_i_valid;

    wire skip;
    wire dL_dalpha_valid;
    wire gradient_valid;

    wire [31:0] T_next;
    wire [95:0] color_next;
    wire [31:0] depth_next;
    wire [31:0] alpha_next;

    wire [95:0] accum_rec_next;
    wire [31:0] accum_rec_depth_next;

    wire [31:0] dL_dalpha;
    
    wire [31:0] alpha_calculated;


    wire [31:0] dL_dopacity_temp, dL_ddepth_temp;
    wire [95:0] dL_dcolor_temp;
    wire [127:0] dL_dconic_temp;
    wire [63:0] dL_dmean2D_temp; 

    wire skip_and_alpha_done, gradient_depth_color_done;

    wire [31:0] G_in, G_out;
    wire [63:0] d_in, d_out;
    

    // Phase 1, skip logic + alpha return
    //skip Logic 이후에 T가 업데이트되어 배출 가능 및 Phase 2의 Gradient Logic에 사용


    //skip and alpha module
    // assign skip_and_alpha_i_valid = i_valid;     // reg 로 타입 변경
    skip_and_alpha #( .BLOCK_SIZE(BLOCK_SIZE), .exponent_bit(exponent_bit), .mantissa_bit(mantissa_bit), .precision(precision)) 
    skip_and_alpha_unit (.block_id(block_id), .mean2D(mean2D), .i_valid(skip_and_alpha_i_valid),
    .conic_opacity(conic_opacity), .pixel_id(pixel_id), .T_before(T_current),
    .skip(skip), .G(G), .d(d), .T(T_next), .alpha(alpha_calculated));


    // Phase 2, Gradient Logic 1 (depth, color) & dL_dalpha
    // background 추가 처리 필요 (이거를 있다고 해야되나)
    // assign gradient_depth_color_i_valid = !skip; // 이거만 하면 계속 1이 떠있는데 reg로 타입 변경

    gradient_depth_color #( .BLOCK_SIZE(BLOCK_SIZE), .exponent_bit(exponent_bit), .mantissa_bit(mantissa_bit), .precision(precision))
    gradient_depth_color_unit (.alpha_before(alpha_current), .color_before(color_current), .depth_before(depth_current), .accum_rec_before(accum_rec_current), .accum_rec_depth_before(accum_rec_depth_current),
    .alpha_in(alpha_calculated), .T_in(T_current), .gaussian_color(gaussian_color), .gaussian_depth(gaussian_depth), .i_valid(gradient_depth_color_i_valid), // .background_color(background_color),

    // gradient data input
    .dL_dpixel(dL_dpixel), .dL_dpixel_depth(dL_dpixel_depth), .dL_dalpha(dL_dalpha), 

    // gradient of gaussians (will be used for update gaussians)
    .dL_dcolor(dL_dcolor), .dL_ddepth(dL_ddepth),

    // data for next stage
    .alpha_out(alpha_next), .color_out(color_next), .depth_out(depth_next), .accum_rec(accum_rec_next), .accum_rec_depth(accum_rec_depth_next), .dL_dalpha_valid(dL_dalpha_valid)
    );

    // Phase 3, Gradient Logic 2 (mean2D, conic2D, opacity)
    // assign gradient_gaussians_i_valid = dL_dalpha_valid; // reg
    gradient_gaussians #( .BLOCK_SIZE(BLOCK_SIZE), .exponent_bit(exponent_bit), .mantissa_bit(mantissa_bit), .precision(precision))
    gradient_gaussians_unit (.W(W), .H(H), .G(G_in), .d(d_in), .dL_dalpha(dL_dalpha), .conic_opacity(conic_opacity), .i_valid(gradient_gaussians_i_valid),
    
    // gradient output
    .dL_dmean2D(dL_dmean2D), .dL_dconic(dL_dconic), .dL_dopacity(dL_dopacity),
    
    //valid signal
    .gradient_valid(gradient_valid)
    );
    
    // Phase 4 (Can Be or cannot be) (이건 group control에 넘긴다고 가정하고 진행)
    // Gradient adding 

    // T (T_next), last_alpha (alpha_next) ... update
    // always @ (*) begin
    //     T_current = T_next;
    //     alpha_current = alpha_next;
    //     color_current = color_next;
    //     depth_current = depth_next;
    //     accum_rec_current = accum_rec_next;
    //     accum_rec_depth_current = accum_rec_depth_next;
    // end    

    // always @ (*) begin
    //     dL_dalpha_out = dL_dalpha;
    //     state_current = {gradient_gaussians_i_valid, gradient_depth_color_i_valid, skip_and_alpha_i_valid};
    // end


    assign G_in = G;
    assign d_in = d;



    // current <= next in edge

    // FSM for what to work
    always @ (posedge clk) begin
        if (!rst_n) begin
            T_current <= 32'h0;
            color_current <= 96'h0;
            depth_current <= 32'h0;
            alpha_current <= 32'h0;
            accum_rec_current <= 96'h0;
            accum_rec_depth_current <= 32'h0;

            G <= 32'h0;
            d <= 64'h0;
            state_next <= 2'b0;

            skip_and_alpha_i_valid <= 1'b0;
            gradient_depth_color_i_valid <= 1'b0;
            gradient_gaussians_i_valid <= 1'b0;
            // stall signal and precision decimal required
        end


        else begin

        state_current <= state_next;

            // Set valid signals based on current state
            case (state_current)
                IDLE: begin
                    
                    if (i_valid && !done) begin
                        // Start Phase 1
                        skip_and_alpha_i_valid <= 1'b1;
                    end 

                    else begin
                        skip_and_alpha_i_valid <= 1'b0;
                    end

                    // Reset downstream valid signals
                    gradient_depth_color_i_valid <= 1'b0;
                    gradient_gaussians_i_valid <= 1'b0;
                end

                SKIP_ALPHA_CALC: begin
                    if (skip_and_alpha_i_valid && !skip) begin
                        // If skip is false, move to Phase 2
                        gradient_depth_color_i_valid <= 1'b1;
                    end else begin
                        gradient_depth_color_i_valid <= 1'b0;
                    end

                    // Reset Phase 1 valid signal once phase is complete
                    skip_and_alpha_i_valid <= 1'b0;
                end

                GRADIENT_DEPTH_COLOR_CALC: begin
                    if (gradient_depth_color_i_valid && dL_dalpha_valid) begin
                        // If dL_dalpha is valid, move to Phase 3
                        gradient_gaussians_i_valid <= 1'b1;
                    end else begin
                        gradient_gaussians_i_valid <= 1'b0;
                    end

                    // Reset Phase 2 valid signal once phase is complete
                    gradient_depth_color_i_valid <= 1'b0;
                end

                GRADIENT_GAUSSIANS_CALC: begin
                    if (gradient_gaussians_i_valid && gradient_valid) begin
                        // If gradient calculation is complete, go back to IDLE or start next
                        gradient_gaussians_i_valid <= 1'b0;
                    end
                end

                default: begin
                    // Default to reset state
                    state_current <= IDLE;
                end
            endcase
            
        end    
    end

    // Next state logic based on current state and conditions
    always @(*) begin
        case (state_current)
            IDLE: begin
                if (i_valid && !done) begin
                    state_next = SKIP_ALPHA_CALC; // Move to Phase 1
                end else begin
                    state_next = IDLE;
                end
            end

            SKIP_ALPHA_CALC: begin
                if (skip_and_alpha_i_valid && !skip) begin
                    state_next = GRADIENT_DEPTH_COLOR_CALC; // Move to Phase 2
                end 
                // else begin
                //     state_next = SKIP_ALPHA_CALC; // Remain in Phase 1 if skip is true
                // end
            end

            GRADIENT_DEPTH_COLOR_CALC: begin
                if (dL_dalpha_valid) begin
                    state_next = GRADIENT_GAUSSIANS_CALC; // Move to Phase 3
                end 
                // else begin
                //     state_next = GRADIENT_DEPTH_COLOR_CALC; // Remain in Phase 2 until valid
                // end
            end

            GRADIENT_GAUSSIANS_CALC: begin
                if (gradient_valid) begin
                    state_next = IDLE; // Go back to IDLE after Phase 3 is done
                end else begin
                    state_next = GRADIENT_GAUSSIANS_CALC; // Stay in Phase 3 until complete
                end
            end

            default: state_next = IDLE;
        endcase
    end

    //Test value 
    always @ (*) begin
        T_current = Test_T; 
        color_current = Test_last_color;
        alpha_current = Test_last_alpha;
        depth_current = Test_last_depth;
        accum_rec_current = Test_rec_accum;
        accum_rec_depth_current = Test_rec_accum_depth;
    end    


    // always  @ (*) begin
    //     state_next = state_out;
        
    //     case (state_out)
    //         IDLE: begin // 2'b00
    //             if (!done && i_valid) 
    //                 state_next = SKIP_CALC;
    //         end

    //         SKIP_CALC : begin // 2'b01
    //             if (!skip) 
    //                 state_next = dL_dalpha_CALC;
    //             else if (skip && i_valid)
    //                 state_next = SKIP_CALC;
    //         end

    //         dL_dalpha_CALC : begin // 2b'10
    //             if (dL_dalpha_valid)
    //                 state_next = dL_dGaussian_CALC;
    //         end

    //         dL_dGaussian_CALC : begin // 2b'11
    //             if (gradient_valid && !i_valid)
    //                 state_next = IDLE;
    //             else if (gradient_valid && i_valid)
    //                 state_next = SKIP_CALC;
    //         end

    //         default: state_next = IDLE;  // Default state is IDLE
    //     endcase 
    // end


endmodule
