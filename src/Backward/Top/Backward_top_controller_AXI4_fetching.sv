module Backward_top_controller_AXI4_fetching #(
    parameter precision = 16,
    parameter mantissa_bit = 7,
    parameter exponent_bit = 8,
    parameter num_pixels = 16,
    parameter GID_bit = 12,
    parameter Gaussian_Range_Bit = 24,
    parameter Banks = 16,
    parameter gaussian_inputs = 4,
    parameter GRADIENT_MERGE_TO_TOP_WIDTH = 11 * precision
)

(
    input wire clk,
    input wire rst_n,


    // Connection with Entire system controller (Testbench)
    input wire backward_start,
    output wire backward_ready,

    input wire [11:0] W_in,
    input wire [11:0] H_in,

    output wire backward_done,

    // Connection with Block Controller
    input wire Block_data_ready,
    input wire gradient_value_valid,

    output wire Block_data_done,
    output wire gradient_value_ready,

    output reg [11:0] W_out,
    output reg [11:0] H_out,
    output reg [15:0] block_id_out,

    output reg [GID_bit-1:0] block_gaussian_range_out,


    // Connection with External DRAM Memory (Gaussian and Pixel)
    // As AXI4 BRAM
        output wire s_aresetn,

        // Gaussian Range
        input wire range_rsta_busy,
        input wire range_rstb_busy,

        // aw channel
        output wire [11:0] range_s_axi_awid,
        output wire [13:0] range_s_axi_awaddr,
        output wire [7:0] range_s_axi_awlen,
        output wire [2:0] range_s_axi_awsize,
        output wire [1:0] range_s_axi_awburst,
        output wire range_s_axi_awvalid,
        input wire range_s_axi_awready,

        // w channel
        output wire [47:0] range_s_axi_wdata,
        output wire [31:0] range_s_axi_wstrb,
        output wire range_s_axi_wlast,
        output wire range_s_axi_wvalid,
        input wire range_s_axi_wready,

        // b channel
        input wire [11:0] range_s_axi_bid,
        input wire [1:0] range_s_axi_bresp,
        input wire range_s_axi_bvalid,
        output wire range_s_axi_bready,

        // ar channel
        output wire [3:0] range_s_axi_arid,
        output wire [13:0] range_s_axi_araddr,
        output wire [7:0] range_s_axi_arlen,
        output wire [2:0] range_s_axi_arsize,
        output wire [1:0] range_s_axi_arburst,
        output wire range_s_axi_arvalid,
        input wire range_s_axi_arready,

        // r channel
        input wire [3:0] range_s_axi_rid,
        input wire [47:0] range_s_axi_rdata,
        input wire [1:0] range_s_axi_rresp,
        input wire range_s_axi_rlast,
        input wire range_s_axi_rvalid,
        output wire range_s_axi_rready,


        // Point List BRAM
        input wire point_list_rsta_busy,
        input wire point_list_rstb_busy,

        // aw channel
        output wire [3:0] point_list_s_axi_awid,
        output wire [13:0] point_list_s_axi_awaddr,
        output wire [7:0] point_list_s_axi_awlen,
        output wire [2:0] point_list_s_axi_awsize,
        output wire [1:0] point_list_s_axi_awburst,
        output wire point_list_s_axi_awvalid,
        input wire point_list_s_axi_awready,

        // w channel
        output wire [Gaussian_Range_Bit-1:0] point_list_s_axi_wdata,
        output wire [31:0] point_list_s_axi_wstrb,
        output wire point_list_s_axi_wlast,
        output wire point_list_s_axi_wvalid,
        input wire point_list_s_axi_wready,

        // b channel
        input wire [3:0] point_list_s_axi_bid,
        input wire [1:0] point_list_s_axi_bresp,
        input wire point_list_s_axi_bvalid,
        output wire point_list_s_axi_bready,

        // ar channel
        output wire [3:0] point_list_s_axi_arid,
        output wire [13:0] point_list_s_axi_araddr,
        output wire [7:0] point_list_s_axi_arlen,
        output wire [2:0] point_list_s_axi_arsize,
        output wire [1:0] point_list_s_axi_arburst,
        output wire point_list_s_axi_arvalid,
        input wire point_list_s_axi_arready,

        // r channel
        input wire [3:0] point_list_s_axi_rid,
        input wire [Gaussian_Range_Bit-1:0] point_list_s_axi_rdata,
        input wire [1:0] point_list_s_axi_rresp,
        input wire point_list_s_axi_rlast,
        input wire point_list_s_axi_rvalid,
        output wire point_list_s_axi_rready,
        


        // Gaussian
        input wire gaussian_rsta_busy,
        input wire gaussian_rstb_busy,


        // aw channel
        output wire [11:0] gaussian_s_axi_awid,
        output wire [23:0] gaussian_s_axi_awaddr,
        output wire [7:0] gaussian_s_axi_awlen,
        output wire [2:0] gaussian_s_axi_awsize,
        output wire [1:0] gaussian_s_axi_awburst,
        output wire gaussian_s_axi_awvalid,
        input wire gaussian_s_axi_awready,

        // w channel
        output wire [159:0] gaussian_s_axi_wdata,
        output wire [31:0] gaussian_s_axi_wstrb,
        output wire gaussian_s_axi_wlast,
        output wire gaussian_s_axi_wvalid,
        input wire gaussian_s_axi_wready,

        // b channel
        input wire [11:0] gaussian_s_axi_bid,
        input wire [1:0] gaussian_s_axi_bresp,
        input wire gaussian_s_axi_bvalid,
        output wire gaussian_s_axi_bready,

        // ar channel
        output wire [11:0] gaussian_s_axi_arid,
        output wire [23:0] gaussian_s_axi_araddr,
        output wire [7:0] gaussian_s_axi_arlen,
        output wire [2:0] gaussian_s_axi_arsize,
        output wire [1:0] gaussian_s_axi_arburst,
        output wire gaussian_s_axi_arvalid,
        input wire gaussian_s_axi_arready,

        // r channel 
        input wire [11:0] gaussian_s_axi_rid,
        // input wire [159:0] gaussian_s_axi_rdata,
        input wire [1:0] gaussian_s_axi_rresp,
        input wire gaussian_s_axi_rlast,
        input wire gaussian_s_axi_rvalid,
        output wire gaussian_s_axi_rready,
    

        // Pixel
        input wire pixel_rsta_busy,
        input wire pixel_rstb_busy,

        // aw channel
        output wire [11:0] pixel_s_axi_awid,
        output wire [23:0] pixel_s_axi_awaddr,
        output wire [7:0] pixel_s_axi_awlen,
        output wire [2:0] pixel_s_axi_awsize,
        output wire [1:0] pixel_s_axi_awburst,
        output wire pixel_s_axi_awvalid,
        input wire pixel_s_axi_awready,

        // w channel
        output wire [159:0] pixel_s_axi_wdata,
        output wire [31:0] pixel_s_axi_wstrb,
        output wire pixel_s_axi_wlast,
        output wire pixel_s_axi_wvalid,
        input wire pixel_s_axi_wready,

        // b channel
        input wire [11:0] pixel_s_axi_bid,
        input wire [1:0] pixel_s_axi_bresp,
        input wire pixel_s_axi_bvalid,
        output wire pixel_s_axi_bready,

        // ar channel
        output wire [11:0] pixel_s_axi_arid,
        output wire [21:0] pixel_s_axi_araddr,
        output wire [7:0] pixel_s_axi_arlen,
        output wire [2:0] pixel_s_axi_arsize,
        output wire [1:0] pixel_s_axi_arburst,
        output wire pixel_s_axi_arvalid,
        input wire pixel_s_axi_arready,

        // r channel
        input wire [11:0] pixel_s_axi_rid,
        input wire [91:0] pixel_s_axi_rdata,
        input wire [1:0] pixel_s_axi_rresp,
        input wire pixel_s_axi_rlast,
        input wire pixel_s_axi_rvalid,
        output wire pixel_s_axi_rready,
        

    // As AXI4 BRAM
    // Connection with External DRAM Memory (Gradient)
        // Gradient

        // aw channel
        output wire [11:0] gradient_s_axi_awid,
        output wire [23:0] gradient_s_axi_awaddr,
        output wire [7:0] gradient_s_axi_awlen,
        output wire [2:0] gradient_s_axi_awsize,
        output wire [1:0] gradient_s_axi_awburst,
        output wire gradient_s_axi_awvalid,
        input wire gradient_s_axi_awready,

        // w channel
        output wire [175:0] gradient_s_axi_wdata,
        output wire [21:0] gradient_s_axi_wstrb,
        output wire gradient_s_axi_wlast,
        output wire gradient_s_axi_wvalid,
        input wire gradient_s_axi_wready,

        // b channel
        input wire [11:0] gradient_s_axi_bid,
        input wire [1:0] gradient_s_axi_bresp,
        input wire gradient_s_axi_bvalid,
        output wire gradient_s_axi_bready,

        // ar channel
        output wire [11:0] gradient_s_axi_arid,
        output wire [23:0] gradient_s_axi_araddr,
        output wire [7:0] gradient_s_axi_arlen,
        output wire [2:0] gradient_s_axi_arsize,
        output wire [1:0] gradient_s_axi_arburst,
        output wire gradient_s_axi_arvalid,
        input wire gradient_s_axi_arready,

        // r channel
        input wire [11:0] gradient_s_axi_rid,
        input wire [175:0] gradient_s_axi_rdata,
        input wire [1:0] gradient_s_axi_rresp,
        input wire gradient_s_axi_rlast,
        input wire gradient_s_axi_rvalid,
        output wire gradient_s_axi_rready,

    // Connection with Cache SRAM

    // Gaussian

    output wire [GID_bit-1:0] write_address_to_gaussian_SRAM [gaussian_inputs-1:0],
    output wire Gaussian_SRAM_WEB [gaussian_inputs-1:0],

    // Pixel
    output wire [$clog2(num_pixels)-1:0] write_address_to_pixel_SRAM [num_pixels-1:0],
    output wire Pixel_SRAM_WEB [num_pixels-1:0],

    // Gradient
    // FIFO로 가져오는 ID
    input wire push_to_Top_FIFO,
    input wire [GRADIENT_MERGE_TO_TOP_WIDTH-1:0] gradient_merge_to_Top_FIFO,

    // SRAM에서 gradient 읽기 위한 신호
    output wire Gradient_SRAM_REB_from_Top_control [Banks-1:0],
    output wire [GID_bit-1:0] gradient_id_to_SRAM_from_Top_control [Banks-1:0],

    // SRAM을 0으로 변환하기 위한 신호
    output wire Gradient_SRAM_WEB_from_Top_control [Banks-1:0],

    // Point List

    // Write
    output wire [GID_bit-1:0] gaussian_ID_address_to_point_list_SRAM,
    output wire [Gaussian_Range_Bit-1:0] gaussian_ID_to_point_list_SRAM,
    output wire Point_list_WEB,

    // Read
    output wire [GID_bit-1:0] gaussian_ID_read_address_point_list_SRAM,
    // 24bit Addr >> AXI4 araddr로 사용
    input wire [Gaussian_Range_Bit-1:0] gaussian_ID_from_point_list_SRAM,
    output wire Point_list_REB
);

