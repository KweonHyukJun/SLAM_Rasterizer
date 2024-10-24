module Memory_fetching_test_controller
#(
    parameter DATA_WIDTH = 64,   // External memory data width (64-bit)
    parameter ADDR_WIDTH = 10,   // Address width for memory addressing
    parameter MEM_SIZE = 1024    // Internal memory size
)


(
    input  logic clk,                    // Clock signal
    input  logic rst_n,                  // Active-low reset
    input  logic ext_mem_data_ready,     // External memory data ready signal
    output logic ext_mem_read,           // Signal to trigger external memory read
    output logic [ADDR_WIDTH-1:0] ext_mem_addr,  // Address to external memory
    input  logic [DATA_WIDTH-1:0] ext_mem_data,  // 64-bit data from external memory
    output logic [ADDR_WIDTH-1:0] int_mem_addr,  // Address to internal memory
    output logic [31:0] int_mem_data,    // Data to store in internal memory
    output logic int_mem_write,          // Write enable for internal memory
    output logic ready                   // Ready signal indicating completion
);

    // Internal signals and registers
    logic [31:0] upper_data;             // data[63:32]
    logic [31:0] lower_data;             // data[31:0]
    logic [31:0] result;                 // Subtraction result
    logic [31:0] new_data;               // New 32-bit data to store
    logic [2:0] state;                   // FSM state register

    // FSM states (encoded as local parameters)
    localparam IDLE        = 3'b000;
    localparam FETCH_64    = 3'b001;
    localparam CALCULATE   = 3'b010;
    localparam FETCH_32    = 3'b011;
    localparam WRITE_MEM   = 3'b100;

    // FSM with always_ff block (SystemVerilog style)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset state
            state <= IDLE;
            ext_mem_read <= 1'b0;
            ext_mem_addr <= 0;
            int_mem_write <= 1'b0;
            ready <= 1'b0;
        end

        else begin

            case (state)

                IDLE: begin
                    ready <= 1'b0;
                    ext_mem_addr <= 0;   // Start reading from external memory at address 0
                    ext_mem_read <= 1'b1; // Initiate external memory read
                    state <= FETCH_64;   // Move to FETCH_64 state
                end

                FETCH_64: begin
                    if (ext_mem_data_ready) begin
                        // Latch the 64-bit data from external memory
                        upper_data <= ext_mem_data[63:32];
                        lower_data <= ext_mem_data[31:0];
                        ext_mem_read <= 1'b0; // Stop reading from external memory
                        state <= CALCULATE;  // Move to calculation state
                    end
                end

                CALCULATE: begin
                    // Perform the subtraction: result = upper_data - lower_data
                    result <= upper_data - lower_data;
                    // Check if result is positive


                    if (upper_data > lower_data) begin
                        ext_mem_addr <= upper_data - lower_data - 1; // Set address for next fetch
                        ext_mem_read <= 1'b1;                        // Initiate external memory read
                        state <= FETCH_32;                           // Move to FETCH_32 state
                    end
                    else begin
                        state <= IDLE;                               // Invalid result, restart
                    end

                end

                FETCH_32: begin
                    if (ext_mem_data_ready) begin
                        // Latch the 32-bit data from external memory
                        new_data <= ext_mem_data[31:0];  // Only use the lower 32 bits
                        ext_mem_read <= 1'b0;            // Stop reading from external memory
                        state <= WRITE_MEM;              // Move to internal memory write state
                    end
                end

                WRITE_MEM: begin
                    // Write the 32-bit data to internal memory
                    int_mem_addr <= result;   // Address determined by result
                    int_mem_data <= new_data; // Data fetched from external memory
                    int_mem_write <= 1'b1;    // Enable internal memory write
                    ready <= 1'b1;            // Indicate operation complete
                    state <= IDLE;            // Return to IDLE state
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Reset write signal after one cycle
    always_ff @(posedge clk) begin
        if (state != WRITE_MEM)
            int_mem_write <= 1'b0;
    end

endmodule