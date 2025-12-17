`timescale 1ns / 1ps

module Decision_Unit (                  input wire [99:0]x_i_VNPU,
                                        input wire [3:0]qber_VNPU,
                                        input wire clk,
                                        input wire rst,
                                        input wire rd_en , wr_en , en,
                                        input wire [6399:0]sign_Rji_CNPU,
                                        input wire [7:0]iteration_num,
                                        output wire [99:0]decision
                                       );

                                       wire [14:0]   Rji_VNPU_packed  [0:79][0:4];
                                       wire [1499:0] LPi_VNPU ;                    // to take LPi values from the Lpi module
                                       wire [14:0]   qij_LPi          [0:99];       // to store the duplicated LPi values ( Here its 4 values because each column has same LPi) 
                                       wire          sign_LPi         [0:99];
                                       wire          sign_out         [0:99];
                                       wire          signL            [0:99];
                                        
                                       wire [4:0]    sign_VNPU        [0:79];
                                       wire          sign_VNPU_packed [0:79][0:4];
                                       wire [99:0]   sign_init;
                                       
  
                                       LPi_calculation lpi( .x_i(x_i_VNPU),   //obtaining LPi Values
                                                         .qber(qber_VNPU),
                                                         .LPi(LPi_VNPU),
                                                         .sign(sign_init) );
                                      
                                                         
                                       wire [74:0] Rji_VNPU          [0:79]; // to take R values from C to V bram   (15 * 5 Rji)   
                                       wire [79:0] sign_Rji_packed   [0:79];          
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
                                        
                                        wire [71:0] dout_pos [0:99] ; //store the positions of row and column
                                        wire [39:0] col_pos [0:79];   // 5 1's per row i.e 40 bits
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
                                        
                                        genvar j,k,l;
                                        generate
                                            for(j=0;j<100;j=j+1)
                                            begin: parsing_H_position
                                                 positionsrowcol bram1       (  
                                                                        .clka(clk),          // input clock                                                                               
                                                                        .wea(1'b0),            // write enable
                                                                        .addra(j),        // address
                                                                        .dina(32'b0),          // data in
                                                                        .douta(dout_pos[j]));
                                                 assign  qij_LPi[j] =  LPi_VNPU[j*15 +:15] ; 
                                                 assign sign_LPi[j] = sign_init[j +: 1] ;                     
                                                 assign row_pos[j]=dout_pos[j][71:40];   // 4 1's per column hence 32 bits        
                                             end
                                             
                                               
                                        for(k=0;k<100;k=k+1) 
                                        begin
                                             wire [7:0] pos1=row_pos[k][31:24]; 
                                             wire [7:0] pos2=row_pos[k][23:16]; 
                                             wire [7:0] pos3=row_pos[k][15:8];  
                                             wire [7:0] pos4=row_pos[k][7:0];

                                             // Slot mapping to pick correct edge of each row
                                             wire [2:0] slot1 = (k==unpacked_col_pos[pos1][0]) ? 3'd0 :
                                                                (k==unpacked_col_pos[pos1][1]) ? 3'd1 :
                                                                (k==unpacked_col_pos[pos1][2]) ? 3'd2 :
                                                                (k==unpacked_col_pos[pos1][3]) ? 3'd3 : 3'd4;
                                             wire [2:0] slot2 = (k==unpacked_col_pos[pos2][0]) ? 3'd0 :
                                                                (k==unpacked_col_pos[pos2][1]) ? 3'd1 :
                                                                (k==unpacked_col_pos[pos2][2]) ? 3'd2 :
                                                                (k==unpacked_col_pos[pos2][3]) ? 3'd3 : 3'd4;
                                             wire [2:0] slot3 = (k==unpacked_col_pos[pos3][0]) ? 3'd0 :
                                                                (k==unpacked_col_pos[pos3][1]) ? 3'd1 :
                                                                (k==unpacked_col_pos[pos3][2]) ? 3'd2 :
                                                                (k==unpacked_col_pos[pos3][3]) ? 3'd3 : 3'd4;
                                             wire [2:0] slot4 = (k==unpacked_col_pos[pos4][0]) ? 3'd0 :
                                                                (k==unpacked_col_pos[pos4][1]) ? 3'd1 :
                                                                (k==unpacked_col_pos[pos4][2]) ? 3'd2 :
                                                                (k==unpacked_col_pos[pos4][3]) ? 3'd3 : 3'd4;
                                        
                                           
                                             wire [14:0] lpi_u =  qij_LPi[k];
                                             wire [14:0] r1_u  =  Rji_VNPU_packed[pos1][slot1];
                                             wire [14:0] r2_u  =  Rji_VNPU_packed[pos2][slot2];
                                             wire [14:0] r3_u  =  Rji_VNPU_packed[pos3][slot3];
                                             wire [14:0] r4_u  =  Rji_VNPU_packed[pos4][slot4];
                                        
                                            
                                             wire [17:0] lpi_s = {{3{sign_LPi[k] }}, lpi_u };
                                             wire [17:0] r1_s  = {{3{sign_VNPU_packed[pos1][slot1] }}, r1_u};
                                             wire [17:0] r2_s  = {{3{sign_VNPU_packed[pos2][slot2] }}, r2_u};
                                             wire [17:0] r3_s  = {{3{sign_VNPU_packed[pos3][slot3] }}, r3_u};
                                             wire [17:0] r4_s  = {{3{sign_VNPU_packed[pos4][slot4] }}, r4_u};
                                        
                                             // True signed posterior sum
                                             wire [17:0] qllr = lpi_s + r1_s + r2_s + r3_s + r4_s;

                                      
                                            assign signL[k]    = qllr[17];           // sign bit
     
                                            assign sign_out[k] = (iteration_num==0) ? sign_LPi[k] : signL[k];
                                            assign decision[k] = sign_out[k];
                end
                endgenerate
    
                                         
                                       
                                       
                                       
                                      
                                       
                                       
endmodule