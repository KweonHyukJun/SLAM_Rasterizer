module Pixel_Group_ctrl
    #(       
        parameter BLOCK_SIZE = 16,
        parameter exponent_bit = 8,
        parameter mantissa_bit = 7,
        parameter precision = 16,


        parameter group_gaussians = 32,
        parameter group_pixels = 16,

        parameter gaussians_to_pixels = 2
    ) 
(
    input wire clk,
    input wire rst_n,



    // input wire [31:0] pixel_touches [( max_H * max_W)-1:0], 필요한가?

    // From Block Ctrl
    input wire [11:0] W,
    input wire [11:0] H,
    input wire [15:0] block_id,

    input wire [31:0] gaussian_id_from_Block_Ctrl [group_gaussians - 1 :0], // gaussian range만큼 만들어야 함
    input wire [(2*precision)-1 :0] mean2D_from_Block_Ctrl [group_gaussians - 1 :0], // gaussian range만큼 만들어야 함
    input wire [(4*precision)-1 :0] conic_opacity_from_Block_Ctrl [group_gaussians - 1 :0],
    input wire [(3*precision)-1 :0] gaussian_color_from_Block_Ctrl [group_gaussians - 1 :0],
    input wire [precision-1 :0] gaussian_depth_from_Block_Ctrl [group_gaussians - 1 :0],
    
    input wire [31:0] Final_T_from_Block_Ctrl [ group_pixels -1:0],
    input wire [(3*precision)-1 :0] dL_dpixel_from_Block_Ctrl [group_pixels - 1:0],
    input wire [precision-1 :0] dL_dpixel_depth_from_Block_Ctrl [group_pixels - 1:0],
    
    // To Block Ctrl
    output reg Block_ctrl_ready,
    output reg Block_ctrl_gradient_valid,

    output reg gaussian_id_out_to_Block_Ctrl [group_gaussians - 1 :0],
    output reg [(2 * precision) - 1:0] dL_dmean2D_to_Block_Ctrl [group_gaussians - 1 :0], // fp | X | Y |
    output reg [(4 * precision) - 1:0] dL_dconic_to_Block_Ctrl [group_gaussians - 1 :0], // fp | X | Y | Z | W |
    output reg [precision - 1:0] dL_dopacity_to_Block_Ctrl [group_gaussians - 1 :0], // fp 
    output reg [(3 * precision) - 1:0] dL_dcolor_to_Block_Ctrl [group_gaussians - 1 :0], // fp | R | G | B |
    output reg [precision - 1:0] dL_ddepth_to_Block_Ctrl [group_gaussians - 1 :0], // fp


    // From Rasterizer Unit
    input wire Rasterizer_valid,
    // input wire Rasterizer_done,
    input wire [31:0] gaussian_id_from_Pixel_unit [group_pixels-1:0],
    input wire [(2 * precision) - 1:0] dL_dmean2D_from_Pixel_unit [group_pixels-1:0], // fp | X | Y |
    input wire [(4 * precision) - 1:0] dL_dconic_from_Pixel_unit [group_pixels-1:0], // fp | X | Y | Z | W |
    input wire [precision - 1:0] dL_dopacity_from_Pixel_unit [group_pixels-1:0], // fp 
    input wire [(3 * precision) - 1:0] dL_dcolor_from_Pixel_unit [group_pixels-1:0], // fp | R | G | B |
    input wire [precision - 1:0] dL_ddepth_from_Pixel_unit [group_pixels-1:0], // fp

    // To Rasterizer Unit
    output reg [31:0] gaussian_id_to_Pixel_unit [group_pixels-1:0][gaussians_to_pixels-1:0] , // [줘야할 채널수][줘야할 gaussian수]
    output reg [(2 * precision) - 1:0] dL_dmean2D_to_Pixel_unit [group_pixels-1:0][gaussians_to_pixels-1:0] , 
    output reg [(4 * precision) - 1:0] dL_dconic_to_Pixel_unit [group_pixels-1:0][gaussians_to_pixels-1:0] , 
    output reg [precision - 1:0] dL_dopacity_to_Pixel_unit [group_pixels-1:0][gaussians_to_pixels-1:0] , 
    output reg [(3 * precision) - 1:0] dL_dcolor_to_Pixel_unit [group_pixels-1:0][gaussians_to_pixels-1:0] , 
    output reg [precision - 1:0] dL_ddepth_to_Pixel_unit [group_pixels-1:0][gaussians_to_pixels-1:0] ,

    output reg gaussian_valid [group_pixels-1:0]

    localparam [1:0]    IDLE = 2'b00,
                        PROCESSING = 2'b01,
                        DONE = 2'b10;
    
    reg [1:0] state, next_state;

    always_comb begin
        next_state = state;

        case (state)
            IDLE: begin
                Block_ctrl_ready = 1'b1;
                if (Block_ctrl_gradient_valid) begin
                    // Block에서 알아서 gaussian 범위 맞게 컨트롤해서 준다고 가정
                    next_state = PROCESSING;
                end
            end

            PROCESSING: begin
                Block_ctrl_ready = 1'b0;
                gaussian_valid[group_pixels-1:0] = 1'b1;

                if () begin // 내부 신호로 모든 채널 gaussian 저장량 다 줬다고 가정시 ? 
                    

                end


            end

            DONE : begin


            end

            default: begin
                next_state = IDLE; // Safe default state
            end
        endcase 
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state = IDLE;
        end

        else begin
            state = next_state;
        end
    end



endmodule