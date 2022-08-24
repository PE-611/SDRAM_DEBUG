///////////////////////////////////////////////////////////
// Name File : SDRAM_IS42S16160B_DRIVER.v						//
// Autor : Dyomkin Pavel Mikhailovich 							//
// Company : FLEXLAB													//
// Description : Test system (shift_reg/driver)			  	//
// Start design : 11.08.2022 										//
// Last revision : 23.08.2022 									//
///////////////////////////////////////////////////////////



module SDRAM_IS42S16160B_DRIVER( input SDRAM_CLK_IN, SDRAM_CLK_OUT,  start_write, start_read, reset,
											input [12:0] ADDR_ROW,
											input [12:0] ADDR_COL,
											input [1:0]  BANK,

											output reg	[12:0]	DRAM_ADDR,
											output reg	[1:0]		DRAM_BA,
											output reg				DRAM_CKE,
											output reg  [1:0]		DRAM_DQM,
											output reg 	[3:0] 	DRAM_CMD,		//DRAM_CS_N, DRAM_RAS_N, DRAM_CAS_N, DRAM_WE_N
											output reg				process_flg,
											output reg				ready_data		//PROCESS FLAG IS HERE!
											//inout  		[15:0]	DRAM_DQ
											
											//	output reg				DRAM_CAS_N,
											//	output reg	    		DRAM_CS_N,
											//	output reg       		DRAM_RAS_N,
											//	output reg       		DRAM_WE_N,
										 );
										 
										 
parameter Fclk								= 140_000_000;		  		  // MHz										 
parameter tREF       					= 64;   						  // ms
parameter tINIT							= 200_000;					  // ns
parameter quantity_autorefresh 		= 8192;  					  // refresh counter (cycle refresh)

parameter tCK        					= 7;     					  // clk period 7 ns (for calcul refresh interval)
parameter REFRESH_TIME					= (((tREF * 1_000_000) / quantity_autorefresh) / tCK); 
																				  // need 64 ms

parameter init_time	 					= tINIT / tCK;       		// need time > 200_000 ns
parameter q_AREF_for_init				= 8;
parameter MRS_DATA						= 12'b000_1_00_011_1_000; // mode register set
parameter trc								= 10;  						  // Trc
parameter trp								= 3;							  // Trp 
parameter cas			 					= 6;							  // CAS
parameter rcd								= 3;							  // Rcd

localparam IDLE 							= 8'd0;
localparam MRS								= 8'd1;
localparam ACTIVATE_ROW					= 8'd2;
localparam REFRESH						= 8'd3;
localparam READ							= 8'd4;
localparam WRITE							= 8'd5;
localparam PRECHARGE						= 8'd6;
localparam NOP_INIT_AREF			  	= 8'd7;
localparam NOP_BEFORE_RW				= 8'd8;
localparam NOP_AFTER_W					= 8'd9;
localparam NOP_AFTER_R					= 8'd10;
										 						 
localparam CMD_DESL  					= 4'b1_1_1_1; // device deselect
localparam CMD_NOP   					= 4'b0_1_1_1; // no operation
localparam CMD_BST   					= 4'b0_1_1_0; // burst stop
localparam CMD_READ  					= 4'b0_1_0_1; // read							DRAM_ADDR[10] functional bit 
localparam CMD_WRITE 					= 4'b0_1_0_0; // write
localparam CMD_ACT   					= 4'b0_0_1_1; // bank activate
localparam CMD_PRE   					= 4'b0_0_1_0; // precharge select bank
localparam CMD_REF   					= 4'b0_0_0_1; // CBR auto-refresh
localparam CMD_MRS   					= 4'b0_0_0_0; // Mode register set
							 
//reg process_flg; This flg in initialization I/O

reg [7:0] state;	
reg [7:0] next_state;
//reg [7:0] state_cnt;

reg [24:0] cnt_timer;
reg [16:0] cnt_autorefresh;	

reg time_init_flg;
reg self_refresh;

reg flg_init;
reg write_flg;
reg read_flg;

reg [4:0]  Trc;
reg [4:0]  Trcd;
reg [4:0]  Tcas;
	

