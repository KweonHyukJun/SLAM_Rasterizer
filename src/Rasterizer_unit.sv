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
        parameter mantissa_bit = 7,
        parameter precision = 16,
        parameter input_gaussians_to_pixel = 4
    )
(
    // input wire
    input logic clk,
    input logic rst_n,
    
    // input logic done, // 어차피 일 안하면 valid로 제어 가능, done 신호 불필요

    input logic [11:0] W, 
    input logic [11:0] H,




    // pixel dimension

    input logic i_valid,

    // 픽셀 처음 시작시에만 주면 되는 값들
    // input logic start [input_gaussians_to_pixel-1:0], // 시작시에만 Block id, pixel id , dL_dpixel, dL_dpixel_depth, 초기 T 값 이후 필요 없음. (Register 내부에서 사용)
    input logic start,

    input logic [15:0] block_id, // block index x at [0] y at [1]  // 1920 이 16x16 으로 분해시 120이니까 최대 비트 7개면 가능 (32비트 쓰지말고)
    input logic [(2 * $clog2(BLOCK_SIZE) - 1): 0] pixel_id [input_gaussians_to_pixel-1:0],
    input logic [(3 * precision) - 1:0] dL_dpixel, //fp32 | R | G | B |
    input logic [precision - 1:0] dL_dpixel_depth, //fp32
    input logic [precision - 1:0] T_first [input_gaussians_to_pixel-1:0],



    input logic stall_backpressure,


    // input logic [(3 * precision) - 1 : 0] background_color, //fp32 | R | G | B |

    input logic [(2 * precision) - 1:0] mean2D [input_gaussians_to_pixel-1:0], //fp32 | X | Y | 
    input logic [(4 * precision) - 1:0] conic_opacity [input_gaussians_to_pixel-1:0], // fp32 | X | Y | Z | W |

    

    input logic [31:0] gaussian_id [input_gaussians_to_pixel-1:0],

    input logic [(3 * precision) - 1:0] gaussian_color [input_gaussians_to_pixel-1:0], //fp32 | R | G | B |
    input logic [precision - 1 : 0] gaussian_depth [input_gaussians_to_pixel-1:0], //fp32

    // output reg
    output logic [(2 * precision) - 1:0] dL_dmean2D_out, // fp32 | X | Y |
    output logic [(4 * precision) - 1:0] dL_dconic_out, // fp32 | X | Y | Z | W |
    output logic [precision - 1:0] dL_dopacity_out, // fp32 
    output logic [(3 * precision) - 1:0] dL_dcolor_out, // fp32 | R | G | B |
    output logic [precision - 1:0] dL_ddepth_out, // fp32

    // output logic [31:0] gaussian_id_out, // 나가는 gaussian ID도 명시해야함.

    output logic gradient_valid,
    // output reg skip

    output logic stage1_stall // Wire, stall signal for input

    );

    localparam stage1_latency = 7;
    localparam stage2_latency = 9;
    // gaussian ID 기록해서 Gradient 계산 후 반환해야함

    // | ---------------->>>> forward path  ---------------->>>> |
    // | <<<<---------------- backward path <<<<---------------- |
    //         | (next)
    //             | (current)
    
    // Register decalaration
    // 초기값을 2번째에 넘기려면 필요함 
    // T_final, gaussian color, id , depth, dL_dpixel, dL_dpixel_depth 등등...
    // 몇 사이클을 쉬어야 할까

    // logic [precision - 1:0] T_first0 [input_gaussians_to_pixel-1:0], T_first1 [input_gaussians_to_pixel-1:0], T_first2 [input_gaussians_to_pixel-1:0], T_first3 [input_gaussians_to_pixel-1:0], T_first4, T_first5, T_first6, T_first7;
    // logic start0, start1, start2, start3, start4, start5, start6, start7;
    // logic [precision - 1:0] gaussian_depth0, gaussian_depth1, gaussian_depth2, gaussian_depth3, gaussian_depth4, gaussian_depth5, gaussian_depth6, gaussian_depth7;
    // logic [(3 * precision) - 1:0] gaussian_color0, gaussian_color1, gaussian_color2, gaussian_color3, gaussian_color4, gaussian_color5, gaussian_color6, gaussian_color7;
    // logic [31:0] gaussian_id0, gaussian_id1, gaussian_id2, gaussian_id3, gaussian_id4, gaussian_id5, gaussian_id6, gaussian_id7;
    // logic [(3 * precision) - 1:0] dL_dpixel0, dL_dpixel1, dL_dpixel2, dL_dpixel3, dL_dpixel4, dL_dpixel5, dL_dpixel6, dL_dpixel7;
    // logic [precision - 1:0] dL_dpixel_depth0, dL_dpixel_depth1, dL_dpixel_depth2, dL_dpixel_depth3, dL_dpixel_depth4, dL_dpixel_depth5, dL_dpixel_depth6, dL_dpixel_depth7;
    // logic early_skip6, early_skip7;

    logic [precision - 1:0] T_first0   [input_gaussians_to_pixel-1:0];
    logic [precision - 1:0] T_first1   [input_gaussians_to_pixel-1:0];
    logic [precision - 1:0] T_first2   [input_gaussians_to_pixel-1:0];
    logic [precision - 1:0] T_first3   [input_gaussians_to_pixel-1:0];
    logic [precision - 1:0] T_first4   [input_gaussians_to_pixel-1:0];
    logic [precision - 1:0] T_first5   [input_gaussians_to_pixel-1:0];
    logic [precision - 1:0] T_first6   [input_gaussians_to_pixel-1:0];
    logic [precision - 1:0] T_first7   [input_gaussians_to_pixel-1:0];

    logic start0    [input_gaussians_to_pixel-1:0];
    logic start1    [input_gaussians_to_pixel-1:0];
    logic start2    [input_gaussians_to_pixel-1:0];
    logic start3    [input_gaussians_to_pixel-1:0];
    logic start4    [input_gaussians_to_pixel-1:0];
    logic start5    [input_gaussians_to_pixel-1:0];
    logic start6    [input_gaussians_to_pixel-1:0];
    logic start7    [input_gaussians_to_pixel-1:0];

    logic [precision - 1:0] gaussian_depth0 [input_gaussians_to_pixel-1:0];
    logic [precision - 1:0] gaussian_depth1 [input_gaussians_to_pixel-1:0];
    logic [precision - 1:0] gaussian_depth2 [input_gaussians_to_pixel-1:0];
    logic [precision - 1:0] gaussian_depth3 [input_gaussians_to_pixel-1:0];
    logic [precision - 1:0] gaussian_depth4 [input_gaussians_to_pixel-1:0];
    logic [precision - 1:0] gaussian_depth5 [input_gaussians_to_pixel-1:0];
    logic [precision - 1:0] gaussian_depth6 [input_gaussians_to_pixel-1:0];
    logic [precision - 1:0] gaussian_depth7 [input_gaussians_to_pixel-1:0];

    logic [(3 * precision) - 1:0] gaussian_color0 [input_gaussians_to_pixel-1:0];
    logic [(3 * precision) - 1:0] gaussian_color1 [input_gaussians_to_pixel-1:0];
    logic [(3 * precision) - 1:0] gaussian_color2 [input_gaussians_to_pixel-1:0];
    logic [(3 * precision) - 1:0] gaussian_color3 [input_gaussians_to_pixel-1:0];
    logic [(3 * precision) - 1:0] gaussian_color4 [input_gaussians_to_pixel-1:0];
    logic [(3 * precision) - 1:0] gaussian_color5 [input_gaussians_to_pixel-1:0];
    logic [(3 * precision) - 1:0] gaussian_color6 [input_gaussians_to_pixel-1:0];
    logic [(3 * precision) - 1:0] gaussian_color7 [input_gaussians_to_pixel-1:0];

    logic [31:0] gaussian_id0  [input_gaussians_to_pixel-1:0];
    logic [31:0] gaussian_id1  [input_gaussians_to_pixel-1:0];
    logic [31:0] gaussian_id2  [input_gaussians_to_pixel-1:0];
    logic [31:0] gaussian_id3  [input_gaussians_to_pixel-1:0];
    logic [31:0] gaussian_id4  [input_gaussians_to_pixel-1:0];
    logic [31:0] gaussian_id5  [input_gaussians_to_pixel-1:0];
    logic [31:0] gaussian_id6  [input_gaussians_to_pixel-1:0];
    logic [31:0] gaussian_id7  [input_gaussians_to_pixel-1:0];

    logic [(3 * precision) - 1:0] dL_dpixel0  [input_gaussians_to_pixel-1:0];
    logic [(3 * precision) - 1:0] dL_dpixel1  [input_gaussians_to_pixel-1:0];
    logic [(3 * precision) - 1:0] dL_dpixel2  [input_gaussians_to_pixel-1:0];
    logic [(3 * precision) - 1:0] dL_dpixel3  [input_gaussians_to_pixel-1:0];
    logic [(3 * precision) - 1:0] dL_dpixel4  [input_gaussians_to_pixel-1:0];
    logic [(3 * precision) - 1:0] dL_dpixel5  [input_gaussians_to_pixel-1:0];
    logic [(3 * precision) - 1:0] dL_dpixel6  [input_gaussians_to_pixel-1:0];
    logic [(3 * precision) - 1:0] dL_dpixel7  [input_gaussians_to_pixel-1:0];

    logic [precision - 1:0] dL_dpixel_depth0 [input_gaussians_to_pixel-1:0];
    logic [precision - 1:0] dL_dpixel_depth1 [input_gaussians_to_pixel-1:0];
    logic [precision - 1:0] dL_dpixel_depth2 [input_gaussians_to_pixel-1:0];
    logic [precision - 1:0] dL_dpixel_depth3 [input_gaussians_to_pixel-1:0];
    logic [precision - 1:0] dL_dpixel_depth4 [input_gaussians_to_pixel-1:0];
    logic [precision - 1:0] dL_dpixel_depth5 [input_gaussians_to_pixel-1:0];
    logic [precision - 1:0] dL_dpixel_depth6 [input_gaussians_to_pixel-1:0];
    logic [precision - 1:0] dL_dpixel_depth7 [input_gaussians_to_pixel-1:0];

    logic early_skip6  [input_gaussians_to_pixel-1:0];
    logic early_skip7  [input_gaussians_to_pixel-1:0];

    logic [11:0] H0;
    logic [11:0] H1;
    logic [11:0] H2;
    logic [11:0] H3;
    logic [11:0] H4;
    logic [11:0] H5;
    logic [11:0] H6;

    logic [11:0] W0;
    logic [11:0] W1;
    logic [11:0] W2;
    logic [11:0] W3;
    logic [11:0] W4;
    logic [11:0] W5;
    logic [11:0] W6;

    // wire declaration
    // logic [precision - 1:0] G_wire;
    // logic [(2 * precision) - 1:0] d_wire;
    // logic [precision - 1:0] alpha_wire;
    // logic skip_wire;
    // logic [(4 * precision) - 1:0] conic_opacity_wire;
    // logic skip_and_alpha_done_and_total_gradient_valid;


    // logic [(3 * precision) - 1:0] dL_dcolor_wire;
    // logic [precision - 1:0] dL_ddepth_wire, dL_dopacity_wire;
    // logic [(2 * precision) - 1:0] dL_dmean2D_wire;
    // logic [(4 * precision) - 1:0] dL_dconic_wire;
    // logic gradient_valid_out;
    // logic early_skip_from_stage1;

    logic [precision - 1:0] G_wire [input_gaussians_to_pixel-1:0];
    logic [(2 * precision) - 1:0] d_wire [input_gaussians_to_pixel-1:0];
    logic [precision - 1:0] alpha_wire [input_gaussians_to_pixel-1:0];
    logic skip_wire [input_gaussians_to_pixel-1:0];
    logic [(4 * precision) - 1:0] conic_opacity_wire [input_gaussians_to_pixel-1:0];
    logic skip_and_alpha_done_and_total_gradient_valid [input_gaussians_to_pixel-1:0];

    logic [(3 * precision) - 1:0] dL_dcolor_wire;
    logic [precision - 1:0] dL_ddepth_wire;
    logic [precision - 1:0] dL_dopacity_wire;
    logic [(2 * precision) - 1:0] dL_dmean2D_wire;
    logic [(4 * precision) - 1:0] dL_dconic_wire;
    logic gradient_valid_out;
    logic early_skip_from_stage1 [input_gaussians_to_pixel-1:0];
    logic stall_from_arbiter;
    logic valid_to_gradient_unit;
    
    assign stage1_stall = stall_backpressure || stall_from_arbiter;
    
    //skip and alpha module
    // Phase 1 alpha and skip Logic
    skip_unit #( .BLOCK_SIZE(BLOCK_SIZE), .exponent_bit(exponent_bit), .mantissa_bit(mantissa_bit), .precision(precision), .inputs(input_gaussians_to_pixel)) 
    skip_unit_stage1 (.clk(clk), .rst_n(rst_n), .block_id(block_id), .mean2D(mean2D), .conic_opacity(conic_opacity), .pixel_id(pixel_id), .i_valid(i_valid), .early_skip(early_skip_from_stage1), // stage 5에서 나옴
    .stall(stage1_stall),

    .skip_out(skip_wire), .G_out(G_wire), .d_out(d_wire), .alpha_out(alpha_wire), .conic_opacity_out(conic_opacity_wire),
    .skip_and_alpha_done_out(skip_and_alpha_done_and_total_gradient_valid)

    );


    localparam ARBITER_DATA_SIZE = 12 * precision + 32; // G(1), d(2), conic_opacity(4), alpha(1), gaussian_color(3) / depth(1) // id(32)
    // Phase 2, Skip Arbitration
    Fixed_Arbiter #(.N_MASTER(input_gaussians_to_pixel), .DATA_SIZE(ARBITER_DATA_SIZE))
     Arbiter (.clk(clk), .rst_n(rst_n), 
     .src_valid_i(skip_and_alpha_done_and_total_gradient_valid && !skip_wire), 
     .src_data_i(),

     .src_ready_o(stall_from_arbiter), 

     .dst_valid_o(valid_to_gradient_unit), .dst_ready_i(!stall_backpressure), 
     .dst_data_o()
     );

    



    // Phase 3, Gradient Logic
    // background 추가 처리 필요 (이거를 있다고 해야되나)
    gradient_unit #( .BLOCK_SIZE(BLOCK_SIZE), .exponent_bit(exponent_bit), .mantissa_bit(mantissa_bit), .precision(precision)) 
    gradient_unit_stage2 (.clk(clk), .rst_n(rst_n), .W(W6), .H(H6), .G(G_wire), .d(d_wire), .conic_opacity(conic_opacity_wire), .alpha_in(alpha_wire),
    .T_first(T_first6), .start(start6), .gaussian_color(gaussian_color6), .gaussian_depth(gaussian_depth6), 

    .i_valid(valid_to_gradient_unit),
    .dL_dpixel(dL_dpixel), .dL_dpixel_depth(dL_dpixel_depth),
    .stall(stall_backpressure),

    .dL_dcolor(dL_dcolor_wire), .dL_ddepth(dL_ddepth_wire), .dL_dmean2D(dL_dmean2D_wire), .dL_dconic(dL_dconic_wire), .dL_dopacity(dL_dopacity_wire),
    .gradient_valid_out(gradient_valid_out)
    );

    // clock
    always_ff @ (posedge clk) begin
        if (!rst_n) begin
            // Reset Output Registers
            dL_dmean2D_out <= '{default: 'h0};  // Reset all input_gaussians_to_pixel elements to 0
            dL_dconic_out <= '{default: 'h0};
            dL_dopacity_out <= '{default: 'h0};
            dL_dcolor_out <= '{default: 'h0};
            dL_ddepth_out <= '{default: 'h0};
            gradient_valid <= '{default: 1'b0};  // Reset all valid flags

            // Reset Internal Registers (T_first, Gaussian, etc.)
            T_first0 <= '{default: 'h0}; T_first1 <= '{default: 'h0};
            T_first2 <= '{default: 'h0}; T_first3 <= '{default: 'h0};
            T_first4 <= '{default: 'h0}; T_first5 <= '{default: 'h0};
            T_first6 <= '{default: 'h0}; T_first7 <= '{default: 'h0};

            start0 <= '{default: 1'b0}; start1 <= '{default: 1'b0};
            start2 <= '{default: 1'b0}; start3 <= '{default: 1'b0};
            start4 <= '{default: 1'b0}; start5 <= '{default: 1'b0};
            start6 <= '{default: 1'b0}; start7 <= '{default: 1'b0};

            gaussian_depth0 <= '{default: 'h0}; gaussian_depth1 <= '{default: 'h0};
            gaussian_depth2 <= '{default: 'h0}; gaussian_depth3 <= '{default: 'h0};
            gaussian_depth4 <= '{default: 'h0}; gaussian_depth5 <= '{default: 'h0};
            gaussian_depth6 <= '{default: 'h0}; gaussian_depth7 <= '{default: 'h0};

            gaussian_color0 <= '{default: 'h0}; gaussian_color1 <= '{default: 'h0};
            gaussian_color2 <= '{default: 'h0}; gaussian_color3 <= '{default: 'h0};
            gaussian_color4 <= '{default: 'h0}; gaussian_color5 <= '{default: 'h0};
            gaussian_color6 <= '{default: 'h0}; gaussian_color7 <= '{default: 'h0};

            gaussian_id0 <= '{default: 'h0}; gaussian_id1 <= '{default: 'h0};
            gaussian_id2 <= '{default: 'h0}; gaussian_id3 <= '{default: 'h0};
            gaussian_id4 <= '{default: 'h0}; gaussian_id5 <= '{default: 'h0};
            gaussian_id6 <= '{default: 'h0}; gaussian_id7 <= '{default: 'h0};

            dL_dpixel0 <= '{default: 'h0}; dL_dpixel1 <= '{default: 'h0};
            dL_dpixel2 <= '{default: 'h0}; dL_dpixel3 <= '{default: 'h0};
            dL_dpixel4 <= '{default: 'h0}; dL_dpixel5 <= '{default: 'h0};
            dL_dpixel6 <= '{default: 'h0}; dL_dpixel7 <= '{default: 'h0};

            dL_dpixel_depth0 <= '{default: 'h0}; dL_dpixel_depth1 <= '{default: 'h0};
            dL_dpixel_depth2 <= '{default: 'h0}; dL_dpixel_depth3 <= '{default: 'h0};
            dL_dpixel_depth4 <= '{default: 'h0}; dL_dpixel_depth5 <= '{default: 'h0};
            dL_dpixel_depth6 <= '{default: 'h0}; dL_dpixel_depth7 <= '{default: 'h0};

            early_skip6 <= '{default: 1'b0}; early_skip7 <= '{default: 1'b0};

            H0 <= '{default: 'h0}; H1 <= '{default: 'h0};
            H2 <= '{default: 'h0}; H3 <= '{default: 'h0};
            H4 <= '{default: 'h0}; H5 <= '{default: 'h0};
            H6 <= '{default: 'h0};

            W0 <= '{default: 'h0}; W1 <= '{default: 'h0};
            W2 <= '{default: 'h0}; W3 <= '{default: 'h0};
            W4 <= '{default: 'h0}; W5 <= '{default: 'h0};
            W6 <= '{default: 'h0};
    
        end
        else begin
            if (!stall) begin
                ////////////////////////////////////////////////////////////////////
                ///////////////////////// Clock 1 Data Input ///////////////////////
                ////////////////////////////////////////////////////////////////////
                for (int i = 0; i < input_gaussians_to_pixel; i++) begin
                    T_first0[i] <= T_first[i];
                    start0[i] <= start[i];
                    gaussian_color0[i] <= gaussian_color[i];
                    gaussian_depth0[i] <= gaussian_depth[i];
                    gaussian_id0[i] <= gaussian_id[i];
                end

                    dL_dpixel0 <= dL_dpixel;
                    dL_dpixel_depth0 <= dL_dpixel_depth;
                    H0 <= H;
                    W0 <= W;


                ////////////////////////////////////////////////////////////////////
                ///////////////////////// Clock 2 Data Input ///////////////////////
                ////////////////////////////////////////////////////////////////////
                for (int i = 0; i < input_gaussians_to_pixel; i++) begin
                    T_first1[i] <= T_first0[i];
                    start1[i] <= start0[i];
                    gaussian_color1[i] <= gaussian_color0[i];
                    gaussian_depth1[i] <= gaussian_depth0[i];
                    gaussian_id1[i] <= gaussian_id0[i];
                end

                    dL_dpixel1 <= dL_dpixel0;
                    dL_dpixel_depth1 <= dL_dpixel_depth0;
                    H1 <= H0;
                    W1 <= W0;

                ////////////////////////////////////////////////////////////////////
                ///////////////////////// Clock 3 Data Input ///////////////////////
                ////////////////////////////////////////////////////////////////////
                for (int i = 0; i < input_gaussians_to_pixel; i++) begin
                    T_first2[i] <= T_first1[i];
                    start2[i] <= start1[i];
                    gaussian_color2[i] <= gaussian_color1[i];
                    gaussian_depth2[i] <= gaussian_depth1[i];
                    gaussian_id2[i] <= gaussian_id1[i];
                end
                    dL_dpixel2 <= dL_dpixel1;
                    dL_dpixel_depth2 <= dL_dpixel_depth1;
                    H2 <= H1;
                    W2 <= W1;

                ////////////////////////////////////////////////////////////////////
                ///////////////////////// Clock 4 Data Input ///////////////////////
                ////////////////////////////////////////////////////////////////////

                for (int i = 0; i < input_gaussians_to_pixel; i++) begin
                    T_first3[i] <= T_first2[i];
                    start3[i] <= start2[i];
                    gaussian_color3[i] <= gaussian_color2[i];
                    gaussian_depth3[i] <= gaussian_depth2[i];
                    gaussian_id3[i] <= gaussian_id2[i];
                end
                    dL_dpixel3 <= dL_dpixel2;
                    dL_dpixel_depth3 <= dL_dpixel_depth2;
                    H3 <= H2;
                    W3 <= W2;


                ////////////////////////////////////////////////////////////////////
                ///////////////////////// Clock 5 Data Input ///////////////////////
                ////////////////////////////////////////////////////////////////////

                for (int i = 0; i < input_gaussians_to_pixel; i++) begin
                    T_first4[i] <= T_first3[i];
                    start4[i] <= start3[i];
                    gaussian_color4[i] <= gaussian_color3[i];
                    gaussian_depth4[i] <= gaussian_depth3[i];
                    gaussian_id4[i] <= gaussian_id3[i];
                end
                    dL_dpixel4 <= dL_dpixel3;
                    dL_dpixel_depth4 <= dL_dpixel_depth3;
                    H4 <= H3;
                    W4 <= W3;

                ////////////////////////////////////////////////////////////////////
                ///////////////////////// Clock 6 Data Input ///////////////////////
                ////////////////////////////////////////////////////////////////////

                for (int i = 0; i < input_gaussians_to_pixel; i++) begin
                    T_first5[i] <= T_first4[i];
                    start5[i] <= start4[i];
                    gaussian_color5[i] <= gaussian_color4[i];
                    gaussian_depth5[i] <= gaussian_depth4[i];
                    gaussian_id5[i] <= gaussian_id4[i];
                    early_skip6[i] <= early_skip_from_stage1[i];
                end
                    dL_dpixel5 <= dL_dpixel4;
                    dL_dpixel_depth5 <= dL_dpixel_depth4;
                    H5 <= H4;
                    W5 <= W4;


                ////////////////////////////////////////////////////////////////////
                //////////////// Clock 7 Data Input (input to Stage 3)//////////////
                ////////////////////////////////////////////////////////////////////

                for (int i = 0; i < input_gaussians_to_pixel; i++) begin
                    T_first6[i] <= T_first5[i];
                    start6[i] <= start5[i];
                    gaussian_color6[i] <= gaussian_color5[i];
                    gaussian_depth6[i] <= gaussian_depth5[i];
                    gaussian_id6[i] <= gaussian_id5[i];
                    early_skip7[i] <= early_skip6[i];
                end
                    dL_dpixel6 <= dL_dpixel5;
                    dL_dpixel_depth6 <= dL_dpixel_depth5;
                    H6 <= H5;
                    W6 <= W5;

                ////////////////////////////////////////////////////////////////////
                ///////////////////// Clock 17 Final Data output ///////////////////
                ////////////////////////////////////////////////////////////////////
                for (int i = 0; i < input_gaussians_to_pixel; i++) begin
                    dL_dcolor_out <= dL_dcolor_wire;
                    dL_ddepth_out <= dL_ddepth_wire;
                    dL_dmean2D_out <= dL_dmean2D_wire;
                    dL_dconic_out <= dL_dconic_wire;
                    dL_dopacity_out <= dL_dopacity_wire;
                    gradient_valid <= gradient_valid_out && !stall_backpressure;
                end
            end
        end
    end

    // always_ff @ (posedge clk) begin
    //     if (!rst_n) begin
    //         // Reset Output Registers
    //         dL_dmean2D_out <= 'h0;
    //         dL_dconic_out <= 'h0;
    //         dL_dopacity_out <= 'h0;
    //         dL_dcolor_out <= 'h0;
    //         dL_ddepth_out <= 'h0;

    //         gradient_valid <= 1'b0;
    //         // skip <= 1'b0;

    //         // Reset Internal Registers (T_first, Gaussian, etc.)
    //         T_first0 <= 'h0; T_first1 <= 'h0; T_first2 <= 'h0; T_first3 <= 'h0;
    //         T_first4 <= 'h0; T_first5 <= 'h0; T_first6 <= 'h0; T_first7 <= 'h0;

    //         start0 <= 1'b0; start1 <= 1'b0;
    //         start2 <= 1'b0; start3 <= 1'b0;
    //         start4 <= 1'b0; start5 <= 1'b0;
    //         start6 <= 1'b0; start7 <= 1'b0;

    //         gaussian_depth0 <= 'h0; gaussian_depth1 <= 'h0;
    //         gaussian_depth2 <= 'h0; gaussian_depth3 <= 'h0;
    //         gaussian_depth4 <= 'h0; gaussian_depth5 <= 'h0;
    //         gaussian_depth6 <= 'h0; gaussian_depth7 <= 'h0;

    //         gaussian_color0 <= 'h0; gaussian_color1 <= 'h0;
    //         gaussian_color2 <= 'h0; gaussian_color3 <= 'h0;
    //         gaussian_color4 <= 'h0; gaussian_color5 <= 'h0;
    //         gaussian_color6 <= 'h0; gaussian_color7 <= 'h0;

    //         gaussian_id0 <= 'h0; gaussian_id1 <= 'h0;
    //         gaussian_id2 <= 'h0; gaussian_id3 <= 'h0;
    //         gaussian_id4 <= 'h0; gaussian_id5 <= 'h0;
    //         gaussian_id6 <= 'h0; gaussian_id7 <= 'h0;

    //         dL_dpixel0 <= 'h0; dL_dpixel1 <= 'h0;
    //         dL_dpixel2 <= 'h0; dL_dpixel3 <= 'h0;
    //         dL_dpixel4 <= 'h0; dL_dpixel5 <= 'h0;
    //         dL_dpixel6 <= 'h0; dL_dpixel7 <= 'h0;

    //         dL_dpixel_depth0 <= 'h0; dL_dpixel_depth1 <= 'h0;
    //         dL_dpixel_depth2 <= 'h0; dL_dpixel_depth3 <= 'h0;
    //         dL_dpixel_depth4 <= 'h0; dL_dpixel_depth5 <= 'h0;
    //         dL_dpixel_depth6 <= 'h0; dL_dpixel_depth7 <= 'h0;

    //         early_skip6 <= 'b0; early_skip7 <= 'b0;
    //     end

    //     else begin

    //         if (!stall) begin
    //             ////////////////////////////////////////////////////////////////////
    //             ///////////////////////// Clock 1 Data Input ///////////////////////
    //             ////////////////////////////////////////////////////////////////////

    //             T_first0 <= T_first;
    //             start0 <= start;
    //             gaussian_color0 <= gaussian_color;
    //             gaussian_depth0 <= gaussian_depth;
    //             gaussian_id0 <= gaussian_id;
    //             dL_dpixel0 <= dL_dpixel;
    //             dL_dpixel_depth0 <= dL_dpixel_depth;

    //             ////////////////////////////////////////////////////////////////////
    //             ///////////////////////// Clock 2 Data Input ///////////////////////
    //             ////////////////////////////////////////////////////////////////////

    //             T_first1 <= T_first0;
    //             start1 <= start0;
    //             gaussian_color1 <= gaussian_color0;
    //             gaussian_depth1 <= gaussian_depth0;
    //             gaussian_id1 <= gaussian_id0;
    //             dL_dpixel1 <= dL_dpixel0;
    //             dL_dpixel_depth1 <= dL_dpixel_depth0;

    //             ////////////////////////////////////////////////////////////////////
    //             ///////////////////////// Clock 3 Data Input ///////////////////////
    //             ////////////////////////////////////////////////////////////////////

    //             T_first2 <= T_first1;
    //             start2 <= start1;
    //             gaussian_color2 <= gaussian_color1;
    //             gaussian_depth2 <= gaussian_depth1;
    //             gaussian_id2 <= gaussian_id1;
    //             dL_dpixel2 <= dL_dpixel1;
    //             dL_dpixel_depth2 <= dL_dpixel_depth1;

    //             ////////////////////////////////////////////////////////////////////
    //             ///////////////////////// Clock 4 Data Input ///////////////////////
    //             ////////////////////////////////////////////////////////////////////

    //             T_first3 <= T_first2;
    //             start3 <= start2;
    //             gaussian_color3 <= gaussian_color2;
    //             gaussian_depth3 <= gaussian_depth2;
    //             gaussian_id3 <= gaussian_id2;
    //             dL_dpixel3 <= dL_dpixel2;
    //             dL_dpixel_depth3 <= dL_dpixel_depth2;

    //             ////////////////////////////////////////////////////////////////////
    //             ///////////////////////// Clock 5 Data Input ///////////////////////
    //             ////////////////////////////////////////////////////////////////////

    //             T_first4 <= T_first3;
    //             start4 <= start3;
    //             gaussian_color4 <= gaussian_color3;
    //             gaussian_depth4 <= gaussian_depth3;
    //             gaussian_id4 <= gaussian_id3;
    //             dL_dpixel4 <= dL_dpixel3;
    //             dL_dpixel_depth4 <= dL_dpixel_depth3;

    //             ////////////////////////////////////////////////////////////////////
    //             ///////////////////////// Clock 6 Data Input ///////////////////////
    //             ////////////////////////////////////////////////////////////////////

    //             T_first5 <= T_first4;
    //             start5 <= start4;
    //             gaussian_color5 <= gaussian_color4;
    //             gaussian_depth5 <= gaussian_depth4;
    //             gaussian_id5 <= gaussian_id4;
    //             dL_dpixel5 <= dL_dpixel4;
    //             dL_dpixel_depth5 <= dL_dpixel_depth4;

    //             ////////////////////////////////////////////////////////////////////
    //             ///////////////////////// Clock 7 Data Input ///////////////////////
    //             ////////////////////////////////////////////////////////////////////

    //             T_first6 <= T_first5;
    //             start6 <= start5;
    //             gaussian_color6 <= gaussian_color5;
    //             gaussian_depth6 <= gaussian_depth5;
    //             gaussian_id6 <= gaussian_id5;
    //             dL_dpixel6 <= dL_dpixel5;
    //             dL_dpixel_depth6 <= dL_dpixel_depth5;

    //             early_skip6 <= early_skip_from_stage1;

    //             ////////////////////////////////////////////////////////////////////
    //             ///////////////////////// Clock 8 Data Input ///////////////////////
    //             ////////////////////////////////////////////////////////////////////

    //             T_first7 <= T_first6;
    //             start7 <= start6;
    //             gaussian_color7 <= gaussian_color6;
    //             gaussian_depth7 <= gaussian_depth6;
    //             gaussian_id7 <= gaussian_id6;
    //             dL_dpixel7 <= dL_dpixel6;
    //             dL_dpixel_depth7 <= dL_dpixel_depth6;

    //             early_skip7 <= early_skip6;



    //             ////////////////////////////////////////////////////////////////////
    //             ///////////////////// Clock 17 Final Data output ///////////////////
    //             ////////////////////////////////////////////////////////////////////

    //             dL_dcolor_out <= dL_dcolor_wire;
    //             dL_ddepth_out <= dL_ddepth_wire;
    //             dL_dmean2D_out <= dL_dmean2D_wire;
    //             dL_dconic_out <= dL_dconic_wire;
    //             dL_dopacity_out <= dL_dopacity_wire;
    //             gradient_valid <= gradient_valid_out;

    //         end
    //     end
    // end

endmodule