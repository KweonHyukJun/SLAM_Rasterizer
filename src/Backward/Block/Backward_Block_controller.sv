
// SRAM은 없다고 가정 (추가로 module화 해서 달 예정)
module Backward_Block_controller #(
    parameter BLOCK_SIZE = 16,
    parameter exponent_bit = 8,
    parameter mantissa_bit = 7,
    parameter precision = 16,
    parameter gaussian_inputs = 4, // in one pixel unit, gaussians
    parameter num_pixels = 16, // number of pixel units
    parameter GID_bit = 24,
    parameter WINDOW_SIZE = 32,
    parameter Banks = 16
    ) 

    (
    input wire clk,
    input wire rst_n,

    // Input from Top controller
        input wire Block_data_done,

        input wire gradient_value_ready,
        // input wire gradient_data_done, // gradient 관련 handshake에서 모든 데이터를 top에서 처리하였을 경우 반환

        input wire [11:0] W_in,
        input wire [11:0] H_in,
        input wire [15:0] block_id_in,

        input wire [GID_bit-1:0] last_gaussian_index_in, // SRAM에서의 Gaussian 범위를 알아낼 수 있도록 제작 0번은 NULL로 처리


    // Output to Top Controller
        output wire Block_data_ready,
        output wire gradient_value_valid,
        output wire gradient_value_done,


        // Input from Group Rasterizer
        input wire stall_to_controller_from_rasterizer [num_pixels-1:0],
        input wire last_input_done_from_rasterizer [Banks-1:0],


    // Output to Group Rasterizer

        // Gaussian Window value
        output reg i_valid [gaussian_inputs * num_pixels - 1:0],

        output reg last_input_done_to_pixel [gaussian_inputs * num_pixels - 1:0],
        output reg [GID_bit-1:0] gaussian_id_to_rasterizer [gaussian_inputs * num_pixels - 1:0],
        output reg [(3 * precision)-1:0] gaussian_color_to_rasterizer [gaussian_inputs * num_pixels - 1:0],
        output reg [precision-1:0] gaussian_depth_to_rasterizer [gaussian_inputs * num_pixels - 1:0],
        output reg [(2 * precision)-1:0] mean2D_to_rasterizer [gaussian_inputs * num_pixels - 1:0],
        output reg [(4 * precision)-1:0] conic_opacity_to_rasterizer [gaussian_inputs * num_pixels - 1:0],
        

        // pixel value
        output reg start [num_pixels-1:0], // 이거 컨트롤 신호, 유사 리셋의 느낌

        output reg [precision-1:0] T_first_current [num_pixels-1:0],
        output reg [(3 * precision)-1:0] dL_dpixel_current [num_pixels-1:0],
        output reg [precision-1:0] dL_dpixel_depth_current [num_pixels-1:0],
        output reg [(2 * $clog2(BLOCK_SIZE) - 1): 0] pixel_id_current [num_pixels-1:0],

        

    // Input from input gaussian SRAM
    input wire [(3 * precision) - 1:0] gaussian_color_from_SRAM,
    input wire [precision-1:0] gaussian_depth_from_SRAM,
    input wire [(2 * precision)-1:0] mean2D_from_SRAM,
    input wire [(4 * precision)-1:0] conic_opacity_from_SRAM,
    input wire [GID_bit-1:0] gaussian_id_from_SRAM, // 이거 그냥 hash? 그거 처리를 어디서 해야되는지는 추후 고민해야 할 사항

    input wire [GID_bit-1:0] Read_address_to_Gaussian_SRAM,

        
    // Output to input gaussian SRAM
        output wire REB_to_gaussian_SRAM,


    // Input from input Pixel SRAM
    input wire [GID_bit-1:0] next_n_contrib_from_SRAM,
    input wire [precision-1:0] next_T_first_from_SRAM,
    input wire [(3 * precision)-1:0] next_dL_dpixel_from_SRAM,
    input wire [precision-1:0] next_dL_dpixel_depth_from_SRAM,

    // Output to input Pixel SRAM
    output wire [2 * $clog2(num_pixels) - 1:0] Read_address_to_Pixel_SRAM,
    output wire REB_to_Pixel_SRAM,


    // Input from gradient merge SRAM
    output wire [GID_bit-1:0] Read_address_from_rasterizer_to_gradient_SRAM [Banks-1:0],


    // Output to gradient merge SRAM
        output wire REB_to_gradient_SRAM [Banks-1:0],
        output wire WEB_to_gradient_SRAM [Banks-1:0]
    );

    //////////////////////// Block Control ////////////////////////
    // Gradient Merge SRAM 관련 데이터를 직접 컨트롤
    // Pixel 및, Gaussian Window 관련 데이터는 간접적으로 컨트롤

        // FF Register
        reg [11:0] W;
        reg [11:0] H;
        reg [15:0] block_id;

        reg Block_state_current;
        reg Block_state_next;

        reg [$clog2(num_pixels):0] last_input_done_FF;
        reg [$clog2(num_pixels):0] row_FF;

        reg pixel_started;
        reg pixel_started_next;
        // 굳이 16개일 이유가?

            // State
            localparam  BLOCK_IDLE = 1'b0,
                        BLOCK_BUSY = 1'b1;

            // Combinational register (for control signal)
            reg Block_ready;
            reg Gradient_cache_clear_done;

            wire BLOCK_handshake;

                    




    //////////////////////// Window Control ////////////////////////
    // Window value and W, H, Block id 보관
    // 가동중인 Row에 대한 컨트롤 

        // FF Register

        // reg [$clog2(num_pixels):0] row_current;

            // State 
            localparam  GAUSSIAN_WINDOW_IDLE = 2'b00,
                        GAUSSIAN_WINDOW_SRAM_READY = 2'b01,
                        GAUSSIAN_WINDOW_READY = 2'b10;

            reg [1:0] Gaussian_window_state_current;
            reg [1:0] Gaussian_window_state_next;

        


        // Comb Register

            //internal handshake register
            reg next_gaussian_window_ready; // assigned by comb in state
            wire next_gaussian_window_valid; // assigned by assign 
        
        // Wire
        wire GAUSSIAN_WINDOW_handshake;


    

    //////////////////////// Pixel Control ////////////////////////
    // 각 픽셀에 관한 입력

        // FF Register

            // State
            localparam  PIXEL_IDLE = 2'b00,
                        PIXEL_SRAM_READY = 2'b01,
                        PIXEL_READY = 2'b10;
                
            reg [1:0] Pixel_state_current;
            reg [1:0] Pixel_state_next;

        reg [$clog2(num_pixels):0] row_next;
        reg [$clog2(num_pixels):0] last_input_done_next;

        reg [GID_bit-1:0] pixel_n_contrib [num_pixels-1:0];

        // Combinational Register
            //internal handshake register
            reg next_pixel_ready;
            reg next_pixel_valid;


        // Wire


    //////////////////////// Gaussian Window ////////////////////////

    // Current Window
        // FF Register
        reg [GID_bit-1:0] gaussian_id_window [WINDOW_SIZE-1:0];
        reg [3 *precision -1:0] gaussian_color_window [WINDOW_SIZE-1:0];
        reg [precision -1 :0] gaussian_depth_window [WINDOW_SIZE-1:0];
        reg [(2 * precision)-1 :0] mean2D_window [WINDOW_SIZE-1:0];
        reg [(4 * precision)-1 :0] conic_opacity_window [WINDOW_SIZE-1:0];

        // Window에서 Rasterizer에 보내는 pointer
        reg [$clog2(WINDOW_SIZE)-1:0] Gaussian_window_pointer_current [num_pixels-1:0];
        reg window_pointer_out_of_index_current [num_pixels-1:0];
        

        // Comb Regitser
        reg [$clog2(WINDOW_SIZE)-1:0] Gaussian_window_pointer_next [num_pixels-1:0];
        reg require_next_window [num_pixels-1:0];


    // Next Window
        // FF Register
        reg [GID_bit-1:0] gaussian_id_for_next_window [WINDOW_SIZE-1:0];
        reg [3 * precision -1:0] gaussian_color_for_next_window [WINDOW_SIZE-1:0];
        reg [precision -1 :0] gaussian_depth_for_next_window [WINDOW_SIZE-1:0];
        reg [(2 * precision)-1 :0] mean2D_for_next_window [WINDOW_SIZE-1:0];
        reg [(4 * precision)-1 :0] conic_opacity_for_next_window [WINDOW_SIZE-1:0];

        reg [$clog2(WINDOW_SIZE):0] Gaussian_window_pointer_for_next_window;
        // window_pointer_for_next_window MSB = valid 넘겨도 된다. 
        // But 추가 조건, WINDOW SIZE 이하의 값이 남은 경우 전부 0 처리


    //////////////////////// Pixel Window ////////////////////////
    
    // // FF Register

    reg [$clog2(num_pixels)-1:0] pixel_pointer;
    reg [$clog2(num_pixels):0] pixel_pointer_next;

    // pixel_id_pointer MSB가 Valid의 역할



    // Comb Register
    




    // REB and WEB

    assign REB_to_gaussian_SRAM = 1'b1;

    assign REB_to_Pixel_SRAM = 1'b1;

    genvar m;
    generate
        for (m = 0; m < Banks; m++) begin : SRAM_WEB_gen
            assign REB_to_gradient_SRAM[m] = 1'b1;
            assign WEB_to_gradient_SRAM[m] = 1'b1;
        end
    endgenerate



    // Block & Pixel 관련
    always_ff @ (posedge clk) begin

        if (!rst_n) begin
            Block_state_current <= BLOCK_IDLE;
            Gaussian_window_state_current <= GAUSSIAN_WINDOW_IDLE;
            Pixel_state_current <= PIXEL_IDLE;

            pixel_pointer <= 'd0;
            pixel_started <= 'd0;

            row_FF <= 'd0;
            last_input_done_FF <= 'd0;

            H <= 'd0;
            W <= 'd0;
            block_id <= 'd0;

            for (int i=0 ; i<num_pixels; i++) begin
                T_first_current[i] <= 'h0;
                dL_dpixel_current[i] <= 'h0;
                dL_dpixel_depth_current[i] <= 'h0;
                pixel_n_contrib[i] <= 'h0;
                pixel_id_current[i] <= 'h0;
            end
        end

        else begin

            Block_state_current <= Block_state_next;
            Gaussian_window_state_current <= Gaussian_window_state_next;
            Pixel_state_current <= Pixel_state_next;

            row_FF <= row_next;
            last_input_done_FF <= last_input_done_next;




            // pixel 데이터 배분하기
            pixel_pointer <= pixel_pointer_next[$clog2(num_pixels)-1:0];
            pixel_started <= pixel_started_next;


            // if ( ) begin // input data is valid 인 경우
                T_first_current[pixel_pointer] <= next_T_first_from_SRAM;
                dL_dpixel_current[pixel_pointer] <= next_dL_dpixel_from_SRAM;
                dL_dpixel_depth_current[pixel_pointer] <= next_dL_dpixel_depth_from_SRAM;
                pixel_n_contrib[pixel_pointer] <= next_n_contrib_from_SRAM;
            // end

            
            for (int i=0; i < num_pixels; i++) begin
                // pixel_id[j] <= num_pixels * row_done_next + j;
                pixel_id_current[i] <= num_pixels * row_next + i[7:0];
            end


            // start 조건 
            if (Pixel_state_current == PIXEL_READY) begin
                for (int i = 0; i < num_pixels ; i++) begin
                    start[i] <= 1'b1;
                end
            end
        end
    end
    
    // Gaussian Window 준비 관련 
    always_ff @ (posedge clk) begin
        if (!rst_n) begin

            for (int i= 0; i<WINDOW_SIZE; i++) begin
                gaussian_id_for_next_window[i] <= 'd0;
                gaussian_color_for_next_window[i] <= 'd0;
                gaussian_depth_for_next_window[i] <= 'd0;
                mean2D_for_next_window[i] <= 'd0;
                conic_opacity_for_next_window[i] <= 'd0;

                gaussian_id_window[i] <= 'h0;
                gaussian_color_window[i] <= 'd0;
                gaussian_depth_window[i] <= 'd0;
                mean2D_window[i] <= 'd0;
                conic_opacity_window[i] <= 'd0;
            end

            for (int i =0 ; i< num_pixels; i++) begin
                Gaussian_window_pointer_current[i] <= 'h0;
            end

            Gaussian_window_pointer_for_next_window <= 'd0;
        end

        else begin

            // SRAM 에서 다음 Window에 해당하는 데이터 받기
            if (Gaussian_window_pointer_for_next_window[$clog2(WINDOW_SIZE)-1:0] < WINDOW_SIZE) begin

                gaussian_id_for_next_window[Gaussian_window_pointer_for_next_window[$clog2(WINDOW_SIZE)-1:0]] <= gaussian_id_from_SRAM;
                // 이게 필요한지 확인해야 함.

                gaussian_color_for_next_window[Gaussian_window_pointer_for_next_window[$clog2(WINDOW_SIZE)-1:0]] <= gaussian_color_from_SRAM;
                gaussian_depth_for_next_window[Gaussian_window_pointer_for_next_window[$clog2(WINDOW_SIZE)-1:0]] <= gaussian_depth_from_SRAM;
                mean2D_for_next_window[Gaussian_window_pointer_for_next_window[$clog2(WINDOW_SIZE)-1:0]] <= mean2D_from_SRAM;
                conic_opacity_for_next_window[Gaussian_window_pointer_for_next_window[$clog2(WINDOW_SIZE)-1:0]] <= conic_opacity_from_SRAM;

                Gaussian_window_pointer_for_next_window <= Gaussian_window_pointer_for_next_window + 'd1;
            end

            // Handshake 발생 시 다음 Window 준비하기 위한 세팅 시작
            else if (GAUSSIAN_WINDOW_handshake) begin
                Gaussian_window_pointer_for_next_window <= 'd0;

                // next window reset 
                for (int i=0; i<WINDOW_SIZE; i++) begin
                    gaussian_id_for_next_window[i] <= 'd0;
                    gaussian_color_for_next_window[i] <= 'd0;
                    gaussian_depth_for_next_window[i] <= 'd0;
                    mean2D_for_next_window[i] <= 'd0;
                    conic_opacity_for_next_window[i] <= 'd0;
                end

            end

        end

    end


    
    

    // BLOCK FSM
    assign Block_data_ready = Block_ready;
    assign BLOCK_handshake = Block_data_ready && Block_data_done;
    genvar k;
    

    always_comb begin
        Block_state_next = Block_state_current;
        Block_ready = 0;
        last_input_done_next = last_input_done_FF;
        row_next = row_FF;
        Gradient_cache_clear_done = 0;


        case (Block_state_current)

            // Block 데이터가 Top으로부터 Block SRAM에 들어오지 않은 상태
            // Top에서 전체 데이터가 SRAM에 다 기입시 Handshake 신호 발생, 이때 State Transition
            BLOCK_IDLE: begin
                Block_ready = 1;

                if (BLOCK_handshake) begin
                    Block_state_next = BLOCK_BUSY;
                end


            end

            // Block 데이터가 SRAM에 들어있고, 이를 처리하는 상태
            // 이때 데이터가 다 처리되면 Handshake 신호 발생, 이때 State Transition
            // 데이터가 다 처리 = 1. row가 15번째 일때, 16번째 last_input_done가 들어오는 경우
            BLOCK_BUSY : begin
                Block_ready = 0;

                if (Gradient_cache_clear_done) begin
                    Block_state_next = BLOCK_IDLE;
                end

                for (int i = 0; i < num_pixels; i++) begin
                    if (last_input_done_from_rasterizer[i]) begin
                        last_input_done_next = last_input_done_next + 1;
                    end
                end

                // row next = row next + if (last_input_done_next == num_pixels) 
                row_next = row_next + {{($clog2(num_pixels)-1){1'b0}} ,last_input_done_next[$clog2(num_pixels)]};
                
            end


        endcase
    end


    // Gaussian Window FSM


    assign GAUSSIAN_WINDOW_handshake = next_gaussian_window_ready && next_gaussian_window_valid;
    assign next_gaussian_window_valid = Gaussian_window_pointer_for_next_window[$clog2(WINDOW_SIZE)];

    always_comb begin
        Gaussian_window_state_next = Gaussian_window_state_current;
        next_gaussian_window_ready = 0;

        case (Gaussian_window_state_current)
    
            GAUSSIAN_WINDOW_IDLE : begin
                if (Block_state_current == BLOCK_BUSY) begin
                    Gaussian_window_state_next = GAUSSIAN_WINDOW_SRAM_READY;
                end

            end

            GAUSSIAN_WINDOW_SRAM_READY : begin
                next_gaussian_window_ready = 1;

                if (Block_state_current == BLOCK_IDLE) begin
                    Gaussian_window_state_next = GAUSSIAN_WINDOW_IDLE;
                end

                else if (GAUSSIAN_WINDOW_handshake) begin
                    Gaussian_window_state_next = GAUSSIAN_WINDOW_READY;
                end

            end

            GAUSSIAN_WINDOW_READY : begin

                if (Block_state_current == BLOCK_IDLE) begin
                    Gaussian_window_state_next = GAUSSIAN_WINDOW_IDLE;
                end

                else if (next_gaussian_window_ready && ! next_gaussian_window_valid) begin
                    Gaussian_window_state_next = GAUSSIAN_WINDOW_SRAM_READY;
                end


            end

            default: Gaussian_window_state_next = GAUSSIAN_WINDOW_IDLE;

        endcase
    end


    // Pixel Window FSM
    
    always_comb begin
        Pixel_state_next = Pixel_state_current;
        pixel_pointer_next = {1'b0, pixel_pointer};
        pixel_started_next = pixel_started;

        case (Pixel_state_current)

            PIXEL_IDLE : begin
                if (Block_state_current == BLOCK_BUSY) begin
                    Pixel_state_next = PIXEL_SRAM_READY;
                end
            end

            PIXEL_SRAM_READY : begin
                if (Block_state_current == BLOCK_IDLE) begin
                    Pixel_state_next = PIXEL_IDLE;
                end

                else if (pixel_pointer[$clog2(num_pixels)]) begin
                    Pixel_state_next = PIXEL_READY;
                    pixel_pointer_next = pixel_pointer + 'd1;
                end
            end

            PIXEL_READY : begin
                if (Block_state_current == BLOCK_IDLE) begin
                    Pixel_state_next = PIXEL_IDLE;
                end
                
                if (!pixel_started) begin
                    Pixel_state_next = PIXEL_SRAM_READY;
                    pixel_started_next = 1'b1;
                end

            end

            default: Pixel_state_next = PIXEL_IDLE;

        endcase
    end

endmodule