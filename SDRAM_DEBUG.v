///////////////////////////////////////////////////////////
// Name File : SDRAM_DEBUG.v 										//
// Autor : Dyomkin Pavel Mikhailovich 							//
// Company : FLEXLAB													//
// Description : Debug SDRAM driver							  	//
// Start design : 16.08.2022 										//
// Last revision : 23.08.2022 									//
///////////////////////////////////////////////////////////


module SDRAM_DEBUG (	input 					CLK_IN, reset,
							output    				CLK_160_COMMON, 
							
							output reg				ERROR,
							output reg				end_write,
							
							output					CLK_160_90_SDRAM,
							output 		[12:0]	DRAM_ADDR,
							output   	[1:0]		DRAM_BA,
							output 					DRAM_CKE,
							output   	[1:0]		DRAM_DQM,
							output  		[3:0] 	DRAM_CMD,		//DRAM_CS_N[3], DRAM_RAS_N[2], DRAM_CAS_N[1], DRAM_WE_N[0]
							inout  wire [15:0]	DRAM_DQ,
							output		[7:0]    LED
							
							);
							

										
							
							
localparam IDLE 							= 8'd0;
localparam READ							= 8'd1;
localparam WRITE							= 8'd2;
localparam WAIT_START_PROCESS			= 8'd3;
localparam WAIT_END_PROCESS			= 8'd4;
localparam SETADDR						= 8'd5;



reg [7:0] state;	
reg [7:0] next_state;



wire 				SDRAM_PROCESS;
wire 				READY_DATA;

reg 				START_WRITE;
reg 				START_READ;
wire 	[12:0]	ADDR_ROW;
wire 	[12:0]	ADDR_COL;
wire	[1:0]		BANK;
reg	[15:0]	DATA_FOR_WR;
reg 	[15:0]   DATA_FOR_CHECK;
reg   [15:0]	DATA_FROM_SDRAM;

reg   [7:0]		addr;



//reg 		end_write;



initial begin


	START_WRITE 		<= 1'b1;
	START_READ 			<= 1'b1;
	
	end_write			<= 1'b0;
	ERROR					<= 1'b0;
	
	addr 					<= 3'd0;

	DATA_FOR_WR 		<= 16'd0;
	DATA_FOR_CHECK		<= 16'd0;
	DATA_FROM_SDRAM 	<= 16'd0;
	


end

assign ADDR_COL	[2:0] = addr[2:0];
assign ADDR_ROW	[2:0] = addr[5:3];
assign BANK			[1:0] = addr[7:6];
 
assign ADDR_COL	[12:3] = 9'b000000000;
assign ADDR_ROW	[12:3] = 9'b000000000;


assign DRAM_DQ = (DRAM_CMD == 4'b0_1_0_0) ? DATA_FOR_WR : 16'b?;

assign LED[0] = ERROR;
assign LED[7] = end_write;




always @* 	
		
		case (state)
			
			IDLE:
						
				
				if (START_WRITE == 1'b1 && SDRAM_PROCESS == 1'b0 && end_write == 1'b0) begin
					next_state <= WRITE;
				end
				
				else if (START_READ == 1'b1 && SDRAM_PROCESS == 1'b0 && end_write == 1'b1) begin
					next_state <= READ;
				end
								
				else begin
					next_state <= IDLE;
				end
				
			WRITE:
			
				if(state == WRITE) begin
					next_state <= WAIT_START_PROCESS;
				end	
				
				else begin
					next_state <= WRITE;
				end
				
			READ:
			
				if(state == READ) begin
					next_state <= WAIT_START_PROCESS;
				end	
				
				else begin
					next_state <= READ;
				end
				
			WAIT_START_PROCESS:
			
				if (SDRAM_PROCESS == 1'b1) begin
					next_state <= WAIT_END_PROCESS;
				end
				
				else begin
					next_state <= WAIT_START_PROCESS;
				end
				
			WAIT_END_PROCESS:
			
				if (SDRAM_PROCESS == 1'b0) begin
					next_state <= SETADDR;
				end
				
				else begin
					next_state <= WAIT_END_PROCESS;
				end

			SETADDR:
				
				if (state == SETADDR && SDRAM_PROCESS == 1'b0) begin
					next_state <= IDLE;
				end
				
				else begin
					next_state <= SETADDR;
				end
			
							
			default:
				next_state <= IDLE;
		
		endcase



		
always @(posedge CLK_160_COMMON) begin
	
	if (state == IDLE) begin
		START_WRITE 	<= 1'b1;
		START_READ 		<= 1'b1;
	end
	
	if	(state == WRITE && SDRAM_PROCESS == 1'b0) begin
		START_WRITE 	<= 1'b0;
		DATA_FOR_WR 	<= DATA_FOR_WR + 1'b1;
	end
	
	if (state == READ && SDRAM_PROCESS == 1'b0) begin
		START_READ 		<= 1'b0;
	end
	
	
	if (state == WAIT_END_PROCESS) begin
		START_WRITE 	<= 1'b1;
		START_READ 		<= 1'b1;
	end
	
	if (state == SETADDR && SDRAM_PROCESS == 1'b0 && end_write == 1'b0) begin
		addr <= addr + 1'b1;
	end
	
	if (START_READ == 1'b0 && SDRAM_PROCESS == 1'b0) begin
		addr <= addr + 1'b1;
	end
	
	if (addr == 255 && SDRAM_PROCESS == 1'b0 && end_write == 1'b0) begin
		end_write <= 1'b1;
	end
end		
		
always @(posedge CLK_160_COMMON or negedge reset) begin 
	
	
	if(!reset) begin
		state <= IDLE;
	end
	
	else begin
		state <= next_state;
	end
end




always @(posedge READY_DATA) begin

		DATA_FROM_SDRAM <= DRAM_DQ;
end



always @(negedge START_READ) begin
	
	if (DATA_FROM_SDRAM != DATA_FOR_CHECK && end_write == 1'b1 && READY_DATA == 1'b1) begin
		ERROR <= 1'b1;
	end
	

	
end
		
always @(posedge READY_DATA) begin
		DATA_FOR_CHECK <= DATA_FOR_CHECK + 1'b1;
	
	if (DATA_FOR_CHECK >= 16'd256) begin
		DATA_FOR_CHECK <= 16'd1;
	end
end						
	




							
			
PLL PLL1 (.inclk0(CLK_IN),	.c0(CLK_160_COMMON),	.c1(CLK_160_90_SDRAM));

SDRAM_IS42S16160B_DRIVER SDRAM1 (.SDRAM_CLK_IN(CLK_160_COMMON), .SDRAM_CLK_OUT(CLK_160_90_SDRAM), .start_write(START_WRITE), .start_read(START_READ),
											.ADDR_ROW(ADDR_ROW), .ADDR_COL(ADDR_COL), .BANK(BANK), .DRAM_ADDR(DRAM_ADDR),
											.DRAM_BA(DRAM_BA), .DRAM_CKE(DRAM_CKE), .DRAM_DQM(DRAM_DQM), .DRAM_CMD(DRAM_CMD),
											.process_flg(SDRAM_PROCESS), .ready_data(READY_DATA), 
											.reset(reset));
		
							
endmodule