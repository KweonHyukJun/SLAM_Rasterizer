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
    )
(
    input   wire clk,
    input   wire rst_n,

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
    input wire                              start_from_memory,



    //////////////////////////
    /////// Ctrl signal //////
    //////////////////////////
    output wire                              gaussian_ready_to_memory_out,
    output wire                              gradient_valid_to_memory_out,
    output wire                              done_to_memory_out,


    ////////////////////////////////////////////////////
    /////////// Communication to Block Ctrl ////////////
    ////////////////////////////////////////////////////

    //////////////////////////////////
    ///////// To Block Ctrl //////////
    //////////////////////////////////

    //////////////////////////
    /////// Ctrl signal //////
    //////////////////////////
    
    output wire                              gaussian_valid_to_block_out                  [num_BLOCK_CTRL-1:0],
    output wire                              gradient_ready_to_block_out                  [num_BLOCK_CTRL-1:0],


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
                TOP_WAIT                        =       2'b01,
                TOP_FETCH                       =       2'b10,
                TOP_GRADIENT_CALCULATION        =       2'b11;

    reg  [1:0] sub_top_state [num_BLOCK_CTRL-1:0];
    reg  [1:0] sub_top_state_next [num_BLOCK_CTRL-1:0];
    
    localparam  SUB_TOP_IDLE                    =       2'b00,
                SUB_TOP_WAIT                    =       2'b01,
                SUB_TOP_GRADIENT_DONE           =       2'b10; 
    

    // Reg declaration
    // reg [11:0] W_from_memory_reg, H_from_memory_reg;
    reg [15:0] block_id_max;
    reg [15:0] block_id_current;

    
    reg top_to_sub_top_gaussian_valid [num_BLOCK_CTRL-1:0];
    reg top_to_sub_top_gradient_ready [num_BLOCK_CTRL-1:0];

    reg sub_top_to_top_gaussian_ready [num_BLOCK_CTRL-1:0];
    reg sub_top_to_top_gradient_valid [num_BLOCK_CTRL-1:0];

    reg gaussian_valid_to_block [num_BLOCK_CTRL-1:0];
    reg gradient_ready_to_block [num_BLOCK_CTRL-1:0];

    
    reg gaussian_ready_to_memory, gradient_valid_to_memory;

    // Wire declaration



    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            top_state <= TOP_IDLE;

            block_id_max <= 16'b0;
            
            block_id_current <= 16'b0;

            // for (int i = 0; i < num_BLOCK_CTRL; i++) begin
            //     sub_top_state[i] <= SUB_TOP_IDLE;
            //     top_to_sub_top_gaussian_valid[i] <= 1'b0;
            //     top_to_sub_top_gradient_ready[i] <= 1'b0;
            //     sub_top_to_top_gaussian_ready[i] <= 1'b0;
            //     sub_top_to_top_gradient_valid[i] <= 1'b0;
            //     gaussian_valid_to_block[i] <= 1'b0;
            //     gradient_ready_to_block[i] <= 1'b0;
            // end
        end 
        
        else begin
            if (start_from_memory) begin

                if ((W_from_memory[$clog2(BLOCK_SIZE)-1:0]) != 4'b0000) begin
                    block_id_max[15:8] <= W_from_memory[11:$clog2(BLOCK_SIZE)] + 'd1;
                end
                else if ((W_from_memory[$clog2(BLOCK_SIZE)-1:0]) == 4'b0000) begin
                    block_id_max[15:8] <= W_from_memory[11:$clog2(BLOCK_SIZE)];
                end

                if ((H_from_memory[$clog2(BLOCK_SIZE)-1:0]) != 4'b0000) begin
                    block_id_max[7:0] <= H_from_memory[11:$clog2(BLOCK_SIZE)] + 'd1;
                end
                else if ((H_from_memory[$clog2(BLOCK_SIZE)-1:0]) == 4'b0000) begin
                    block_id_max[7:0] <= W_from_memory[11:$clog2(BLOCK_SIZE)];
                end

            end
            top_state <= top_state_next;
            for (int i = 0; i < num_BLOCK_CTRL; i++) begin
                sub_top_state[i] <= sub_top_state_next[i];
            end
        end


    end


    // Top FSM
    always_comb begin

        top_state_next = top_state;

        for (int i=0;i<num_BLOCK_CTRL;i=i+1) begin
            sub_top_state_next[i] = sub_top_state[i];
            top_to_sub_top_gaussian_valid[i] = 1'b0;
            top_to_sub_top_gradient_ready[i] = 1'b0;
        end


        case (top_state)
            // W랑 blockid 최대값 IDLE에서 정해야 함

            TOP_IDLE: begin
                gaussian_ready_to_memory = 1'b1;
                gradient_valid_to_memory = 1'b0;
                
                for (int i = 0; i < num_BLOCK_CTRL; i++) begin                    
                    top_to_sub_top_gaussian_valid[i] = 1'b0;
                    top_to_sub_top_gradient_ready[i] = 1'b1;
                end

                if (gaussian_valid_from_memory) begin
                    top_state_next = TOP_WAIT;
                    
                    // 메모리 받는 액션
                end
            end

            TOP_WAIT: begin
                gaussian_ready_to_memory = 1'b0;
                gradient_valid_to_memory = 1'b0;

                for (int i = 0; i < num_BLOCK_CTRL; i++) begin                    
                    top_to_sub_top_gaussian_valid[i] = 1'b1;
                    top_to_sub_top_gradient_ready[i] = 1'b1;
                    // 메모리 주는 액션
                end

                // Gaussian 부족할 때 IDLE로 넘어가기
                // if (gaussian_valid_from_memory) begin
                //     top_state_next = TOP_FETCH;
                // end
                

                // TOP_GRADIENT으로 넘어가는 조건 추가해야 함
                // 전부 다 준 경우
                // if (sub_top_to_top_gaussian_ready_all_zero) begin
                //     top_state_next = TOP_GRADIENT_CALCULATION;
                // end                    

            end


            TOP_FETCH: begin
                gaussian_ready_to_memory = 1'b1;
                gradient_valid_to_memory = 1'b0;

                if (gaussian_valid_from_memory) begin
                    // 메모리 받는 액션
                    top_state_next = TOP_WAIT;
                end
            end


            // Gradient 계산 다 끝난 경우
            TOP_GRADIENT_CALCULATION: begin
                gaussian_ready_to_memory = 1'b0;
                gradient_valid_to_memory = 1'b1;                

                if (gradient_ready_from_memory) begin
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
            gaussian_valid_to_block[i] = 1'b0;
            gradient_ready_to_block[i] = 1'b0;
            sub_top_to_top_gaussian_ready[i] = 1'b0;
            sub_top_to_top_gradient_valid[i] = 1'b0;            

            case (sub_top_state[i]) 
                SUB_TOP_IDLE : begin
                    for (int i = 0; i < num_BLOCK_CTRL; i++) begin
                        if (top_to_sub_top_gaussian_valid[i]) begin

                            gaussian_valid_to_block[i] = 1'b0;
                            gradient_ready_to_block[i] = 1'b1;
                            sub_top_to_top_gaussian_ready[i] = 1'b1;
                            sub_top_to_top_gradient_valid[i] = 1'b0;
                            sub_top_state_next[i] = SUB_TOP_WAIT;
                        end
                    end
                end

                SUB_TOP_WAIT : begin
                    for (int i = 0; i < num_BLOCK_CTRL; i++) begin
                        gaussian_valid_to_block[i] = 1'b1;
                        gradient_ready_to_block[i] = 1'b1;
                        sub_top_to_top_gaussian_ready[i] = 1'b0;
                        sub_top_to_top_gradient_valid[i] = 1'b0;


                        // 한번 보내면 다시 TOP에서 가져오는 상태로
                        if (gaussian_ready_from_block[i]) begin
                            sub_top_state_next[i] = SUB_TOP_IDLE;
                        end

                        // 
                        if (gradient_valid_from_block[i]) begin
                            sub_top_state_next[i] = SUB_TOP_GRADIENT_DONE;
                        end
                    end
                end

                SUB_TOP_GRADIENT_DONE : begin
                    for (int i = 0; i < num_BLOCK_CTRL; i++) begin
                        gaussian_valid_to_block[i] = 1'b1;
                        gradient_ready_to_block[i] = 1'b0;

                        sub_top_to_top_gaussian_ready[i] = 1'b1;
                        sub_top_to_top_gradient_valid[i] = 1'b1;

                        if (gaussian_ready_from_block[i]) begin
                            sub_top_state_next[i] = SUB_TOP_IDLE;
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