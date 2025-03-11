module Backward_Pixel_group_controller_before_SRAM #(
    parameter BLOCK_SIZE = 16,
    parameter exponent_bit = 8,
    parameter mantissa_bit = 7,
    parameter precision = 16,
    parameter gaussian_inputs = 3, // in one pixel unit, gaussians
    parameter num_pixels = 16, // number of pixel units
    parameter GID_bit = 24,
    parameter WINDOW_SIZE = 32    
    ) 

    (
    input wire clk,
    input wire rst_n,

    // Input from Block Controller (Currently Testbench)
    input wire [11:0] W_in,
    input wire [11:0] H_in,
    input wire [15:0] block_id_in,

    // SRAM 데이터가 다 받았을때 Block controller에서 오는 신호
    // Gaussian Window랑은 일단 별개로 생각

    // input wire start_from_block_controller,
    // start를 hs 후 받은걸 기준으로 처리

    input wire pixel_values_from_block_control_valid,
    input wire gaussian_window_values_from_block_control_valid,

    input wire [$clog2(num_pixels)-1:0] current_row_from_block_controller,


    // Output to Block Controller (Currently Testbench)
    // output wire all_block_work_done_out, // Gradient도 인지 아니면 Raster만 done인지도 판단 필요
    output wire pixel_values_to_block_control_ready, // 다음 Pixel 값 n_contrib, T, Loss 요청
    output wire gaussian_window_values_to_block_control_ready, // Window에 넣을 다음 Gaussian 값 요청

    // Input from Backward Pixel Group Unit
    input wire stall_to_controller_from_rasterizer [num_pixels-1:0],

    // 이거는 Bank에서 오는거긴한데... 현재까지는 이거로
    input wire last_input_done_from_rasterizer [num_pixels-1:0],


    // Output to Backward Pixel Group Unit
    // start가 Rasterizer의 semi-reset 신호
    output reg start [num_pixels-1:0],
    
    output reg [(3 * precision) - 1:0] dL_dpixel [num_pixels-1:0],
    output reg [precision - 1:0] dL_dpixel_depth [num_pixels-1:0],
    output reg [precision - 1:0] T_first [num_pixels-1:0],
    output reg [(2 * $clog2(BLOCK_SIZE) - 1): 0] pixel_id_to_pixel [num_pixels-1:0],    


    output reg i_valid [gaussian_inputs * num_pixels - 1:0],
    output reg last_input_to_pixel [gaussian_inputs * num_pixels - 1:0],
    output reg [GID_bit-1:0] gaussian_id_to_rasterizer [gaussian_inputs * num_pixels - 1:0],
    output reg [(3 * precision)-1:0] gaussian_color_to_rasterizer [gaussian_inputs * num_pixels - 1:0],
    output reg [precision-1:0] gaussian_depth_to_rasterizer [gaussian_inputs * num_pixels - 1:0],
    output reg [(2 * precision)-1:0] mean2D_to_rasterizer [gaussian_inputs * num_pixels - 1:0],
    output reg [(4 * precision)-1:0] conic_opacity_to_rasterizer [gaussian_inputs * num_pixels - 1:0],




    // Input from Backward Gradient Merge Unit SRAM


    // 합칠때 사용, 현재는 Backward Rasterizer만
    // // Output to Backward Gradient Merge Unit SRAM
    // output wire WEB_to_SRAM [num_pixels-1:0],
    // output wire REB_to_SRAM [num_pixels-1:0],


    // Input from SRAM, Pixel values (Currently Testbench)
        // As Backward Rasterizer Input
    input wire [GID_bit-1:0] next_n_contrib_from_SRAM [num_pixels-1:0],
    input wire [precision-1:0] next_T_first_from_SRAM [num_pixels-1:0],
    input wire [(3 * precision)-1:0] next_dL_dpixel_from_SRAM [num_pixels-1:0],
    input wire [precision-1:0] next_dL_dpixel_depth_from_SRAM [num_pixels-1:0],


    // Input from SRAM, Window values
    // 이게 사실 1 ~ n_contrib까지의 Hashing 된 값.
    input wire [GID_bit-1:0] gaussian_id_from_SRAM [WINDOW_SIZE-1:0],

    input wire [(3 * precision)-1:0] gaussian_color_from_SRAM [WINDOW_SIZE-1:0],
    input wire [precision-1:0] gaussian_depth_from_SRAM [WINDOW_SIZE-1:0],
    input wire [(2 * precision)-1:0] mean2D_from_SRAM [WINDOW_SIZE-1:0],
    input wire [(4 * precision)-1:0] conic_opacity_from_SRAM [WINDOW_SIZE-1:0]
    

    // // Output to SRAM (Currently Testbench)
    //     As Backward Gradient Merge Unit Control to SRAM
    // // output wire WEB_to_SRAM [num_pixels-1:0],
    // // output wire REB_to_SRAM [num_pixels-1:0]
    );


    //////////////////////// GlobalPixel Control ////////////////////////
    // Window value and W, H, Block id 보관
    // 가동중인 Row에 대한 컨트롤 

        // FF Register

        // reg [$clog2(num_pixels):0] row_current;
        reg [$clog2(num_pixels):0] last_input_done_FF;

        reg [11:0] W;
        reg [11:0] H;
        reg [15:0] block_id;


            // State 
            localparam  IDLE = 2'b00,
                        WORKING = 2'b01,
                        GAUSSIAN_MEMORY_FETCHING = 2'b10,
                        ROW_DONE = 2'b11;

            reg [1:0] state_current ;
            reg [1:0] state_next;

            // Next State Register


        // Comb Register
        // reg [$clog2(num_pixels):0] row_next;
        reg [$clog2(num_pixels):0] last_input_done_next;

        reg request_next_row;
        reg request_next_window;
        
        // Wire


    //////////////////////// SubPixel Control ////////////////////////
    // 각 픽셀에 관한 입력

        // FF Register

        reg pixel_working [num_pixels-1:0];
        
        reg [GID_bit-1:0] current_n_contrib [num_pixels-1:0];

    
        // Wire
        


    //////////////////////// Gaussian Window ////////////////////////

        // FF Register
        reg [GID_bit-1:0] gaussian_id_window [WINDOW_SIZE-1:0];
        reg [3 *precision -1:0] gaussian_color_window [WINDOW_SIZE-1:0];
        reg [precision -1 :0] gaussian_depth_window [WINDOW_SIZE-1:0];
        reg [(2 * precision)-1 :0] mean2D_window [WINDOW_SIZE-1:0];
        reg [(4 * precision)-1 :0] conic_opacity_window [WINDOW_SIZE-1:0];

        // reg [$clog2(WINDOW_SIZE)-1:0] window_pointer_current [num_pixels-1:0];
        // reg window_pointer_out_of_index_current [num_pixels-1:0];
        
        // Comb Register
        // reg [$clog2(WINDOW_SIZE)-1:0] window_pointer_next [num_pixels-1:0];
        // reg window_pointer_out_of_index_next [num_pixels-1:0];
        // reg require_next_window [num_pixels-1:0];
        reg all_pixel_needs_next_window;

        // Window pointer wires to track remaining gaussians per pixel
        wire [$clog2(WINDOW_SIZE)-1:0] window_pointer [num_pixels-1:0];

        

    
    // FF
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            W <= 'd0;
            H <= 'd0;
            block_id <= 'd0;
            last_input_done_FF <= 'd0;

            state_current <= IDLE;

            

            for (int i = 0; i < num_pixels; i++) begin
                pixel_working[i] <= 'b0;
                start[i] <= 'b0;

                pixel_id_to_pixel[i] <= 'd0;

                gaussian_id_to_rasterizer[i] <= 'h0;
                gaussian_color_to_rasterizer[i] <= 'h0;
                gaussian_depth_to_rasterizer[i] <= 'h0;
                mean2D_to_rasterizer[i] <= 'h0;
                conic_opacity_to_rasterizer[i] <= 'h0;

                current_n_contrib[i] <= 'd0;

                T_first[i] <= 'h0;
                dL_dpixel[i] <= 'h0;
                dL_dpixel_depth[i] <= 'h0;
            end

            for (int i =0 ; i< WINDOW_SIZE; i++) begin
                gaussian_id_window[i] <= 'h0;
                gaussian_color_window[i] <= 'h0;
                gaussian_depth_window[i] <= 'h0;
                mean2D_window[i] <= 'h0;
                conic_opacity_window[i] <= 'h0;
            end

            for (int i =0 ; i < gaussian_inputs * num_pixels; i++) begin
                i_valid[i] <= 'b0;
                last_input_to_pixel[i] <= 'b0;
                gaussian_id_to_rasterizer[i] <= 'h0;
                gaussian_color_to_rasterizer[i] <= 'h0;
                gaussian_depth_to_rasterizer[i] <= 'h0;
                mean2D_to_rasterizer[i] <= 'h0;
                conic_opacity_to_rasterizer[i] <= 'h0;
            end

        end
        

        else begin
            state_current <= state_next;

            // 새로운 pixel 데이터 입력
            // if (start_from_block_controller) begin
            if (pixel_values_from_block_control_valid && pixel_values_to_block_control_ready) begin                
                W <= W_in;
                H <= H_in;
                block_id <= block_id_in;    
                last_input_done_FF <= 'd0;

                for (int i = 0; i < num_pixels; i++) begin
                    if (!pixel_working[i]) begin                        
                        start[i] <= 1'b1;
                    end

                    current_n_contrib[i] <= next_n_contrib_from_SRAM[i];

                    T_first[i] <= next_T_first_from_SRAM[i];
                    dL_dpixel[i] <= next_dL_dpixel_from_SRAM[i];
                    dL_dpixel_depth[i] <= next_dL_dpixel_depth_from_SRAM[i];


                    // pixel_id_to_pixel[i] <= (current_row_from_block_controller << $clog2(BLOCK_SIZE)) + i;
                    pixel_id_to_pixel[i] <= {current_row_from_block_controller << $clog2(BLOCK_SIZE) , i[3:0]};
                end
            end

            

            // Gaussian Window 데이터 받아오기
            if (gaussian_window_values_from_block_control_valid && gaussian_window_values_to_block_control_ready) begin
                for (int i = 0; i < WINDOW_SIZE; i++) begin
                    gaussian_id_window[i] <= gaussian_id_from_SRAM[i];
                    gaussian_color_window[i] <= gaussian_color_from_SRAM[i];
                    gaussian_depth_window[i] <= gaussian_depth_from_SRAM[i];
                    mean2D_window[i] <= mean2D_from_SRAM[i];
                    conic_opacity_window[i] <= conic_opacity_from_SRAM[i];
                end   
            end

            


            // Window에서 Rasterizer로 데이터 전송
            for (int i = 0; i < num_pixels; i++) begin

                // if (start[i]) begin
                //     // 한 사이클 뒤 start 내림
                //     start[i] <= 1'b0;
                //     working[i] <= 1'b1;
                // end
                if (start[i]) begin
                    pixel_working[i] <= 1'b1;
                end
                else if (state_current == ROW_DONE) begin
                    pixel_working[i] <= 1'b0;
                end

                // 데이터 Rasterizer한테 입력
                if (!stall_to_controller_from_rasterizer[i] && state_current == WORKING) begin

                    for (int j = 0 ; j < gaussian_inputs; j++) begin

                        // 입력 가능 조건
                        // Gaussian input 때려도 남아돔
                        if (current_n_contrib[i] - j[GID_bit-1:0] >= gaussian_id_window[WINDOW_SIZE-1]) begin

                            i_valid[i * gaussian_inputs + j] <= 1'b1;

                            gaussian_id_to_rasterizer[i * gaussian_inputs + j] <= gaussian_id_window[window_pointer[i] + j[$clog2(WINDOW_SIZE)-1:0]];
                            gaussian_color_to_rasterizer[i * gaussian_inputs + j] <= gaussian_color_window[window_pointer[i] + j[$clog2(WINDOW_SIZE)-1:0]];
                            gaussian_depth_to_rasterizer[i * gaussian_inputs + j] <= gaussian_depth_window[window_pointer[i] + j[$clog2(WINDOW_SIZE)-1:0]];
                            mean2D_to_rasterizer[i * gaussian_inputs + j] <= mean2D_window[window_pointer[i] + j[$clog2(WINDOW_SIZE)-1:0]];
                            conic_opacity_to_rasterizer[i * gaussian_inputs + j] <= conic_opacity_window[window_pointer[i] + j[$clog2(WINDOW_SIZE)-1:0]];

                            // // 한 사이클만 보낼 수 있는가에 대한 확인 필요
                            // last_input_to_pixel 관련 신호 처리 필요
                            // if (current_n_contrib[i] - j[GID_bit-1:0] == gaussian_id_window[WINDOW_SIZE-1] + 1) begin    
                            //     last_input_to_pixel[i * gaussian_inputs + j] <= 1'b1;
                            // end

                            // else begin
                            //     last_input_to_pixel[i * gaussian_inputs + j] <= 1'b0;
                            // end
                        end

                        // 입력 불가능 조건
                        else if (current_n_contrib[i] - j[GID_bit-1:0] < gaussian_id_window[WINDOW_SIZE-1]) begin

                            i_valid[i * gaussian_inputs + j] <= 1'b0;

                            gaussian_id_to_rasterizer[i * gaussian_inputs + j] <= 'h0;
                            gaussian_color_to_rasterizer[i * gaussian_inputs + j] <= 'h0;
                            gaussian_depth_to_rasterizer[i * gaussian_inputs + j] <= 'h0;
                            mean2D_to_rasterizer[i * gaussian_inputs + j] <= 'h0;
                            conic_opacity_to_rasterizer[i * gaussian_inputs + j] <= 'h0;
                            last_input_to_pixel[i * gaussian_inputs + j] <= 1'b0;
                        end
                    end

                    // if (current_n_contrib[i] - gaussian_inputs >= gaussian_id_window[0]) begin
                    if (current_n_contrib[i] >= gaussian_id_window[WINDOW_SIZE-1]) begin
                        if (current_n_contrib[i] >= gaussian_inputs) begin
                            current_n_contrib[i] <= current_n_contrib[i] - gaussian_inputs;
                        end
                        else begin
                            current_n_contrib[i] <= 'd0;
                        end
                    end
                    
                end
            end
        end
    end




    // State Machine
    always_comb begin

        state_next = state_current;

        request_next_row = 0; 
        request_next_window = 0;
        all_pixel_needs_next_window = 0;

        case (state_current)
            IDLE: begin
                request_next_row = 1;
                // request_next_window = 1;
                
                if (pixel_values_from_block_control_valid && pixel_values_to_block_control_ready) begin

                    state_next = GAUSSIAN_MEMORY_FETCHING;

                    // if (gaussian_window_values_from_block_control_valid && gaussian_window_values_to_block_control_ready) begin
                    //     state_next = WORKING;
                    // end
                end

            end

            WORKING: begin
                // New Window 요청하는 조건 
                // 1. pixel 데이터를 먼저 받아서 늦는 경우
                // 2. Window 데이터 모두 사용시

                // New Window 요청
                all_pixel_needs_next_window = 1;
    
                for (int i = 0; i < num_pixels; i++) begin
                    all_pixel_needs_next_window = all_pixel_needs_next_window && (current_n_contrib[i] <= gaussian_id_window[WINDOW_SIZE-1]);
                end

                // 현재는 row_done인 경우
                if (last_input_done_next[$clog2(num_pixels)]) begin
                    // state_next = IDLE;
                    state_next = ROW_DONE;

                end

                // Window 관련
                // 근데 이거 Window를 새로 주는 조건을 조금 생각해야 함
                // 모든 Pixel에서 0에 도달할 시 조건
                else if (all_pixel_needs_next_window) begin
                    state_next = GAUSSIAN_MEMORY_FETCHING;
                end
            end
            
            GAUSSIAN_MEMORY_FETCHING: begin
                request_next_window = 1;
                
                // handshake 발생 시 
                if (gaussian_window_values_from_block_control_valid && gaussian_window_values_to_block_control_ready) begin
                    state_next = WORKING;
                end
            end

            ROW_DONE : begin
                // 추가 예정
                // last_input_done_FF 초기화하는 거 처리
                state_next = IDLE;
            end

            default: begin
                state_next = IDLE;
            end

        endcase 
    end

    
    always_comb begin
        last_input_done_next = last_input_done_FF;
        for (int i = 0; i < num_pixels; i++) begin
            last_input_done_next = last_input_done_next + last_input_done_from_rasterizer[i];
        end
    end


    genvar p;
    generate
        for (p = 0; p < num_pixels; p = p + 1) begin
            assign window_pointer[p] = current_n_contrib[p] != 0 ?  gaussian_id_window[0][$clog2(WINDOW_SIZE)-1:0] - current_n_contrib[p][$clog2(WINDOW_SIZE)-1:0] : 'd0;
        end
    endgenerate


    // Output Control wire
    assign pixel_values_to_block_control_ready = request_next_row;
    assign gaussian_window_values_to_block_control_ready = request_next_window;


endmodule