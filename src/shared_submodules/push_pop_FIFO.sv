module push_pop_FIFO #(
    parameter FIFO_depth = 8, 
    parameter input_data_width = 800, 
    parameter output_data_width = 800
    )
    (
    input wire clk,
    input wire rst_n,
    input wire [input_data_width - 1 : 0] push_data_in,
    input wire push_valid_in,
    input wire pop_valid_in,

    output wire [output_data_width - 1 : 0] pop_data_out,


    output wire full_out,
    output wire empty_out
    );
    // synopsys template

    // Register declaration
    logic full, full_next;
    logic empty, empty_next;
    logic [$clog2(FIFO_depth):0] push_pointer, push_pointer_next; // MSB is for circular position
    logic [$clog2(FIFO_depth):0] pop_pointer, pop_pointer_next; // MSB is for position

    logic [input_data_width-1:0] data [FIFO_depth-1:0];

    integer i;


    always_ff @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            full <= 1'b0;
            empty <= 1'b1;

            push_pointer <= { ($clog2(FIFO_depth) + 1) {1'b0}};
            pop_pointer <= { ($clog2(FIFO_depth) + 1) {1'b0}};

            for (int i = 0 ; i < FIFO_depth ; i = i + 1) begin
                data[i] <= {(input_data_width){1'b0}};
            end
            
        end

        else begin 
            full <= full_next;
            empty <= empty_next;
            
            push_pointer <= push_pointer_next;
            pop_pointer <= pop_pointer_next;

            if (push_valid_in && !full) begin    // Changed condition
                data[push_pointer[$clog2(FIFO_depth)-1:0]] <= push_data_in;
            end
        end
    end


    always_comb begin
        push_pointer_next = push_pointer;
        pop_pointer_next = pop_pointer;

        if (push_valid_in && !full) begin        // Changed condition (push pointer = write pointer )
            push_pointer_next = push_pointer + 'd1;
        end

        if (pop_valid_in && !empty) begin        // Changed condition (pop pointer = read pointer)
            pop_pointer_next = pop_pointer + 'd1;
        end
        
        empty_next = (push_pointer_next == pop_pointer_next);
        full_next = (push_pointer_next[$clog2(FIFO_depth)-1:0] == pop_pointer_next[$clog2(FIFO_depth)-1:0]) && (push_pointer_next[$clog2(FIFO_depth)] != pop_pointer_next[$clog2(FIFO_depth)]);

    end


    assign full_out = full;
    assign empty_out = empty;

    // To make Output data different, need to change (bit operation needed)
    assign pop_data_out = !empty ? data[pop_pointer[$clog2(FIFO_depth)-1:0]][output_data_width-1:0] : {(output_data_width){1'b0}};
    // assign pop_data_out = data[pop_pointer[$clog2(FIFO_depth)-1:0]][output_data_width-1:0];

endmodule