
// SRAM은 없다고 가정 (추가로 module화 해서 달 예정)
module Forward_Block_controller_fetching_near_pixel #(
    parameter BLOCK_SIZE = 16,
    parameter exponent_bit = 8,
    parameter mantissa_bit = 7,
    parameter precision = 16,
    parameter gaussian_inputs = 4, // in one pixel unit, gaussians
    parameter num_pixels = 16, // number of pixel units
    // parameter GID_bit = 24,
    parameter GID_bit = 12,
    parameter WINDOW_SIZE = 32
    // parameter Banks = 16,
    // parameter LUT_SIZE = 1 << GID_bit
    ) 

    (
    input wire clk,
    input wire rst_n,

    // Input from Top controller
        input wire Block_data_done,

        input wire pixel_out_value_ready,
        // input wire gradient_data_done, // gradient 관련 handshake에서 모든 데이터를 top에서 처리하였을 경우 반환

        input wire [15:0] block_id_in,

        input wire [GID_bit-1:0] last_gaussian_index_in, // SRAM에서의 Gaussian 범위를 알아낼 수 있도록 제작 0번은 NULL로 처리


    // Output to Top Controller
        output wire Block_data_ready,
        output wire pixel_out_value_valid,

        // Input from Group Rasterizer
        input wire stall_to_controller_from_rasterizer [num_pixels-1:0],
        input wire last_input_done_from_rasterizer [num_pixels-1:0],

        output wire stall_to_rasterizer_from_controller,



    // Output to Group Rasterizer

        // Gaussian Window value
        output reg i_valid [gaussian_inputs * num_pixels - 1:0],

        output reg last_input_done_to_rasterizer [gaussian_inputs * num_pixels - 1:0],
        output reg [(3 * precision)-1:0] gaussian_color_to_rasterizer [gaussian_inputs * num_pixels - 1:0],
        output reg [precision-1:0] gaussian_depth_to_rasterizer [gaussian_inputs * num_pixels - 1:0],
        output reg [(2 * precision)-1:0] mean2D_to_rasterizer [gaussian_inputs * num_pixels - 1:0],
        output reg [(4 * precision)-1:0] conic_opacity_to_rasterizer [gaussian_inputs * num_pixels - 1:0],
        output reg [GID_bit-1:0] gaussian_id_to_rasterizer [gaussian_inputs * num_pixels - 1:0],

        // pixel value
        output reg start [num_pixels-1:0], // 이거 컨트롤 신호, 유사 리셋의 느낌

        output reg [15:0] block_id,
        output reg [(2 * $clog2(BLOCK_SIZE) - 1): 0] pixel_id [num_pixels-1:0],
        

    // Input from input gaussian SRAM
    input wire [(3 * precision) - 1:0] gaussian_color_from_SRAM [gaussian_inputs-1:0],
    input wire [precision-1:0] gaussian_depth_from_SRAM [gaussian_inputs-1:0],
    input wire [(2 * precision)-1:0] mean2D_from_SRAM [gaussian_inputs-1:0],
    input wire [(4 * precision)-1:0] conic_opacity_from_SRAM [gaussian_inputs-1:0],

    
    output reg [GID_bit-1:0] gaussian_id_to_SRAM [gaussian_inputs-1:0], // 이거 그냥 hash? 그거 처리를 어디서 해야되는지는 추후 고민해야 할 사항
        
    // Output to input gaussian SRAM
    // output wire REB_to_gaussian_SRAM [gaussian_inputs-1:0],
    output reg REB_to_gaussian_SRAM [gaussian_inputs-1:0],

    // Output to Pixel SRAM
    output reg WEB_to_Pixel_SRAM [num_pixels-1:0],
    output reg [$clog2(num_pixels)-1:0] Write_address_to_Pixel_SRAM [num_pixels-1:0]
    );



    //////////////////////// Block Control ////////////////////////
    // Gradient Merge SRAM 관련 데이터를 직접 컨트롤
    // Pixel 및, Gaussian Window 관련 데이터는 간접적으로 컨트롤

        // FF Register

        reg Block_state_current;
        reg Block_state_next;

        reg [GID_bit-1:0] last_gaussian_index;



        // IDEA : last_input_done과 row_FF 통일
        // reg [$clog2(num_pixels):0] last_input_done_FF;
        // reg [$clog2(num_pixels):0] row_FF;

        reg [2 * $clog2(num_pixels):0] last_input_done_FF;
        reg [2 * $clog2(num_pixels):0] last_input_done_next;

        reg all_last_input_done;

        reg pixel_started;

        // 굳이 16개일 이유가?

            // State
            localparam  BLOCK_IDLE = 1'b0,
                        BLOCK_BUSY = 1'b1;

            // Combinational register (for control signal)
            reg Block_ready;
            wire block_handshake;
            wire pixel_out_value_handshake;
            

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

        // reg current_window_max_index_is_zero;

        reg [GID_bit-1:0] gaussian_id_to_SRAM_before [gaussian_inputs-1:0];
        reg [GID_bit-1:0] gaussian_id_to_SRAM_original [gaussian_inputs-1:0];


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
        reg [$clog2(WINDOW_SIZE):0] next_window_fetching_pointer_FF1;
        reg [$clog2(WINDOW_SIZE):0] next_window_fetching_pointer_FF2;

        reg [$clog2(WINDOW_SIZE):0] next_window_fetching_pointer_next; 

        reg stall_to_controller_from_rasterizer_comb;        
        

    // //////////////////////// Pixel Control ////////////////////////
    // // 각 픽셀에 관한 입력


        // reg [$clog2(num_pixels):0] row_next;
        // reg [$clog2(num_pixels):0] last_input_done_next;


        // Pixel 데이터 겸 hot gaussian window에서의 n_contrib의 역할
        reg [GID_bit-1:0] pixel_n_contrib [num_pixels-1:0];

        reg [GID_bit-1:0] pixel_n_contrib_for_next_window;
        reg [GID_bit-1:0] pixel_n_contrib_for_next_window_FF;

    

        wire [$clog2(gaussian_inputs)-1:0] gaussian_index [gaussian_inputs-1:0];
        reg [$clog2(gaussian_inputs)-1:0] gaussian_index_FF1 [gaussian_inputs-1:0];
        reg [$clog2(gaussian_inputs)-1:0] gaussian_index_FF2 [gaussian_inputs-1:0];

        wire [GID_bit-1:0] gaussian_id_for_fetching [gaussian_inputs-1:0];

                        

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
        
        
    // Next Window
        // FF Register
        reg [GID_bit-1:0] gaussian_id_for_next_window [WINDOW_SIZE-1:0];
        reg [3 * precision -1:0] gaussian_color_for_next_window [WINDOW_SIZE-1:0];
        reg [precision -1 :0] gaussian_depth_for_next_window [WINDOW_SIZE-1:0];
        reg [(2 * precision)-1 :0] mean2D_for_next_window [WINDOW_SIZE-1:0];
        reg [(4 * precision)-1 :0] conic_opacity_for_next_window [WINDOW_SIZE-1:0];


        wire [GID_bit-1:0] SRAM_shift_amount;


        reg REB_to_gaussian_SRAM_FF [gaussian_inputs-1:0];


        // Combinational Logic
        reg [GID_bit-1:0] gaussian_id_to_SRAM_original_comb [gaussian_inputs-1:0];
        reg [GID_bit-1:0] gaussian_id_to_SRAM_comb [gaussian_inputs-1:0];
        reg REB_to_gaussian_SRAM_comb [gaussian_inputs-1:0];    
        
    //////////////////////// Pixel Window ////////////////////////




    //////////////////////// Backward Unit Control singal ////////////////////////

    // assign pixel_out_value_valid = (Block_state_current == BLOCK_BUSY) && (row_FF == num_pixels);
    assign pixel_out_value_valid = (Block_state_current == BLOCK_BUSY) && (last_input_done_next[2 * $clog2(num_pixels)]);

    assign block_handshake = Block_data_done && Block_ready;
    assign window_handshake = window_valid && window_request;
    assign pixel_out_value_handshake = pixel_out_value_valid && pixel_out_value_ready;


    // Block State control
    always_comb begin
        Block_state_next = Block_state_current;
        // row_next = row_FF;

        Block_ready = 1'b0;
        
        case (Block_state_current)
            //'d0, Block에 SRAM 데이터가 준비되지 않음 or Top 컨트롤러에서 Gradient 반환 
            
            BLOCK_IDLE: begin
                Block_ready = 1'b1;
                if (Block_data_done) begin
                    Block_state_next = BLOCK_BUSY;
                end
            end

            //'d1, Gaussian Cache에 데이터가 차 있는 상태
            BLOCK_BUSY: begin

                // 전체 블록 완료시
                // if (pixel_out_value_handshake || last_input_done_next[2 * $clog2(num_pixels)]) begin
                if (pixel_out_value_handshake) begin
                    Block_state_next = BLOCK_IDLE;
                end
                
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
                if (pixel_out_value_handshake) begin
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
                if (pixel_out_value_handshake) begin
                    Window_state_next = WINDOW_IDLE;
                end
                
                // if (window_empty && !stall_to_controller_from_rasterizer_comb) begin
                else if (window_empty && !stall_to_controller_from_rasterizer_comb) begin
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
        


        case (Next_window_state_current)

            // 'd0
            NEXT_WINDOW_IDLE: begin
                if (block_handshake) begin
                    Next_window_state_next = NEXT_WINDOW_FETCHING;
                    next_window_fetching_pointer_next = 'd0;
                end
            end

            NEXT_WINDOW_FETCHING: begin

                // State가 중간에 넘어가기 위한 조건 - 중간 지점에서 끝나는 경우에 대비해야 함.

                if (pixel_out_value_handshake) begin
                    Next_window_state_next = NEXT_WINDOW_IDLE;
                end

                else if ((next_window_fetching_pointer_FF1[$clog2(WINDOW_SIZE)] || pixel_n_contrib_for_next_window_FF > last_gaussian_index) && gaussian_id_for_next_window[0] != 'd0 ) begin                                        
                    Next_window_state_next = NEXT_WINDOW_READY;
                end

                else if (!next_window_fetching_pointer[$clog2(WINDOW_SIZE)]) begin
                // else begin
                
                    // 다 채우지 못하고 남은게 0 인경우 (약간 초기 상황도 포함이네)
                    // 여기서 후반 조건에 대한 transition 해야함

                    if (next_window_fetching_pointer_FF2 + gaussian_inputs < WINDOW_SIZE) begin
                        next_window_fetching_pointer_next = next_window_fetching_pointer + gaussian_inputs;
                    end

                end
            end

            NEXT_WINDOW_READY: begin
                window_valid = 1'b1;

                if (pixel_out_value_handshake) begin
                    Next_window_state_next = NEXT_WINDOW_IDLE;
                end
                
                // window handshake시 fetching 상태로 변경
                // if (window_request) begin
                else if (window_request) begin                    
                    Next_window_state_next = NEXT_WINDOW_FETCHING;
                    next_window_fetching_pointer_next = 'd0;
                end
            end

            default: begin
                Next_window_state_next = NEXT_WINDOW_IDLE;
            end

        endcase
    end



    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    // Block State control FF

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            Block_state_current <= BLOCK_IDLE;
            
            last_input_done_FF <= 'd0;
            
            block_id <= 'd0;
            last_gaussian_index <= 'd0;


            for (int i = 0; i < num_pixels; i++) begin

                pixel_id[i] <= 'd0;
                start[i] <= 'd0;

                WEB_to_Pixel_SRAM [i] <= 'b1;
                Write_address_to_Pixel_SRAM [i] <= 'd0;
            end


            pixel_started <= 1'b0;



        end

        else begin

            

            Block_state_current <= Block_state_next;
            // row_FF <= row_next;

            for (int i = 0; i < num_pixels; i++) begin
                WEB_to_Pixel_SRAM[i] <= !(last_input_done_from_rasterizer[i] && start[i]);


                if (all_last_input_done || (Block_state_current == BLOCK_IDLE && Block_state_next == BLOCK_BUSY)) begin

                    if (start[i] && last_input_done_from_rasterizer[i]) begin
                        start[i] <= 1'b0;
                    end

                    else begin
                        start[i] <= 1'b1;
                    end

                    pixel_id[i] <= {last_input_done_next[2 * $clog2(num_pixels)-1:$clog2(num_pixels)], i[$clog2(num_pixels)-1:0]};
                end

                else begin
                    start[i] <= 1'b0;
                end

                

                Write_address_to_Pixel_SRAM[i] <= last_input_done_FF[2 * $clog2(num_pixels)-1:$clog2(num_pixels)];


            end
            
            
            // State 하나 사라지면서 생기는 문제점 - last input을 제어할 방법이 없다.
            if (Block_state_next == BLOCK_IDLE && Block_state_current == BLOCK_BUSY) begin
                last_input_done_FF <= 'd0;
                last_gaussian_index <= 'd0;
            end

            else begin
                last_input_done_FF <= last_input_done_next;
            end

            // State 하나 사라지면서 생기는 문제점 - last input을 제어할 방법이 없다.
            if (Block_state_next == BLOCK_BUSY && Block_state_current == BLOCK_IDLE) begin
                last_gaussian_index <= last_gaussian_index_in;
            end


            if (block_handshake) begin 
                block_id <= block_id_in;
            end

            if (pixel_out_value_handshake) begin
                pixel_started <= 1'b0;
            end

        end
    end

    // Window State control FF

    always_ff @ (posedge clk) begin
        if (!rst_n) begin
            Window_state_current <= WINDOW_IDLE;
            

            for (int i = 0; i < num_pixels; i++) begin
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

            for (int i=0; i < gaussian_inputs * num_pixels ; i++) begin
                i_valid[i] <= 1'b0;
                last_input_done_to_rasterizer[i] <= 1'b0;
                gaussian_id_to_rasterizer[i] <= 'd0;
                gaussian_color_to_rasterizer[i] <= 'd0;
                gaussian_depth_to_rasterizer[i] <= 'd0;
                mean2D_to_rasterizer[i] <= 'd0;
                conic_opacity_to_rasterizer[i] <= 'd0;    
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

                for (int i=0; i< num_pixels; i++) begin
                    Gaussian_window_pointer_current[i] <= 'd0;
                    pixel_n_contrib[i] <= 'd0;
                end
            end

            // if (all_last_input_done) begin
            //     for (int i=0; i<num_pixels; i++) begin
            //         pixel_n_contrib[i] <= 'd0;
            //     end
            // end
            

            case (Window_state_current)
                WINDOW_BUSY: begin
                    for (int i = 0; i < num_pixels; i++) begin

                        if (!stall_to_controller_from_rasterizer[i]) begin
    

                            if (!Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)]) begin
                                Gaussian_window_pointer_current[i] <= Gaussian_window_pointer_current[i] + gaussian_inputs;
                                pixel_n_contrib[i] <= pixel_n_contrib[i] + gaussian_inputs;
                            end
                            

                            for (int j = 0; j < gaussian_inputs; j++) begin

                                // Input 조건 
                                if (Gaussian_window_pointer_current[i] + j < WINDOW_SIZE) begin

                                    // // if (pixel_n_contrib[i] >= gaussian_id_window[Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)-1:0] + j]) begin
                                    if (gaussian_id_window[Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)-1:0] + j] <= last_gaussian_index && gaussian_id_window[Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)-1:0] + j] > 0) begin
                                        i_valid[i * gaussian_inputs + j] <= 1'b1;
                                    end

                                    else begin
                                        i_valid[i * gaussian_inputs + j ] <= 1'b0;
                                    end



                                    if (pixel_n_contrib[i] + j + 1 == last_gaussian_index) begin
                                        last_input_done_to_rasterizer[i * gaussian_inputs + j] <= 1'b1;
                                    end

                                    else begin
                                        last_input_done_to_rasterizer[i * gaussian_inputs + j] <= 1'b0;
                                    end
                                    
                                    gaussian_id_to_rasterizer[i * gaussian_inputs + j] <= gaussian_id_window[Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)-1:0] + j];
                                    gaussian_color_to_rasterizer[i * gaussian_inputs + j] <= gaussian_color_window[Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)-1:0] + j];
                                    gaussian_depth_to_rasterizer[i * gaussian_inputs + j] <= gaussian_depth_window[Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)-1:0] + j];
                                    mean2D_to_rasterizer[i * gaussian_inputs + j] <= mean2D_window[Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)-1:0] + j];
                                    conic_opacity_to_rasterizer[i * gaussian_inputs + j] <= conic_opacity_window[Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)-1:0] + j];

                                end

                                else begin
                                    i_valid[i * gaussian_inputs + j] <= 1'b0;

                                    last_input_done_to_rasterizer[i * gaussian_inputs + j] <= 1'b0;
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
                            last_input_done_to_rasterizer[i * gaussian_inputs + j] <= 1'b0;
                            gaussian_id_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                            gaussian_color_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                            gaussian_depth_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                            mean2D_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                            conic_opacity_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                        end

                        Gaussian_window_pointer_current[i] <= 'd0;
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
            next_window_fetching_pointer_FF1 <= 'd0;
            next_window_fetching_pointer_FF2 <= 'd0;

            pixel_n_contrib_for_next_window <= 'd1;
            pixel_n_contrib_for_next_window_FF <= 'd1;



            for (int i = 0; i < gaussian_inputs; i++) begin
                REB_to_gaussian_SRAM_FF[i] <= 1'b1;
                gaussian_id_to_SRAM_before[i] <= 'd0;


                gaussian_id_to_SRAM[i] <= 'd0;
                REB_to_gaussian_SRAM[i] <= 1'b1;

                
                gaussian_index_FF1[i] <= 'd0;
                gaussian_index_FF2[i] <= 'd0;
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
            next_window_fetching_pointer_FF1 <= next_window_fetching_pointer;
            next_window_fetching_pointer_FF2 <= next_window_fetching_pointer_FF1;


            // if (pixel_out_value_handshake) begin
            if (window_handshake) begin                

                for (int i = 0; i < gaussian_inputs; i++) begin
                    REB_to_gaussian_SRAM_FF[i] <= 1'b1;
                    gaussian_id_to_SRAM_before[i] <= 'd0;

                    gaussian_id_to_SRAM[i] <= 'd0;
                    REB_to_gaussian_SRAM[i] <= 1'b1;

                    gaussian_index_FF1[i] <= 'd0;
                    gaussian_index_FF2[i] <= 'd0;
                end

                for (int i = 0; i < WINDOW_SIZE; i++) begin
                    gaussian_id_for_next_window[i] <= 'h0;
                    gaussian_color_for_next_window[i] <= 'h0;
                    gaussian_depth_for_next_window[i] <= 'h0;
                    mean2D_for_next_window[i] <= 'h0;
                    conic_opacity_for_next_window[i] <= 'h0;
                end

                next_window_fetching_pointer <= 'd0;
                next_window_fetching_pointer_FF1 <= 'd0;
                next_window_fetching_pointer_FF2 <= 'd0;

            end


            for (int i = 0; i < gaussian_inputs; i++) begin
                gaussian_id_to_SRAM_before[i] <= gaussian_id_to_SRAM_original[i];

                gaussian_id_to_SRAM_original[i] <= gaussian_id_to_SRAM_original_comb[i];
                gaussian_id_to_SRAM[i] <= gaussian_id_to_SRAM_comb[i];
                REB_to_gaussian_SRAM[i] <= REB_to_gaussian_SRAM_comb[i];

                gaussian_index_FF1[i] <= gaussian_index[i];
                gaussian_index_FF2[i] <= gaussian_index_FF1[i];
            end
            


            if (window_handshake) begin
                for (int i = 0; i < WINDOW_SIZE; i++) begin
                    gaussian_id_for_next_window[i] <= 'h0;
                    gaussian_color_for_next_window[i] <= 'h0;
                    gaussian_depth_for_next_window[i] <= 'h0;
                    mean2D_for_next_window[i] <= 'h0;
                    conic_opacity_for_next_window[i] <= 'h0;


                    REB_to_gaussian_SRAM[i] <= 1'b1;
                    REB_to_gaussian_SRAM_FF[i] <= 1'b1;
                end        

                next_window_fetching_pointer <= 'd0;
                next_window_fetching_pointer_FF1 <= 'd0;
                next_window_fetching_pointer_FF2 <= 'd0;

                pixel_n_contrib_for_next_window <= 'd1;
                pixel_n_contrib_for_next_window_FF <= 'd1;

            end

            // Next window fetching
            if (Next_window_state_current == NEXT_WINDOW_FETCHING) begin
                // next_window_fetching_pointer <= next_window_fetching_pointer + gaussian_inputs;
                // next_window_fetching_pointer <= next_window_fetching_pointer_next; 
                if (pixel_n_contrib_for_next_window + gaussian_inputs < last_gaussian_index) begin
                    pixel_n_contrib_for_next_window <= pixel_n_contrib_for_next_window + gaussian_inputs;
                end

                else begin
                    // REB가 무력화되는 조건 : last_gaussian_index보다 크게 설정
                    pixel_n_contrib_for_next_window <= last_gaussian_index + 'd1;
                end

                // pixel_n_contrib_for_next_window_FF가 state 넘기기 위한 신호
                pixel_n_contrib_for_next_window_FF <= pixel_n_contrib_for_next_window;

                for (int i = 0; i < gaussian_inputs; i++) begin
                    REB_to_gaussian_SRAM_FF[i] <= REB_to_gaussian_SRAM[i];

                    if (next_window_fetching_pointer_FF2 + i < WINDOW_SIZE && !REB_to_gaussian_SRAM_FF[gaussian_index_FF2[i]]) begin

                        gaussian_id_for_next_window[next_window_fetching_pointer_FF2 + i] <= gaussian_id_to_SRAM_before[gaussian_index_FF2[i]];
                        gaussian_color_for_next_window[next_window_fetching_pointer_FF2 + i] <= gaussian_color_from_SRAM[gaussian_index_FF2[i]];
                        gaussian_depth_for_next_window[next_window_fetching_pointer_FF2 + i] <= gaussian_depth_from_SRAM[gaussian_index_FF2[i]];
                        mean2D_for_next_window[next_window_fetching_pointer_FF2 + i] <= mean2D_from_SRAM[gaussian_index_FF2[i]];
                        conic_opacity_for_next_window[next_window_fetching_pointer_FF2 + i] <= conic_opacity_from_SRAM[gaussian_index_FF2[i]];
                        
                        
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
    assign SRAM_shift_amount = 'd1;

    assign stall_to_rasterizer_from_controller = 1'b0;

    assign Block_data_ready = Block_ready;

    genvar l;
    generate 

        for (l = 0 ; l < gaussian_inputs; l++) begin : before_indexing
            
            // gaussian index 가 
            // assign gaussian_index[l] = (Next_window_state_current == NEXT_WINDOW_FETCHING) && (max_pixel_n_contrib_for_next_window_current > l) ? (SRAM_shift_amount - l + gaussian_inputs) % gaussian_inputs : 'd0 ;
            assign gaussian_index[l] = (Next_window_state_current == NEXT_WINDOW_FETCHING) ? (SRAM_shift_amount + l) % gaussian_inputs : 'd0 ;
            
            // assign gaussian_id_for_fetching[l] = (Next_window_state_current == NEXT_WINDOW_FETCHING) ? max_pixel_n_contrib_for_next_window_current - l : 'd0;
            // assign gaussian_id_for_fetching[l] = (Next_window_state_current == NEXT_WINDOW_FETCHING) && (pixel_n_contrib_for_next_window + l  < last_gaussian_index) ? pixel_n_contrib_for_next_window + l : 'd0;
            assign gaussian_id_for_fetching[l] = (Next_window_state_current == NEXT_WINDOW_FETCHING) ? pixel_n_contrib_for_next_window + l : 'd0;
        end        

    endgenerate 


    // Window_empty
    // 모든 픽셀에서의 window pointer가 WINDOW SIZE 초과시 반환
    always_comb begin
        window_empty = Gaussian_window_pointer_current[0][$clog2(WINDOW_SIZE)];
        for (int i = 1; i < num_pixels; i++) begin
            window_empty = window_empty && Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)];
        end
    end

    //last_input_done

    always_comb begin
        last_input_done_next = last_input_done_FF;
        for (int i = 0; i < num_pixels; i++) begin
            if (last_input_done_from_rasterizer[i] && start[i]) begin
                last_input_done_next = last_input_done_next + 'd1;
            end
        end
    end

    always_comb begin
        for (int j = 0; j < gaussian_inputs; j++) begin
            gaussian_id_to_SRAM_original_comb[j] = 'd0;
            gaussian_id_to_SRAM_comb[j] = 'd0;
            REB_to_gaussian_SRAM_comb[j] = 1'b1;      


            if (Next_window_state_current == NEXT_WINDOW_FETCHING) begin
                for (int i = 0; i < gaussian_inputs; i++) begin

                    // if (gaussian_index[i] == j[$clog2(gaussian_inputs)-1:0] && gaussian_id_for_fetching[i] > 0) begin
                    if (gaussian_index[i] == j[$clog2(gaussian_inputs)-1:0] && gaussian_id_for_fetching[i] <= last_gaussian_index) begin                        
                        gaussian_id_to_SRAM_original_comb[j] = gaussian_id_for_fetching[i];
                        gaussian_id_to_SRAM_comb[j] = gaussian_id_for_fetching[i] / gaussian_inputs;
                        REB_to_gaussian_SRAM_comb[j] = 1'b0;
                    end

                end
            end
        end
    end



    always_comb begin
        stall_to_controller_from_rasterizer_comb = 1'b0;
        for (int i = 0; i < num_pixels; i++) begin
            stall_to_controller_from_rasterizer_comb = stall_to_controller_from_rasterizer_comb || stall_to_controller_from_rasterizer[i];
        end
    end

    // last input이 모든 pixel에서 반환 여부 확인
    always_comb begin
        all_last_input_done = last_input_done_from_rasterizer[0];
        
        for (int i = 1; i < num_pixels; i++) begin
            all_last_input_done = all_last_input_done && last_input_done_from_rasterizer[i];
        end


    end


endmodule