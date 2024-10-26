module Gradient_merge_unit#()

(



);
endmodule


// module merge_lists (
//     input            clk,
//     input            rst_n,
//     input  [15:0][3:0] list1_id,     // List 1 IDs (16x4-bit IDs)
//     input  [15:0][7:0] list1_value,  // List 1 values (16x8-bit values)
//     input  [15:0][3:0] list2_id,     // List 2 IDs (16x4-bit IDs)
//     input  [15:0][7:0] list2_value,  // List 2 values (16x8-bit values)
//     output reg [15:0][3:0] result_id,    // Merged List IDs (16x4-bit IDs)
//     output reg [15:0][7:0] result_value  // Merged List values (16x8-bit values)
// );

//     reg [15:0][7:0] merge_storage; // Temporary storage to hold accumulated values
//     reg [15:0]      id_seen;       // Bitmask to track unique IDs
//     integer i, j;

//     // Merging Lists Logic
//     always @(posedge clk or negedge rst_n) begin
//         if (!rst_n) begin
//             // Reset storage and tracking variables
//             merge_storage <= 0;
//             id_seen       <= 0;
//             result_id     <= 0;
//             result_value  <= 0;
//         end else begin
//             // First, add entries from List 1 to merge storage
//             for (i = 0; i < 16; i = i + 1) begin
//                 if (!id_seen[list1_id[i]]) begin
//                     // Unique ID, add it to the result
//                     id_seen[list1_id[i]] <= 1'b1;
//                     merge_storage[list1_id[i]] <= list1_value[i];
//                 end
//                 else begin
//                     // If ID already exists in storage, add values
//                     merge_storage[list1_id[i]] <= merge_storage[list1_id[i]] + list1_value[i];
//                 end
//             end

//             // Now, add entries from List 2 to merge storage
//             for (j = 0; j < 16; j = j + 1) begin
//                 if (!id_seen[list2_id[j]]) begin
//                     // Unique ID, add it to the result
//                     id_seen[list2_id[j]] <= 1'b1;
//                     merge_storage[list2_id[j]] <= list2_value[j];
//                 end
//                 else begin
//                     // If ID already exists in storage, add values
//                     merge_storage[list2_id[j]] <= merge_storage[list2_id[j]] + list2_value[j];
//                 end
//             end

//             // Populate result lists with the merged values
//             for (i = 0; i < 16; i = i + 1) begin
//                 if (id_seen[i]) begin
//                     result_id[i] <= i[3:0];  // Set result ID
//                     result_value[i] <= merge_storage[i]; // Set result value
//                 end else begin
//                     result_id[i] <= 4'b0000;
//                     result_value[i] <= 8'b0;
//                 end
//             end
//         end
//     end
// endmodule

