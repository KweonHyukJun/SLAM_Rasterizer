
// SRAM은 없다고 가정 (추가로 module화 해서 달 예정)
module Backward_Block_controller #(
    parameter BLOCK_SIZE = 16,
    parameter exponent_bit = 8,
    parameter mantissa_bit = 7,
    parameter precision = 16,
    parameter gaussian_inputs = 4, // in one pixel unit, gaussians
    parameter num_pixels = 16, // number of pixel units
    // parameter GID_bit = 24,
    parameter GID_bit = 12,
    parameter WINDOW_SIZE = 32,
    parameter Banks = 16,
    parameter LUT_SIZE = 1 << GID_bit
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
        // output wire gradient_value_done,


        // Input from Group Rasterizer
        input wire stall_to_controller_from_rasterizer [num_pixels-1:0],
        input wire last_input_done_from_rasterizer [Banks-1:0],

        output wire rasterizer_FIFO_pop_valid_in [Banks-1:0],
        input wire rasterizer_FIFO_pop_ready_out [Banks-1:0],

        output wire stall_to_rasterizer_from_controller,



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

        output reg [11:0] H,
        output reg [11:0] W,
        output reg [15:0] block_id,
        output reg [(2 * $clog2(BLOCK_SIZE) - 1): 0] pixel_id [num_pixels-1:0],

        output reg [precision-1:0] T_first_current [num_pixels-1:0],
        output reg [(3 * precision)-1:0] dL_dpixel_current [num_pixels-1:0],
        output reg [precision-1:0] dL_dpixel_depth_current [num_pixels-1:0],
        // output reg [(2 * $clog2(BLOCK_SIZE) - 1): 0] pixel_id_current [num_pixels-1:0],

        

    // Input from input gaussian SRAM
    input wire [(3 * precision) - 1:0] gaussian_color_from_SRAM [gaussian_inputs-1:0],
    input wire [precision-1:0] gaussian_depth_from_SRAM [gaussian_inputs-1:0],
    input wire [(2 * precision)-1:0] mean2D_from_SRAM [gaussian_inputs-1:0],
    input wire [(4 * precision)-1:0] conic_opacity_from_SRAM [gaussian_inputs-1:0],

    output wire [GID_bit-1:0] gaussian_id_to_SRAM [gaussian_inputs-1:0], // 이거 그냥 hash? 그거 처리를 어디서 해야되는지는 추후 고민해야 할 사항

        
    // Output to input gaussian SRAM
    output wire REB_to_gaussian_SRAM [gaussian_inputs-1:0],


    // Input from input Pixel SRAM
    input wire [GID_bit-1:0] next_n_contrib_from_SRAM [num_pixels-1:0],
    input wire [precision-1:0] next_T_first_from_SRAM [num_pixels-1:0],
    input wire [(3 * precision)-1:0] next_dL_dpixel_from_SRAM [num_pixels-1:0],
    input wire [precision-1:0] next_dL_dpixel_depth_from_SRAM [num_pixels-1:0],

    // Output to input Pixel SRAM
    output wire [$clog2(num_pixels) - 1:0] Read_address_to_Pixel_SRAM [num_pixels-1:0],
    output wire REB_to_Pixel_SRAM [num_pixels-1:0],


    // Input from gradient merge SRAM
    input wire [GID_bit-1:0] Read_address_from_rasterizer_to_gradient_SRAM [Banks-1:0],


    // Output to gradient merge SRAM
        output wire REB_to_gradient_SRAM [Banks-1:0],
        output wire WEB_to_gradient_SRAM [Banks-1:0],

        output wire gradient_ID_used [Banks-1:0],

        output reg [LUT_SIZE-1:0] Gradient_first_used_LUT
    );


    // localparam LUT_SIZE = 1 << GID_bit;

    //////////////////////// Block Control ////////////////////////
    // Gradient Merge SRAM 관련 데이터를 직접 컨트롤
    // Pixel 및, Gaussian Window 관련 데이터는 간접적으로 컨트롤

        // FF Register

        reg [1:0] Block_state_current;
        reg [1:0] Block_state_next;


        // reg [GID_bit-1:0] block_last_gaussian_index; // SRAM에서의 Gaussian 범위를 알아낼 수 있도록 제작 0번은 NULL로 처리

        reg [$clog2(num_pixels):0] last_input_done_FF;
        reg [$clog2(num_pixels):0] row_FF;

        reg pixel_started;

        // 굳이 16개일 이유가?

            // State
            localparam  BLOCK_IDLE = 2'b00,
                        BLOCK_PIXEL_FETCHING = 2'b01,
                        BLOCK_BUSY = 2'b10;

            // Combinational register (for control signal)
            reg Block_ready;
            wire block_handshake;
            wire gradient_handshake;


    // //////////////////////// Window Control ////////////////////////
    // 가동중인 Window에 대한 컨트롤

        // FF Register

            // State
            localparam  WINDOW_IDLE = 2'd0,
                        WINDOW_REQUEST = 2'd1,
                        WINDOW_BUSY = 2'd2;
                        

            reg [1:0] Window_state_current;
            reg [1:0] Window_state_next;

            reg window_request;
        
            wire window_handshake;
            reg window_empty;
            

        // // Window에 기입해야 하는 최대 index 받아오기
        // reg [GID_bit-1:0] current_window_max_index;
        // reg [GID_bit-1:0] current_window_max_index_next;

        // reg current_window_max_index_is_zero;

        reg [GID_bit-1:0] gaussian_id_to_SRAM_before [gaussian_inputs-1:0];
        wire [GID_bit-1:0] gaussian_id_to_SRAM_original [gaussian_inputs-1:0];


    // //////////////////////// Next Window Control ////////////////////////

    // Next Window에 대한 컨트롤

        // State
        localparam  NEXT_WINDOW_IDLE = 2'd0,
                    NEXT_WINDOW_FETCHING = 2'd1,
                    NEXT_WINDOW_READY = 2'd2;

        reg [1:0] Next_window_state_current;
        reg [1:0] Next_window_state_next;

        reg window_valid;

        reg [$clog2(WINDOW_SIZE):0] next_window_fetching_pointer;
        reg [$clog2(WINDOW_SIZE):0] next_window_fetching_pointer_next; 
        

    // //////////////////////// Pixel Control ////////////////////////
    // // 각 픽셀에 관한 입력


        reg [$clog2(num_pixels):0] row_next;
        reg [$clog2(num_pixels):0] last_input_done_next;

        // SRAM에서 받는 max_index
        // Gaussian Window 시작점
        reg [GID_bit-1:0] pixel_max_index_from_SRAM;
        reg [GID_bit-1:0] pixel_max_index_from_SRAM_next;

        reg REB_to_pixel_SRAM_FF [num_pixels-1:0];

        // Pixel 데이터 겸 hot gaussian window에서의 n_contrib의 역할
        reg [GID_bit-1:0] pixel_n_contrib [num_pixels-1:0];

        reg any_REB_to_gaussian_SRAM_FF;

                        

    //////////////////////// Gaussian Window ////////////////////////

    // Current Window
        // FF Register
        reg [GID_bit-1:0] gaussian_id_window [WINDOW_SIZE-1:0];
        reg [3 *precision -1:0] gaussian_color_window [WINDOW_SIZE-1:0];
        reg [precision -1 :0] gaussian_depth_window [WINDOW_SIZE-1:0];
        reg [(2 * precision)-1 :0] mean2D_window [WINDOW_SIZE-1:0];
        reg [(4 * precision)-1 :0] conic_opacity_window [WINDOW_SIZE-1:0];

        // 각 window에서 각 Pixel에 보내는 pointer
        reg [$clog2(WINDOW_SIZE):0] Gaussian_window_pointer_current [num_pixels-1:0];


        wire over_the_window [num_pixels-1:0];
        wire pixel_is_not_finished [gaussian_inputs * num_pixels-1:0];
        wire pixel_starting_condition [gaussian_inputs * num_pixels-1:0];

        wire [GID_bit-1:0] gaussian_id_current_window_pointing [num_pixels-1:0];



        
    // Next Window
        // FF Register
        reg [GID_bit-1:0] gaussian_id_for_next_window [WINDOW_SIZE-1:0];
        reg [3 * precision -1:0] gaussian_color_for_next_window [WINDOW_SIZE-1:0];
        reg [precision -1 :0] gaussian_depth_for_next_window [WINDOW_SIZE-1:0];
        reg [(2 * precision)-1 :0] mean2D_for_next_window [WINDOW_SIZE-1:0];
        reg [(4 * precision)-1 :0] conic_opacity_for_next_window [WINDOW_SIZE-1:0];



        reg [GID_bit-1:0] max_pixel_n_contrib_for_next_window_current;
        reg [GID_bit-1:0] max_pixel_n_contrib_for_next_window_next;

        wire [GID_bit-1:0] max_pixel_n_contrib_remainder;

        // 처음 pixel 값에서 부터 가져오는 max 값
        reg [GID_bit-1:0] max_pixel_n_contrib_for_next_window_first;

        reg REB_to_gaussian_SRAM_FF [gaussian_inputs-1:0];
        
    //////////////////////// Pixel Window ////////////////////////




    //////////////////////// Backward Unit Control singal ////////////////////////
    reg [GID_bit-1:0] Write_address_FF [Banks-1:0];
    reg [GID_bit-1:0] Write_address_FF1 [Banks-1:0];

    // reg [GID_bit-1:0] Read_address_from_rasterizer_to_gradient_SRAM [Banks-1:0];

    reg rasterizer_FIFO_pop_valid_in_FF_temp [Banks-1:0];
    reg rasterizer_FIFO_pop_valid_in_FF_temp2 [Banks-1:0];

    reg WEB_to_gradient_SRAM_temp [Banks-1:0];


    assign gradient_value_valid = (Block_state_current == BLOCK_BUSY) && (row_FF == num_pixels);

    assign block_handshake = Block_data_done && Block_ready;
    assign window_handshake = window_valid && window_request;
    assign gradient_handshake = gradient_value_valid && gradient_value_ready;


    // Block State control
    always_comb begin
        Block_state_next = Block_state_current;
        row_next = row_FF;
        Block_ready = 1'b0;
        
        case (Block_state_current)
            //'d0, Block에 SRAM 데이터가 준비되지 않음 or Top 컨트롤러에서 Gradient 반환 
            
            BLOCK_IDLE: begin
                Block_ready = 1'b1;
                if (Block_data_done) begin
                    Block_state_next = BLOCK_PIXEL_FETCHING;
                end
            end

            //'d1, 다음 pixel에 대한 데이터 가져와야함
            BLOCK_PIXEL_FETCHING: begin
                
                // 픽셀 데이터가 다 차면 반환
                // if (pixel_fetching_pointer[$clog2(num_pixels)]) begin
                
                // Pixel 데이터를 Read 하면 반환
                if (!REB_to_Pixel_SRAM[0]) begin
                    Block_state_next = BLOCK_BUSY;
                end

            end

            //'d2, Pixel 데이터 가져옴
            BLOCK_BUSY: begin

                // 전체 블록 완료시
                if (gradient_handshake) begin
                    Block_state_next = BLOCK_IDLE;
                end

                // 다음 pixel 데이터가 필요시
                else if (last_input_done_FF[$clog2(num_pixels)] && !row_FF[$clog2(num_pixels)]) begin
                    Block_state_next = BLOCK_PIXEL_FETCHING;
                    row_next = row_FF + 1;
                end
            end

            default : begin
                Block_state_next = BLOCK_IDLE;
            end
        endcase
    end


    // Window State Control
    always_comb begin
        Window_state_next = Window_state_current;
        window_request = 1'b0;


        case (Window_state_current)
            // BLock 대기 시
            WINDOW_IDLE: begin
                if (block_handshake) begin
                    Window_state_next = WINDOW_REQUEST;
                end
            end

            // Window 요청 시 (hot window 비어있음)
            // window 요청을 다 줘야 last input 그게 된다.
            WINDOW_REQUEST: begin
                window_request = 1'b1;

                // 전체 데이터 완료시 IDLE
                if (gradient_handshake) begin
                    Window_state_next = WINDOW_IDLE;
                end

                // 데이터 수신 완료시 BUSY
                else if (window_handshake) begin
                    Window_state_next = WINDOW_BUSY;
                end
            end

            // Hot Window 존재, 데이터 수신 완료
            WINDOW_BUSY : begin

                // 다음 window 필요할 시 상태 변경
                // 모든 픽셀에서의 window pointer가 WINDOW SIZE 초과시 
                // 혹은 window pointer가 0까지 내려간 경우 (이 경우에 대한 보완 필요)
                if (window_empty) begin
                    Window_state_next = WINDOW_REQUEST;
                end

            end

            default: begin
                Window_state_next = WINDOW_IDLE;
            end

        endcase     

    end

    // Next window state control

    always_comb begin
        Next_window_state_next = Next_window_state_current;
        window_valid = 1'b0;
        next_window_fetching_pointer_next = next_window_fetching_pointer;
        max_pixel_n_contrib_for_next_window_next = max_pixel_n_contrib_for_next_window_current;

        case (Next_window_state_current)
            NEXT_WINDOW_IDLE: begin
                if (block_handshake) begin
                    Next_window_state_next = NEXT_WINDOW_FETCHING;
                    next_window_fetching_pointer_next = 'd0;
                end
            end

            NEXT_WINDOW_FETCHING: begin

                // next window full 조건
                // 1. 다 채웠거나
                // 2. 다음 window 최대 index가 0보다 작은 경우 (중간에 끝)

                if (!any_REB_to_gaussian_SRAM_FF) begin
                    if (max_pixel_n_contrib_for_next_window_current < gaussian_inputs) begin
                        max_pixel_n_contrib_for_next_window_next = 'd0;
                        next_window_fetching_pointer_next = next_window_fetching_pointer + max_pixel_n_contrib_for_next_window_current;
                    end

                    else begin
                        max_pixel_n_contrib_for_next_window_next = max_pixel_n_contrib_for_next_window_current - gaussian_inputs;
                        next_window_fetching_pointer_next = next_window_fetching_pointer + gaussian_inputs;
                    end
                end

                // if (next_window_fetching_pointer[$clog2(WINDOW_SIZE)] || max_pixel_n_contrib_for_next_window_current == 0) begin
                if (next_window_fetching_pointer[$clog2(WINDOW_SIZE)]) begin                    
                    Next_window_state_next = NEXT_WINDOW_READY;
                end


            end

            NEXT_WINDOW_READY: begin
                window_valid = 1'b1;

                // window handshake시 fetching 상태로 변경
                if (window_request) begin
                    Next_window_state_next = NEXT_WINDOW_FETCHING;
                    next_window_fetching_pointer_next = 'd0;
                end
            end

            default: begin
                Next_window_state_next = NEXT_WINDOW_IDLE;
            end

        endcase
    end


    // Next window max n_contrib >> 그걸 알아야 다음에 뭘 가져올 지 아니까
    always_comb begin
        max_pixel_n_contrib_for_next_window_first = 'd0;

        for (int i = 0; i < num_pixels; i++) begin
            // if (!REB_to_pixel_SRAM_FF[i] && (pixel_n_contrib[i] > max_pixel_n_contrib_for_next_window_first)) begin
            //     max_pixel_n_contrib_for_next_window_first = pixel_n_contrib[i];
            // end
            if (!REB_to_pixel_SRAM_FF[i] && (next_n_contrib_from_SRAM[i] > max_pixel_n_contrib_for_next_window_first)) begin
                max_pixel_n_contrib_for_next_window_first = next_n_contrib_from_SRAM[i];
            end            
        end
    end



    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    // Block State control FF

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            Block_state_current <= BLOCK_IDLE;
            row_FF <= 'd0;
            last_input_done_FF <= 'd0;


            for (int i = 0; i < num_pixels; i++) begin
                REB_to_pixel_SRAM_FF[i] <= 1'b1;

                T_first_current[i] <= 'd0;
                dL_dpixel_current[i] <= 'd0;
                dL_dpixel_depth_current[i] <= 'd0;
                pixel_id[i] <= 'd0;
                start[i] <= 'd0;
            end
        end

        else begin

            Block_state_current <= Block_state_next;
            row_FF <= row_next;
            last_input_done_FF <= last_input_done_next;

            for (int i = 0; i < num_pixels; i++) begin
                REB_to_pixel_SRAM_FF[i] <= REB_to_Pixel_SRAM[i];

                pixel_id[i] <= {row_FF[$clog2(num_pixels)-1:0], i[$clog2(num_pixels)-1:0]};

                // 이전 사이클에 Pixel REB 신호시
                // 다음 사이클에 픽셀 데이터 가져옴 + start 신호 반환
                if (!REB_to_pixel_SRAM_FF[i]) begin
                    // pixel_n_contrib[i] <= next_n_contrib_from_SRAM[i];
                    T_first_current[i] <= next_T_first_from_SRAM[i];
                    dL_dpixel_current[i] <= next_dL_dpixel_from_SRAM[i];
                    dL_dpixel_depth_current[i] <= next_dL_dpixel_depth_from_SRAM[i];
                    start[i] <= 1'b1;
                end

                else begin
                    start[i] <= 1'b0;
                end
                
            end

        end
    end

    // Window State control FF

    always_ff @ (posedge clk) begin
        if (!rst_n) begin
            Window_state_current <= WINDOW_IDLE;
            

            for (int i = 0; i <num_pixels; i++) begin
                Gaussian_window_pointer_current[i] <= 'd0;
                pixel_n_contrib[i] <= 'd0;
                
            end

            for (int i = 0; i < WINDOW_SIZE; i++) begin
                gaussian_id_window[i] <= 'd0;
                gaussian_color_window[i] <= 'd0;
                gaussian_depth_window[i] <= 'd0;
                mean2D_window[i] <= 'd0;
                conic_opacity_window[i] <= 'd0;
            end
        end

        else begin
            Window_state_current <= Window_state_next;

            if (window_handshake) begin
                for (int i = 0; i < WINDOW_SIZE; i++) begin
                    gaussian_id_window[i] <= gaussian_id_for_next_window[i];
                    gaussian_color_window[i] <= gaussian_color_for_next_window[i];
                    gaussian_depth_window[i] <= gaussian_depth_for_next_window[i];
                    mean2D_window[i] <= mean2D_for_next_window[i];
                    conic_opacity_window[i] <= conic_opacity_for_next_window[i];
                end
            end
            

            case (Window_state_current)
                WINDOW_BUSY: begin
                    for (int i = 0; i < num_pixels; i++) begin

                        if (!stall_to_controller_from_rasterizer[i]) begin
                            Gaussian_window_pointer_current[i] <= Gaussian_window_pointer_current[i] + gaussian_inputs;

                            if (pixel_n_contrib[i] < gaussian_inputs) begin
                                pixel_n_contrib[i] <= 'd0;
                            end

                            else begin
                                pixel_n_contrib[i] <= pixel_n_contrib[i] - gaussian_inputs;
                            end


                            for (int j = 0; j < gaussian_inputs; j++) begin

                                // Input 조건 

                                if (Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)-1:0] + j < WINDOW_SIZE) begin

                                    i_valid[i * gaussian_inputs + j] <= 1'b1;

                                    if (pixel_n_contrib[i] == j) begin
                                        last_input_done_to_pixel[i * gaussian_inputs + j] <= 1'b1;
                                    end

                                    else begin
                                        last_input_done_to_pixel[i * gaussian_inputs + j] <= 1'b0;
                                    end
                                    
                                    gaussian_id_to_rasterizer[i * gaussian_inputs + j] <= gaussian_id_window[Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)-1:0] + j];
                                    gaussian_color_to_rasterizer[i * gaussian_inputs + j] <= gaussian_color_window[Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)-1:0] + j];
                                    gaussian_depth_to_rasterizer[i * gaussian_inputs + j] <= gaussian_depth_window[Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)-1:0] + j];
                                    mean2D_to_rasterizer[i * gaussian_inputs + j] <= mean2D_window[Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)-1:0] + j];
                                    conic_opacity_to_rasterizer[i * gaussian_inputs + j] <= conic_opacity_window[Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)-1:0] + j];

                                end

                                else begin
                                    i_valid[i * gaussian_inputs + j] <= 1'b0;
                                    last_input_done_to_pixel[i * gaussian_inputs + j] <= 1'b0;
                                    gaussian_id_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                                    gaussian_color_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                                    gaussian_depth_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                                    mean2D_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                                    conic_opacity_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                                end

                            end


                        end

                    end
                end

                default : begin
                    for (int i = 0; i < num_pixels; i++) begin
                        for (int j = 0; j < gaussian_inputs; j++) begin
                            i_valid[i * gaussian_inputs + j] <= 1'b0;
                            last_input_done_to_pixel[i * gaussian_inputs + j] <= 1'b0;
                            gaussian_id_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                            gaussian_color_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                            gaussian_depth_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                            mean2D_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                            conic_opacity_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                        end

                        Gaussian_window_pointer_current[i] <= 'd0;
                    end

                    for (int i=0; i< num_pixels ; i++)begin
                        if (!REB_to_pixel_SRAM_FF[i]) begin
                            pixel_n_contrib[i] <= next_n_contrib_from_SRAM[i];
                        end
                    end
                end
            endcase
        end
    end

    // Next Window State control FF

    always_ff @ (posedge clk) begin
        if (!rst_n) begin
            Next_window_state_current <= NEXT_WINDOW_IDLE;
            next_window_fetching_pointer <= 'd0;

            max_pixel_n_contrib_for_next_window_current <= 'd0;

            for (int i = 0; i < gaussian_inputs; i++) begin
                REB_to_gaussian_SRAM_FF[i] <= 1'b1;
                gaussian_id_to_SRAM_before[i] <= 'd0;
            end

            for (int i = 0; i < WINDOW_SIZE; i++) begin
                gaussian_id_for_next_window[i] <= 'h0;
                gaussian_color_for_next_window[i] <= 'h0;
                gaussian_depth_for_next_window[i] <= 'h0;
                mean2D_for_next_window[i] <= 'h0;
                conic_opacity_for_next_window[i] <= 'h0;
            end
        end

        else begin
            Next_window_state_current <= Next_window_state_next;
            next_window_fetching_pointer <= next_window_fetching_pointer_next;

            for (int i = 0; i < gaussian_inputs; i++) begin
                gaussian_id_to_SRAM_before[i] <= gaussian_id_to_SRAM_original[i];
            end


            if (window_handshake) begin
                for (int i = 0; i < WINDOW_SIZE; i++) begin
                    gaussian_id_for_next_window[i] <= 'h0;
                    gaussian_color_for_next_window[i] <= 'h0;
                    gaussian_depth_for_next_window[i] <= 'h0;
                    mean2D_for_next_window[i] <= 'h0;
                    conic_opacity_for_next_window[i] <= 'h0;
                end        
            end


            // Max Winodw value
            if (!REB_to_pixel_SRAM_FF[0]) begin
                max_pixel_n_contrib_for_next_window_current <= max_pixel_n_contrib_for_next_window_first;
                next_window_fetching_pointer <= 'd0;
            end

            // Max Window value 업데이트
            else begin
                max_pixel_n_contrib_for_next_window_current <= max_pixel_n_contrib_for_next_window_next;
            end


            // Next window fetching
            if (Next_window_state_current == NEXT_WINDOW_FETCHING) begin
                // next_window_fetching_pointer <= next_window_fetching_pointer + gaussian_inputs;
                // next_window_fetching_pointer <= next_window_fetching_pointer_next; 

                for (int i = 0; i < gaussian_inputs; i++) begin
                    REB_to_gaussian_SRAM_FF[i] <= REB_to_gaussian_SRAM[i];

                    if (next_window_fetching_pointer + i < WINDOW_SIZE && !REB_to_gaussian_SRAM_FF[i]) begin

                        gaussian_id_for_next_window[next_window_fetching_pointer + i] <= gaussian_id_to_SRAM_before[i];
                        gaussian_color_for_next_window[next_window_fetching_pointer + i] <= gaussian_color_from_SRAM[i];
                        gaussian_depth_for_next_window[next_window_fetching_pointer + i] <= gaussian_depth_from_SRAM[i];
                        mean2D_for_next_window[next_window_fetching_pointer + i] <= mean2D_from_SRAM[i];
                        conic_opacity_for_next_window[next_window_fetching_pointer + i] <= conic_opacity_from_SRAM[i];

                    end
                end
            end



        end
    end    



    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////  

    // l=0 에서의 remainder

    // 약간 이게 shifting amount의 기능을 하도록 barrel shifter 구현해야함
    assign max_pixel_n_contrib_remainder = max_pixel_n_contrib_for_next_window_current % gaussian_inputs;

    genvar k, l, m;
    generate 
        for (k = 0; k < num_pixels; k++) begin : pixel_control

            // Pixel SRAM Read, Address = pixel_id % num_pixels 의 의미 
            assign REB_to_Pixel_SRAM[k] = (Block_state_current == BLOCK_PIXEL_FETCHING) ? 1'b0 : 1'b1;
            assign Read_address_to_Pixel_SRAM[k] = pixel_id[k][$clog2(num_pixels)-1:0];
        end

        
        for (m = 0; m < gaussian_inputs; m++) begin : gaussian_id_to_SRAM_original_control
                
                // // Assign `gaussian_id_to_SRAM_original
                assign gaussian_id_to_SRAM_original[m] = 
                    (max_pixel_n_contrib_for_next_window_current > m) ?
                    // && (max_pixel_n_contrib_remainder - m + gaussian_inputs) % gaussian_inputs == m  ? 

                    max_pixel_n_contrib_for_next_window_current - m : 'd0;

                // Assign `gaussian_id_to_SRAM`
                assign gaussian_id_to_SRAM[m] = 
                    (max_pixel_n_contrib_for_next_window_current > m) ?
                    // && (max_pixel_n_contrib_remainder - m + gaussian_inputs) % gaussian_inputs == m  ? 
                    (max_pixel_n_contrib_for_next_window_current - m + gaussian_inputs) / gaussian_inputs : 'd0;

                // Assign `REB_to_gaussian_SRAM`
                assign REB_to_gaussian_SRAM[m] = 
                    (max_pixel_n_contrib_for_next_window_current > m) ?
                    // && (max_pixel_n_contrib_remainder - m + gaussian_inputs) % gaussian_inputs == m  ? 
                    1'b0 : 1'b1;            


                // assign gaussian_id_to_SRAM_original[m] = 
                //     (max_pixel_n_contrib_for_next_window_current > l) && 
                //     (m == (max_pixel_n_contrib_remainder + gaussian_inputs - l) % gaussian_inputs) ? 
                //     max_pixel_n_contrib_for_next_window_current - l : 'd0;

                // // Assign `gaussian_id_to_SRAM`
                // assign gaussian_id_to_SRAM[m] = 
                //     (max_pixel_n_contrib_for_next_window_current > l) && 
                //     (m == (max_pixel_n_contrib_remainder + gaussian_inputs - l) % gaussian_inputs) ? 
                //     (max_pixel_n_contrib_remainder - l) / gaussian_inputs : 'd0;

                // // Assign `REB_to_gaussian_SRAM`
                // assign REB_to_gaussian_SRAM[m] = 
                //     (max_pixel_n_contrib_for_next_window_current > l) && 
                //     (m == (max_pixel_n_contrib_remainder + gaussian_inputs - l) % gaussian_inputs) ? 
                //     1'b0 : 1'b1;            
        
        end
        
    endgenerate 


    // Window_empty
    // 모든 픽셀에서의 window pointer가 WINDOW SIZE 초과시 반환
    always_comb begin
        window_empty = Gaussian_window_pointer_current[$clog2(WINDOW_SIZE)][0];
        for (int i = 1; i < gaussian_inputs; i++) begin
            window_empty = window_empty && Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)];
        end
    end

    //last_input_done

    always_comb begin
        last_input_done_next = last_input_done_FF;
        for (int i = 0; i < Banks; i++) begin
            if (last_input_done_from_rasterizer[i]) begin
                last_input_done_next = last_input_done_next + 1;
            end
        end
    end

    // any_REB_to_gaussian_SRAM_FF
    always_comb begin
        any_REB_to_gaussian_SRAM_FF = 1'b1;
        for (int i = 0; i < gaussian_inputs; i++) begin
            any_REB_to_gaussian_SRAM_FF = any_REB_to_gaussian_SRAM_FF && REB_to_gaussian_SRAM_FF[i];
        end
    end


endmodule