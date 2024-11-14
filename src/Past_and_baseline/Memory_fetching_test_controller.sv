module DMAC
#(
    parameter ADDR_WIDTH = 28,        // Address width for source and destination memory

    // addr width 32 = 4G, 28 = 256M , 24 = 16M

    // Final Address : 0x02E0_0000    (넉넉하게 대략 48MB)

    parameter DATA_WIDTH = 32         // Data width for the transfers
)
(
    input  wire        clk,          // Clock signal
    input  wire        rst_n,        // Active low reset signal
    input  wire        start_in,        // Start transfer signal from CPU


    input  wire [15:0]  block_id_in,   // BLOCK ID for the transfer
    
    input  wire [ADDR_WIDTH-1:0] range_src_addr_in, // BLOCK ID range 시작 주소 (0x0000_0200 + block_id << 3 으로 외부에서 줘야함)


    input  wire [63:0]  source_size, // BLOCK ID에서의 Gaussian Size 확인 (가져와야 하는 갯수)


    input  wire [ADDR_WIDTH-1:0] src_addr_in,  // Source address for the transfer
    input  wire [ADDR_WIDTH-1:0] dest_addr_in, // Destination address for the transfer

    // input  wire [15:0] transfer_size,   // Number of words to transfer

    output wire        busy_out,         // Indicates DMAC is busy transferring
    output wire        done_out,         // Transfer done interrupt signal

    // Source memory interface
    output wire [ADDR_WIDTH-1:0] src_mem_addr_out,  // Address to source memory
    // input  wire [DATA_WIDTH-1:0] src_mem_data_in,   // Data from source memory
    
    // Destination memory interface
    output wire [ADDR_WIDTH-1:0] dest_mem_addr_out, // Address to destination memory
    // output wire [DATA_WIDTH-1:0] dest_mem_data_out, // Data to destination memory
    output wire        dest_mem_write_out           // Write enable to destination memory
);

    // Internal signals and registers
    reg [ADDR_WIDTH-1:0] src_addr, src_addr_next;  // Current source address during transfer
    reg [ADDR_WIDTH-1:0] dest_addr, dest_addr_next; // Current destination address during transfer
    reg [15:0]           words_left, words_left_next;        // Number of words left to transfer
    reg                  transfer_active;   // Active transfer flag
    reg                  busy, done;        // Status signals
    reg [15:0]           block_id;   

    reg [63:0]           source_size_save; // BLOCK ID에서의 Gaussian Size 확인 (가져와야 하는 갯수)

    

    // FSM States for DMAC
    typedef enum logic [2:0] {
        IDLE        = 3'b000,
        FETCH_SIZE  = 3'b001,
        READ        = 3'b010,
        WRITE       = 3'b011,
        COMPLETE    = 3'b100
    } state_t;

    state_t state, state_next;

    // DMA Transfer FSM
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;

            done <= 1'b0;
            busy <= 1'b0;
            transfer_active <= 1'b0;
            src_addr <= 'h0;
            dest_addr <= 'h0;
            words_left <= 0;
            block_id <= 0;
        end 

        else begin
            state <= state_next;
            src_addr <= src_addr_next;
            dest_addr <= dest_addr_next;
            words_left <= words_left_next;
        end
    end

    // FSM Next State Logic and Outputs
    always_comb begin
        // Default values
        state_next = state;
        busy = transfer_active;
        done = 1'b0;

        case (state)

            IDLE: begin
                busy = 1'b0;

                // Transition to the READ state if start signal is asserted
                if (start_in) begin

                    // Initialize transfer parameters
                    src_addr_next = src_addr_in;
                    dest_addr_next = dest_addr_in;
                    block_id = block_id_in;




                    words_left_next = 0;
                    transfer_active = 1'b1;
                    state_next = FETCH_SIZE;  // Move to the read state to start fetching data

                end 

            end

            FETCH_SIZE : begin

            end

            READ: begin
                if (words_left > 0) begin
                    // Provide the current source address to the source memory
                    src_mem_addr = current_src_addr;
                    state_next = WRITE;  // After reading, move to the write state
                end else begin
                    state_next = COMPLETE;  // No more words to transfer
                end
            end

            WRITE: begin
                // Write the fetched data to the destination memory
                dest_mem_addr = current_dest_addr;
                dest_mem_data = src_mem_data;  // Transfer the read data
                dest_mem_write = 1'b1;         // Assert the write signal

                // Update the source and destination addresses and decrement words left
                current_src_addr = current_src_addr + 1;
                current_dest_addr = current_dest_addr + 1;
                words_left = words_left - 1;

                state_next = READ;  // Go back to READ state to fetch next data
            end

            COMPLETE: begin
                // Transfer is complete
                transfer_active = 1'b0;
                done = 1'b1;  // Assert done signal to indicate transfer completion
                state_next = IDLE;
            end

            default: state_next = IDLE;
        endcase
    end

endmodule
