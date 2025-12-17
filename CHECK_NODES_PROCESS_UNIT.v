`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 13.08.2025 19:59:01
// Design Name: 
// Module Name: CHECK_NODES_PROCESS_UNIT
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


module CHECK_NODES_PROCESS_UNIT (
                                 
                                 input wire             clk,rst,rd_en,wr_en,en,   
                                 input wire  [6399:0]sign_Qij_VNPU,    //simulation only
                                 output wire [6399:0]sign_Rji_out   );
                                 
                                 wire [1:0]alpha = 2'h3; //normalisation factor
                                 
                                 
                                 wire [3:0]  sign_VTC             [0:99];                                 
                                 wire [59:0] Qij                  [0:99];                 //15 bits * 4 qijs
                                 wire        sign_VTC_packed      [0:99][0:3];
                                 wire [14:0] Qij_packed           [0:99][0:3];
                                 
                                 wire [59:0] q_values             [0:79][0:4];
                                 wire [59:0] abs_q_values         [0:79][0:4];
                                 wire [3:0]  sign_inter           [0:79][0:4];
                                 
                                 wire [74:0] final_minimum        [0:79]; //15 bits * 5 rjis
                                 
                                 
                                 wire [4:0]  final_sign           [0:79]; 
                                 wire [74:0] Rji                  [0:79]; // each J will have 5 R values eg: R[j,0] , [j,1]...... [j,4]
                                 wire [79:0] sign_Rji             [0:79]; // 75 bits ( each 15 bits ) for 5 rjis + 5 sign

                               
                                 wire [63:0]sign_Qij_packed       [0:99];
                                 genvar O;genvar P;
                                 generate
                                    for(O=0 ; O<100;O=O+1)
                                        begin
                                              assign sign_Qij_packed[O]   =  sign_Qij_VNPU[O*64 +: 64];                          
                                              assign Qij[O]               =  sign_Qij_packed[O][59:0];
                                              assign sign_VTC[O]          =  sign_Qij_packed[O][63:60];
                                        for(P=0 ; P<4 ; P=P+1)
                                            begin
                                                assign Qij_packed[O][P]      =  Qij[O][(3-P)*15 +: 15]; // unpacking
                                                assign sign_VTC_packed[O][P] = sign_VTC[O][(3-P) +: 1];
                                            end
                                                                               
                                        end
                                 endgenerate
                                 
				//Obtaining positions of the 1's

                                 wire [71:0] dout_posT [0:99]; // 5 1's per row each 8 bits wide i.e 40 and 4 1's per column i.e 32 totaling 72 bits
                                 wire [31:0] row_pos   [0:99]; //4 1's per col each 8 bits i.e 32 bits
                                 wire [39:0] col_pos   [0:79]; // 5 1's per row i.e 40 bits
                                 
                                 genvar i;
                                 generate
                                    for(i=0;i<100;i=i+1)  // Obtaining the positions from the BRAM 
                                        begin
                                            positionsrowcol bram1  (  
                                                                        .clka(clk),            // input clock
                                                                        .wea(1'b0),            // write enable
                                                                        .addra(i),             // address
                                                                        .dina(32'b0),          // data in
                                                                        .douta(dout_posT[i]));
                                                                        
                                            assign row_pos[i]=dout_posT[i][71:40]; 
                                        end
                                 endgenerate 

                                 wire [7:0]unpacked_row_pos[0:99][0:3];
                                 genvar w;
                                 generate
                                    for(w=0;w<100;w=w+1)
                                        begin
                                            assign unpacked_row_pos[w][0] = row_pos[w][31:24];
                                            assign unpacked_row_pos[w][1] = row_pos[w][23:16];
                                            assign unpacked_row_pos[w][2] = row_pos[w][15:8];
                                            assign unpacked_row_pos[w][3] = row_pos[w][7:0];
                                        end
                                 endgenerate
                                            
                                 wire [31:0]deleted[0:79][0:4]; // 8 bit each and 4 values to be fed
                                 genvar j;genvar k;
                                 generate 
                                    for(j=0;j<80;j=j+1) // there are 80 columns in H (transpose) , Each column has 5 1's
                                        begin:delete_idash
                                        
                                            assign col_pos[j]         =       dout_posT[j][39:0];      // takes the 5 1's positions 
                                            wire [39:0]bram_out_inter =       col_pos[j];              //8 bit each and there are 5 values (8*5)
                                            wire [7:0]pos5            =       bram_out_inter[7:0];
                                            wire [7:0]pos4            =       bram_out_inter[15:8];
                                            wire [7:0]pos3            =       bram_out_inter[23:16];
                                            wire [7:0]pos2            =	      bram_out_inter[31:24];
                                            wire [7:0]pos1            =       bram_out_inter[39:32];

                                            for(k=0;k<5;k=k+1) //Rji (j,0) ; (j,1) ; (j,2) ; (j,3) ; (j,4)
                                                begin:delete                                               
                                                    assign deleted[j][k] =  (k==0)? {pos2,pos3,pos4,pos5}:
                                                                            (k==1)? {pos1,pos3,pos4,pos5}: 
                                                                            (k==2)? {pos1,pos2,pos4,pos5}:
                                                                            (k==3)? {pos1,pos2,pos3,pos5}: {pos1,pos2,pos3,pos4} ;
                                                end
                                    end
                                endgenerate
                                
                                 genvar l,p;
                                 generate 
                                    for(l=0;l<80;l=l+1) 
                                        begin:Taking_Q  // the deleted variable stores the positions of the Q values , this for loop takes that particular Q value and the sign from the positions provided by deleted
                                       
                                            
                                        
                                            assign q_values     [l][0] = { Qij_packed[deleted[l][0][31:24]][l==unpacked_row_pos[deleted[l][0][31:24]][0]? 0 :
                                                                                                            l==unpacked_row_pos[deleted[l][0][31:24]][1]? 1 :
                                                                                                            l==unpacked_row_pos[deleted[l][0][31:24]][2]? 2 :
                                                                                                                                                          3], 
                                                                                                           
                                                                           Qij_packed[deleted[l][0][23:16]][l==unpacked_row_pos[deleted[l][0][23:16]][0]? 0 :
                                                                                                            l==unpacked_row_pos[deleted[l][0][23:16]][1]? 1 :
                                                                                                            l==unpacked_row_pos[deleted[l][0][23:16]][2]? 2 :
                                                                                                                                                          3] , 
                                                                                                           
                                                                           Qij_packed[deleted[l][0][15:8]] [l==unpacked_row_pos[deleted[l][0][15:8]][0]? 0 :
                                                                                                            l==unpacked_row_pos[deleted[l][0][15:8]][1]? 1 :
                                                                                                            l==unpacked_row_pos[deleted[l][0][15:8]][2]? 2 :
                                                                                                                                                        3] , 
                                                                                                           
                                                                           Qij_packed[deleted[l][0][7:0]]  [l==unpacked_row_pos[deleted[l][0][7:0]][0]? 0 :
                                                                                                            l==unpacked_row_pos[deleted[l][0][7:0]][1]? 1 :
                                                                                                            l==unpacked_row_pos[deleted[l][0][7:0]][2]? 2 :
                                                                                                                                                               3] };
                                            assign sign_inter   [l][0] = {sign_VTC_packed[deleted[l][0][31:24]]  [l==unpacked_row_pos[deleted[l][0][31:24]][0]? 0 :
                                                                                                                l==unpacked_row_pos[deleted[l][0][31:24]][1]? 1 :
                                                                                                                l==unpacked_row_pos[deleted[l][0][31:24]][2]? 2 :
                                                                                                                                                            3] , 
                                                                          sign_VTC_packed[deleted[l][0][23:16]] [l==unpacked_row_pos[deleted[l][0][23:16]][0]? 0 :
                                                                                                                l==unpacked_row_pos[deleted[l][0][23:16]][1]? 1 :
                                                                                                                l==unpacked_row_pos[deleted[l][0][23:16]][2]? 2 :
                                                                                                                                                             3] , 
                                                                          sign_VTC_packed[deleted[l][0][15:8]][l==unpacked_row_pos[deleted[l][0][15:8]][0]? 0 :
                                                                                                                l==unpacked_row_pos[deleted[l][0][15:8]][1]? 1 :
                                                                                                                l==unpacked_row_pos[deleted[l][0][15:8]][2]? 2 :
                                                                                                                                                             3] , 
                                                                          sign_VTC_packed[deleted[l][0][7:0]][l==unpacked_row_pos[deleted[l][0][7:0]][0]? 0 :
                                                                                                                l==unpacked_row_pos[deleted[l][0][7:0]][1]? 1 :
                                                                                                                l==unpacked_row_pos[deleted[l][0][7:0]][2]? 2 :
                                                                                                                                                              3] };
                                                                                                           
                                                                                                           
                                                                                                           
                                            assign q_values     [l][1] = { Qij_packed[deleted[l][1][31:24]][l==unpacked_row_pos[deleted[l][1][31:24]][0]? 0 :
                                                                                                            l==unpacked_row_pos[deleted[l][1][31:24]][1]? 1 :
                                                                                                            l==unpacked_row_pos[deleted[l][1][31:24]][2]? 2 :
                                                                                                                                                          3], 
                                                                                                           
                                                                           Qij_packed[deleted[l][1][23:16]][l==unpacked_row_pos[deleted[l][1][23:16]][0]? 0 :
                                                                                                            l==unpacked_row_pos[deleted[l][1][23:16]][1]? 1 :
                                                                                                            l==unpacked_row_pos[deleted[l][1][23:16]][2]? 2 :
                                                                                                                                                          3] , 
                                                                                                           
                                                                           Qij_packed[deleted[l][1][15:8]] [l==unpacked_row_pos[deleted[l][1][15:8]][0]? 0 :
                                                                                                            l==unpacked_row_pos[deleted[l][1][15:8]][1]? 1 :
                                                                                                            l==unpacked_row_pos[deleted[l][1][15:8]][2]? 2 :
                                                                                                                                                        3] , 
                                                                                                           
                                                                           Qij_packed[deleted[l][1][7:0]]  [l==unpacked_row_pos[deleted[l][1][7:0]][0]? 0 :
                                                                                                            l==unpacked_row_pos[deleted[l][1][7:0]][1]? 1 :
                                                                                                            l==unpacked_row_pos[deleted[l][1][7:0]][2]? 2 :
                                                                                                                                                       3] };
                                            assign sign_inter   [l][1] = {sign_VTC_packed[deleted[l][1][31:24]]  [l==unpacked_row_pos[deleted[l][1][31:24]][0]? 0 :
                                                                                                                  l==unpacked_row_pos[deleted[l][1][31:24]][1]? 1 :
                                                                                                                  l==unpacked_row_pos[deleted[l][1][31:24]][2]? 2 :
                                                                                                                                                                3] , 
                                                                          sign_VTC_packed[deleted[l][1][23:16]]  [l==unpacked_row_pos[deleted[l][1][23:16]][0]? 0 :
                                                                                                                  l==unpacked_row_pos[deleted[l][1][23:16]][1]? 1 :
                                                                                                                  l==unpacked_row_pos[deleted[l][1][23:16]][2]? 2 :
                                                                                                                                                                3] , 
                                                                          sign_VTC_packed[deleted[l][1][15:8]]   [l==unpacked_row_pos[deleted[l][1][15:8]][0]? 0 :
                                                                                                                  l==unpacked_row_pos[deleted[l][1][15:8]][1]? 1 :
                                                                                                                  l==unpacked_row_pos[deleted[l][1][15:8]][2]? 2 :
                                                                                                                                                                3] , 
                                                                          sign_VTC_packed[deleted[l][1][7:0]]  [l==unpacked_row_pos[deleted[l][1][7:0]][0]? 0 :
                                                                                                                  l==unpacked_row_pos[deleted[l][1][7:0]][1]? 1 :
                                                                                                                  l==unpacked_row_pos[deleted[l][1][7:0]][2]? 2 :
                                                                                                                                                                3] };
                                                                                                                                                                
                                                                                                                                                                
                                                                                                                                                                
                                            
                                            assign q_values     [l][2] = { Qij_packed[deleted[l][2][31:24]][l==unpacked_row_pos[deleted[l][2][31:24]][0]? 0 :
                                                                                                            l==unpacked_row_pos[deleted[l][2][31:24]][1]? 1 :
                                                                                                            l==unpacked_row_pos[deleted[l][2][31:24]][2]? 2 :
                                                                                                                                                          3], 
                                                                                                           
                                                                           Qij_packed[deleted[l][2][23:16]][l==unpacked_row_pos[deleted[l][2][23:16]][0]? 0 :
                                                                                                            l==unpacked_row_pos[deleted[l][2][23:16]][1]? 1 :
                                                                                                            l==unpacked_row_pos[deleted[l][2][23:16]][2]? 2 :
                                                                                                                                                          3] , 
                                                                                                           
                                                                           Qij_packed[deleted[l][2][15:8]] [l==unpacked_row_pos[deleted[l][2][15:8]][0]? 0 :
                                                                                                            l==unpacked_row_pos[deleted[l][2][15:8]][1]? 1 :
                                                                                                            l==unpacked_row_pos[deleted[l][2][15:8]][2]? 2 :
                                                                                                                                                        3] , 
                                                                                                           
                                                                           Qij_packed[deleted[l][2][7:0]]  [l==unpacked_row_pos[deleted[l][2][7:0]][0]? 0 :
                                                                                                            l==unpacked_row_pos[deleted[l][2][7:0]][1]? 1 :
                                                                                                            l==unpacked_row_pos[deleted[l][2][7:0]][2]? 2 :
                                                                                                                                                       3] };
                                            assign sign_inter   [l][2] = {sign_VTC_packed[deleted[l][2][31:24]]  [l==unpacked_row_pos[deleted[l][2][31:24]][0]? 0 :
                                                                                                                  l==unpacked_row_pos[deleted[l][2][31:24]][1]? 1 :
                                                                                                                  l==unpacked_row_pos[deleted[l][2][31:24]][2]? 2 :
                                                                                                                                                                3] , 
                                                                          sign_VTC_packed[deleted[l][2][23:16]]  [l==unpacked_row_pos[deleted[l][2][23:16]][0]? 0 :
                                                                                                                  l==unpacked_row_pos[deleted[l][2][23:16]][1]? 1 :
                                                                                                                  l==unpacked_row_pos[deleted[l][2][23:16]][2]? 2 :
                                                                                                                                                                3] , 
                                                                          sign_VTC_packed[deleted[l][2][15:8]]   [l==unpacked_row_pos[deleted[l][2][15:8]][0]? 0 :
                                                                                                                  l==unpacked_row_pos[deleted[l][2][15:8]][1]? 1 :
                                                                                                                  l==unpacked_row_pos[deleted[l][2][15:8]][2]? 2 :
                                                                                                                                                                3] , 
                                                                          sign_VTC_packed[deleted[l][2][7:0]]    [l==unpacked_row_pos[deleted[l][2][7:0]][0]? 0 :
                                                                                                                  l==unpacked_row_pos[deleted[l][2][7:0]][1]? 1 :
                                                                                                                  l==unpacked_row_pos[deleted[l][2][7:0]][2]? 2 :
                                                                                                                                                                3] };
                                            
                                            assign q_values     [l][3] = { Qij_packed[deleted[l][3][31:24]][l==unpacked_row_pos[deleted[l][3][31:24]][0]? 0 :
                                                                                                            l==unpacked_row_pos[deleted[l][3][31:24]][1]? 1 :
                                                                                                            l==unpacked_row_pos[deleted[l][3][31:24]][2]? 2 :
                                                                                                                                                          3], 
                                                                                                           
                                                                           Qij_packed[deleted[l][3][23:16]][l==unpacked_row_pos[deleted[l][3][23:16]][0]? 0 :
                                                                                                            l==unpacked_row_pos[deleted[l][3][23:16]][1]? 1 :
                                                                                                            l==unpacked_row_pos[deleted[l][3][23:16]][2]? 2 :
                                                                                                                                                          3] , 
                                                                                                           
                                                                           Qij_packed[deleted[l][3][15:8]] [l==unpacked_row_pos[deleted[l][3][15:8]][0]? 0 :
                                                                                                            l==unpacked_row_pos[deleted[l][3][15:8]][1]? 1 :
                                                                                                            l==unpacked_row_pos[deleted[l][3][15:8]][2]? 2 :
                                                                                                                                                        3] , 
                                                                                                           
                                                                           Qij_packed[deleted[l][3][7:0]]  [l==unpacked_row_pos[deleted[l][3][7:0]][0]? 0 :
                                                                                                            l==unpacked_row_pos[deleted[l][3][7:0]][1]? 1 :
                                                                                                            l==unpacked_row_pos[deleted[l][3][7:0]][2]? 2 :
                                                                                                                                                       3] };
                                            assign sign_inter   [l][3] = {sign_VTC_packed[deleted[l][3][31:24]]  [l==unpacked_row_pos[deleted[l][3][31:24]][0]? 0 :
                                                                                                                  l==unpacked_row_pos[deleted[l][3][31:24]][1]? 1 :
                                                                                                                  l==unpacked_row_pos[deleted[l][3][31:24]][2]? 2 :
                                                                                                                                                                3] , 
                                                                          sign_VTC_packed[deleted[l][3][23:16]]  [l==unpacked_row_pos[deleted[l][3][23:16]][0]? 0 :
                                                                                                                  l==unpacked_row_pos[deleted[l][3][23:16]][1]? 1 :
                                                                                                                  l==unpacked_row_pos[deleted[l][3][23:16]][2]? 2 :
                                                                                                                                                                3] , 
                                                                          sign_VTC_packed[deleted[l][3][15:8]]   [l==unpacked_row_pos[deleted[l][3][15:8]][0]? 0 :
                                                                                                                  l==unpacked_row_pos[deleted[l][3][15:8]][1]? 1 :
                                                                                                                  l==unpacked_row_pos[deleted[l][3][15:8]][2]? 2 :
                                                                                                                                                                3] , 
                                                                          sign_VTC_packed[deleted[l][3][7:0]]    [l==unpacked_row_pos[deleted[l][3][7:0]][0]? 0 :
                                                                                                                  l==unpacked_row_pos[deleted[l][3][7:0]][1]? 1 :
                                                                                                                  l==unpacked_row_pos[deleted[l][3][7:0]][2]? 2 :
                                                                                                                                                                3] };
                                            
                                            assign q_values     [l][4] = { Qij_packed[deleted[l][4][31:24]][l==unpacked_row_pos[deleted[l][4][31:24]][0]? 0 :
                                                                                                            l==unpacked_row_pos[deleted[l][4][31:24]][1]? 1 :
                                                                                                            l==unpacked_row_pos[deleted[l][4][31:24]][2]? 2 :
                                                                                                                                                          3], 
                                                                                                           
                                                                           Qij_packed[deleted[l][4][23:16]][l==unpacked_row_pos[deleted[l][4][23:16]][0]? 0 :
                                                                                                            l==unpacked_row_pos[deleted[l][4][23:16]][1]? 1 :
                                                                                                            l==unpacked_row_pos[deleted[l][4][23:16]][2]? 2 :
                                                                                                                                                          3] , 
                                                                                                           
                                                                           Qij_packed[deleted[l][4][15:8]] [l==unpacked_row_pos[deleted[l][4][15:8]][0]? 0 :
                                                                                                            l==unpacked_row_pos[deleted[l][4][15:8]][1]? 1 :
                                                                                                            l==unpacked_row_pos[deleted[l][4][15:8]][2]? 2 :
                                                                                                                                                        3] , 
                                                                                                           
                                                                           Qij_packed[deleted[l][4][7:0]]  [l==unpacked_row_pos[deleted[l][4][7:0]][0]? 0 :
                                                                                                            l==unpacked_row_pos[deleted[l][4][7:0]][1]? 1 :
                                                                                                            l==unpacked_row_pos[deleted[l][4][7:0]][2]? 2 :
                                                                                                                                                       3] };
                                            assign sign_inter   [l][4] = {sign_VTC_packed[deleted[l][4][31:24]]  [l==unpacked_row_pos[deleted[l][4][31:24]][0]? 0 :
                                                                                                                  l==unpacked_row_pos[deleted[l][4][31:24]][1]? 1 :
                                                                                                                  l==unpacked_row_pos[deleted[l][4][31:24]][2]? 2 :
                                                                                                                                                                3] , 
                                                                          sign_VTC_packed[deleted[l][4][23:16]]  [l==unpacked_row_pos[deleted[l][4][23:16]][0]? 0 :
                                                                                                                  l==unpacked_row_pos[deleted[l][4][23:16]][1]? 1 :
                                                                                                                  l==unpacked_row_pos[deleted[l][4][23:16]][2]? 2 :
                                                                                                                                                                3] , 
                                                                          sign_VTC_packed[deleted[l][4][15:8]]   [l==unpacked_row_pos[deleted[l][4][15:8]][0]? 0 :
                                                                                                                  l==unpacked_row_pos[deleted[l][4][15:8]][1]? 1 :
                                                                                                                  l==unpacked_row_pos[deleted[l][4][15:8]][2]? 2 :
                                                                                                                                                                3] , 
                                                                          sign_VTC_packed[deleted[l][4][7:0]]    [l==unpacked_row_pos[deleted[l][4][7:0]][0]? 0 :
                                                                                                                  l==unpacked_row_pos[deleted[l][4][7:0]][1]? 1 :
                                                                                                                  l==unpacked_row_pos[deleted[l][4][7:0]][2]? 2 :
                                                                                                                                                                3] };
                                            
                                            
                                              
                                            assign abs_q_values   [l][0] = {sign_inter[l][0][3] ? (~(q_values[l][0][59:45]) + 15'd1) : q_values[l][0][59:45] ,   
                                                                            sign_inter[l][0][2] ? (~(q_values[l][0][44:30]) + 15'd1) : q_values[l][0][44:30] ,
                                                                            sign_inter[l][0][1] ? (~(q_values[l][0][29:15]) + 15'd1): q_values[l][0][29:15] ,
                                                                            sign_inter[l][0][0] ? (~(q_values[l][0][14:0])  + 15'd1): q_values[l][0][14: 0] };
                                            
                                            assign abs_q_values   [l][1] = {sign_inter[l][1][3] ? (~(q_values[l][1][59:45]) + 15'd1) : q_values[l][1][59:45] ,   
                                                                            sign_inter[l][1][2] ? (~(q_values[l][1][44:30]) + 15'd1) : q_values[l][1][44:30] ,
                                                                            sign_inter[l][1][1] ? (~(q_values[l][1][29:15]) + 15'd1) : q_values[l][1][29:15] ,
                                                                            sign_inter[l][1][0] ? (~(q_values[l][1][14:0])  + 15'd1) : q_values[l][1][14:0] };
                                            
                                            assign abs_q_values   [l][2] = {sign_inter[l][2][3] ? (~(q_values[l][2][59:45]) + 15'd1) : q_values[l][2][59:45] ,   
                                                                            sign_inter[l][2][2] ? (~(q_values[l][2][44:30]) + 15'd1) : q_values[l][2][44:30] ,
                                                                            sign_inter[l][2][1] ? (~(q_values[l][2][29:15]) + 15'd1) : q_values[l][2][29:15] ,
                                                                            sign_inter[l][2][0] ? (~(q_values[l][2][14:0])  + 15'd1) : q_values[l][2][14:0] };
                                            
                                            assign abs_q_values   [l][3] = {sign_inter[l][3][3] ? (~(q_values[l][3][59:45]) + 15'd1) : q_values[l][3][59:45] ,   
                                                                            sign_inter[l][3][2] ? (~(q_values[l][3][44:30]) + 15'd1) : q_values[l][3][44:30] ,
                                                                            sign_inter[l][3][1] ? (~(q_values[l][3][29:15]) + 15'd1) : q_values[l][3][29:15] ,
                                                                            sign_inter[l][3][0] ? (~(q_values[l][3][14:0])  + 15'd1) : q_values[l][3][14:0] };
                                           
                                            assign abs_q_values   [l][4] = {sign_inter[l][4][3] ? (~(q_values[l][4][59:45]) + 15'd1) : q_values[l][4][59:45] ,   
                                                                            sign_inter[l][4][2] ? (~(q_values[l][4][44:30]) + 15'd1) : q_values[l][4][44:30] ,
                                                                            sign_inter[l][4][1] ? (~(q_values[l][4][29:15]) + 15'd1) : q_values[l][4][29:15] ,
                                                                            sign_inter[l][4][0] ? (~(q_values[l][4][14:0])  + 15'd1) : q_values[l][4][14:0] };
                                        end
                                  endgenerate
                                        
                          
                                genvar m; genvar n;
                                generate 
                                
                                
                                    for(m=0;m<80;m=m+1)  // min(abs(q)) given in paper
                                        begin:finding_min
                                            wire [14:0] temp0 [0:3] ; wire [14:0] temp1 [0:3] ; wire [14:0] temp2 [0:3] ; wire [14:0] temp3 [0:3] ; wire [14:0] temp4 [0:3] ;
                                            wire sign0       ; wire sign1              ; wire sign2              ; wire sign3              ; wire sign4              ;
                                            wire [14:0] Rji0_abs , Rji1_abs , Rji2_abs , Rji3_abs , Rji4_abs;
                                            wire [14:0]     Rji0 ,     Rji1 ,     Rji2 ,     Rji3 ,    Rji4 ;                                            
                                            assign temp0[0] = abs_q_values[m][0][14:0];
                                            assign temp1[0] = abs_q_values[m][1][14:0];
                                            assign temp2[0] = abs_q_values[m][2][14:0];
                                            assign temp3[0] = abs_q_values[m][3][14:0];
                                            assign temp4[0] = abs_q_values[m][4][14:0];
                                            for(n=1 ; n<4 ; n=n+1)
                                                begin 
                                                    assign temp0[n] = (temp0[n-1] < abs_q_values[m][0][n*15 +: 15]  ? temp0[n-1] : abs_q_values[m][0][n*15 +: 15]);
                                                    assign temp1[n] = (temp1[n-1] < abs_q_values[m][1][n*15 +: 15]  ? temp1[n-1] : abs_q_values[m][1][n*15 +: 15]);
                                                    assign temp2[n] = (temp2[n-1] < abs_q_values[m][2][n*15 +: 15]  ? temp2[n-1] : abs_q_values[m][2][n*15 +: 15]);
                                                    assign temp3[n] = (temp3[n-1] < abs_q_values[m][3][n*15 +: 15]  ? temp3[n-1] : abs_q_values[m][3][n*15 +: 15]);
                                                    assign temp4[n] = (temp4[n-1] < abs_q_values[m][4][n*15 +: 15]  ? temp4[n-1] : abs_q_values[m][4][n*15 +: 15]);
                                                end
                                            assign final_minimum[m] = { temp0[3] , temp1[3] , temp2[3] , temp3[3] , temp4[3] };
                                           
                                            assign sign0 = (sign_inter[m][0][0] ^ sign_inter[m][0][1] ^ sign_inter[m][0][2] ^ sign_inter[m][0][3]); //sgn function
                                            assign sign1 = (sign_inter[m][1][0] ^ sign_inter[m][1][1] ^ sign_inter[m][1][2] ^ sign_inter[m][1][3]);
                                            assign sign2 = (sign_inter[m][2][0] ^ sign_inter[m][2][1] ^ sign_inter[m][2][2] ^ sign_inter[m][2][3]);
                                            assign sign3 = (sign_inter[m][3][0] ^ sign_inter[m][3][1] ^ sign_inter[m][3][2] ^ sign_inter[m][3][3]);
                                            assign sign4 = (sign_inter[m][4][0] ^ sign_inter[m][4][1] ^ sign_inter[m][4][2] ^ sign_inter[m][4][3]);
                                            
                                            assign final_sign[m] = { sign0 , sign1 , sign2 , sign3 , sign4 };
                                            
                                            assign Rji0_abs = ((alpha * final_minimum[m][74:60]) +  2) >> 2;
                                            assign Rji1_abs = ((alpha * final_minimum[m][59:45]) +  2) >> 2;
                                            assign Rji2_abs = ((alpha * final_minimum[m][44:30]) +  2) >> 2;
                                            assign Rji3_abs = ((alpha * final_minimum[m][29:15]) +  2) >> 2;
                                            assign Rji4_abs = ((alpha * final_minimum[m][14:0])  +  2) >> 2;
                                            
                                            
                                            assign Rji0 = sign0? ~(Rji0_abs) + 1 : Rji0_abs ;
                                            assign Rji1 = sign1? ~(Rji1_abs) + 1 : Rji1_abs ;
                                            assign Rji2 = sign2? ~(Rji2_abs) + 1 : Rji2_abs ;
                                            assign Rji3 = sign3? ~(Rji3_abs) + 1 : Rji3_abs ;
                                            assign Rji4 = sign4? ~(Rji4_abs) + 1 : Rji4_abs ;
                                            
                                            assign Rji[m] = { (Rji0 > 16'd32767 )?16'd32767:Rji0[14:0] , (Rji1 > 16'd32767)?16'd32767:Rji1[14:0] , (Rji2 > 16'd32767)?16'd32767:Rji2[14:0] , (Rji3 > 16'd32767)?16'd32767:Rji3[14:0] , (Rji4 > 16'd32767)?16'd32767:Rji4[14:0] }; // We will have 400 R's as there are 400 1's in the ldpc matrix ( 80*5)   
                                            
                                            
                                            assign sign_Rji[m] = {final_sign[m] , Rji[m] };
                                            
                                            assign sign_Rji_out[m*80 +: 80] = sign_Rji[m]; // 5 Rjis each 15 bit , 5 sign bit so 15*5 + 5
                                                                                                                                                               
                                   end      
                                                                       
                                endgenerate
                                                                          
endmodule
