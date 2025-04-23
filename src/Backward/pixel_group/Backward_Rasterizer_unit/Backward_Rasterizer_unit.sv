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
module Backward_Rasterizer_unit
    #(
        parameter BLOCK_SIZE = 16,
        parameter exponent_bit = 8,
        parameter mantissa_bit = 7,
        parameter precision = 16,
        parameter gaussian_inputs = 4,
        parameter GID_bit = 12
    )
(
    // input wire
    input logic clk,
    input logic rst_n,

    input logic [11:0] W, 
    input logic [11:0] H,

    // pixel dimension

    input logic i_valid [gaussian_inputs-1:0], // 1이면 valid, 0이면 invalid

    // 픽셀 처음 시작시에만 주면 되는 값들
    // input logic start [gaussian_inputs-1:0], // 시작시에만 Block id, pixel id , dL_dpixel, dL_dpixel_depth, 초기 T 값 이후 필요 없음. (Register 내부에서 사용)
    input logic start,
    input logic [(3 * precision) - 1:0] dL_dpixel, //fp32 | R | G | B |
    input logic [precision - 1:0] dL_dpixel_depth, //fp32
    input logic [precision - 1:0] T_first,    

    input logic [15:0] block_id, // block index x at [0] y at [1]  // 1920 이 16x16 으로 분해시 120이니까 최대 비트 7개면 가능 (32비트 쓰지말고)
    input logic [(2 * $clog2(BLOCK_SIZE) - 1): 0] pixel_id,

    input logic stall_backpressure,

    input logic last_input [gaussian_inputs-1:0],


    // input logic [(3 * precision) - 1 : 0] background_color, //fp32 | R | G | B |

    input logic [(2 * precision) - 1:0] mean2D [gaussian_inputs-1:0], //fp32 | X | Y | 
    input logic [(4 * precision) - 1:0] conic_opacity [gaussian_inputs-1:0], // fp32 | X | Y | Z | W |

    input logic [GID_bit-1:0] gaussian_id [gaussian_inputs-1:0],
    input logic [(3 * precision) - 1:0] gaussian_color [gaussian_inputs-1:0], //fp32 | R | G | B |
    input logic [precision - 1 : 0] gaussian_depth [gaussian_inputs-1:0], //fp32



    // output logic라고 간주 (어차피 gradient unit에서 reg 처리)
    output logic [(3 * precision) - 1:0] dL_dcolor_out, // fp32 | R | G | B |
    output logic [precision - 1:0] dL_ddepth_out, // fp32
    output logic [precision - 1:0] dL_dopacity_out, // fp32 
    output logic [(2 * precision) - 1:0] dL_dmean2D_out, // fp32 | X | Y |
    output logic [(4 * precision) - 1:0] dL_dconic_out, // fp32 | X | Y | Z | W |
    output logic [GID_bit-1:0] gaussian_id_out,


    // output logic [31:0] gaussian_id_out, // 나가는 gaussian ID도 명시해야함.

    output logic gradient_valid_out,

    output logic stall_to_controller,

    output logic last_input_done
    );
    




    // | ---------------->>>> forward path  ---------------->>>> |
    // | <<<<---------------- backward path <<<<---------------- |
    //         | (next)
    //             | (current)
    
    // Register decalaration

    logic [precision - 1:0] G_wire [gaussian_inputs-1:0];
    logic [(2 * precision) - 1:0] d_wire [gaussian_inputs-1:0];
    logic [precision - 1:0] alpha_wire [gaussian_inputs-1:0];
    logic skip_wire [gaussian_inputs-1:0];
    logic [(4 * precision) - 1:0] conic_opacity_wire [gaussian_inputs-1:0];
    logic skip_and_alpha_done_out [gaussian_inputs-1:0];

    logic stall_from_arbiter;
    logic valid_to_gradient_unit;
    logic [GID_bit-1:0] gaussian_id_wire [gaussian_inputs-1:0];
    logic [(3 * precision)-1:0] gaussian_color_wire [gaussian_inputs-1:0];
    logic [precision-1:0] gaussian_depth_wire [gaussian_inputs-1:0];

    localparam ARBITER_DATA_SIZE = (12 * precision) + GID_bit; // G(1), d(2), conic_opacity(4), alpha(1) , gaussian_color(3) , depth(1) // id(24)
    
    logic [ARBITER_DATA_SIZE-1:0] arbiter_data_out;
    
    logic src_request_temp [gaussian_inputs-1:0];
    logic [ARBITER_DATA_SIZE-1:0] src_data_arbiter [gaussian_inputs-1:0];
    logic src_grant_out [gaussian_inputs-1:0];


    logic [(2 * precision)-1:0] d_to_gradient_unit;
    logic [precision-1:0]       G_to_gradient_unit;
    logic [(3 * precision)-1:0] gaussian_color_to_gradient_unit;
    logic [(4 * precision)-1:0] conic_opacity_to_gradient_unit;
    logic [precision-1:0]   gaussian_depth_to_gradient_unit;
    logic [precision-1:0]   alpha_to_gradient_unit;
    logic [GID_bit-1:0]     gaussian_id_to_gradient_unit;


    logic last_input_done_wire_from_skip_unit [gaussian_inputs-1:0];
    logic last_input_done_wire_from_arbiter;

    assign stall_to_controller = stall_backpressure || stall_from_arbiter;
    //skip and alpha module
    // Phase 1 alpha and skip Logic

    Backward_skip_unit #( 
        .BLOCK_SIZE(BLOCK_SIZE), 
        .exponent_bit(exponent_bit), 
        .mantissa_bit(mantissa_bit), 
        .precision(precision), 
        .gaussian_inputs(gaussian_inputs), 
        .GID_bit(GID_bit)
    ) 
    skip_unit_stage1 (
        // Input
        .clk(clk), 
        .rst_n(rst_n), 

        .start(start),
        .block_id(block_id), 

        .mean2D(mean2D), 
        .conic_opacity(conic_opacity), 
        .pixel_id(pixel_id), 

        .gaussian_id_in(gaussian_id), 
        .gaussian_depth_in(gaussian_depth), 
        .gaussian_color_in(gaussian_color), 

        .i_valid(i_valid), 
         
        .stall(stall_to_controller), 

        .grant_from_arbiter(src_grant_out),
        
        .last_input(last_input),
        
        // Output
        .skip_out(skip_wire), 
        .G_out(G_wire), 
        .d_out(d_wire), 
        .alpha_out(alpha_wire), 
        .conic_opacity_out(conic_opacity_wire),

        .gaussian_id_out(gaussian_id_wire), 
        .gaussian_color_out(gaussian_color_wire), 
        .gaussian_depth_out(gaussian_depth_wire),

        .skip_and_alpha_done_out(skip_and_alpha_done_out), 
        .last_input_done(last_input_done_wire_from_skip_unit)
        );
    

    // localparam ARBITER_DATA_SIZE = 12 * precision + 32; // G(1), d(2), conic_opacity(4), alpha(1), gaussian_color(3) / depth(1) // id(32)
    
    // Phase 2, Skip Arbitration (Combinational Logic)
    fixed_arbiter #(
        .N_MASTER(gaussian_inputs), 
        .DATA_SIZE(ARBITER_DATA_SIZE)
    )
    fixed_arbiter_stage2 (
        .clk(clk), .rst_n(rst_n),  

        .src_request_i(src_request_temp), 
        .src_data_i(src_data_arbiter),

        .last_input_done_i(last_input_done_wire_from_skip_unit),

        // .src_ready_o(src_ready_out),
        .src_grant_o(src_grant_out),
        .last_input_done_o(last_input_done_wire_from_arbiter),

        .stall_from_arbiter(stall_from_arbiter),
        .stall_backpressure(stall_backpressure),

        .dst_valid_o(valid_to_gradient_unit),  // .dst_ready_i(!stall_backpressure), 
        .dst_data_o(arbiter_data_out)
     );

    
    generate
        for (genvar i = 0; i < gaussian_inputs; i++) begin : gen_arbiter_inputs
            assign src_request_temp[i] = skip_and_alpha_done_out[i] & !skip_wire[i]; // Use ~ instead of ! for bitwise NOT
            assign src_data_arbiter[i] = {G_wire[i],                  // 1*precision
                                        d_wire[i],                    // 2*precision  
                                        conic_opacity_wire[i],        // 4*precision
                                        alpha_wire[i],                // 1*precision
                                        gaussian_color_wire[i],       // 3*precision
                                        gaussian_depth_wire[i],       // 1*precision
                                        gaussian_id_wire[i]};         // GID_bit
        end
    endgenerate
    
    assign {G_to_gradient_unit, d_to_gradient_unit, conic_opacity_to_gradient_unit, alpha_to_gradient_unit, gaussian_color_to_gradient_unit, gaussian_depth_to_gradient_unit, gaussian_id_to_gradient_unit} = arbiter_data_out;
    
     // Phase 3 Gradient Unit
    gradient_unit #( 
        .BLOCK_SIZE(BLOCK_SIZE), 
        .exponent_bit(exponent_bit), 
        .mantissa_bit(mantissa_bit), 
        .precision(precision), 
        .GID_bit(GID_bit) 
    )    
    gradient_unit_stage3 (
        .clk(clk), .rst_n(rst_n), 
        .G(G_to_gradient_unit), 
        .d(d_to_gradient_unit), 
        .conic_opacity(conic_opacity_to_gradient_unit), 
        .alpha_in(alpha_to_gradient_unit),
        .gaussian_color(gaussian_color_to_gradient_unit), 
        .gaussian_depth(gaussian_depth_to_gradient_unit), 
        .gaussian_id_in(gaussian_id_to_gradient_unit),
        .i_valid(valid_to_gradient_unit), 
        .start(start), 
        .T_first(T_first), 
        .W(W), 
        .H(H),
        .dL_dpixel(dL_dpixel), 
        .dL_dpixel_depth(dL_dpixel_depth),
        .stall(stall_backpressure),
        .last_input(last_input_done_wire_from_arbiter),

        // Output
        .dL_dcolor(dL_dcolor_out), 
        .dL_ddepth(dL_ddepth_out), 
        .dL_dmean2D(dL_dmean2D_out), 
        .dL_dconic(dL_dconic_out), 
        .dL_dopacity(dL_dopacity_out),
        .gaussian_id_out(gaussian_id_out),
        .gradient_valid_out(gradient_valid_out),
        .last_input_done(last_input_done)
        );

endmodule