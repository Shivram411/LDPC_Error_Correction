`timescale 1ns / 1ps

module VARIABLE_NODES_PROCESSING_UNIT ( input wire  [99:0]x_i_VNPU,
                                        input wire  [3:0]qber_VNPU,
                                        input wire  clk,
                                        input wire  rst,
                                        input wire  en,
                                        input wire  [7:0]iteration_num,
                                        input wire  [6399:0]sign_Rji_CNPU,
                                        output wire [6399:0]sign_Qij 
                                       );
                                                                                                                                                     
                                       wire [14:0]   Rji_VNPU_packed [0:79][0:4];
                                       wire [1499:0] LPi_VNPU ;                     // to take LPi values from the Lpi module
                                       wire [59:0]   Qij_LPi         [0:99];        // to store the duplicated LPi values ( Here its 4 values because each column has same LPi) 
                                       wire [99:0]   sign_init;                                      
                                       wire [59:0]   Qij_out         [0:99];        // to send to V to C bram
                                       wire [3:0]    sign_out        [0:99];
                                       wire [63:0]   sign_Qij_out    [0:99];                                                                                                            
                                       wire [14:0]   QijL            [0:99][0:3];   // (original size 15 bits)
                                       wire          signL           [0:99][0:3];                                   
                                       wire [59:0]   Qij_CTV         [0:99];
                                       wire [3:0]    sign_CTV        [0:99];                                       
                                       wire [3:0]    sign_LPi        [0:99];
                                       wire          sign_VNPU_packed[0:79][0:4];
                                       
                                       wire [79:0]   sign_Rji_packed [0:79];  // 5 Rji values each 5.10 + 5 sign   75 +5 =80              
                                       wire [74:0]   Rji_VNPU        [0:79]; // to take R values from C to V bram     
                                       wire [4:0]    sign_VNPU       [0:79];
                                       
                                       LPi_calculation uut3 ( .x_i(x_i_VNPU),
                                                              .qber(qber_VNPU),
                                                              .LPi(LPi_VNPU),
                                                              .sign(sign_init) );
                                      
                                      
                                                   
                                       genvar i;
                                       generate
                                            for(i=0 ; i<80 ; i=i+1 )
                                                begin
                                                        assign sign_Rji_packed[i] = sign_Rji_CNPU[i*80 +: 80];
                                                        assign Rji_VNPU[i] =  sign_Rji_packed[i][74:0];
                                                        assign sign_VNPU[i] = sign_Rji_packed[i][79:75];

                                                        // Packing each 5 Rji's per m into arrays

                                                        assign Rji_VNPU_packed[i][0] = Rji_VNPU [i][74:60];   assign sign_VNPU_packed[i][0] = sign_VNPU[i][4];
                                                        assign Rji_VNPU_packed[i][1] = Rji_VNPU [i][59:45];   assign sign_VNPU_packed[i][1] = sign_VNPU[i][3];
                                                        assign Rji_VNPU_packed[i][2] = Rji_VNPU [i][44:30];   assign sign_VNPU_packed[i][2] = sign_VNPU[i][2];
                                                        assign Rji_VNPU_packed[i][3] = Rji_VNPU [i][29:15];   assign sign_VNPU_packed[i][3] = sign_VNPU[i][1];
                                                        assign Rji_VNPU_packed[i][4] = Rji_VNPU [i][14:0];    assign sign_VNPU_packed[i][4] = sign_VNPU[i][0];
                                                                                                                  
                                                 end
                                        endgenerate
                                        
                                        wire [71:0]dout_pos [0:99] ; //store the positions of row and column
                                        wire [39:0]col_pos [0:79]; // 5 1's per row i.e 40 bits
                                        genvar w;
                                        generate
                                            for(w=0;w<80;w=w+1)
                                            begin
                                                assign col_pos[w] = dout_pos[w][39:0];
                                            end
                                        endgenerate
                                        
                                        wire [7:0] unpacked_col_pos [0:79][0:4];
                                        genvar x;
                                        generate
                                            for(x=0;x<80;x=x+1)
                                            begin
                                                assign unpacked_col_pos[x][0] = col_pos[x][39:32];
                                                assign unpacked_col_pos[x][1] = col_pos[x][31:24];
                                                assign unpacked_col_pos[x][2] = col_pos[x][23:16];
                                                assign unpacked_col_pos[x][3] = col_pos[x][15:8];
                                                assign unpacked_col_pos[x][4] = col_pos[x][7:0];
                                            end
                                        endgenerate
                                                
                                        
                                        
                                        wire [31:0]row_pos [0:99]; //4 1's per col each 8 bits i.e 32
                                        
                                        genvar j,k,l,q;
                                        generate
                                            for(j=0;j<100;j=j+1)
                                            begin: parsing_H_position
                                                 positionsrowcol bram1       (  
                                                                        .clka(clk),            // input clock                                                                              
                                                                        .wea(1'b0),            // write enable
                                                                        .addra(j),             // address
                                                                        .dina(32'b0),          // data in
                                                                        .douta(dout_pos[j]));
                                                 assign  Qij_LPi[j] = { LPi_VNPU[j*15 +:15] , LPi_VNPU[j*15 +:15] , LPi_VNPU[j*15 +:15] , LPi_VNPU[j*15 +:15]};   
                                                 assign sign_LPi[j] = {sign_init[j +: 1] , sign_init[j +: 1] , sign_init[j +: 1] , sign_init[j +: 1] };                    
                                                 assign row_pos[j]=dout_pos[j][71:40];   // 4 1's per column hence 32 bits        
                                             end
                                             
                                         
                                              wire [23:0]deleted[0:99][0:3]; // each position is 8 bit wide , therefore 8*3
                                              for(k=0;k<100;k=k+1) //parsing column wise , hence 100 , we choose 3 out of 4 r's per column
                                                begin
                                                     wire [31:0]bram_out_inter = row_pos[k];
                                                     wire [7:0]pos1=bram_out_inter[31:24]; // 0th position
                                                     wire [7:0]pos2=bram_out_inter[23:16]; //1st position
                                                     wire [7:0]pos3=bram_out_inter[15:8];  // 2nd pos                                                   
                                                     wire [7:0]pos4=bram_out_inter[7:0];
                                                     for (q=0;q<4;q=q+1)                                                   
                                                     begin
                                                        assign deleted[k][q] =  (q==0)?{pos2 , pos3 , pos4} :
                                                                                (q==1)?{pos1 , pos3 , pos4} :
                                                                                (q==2)?{pos1 , pos2 , pos4} :
                                                                                       {pos1 , pos2 , pos3} ;
                                                     end
                                                        
                                                                                                               
                                                   
                                                      // Extract LPi magnitude (12-bit) and convert to 18-bit signed
                                                        wire [14:0] lpi_u0 = LPi_VNPU[k*15 +: 15];
                                                        wire sign_lpi_u0 = sign_init[k +: 1];
                                                        wire [17:0] lpi_s0 = {{3{sign_lpi_u0}},lpi_u0};
                                                        
                                                       
                                                        wire [14:0] r1_u0 = Rji_VNPU_packed[deleted[k][0][23:16]]
                                                                            [k==unpacked_col_pos[deleted[k][0][23:16]][0] ? 0 :
                                                                             k==unpacked_col_pos[deleted[k][0][23:16]][1] ? 1 :        //takes the Rji of that position
                                                                             k==unpacked_col_pos[deleted[k][0][23:16]][2] ? 2 :
                                                                             k==unpacked_col_pos[deleted[k][0][23:16]][3] ? 3 : 4];
                                                        
                                                        wire [17:0] r1_s0 = {{3{sign_VNPU_packed[deleted[k][0][23:16]]
                                                                            [k==unpacked_col_pos[deleted[k][0][23:16]][0] ? 0 :
                                                                             k==unpacked_col_pos[deleted[k][0][23:16]][1] ? 1 :         
                                                                             k==unpacked_col_pos[deleted[k][0][23:16]][2] ? 2 :
                                                                             k==unpacked_col_pos[deleted[k][0][23:16]][3] ? 3 : 4] }} , r1_u0};
                                                                           
                                                        
                                                        wire [14:0] r2_u0 = Rji_VNPU_packed[deleted[k][0][15:8]]
                                                                            [k==unpacked_col_pos[deleted[k][0][15:8]][0] ? 0 :
                                                                             k==unpacked_col_pos[deleted[k][0][15:8]][1] ? 1 :
                                                                             k==unpacked_col_pos[deleted[k][0][15:8]][2] ? 2 :
                                                                             k==unpacked_col_pos[deleted[k][0][15:8]][3] ? 3 : 4];
                                                        
                                                        wire [17:0] r2_s0 = {{3{sign_VNPU_packed[deleted[k][0][15:8]]
                                                                            [k==unpacked_col_pos[deleted[k][0][15:8]][0] ? 0 :
                                                                             k==unpacked_col_pos[deleted[k][0][15:8]][1] ? 1 :
                                                                             k==unpacked_col_pos[deleted[k][0][15:8]][2] ? 2 :
                                                                             k==unpacked_col_pos[deleted[k][0][15:8]][3] ? 3 : 4] }} ,  r2_u0}; 
                                                                           
                                                        
                                                        wire [14:0] r3_u0 = Rji_VNPU_packed[deleted[k][0][7:0]]
                                                                            [k==unpacked_col_pos[deleted[k][0][7:0]][0] ? 0 :
                                                                             k==unpacked_col_pos[deleted[k][0][7:0]][1] ? 1 :
                                                                             k==unpacked_col_pos[deleted[k][0][7:0]][2] ? 2 :
                                                                             k==unpacked_col_pos[deleted[k][0][7:0]][3] ? 3 : 4];
                                                        
                                                        wire [17:0] r3_s0 = {{3{ sign_VNPU_packed[deleted[k][0][7:0]]
                                                                            [k==unpacked_col_pos[deleted[k][0][7:0]][0] ? 0 :
                                                                             k==unpacked_col_pos[deleted[k][0][7:0]][1] ? 1 :
                                                                             k==unpacked_col_pos[deleted[k][0][7:0]][2] ? 2 :
                                                                             k==unpacked_col_pos[deleted[k][0][7:0]][3] ? 3 : 4] }} , r3_u0}; 
                                                        
                                                        // Final 18-bit signed sum
                                                        wire [17:0] qij_sum0 = lpi_s0 + r1_s0 + r2_s0 + r3_s0;
                                                        
                                                        // Saturate to 12-bit magnitude
                                                       assign QijL[k][0]  = (qij_sum0[14:0] >= 15'd32767) ? 15'd32767 : qij_sum0[14:0];
                                                       assign signL[k][0] = qij_sum0[17];
                                                                                                                   
                                                                                                                                                                         
                                                        
                                                      
                                                                                                                                                                         
                                                        wire [14:0] r1_u1 = Rji_VNPU_packed[deleted[k][1][23:16]]
                                                                            [k==unpacked_col_pos[deleted[k][1][23:16]][0] ? 0 :
                                                                             k==unpacked_col_pos[deleted[k][1][23:16]][1] ? 1 :        //takes the Rji of that position
                                                                             k==unpacked_col_pos[deleted[k][1][23:16]][2] ? 2 :
                                                                             k==unpacked_col_pos[deleted[k][1][23:16]][3] ? 3 : 4];
                                                        
                                                        wire [17:0] r1_s1 = {{3{sign_VNPU_packed[deleted[k][1][23:16]]
                                                                            [k==unpacked_col_pos[deleted[k][1][23:16]][0] ? 0 :
                                                                             k==unpacked_col_pos[deleted[k][1][23:16]][1] ? 1 :         //converts the RJi taken above into neagtive or positive based on the sign
                                                                             k==unpacked_col_pos[deleted[k][1][23:16]][2] ? 2 :
                                                                             k==unpacked_col_pos[deleted[k][1][23:16]][3] ? 3 : 4] }} , r1_u1};  
                                                                                                                                        
                                                        
                                                        wire [14:0] r2_u1 = Rji_VNPU_packed[deleted[k][1][15:8]]
                                                                            [k==unpacked_col_pos[deleted[k][1][15:8]][0] ? 0 :
                                                                             k==unpacked_col_pos[deleted[k][1][15:8]][1] ? 1 :
                                                                             k==unpacked_col_pos[deleted[k][1][15:8]][2] ? 2 :
                                                                             k==unpacked_col_pos[deleted[k][1][15:8]][3] ? 3 : 4];
                                                        
                                                        wire [17:0] r2_s1 = { {3{sign_VNPU_packed[deleted[k][1][15:8]]
                                                                            [k==unpacked_col_pos[deleted[k][1][15:8]][0] ? 0 :
                                                                             k==unpacked_col_pos[deleted[k][1][15:8]][1] ? 1 :
                                                                             k==unpacked_col_pos[deleted[k][1][15:8]][2] ? 2 :
                                                                             k==unpacked_col_pos[deleted[k][1][15:8]][3] ? 3 : 4] }} , r2_u1 };
                                                                                                                                              
                                                        
                                                        wire [14:0] r3_u1 = Rji_VNPU_packed[deleted[k][1][7:0]]
                                                                            [k==unpacked_col_pos[deleted[k][1][7:0]][0] ? 0 :
                                                                             k==unpacked_col_pos[deleted[k][1][7:0]][1] ? 1 :
                                                                             k==unpacked_col_pos[deleted[k][1][7:0]][2] ? 2 :
                                                                             k==unpacked_col_pos[deleted[k][1][7:0]][3] ? 3 : 4];
                                                        
                                                        wire [17:0] r3_s1 = {{3{sign_VNPU_packed[deleted[k][1][7:0]]
                                                                            [k==unpacked_col_pos[deleted[k][1][7:0]][0] ? 0 :
                                                                             k==unpacked_col_pos[deleted[k][1][7:0]][1] ? 1 :
                                                                             k==unpacked_col_pos[deleted[k][1][7:0]][2] ? 2 :
                                                                             k==unpacked_col_pos[deleted[k][1][7:0]][3] ? 3 : 4] }} ,r3_u1 };
                                                                                                                                              
                                                                            
                                                       wire [17:0] qij_sum1 = lpi_s0 + r1_s1 + r2_s1 + r3_s1;
                                                       
                                                        assign QijL[k][1]  = (qij_sum1[14:0] >= 15'd32767) ? 15'd32767 : qij_sum1[14:0];
                                                        assign signL[k][1] = qij_sum1[17];
                                                                                                                                                                
                                                                                                                                                                         
                                                                                                                                                                                                                                                                                                                                                               
                                                     
                                                    
                                                                                                                                                                         
                                                                                                                                                                         
                                                        wire [14:0] r1_u2 =      Rji_VNPU_packed[deleted[k][2][23:16]]
                                                                            [k==unpacked_col_pos[deleted[k][2][23:16]][0] ? 0 :
                                                                             k==unpacked_col_pos[deleted[k][2][23:16]][1] ? 1 :        //takes the Rji of that position
                                                                             k==unpacked_col_pos[deleted[k][2][23:16]][2] ? 2 :
                                                                             k==unpacked_col_pos[deleted[k][2][23:16]][3] ? 3 : 4];
                                                        
                                                        wire [17:0] r1_s2 = {{3{sign_VNPU_packed[deleted[k][2][23:16]]
                                                                            [k==unpacked_col_pos[deleted[k][2][23:16]][0] ? 0 :
                                                                             k==unpacked_col_pos[deleted[k][2][23:16]][1] ? 1 :         //converts the RJi taken above into neagtive or positive based on the sign
                                                                             k==unpacked_col_pos[deleted[k][2][23:16]][2] ? 2 :
                                                                             k==unpacked_col_pos[deleted[k][2][23:16]][3] ? 3 : 4] }} , r1_u2 };
                                                                            
                                                        
                                                        wire [14:0] r2_u2 = Rji_VNPU_packed[deleted[k][2][15:8]]
                                                                            [k==unpacked_col_pos[deleted[k][2][15:8]][0] ? 0 :
                                                                             k==unpacked_col_pos[deleted[k][2][15:8]][1] ? 1 :
                                                                             k==unpacked_col_pos[deleted[k][2][15:8]][2] ? 2 :
                                                                             k==unpacked_col_pos[deleted[k][2][15:8]][3] ? 3 : 4];
                                                        
                                                        wire [17:0] r2_s2 = {{3{sign_VNPU_packed[deleted[k][2][15:8]]
                                                                            [k==unpacked_col_pos[deleted[k][2][15:8]][0] ? 0 :
                                                                             k==unpacked_col_pos[deleted[k][2][15:8]][1] ? 1 :
                                                                             k==unpacked_col_pos[deleted[k][2][15:8]][2] ? 2 :
                                                                             k==unpacked_col_pos[deleted[k][2][15:8]][3] ? 3 : 4] }} , r2_u2 };
                                                                           
                                                        
                                                        wire [14:0] r3_u2 = Rji_VNPU_packed[deleted[k][2][7:0]]
                                                                            [k==unpacked_col_pos[deleted[k][2][7:0]][0] ? 0 :
                                                                             k==unpacked_col_pos[deleted[k][2][7:0]][1] ? 1 :
                                                                             k==unpacked_col_pos[deleted[k][2][7:0]][2] ? 2 :
                                                                             k==unpacked_col_pos[deleted[k][2][7:0]][3] ? 3 : 4];
                                                        
                                                        wire [17:0] r3_s2 = {{3{sign_VNPU_packed[deleted[k][2][7:0]]
                                                                            [k==unpacked_col_pos[deleted[k][2][7:0]][0] ? 0 :
                                                                             k==unpacked_col_pos[deleted[k][2][7:0]][1] ? 1 :
                                                                             k==unpacked_col_pos[deleted[k][2][7:0]][2] ? 2 :
                                                                             k==unpacked_col_pos[deleted[k][2][7:0]][3] ? 3 : 4] }} , r3_u2 };
                                                                                      
                                                                            
                                                       wire [17:0] qij_sum2 = lpi_s0 + r1_s2 + r2_s2 + r3_s2;
                                                       
                                                        assign QijL[k][2]  = (qij_sum2[14:0] >= 15'd32767) ? 15'd32767 : qij_sum2[14:0];   
                                                        assign signL[k][2] = qij_sum2[17];
                                                        
                                                                                
                                                                                                                                                                         
                                                                                                                                                                         
                                                        wire [14:0] r1_u3 =      Rji_VNPU_packed[deleted[k][3][23:16]]
                                                                            [k==unpacked_col_pos[deleted[k][3][23:16]][0] ? 0 :
                                                                             k==unpacked_col_pos[deleted[k][3][23:16]][1] ? 1 :        //takes the Rji of that position
                                                                             k==unpacked_col_pos[deleted[k][3][23:16]][2] ? 2 :
                                                                             k==unpacked_col_pos[deleted[k][3][23:16]][3] ? 3 : 4];
                                                        
                                                        wire [17:0] r1_s3 = { {3{sign_VNPU_packed[deleted[k][3][23:16]]
                                                                            [k==unpacked_col_pos[deleted[k][3][23:16]][0] ? 0 :
                                                                             k==unpacked_col_pos[deleted[k][3][23:16]][1] ? 1 :         //converts the RJi taken above into neagtive or positive based on the sign
                                                                             k==unpacked_col_pos[deleted[k][3][23:16]][2] ? 2 :
                                                                             k==unpacked_col_pos[deleted[k][3][23:16]][3] ? 3 : 4] }} , r1_u3};
                                                                            
                                                        
                                                        wire [14:0] r2_u3 = Rji_VNPU_packed[deleted[k][3][15:8]]
                                                                            [k==unpacked_col_pos[deleted[k][3][15:8]][0] ? 0 :
                                                                             k==unpacked_col_pos[deleted[k][3][15:8]][1] ? 1 :
                                                                             k==unpacked_col_pos[deleted[k][3][15:8]][2] ? 2 :
                                                                             k==unpacked_col_pos[deleted[k][3][15:8]][3] ? 3 : 4];
                                                        
                                                        wire [17:0] r2_s3 = { {3{sign_VNPU_packed[deleted[k][3][15:8]]
                                                                            [k==unpacked_col_pos[deleted[k][3][15:8]][0] ? 0 :
                                                                             k==unpacked_col_pos[deleted[k][3][15:8]][1] ? 1 :
                                                                             k==unpacked_col_pos[deleted[k][3][15:8]][2] ? 2 :
                                                                             k==unpacked_col_pos[deleted[k][3][15:8]][3] ? 3 : 4] }} , r2_u3 };
                                                                            
                                                        
                                                        wire [14:0] r3_u3 = Rji_VNPU_packed[deleted[k][3][7:0]]
                                                                            [k==unpacked_col_pos[deleted[k][3][7:0]][0] ? 0 :
                                                                             k==unpacked_col_pos[deleted[k][3][7:0]][1] ? 1 :
                                                                             k==unpacked_col_pos[deleted[k][3][7:0]][2] ? 2 :
                                                                             k==unpacked_col_pos[deleted[k][3][7:0]][3] ? 3 : 4];
                                                        
                                                        wire [17:0] r3_s3 = { {3{sign_VNPU_packed[deleted[k][3][7:0]]
                                                                            [k==unpacked_col_pos[deleted[k][3][7:0]][0] ? 0 :
                                                                             k==unpacked_col_pos[deleted[k][3][7:0]][1] ? 1 :
                                                                             k==unpacked_col_pos[deleted[k][3][7:0]][2] ? 2 :
                                                                             k==unpacked_col_pos[deleted[k][3][7:0]][3] ? 3 : 4] }} , r3_u3 };
                                                                                     
                                                                            
                                                       wire [17:0] qij_sum3 = lpi_s0 + r1_s3 + r2_s3 + r3_s3;
                                                       
                                                        assign QijL[k][3]  = (qij_sum3[14:0] >= 15'd32767) ? 15'd32767 : qij_sum3[14:0];                                                                                                                   
                                                        assign signL[k][3] = qij_sum3[17];                                                                                                                 
                                                                                                                                                                                                      
                                                      
                                                     
                                                     assign Qij_CTV[k]  = { QijL[k][0]  , QijL[k][1]  , QijL[k][2]   , QijL[k][3]   };
                                                     assign sign_CTV[k] = { signL[k][0] , signL[k][1] , signL[k][2] , signL[k][3] };
                                                     
                                                     assign Qij_out[k]  =  iteration_num==0? Qij_LPi[k] : Qij_CTV[k] ; 
                                                     assign sign_out[k] = iteration_num==0? sign_LPi[k] : sign_CTV[k] ;
                                                     assign sign_Qij_out[k] = {sign_out[k] , Qij_out[k] };
                                               end
                                               
                                             endgenerate
                                               
                                               
                                       genvar m;
                                       generate
                                            for(m=0; m<100 ; m=m+1 )
                                                begin
                                                        assign sign_Qij[m*64 +: 64] = sign_Qij_out[m];                       
                                                end    
                                       endgenerate                   
endmodule