// localparam N_PIXELS = 307200;

// FF register
// reg [15:0] block_index_for_control;
// reg [12:0] block_index_for_control;
reg [13:0] block_index_for_control;

reg [15:0] max_block_index;

// Pixel fetching index
reg [21:0] pixel_fetching_index;


reg [$clog2(num_pixels):0] pixel_fetching_row;
reg [$clog2(num_pixels):0] pixel_SRAM_row;

reg [$clog2(num_pixels):0] pixel_fetching_line;


reg [2 * $clog2(num_pixels):0] pixel_fetching_count;
reg [2 * $clog2(num_pixels):0] pixel_handshake_count;

reg [GID_bit-1:0] gaussian_fetching_index;
reg [GID_bit-1:0] gaussian_SRAM_address;

reg [GID_bit-1:0] Top_gaussian_fetching_index;
reg [GID_bit-1:0] Top_gaussian_fetching_index_next;

reg [GID_bit-1:0] gradient_fetching_index;

reg [Gaussian_Range_Bit-1:0] gaussian_range_starting_index;

reg [7:0] target_block_x;
reg [7:0] target_block_y;

reg [7:0] target_block_x_next;
reg [7:0] target_block_y_next;

reg [GID_bit-1:0] gradient_writing_index;


reg [GRADIENT_MERGE_TO_TOP_WIDTH - 1:0] gradient_adder_grads_result_FF;

// Comb register
reg gradient_value_ready_reg;
reg gradient_fetching_done_reg;
reg block_fetching_allowed_reg;
reg Block_data_done_reg;

// reg [15:0] block_index_for_control_next;
reg [13:0] block_index_for_control_next;

reg [21:0] pixel_fetching_index_next;
reg [$clog2(num_pixels):0] pixel_fetching_row_next;
reg [$clog2(num_pixels):0] pixel_fetching_line_next;



// wire
wire backward_handshake;
wire gradient_handshake;

wire point_list_ar_handshake;
wire pixel_ar_handshake;

wire gradient_fetching_done;

wire point_list_fetching_done;
wire range_fetching_done;

