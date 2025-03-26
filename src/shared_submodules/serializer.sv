module serializer #(
    parameter precision = 16,
    parameter GID_bit = 24,
    parameter DATA_SIZE = 11 * precision + GID_bit,
    // parameter DATA_SIZE = 24,
    parameter Encoder_outs = 4
    )
    (
        input logic clk, // Wire
        input logic rst_n, // Wire

        input logic [DATA_SIZE-1:0] data_in     [Encoder_outs-1:0], // Wire
        input logic                 valid_in    [Encoder_outs-1:0], // Wire

        // output logic                data_in_grant_out [Encoder_outs-1:0],

        output logic [DATA_SIZE-1:0] data_out, // FF
        output logic valid_out, // FF

        input logic last_input_done_i [Encoder_outs-1:0], // Wire
        output logic last_input_done_o, // FF


        input logic stall_backpressure, // Wire

        // output logic stall_from_serializer, // Wire
        output logic pop_next_valid_out, // Wire로 진행 + stall의 역할

        // Before stage FIFO
        input logic src_pop_valid_i,

        // Next stage FIFO
        input logic dst_ready_i





    );
    // synopsys template

    // Internal signals
    logic serializing ; // Flag indicating serialization is in progress

    // Register to store input data
    logic [DATA_SIZE-1:0] data_reg [Encoder_outs-1:0];
    logic valid_reg [Encoder_outs-1:0];
    logic last_input_done_reg [Encoder_outs-1:0];
    
    // integer out_ptr;
    // integer last_idx;

    reg index_overflow;
    reg out_ptr_found;
    reg out_ptr_found_next;
    reg ready_to_read;
    reg [$clog2(Encoder_outs):0] current_idx;
    reg [$clog2(Encoder_outs):0] next_idx;

    // Sequential logic
    always_ff @(posedge clk) begin

        if (!rst_n) begin
            data_out <= 'h0;
            valid_out <= 1'b0;
            last_input_done_o <= 1'b0;
            // out_ptr_found <= 1'b0;
            current_idx <= 0;
            ready_to_read <= 1'b0;

            for (int i = 0; i < Encoder_outs; i = i + 1) begin
                last_input_done_reg[i] <= 0;
                data_reg[i] <= 0;
                valid_reg[i] <= 0;
            end
        end

        else begin

            if (!stall_backpressure) begin

                if (out_ptr_found && dst_ready_i) begin
                    data_out <= data_reg[current_idx[$clog2(Encoder_outs)-1:0]];
                    valid_out <= valid_reg[current_idx[$clog2(Encoder_outs)-1:0]];
                    last_input_done_o <= last_input_done_reg[current_idx[$clog2(Encoder_outs)-1:0]];

                    // Reset Used Register Data
                    data_reg[current_idx[$clog2(Encoder_outs)-1:0]] <= 0;
                    valid_reg[current_idx[$clog2(Encoder_outs)-1:0]] <= 0;
                    last_input_done_reg[current_idx[$clog2(Encoder_outs)-1:0]] <= 0;
                end                

                // 추가 조건
                else begin
                    data_out <= 0;
                    valid_out <= 0;
                    last_input_done_o <= 0;
                end

                current_idx <= next_idx;
                
                
                // // input 데이터를 받아들이는 조건
                // if (dst_ready_i && !out_ptr_found_next) begin
                //     for (int i = 0; i < Encoder_outs; i = i + 1) begin
                //         last_input_done_reg[i] <= last_input_done_i[i];
                //         data_reg[i] <= data_in[i];
                //         valid_reg[i] <= valid_in[i];
                //     end
                // end
            end

            // 25-03-27 추가, stall이 들어온 경우에 valid를 방출하지 않도록
            // else begin
            //     valid_out <= 1'b0;
            // end
            
            // input 데이터를 받아들이는 조건
            if (dst_ready_i && !out_ptr_found_next) begin
                for (int i = 0; i < Encoder_outs; i = i + 1) begin
                    last_input_done_reg[i] <= last_input_done_i[i];
                    data_reg[i] <= data_in[i];
                    valid_reg[i] <= valid_in[i];
                end
            end
            
        end
    end

    // 다음 인덱스 계산 -> data입력을 받을 수 있는 조건 확인
    always_comb begin
        next_idx = current_idx + 1;
        out_ptr_found_next = 1'b0;

        serializing = 1'b0;
        index_overflow = 1'b0;


        if (!dst_ready_i) begin
            next_idx = current_idx;
        end

        else begin
            next_idx = current_idx + 1;

            if (next_idx[$clog2(Encoder_outs)] != current_idx[$clog2(Encoder_outs)]) begin
                out_ptr_found_next = 1'b0;
                serializing = 1'b0;
                index_overflow = 1'b1;
            end
        end


        if ((valid_reg[next_idx[$clog2(Encoder_outs)-1:0]] || last_input_done_reg[next_idx[$clog2(Encoder_outs)-1:0]]) && !index_overflow) begin
            out_ptr_found_next = 1'b1;
            serializing = 1'b1; // Next인데.
        end

        else begin
            out_ptr_found_next = 1'b0;
            serializing = 1'b0;
            next_idx[$clog2(Encoder_outs)-1:0] = 0;
        end
        
    end

    always_comb begin
        out_ptr_found = 1'b0;

        if (valid_reg[current_idx[$clog2(Encoder_outs)-1:0]] || last_input_done_reg[current_idx[$clog2(Encoder_outs)-1:0]]) begin
            out_ptr_found = 1'b1;
        end

    end


    assign pop_next_valid_out = !serializing && !stall_backpressure && src_pop_valid_i;


endmodule