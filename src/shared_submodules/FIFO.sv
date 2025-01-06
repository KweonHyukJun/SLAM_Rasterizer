module FIFO #(
    parameter FIFO_depth = 16, 
    parameter input_data_width = 200, 
    parameter output_data_width = 200)
    (
    input wire clk,
    input wire rst_n,
    input wire [input_data_width - 1 : 0] write_data_in,
    input wire write_valid_in,
    input wire read_valid_in,

    output wire [output_data_width - 1 : 0] read_data_out,

    output wire full_out,
    output wire empty_out
    );
    

    // Register declaration
    logic full, full_next;
    logic empty, empty_next;
    logic [$clog2(FIFO_depth):0] write_pointer, write_pointer_next; // MSB is for circular position
    logic [$clog2(FIFO_depth):0] read_pointer, read_pointer_next; // MSB is for position

    logic [input_data_width-1:0] data [FIFO_depth-1:0];

    integer i;


    always_ff @ (posedge clk) begin
        if (!rst_n) begin
            full <= 1'b0;
            empty <= 1'b1;

            write_pointer <= { ($clog2(FIFO_depth) + 1) {1'b0}};
            read_pointer <= { ($clog2(FIFO_depth) + 1) {1'b0}};

            for (int i = 0 ; i < FIFO_depth ; i = i + 1) begin
                data[i] <= {(input_data_width){1'b0}};
            end
            
        end

        else begin 

            full <= full_next;
            empty <= empty_next;
            
            write_pointer <= write_pointer_next;
            read_pointer <= read_pointer_next;

            if (write_valid_in) begin
                data[write_pointer[$clog2(FIFO_depth)-1:0]] <= write_data_in;
            end

        end
    end


    always_comb begin
        write_pointer_next = write_pointer;
        read_pointer_next = read_pointer;

        if (write_valid_in && !full) begin
            // Circular Logic 추가
            write_pointer_next = write_pointer + 'd1;
        end

        if (read_valid_in && !empty) begin
            // Circular Logic 추가
            read_pointer_next = read_pointer + 'd1;
        end
        
        empty_next = (write_pointer_next == read_pointer_next);
        full_next = (write_pointer_next[$clog2(FIFO_depth)-1:0] == read_pointer_next[$clog2(FIFO_depth)-1:0]) && (write_pointer_next[$clog2(FIFO_depth)] && read_pointer_next[$clog2(FIFO_depth)]);

    end


    assign full_out = full;
    assign empty_out = empty;

    // To make Output data different, need to change (bit operation needed)
    assign read_data_out = data[read_pointer[$clog2(FIFO_depth)-1:0]][output_data_width-1:0];

endmodule