wire [GRADIENT_MERGE_TO_TOP_WIDTH - 1:0] gradient_adder_grads_result;


wire Top_fifo_push;
wire [GRADIENT_MERGE_TO_TOP_WIDTH + Gaussian_Range_Bit-1:0] Top_fifo_push_data;

wire Top_fifo_pop;
wire [GRADIENT_MERGE_TO_TOP_WIDTH + Gaussian_Range_Bit-1:0] Top_fifo_pop_data;

wire Top_fifo_full;
wire Top_fifo_empty;



// State
reg [2:0] Gradient_state_current;
reg [2:0] Gradient_state_next;

localparam  GRADIENT_IDLE = 3'd0,
            TILE_BASIC_FETCHING = 3'd1,
            TILE_POINT_LIST_FETCHING = 3'd2,
            GRADIENT_BUSY = 3'd3,
            GRADIENT_FETCHING = 3'd4;

reg [1:0] Top_block_value_state_current;
reg [1:0] Top_block_value_state_next;

localparam  TOP_BLOCK_IDLE = 2'd0,
            TOP_BLOCK_FETCHING = 2'd1,
            TOP_BLOCK_DONE = 2'd2;



assign gradient_value_ready = gradient_value_ready_reg;
assign gradient_fetching_done = gradient_fetching_done_reg;
assign backward_ready = (Top_block_value_state_current == TOP_BLOCK_IDLE) && (Top_block_value_state_current == TOP_BLOCK_IDLE);
assign backward_handshake = backward_start && backward_ready;
assign gradient_handshake = gradient_value_valid && gradient_value_ready;
assign backward_done = (block_index_for_control == max_block_index) && gradient_fetching_done;

assign point_list_ar_handshake = point_list_s_axi_arvalid && point_list_s_axi_arready;
assign pixel_ar_handshake = pixel_s_axi_arvalid && pixel_s_axi_arready;
assign range_fetching_done = range_s_axi_rvalid && range_s_axi_rready;

// assign point_list_fetching_done = (point_list_s_axi_rvalid && point_list_s_axi_rready) && (Top_gaussian_fetching_index >= block_gaussian_range_out);
assign point_list_fetching_done = (point_list_s_axi_rvalid && point_list_s_axi_rready) && (Top_gaussian_fetching_index > block_gaussian_range_out);

assign gaussian_ID_address_to_point_list_SRAM = !Point_list_WEB ? Top_gaussian_fetching_index : 'd0;
assign gaussian_ID_to_point_list_SRAM = !Point_list_WEB ? point_list_s_axi_rdata : 'd0;
assign Point_list_WEB = (Gradient_state_current == TILE_POINT_LIST_FETCHING) && (Top_gaussian_fetching_index <= block_gaussian_range_out) && (point_list_s_axi_arvalid && point_list_s_axi_arready) ? 1'b0 : 1'b1;

assign Block_data_done = Block_data_done_reg;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////// State Transition ////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Gradient (Total)
always_comb begin
    Gradient_state_next = Gradient_state_current;
    gradient_value_ready_reg = 1'b0;
    block_fetching_allowed_reg = 1'b0;


    // target_block_x_next = target_block_x;
    // target_block_y_next = target_block_y;
    block_index_for_control_next = block_index_for_control;

    case (Gradient_state_current)

        // 'd0, IDLE
        GRADIENT_IDLE: begin
            if (backward_start) begin
                Gradient_state_next = TILE_BASIC_FETCHING;
            end
        end

        // 'd1, BASIC RANGE FETCHIING
        TILE_BASIC_FETCHING: begin
            // condition to read range 
            // State 탈출시에 신호가 있어야 Top state도 탈출할듯?
            // 전체 블록 완료
            if (block_index_for_control == max_block_index) begin
                Gradient_state_next = GRADIENT_IDLE;
            end

            // Range를 가져오면 다음 state 전환
            // Range + Point list 다 가져와야함
            // Range 가져오는거 구현해야 함

            else if (range_fetching_done) begin
                Gradient_state_next = TILE_POINT_LIST_FETCHING;
            end
        end

        // 'd2, Point List Fetching
        TILE_POINT_LIST_FETCHING: begin


            if (point_list_fetching_done) begin
                block_fetching_allowed_reg = 1'b1;
                Gradient_state_next = GRADIENT_BUSY;
            end

        end

        // 'd3, GRADIENT BUSY
        GRADIENT_BUSY: begin
            gradient_value_ready_reg = 1'b1;

            // 한 블록 완료시 완료 후 Gradient 모으는 state 전환하여 gradient 모집
            if (gradient_handshake) begin
                Gradient_state_next = GRADIENT_FETCHING;
            end
        end

        // 'd4, GRADIENT FETCHING
        GRADIENT_FETCHING: begin
            if (gradient_fetching_done) begin
                block_index_for_control_next = block_index_for_control + 'd1;
                
                Gradient_state_next = TILE_BASIC_FETCHING;
            end
        end

        default: begin
            Gradient_state_next = GRADIENT_IDLE;
        end
        
    endcase
end

// Top to Block Memory

always_comb begin
    Top_block_value_state_next = Top_block_value_state_current;
    Block_data_done_reg = 1'b0;
    


    case (Top_block_value_state_current)

        // 'd0
        TOP_BLOCK_IDLE: begin
            // if (block_fetching_allowed_reg) begin
            if (range_fetching_done) begin
                Top_block_value_state_next = TOP_BLOCK_FETCHING;
            end
        end

        // 'd1
        TOP_BLOCK_FETCHING: begin

            // Max에 해당하는 데이터 전부 전송시 반환
            // Pixel 데이터 획득 && Gaussian 데이터 획득시 반환
        
            if ((pixel_fetching_count[2 * $clog2(num_pixels)]) && (gaussian_fetching_index >= block_gaussian_range_out)) begin                
                Block_data_done_reg = 1'b1;
                Top_block_value_state_next = TOP_BLOCK_DONE;
                // block_index_for_control_next = block_index_for_control_next + 1;                
            end

        end

        // 'd2
        TOP_BLOCK_DONE: begin

            if ((block_index_for_control == max_block_index) && gradient_fetching_done) begin                
                Top_block_value_state_next = TOP_BLOCK_IDLE;
            end

            else if (gradient_fetching_done) begin                
                Top_block_value_state_next = TOP_BLOCK_FETCHING;
            end
        end

        default: begin
            Top_block_value_state_next = TOP_BLOCK_IDLE;
        end

    endcase
end


