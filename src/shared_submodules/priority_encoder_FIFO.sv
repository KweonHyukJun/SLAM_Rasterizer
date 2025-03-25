
// 한번에 나올 갯수 변경

module priority_encoder_FIFO #(
    parameter Encoder_out = 4,
    parameter FIFO_depth = 16, 
    // parameter input_data_width = 200, 
    // parameter output_data_width = 200,
    parameter DATA_WIDTH = 200,
    parameter Encoder_in = 16
    )
    (
    input wire clk,
    input wire rst_n,
    input wire [DATA_WIDTH : 0] push_data_in [Encoder_in-1:0],
    input wire push_valid_in,
    input wire push_valid_index_in [Encoder_in-1:0],

    input wire pop_valid_in,

    input wire stall_backpressure,

    output wire [DATA_WIDTH: 0] pop_data_out [Encoder_out-1:0],
    output wire pop_valid_out [Encoder_out-1:0],

    // output logic push_valid_in_grant_out [Encoder_in-1:0],


    output wire full_out,
    output wire empty_out,

    output wire stall_from_FIFO
    );
    // synopsys template

    // Register declaration
    logic full, full_next;
    logic empty, empty_next;
    logic [$clog2(FIFO_depth):0] write_pointer, write_pointer_next; // MSB is for circular position
    logic [$clog2(FIFO_depth):0] read_pointer, read_pointer_next; // MSB is for position
    // logic return_valid [Encoder_out-1:0];

    logic return_valid_temp [Encoder_out-1:0];
    logic push_valid_in_temp [Encoder_in-1:0];
    

    

    logic [DATA_WIDTH:0] data [FIFO_depth-1:0];

    wire pop_condition = pop_valid_in && !empty;
    wire push_condition = push_valid_in && !full;

    wire [$clog2(FIFO_depth)-1:0] pop_index [Encoder_out-1:0];

    reg allowed_to_input;


    // // comb register for next write
    // reg [DATA_WIDTH: 0] next_fifo_data [Encoder_in-1:0];
    // reg next_fifo_valid_in [Encoder_in-1:0];
    // reg [$clog2(FIFO_depth):0] next_fifo_write_pointer;


    always_ff @ (posedge clk) begin
        if (!rst_n) begin
            full <= 1'b0;
            empty <= 1'b1;

            write_pointer <= {($clog2(FIFO_depth) + 1) {1'b0}};
            read_pointer <= {($clog2(FIFO_depth) + 1) {1'b0}};

            for (int i = 0 ; i < FIFO_depth ; i = i + 1) begin
                data[i] <= {(DATA_WIDTH + 1){1'b0}}; 
            end

            // for (int i = 0 ; i < Encoder_in ; i = i + 1) begin
            //     push_valid_in_grant_out[i] <= 1'b0;
            // end
        end

        else begin 

            if (!stall_backpressure) begin
                full <= full_next;
                empty <= empty_next;
                
                write_pointer <= write_pointer_next;
                read_pointer <= read_pointer_next;

                // 데이터 FIFO로 저장
                if (push_valid_in && allowed_to_input) begin
                    for (int i = 0 ; i < Encoder_in ; i = i + 1) begin
                        if (push_valid_index_in[i]) begin    // Changed condition                
                            data[(write_pointer + i) % FIFO_depth] <= push_data_in[i];                        
                        end
                    end
                end
            end
        end


    end


    always_comb begin
        write_pointer_next = write_pointer;
        read_pointer_next = read_pointer;

        allowed_to_input = 1'b1;

        for (int i = 0 ; i < Encoder_out ; i = i + 1) begin
            return_valid_temp[i] = 1'b0;
            if (!empty && !(write_pointer_next == read_pointer_next)) begin        // Changed condition (pop pointer = read pointer)
                read_pointer_next = read_pointer_next + 'd1;
                return_valid_temp[i] = 1'b1;
            end
        end

        for (int i = 0; i < Encoder_in; i = i + 1) begin
            push_valid_in_temp[i] = 1'b0;       



            if (!full && push_valid_index_in[i] && !((write_pointer_next[$clog2(FIFO_depth)-1:0] == read_pointer_next[$clog2(FIFO_depth)-1:0]) && (write_pointer_next[$clog2(FIFO_depth)] != read_pointer_next[$clog2(FIFO_depth)])) ) begin        // Changed condition (push pointer = write pointer )
                write_pointer_next = write_pointer_next + 'd1;
                push_valid_in_temp[i] = 1'b1;
            end
            
            // write pointer가 넘어가면 allowed_to_input 0처리
            // full next 조건 + write pointer 
            else if (write_pointer_next[$clog2(FIFO_depth)-1:0] == read_pointer_next[$clog2(FIFO_depth)-1:0] && push_valid_index_in[i]) begin
                allowed_to_input = 1'b0;
            end
        end


        if (!allowed_to_input) begin
            write_pointer_next = write_pointer;
        end

        if (!pop_valid_in) begin
            read_pointer_next = read_pointer;
        end
        
        empty_next = (write_pointer_next == read_pointer_next);
        full_next = (write_pointer_next[$clog2(FIFO_depth)-1:0] == read_pointer_next[$clog2(FIFO_depth)-1:0]) && (write_pointer_next[$clog2(FIFO_depth)] != read_pointer_next[$clog2(FIFO_depth)]);
    end



    assign full_out = full;
    assign empty_out = empty;
    assign stall_from_FIFO = !allowed_to_input;

    

    // To make Output data different, need to change (bit operation needed)
    genvar k, l;
    generate 
        for (k = 0; k < Encoder_out; k = k + 1) begin : pop_data_out_gen

            // circulation하게 넘어가면 문제가 되는거네
            // assign pop_data_out[k] = pop_valid_out[k] ? data[read_pointer[$clog2(FIFO_depth)-1:0] + k] : 'h0;
            
            assign pop_data_out[k] = pop_valid_out[k] ? data[pop_index[k]] : 'h0;
            
            // assign pop_index[k] = (read_pointer[$clog2(FIFO_depth)-1:0] + k) % (2**$clog2(FIFO_depth));
            assign pop_index[k] = (read_pointer[$clog2(FIFO_depth)-1:0] + k) % FIFO_depth;

            assign pop_valid_out[k] = return_valid_temp[k];            
        end

        // for (l = 0; l < Encoder_in; l = l + 1) begin : push_valid_in_grant_out_gen
        //     assign push_valid_in_grant_out[l] = push_valid_in_temp[l];
        // end
    endgenerate

    
    // assign pop_data_out = data[read_pointer[$clog2(FIFO_depth)-1:0]][output_data_width-1:0];

endmodule