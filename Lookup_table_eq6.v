`timescale 1ns / 1ps
// Lookup table for L(Pi) = ln((1 - abs(xi - qber)) / abs(xi - qber))
// Format: Q3.9 signed fixed-point (12 bits total)
// xi: 0 or 1 (1 bit), qber_sel: 0..10 for 0.01..0.11 (4 bits)

module Lookup_table_eq6 (
    input  wire       xi,          // 0 or 1
    input  wire [3:0] qber_sel,    // 0..10 representing 0.01..0.11
    output reg  [14:0] L_Pi, // q5.10
    output wire sign
);

always @(*) begin
    case ({xi, qber_sel})
        // xi = 0 (positive values)
        5'b0_0000: L_Pi = 15'h1261; // 4.59511985
        5'b0_0001: L_Pi = 15'h0F91; // 3.89182030
        5'b0_0010: L_Pi = 15'h0DE8; // 3.47609869
        5'b0_0011: L_Pi = 15'h0CB6; // 3.17805383      
        5'b0_0100: L_Pi = 15'h0BC7; // 2.94443898
        5'b0_0101: L_Pi = 15'h0B02; // 2.75153531
        5'b0_0110: L_Pi = 15'h0A59; // 2.58668934
        5'b0_0111: L_Pi = 15'h09C5; // 2.44234704
        5'b0_1000: L_Pi = 15'h0941; // 2.31363493
        5'b0_1001: L_Pi = 15'h08CA; // 2.19722458
        5'b0_1010: L_Pi = 15'h085D; // 2.09074110

        // xi = 1 (negative values in 2's complement, 15-bit)
        5'b1_0000: L_Pi = 15'h6D9F; // -4.59511985
        5'b1_0001: L_Pi = 15'h706F; // -3.89182030
        5'b1_0010: L_Pi = 15'h7218; // -3.47609869
        5'b1_0011: L_Pi = 15'h734A; // -3.17805383
        5'b1_0100: L_Pi = 15'h7439; // -2.94443898
        5'b1_0101: L_Pi = 15'h74FE; // -2.75153531
        5'b1_0110: L_Pi = 15'h75A7; // -2.58668934
        5'b1_0111: L_Pi = 15'h763B; // -2.44234704
        5'b1_1000: L_Pi = 15'h76BF; // -2.31363493
        5'b1_1001: L_Pi = 15'h7736; // -2.19722458
        5'b1_1010: L_Pi = 15'h77A3; // -2.09074110

        default: L_Pi = 15'd0;
    endcase
end
    assign sign = xi ;

endmodule
