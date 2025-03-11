module ArrayBarrelShifter
    #(parameter N = 4, parameter WL=16)
    (
    select,
    D,
    Q);
// Created by JW Park on Sep. 23, 2019
// This is a synthesizable combinational array barrel shifter implementation.
// The size of the array is N, and the width of each element is WL.
// The input D is indexed with WL, N, and the output Q is indexed with WL, N.
// The "select" value is used to select the amount of shift.
// When select = 1, the array is shifted by 1, and when select = 2, the array is shifted by 2, and so on.
localparam W = $clog2(N); // width for shifting
input [W-1:0] select;
input [N*WL-1:0] D;    // Indexed with WORD_LENGTH, N
output reg [N*WL-1:0] Q;   // Indexed with WORD_LENGTH, N
wire [WL-1:0] D_ARRAY [0:N-1];  // Unlooped D array
wire [WL-1:0] Q_ARRAY [0:N-1];  // Unlooped Q array
integer i;
integer j;
// Assign D_ARRAY with D
genvar n;
generate
for (n=0; n<N; n=n+1) begin : D_ASSIGN
    assign D_ARRAY[n] = D[WL*(n+1)-1:WL*n];
end
endgenerate
// Generate barrel shifters
genvar w;
genvar d;
generate
for (w=0; w<WL; w=w+1) begin : BSHIFT_GEN
    wire [N-1:0] d_line;
    wire [N-1:0] q_line;
    for (d=0; d<N; d=d+1) begin : DLINE_GEN
        assign d_line[d] = D_ARRAY[d][w];
        assign Q_ARRAY[d][w] = q_line[d];
    end
    BarrelShifter #(.N(N)) U0 (.d(d_line), .select(select), .q(q_line));
end
endgenerate
always @(*) begin
    for (i=0; i<N; i=i+1) begin
        for (j=0; j<WL; j=j+1) begin
            Q[WL*i+j] = Q_ARRAY[i][j];
        end
    end
end
endmodule

module BarrelShifter
#(parameter N=8)
(
    d,
    select,
    q
);
// An synthesizable combinational logic N-Bit barrel shifter implementation.
// synopsys template
localparam W = $clog2(N);
input [N-1:0] d;
input [W-1:0] select;
output [N-1:0] q;
wire [N-1:0] INTERNAL [0:W];
assign INTERNAL[0] = d;
// STAGED OUTPUTS
genvar stage;
generate
for (stage=0; stage<W; stage=stage+1) begin : STAGED_OUTPUTS
    localparam n_shift = 1 << stage ;
    //localparam n_shift = 1 >> stage ;
    wire [N+n_shift-1:0] SHIFTED;
    assign SHIFTED = (INTERNAL[stage] << n_shift) ;
    //assign SHIFTED = (INTERNAL[stage] >> n_shift) ;
    assign INTERNAL[stage+1] = select[stage] ? {SHIFTED[N-1 : n_shift], SHIFTED[N+n_shift-1:N]} : INTERNAL[stage] ;
end
endgenerate
assign q = INTERNAL[W];
endmodule