module Top_controller #(
    // parameter max_num_rendered = 500000,  // point list에 사용되는 Block 마다 depth 기준 복제된 Gaussian의 총 수로 사용됩니다.  Replica Dataset 기준 최대 450k 여서 넉넉히 500k로 설정했습니다.
    // parameter max_blocks = 8160, // 1920 x 1080 에 Block마다 16x16 픽셀이라고 가정 시 최대의 block 수 (120 * 67.5 -> 68) = (120 * 68) = 8160
    // parameter max_num_gaussian = 200000, //

    parameter precision = 24,
    parameter mantissa_bit = 15,
    parameter exponent_bit = 8,

    parameter max_W = 1920,
    parameter max_H = 1080,
    parameter num_BLOCK_CTRL = 8,
    parameter BLOCK_SIZE = 16,
    
    parameter group_gaussian = 32
) (
    input   wire clk,
    input   wire rst_n,

    // input   wire [7:0] mem_data_in,
    // output  reg [7:0] mem_data_out [NUM_BLOCKS][NUM_PIXEL_GROUPS],
    // input   wire [15:0] mem_addr_in,
    // output  reg [15:0] mem_addr_out [NUM_BLOCKS][NUM_PIXEL_GROUPS],
    // input   wire mem_read,
    // input   wire mem_write

    ////////////////////////////////////////////////////
    /////////// Communication to Memory Ctrl ///////////
    ////////////////////////////////////////////////////

    //////////////////////////////////
    //////// From Memory Ctrl ////////
    //////////////////////////////////
    input wire [11:0]                       W_from_memory,                                                                  // 최대 1920 x 1080 기준으로 할때 2048인 2^11 기준 (혹시 몰라서 1비트 추가한 11비트로 W, H 책정했습니다)
    input wire [11:0]                       H_from_memory,

    //////////////////////////
    /////// Ctrl signal //////
    //////////////////////////
    input wire                              gaussian_valid_from_memory,
    input wire                              gradient_ready_from_memory,



    //////////////////////////
    /////// Ctrl signal //////
    //////////////////////////
    output reg                              gaussian_ready_to_memory,
    output reg                              gradient_valid_to_memory,
    output reg                              done_to_memory,


    ////////////////////////////////////////////////////
    /////////// Communication to Block Ctrl ////////////
    ////////////////////////////////////////////////////

    //////////////////////////////////
    ///////// To Block Ctrl //////////
    //////////////////////////////////



    //////////////////////////
    /////// Ctrl signal //////
    //////////////////////////
    
    output reg                              gaussian_valid_to_block                  [num_BLOCK_CTRL-1:0],
    output reg                              gradient_ready_to_block                  [num_BLOCK_CTRL-1:0],


    //////////////////////////////////
    //////// From Block Ctrl /////////
    //////////////////////////////////

    //////////////////////////
    /////// Ctrl signal //////
    //////////////////////////
    
    input wire                              gaussian_ready_from_block                [num_BLOCK_CTRL-1:0], 
    input wire                              gradient_valid_from_block                [num_BLOCK_CTRL-1:0]

);

    
    // state declaration
    reg [1:0] top_state, top_state_next ;
    localparam  TOP_IDLE                        =       2'b00,
                TOP_GAUSSIAN_TRANSFER           =       2'b01,
                TOP_FETCH                       =       2'b10,
                TOP_GRADIENT_CALCULATION        =       2'b11;  

    reg [1:0] sub_top_state [num_BLOCK_CTRL-1:0];
    reg [1:0] sub_top_state_next [num_BLOCK_CTRL-1:0];
    
    localparam  SUB_TOP_IDLE                    =       2'b00,
                SUB_TOP_GAUSSIAN_TRANSFER       =       2'b01,
                SUB_TOP_GRADIENT_WAIT           =       2'b10;


    // Reg declaration
    reg [11:0] W_from_memory_reg, H_from_memory_reg;

    reg top_to_sub_top_to_BUSY [num_BLOCK_CTRL-1:0];
    reg top_to_sub_top_gaussian_valid [num_BLOCK_CTRL-1:0];
    reg top_to_sub_top_gradient_ready [num_BLOCK_CTRL-1:0];

    reg sub_top_to_top_gaussian_ready [num_BLOCK_CTRL-1:0];
    reg sub_top_to_top_gradient_valid [num_BLOCK_CTRL-1:0];

    // Wire declaration

    wire sub_top_to_top_gaussian_ready_all_zero;
    

    // Sub_top에서 gaussian 요청이 없음.
    assign sub_top_to_top_gaussian_ready_all_zero = &sub_top_to_top_gaussian_ready;


    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            top_state <= TOP_IDLE;

            // Reset all registers
            gaussian_ready_to_memory <= 1'b1;
            gradient_valid_to_memory <= 1'b0;

            for (int i = 0; i < num_BLOCK_CTRL; i++) begin
                gaussian_valid_to_block[i] <= 1'b0;
                gradient_ready_to_block[i] <= 1'b0;
                sub_top_state[i] <= SUB_TOP_IDLE;
            end
        end 
        
        else begin
            top_state <= top_state_next;
            for (int i = 0; i < num_BLOCK_CTRL; i++) begin
                sub_top_state[i] <= sub_top_state_next[i];
            end
        end
    end


    // Top FSM
    always_comb begin

        top_state_next = top_state;

        case (top_state)
            // W랑 blockid 최대값 IDLE에서 정해야 함
            TOP_IDLE: begin
                gaussian_ready_to_memory = 1'b1;
                

                for (int i = 0; i < num_BLOCK_CTRL; i++) begin                    
                    top_to_sub_top_to_BUSY[i] = 1'b0;
                    top_to_sub_top_gaussian_valid[i] = 1'b0;
                    top_to_sub_top_gradient_ready[i] = 1'b0;
                end

                if (gaussian_valid_from_memory) begin
                    top_state_next = TOP_GAUSSIAN_TRANSFER;
                    // 메모리 받는 액션
                end
            end

            TOP_GAUSSIAN_TRANSFER: begin
                gaussian_ready_to_memory = 1'b0;
                
                for (int i = 0; i < num_BLOCK_CTRL; i++) begin                    
                    top_to_sub_top_to_BUSY[i] = 1'b1;
                    top_to_sub_top_gaussian_valid[i] = 1'b1;
                    top_to_sub_top_gradient_ready[i] = 1'b0;
                    // 메모리 주는 액션
                end

                // Gaussian 부족하다는 조건에서 넘어가기
                // if (gaussian_valid_from_memory) begin
                //     top_state_next = TOP_FETCH;
                // end
                

                // TOP_GRADIENT으로 넘어가는 조건 추가해야 함
                if (sub_top_to_top_gaussian_ready_all_zero) begin
                    top_state_next = TOP_GRADIENT_CALCULATION;
                end                    

            end


            TOP_FETCH: begin
                gaussian_ready_to_memory = 1'b1;

                if (gaussian_valid_from_memory) begin
                    // 메모리 받는 액션

                    // SUB_TOP 에서 온게 없으면 GRADIENT 처리
                    if (sub_top_to_top_gaussian_ready_all_zero) begin
                        top_state_next = TOP_GRADIENT_CALCULATION;
                    end
                    
                    else begin
                        top_state_next = TOP_GAUSSIAN_TRANSFER;
                    end
                end
            end

            TOP_GRADIENT_CALCULATION: begin
                gradient_valid_to_memory = 1'b1;
                if (done_to_memory) begin
                    top_state_next = TOP_IDLE;
                end
            end


            default : begin
                top_state_next = TOP_IDLE;
            end

        endcase
    end 


    // Sub Top FSM
    always_comb begin
        for (int i = 0; i < num_BLOCK_CTRL; i++) begin
            sub_top_state_next[i] = sub_top_state[i];
        end


        case (sub_top_state) 
            SUB_TOP_IDLE : begin
                for (int i = 0; i < num_BLOCK_CTRL; i++) begin
                    if (top_to_sub_top_to_BUSY[i]) begin
                        gaussian_valid_to_block[i] = 1'b0;
                        gradient_ready_to_block[i] = 1'b0;
                        sub_top_to_top_gaussian_ready[i] = 1'b0;
                        sub_top_to_top_gradient_valid[i] = 1'b0;

                        sub_top_state_next[i] = SUB_TOP_GAUSSIAN_TRANSFER;
                        
                    end
                end
            end

            SUB_TOP_GAUSSIAN_TRANSFER : begin
                for (int i = 0; i < num_BLOCK_CTRL; i++) begin
                    gaussian_valid_to_block[i] = 1'b1;
                    gradient_ready_to_block[i] = 1'b0;
                    sub_top_to_top_gaussian_ready[i] = 1'b1;
                    sub_top_to_top_gradient_valid[i] = 1'b0;

                    if (gaussian_ready_from_block[i]) begin
                        sub_top_state_next[i] = SUB_TOP_GRADIENT_WAIT;
                    end
                end
            end


            SUB_TOP_GRADIENT_WAIT : begin
                for (int i = 0; i < num_BLOCK_CTRL; i++) begin

                    gaussian_valid_to_block[i] = 1'b0;
                    gradient_ready_to_block[i] = 1'b1;

                    if (gradient_valid_from_block[i]) begin

                        // Gradient가 완료되었을 때
                        if (top_to_sub_top_gaussian_valid[i]) begin
                            sub_top_state_next[i] = SUB_TOP_GAUSSIAN_TRANSFER;
                        end

                        else begin
                            sub_top_state_next[i] = SUB_TOP_IDLE;
                        end


                    end
                end
            end

            default: begin
                for (int i = 0; i < num_BLOCK_CTRL; i++) begin
                    sub_top_state_next[i] = SUB_TOP_IDLE;
                end
            end

        endcase
    end



    // BlockController #(.NUM_PIXEL_GROUPS(NUM_PIXEL_GROUPS)) block_controllers [NUM_BLOCKS] (
    //     .clk(clk),
    //     .reset(reset),
    //     .mem_data_in(mem_data_in),
    //     .mem_data_out(mem_data_out),
    //     .mem_addr_in(mem_addr_in),
    //     .mem_addr_out(mem_addr_out),
    //     .mem_read(mem_read),
    //     .mem_write(mem_write)
    // );

    // Additional top-level control logic here

    

endmodule