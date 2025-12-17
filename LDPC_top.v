`timescale 1ns / 1ps
module LDPC_top(
    input  wire clk , rst,
    input  wire [99:0] x_i,
    input  wire [3:0]  qber,
    input  wire        en,
    output wire [99:0] corrected_code_top,
    output reg         ldpc_done     
);

    reg [3:0] cycle_cnt;     // cycles within 1 iteration 
    reg [7:0] iteration_num; 
    reg       iter_pulse_VNPU;    // 1-cycle pulse at iteration boundary
    reg       iter_pulse_CNPU;
    reg       done;          

    localparam ITER_CYCLES = 7;
    localparam MAX_ITERS   = 17; 

    always @(posedge clk or posedge rst) 
    	begin
        if (rst) 
		begin

            	cycle_cnt       <= 0;
            	iteration_num   <= 0;
           	iter_pulse_VNPU <= 0;
            	iter_pulse_CNPU <= 0;
            	done            <= 0;
            	ldpc_done       <= 0;

       		end

        else if (en && !ldpc_done) 
		begin  
            	if (cycle_cnt == ITER_CYCLES-1) 
            		begin

                	cycle_cnt     <= 0;
                	iteration_num <= iteration_num + 1;
                	iter_pulse_VNPU    <= 1'b0;
                	iter_pulse_CNPU    <= 1'b0;
                	if (iteration_num == MAX_ITERS-1)
                    		done <= 1'b1;
                	if (iteration_num == (STOP_ITER-1)) 
                    		ldpc_done <= 1'b1;

            		end 
            	else if (cycle_cnt == ITER_CYCLES - 5)
            		begin

               		iter_pulse_VNPU <=1'b1;
                	iter_pulse_CNPU <= 1'b0;
                	cycle_cnt  <= cycle_cnt + 1;

            		end 
            	else if (cycle_cnt == ITER_CYCLES - 3)
            		begin

                	iter_pulse_VNPU <=1'b0;
                	iter_pulse_CNPU <= 1'b1;
                	cycle_cnt  <= cycle_cnt + 1;

            		end 
            	else
           		begin
                	iter_pulse_VNPU <=   1'b0;
                	iter_pulse_CNPU <=   1'b0;
                	cycle_cnt  <= cycle_cnt + 1;
            		end

        	end 
	else if (!en || ldpc_done) 
		begin
            	iter_pulse_VNPU <=   1'b0;
            	iter_pulse_CNPU <=   1'b0;
       		end
    	end

    wire [6399:0] sign_Qij_raw;
    wire [6399:0] sign_Rji_raw;

    reg  [6399:0] Qij_reg;   //for latching
    reg  [6399:0] Rji_reg;   

    VARIABLE_NODES_PROCESSING_UNIT vnpu_core (
        .clk(clk), 
	.rst(rst),
        .x_i_VNPU(x_i),
	.qber_VNPU(qber),
        .en(en),
        .iteration_num(iteration_num),
        .sign_Rji_CNPU((iteration_num==0)? 6400'b0 : Rji_reg),   
        .sign_Qij(sign_Qij_raw)
    );

    always @(posedge clk or posedge rst) 
	begin
        if (rst) 
            Qij_reg <= 0;
        else if (iter_pulse_VNPU) 
            Qij_reg <= sign_Qij_raw;
   	end
    CHECK_NODES_PROCESS_UNIT cnpu_core (
        .clk(clk), 
	.rst(rst),
        .en(en),
        .sign_Qij_VNPU(Qij_reg),   
        .sign_Rji_out(sign_Rji_raw)
    );

    always @(posedge clk or posedge rst) begin
        if (rst) 
            Rji_reg <= 0;
        else if (iter_pulse_CNPU) 
            Rji_reg <= sign_Rji_raw;
    end

    Decision_Unit dec (
        .clk(clk), .rst(rst),
        .x_i_VNPU(x_i), .qber_VNPU(qber),
        .rd_en(rd_en), .wr_en(wr_en), .en(en),
        .iteration_num(iteration_num),
        .sign_Rji_CNPU(Rji_reg),
        .decision(corrected_code_top)
    );

endmodule