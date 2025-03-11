
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
    input wire [(3 * precision) - 1:0] gaussian_color_from_SRAM,
    input wire [precision-1:0] gaussian_depth_from_SRAM,
    input wire [(2 * precision)-1:0] mean2D_from_SRAM,
    input wire [(4 * precision)-1:0] conic_opacity_from_SRAM,
    output wire [GID_bit-1:0] gaussian_id_to_SRAM, // 이거 그냥 hash? 그거 처리를 어디서 해야되는지는 추후 고민해야 할 사항


        
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

        reg Block_state_current;
        reg Block_state_next;


        // reg [GID_bit-1:0] block_last_gaussian_index; // SRAM에서의 Gaussian 범위를 알아낼 수 있도록 제작 0번은 NULL로 처리

        reg [$clog2(num_pixels):0] last_input_done_FF;
        reg [$clog2(num_pixels):0] row_FF;

        reg pixel_started;

        // 굳이 16개일 이유가?

            // State
            localparam  BLOCK_IDLE = 1'b0,
                        BLOCK_BUSY = 1'b1;

            // Combinational register (for control signal)
            reg Block_ready;
            wire block_handshake;
            wire gradient_handshake;

        // SRAM Gradient 초기화 신호
        // 1 bit 
        // reg Gradient_first_used_LUT [LUT_SIZE-1:0];
        // reg [LUT_SIZE-1:0] Gradient_first_used_LUT ;
        

            

                    




    // //////////////////////// Window Control ////////////////////////
    // // Window value and W, H, Block id 보관
    // // 가동중인 Row에 대한 컨트롤 


        // Window에 기입해야 하는 최대 index 받아오기
        reg [GID_bit-1:0] current_window_max_index;
        reg [GID_bit-1:0] current_window_max_index_next;
        reg current_window_max_index_is_zero;

        reg [GID_bit-1:0] gaussian_id_to_SRAM_before;






    

    // //////////////////////// Pixel Control ////////////////////////
    // // 각 픽셀에 관한 입력


        reg [$clog2(num_pixels):0] row_next;
        reg [$clog2(num_pixels):0] last_input_done_next;

        // SRAM에서 받는 max_index
        // Gaussian Window 시작점
        reg [GID_bit-1:0] pixel_max_index_from_SRAM;
        reg [GID_bit-1:0] pixel_max_index_from_SRAM_next;

        // SRAM에서 받는 n_contrib
        // current_n_contrib와 동일한 작동
        reg [GID_bit-1:0] pixel_n_contrib [num_pixels-1:0];
        reg [GID_bit-1:0] pixel_n_contrib_next [num_pixels-1:0];
        reg [1:0] pixel_n_contrib_state [num_pixels-1:0];
        reg [$clog2(gaussian_inputs):0] max_valid_j [num_pixels-1:0];
                

        // Combinational Register
        reg REB_to_gaussian_SRAM_before;
        reg REB_to_Pixel_SRAM_before;
        reg REB_to_gradient_SRAM_before [Banks-1:0];
                
        
        reg fetching_at_both_ready_allowed;
        

    //////////////////////// Data Control ////////////////////////

        // FF Register

            // State
            localparam  DATA_IDLE = 2'd0,
                        DATA_SRAM_READY = 2'd1,
                        DATA_PIXEL_READY = 2'd2,
                        DATA_BOTH_READY = 2'd3;

            reg [1:0] Data_state_current;
            reg [1:0] Data_state_next;

        
            
            


    //////////////////////// Gaussian Window ////////////////////////

    // Current Window
        // FF Register
        reg [GID_bit-1:0] gaussian_id_window [WINDOW_SIZE-1:0];
        reg [3 *precision -1:0] gaussian_color_window [WINDOW_SIZE-1:0];
        reg [precision -1 :0] gaussian_depth_window [WINDOW_SIZE-1:0];
        reg [(2 * precision)-1 :0] mean2D_window [WINDOW_SIZE-1:0];
        reg [(4 * precision)-1 :0] conic_opacity_window [WINDOW_SIZE-1:0];

        // Window에서 Rasterizer에 보내는 pointer
        // 각 픽셀에 해당하는 값
        
        reg [$clog2(WINDOW_SIZE):0] Gaussian_window_pointer_current [num_pixels-1:0];


        wire over_the_window [num_pixels-1:0];
        wire pixel_is_not_finished [gaussian_inputs * num_pixels-1:0];
        wire pixel_starting_condition [gaussian_inputs * num_pixels-1:0];

        wire [GID_bit-1:0] gaussian_id_current_window_pointing [num_pixels-1:0];

    
        // Comb Regitser
        wire require_next_window [num_pixels-1:0];

        
    // Next Window
        // FF Register
        reg [GID_bit-1:0] gaussian_id_for_next_window [WINDOW_SIZE-1:0];
        reg [3 * precision -1:0] gaussian_color_for_next_window [WINDOW_SIZE-1:0];
        reg [precision -1 :0] gaussian_depth_for_next_window [WINDOW_SIZE-1:0];
        reg [(2 * precision)-1 :0] mean2D_for_next_window [WINDOW_SIZE-1:0];
        reg [(4 * precision)-1 :0] conic_opacity_for_next_window [WINDOW_SIZE-1:0];

        reg [$clog2(WINDOW_SIZE):0] Gaussian_window_pointer_for_next_window_current;

        // window_pointer_for_next_window MSB = valid 넘겨도 된다. 
        // But 추가 조건, WINDOW SIZE 이하의 값이 남은 경우 전부 0 처리

        wire window_valid;
        // reg window_valid;
        reg window_request;
        wire window_handshake;

        reg [$clog2(WINDOW_SIZE):0] window_counter;
        reg [$clog2(WINDOW_SIZE):0] window_counter_next;


    //////////////////////// Pixel Window ////////////////////////
    
    // // FF Register

    reg [$clog2(num_pixels):0] pixel_pointer_before;
    reg [$clog2(num_pixels):0] pixel_pointer;
    reg [$clog2(num_pixels):0] pixel_pointer_next;


    // pixel_id_pointer MSB가 Valid의 역할




    //////////////////////// Backward Unit Control singal ////////////////////////
    reg [GID_bit-1:0] Write_address_FF [Banks-1:0];
    reg [GID_bit-1:0] Write_address_FF1 [Banks-1:0];

    // reg [GID_bit-1:0] Read_address_from_rasterizer_to_gradient_SRAM [Banks-1:0];

    reg rasterizer_FIFO_pop_valid_in_FF_temp [Banks-1:0];
    reg rasterizer_FIFO_pop_valid_in_FF_temp2 [Banks-1:0];

    reg WEB_to_gradient_SRAM_temp [Banks-1:0];


    // Block state
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            Block_state_current <= BLOCK_IDLE;

            row_FF <= 'd0;
            H <= 'd0;
            W <= 'd0;
            block_id <= 'd0;

            for (int i = 0; i < LUT_SIZE; i++) begin
                Gradient_first_used_LUT[i] <= 1'b0;
            end
            // Gradient_first_used_LUT <= 'b0;

            for (int j = 0; j < Banks; j++) begin
                Write_address_FF[j] <= 'h0;
                Write_address_FF1[j] <= 'h0;
                rasterizer_FIFO_pop_valid_in_FF_temp[j] <= 'h0;
                rasterizer_FIFO_pop_valid_in_FF_temp2[j] <= 'h0;
                WEB_to_gradient_SRAM_temp[j] <= 'b1;
            end

        end 

        else begin
            Block_state_current <= Block_state_next;
            row_FF <= row_next;

            // Add this condition to update H and W when transitioning states
            if (Data_state_current == DATA_IDLE && Data_state_next == DATA_SRAM_READY) begin
                row_FF <= 'd0;
                H <= H_in;
                W <= W_in;
                block_id <= block_id_in;

                for (int i = 0; i < LUT_SIZE; i++) begin
                    Gradient_first_used_LUT[i] <= 1'b0;
                end                
                // Gradient_first_used_LUT <= 'b0;
                
            end

            for (int j = 0; j < Banks; j++) begin
                Write_address_FF1[j] <= Read_address_from_rasterizer_to_gradient_SRAM[j];
                Write_address_FF[j] <= Write_address_FF1[j];
                rasterizer_FIFO_pop_valid_in_FF_temp[j] <= rasterizer_FIFO_pop_valid_in[j];
                rasterizer_FIFO_pop_valid_in_FF_temp2[j] <= rasterizer_FIFO_pop_valid_in_FF_temp[j];
                WEB_to_gradient_SRAM_temp[j] <= !rasterizer_FIFO_pop_valid_in_FF_temp[j];


                Gradient_first_used_LUT[Read_address_from_rasterizer_to_gradient_SRAM[j]] <= 1'b1;

            end            

        end

    end




    assign Block_data_ready = Block_ready;
    assign block_handshake = Block_data_done && Block_data_ready;


    // Block state FSM
    always_comb begin
        Block_state_next = Block_state_current;
        Block_ready = 1'b0;
        

        case (Block_state_current)

            // Block 데이터가 준비되지 않음 && Gradient 반환 중
            BLOCK_IDLE: begin
                Block_ready = 1'b1;

                if (block_handshake) begin
                    Block_state_next = BLOCK_BUSY;
                end
            end

            // Block Rasterizing 진행 중
            BLOCK_BUSY: begin
                // 마지막 row에 도달한 경우
                // if (row_FF == num_pixels) begin        
                if (gradient_handshake) begin
                    Block_state_next = BLOCK_IDLE;
                end
            end

        endcase
    end

    // REB and WEB
    // assign REB_to_gaussian_SRAM = (Data_state_current == DATA_PIXEL_READY) ? Gaussian_window_pointer_for_next_window_current[$clog2(WINDOW_SIZE)] : 1'b1;
    // Gaussian SRAM을 State 3 에서 가져오는 경우에는 특정 조건이 붙어야 함.
    assign REB_to_gaussian_SRAM = (Data_state_current == DATA_PIXEL_READY) || (Data_state_current == DATA_BOTH_READY && fetching_at_both_ready_allowed) ? Gaussian_window_pointer_for_next_window_current[$clog2(WINDOW_SIZE)] : 1'b1;

    assign gaussian_id_to_SRAM = (Data_state_current == DATA_PIXEL_READY) ? current_window_max_index : 'd0;
    
    // assign REB_to_Pixel_SRAM = 1'b1;
    assign REB_to_Pixel_SRAM =  (Data_state_current == DATA_SRAM_READY) ? pixel_pointer[$clog2(num_pixels)] : 1'b1;
    assign Read_address_to_Pixel_SRAM = {3'h0, pixel_pointer};


    // current_window_max_index == 0이고 write할 1 cycle 필요
    // 1. window가 채워지기 전에 n contrib가 0이 되는 경우 , 그냥 이거는 comb로직으로 처리하면 되는거 아님?
    // 2. window가 다 채워지는 경우
    // assign window_valid = (current_window_max_index_is_zero && (gaussian_id_for_next_window[0] != 0)) || Gaussian_window_pointer_for_next_window_current[$clog2(WINDOW_SIZE)];
    assign window_valid = (gaussian_id_for_next_window[0] != 0) && ((current_window_max_index_is_zero) || Gaussian_window_pointer_for_next_window_current[$clog2(WINDOW_SIZE)]);
    
    // assign window_valid = (current_window_max_index_is_zero ) || Gaussian_window_pointer_for_next_window_current[$clog2(WINDOW_SIZE)];
    
    assign window_handshake = window_valid && window_request;

    // Stall to Rasterizer from controller
    assign stall_to_rasterizer_from_controller = 1'b0;

    assign gradient_value_valid = (Block_state_current == BLOCK_BUSY) && (row_FF == num_pixels);
    assign gradient_handshake = gradient_value_valid && gradient_value_ready;

    genvar m, l, n;
    generate

        for (m = 0; m < Banks; m++) begin : SRAM_control_signals
            assign WEB_to_gradient_SRAM[m] = WEB_to_gradient_SRAM_temp[m];

            assign REB_to_gradient_SRAM[m] = rasterizer_FIFO_pop_ready_out[m] && (!((Write_address_FF[m] == Read_address_from_rasterizer_to_gradient_SRAM[m]) && rasterizer_FIFO_pop_valid_in_FF_temp2[m]) || Read_address_from_rasterizer_to_gradient_SRAM[m] == 0) ? 1'b0 : 1'b1;

            assign rasterizer_FIFO_pop_valid_in[m] = (rasterizer_FIFO_pop_ready_out[m]) && (!((Write_address_FF[m] == Read_address_from_rasterizer_to_gradient_SRAM[m]) && rasterizer_FIFO_pop_valid_in_FF_temp2[m]) || Read_address_from_rasterizer_to_gradient_SRAM[m] == 0) ? 1'b1 : 1'b0;

            // 이번 블록에서 사용한 ID를 통해서 초기 Gradient 값인 경우 (XXXX) 인 경우 0으로 처리하여 더할 수 있게끔 설정
            // 전 state에서 Read Action 수행 확인
            assign gradient_ID_used[m] = Gradient_first_used_LUT[Read_address_from_rasterizer_to_gradient_SRAM[m]] && !REB_to_gradient_SRAM_before[m];
            // assign gradient_ID_used[m] = !REB_to_gradient_SRAM_before[m];
        end

        for (l = 0; l < num_pixels; l++) begin : window_control
            // 추가 조건 필요
            // 1'b0자리에 n_contrib과 관련된 조건 필요
            // assign require_next_window[l] = (Data_state_current == DATA_PIXEL_READY)  || ((Data_state_current == DATA_BOTH_READY) && (pixel_n_contrib[l] <= current_window_max_index));
            assign require_next_window[l] = (Data_state_current == DATA_PIXEL_READY)  || ((Data_state_current == DATA_BOTH_READY) && (pixel_n_contrib[l] <= current_window_max_index));
            assign over_the_window[l] = (pixel_n_contrib[l] >= gaussian_id_window[WINDOW_SIZE - 1]) ? 1'b0 : 1'b1;


            assign gaussian_id_current_window_pointing[l] = gaussian_id_window[Gaussian_window_pointer_current[l][$clog2(WINDOW_SIZE)-1:0]];


            // pixel is not finished = 
            for (n = 0; n < gaussian_inputs; n++) begin : pixel_is_not_finished_gen
                assign pixel_is_not_finished[l * gaussian_inputs + n] = (pixel_n_contrib[l] > n) ? 1'b1 : 1'b0;
                assign pixel_starting_condition[l * gaussian_inputs + n] = (pixel_n_contrib[l] >= gaussian_id_window[Gaussian_window_pointer_current[l][$clog2(WINDOW_SIZE)-1:0] + n]) && pixel_is_not_finished[l * gaussian_inputs + n] ? 1'b1 : 1'b0;


                
            end
        end
    endgenerate


    // DATA STATE
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            Data_state_current <= DATA_IDLE;
            pixel_pointer <= 'd0;
            pixel_pointer_before <= 'd0;   

            // row_FF <= 'd0;
            last_input_done_FF <= 'd0;

            for (int i= 0; i < WINDOW_SIZE; i++) begin
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

                T_first_current[i] <= 'd0;
                dL_dpixel_current[i] <= 'd0;
                dL_dpixel_depth_current[i] <= 'd0;
                pixel_n_contrib[i] <= 'd0;
                start[i] <= 1'b0;

                pixel_id[i] <= 'd0;

                

                for (int j = 0; j < gaussian_inputs; j++) begin
                    // i_valid[i * gaussian_inputs + j] <= 1'b0;
                    last_input_done_to_pixel[i * gaussian_inputs + j] <= 1'b0;
                    gaussian_id_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                    gaussian_color_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                    gaussian_depth_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                    mean2D_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                    conic_opacity_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                end

            end

            REB_to_Pixel_SRAM_before <= 1'b1;
            REB_to_gaussian_SRAM_before <= 1'b1;

            for (int i = 0; i < Banks; i++) begin
                REB_to_gradient_SRAM_before[i] <= 1'b1;
            end

            Gaussian_window_pointer_for_next_window_current <= 'd0;
            current_window_max_index <= 'd0;

            pixel_max_index_from_SRAM <= 'd0;
            gaussian_id_to_SRAM_before <= 'd0;

            pixel_started <= 1'b0;

            window_counter <= 'd0;

            current_window_max_index_is_zero <= 1'b0;

        end

        // 리셋이 아닌 경우
        else begin


            // stall 조건시
        
            
            Data_state_current <= Data_state_next;
            current_window_max_index <= current_window_max_index_next;
            window_counter <= window_counter_next;
            pixel_max_index_from_SRAM <= pixel_max_index_from_SRAM_next;

            // row_FF <= row_next;
            last_input_done_FF <= last_input_done_next;

            REB_to_gradient_SRAM_before <= REB_to_gradient_SRAM;

            REB_to_gaussian_SRAM_before <= REB_to_gaussian_SRAM;
            gaussian_id_to_SRAM_before <= gaussian_id_to_SRAM;

            // pixel_pointer <= pixel_pointer_next;

            pixel_pointer_before <= pixel_pointer;
            REB_to_Pixel_SRAM_before <= REB_to_Pixel_SRAM;

            if (Data_state_current == DATA_SRAM_READY && Data_state_next == DATA_PIXEL_READY) begin
                pixel_pointer <= 'd0;
                pixel_max_index_from_SRAM <= 'd0;

            end
            else begin
                pixel_pointer <= pixel_pointer_next;
            end

            for (int i = 0; i < num_pixels; i++) begin
                pixel_id[i] <= row_FF * num_pixels + i;
            end

            if (window_handshake) begin
                for (int i = 0; i< WINDOW_SIZE; i++) begin
                    gaussian_id_window[i] <= gaussian_id_for_next_window[i];
                    gaussian_color_window[i] <= gaussian_color_for_next_window[i];
                    gaussian_depth_window[i] <= gaussian_depth_for_next_window[i];
                    mean2D_window[i] <= mean2D_for_next_window[i];
                    conic_opacity_window[i] <= conic_opacity_for_next_window[i];
                    Gaussian_window_pointer_current[i] <= 'd0;


                    gaussian_id_for_next_window[i] <= 'd0;
                    gaussian_color_for_next_window[i] <= 'd0;
                    gaussian_depth_for_next_window[i] <= 'd0;
                    mean2D_for_next_window[i] <= 'd0;
                    conic_opacity_for_next_window[i] <= 'd0;
                end

                window_counter <= 'd0;
                Gaussian_window_pointer_for_next_window_current <= 'd0;

            end         

            // if (current_window_max_index == 'd0) begin
            //     current_window_max_index_is_zero <= 1'b1;
            // end

            // else begin
            //     current_window_max_index_is_zero <= 1'b0;
            // end

            case (Data_state_current)

                // 'd0
                DATA_IDLE: begin
                    pixel_pointer <= 'd0;
                    pixel_pointer_before <= 'd0;

                    Gaussian_window_pointer_for_next_window_current <= 'd0;
                    last_input_done_FF <= 'd0;
                    // row_FF <= 'd0;
                    current_window_max_index <= 'd0;
                    window_counter <= 'd0;

                // State 3 제외 에서는 모든 output 값 초기화
                    for (int i = 0; i < num_pixels; i++) begin
                        for (int j= 0; j < gaussian_inputs; j++) begin
                            last_input_done_to_pixel[i * gaussian_inputs + j] <= 1'b0;
                            gaussian_id_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                            gaussian_color_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                            gaussian_depth_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                            mean2D_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                            conic_opacity_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                        end
                    end

                end

                
                // 'd1
                DATA_SRAM_READY: begin

                    // Gaussian_window_pointer_for_next_window_current <= 'd0;

                    pixel_started <= 1'b0;
                    
                    if (!REB_to_Pixel_SRAM_before) begin // input data is valid 인 경우
                        
                        T_first_current[pixel_pointer_before[$clog2(num_pixels)-1:0]] <= next_T_first_from_SRAM;
                        dL_dpixel_current[pixel_pointer_before[$clog2(num_pixels)-1:0]] <= next_dL_dpixel_from_SRAM;
                        dL_dpixel_depth_current[pixel_pointer_before[$clog2(num_pixels)-1:0]] <= next_dL_dpixel_depth_from_SRAM;
                        pixel_n_contrib[pixel_pointer_before[$clog2(num_pixels)-1:0]] <= next_n_contrib_from_SRAM;

                        // if (next_n_contrib_from_SRAM > pixel_max_index_from_SRAM) begin
                        //     pixel_max_index_from_SRAM <= next_n_contrib_from_SRAM;
                        // end

                    end

                    if (current_window_max_index == 'd0) begin
                        current_window_max_index_is_zero <= 1'b1;
                    end

                    else begin
                        current_window_max_index_is_zero <= 1'b0;
                    end

                // State 3 제외 에서는 모든 output 값 초기화
                    for (int i = 0; i < num_pixels; i++) begin
                        for (int j= 0; j < gaussian_inputs; j++) begin
                            last_input_done_to_pixel[i * gaussian_inputs + j] <= 1'b0;
                            gaussian_id_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                            gaussian_color_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                            gaussian_depth_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                            mean2D_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                            conic_opacity_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                        end
                    end


                end

                // 'd2
                DATA_PIXEL_READY: begin

                    // REB_to_gaussian_SRAM_before <= REB_to_gaussian_SRAM;
                    // gaussian_id_to_SRAM_before <= gaussian_id_to_SRAM;

                    if (current_window_max_index == 'd0) begin
                        current_window_max_index_is_zero <= 1'b1;
                    end

                    else begin
                        current_window_max_index_is_zero <= 1'b0;
                    end
                    

                    if (Data_state_next == DATA_SRAM_READY) begin
                        last_input_done_FF <= 'd0;
                    end

                    Gaussian_window_pointer_for_next_window_current <= 'd0;

                    // 이거 신호도 다음 row 필요시 0으로 전환해야 함. 
                    if (!pixel_started) begin
                        for (int i =0; i< num_pixels; i++) begin
                            start[i] <= 1'b1;
                            pixel_started <= 1'b1;
                        end
                    end

                    else begin
                        for (int i=0; i< num_pixels; i++) begin
                            start[i] <= 1'b0;
                            T_first_current[i] <= 'd0;
                            dL_dpixel_current[i] <= 'd0;
                            dL_dpixel_depth_current[i] <= 'd0;
                            // pixel_n_contrib[i] <= 'd0;
                        end
                    end




                    if (Gaussian_window_pointer_for_next_window_current < WINDOW_SIZE) begin
                                           
                        if (!REB_to_gaussian_SRAM_before) begin

                            gaussian_id_for_next_window[Gaussian_window_pointer_for_next_window_current[$clog2(WINDOW_SIZE)-1:0]] <= gaussian_id_to_SRAM_before;
                    
                            gaussian_color_for_next_window[Gaussian_window_pointer_for_next_window_current[$clog2(WINDOW_SIZE)-1:0]] <= gaussian_color_from_SRAM;
                            gaussian_depth_for_next_window[Gaussian_window_pointer_for_next_window_current[$clog2(WINDOW_SIZE)-1:0]] <= gaussian_depth_from_SRAM;
                            mean2D_for_next_window[Gaussian_window_pointer_for_next_window_current[$clog2(WINDOW_SIZE)-1:0]] <= mean2D_from_SRAM;
                            conic_opacity_for_next_window[Gaussian_window_pointer_for_next_window_current[$clog2(WINDOW_SIZE)-1:0]] <= conic_opacity_from_SRAM;
        
                            Gaussian_window_pointer_for_next_window_current <= Gaussian_window_pointer_for_next_window_current + 'd1;
                        end
                    end

                    else begin
                        Gaussian_window_pointer_for_next_window_current <= 'd0;
                    end



                // State 3 제외 에서는 모든 output 값 초기화
                    for (int i = 0; i < num_pixels; i++) begin
                        for (int j= 0; j < gaussian_inputs; j++) begin

                            if (!stall_to_controller_from_rasterizer[i]) begin
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


                // Pixel 데이터와 Gaussian Data가 준비됨.

                // 'd3  
                DATA_BOTH_READY: begin

                    if (current_window_max_index == 'd0) begin
                        current_window_max_index_is_zero <= 1'b1;
                    end

                    else begin
                        current_window_max_index_is_zero <= 1'b0;
                    end
                    

                    // data3에서도 시도
                    if (Gaussian_window_pointer_for_next_window_current < WINDOW_SIZE) begin
                                           
                        if (!REB_to_gaussian_SRAM_before) begin

                            gaussian_id_for_next_window[Gaussian_window_pointer_for_next_window_current[$clog2(WINDOW_SIZE)-1:0]] <= gaussian_id_to_SRAM_before;
                    
                            gaussian_color_for_next_window[Gaussian_window_pointer_for_next_window_current[$clog2(WINDOW_SIZE)-1:0]] <= gaussian_color_from_SRAM;
                            gaussian_depth_for_next_window[Gaussian_window_pointer_for_next_window_current[$clog2(WINDOW_SIZE)-1:0]] <= gaussian_depth_from_SRAM;
                            mean2D_for_next_window[Gaussian_window_pointer_for_next_window_current[$clog2(WINDOW_SIZE)-1:0]] <= mean2D_from_SRAM;
                            conic_opacity_for_next_window[Gaussian_window_pointer_for_next_window_current[$clog2(WINDOW_SIZE)-1:0]] <= conic_opacity_from_SRAM;
        
                            Gaussian_window_pointer_for_next_window_current <= Gaussian_window_pointer_for_next_window_current + 'd1;
                        end
                    end

                    else begin
                        Gaussian_window_pointer_for_next_window_current <= 'd0;
                    end


                    

                    for (int i = 0; i < num_pixels; i++) begin

                        // stall시 현상유지 그외 조건들은 0 처리
                        if (!stall_to_controller_from_rasterizer[i]) begin
                        // Pixel의 Window index가 32를 넘지 않는 경우

                            if (!Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)] && (!over_the_window[i])) begin                            

                                for (int j = 0; j < gaussian_inputs; j++) begin

                                    if ((Gaussian_window_pointer_current[i] + j < WINDOW_SIZE) && (pixel_is_not_finished[i * gaussian_inputs + j]) && (pixel_starting_condition[i * gaussian_inputs + j])) begin
                                    // if ((Gaussian_window_pointer_current[i] + j < WINDOW_SIZE) && (pixel_is_not_finished[i * gaussian_inputs + j])) begin                                        
                                        
                                        gaussian_id_to_rasterizer[i * gaussian_inputs + j] <= gaussian_id_window[Gaussian_window_pointer_current[i] + j];
                                        gaussian_color_to_rasterizer[i * gaussian_inputs + j] <= gaussian_color_window[Gaussian_window_pointer_current[i] + j];
                                        gaussian_depth_to_rasterizer[i * gaussian_inputs + j] <= gaussian_depth_window[Gaussian_window_pointer_current[i] + j];
                                        mean2D_to_rasterizer[i * gaussian_inputs + j] <= mean2D_window[Gaussian_window_pointer_current[i] + j];
                                        conic_opacity_to_rasterizer[i * gaussian_inputs + j] <= conic_opacity_window[Gaussian_window_pointer_current[i] + j];

                                        
                                        // last input 조건 
                                        if (pixel_n_contrib[i] == j + 1) begin
                                            last_input_done_to_pixel[i * gaussian_inputs + j] <= 1'b1;
                                        end

                                        else begin
                                            last_input_done_to_pixel[i * gaussian_inputs + j] <= 1'b0;
                                        end

                                    end

                                    else begin
                                        // i_valid[i * gaussian_inputs + j] <= 1'b0;

                                        last_input_done_to_pixel[i * gaussian_inputs + j] <= 1'b0;
                                        gaussian_id_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                                        gaussian_color_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                                        gaussian_depth_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                                        mean2D_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                                        conic_opacity_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                                    end                                 

                                end

                                Gaussian_window_pointer_current[i] <= Gaussian_window_pointer_current[i] + gaussian_inputs;

                                pixel_n_contrib[i] <= pixel_n_contrib_next[i];

                            end


                            else begin
                                for (int j = 0; j < gaussian_inputs; j++) begin

                                    last_input_done_to_pixel[i * gaussian_inputs + j] <= 1'b0;
                                    gaussian_id_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                                    gaussian_color_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                                    gaussian_depth_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                                    mean2D_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                                    conic_opacity_to_rasterizer[i * gaussian_inputs + j] <= 'd0;

                                end                            
                            end
                        end


                        // // stall 인데 window가 끝나는 것으로 판단하는 경우
                        // else if () begin
                        //     for (int j = 0; j < gaussian_inputs; j++) begin
                        //         last_input_done_to_pixel[i * gaussian_inputs + j] <= 1'b0;
                        //         gaussian_id_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                        //         gaussian_color_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                        //         gaussian_depth_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                        //         mean2D_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                        //         conic_opacity_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                        //     end
                        // end


                    end

                end

            endcase
        end
    end


    // always_ff for i_valid
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            for (int i = 0; i < num_pixels; i++) begin
                for (int j = 0; j < gaussian_inputs; j++) begin
                    i_valid[i * gaussian_inputs + j] <= 1'b0;
                end
            end
        end
        else begin


            case (Data_state_current)

                DATA_IDLE:begin
                    for (int i = 0; i < num_pixels; i++) begin
                        for (int j = 0; j < gaussian_inputs; j++) begin
                            i_valid[i * gaussian_inputs + j] <= 1'b0;
                        end
                    end
                end

                DATA_SRAM_READY: begin
                    for (int i = 0; i < num_pixels; i++) begin
                        for (int j = 0; j < gaussian_inputs; j++) begin
                            i_valid[i * gaussian_inputs + j] <= 1'b0;
                        end
                    end
                end

                DATA_PIXEL_READY: begin
                    for (int i = 0; i < num_pixels; i++) begin
                        for (int j = 0; j < gaussian_inputs; j++) begin
                            i_valid[i * gaussian_inputs + j] <= 1'b0;
                        end
                    end
                end

                // 'd3
                DATA_BOTH_READY: begin
                    for (int i = 0; i < num_pixels; i++) begin
                        if(!stall_to_controller_from_rasterizer[i]) begin

                            if (!Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)] && (!over_the_window[i])) begin
                                for (int j = 0; j < gaussian_inputs; j++) begin

                                    if ((Gaussian_window_pointer_current[i] + j < WINDOW_SIZE) && (pixel_is_not_finished[i * gaussian_inputs + j]) && (pixel_starting_condition[i * gaussian_inputs + j])) begin                                
                                    // if ((Gaussian_window_pointer_current[i] + j < WINDOW_SIZE) && (pixel_is_not_finished[i * gaussian_inputs + j])) begin                                
                                        i_valid[i * gaussian_inputs + j] <= 1'b1;
                                    end

                                    else begin
                                        i_valid[i * gaussian_inputs + j] <= 1'b0;
                                    end
                                end
                            end

                            else begin
                                for (int j = 0; j < gaussian_inputs; j++) begin
                                    i_valid[i * gaussian_inputs + j] <= 1'b0;
                                end
                            end

                        end
                    end
                end


            endcase
        end
    end


    always_comb begin
        Data_state_next = Data_state_current;
        pixel_pointer_next = pixel_pointer;
        row_next = row_FF;
        current_window_max_index_next = current_window_max_index;
        window_counter_next = window_counter;
        pixel_max_index_from_SRAM_next = pixel_max_index_from_SRAM;
        fetching_at_both_ready_allowed = 1'b0;


        
        case (Data_state_current)

            // 'd0
            DATA_IDLE: begin
                
                if (block_handshake) begin
                    Data_state_next = DATA_SRAM_READY;
                end
            end

            // PIXEL DATA 가져오기 + 이번 Row의 Max n_contrib 확인

            // 'd1
            DATA_SRAM_READY: begin

                pixel_pointer_next = pixel_pointer + 'd1;

                if (next_n_contrib_from_SRAM > pixel_max_index_from_SRAM) begin
                    pixel_max_index_from_SRAM_next = next_n_contrib_from_SRAM;
                end

                // Block의 연산이 전부 끝난 상태
                // Gradient 전송일때는 Data IDLE에서 대기. 하지만 다음 Block 데이터를 Top으로 부터 받을 여지를 남겨놓은 상태
                if ((last_input_done_next[$clog2(num_pixels)]) && (row_next[$clog2(num_pixels)])) begin
                    Data_state_next = DATA_IDLE;
                end

                // 한 Row에 대한 픽셀의 데이터 전부 수신

                // else if (pixel_pointer[$clog2(num_pixels)]) begin
                else if (pixel_pointer[$clog2(num_pixels)]) begin
                    current_window_max_index_next = pixel_max_index_from_SRAM_next;
                    Data_state_next = DATA_PIXEL_READY;
                end
            end

            // Pixel 데이터 다 가져왔고, Gaussian Window에 해당하는 데이터 Fetching하는 시기
            // 'd2
            DATA_PIXEL_READY: begin

                // Window 사이즈 다 Fetch시 Both Data ready state로 이동

                if (window_counter_next < WINDOW_SIZE && current_window_max_index > 'd0) begin
                    window_counter_next = window_counter_next + 'd1;
                    current_window_max_index_next = current_window_max_index - 'd1;
                end

                else begin
                    if (window_handshake) begin
                        // if (current_window_max_index != 'd0) begin
                        //     current_window_max_index_next = current_window_max_index + 'd1;
                        // end

                        Data_state_next = DATA_BOTH_READY;
                    end
                    else begin
                        current_window_max_index_next = current_window_max_index ;
                    end
                end

                // 한 Block에 대한 모든 데이터 수신 완료시 IDLE
                if ((last_input_done_next[$clog2(num_pixels)]) && (row_next[$clog2(num_pixels)])) begin
                    Data_state_next = DATA_IDLE; // 'd0
                end

                // 한 Row에 대한 모든 데이터 수신 완료시 Pixel Ready로 이동
                else if (last_input_done_next[$clog2(num_pixels)]) begin
                    Data_state_next = DATA_SRAM_READY; // d1
                    row_next = row_next + 'd1;
                end
            end

            // 'd3
            DATA_BOTH_READY: begin

                
                // // fetching 상태
                // if (window_counter_next < WINDOW_SIZE && current_window_max_index > 'd0) begin
                //     window_counter_next = window_counter_next + 'd1;
                //     current_window_max_index_next = current_window_max_index - 'd1;
                //     fetching_at_both_ready_allowed = 1'b1;
                // end
                
                // 한 Gaussian Window 처리 완료시 Window 가지러 가기
                if (window_request && !window_valid) begin
                    Data_state_next = DATA_PIXEL_READY; // 'd2
                end
            end

        endcase 
    end

    // last_input
    always_comb begin
        last_input_done_next = last_input_done_FF;
        for (int i = 0; i < Banks; i++) begin
            if (last_input_done_from_rasterizer[i]) begin
                last_input_done_next = last_input_done_next + 'd1;
            end
        end
    end

    // window request 조건
    // 근데 나머지가 다 0이고 한 픽셀만 0이 아닌 경우는?
    always_comb begin
        window_request = 1'b1;
        for (int i = 0; i < num_pixels; i++) begin
            // window_request = window_request && (require_next_window[i] && (pixel_n_contrib[i] != 0)) ;
            window_request = window_request && (require_next_window[i]) ;
        end
    end


    // Pixel n_contrib next
    always_comb begin
        for (int i =0; i < num_pixels; i++) begin
            pixel_n_contrib_next[i] = pixel_n_contrib[i];
            pixel_n_contrib_state[i] = 'd0;
            max_valid_j[i] = 'd0;

            if (Data_state_current == DATA_BOTH_READY) begin

                // 조건 1. pixel_n_contrib가 gaussian_input보다 작다
                if (pixel_n_contrib[i] < gaussian_inputs) begin
                    pixel_n_contrib_next[i] = 'd0;
                    pixel_n_contrib_state[i] = 'd3;
                end



                // 조건 2. pixel_n_contrib가 window 최소값보다 작은 경우
                else if (pixel_n_contrib[i] - gaussian_inputs < gaussian_id_window[WINDOW_SIZE - 1]) begin
                    
                    pixel_n_contrib_next[i] = gaussian_id_window[WINDOW_SIZE - 1] - 'd1;
                    pixel_n_contrib_state[i] = 'd1;
                end

                

                
                // 조건 3. window 진행 중
                // else if (pixel_n_contrib[i] >= gaussian_id_window[Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)-1:0]] ) begin
                // else if (pixel_n_contrib[i] >= gaussian_id_window[Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)-1:0]] &&  Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)-1:0] + gaussian_inputs < WINDOW_SIZE) begin

                // else if (pixel_n_contrib[i] >= gaussian_id_window[Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)-1:0]] &&  Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)-1:0]< WINDOW_SIZE) begin
                else if (pixel_n_contrib[i] >= gaussian_id_window[Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)-1:0] + gaussian_inputs - 1] &&  Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)-1:0] < WINDOW_SIZE) begin                    
                    //
                    for (int j = 0; j < gaussian_inputs; j++) begin
                    // for (int j = gaussian_inputs-1; j >= 0; j--) begin
                        // some condition to pixel_n_contrib_next[i]
                        // if (pixel_n_contrib[i] >= gaussian_id_window[Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)-1:0] - j] && Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)-1:0] + j < WINDOW_SIZE) begin
                        // if (Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)-1:0] + j < WINDOW_SIZE && pixel_n_contrib[i] >= gaussian_id_window[Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)-1:0] + j] &&  Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)-1:0] + j < WINDOW_SIZE) begin
                        if ((Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)-1:0] + j ) < WINDOW_SIZE && (pixel_n_contrib[i] >= gaussian_id_window[Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)-1:0] + j])) begin                            
                            // pixel_n_contrib_next[i] = pixel_n_contrib_next[i] - (j + 1);   
                            pixel_n_contrib_state[i] = 'd2;
                            max_valid_j[i] = max_valid_j[i] + 1;
                        end
                    end         

                    pixel_n_contrib_next[i] = pixel_n_contrib_next[i] - max_valid_j[i];   
                end

            end   
        end
    end
    

endmodule