always_comb begin

    pixel_fetching_index_next = pixel_fetching_index;
    pixel_fetching_line_next = pixel_fetching_line;
    pixel_fetching_row_next = pixel_fetching_row;


    // Pixel Fetching 관련 컨트롤

    // 'd256 이하
    // if (!pixel_fetching_count[2 * $clog2(num_pixels)]) begin

    //     // 처음 block 진입
    //     // if (pixel_fetching_count == 'd0) begin
    //     //     pixel_fetching_index_next = (pixel_fetching_row * W_out) + (target_block_x_next * num_pixels) + (target_block_y_next * num_pixels * W_out);
    //     // end

    //     // else begin
    //         pixel_fetching_line_next = pixel_fetching_line_next + 1;
    //         pixel_fetching_index_next = pixel_fetching_index_next + 1;

    //         // pixel 다 참
    //         // row + 1 , line = 0
    //         if (pixel_fetching_line_next[$clog2(num_pixels)]) begin

    //             pixel_fetching_line_next = 'd0;
    //             pixel_fetching_row_next = pixel_fetching_row + 1;
    //             pixel_fetching_index_next = (pixel_fetching_row_next * W_out) + (target_block_x * num_pixels) + (target_block_y * num_pixels * W_out);

    //             // row 도 다 참 (마지막)
    //             // row = 0, line = 0, 
    //             if (pixel_fetching_row_next[$clog2(num_pixels)]) begin
    //                 pixel_fetching_row_next = 'd0;
    //                 pixel_fetching_index_next = (pixel_fetching_row_next * W_out) + (target_block_x_next * num_pixels) + (target_block_y_next * num_pixels * W_out);
    //             end
    //         end        
    //     // end
    // end    




    // 인접 픽셀 로직
    if (!pixel_fetching_count[2 * $clog2(num_pixels)]) begin

        pixel_fetching_line_next = pixel_fetching_line + 1;
        pixel_fetching_index_next = (target_block_x * num_pixels) + (target_block_y * num_pixels * W_in)
                                    + ( (pixel_fetching_row_next % $clog2(num_pixels)) * $clog2(num_pixels) ) + ( (pixel_fetching_row_next / $clog2(num_pixels)) * $clog2(num_pixels) * W_out)
                                    + ( (pixel_fetching_line_next % $clog2(num_pixels)) ) + ( (pixel_fetching_line_next / $clog2(num_pixels)) * W_out);
        


        // pixel 다 참
        // row + 1 , line = 0
        if (pixel_fetching_line_next[$clog2(num_pixels)]) begin

            pixel_fetching_line_next = 'd0;
            pixel_fetching_row_next = pixel_fetching_row + 1;

            // pixel_fetching_index_next = (pixel_fetching_row_next * W_out) + (target_block_x * num_pixels) + (target_block_y * num_pixels * W_out);

            // 수식 : (target block x * 16 + target block y * 16 * W) + (row % 4 * 4) + (row // 4 ) * 4 * 640 + (line % 4) + (line // 4) * 640
            pixel_fetching_index_next = (target_block_x * num_pixels) + (target_block_y * num_pixels * W_out)
                                        + ( (pixel_fetching_row_next % $clog2(num_pixels)) * $clog2(num_pixels) ) + ( (pixel_fetching_row_next / $clog2(num_pixels)) * $clog2(num_pixels) * W_out)
                                        + ( (pixel_fetching_line_next % $clog2(num_pixels)) ) + ( (pixel_fetching_line_next / $clog2(num_pixels)) * W_out);
            

            // row 도 다 참 (마지막)
            // row = 0, line = 0, 
            if (pixel_fetching_row_next[$clog2(num_pixels)]) begin
                pixel_fetching_row_next = 'd0;
                pixel_fetching_index_next = (target_block_x_next * num_pixels) + (target_block_y_next * num_pixels * W_out)
                                        + ( (pixel_fetching_row_next % $clog2(num_pixels)) * $clog2(num_pixels) ) + ( (pixel_fetching_row_next / $clog2(num_pixels)) * $clog2(num_pixels) * W_out)
                                        + ( (pixel_fetching_line_next % $clog2(num_pixels)) ) + ( (pixel_fetching_line_next / $clog2(num_pixels)) * W_out);

            end
        end        

    end

end



// FF Transition

