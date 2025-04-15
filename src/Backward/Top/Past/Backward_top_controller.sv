module Backward_top_controller #(
    parameter precision = 16,
    parameter mantissa_bit = 7,
    parameter exponent_bit = 8,
    parameter num_pixels = 16,
    parameter GID_bit = 12,
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

    input wire [GID_bit-1:0] block_gaussian_range,

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

        // Gaussian Range
        input wire range_rsta_busy,
        input wire range_rstb_busy,

        // aw channel
        output wire [11:0] range_s_axi_awid,
        output wire [23:0] range_s_axi_awaddr,
        output wire [7:0] range_s_axi_awlen,
        output wire [2:0] range_s_axi_awsize,
        output wire [1:0] range_s_axi_awburst,
        output wire range_s_axi_awvalid,
        input wire range_s_axi_awready,

        // w channel
        output wire [159:0] range_s_axi_wdata,
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
        output wire [11:0] range_s_axi_arid,
        output wire [23:0] range_s_axi_araddr,
        output wire [7:0] range_s_axi_arlen,
        output wire [2:0] range_s_axi_arsize,
        output wire [1:0] range_s_axi_arburst,
        output wire range_s_axi_arvalid,
        input wire range_s_axi_arready,

        // r channel
        input wire [11:0] range_s_axi_rid,
        input wire [159:0] range_s_axi_rdata,
        input wire [1:0] range_s_axi_rresp,
        input wire range_s_axi_rlast,
        input wire range_s_axi_rvalid,
        output wire range_s_axi_rready,

        
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
        input wire [159:0] gaussian_s_axi_rdata,
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
        output wire [23:0] pixel_s_axi_araddr,
        output wire [7:0] pixel_s_axi_arlen,
        output wire [2:0] pixel_s_axi_arsize,
        output wire [1:0] pixel_s_axi_arburst,
        output wire pixel_s_axi_arvalid,
        input wire pixel_s_axi_arready,

        // r channel
        input wire [11:0] pixel_s_axi_rid,
        input wire [159:0] pixel_s_axi_rdata,
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
        output wire [159:0] gradient_s_axi_wdata,
        output wire [31:0] gradient_s_axi_wstrb,
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
        input wire [159:0] gradient_s_axi_rdata,
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
    output wire Gradient_SRAM_WEB_from_Top_control [Banks-1:0]
);

// localparam N_PIXELS = 307200;

// FF register
reg [15:0] block_index_for_control;

reg [15:0] max_block_index;

// Pixel fetching index
reg [21:0] pixel_fetching_index;


reg [$clog2(num_pixels)-1:0] pixel_fetching_row;


reg [$clog2(num_pixels)-1:0] pixel_fetching_line;


reg [2 * $clog2(num_pixels):0] pixel_fetching_count;

reg [GID_bit-1:0] gaussian_fetching_index;
reg [GID_bit-1:0] gradient_fetching_index;


reg [7:0] target_block_x;
reg [7:0] target_block_y;

// Comb register
reg gradient_value_ready_reg;
reg gradient_fetching_done_reg;
reg block_fetching_allowed_reg;
reg Block_data_done_reg;

reg [15:0] block_index_for_control_next;
reg [21:0] pixel_fetching_index_next;
reg [$clog2(num_pixels)-1:0] pixel_fetching_row_next;
reg [$clog2(num_pixels)-1:0] pixel_fetching_line_next;
reg [GID_bit-1:0] gaussian_fetching_index_next;
reg [GID_bit-1:0] gradient_fetching_index_before;

reg [7:0] target_block_x_next;
reg [7:0] target_block_y_next;



// wire
wire backward_handshake;
wire gradient_handshake;

wire gradient_fetching_done;




// State
reg [1:0] Gradient_state_current;
reg [1:0] Gradient_state_next;

