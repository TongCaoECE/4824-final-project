
`timescale 1ns/100ps

module pipeline (
	input clock,  
	input reset,  
	input [`SUPERSCALAR_WAYS-1:0][3:0]  					mem2proc_response, 
	input [63:0] 											mem2proc_data,  	
	input [`SUPERSCALAR_WAYS-1:0][3:0]  					mem2proc_tag,    
    input [`SUPERSCALAR_WAYS-1:0][63:0]	                    Imem2proc_data,
	
	output logic [1:0]  									proc2mem_command,   
	output logic [`XLEN-1:0] 								proc2mem_addr,     
	output logic [63:0] 									proc2mem_data,    

    output logic        									halt,
    output logic [2:0]  									inst_count,


	
	// Outputs from Fetch-Stage 
	output logic [`SUPERSCALAR_WAYS-1:0][`XLEN-1:0] 		fetch_PC_out,
	output logic [`SUPERSCALAR_WAYS-1:0][`XLEN-1:0] 		fetch_NPC_out,
	output logic [`SUPERSCALAR_WAYS-1:0][31:0] 				fetch_IR_out,
	output logic [`SUPERSCALAR_WAYS-1:0] 					fetch_valid_inst_out,
	
	// Outputs from Fetch/Dispatch Pipeline Register
	output logic [`SUPERSCALAR_WAYS-1:0][`XLEN-1:0] 		fetch_dispatch_NPC_out,
	output logic [`SUPERSCALAR_WAYS-1:0][31:0] 				fetch_dispatch_IR_out,
	output logic [`SUPERSCALAR_WAYS-1:0] 					fetch_dispatch_valid_inst_out,
	
	// Outputs from Dispatch-Stage
	output logic [`SUPERSCALAR_WAYS-1:0][`XLEN-1:0] 		dispatch_NPC_out,
	output logic [`SUPERSCALAR_WAYS-1:0][31:0] 				dispatch_IR_out,
	output logic [`SUPERSCALAR_WAYS-1:0] 					dispatch_valid_inst_out,

	// Outputs from Issue-Stage
	output logic [`SUPERSCALAR_WAYS-1:0][`XLEN-1:0] 		issue_NPC_out,
	output logic [`SUPERSCALAR_WAYS-1:0][31:0] 				issue_IR_out,
	output logic [`SUPERSCALAR_WAYS-1:0] 					issue_valid_inst_out,
	
	// Outputs from Issue/Execute Pipeline Register
	output logic [`SUPERSCALAR_WAYS-1:0][`XLEN-1:0] 		issue_execute_NPC_out,
	output logic [`SUPERSCALAR_WAYS-1:0][31:0] 				issue_execute_IR_out,
	output logic [`SUPERSCALAR_WAYS-1:0] 					issue_execute_valid_inst_out,


	// Outputs of FETCH stage
    output logic [`SUPERSCALAR_WAYS-1:0][`XLEN-1:0] 		proc2Imem_addr,
    output FETCH_DISPATCH_PACKET [`SUPERSCALAR_WAYS-1:0] 	fetch_packet,
    output FETCH_DISPATCH_PACKET [`SUPERSCALAR_WAYS-1:0]    fetch_dispatch_packet,

	// Outputs of the DISPATCH stage
    output DISPATCH_FETCH_PACKET 							dispatch_fetch_packet,
    output DISPATCH_RS_PACKET [`SUPERSCALAR_WAYS-1:0] 		dispatch_rs_packet,
    output DISPATCH_ROB_PACKET [`SUPERSCALAR_WAYS-1:0] 		dispatch_rob_packet,
    output DISPATCH_MAPTABLE_PACKET [`SUPERSCALAR_WAYS-1:0] dispatch_maptable_packet,
    output DISPATCH_FREELIST_PACKET /*[`SUPERSCALAR_WAYS-1:0]*/ dispatch_freelist_packet,

	// Outputs of the ISSUE stage
    // output RS_ISSUE_PACKET [`SUPERSCALAR_WAYS-1:0] 				rs_issue_packet,
    output ISSUE_FU_PACKET [`SUPERSCALAR_WAYS-1:0] 			issue_packet,
    output ISSUE_FU_PACKET [`SUPERSCALAR_WAYS-1:0]          issue_fu_packet,

	// Outputs of the EXECUTE stage
    output FU_RS_PACKET 								    fu_rs_packet,
    output FU_PRF_PACKET [6:0]                              fu_prf_packet,
    output FU_COMPLETE_PACKET [`SUPERSCALAR_WAYS-1:0] 		fu_packet,
    output FU_COMPLETE_PACKET [`SUPERSCALAR_WAYS-1:0]       fu_complete_packet,

	// Outputs of the COMPLETE stage
    output logic 											branch_flush_en,
	output COMPLETE_ROB_PACKET [`SUPERSCALAR_WAYS-1:0] 		complete_rob_packet,
    output CDB_PACKET 										cdb_packet,

	// Outputs of the RETIRE stage
	output logic 											br_recover_enable,
    output MAPTABLE_PACKET 									recovery_maptable,
    output RETIRE_PACKET [`SUPERSCALAR_WAYS-1:0] 			retire_packet,
    output RETIRE_FREELIST_PACKET [`SUPERSCALAR_WAYS-1:0] 	retire_freelist_packet,
    output logic   [`XLEN-1:0]                              target_pc, // target_pc pc for precise state
    output logic                                            retire_wfi_halt,
	output logic [2:0]                                         	done_fu_sel,
	output logic [5:0]										done_fu_out,
	output logic [1:0]										proc2Dmem_command,
	output logic [`XLEN-1:0] proc2Dmem_data,
    output logic [`XLEN-1:0] proc2Dmem_addr,
	output logic [1:0]										proc2Dmem_fu_command,
	output logic [`XLEN-1:0] proc2Dmem_fu_addr

    
    `ifdef TEST_MODE
    , output ROB_PACKET [`N_ROB_ENTRIES-1:0]                rob_table_display
	, output ROB_PACKET [`SUPERSCALAR_WAYS-1:0] 			rob_retire_packet_display

	, output ROB_DISPATCH_PACKET 							rob_dispatch_packet_display
	, output DISPATCH_RS_PACKET [`N_RS_ENTRIES-1:0]       	rs_table_display
	, output RS_ISSUE_PACKET [`SUPERSCALAR_WAYS-1:0] 		rs_issue_packet_display
	, output MAPTABLE_PACKET				                maptable_packet_display
    , output [`N_PHYS_REG-1:0][`XLEN-1:0]					physical_register_display
    `endif

);
	// Outputs of the ROB module
	ROB_PACKET 	[`SUPERSCALAR_WAYS-1:0]						rob_retire_packet;
	ROB_DISPATCH_PACKET 									rob_dispatch_packet;

	// Outputs of the RS module
	RS_DISPATCH_PACKET 										rs_dispatch_packet;
	RS_ISSUE_PACKET [`SUPERSCALAR_WAYS-1:0] 				rs_issue_packet;



	// Outputs of the FREELIST module
	FREELIST_DISPATCH_PACKET 								freelist_dispatch_packet;

	// Outputs of the MAPTABLE module
	MAPTABLE_PACKET 										maptable_packet;

	// Outputs of the PRF module
	logic [63:0][31:0] 										physical_register;

	// Outputs of the ARCH module
	logic [`N_ARCH_REG-1:0][`N_PHYS_REG_BITS-1:0] 			arch_maptable;

	// Clear pipeline
	logic clear;

	assign clear = (reset | br_recover_enable);

	//stall from fu to dispatch
	logic 													stall_fu_2_dispatch;
	

	// Display output
  `ifdef TEST_MODE
	assign rob_retire_packet_display   = rob_retire_packet;
	assign rob_dispatch_packet_display = rob_dispatch_packet;
	assign rs_issue_packet_display	   = rs_issue_packet;
	assign maptable_packet_display	   = maptable_packet;
    assign physical_register_display   = physical_register;
  `endif


	rob rob_0 (
		// Inputs
		.clock(clock), 
		.reset(clear),
		.rob_dispatch_in(dispatch_rob_packet),
		.rob_complete_in(complete_rob_packet), 

		// Outputs
		.rob_dispatch_out(rob_dispatch_packet), 
		.rob_retire_out(rob_retire_packet)
	  `ifdef TEST_MODE
        , .rob_table(rob_table_display)
	  `endif
	);



	rs rs_0 (
		// Inputs
		.clock(clock), 
		.reset(clear),
		.rs_cdb_in(cdb_packet),
		.rs_dispatch_in(dispatch_rs_packet),
		.rs_fu_in(fu_rs_packet),
		.stall(stall_fu_2_dispatch),

		// Outputs
		.rs_issue_out(rs_issue_packet),
		.rs_dispatch_out(rs_dispatch_packet)
	  `ifdef TEST_MODE
		,.rs_table(rs_table_display)
	  `endif
	);



	freelist freelist_0 (
		// Inputs
		.clock(clock), 
		.reset(reset),
        .freelist_dispatch_in(dispatch_freelist_packet), 
        .freelist_retire_in(retire_freelist_packet),
		.br_recover_enable(br_recover_enable),
		.recovery_maptable(recovery_maptable),

		// Outputs
		.freelist_dispatch_out(freelist_dispatch_packet)
		// `ifdef TEST_MODE
		// .freelist_display(freelist_display)
		// .gnt_free_idx_display(gnt_free_idx_display)
	  	// `endif
	);



	maptable maptable_0 (
		// Inputs
		.clock(clock), 
		.reset(reset),
		.br_recover_enable(br_recover_enable),
		.recovery_maptable(recovery_maptable),
		.maptable_cdb_in(cdb_packet),
		.maptable_dispatch_in(dispatch_maptable_packet),

		// Outputs
		.maptable_out(maptable_packet)
	);



	prf prf_0 (
		// Inputs
		.clock(clock), 
		.reset(reset),
		.prf_fu_in(fu_prf_packet), 

		// Outputs
		.physical_register(physical_register)
	);


	
	arch arch_0 (
		// Inputs
		.clock(clock), 
		.reset(reset ),
		.arch_retire_in(retire_packet), 

		// Outputs
		.arch_maptable(arch_maptable)
	);



	always_comb begin
		for (int i = 0; i < `SUPERSCALAR_WAYS; i++) begin
			fetch_NPC_out[i]        = fetch_packet[i].NPC;
			fetch_IR_out[i]         = fetch_packet[i].inst;
			fetch_valid_inst_out[i] = fetch_packet[i].valid;
		end
	end

	fetch fetch_0 (
		// Inputs
		.clock(clock), 
		.reset(reset), 
		.branch_flush_en(br_recover_enable),
		.target_pc(target_pc), 
		.fetch_dispatch_in(dispatch_fetch_packet), 
		.Imem2proc_data(Imem2proc_data),  

		// Outputs
		.PC_out(fetch_PC_out),
		.proc2Imem_addr(proc2Imem_addr), 
		.fetch_dispatch_out(fetch_packet)
	);



	always_comb begin
		for (int i = 0; i < `SUPERSCALAR_WAYS; i++) begin
			fetch_dispatch_NPC_out[i]		 = fetch_dispatch_packet[i].NPC;
			fetch_dispatch_IR_out[i]		 = fetch_dispatch_packet[i].inst;
			fetch_dispatch_valid_inst_out[i] = fetch_dispatch_packet[i].valid;
		end
	end

	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (clear) begin 
			for (int i = 0; i < `SUPERSCALAR_WAYS; i++) begin
				fetch_dispatch_packet[i].inst  <= `SD `NOP;
				fetch_dispatch_packet[i].valid <= `SD `FALSE;
				fetch_dispatch_packet[i].NPC   <= `SD 0;
				fetch_dispatch_packet[i].PC    <= `SD 0;
			end
		end  // if (reset)
		else if (dispatch_fetch_packet.enable) begin
			for (int i = 0; i < `SUPERSCALAR_WAYS; i++) begin
                if (i < (`SUPERSCALAR_WAYS - dispatch_fetch_packet.first_stall_idx))
				    fetch_dispatch_packet[i] <= 
						`SD fetch_dispatch_packet[i + dispatch_fetch_packet.first_stall_idx];
                else 
                    fetch_dispatch_packet[i] <= 
						`SD fetch_packet[i + dispatch_fetch_packet.first_stall_idx - `SUPERSCALAR_WAYS];
            end
		end  // if (~reset & dispatch_fetch_out.enable)
        else fetch_dispatch_packet <= `SD fetch_packet;
	end // always



	always_comb begin
		for (int i = 0; i < `SUPERSCALAR_WAYS; i++) begin
			dispatch_NPC_out[i]        = dispatch_rs_packet[i].NPC;
			dispatch_IR_out[i]         = dispatch_rs_packet[i].inst;
			dispatch_valid_inst_out[i] = dispatch_rs_packet[i].valid;
		end
	end

    dispatch dispatch_0 (
		// Inputs
        .dispatch_maptable_in(maptable_packet),
        .dispatch_rs_in(rs_dispatch_packet),
        .dispatch_rob_in(rob_dispatch_packet),
        .dispatch_freelist_in(freelist_dispatch_packet),
        .dispatch_fetch_in(fetch_dispatch_packet),
        .branch_flush_en(br_recover_enable),
    	.cdb_in(cdb_packet),
		.stall_from_fu(stall_fu_2_dispatch),

		// Outputs
        .dispatch_rs_out(dispatch_rs_packet),
        .dispatch_rob_out(dispatch_rob_packet),
        .dispatch_maptable_out(dispatch_maptable_packet),
        .dispatch_fetch_out(dispatch_fetch_packet),
        .dispatch_freelist_out(dispatch_freelist_packet)
    );



	always_comb begin
		for (int i = 0; i < `SUPERSCALAR_WAYS; i++) begin
			issue_NPC_out[i]        = issue_packet[i].NPC;
			issue_IR_out[i]         = issue_packet[i].inst;
			issue_valid_inst_out[i] = issue_packet[i].valid;
		end
	end

	issue issue_0 (
		// Inputs
        .issue_rs_in(rs_issue_packet),
        .physical_register(physical_register), 

		// Outputs
		.issue_fu_out(issue_packet)
	);



	always_comb begin
		for (int i = 0; i < `SUPERSCALAR_WAYS; i++) begin
			issue_execute_NPC_out[i]        = issue_fu_packet[i].NPC;
			issue_execute_IR_out[i]         = issue_fu_packet[i].inst;
			issue_execute_valid_inst_out[i] = issue_fu_packet[i].valid;
		end
	end

	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (clear) begin 
			for (int i = 0; i < `SUPERSCALAR_WAYS; i++) begin
				issue_fu_packet[i].inst  <= `SD `NOP;
				issue_fu_packet[i].valid <= `SD `FALSE;
				issue_fu_packet[i].NPC   <= `SD 0;
				issue_fu_packet[i].PC    <= `SD 0;
			end
		end  // if (reset)
		else begin
			for (int i = 0; i < `SUPERSCALAR_WAYS; i++)
                issue_fu_packet[i] <= `SD issue_packet[i];
            end  // if (~reset)
	end // always


	fu fu_0 (
		// Inputs
		.clock(clock),
		.reset(clear),
		.fu_issue_in(issue_fu_packet),
		.mem2proc_data(mem2proc_data),

		// Outputs
		.fu_rs_out(fu_rs_packet),
		.fu_complete_out(fu_packet),
		.fu_prf_out(fu_prf_packet),
		.proc2Dmem_fu_command(proc2Dmem_fu_command),
		.proc2Dmem_fu_addr(proc2Dmem_fu_addr),
		.stall_fu_2_dispatch(stall_fu_2_dispatch),
		.done_fu_sel(done_fu_sel),
		.done_fu_out(done_fu_out)
	);



	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (clear) begin 
			for (int i = 0; i < `SUPERSCALAR_WAYS; i++) begin
				fu_complete_packet[i].rd_mem 		 <= `SD 0;
				fu_complete_packet[i].wr_mem 		 <= `SD 0;
				fu_complete_packet[i].ar_idx	 <= `SD `ZERO_REG;
				fu_complete_packet[i].dest_value <= `SD 0;
			end
		end  // if (reset)
		else begin
			for (int i = 0; i < `SUPERSCALAR_WAYS; i++)
				fu_complete_packet[i] <= `SD fu_packet[i]; 
		end  // if (~reset)
	end // always



	complete complete_0 (
		// Inputs
        .complete_fu_in(fu_complete_packet),

		// Outputs
		.complete_rob_out(complete_rob_packet),
		.cdb_out(cdb_packet)
	);



    assign halt = retire_wfi_halt;


	retire retire_0 (
		// Inputs 
        .retire_rob_in(rob_retire_packet),
        .arch_maptable(arch_maptable),

		// Outputs
        .recovery_maptable(recovery_maptable),
        .retire_out(retire_packet),
        .retire_freelist_out(retire_freelist_packet),

        // .br_recover_enable(br_recover_enable_r),
        // .target_pc(target_pc_r),
		.br_recover_enable(br_recover_enable),
        .target_pc(target_pc),

        .wfi_halt(retire_wfi_halt),

		//memory access
		.proc2Dmem_command(proc2Dmem_command),
		.proc2Dmem_addr(proc2Dmem_addr),
		.proc2Dmem_data(proc2Dmem_data)
    );


	//////////////////////////////// mem retire


	always_comb begin
        if(proc2Dmem_fu_command != BUS_NONE) begin
			proc2mem_command = proc2Dmem_fu_command;
            proc2mem_addr    = proc2Dmem_fu_addr;
		end
		else if (proc2Dmem_command != BUS_NONE ) begin // read or write DATA from memory
			proc2mem_command = proc2Dmem_command;
            proc2mem_addr    = proc2Dmem_addr; 
            //proc2mem_size    = proc2Dmem_size;  // size is never DOUBLE in project 3
        end else begin                          // read an INSTRUCTION from memory
            proc2mem_command = BUS_LOAD;
            proc2mem_addr    = proc2Imem_addr;
            //proc2mem_size    = DOUBLE;          // instructions load a full memory line (64 bits)
        end
        	proc2mem_data = {32'b0, proc2Dmem_data};
    end
endmodule  // module pipeline