initial begin

	state								<= IDLE;
	next_state 						<= IDLE;

	DRAM_CKE 						<= 1'b1;
	DRAM_CMD							<= CMD_NOP;
	DRAM_ADDR 						<= 12'd0;
	DRAM_BA 							<= 1'b00;
	DRAM_DQM 						<= 1'b0;
	
	cnt_timer	 					<= 24'd0;
	cnt_autorefresh			 	<= 16'd0;
	
	time_init_flg					<= 1'b0;  
	process_flg 					<= 1'b1; 
	self_refresh 					<= 1'b0;
	flg_init 						<= 1'b0;
	write_flg						<= 1'b0;
	read_flg							<= 1'b0;

	
	Trc								<= 4'd0;
	Tcas								<= 4'd0;
	Trcd								<= 4'd0;
	
end




always @* 	
		
		case (state)
			
			IDLE:
						
				
				if ((time_init_flg == 1'b1 && flg_init == 1'b0) || (self_refresh == 1'b1 && flg_init == 1'b1)) begin
					next_state <= PRECHARGE;
				end
								
				else if (write_flg == 1'b1 || read_flg == 1'b1) begin  
					next_state <= ACTIVATE_ROW;
				end
								
				else begin
					next_state <= IDLE;
				end

				
			NOP_INIT_AREF:
			
				
				if (Trc >= trc && cnt_autorefresh >= q_AREF_for_init && flg_init == 1'b0) begin
					next_state <= MRS;
				end
				
				
				else if (Trc >= trc && cnt_autorefresh < quantity_autorefresh && flg_init == 1'b0) begin
					next_state <= REFRESH;
				end
				
				else if (Trc >= trc && cnt_autorefresh < quantity_autorefresh && self_refresh == 1'b1) begin
					next_state <= REFRESH;
				end
				
				else if (Trc < trc) begin
					next_state <= NOP_INIT_AREF;
				end
				
				else begin
					next_state <= IDLE;
				end
				
				
			PRECHARGE:
						
				
				if (state == PRECHARGE) begin
					next_state <= NOP_INIT_AREF;
				end
				
								
				else begin
					next_state <= PRECHARGE;
				end
			
			REFRESH:
						
				
				if (state == REFRESH) begin
					next_state <= NOP_INIT_AREF;
				end
				
								
				else begin
					next_state <= REFRESH;
				end
				
			MRS:
						
				
				if (state == MRS) begin
					next_state <= NOP_INIT_AREF;
				end
				
								
				else begin
					next_state <= MRS;
				end
			
				
			ACTIVATE_ROW:
				
				
				if (state == ACTIVATE_ROW) begin
					next_state <= NOP_BEFORE_RW;
				end	
				
							
				else begin
					next_state <= ACTIVATE_ROW;
				end
				
				
			NOP_BEFORE_RW: 
				
				if (Trcd >= rcd && write_flg == 1'b1) begin
					next_state <= WRITE;
				end
				
				else if (Trcd >= rcd && read_flg == 1'b1) begin
					next_state <= READ;
				end
				
				else begin
					next_state <= NOP_BEFORE_RW;
				end
				
				
			READ:
						
				
				if (state == READ) begin
					next_state <= NOP_AFTER_R;
				end
				
							
				else begin
					next_state <= READ;
				end
				
				
			WRITE:
						
				
				if (state == WRITE) begin
					next_state <= NOP_AFTER_W;
				end
				
							
				else begin
					next_state <= WRITE;
				end
				
				
			NOP_AFTER_R:
				
				if (Tcas == cas) begin						// CAS = 3 and 3 for Trc for next ACTIVATE comand
					next_state <= IDLE;
				end		
				
				else begin
					next_state <= NOP_AFTER_R;
				end
				
			NOP_AFTER_W:
				
				if (Tcas == cas) begin						// CAS = 3 and 3 for Trc for next ACTIVATE comand
					next_state <= IDLE;
				end		
				
				else begin
					next_state <= NOP_AFTER_W;
				end
				
			
			default:
				next_state <= IDLE;
		
		endcase
		
		
always @(posedge SDRAM_CLK_IN) begin
	
	cnt_timer <= cnt_timer + 1'b1;
	DRAM_CKE <= 1'b1;
	DRAM_DQM	<= 1'b0;
	
	
		
	if (state == IDLE) begin
		DRAM_CMD 						<= CMD_NOP;
		DRAM_DQM 						<= 1'b0;
		process_flg 					<= 1'b0;
		
	end
	
	if (state == PRECHARGE) begin
		process_flg 					<= 1'b1;
		DRAM_CMD  						<= CMD_PRE;
		DRAM_ADDR 						<= 12'b010000000000;				// ALL BANK
		DRAM_BA							<= BANK;
	end
		
	if (state == NOP_INIT_AREF) begin
		Trc 								<= Trc + 1'b1;
		DRAM_CMD 						<= CMD_NOP;
	end
	
	if (state != NOP_INIT_AREF) begin
		Trc 								<= 1'b0;
	end
	
	if (Trc == trc) begin
		Trc 								<= 4'd0;
	end
	
	if (state == REFRESH) begin
		cnt_autorefresh 				<= cnt_autorefresh + 1'b1;
		DRAM_CMD 						<= CMD_REF;
	end

	if (state == MRS) begin
		DRAM_CMD  						<= CMD_MRS;
		DRAM_ADDR 						<= MRS_DATA;
		cnt_autorefresh 				<= 8'd0;
		DRAM_BA							<= BANK;
	end
	
	if (state == ACTIVATE_ROW) begin
		DRAM_CMD  						<= CMD_ACT;
		DRAM_ADDR						<= ADDR_ROW;
		DRAM_BA							<= BANK;					
		process_flg 					<= 1'b1; 
	end
	
	if (state == NOP_BEFORE_RW) begin
		Trcd		 						<= Trcd + 1'b1;
		DRAM_CMD 						<= CMD_NOP;
	end
	
	if (state != NOP_BEFORE_RW) begin
		Trcd		 						<= 1'b0;
	end
	
	if (Trcd == rcd) begin
		Trcd 								<= 4'd0;
	end	
	
	if (state == WRITE) begin
		DRAM_CMD 						<= CMD_WRITE;
		DRAM_ADDR						<= ADDR_COL + 1024;  //1024 for set a10 bit in high level. For enable autoprecharge ALL banks
		DRAM_BA							<= BANK;				  	 
	end
	
	if (state == READ) begin
		DRAM_CMD 						<= CMD_READ;
		DRAM_ADDR						<= ADDR_COL + 1024;  //1024 for set a10 bit in high level. For enable autoprecharge ALL banks
		DRAM_BA							<= BANK;
//		ready_data						<= 1'b0;
	end
	
	if (state == NOP_AFTER_R) begin
		DRAM_CMD 						<= CMD_NOP;
		Tcas 								<= Tcas + 1'b1;
		read_flg <= 1'b0;
	end

	
	if (state == NOP_AFTER_W) begin
		DRAM_CMD 						<= CMD_NOP;
		Tcas 								<= Tcas + 1'b1;
		write_flg <= 1'b0;
	end
	
	
	if (Tcas == cas) begin
		Tcas 								<= 4'd0;
	end
	
	
	
	
	if (start_write == 1'b0) begin
		write_flg 						<= 1'b1;
		process_flg 					<= 1'b1;
	end
	
	if (start_read == 1'b0) begin
		read_flg 						<= 1'b1;
		process_flg 					<= 1'b1;
	end
	
	

	
	if (cnt_timer >= REFRESH_TIME && flg_init == 1'b1) begin
		cnt_timer <= 24'd0;
		self_refresh <= 1'b1;
		process_flg <= 1'b1;
	end
	
	if (self_refresh == 1'b1) begin
		process_flg <= 1'b1;
	end
	
	if (cnt_timer >= init_time) begin
		time_init_flg <= 1'b1;
	end
	
	if (cnt_timer == init_time + 110) begin								// 110 is quantity tacts for initialization SDRAM
		flg_init <= 1'b1;
	end
	
	if (cnt_timer < init_time + 2 && flg_init == 1'b0) begin			// +1 takt chtob process_flg ne provalivalsa poka flg_init ne stanet 1
		process_flg <= 1'b1;
	end
	
	if (Trc == trc && flg_init == 1'b1)  begin   
		self_refresh <= 1'b0;
	end
	
//	if (state == NOP_AFTER_R && Tcas == 4'd3) begin
//		ready_data   <= 1'b1;
//	end	

	
end


always @(posedge SDRAM_CLK_OUT) begin
	if (state == NOP_AFTER_R && Tcas == 4'd3) begin
		ready_data   <= 1'b1;
	end
	
	if (state == READ) begin
		ready_data	<= 1'b0;
	end
end 	


always @(posedge SDRAM_CLK_IN or negedge reset) begin 
	
	
	if(!reset) begin
		state <= IDLE;
	end
	
	else begin
		state <= next_state;
	end
end	


	
endmodule

									
										 