// Gradient State
always_ff @ (posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        Gradient_state_current <= GRADIENT_IDLE;
        W_out <= 'd0;
        H_out <= 'd0;
        block_id_out <= 'd0;
        block_gaussian_range_out <= 'd0;
        block_index_for_control <= 'd0;

        gaussian_range_starting_index <= 'd0;

        Top_gaussian_fetching_index <= 'd0;
        Top_gaussian_fetching_index_next <= 'd0;

        max_block_index <= 'd0;

        target_block_x <= 'd0;
        target_block_y <= 'd0;

        target_block_x_next <= 'd1;
        target_block_y_next <= 'd0;
    end

    else begin
        Gradient_state_current <= Gradient_state_next;
        block_index_for_control <= block_index_for_control_next;
        // target_block_x <= target_block_x_next;
        // target_block_y <= target_block_y_next;

        if (backward_handshake) begin
            W_out <= W_in;
            H_out <= H_in;
            max_block_index <= (W_in >> $clog2(num_pixels)) * (H_in >> $clog2(num_pixels));
        end

        // first block pixel fetching
        Top_gaussian_fetching_index_next <= Top_gaussian_fetching_index;
        

        if (range_fetching_done) begin
            gaussian_range_starting_index <= range_s_axi_rdata[2 * Gaussian_Range_Bit-1:Gaussian_Range_Bit];
            block_gaussian_range_out <= (range_s_axi_rdata[Gaussian_Range_Bit-1:0] - range_s_axi_rdata[2 * Gaussian_Range_Bit-1 : Gaussian_Range_Bit]);
        end

        if (Gradient_state_current == TILE_POINT_LIST_FETCHING) begin
            // if (Top_gaussian_fetching_index < block_gaussian_range_out && point_list_ar_handshake) begin
            if (Top_gaussian_fetching_index <= block_gaussian_range_out && point_list_ar_handshake) begin
                Top_gaussian_fetching_index <= Top_gaussian_fetching_index + 'd1;
            end
        end

        if (Top_block_value_state_current == TOP_BLOCK_DONE) begin
            // Top_gaussian_fetching_index <= block_gaussian_range_out + 'd1;
            Top_gaussian_fetching_index <= 'd0;
            Top_gaussian_fetching_index_next <= 'd0;
        end
    end

    if (Gradient_state_current == GRADIENT_FETCHING && Gradient_state_next == TILE_BASIC_FETCHING) begin
        target_block_x <= target_block_x_next;
        target_block_y <= target_block_y_next;

        if (target_block_x_next == (W_out >> $clog2(num_pixels)) - 1) begin
            target_block_x_next <= 'd0;
            target_block_y_next <= target_block_y_next + 'd1;
            block_id_out <= {target_block_x_next, target_block_y_next};
        end

        else begin
            target_block_x_next <= target_block_x_next + 'd1;
            block_id_out <= {target_block_x_next, target_block_y_next};
        end
        
        
    end


// localparam  GRADIENT_IDLE = 3'd0,
//             TILE_BASIC_FETCHING = 3'd1,
//             TILE_POINT_LIST_FETCHING = 3'd2,
//             GRADIENT_BUSY = 3'd3,
//             GRADIENT_FETCHING = 3'd4;

end

// Top to Block State

always_ff @ (posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        Top_block_value_state_current <= TOP_BLOCK_IDLE;

        
        pixel_fetching_index <= 'd0;
        pixel_fetching_row <= 'd0;
        pixel_SRAM_row <= 'd0;

        pixel_fetching_line <= 'd0;
        pixel_fetching_count <= 'd0;

        gaussian_fetching_index <= 'd0;
        gaussian_SRAM_address <= 'd0;

        pixel_handshake_count <= 'd0;


    end

    else begin
        Top_block_value_state_current <= Top_block_value_state_next;

        if (Top_block_value_state_current == TOP_BLOCK_FETCHING) begin

            // Gaussian Fetching
            if (gaussian_fetching_index < block_gaussian_range_out && (gaussian_s_axi_rvalid && gaussian_s_axi_rready)) begin
                gaussian_fetching_index <= gaussian_fetching_index + 'd1;
                gaussian_SRAM_address <= gaussian_fetching_index;
            end

            if (Top_block_value_state_next == TOP_BLOCK_DONE) begin
                gaussian_fetching_index <= 'd0;
                gaussian_SRAM_address <= 'd0;
            end


            // if (pixel_fetching_count < 'd256 && pixel_ar_handshake && Top_block_value_state_current == TOP_BLOCK_FETCHING) begin
            if (pixel_fetching_count < 'd256 && pixel_ar_handshake && Top_block_value_state_current == TOP_BLOCK_FETCHING) begin
                // Pixel Fetching
                pixel_fetching_index <= pixel_fetching_index_next;
                pixel_fetching_line <= pixel_fetching_line_next;
                pixel_fetching_row <= pixel_fetching_row_next;

                pixel_SRAM_row <= pixel_fetching_row;

                pixel_fetching_count <= pixel_fetching_count + 1;
            end


            if (pixel_s_axi_rvalid && pixel_s_axi_rready) begin
                pixel_handshake_count <= pixel_handshake_count + 1;
            end

            if (Top_block_value_state_next == TOP_BLOCK_DONE) begin
                pixel_fetching_count <= 'd0;
                pixel_handshake_count <= 'd0;
                // pixel_fetching_index <= 'd0;
                pixel_fetching_line <= 'd0;
                pixel_fetching_row <= 'd0;                
            end

        end   

        // if  (Gradient_state_current == GRADIENT_FETCHING && Gradient_state_next == TILE_BASIC_FETCHING) begin
        //     pixel_fetching_index <= pixel_fetching_index_next;
        // end

    end
end


genvar g, p, b;
generate 

    for (g = 0; g < gaussian_inputs; g++) begin : gaussian_to_SRAM_inst
        // assign Gaussian_SRAM_WEB[g] = (Top_block_value_state_current == TOP_BLOCK_FETCHING) && (gaussian_fetching_index < block_gaussian_range_out ) && ((gaussian_fetching_index + 1) % gaussian_inputs == g) ? 1'b0 : 1'b1;

        assign Gaussian_SRAM_WEB[g] = (Top_block_value_state_current == TOP_BLOCK_FETCHING) && (gaussian_fetching_index < block_gaussian_range_out ) && (gaussian_s_axi_rvalid && gaussian_s_axi_rready) && ((gaussian_fetching_index + 1) % gaussian_inputs == g) ? 1'b0 : 1'b1;
        // assign write_address_to_gaussian_SRAM[g] = ((Top_block_value_state_current == TOP_BLOCK_FETCHING) && (gaussian_fetching_index < block_gaussian_range_out )) && (gaussian_s_axi_rvalid && gaussian_s_axi_rready) && ((gaussian_fetching_index + 1) % gaussian_inputs == g) ? (gaussian_fetching_index + 1) >> $clog2(gaussian_inputs): 'h0;
        assign write_address_to_gaussian_SRAM[g] = ((Top_block_value_state_current == TOP_BLOCK_FETCHING) && (gaussian_fetching_index < block_gaussian_range_out )) && (gaussian_s_axi_rvalid && gaussian_s_axi_rready) && ((gaussian_fetching_index + 1) % gaussian_inputs == g) ? (gaussian_fetching_index + 1) / gaussian_inputs: 'h0;

        // assign write_address_to_gaussian_SRAM[g] = ((Top_block_value_state_current == TOP_BLOCK_FETCHING) && (gaussian_fetching_index < block_gaussian_range_out )) && (gaussian_s_axi_rvalid && gaussian_s_axi_rready) && ((gaussian_fetching_index + 1) % gaussian_inputs == g) ? gaussian_SRAM_address : 'h0;


        // Block 0일때 초기화 변수
        // assign Gradient_SRAM_WEB_from_Top_control[g] = (Gradient_state_current == TILE_POINT_LIST_FETCHING) && ((gaussian_fetching_index[$clog2(Banks)-1:0] + 'd1) % num_pixels == g) ? 1'b0 : 1'b1;
    end

    for (p = 0; p < num_pixels; p++) begin : pixel_to_SRAM_inst
        assign Pixel_SRAM_WEB[p] = (Top_block_value_state_current == TOP_BLOCK_FETCHING) && (pixel_handshake_count < 'd256) && (pixel_handshake_count % num_pixels == p) && (pixel_s_axi_rvalid && pixel_s_axi_rready)  ? 1'b0 : 1'b1;
        
        

        // assign write_address_to_pixel_SRAM[p] = ((Top_block_value_state_current == TOP_BLOCK_FETCHING) && (pixel_handshake_count < 'd256 )) && (pixel_handshake_count % num_pixels == p) ? pixel_fetching_row : 'h0;
        assign write_address_to_pixel_SRAM[p] = ((Top_block_value_state_current == TOP_BLOCK_FETCHING) && (pixel_handshake_count < 'd256 )) && (pixel_handshake_count % num_pixels == p) ? pixel_SRAM_row : 'h0;
    end

    for (b = 0; b < Banks; b++) begin : gradient_Cache_writing_inst
        assign Gradient_SRAM_WEB_from_Top_control[b] = (Gradient_state_current == TILE_POINT_LIST_FETCHING) && ((gaussian_fetching_index[$clog2(Banks)-1:0] + 'd1) % num_pixels == b) && (block_index_for_control == 'd0) ? 1'b0 : 1'b1;
    end

endgenerate


// Point list REB 조건 : 모든 Writing이 끝나는 경우

// AW -> W -> B 인데,
// W handshake 시 B가 완료
// 다음거 읽는 동안에는 이거 실행하면 안됨.
// assign Point_list_REB = (Gradient_state_current == GRADIENT_FETCHING) && push_to_Top_FIFO && (gradient_fetching_index <= block_gaussian_range_out) ? 1'b0 : 1'b1;
// assign gaussian_ID_read_address_point_list_SRAM = !Point_list_REB ? gradient_fetching_index : 'd0;





/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////// Range Unit AXI4 BRAM ////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////



    reg range_fetching_state;
    reg range_fetching_state_next;

    localparam RANGE_FETCHING_IDLE = 1'd0,
               RANGE_FETCHING_R = 1'd1;

    assign s_aresetn = 1'b1;
    
    // aw channel
    assign range_s_axi_awid = 'b0;
    assign range_s_axi_awaddr = 'b0;
    assign range_s_axi_awlen = 'b0;
    assign range_s_axi_awsize = 'b0;
    assign range_s_axi_awburst = 'b0;
    assign range_s_axi_awvalid = 1'b0;
    
    // w channel
    assign range_s_axi_wdata = 'b0;
    assign range_s_axi_wstrb = 'b0;
    assign range_s_axi_wlast = 1'b0;
    assign range_s_axi_wvalid = 1'b0;

    // b channel
    assign range_s_axi_bready = 1'b0;
    
    // ar channel
    assign range_s_axi_arid = block_index_for_control % 16; 
    assign range_s_axi_araddr = block_index_for_control;
    assign range_s_axi_arlen = 'd0;
    assign range_s_axi_arsize = 'd3;
    assign range_s_axi_arburst = 'd0;

    assign range_s_axi_arvalid = (Gradient_state_current == TILE_BASIC_FETCHING) && (range_fetching_state == RANGE_FETCHING_IDLE);
    
    // r channel
    assign range_s_axi_rready = (Gradient_state_current == TILE_BASIC_FETCHING) && (range_fetching_state == RANGE_FETCHING_R);
    



    always_comb begin
        range_fetching_state_next = range_fetching_state;

        case (range_fetching_state)
            RANGE_FETCHING_IDLE: begin
                if (range_s_axi_arready && range_s_axi_arvalid) begin
                    range_fetching_state_next = RANGE_FETCHING_R;
                end
            end
            RANGE_FETCHING_R: begin
                if (range_s_axi_rvalid && range_s_axi_rready) begin
                    range_fetching_state_next = RANGE_FETCHING_IDLE;
                end
            end
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin
            range_fetching_state <= RANGE_FETCHING_IDLE;
        end

        else begin
            range_fetching_state <= range_fetching_state_next;
        end
    end
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////// Point list AXI4 BRAM ////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    // aw channel
    assign point_list_s_axi_awid = 'b0;
    assign point_list_s_axi_awaddr = 'b0;
    assign point_list_s_axi_awlen = 'b0;
    assign point_list_s_axi_awsize = 'b0;
    assign point_list_s_axi_awburst = 'b0;
    assign point_list_s_axi_awvalid = 1'b0;
    
    // w channel
    assign point_list_s_axi_wdata = 'b0;
    assign point_list_s_axi_wstrb = 'b0;
    assign point_list_s_axi_wlast = 1'b0;
    assign point_list_s_axi_wvalid = 1'b0;

    // b channel
    assign point_list_s_axi_bready = 1'b0;

    // ar channel
    assign point_list_s_axi_arid = Top_gaussian_fetching_index % 16; 
    assign point_list_s_axi_araddr = Top_gaussian_fetching_index + gaussian_range_starting_index;
    assign point_list_s_axi_arlen = 'd0;
    assign point_list_s_axi_arsize = 'd2;
    assign point_list_s_axi_arburst = 'd0;
    // assign point_list_s_axi_arvalid = (Gradient_state_current == TILE_POINT_LIST_FETCHING)
    assign point_list_s_axi_arvalid = (Gradient_state_current == TILE_POINT_LIST_FETCHING) && !point_list_fetching_done;
    
    
    // r channel
    assign point_list_s_axi_rready = (Gradient_state_current == TILE_POINT_LIST_FETCHING);


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////// Gaussian AXI4 BRAM ////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    // aw channel
    assign gaussian_s_axi_awid = 'b0;
    assign gaussian_s_axi_awaddr = 'b0;
    assign gaussian_s_axi_awlen = 'b0;
    assign gaussian_s_axi_awsize = 'b0;
    assign gaussian_s_axi_awburst = 'b0;
    assign gaussian_s_axi_awvalid = 1'b0;

    // w channel
    assign gaussian_s_axi_wdata = 'b0;
    assign gaussian_s_axi_wstrb = 'b0;
    assign gaussian_s_axi_wlast = 1'b0;
    assign gaussian_s_axi_wvalid = 1'b0;
    
    // b channel
    assign gaussian_s_axi_bready = 1'b0;
    
    // ar channel
    // assign gaussian_s_axi_arid = point_list_s_axi_arvalid ? point_list_s_axi_rid : 'b0;
    // assign gaussian_s_axi_araddr = point_list_s_axi_arvalid ? point_list_s_axi_rdata : 'b0;

    assign gaussian_s_axi_arid = (point_list_s_axi_rvalid && point_list_s_axi_rready) ? point_list_s_axi_rid : 'b0;
    assign gaussian_s_axi_araddr = (point_list_s_axi_rvalid && point_list_s_axi_rready) ? point_list_s_axi_rdata : 'b0;

    assign gaussian_s_axi_arlen = 'd0;
    assign gaussian_s_axi_arsize = 'd5;
    assign gaussian_s_axi_arburst = 'd0;
    assign gaussian_s_axi_arvalid = (Top_block_value_state_current == TOP_BLOCK_FETCHING) && (Top_gaussian_fetching_index <= block_gaussian_range_out) && (point_list_s_axi_rvalid && point_list_s_axi_rready);

    // r channel
    assign gaussian_s_axi_rready = (Top_block_value_state_current == TOP_BLOCK_FETCHING) && (Top_gaussian_fetching_index_next <= block_gaussian_range_out);



/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////// Pixel AXI4 BRAM ////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    // aw channel
    assign pixel_s_axi_awid = 'b0;
    assign pixel_s_axi_awaddr = 'b0;
    assign pixel_s_axi_awlen = 'b0;
    assign pixel_s_axi_awsize = 'b0;
    assign pixel_s_axi_awburst = 'b0;
    assign pixel_s_axi_awvalid = 1'b0;

    assign pixel_s_axi_wdata = 'b0;
    assign pixel_s_axi_wstrb = 'b0;
    assign pixel_s_axi_wlast = 1'b0;
    assign pixel_s_axi_wvalid = 1'b0;

    assign pixel_s_axi_bready = 1'b0;

    assign pixel_s_axi_arid = pixel_fetching_count;
    assign pixel_s_axi_araddr = pixel_fetching_index;
    assign pixel_s_axi_arlen = 'd0;
    assign pixel_s_axi_arsize = 'd4;
    assign pixel_s_axi_arburst = 'd0;
    assign pixel_s_axi_arvalid = (Top_block_value_state_current == TOP_BLOCK_FETCHING) && (pixel_fetching_count < 'd256);
    

    assign pixel_s_axi_rready = (Top_block_value_state_current == TOP_BLOCK_FETCHING) && (pixel_fetching_count <= 'd256) ;
    

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////// Gradient AXI4 BRAM ////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


reg [Gaussian_Range_Bit-1:0] reading_gradient_gaussian_official_ID;
reg [GRADIENT_MERGE_TO_TOP_WIDTH-1:0] gradient_data_from_cache;
reg [GRADIENT_MERGE_TO_TOP_WIDTH-1:0] gradient_data_from_external_memory;
reg [GRADIENT_MERGE_TO_TOP_WIDTH-1:0] gradient_data_from_adder;


reg [1:0] gradient_fetching_state_current;
reg [1:0] gradient_fetching_state_next;

localparam GRADIENT_FETCHING_IDLE = 2'd0,
           GRADIENT_FETCHING_AR = 2'd1,
           GRADIENT_FETCHING_R = 2'd2,
           GRADIENT_FETCHING_ADD = 2'd3;

reg [1:0] gradient_writing_state_current;
reg [1:0] gradient_writing_state_next;

localparam GRADIENT_WRITING_IDLE = 2'd0,
           GRADIENT_WRITING_W = 2'd1,
           GRADIENT_WRITING_B = 2'd2;






    // aw channel
    assign gradient_s_axi_awid = (Gradient_state_current == GRADIENT_FETCHING) && (gradient_writing_state_current == GRADIENT_WRITING_IDLE) && !Top_fifo_empty? gradient_writing_index : 'd0;
    assign gradient_s_axi_awaddr = (Gradient_state_current == GRADIENT_FETCHING) && (gradient_writing_state_current == GRADIENT_WRITING_IDLE) && !Top_fifo_empty ? Top_fifo_pop_data[GRADIENT_MERGE_TO_TOP_WIDTH + Gaussian_Range_Bit - 1:GRADIENT_MERGE_TO_TOP_WIDTH] : 'd0;
    assign gradient_s_axi_awlen = 'd0;
    assign gradient_s_axi_awsize = 'd5;
    assign gradient_s_axi_awburst = 'b0;
    assign gradient_s_axi_awvalid = (Gradient_state_current == GRADIENT_FETCHING) && (gradient_writing_state_current == GRADIENT_WRITING_IDLE) && !Top_fifo_empty;


    assign gradient_s_axi_wdata = (Gradient_state_current == GRADIENT_FETCHING) && (gradient_writing_state_current == GRADIENT_WRITING_W) && !Top_fifo_empty ? gradient_adder_grads_result_FF : 'd0;
    assign gradient_s_axi_wstrb = (Gradient_state_current == GRADIENT_FETCHING) && (gradient_writing_state_current == GRADIENT_WRITING_W) && !Top_fifo_empty ? 22'h3FFFFF : 'd0;
    assign gradient_s_axi_wlast = (Gradient_state_current == GRADIENT_FETCHING) && (gradient_writing_state_current == GRADIENT_WRITING_W) && !Top_fifo_empty ? 1'b1 : 1'b0;
    assign gradient_s_axi_wvalid = (Gradient_state_current == GRADIENT_FETCHING) && (gradient_writing_state_current == GRADIENT_WRITING_W) && !Top_fifo_empty;

    assign gradient_s_axi_bready = (Gradient_state_current == GRADIENT_FETCHING) && (gradient_writing_state_current == GRADIENT_WRITING_B);

    assign gradient_s_axi_arid = (Gradient_state_current == GRADIENT_FETCHING) && (gradient_fetching_state_current == GRADIENT_FETCHING_AR) ? (gradient_fetching_index)  : 'd0;
    assign gradient_s_axi_araddr = (Gradient_state_current == GRADIENT_FETCHING) && (gradient_fetching_state_current == GRADIENT_FETCHING_AR) && (gradient_fetching_index <= block_gaussian_range_out + 1)? gaussian_ID_from_point_list_SRAM : 'd0;
    assign gradient_s_axi_arlen = 'd0;
    assign gradient_s_axi_arsize = 'd5;
    assign gradient_s_axi_arburst = 'd0;

    // fetching 상태 + 전 단계에서 gid 받은 경우 + 종료 조건 전까지
    assign gradient_s_axi_arvalid = (Gradient_state_current == GRADIENT_FETCHING) && (gradient_fetching_state_current == GRADIENT_FETCHING_AR) && (gradient_fetching_index <= block_gaussian_range_out + 1);
    
    assign gradient_s_axi_rready = (Gradient_state_current == GRADIENT_FETCHING) && (gradient_fetching_state_current == GRADIENT_FETCHING_R) ;



assign Point_list_REB = (Gradient_state_current == GRADIENT_FETCHING) && (gradient_fetching_index < block_gaussian_range_out) ? 1'b0 : 1'b1;
assign gaussian_ID_read_address_point_list_SRAM = !Point_list_REB ? gradient_fetching_index + 1 : 'd0;

genvar bnk;
    generate
        for (bnk = 0; bnk < Banks; bnk++) begin : gradient_to_SRAM_inst
            assign Gradient_SRAM_REB_from_Top_control[bnk] = (Gradient_state_current == GRADIENT_FETCHING) && ( ((gradient_fetching_index[$clog2(Banks)-1:0] + 1) % num_pixels == bnk) && (gradient_fetching_index < block_gaussian_range_out))  && !Top_fifo_pop? 1'b0 : 1'b1;
            assign gradient_id_to_SRAM_from_Top_control[bnk] = (Gradient_state_current == GRADIENT_FETCHING) && (gradient_fetching_index <= block_gaussian_range_out) ? gradient_fetching_index + 1: 'd0;
        end
    endgenerate



// gradient fetching index
// 이거 수정 필요
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        gradient_fetching_done_reg <= 1'b0;
        gradient_fetching_index <= 'd0;
        gradient_writing_index <= 'd0;

        reading_gradient_gaussian_official_ID <= 'd0;
        gradient_data_from_cache <= 'd0;
        gradient_data_from_external_memory <= 'd0;
        gradient_data_from_adder <= 'd0;

        gradient_writing_state_current <= GRADIENT_WRITING_IDLE;
        gradient_fetching_state_current <= GRADIENT_FETCHING_IDLE;
        
        
    end
    else begin

        gradient_fetching_state_current <= gradient_fetching_state_next;
        gradient_writing_state_current <= gradient_writing_state_next;

        if (Gradient_state_current == GRADIENT_BUSY && Gradient_state_next == GRADIENT_FETCHING) begin
            
            reading_gradient_gaussian_official_ID <= 'd0;
            gradient_data_from_cache <= 'd0;
            gradient_data_from_external_memory <= 'd0;
            gradient_data_from_adder <= 'd0;

            gradient_fetching_index <= 'd0;
            gradient_writing_index <= 'd0;
            
        end

        if (Gradient_state_current == GRADIENT_FETCHING) begin

            // if (gradient_fetching_index < block_gaussian_range_out) begin
            // 새로운 데이터 + 인덱스 + 기존 데이터 읽는 동안에는 증가하면 안됨
            // if (push_to_Top_FIFO && (gradient_fetching_index <= block_gaussian_range_out + 1)  )  begin
            if (Top_fifo_push && (gradient_fetching_index <= block_gaussian_range_out + 1)  )  begin
                gradient_fetching_index <= gradient_fetching_index + 1;
            end

            if (gradient_writing_index == block_gaussian_range_out) begin
                gradient_fetching_done_reg <= 1'b1;

            end

        end
        else begin
            gradient_fetching_done_reg <= 1'b0;
        end


        
        if ((gradient_fetching_state_current == GRADIENT_FETCHING_AR) && push_to_Top_FIFO) begin
            reading_gradient_gaussian_official_ID <= gaussian_ID_from_point_list_SRAM;
            gradient_data_from_cache <= gradient_merge_to_Top_FIFO;
        end

        if ((gradient_fetching_state_current == GRADIENT_FETCHING_R) && (gradient_s_axi_rvalid && gradient_s_axi_rready)) begin
            // gradient_data_from_external_memory <= gradient_s_axi_rdata;
            gradient_data_from_adder <= gradient_adder_grads_result;
        end

        if (gradient_writing_state_current == GRADIENT_WRITING_B && gradient_writing_state_next == GRADIENT_WRITING_IDLE) begin
            gradient_writing_index <= gradient_writing_index + 1;
        end

    end
end


always_comb begin
    gradient_fetching_state_next = gradient_fetching_state_current;

    case (gradient_fetching_state_current)

        // 'd0 : IDLE + REB시 다음 상태인 AR 상태로 전환
        GRADIENT_FETCHING_IDLE: begin
            if (!Point_list_REB) begin
                gradient_fetching_state_next = GRADIENT_FETCHING_AR;
            end
        end

        // 'd1 : AR 상태
        GRADIENT_FETCHING_AR: begin
            if (gradient_s_axi_arready) begin
                gradient_fetching_state_next = GRADIENT_FETCHING_R;
            end
        end

        GRADIENT_FETCHING_R: begin
            if (gradient_s_axi_rvalid) begin
                gradient_fetching_state_next = GRADIENT_FETCHING_ADD;
            end
        end

        GRADIENT_FETCHING_ADD: begin
            if (!Top_fifo_full) begin
                gradient_fetching_state_next = GRADIENT_FETCHING_IDLE;
            end
        end
        
    endcase
end


always_comb begin
    gradient_writing_state_next = gradient_writing_state_current;

    case (gradient_writing_state_current)
        GRADIENT_WRITING_IDLE: begin
            if (gradient_s_axi_awvalid && gradient_s_axi_awready) begin
                gradient_writing_state_next = GRADIENT_WRITING_W;
            end
        end

        GRADIENT_WRITING_W: begin
            if (gradient_s_axi_wvalid && gradient_s_axi_wready) begin
                gradient_writing_state_next = GRADIENT_WRITING_B;
            end
        end

        GRADIENT_WRITING_B: begin
            if (gradient_s_axi_bvalid && gradient_s_axi_bready) begin
                gradient_writing_state_next = GRADIENT_WRITING_IDLE;
            end
        end

        default: begin
            gradient_writing_state_next = GRADIENT_WRITING_IDLE;
        end
    endcase

end 






    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////// Gradient FIFO ////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    
    // assign Top_fifo_push = push_to_Top_FIFO && !Top_fifo_full;
    assign Top_fifo_push = (Gradient_state_current == GRADIENT_FETCHING) && (gradient_fetching_state_current == GRADIENT_FETCHING_ADD) && !Top_fifo_full;

    assign Top_fifo_push_data = {reading_gradient_gaussian_official_ID, gradient_data_from_adder};

    // assign Top_fifo_pop = (gradient_s_axi_rvalid && gradient_s_axi_rready) && !Top_fifo_empty;
    assign Top_fifo_pop = (Gradient_state_current == GRADIENT_FETCHING) && (gradient_writing_state_current == GRADIENT_WRITING_W) && !Top_fifo_empty && (gradient_s_axi_wvalid && gradient_s_axi_wready);

    
    // BLock에서의 데이터를 

    push_pop_FIFO
    #(
        .FIFO_depth(2),
        .input_data_width(GRADIENT_MERGE_TO_TOP_WIDTH + Gaussian_Range_Bit),
        .output_data_width(GRADIENT_MERGE_TO_TOP_WIDTH + Gaussian_Range_Bit)
    )

    gradient_to_External_memory_FIFO_inst
    (
        .clk(clk),
        .rst_n(rst_n),
        
        .push_data_in(Top_fifo_push_data),
        .push_valid_in(Top_fifo_push),

        .pop_valid_in(Top_fifo_pop),
        .pop_data_out(Top_fifo_pop_data),

        .full_out(Top_fifo_full),
        .empty_out(Top_fifo_empty) 
    );


    always_ff @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gradient_adder_grads_result_FF <= 'd0;
        end
        else begin
            gradient_adder_grads_result_FF <= gradient_adder_grads_result;
        end
    end

    genvar grads;
    generate 
        for (grads = 0; grads < 11; grads++) begin : gradient_adder
            DW_fp_add #(mantissa_bit, exponent_bit, 0) 
                gradient_adder_grads (
                .a(gradient_data_from_cache[((grads + 1) * precision)-1:grads * precision]),
                .b(gradient_s_axi_rdata[((grads + 1) * precision)-1: grads * precision]),
                .rnd(3'b0),
                .z(gradient_adder_grads_result[((grads + 1) * precision)-1: grads * precision]),
                .status(status[0])
            );            
        end
    endgenerate 



endmodule