`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.08.2025 15:34:46
// Design Name: 
// Module Name: Initialisation_block
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module LPi_calculation(input wire [99:0]x_i,//noisy sifted key
                            input wire [3:0]qber,//global Qber ( one qber for all 100 bits)
                            output wire [1499:0]LPi, // 100 values , each of them are 15 bits (Q5.10)
                            output wire [99:0]sign //sign for each 100 values
                           );
    wire sign_inter[0:99];                      
    genvar i;
    generate
    for ( i =0 ; i<100 ; i=i+1)
        begin 
        Lookup_table_eq6 uut0(.xi(x_i[i*1 +: 1]) ,
                         .qber_sel(qber),
                         .L_Pi(LPi[i*15 +: 15]),
                         .sign(sign_inter[i]));
                         
        assign sign[i +: 1] = sign_inter[i];
        end
    endgenerate
                                                  
                           
endmodule