localparam  GRADIENT_IDLE = 2'd0,
            TILE_BASIC_FETCHING = 2'd1,
            GRADIENT_BUSY = 2'd2,
            GRADIENT_FETCHING = 2'd3;

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
            // Range 가져오는거 구현해야 함
            else if (1'b1) begin
                block_fetching_allowed_reg = 1'b1;
                Gradient_state_next = GRADIENT_BUSY;
            end
        end

        // 'd2, GRADIENT BUSY
        GRADIENT_BUSY: begin
            gradient_value_ready_reg = 1'b1;
            

            // 한 블록 완료시 완료 후 Gradient 모으는 state 전환하여 gradient 모집
            if (gradient_handshake) begin
                Gradient_state_next = GRADIENT_FETCHING;
            end
        end

        // 'd3, GRADIENT FETCHING
        GRADIENT_FETCHING: begin
            if (gradient_fetching_done) begin
                Gradient_state_next = TILE_BASIC_FETCHING;
            end
        end
        
    endcase
end

// Top to Block Memory

always_comb begin
    Top_block_value_state_next = Top_block_value_state_current;
    Block_data_done_reg = 1'b0;
    block_index_for_control_next = block_index_for_control;

    pixel_fetching_index_next = pixel_fetching_index;
    pixel_fetching_line_next = pixel_fetching_line;
    pixel_fetching_row_next = pixel_fetching_row;

    case (Top_block_value_state_current)

        TOP_BLOCK_IDLE: begin
            if (block_fetching_allowed_reg) begin
                Top_block_value_state_next = TOP_BLOCK_FETCHING;
            end
        end

        TOP_BLOCK_FETCHING: begin

            // Max에 해당하는 데이터 전부 전송시 반환
            // Pixel 데이터 획득 && Gaussian 데이터 획득시 반환
        
            if ((pixel_fetching_count[2 * $clog2(num_pixels)]) && (gaussian_fetching_index >= block_gaussian_range_out)) begin                
                Block_data_done_reg = 1'b1;
                Top_block_value_state_next = TOP_BLOCK_DONE;
                block_index_for_control_next = block_index_for_control_next + 1;                
            end


            if (pixel_fetching_count == 0) begin
                pixel_fetching_index_next = pixel_fetching_row_next * W_in + target_block_x * num_pixels + target_block_y * num_pixels * W_out;
            end        

            // 15개 다 찬 경우
            else if (pixel_fetching_line_next == num_pixels - 1) begin                
                pixel_fetching_line_next = 'd0;
                pixel_fetching_row_next = pixel_fetching_row_next + 1;
                pixel_fetching_index_next = pixel_fetching_row_next * W_out + target_block_x * num_pixels + target_block_y * num_pixels * W_out;
            end

            else begin
                pixel_fetching_line_next = pixel_fetching_line_next + 1;
                pixel_fetching_index_next = pixel_fetching_index_next + 1;
            end


        end

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


genvar Bnk;
generate
    for (Bnk = 0; Bnk < Banks; Bnk = Bnk + 1) begin : Gradient_SRAM_REB_control_inst
        assign Gradient_SRAM_REB_from_Top_control[Bnk] = (Gradient_state_current == GRADIENT_FETCHING) && ((gradient_fetching_index[$clog2(Banks)-1:0] + 'd1) % num_pixels == Bnk) ? 1'b0 : 1'b1;
        assign gradient_id_to_SRAM_from_Top_control[Bnk] = (Gradient_state_current == GRADIENT_FETCHING) ? gradient_fetching_index + 1 : 'd0;
    end
endgenerate 


// FF Transition

// Gradient State
always_ff @ (posedge clk) begin
    if (!rst_n) begin
        Gradient_state_current <= GRADIENT_IDLE;
        W_out <= 'd0;
        H_out <= 'd0;
        block_id_out <= 'd0;
        block_gaussian_range_out <= 'd0;

    end

    else begin
        Gradient_state_current <= Gradient_state_next;

        if (backward_handshake) begin
            W_out <= W_in;
            H_out <= H_in;
        end

    end
end

// Top to Block State

always_ff @ (posedge clk) begin
    if (!rst_n) begin
        Top_block_value_state_current <= TOP_BLOCK_IDLE;

        block_index_for_control <= 'd0;
        pixel_fetching_index <= 'd0;
        pixel_fetching_row <= 'd0;
        pixel_fetching_line <= 'd0;
        pixel_fetching_count <= 'd0;
        // gaussian_fetching_index <= 'd0;
        // gradient_fetching_index <= 'd0;
        target_block_x <= 'd0;
        target_block_y <= 'd0;
        // gradient_fetching_index_before <= 'd0;

    end

    else begin
        Top_block_value_state_current <= Top_block_value_state_next;
    end
end


genvar g, p;
generate 

    for (g = 0; g < gaussian_inputs; g++) begin : gaussian_to_SRAM_inst
        assign Gaussian_SRAM_WEB[g] = (Top_block_value_state_current == TOP_BLOCK_FETCHING) && (gaussian_fetching_index < block_gaussian_range_out ) && ((gaussian_fetching_index + 1) % gaussian_inputs == g) ? 1'b0 : 1'b1;                            
        assign write_address_to_gaussian_SRAM[g] = ((Top_block_value_state_current == TOP_BLOCK_FETCHING) && (gaussian_fetching_index < block_gaussian_range_out )) && ((gaussian_fetching_index + 1) % gaussian_inputs == g) ? (gaussian_fetching_index + 1) >> $clog2(gaussian_inputs): 'h0;
    end

    for (p = 0; p < num_pixels; p++) begin : pixel_to_SRAM_inst
        assign Pixel_SRAM_WEB[p] = (Top_block_value_state_current == TOP_BLOCK_FETCHING && pixel_fetching_count < 'd256) && (pixel_fetching_count % num_pixels == p) ? 1'b0 : 1'b1;
        assign write_address_to_pixel_SRAM[p] = ((Top_block_value_state_current == TOP_BLOCK_FETCHING) && (pixel_fetching_count < 'd256 )) && (pixel_fetching_count % num_pixels == p) ? pixel_fetching_row : 'h0;
    end

endgenerate


// gradient fetching index
always_ff @(posedge clk) begin
    if (!rst_n) begin
        gradient_fetching_done_reg <= 1'b0;
        gradient_fetching_index <= 'd0;
        gradient_fetching_index_before <= 'd0;
    end
    else begin

        if (Gradient_state_current == GRADIENT_BUSY && Gradient_state_next == GRADIENT_FETCHING) begin
            gradient_fetching_index <= 'd0;
            gradient_fetching_index_before <= 'd0;
        end

        if (Gradient_state_current == GRADIENT_FETCHING) begin

            gradient_fetching_index_before <= gradient_fetching_index;
            gradient_fetching_index <= gradient_fetching_index + 1;

            // if (gradient_fetching_index == (mem_range[2 * (block_index_for_control - 1) + 1] - mem_range[2 * (block_index_for_control - 1)] - 2)) begin
            if (gradient_fetching_index == (block_gaussian_range_out - 1)) begin                
                gradient_fetching_done_reg <= 1'b1;
            end
        end
        else begin
            gradient_fetching_done_reg <= 1'b0;
        end
    end
end


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////// Range Unit AXI4 BRAM ////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    
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
    assign range_s_axi_bid = 'b0;
    assign range_s_axi_bresp = 'b0;
    assign range_s_axi_bvalid = 1'b0;
    

    // ar channel
    assign [11:0] range_s_axi_arid = // arid = Block 내부에서의 Gaussian ID
    assign [23:0] range_s_axi_araddr = {{8'b0}, block_index_for_control};
    assign [7:0] range_s_axi_arlen,
    assign [2:0] range_s_axi_arsize,
    assign [1:0] range_s_axi_arburst,
    assign range_s_axi_arvalid = (Gradient_state_current == TILE_BASIC_FETCHING);
    
    // r channel
    input wire [11:0] range_s_axi_rid,
    input wire [159:0] range_s_axi_rdata,
    input wire [1:0] range_s_axi_rresp,
    input wire range_s_axi_rlast,
    input wire range_s_axi_rvalid = (Gradient_state_current == TILE_BASIC_FETCHING);
    




// Push Pop FIFO
// BLOCK gaussian ID => Total Gradient ID



endmodule