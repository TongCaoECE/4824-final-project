`include "../test/mem.sv"


module testbench;
    // //Internal Wires
    logic [63:0] tb_mem [`MEM_64BIT_LINES - 1:0];
    string filename;
    //counter used for when pipeline infinite loops, forces termination
    logic [63:0] debug_counter;
    
    logic [31:0] clock_count;
    logic [31:0] instr_count;
    int wb_fileno;
    int cpi_fileno;
    int pipe_out;
    
    EXCEPTION_CODE pipeline_error_status;
    
    // //Module Wires
    logic /*clock, reset, */enable;
    //
    // //CDB_PACKET [(`N-1):0] CDB;
    //
    // logic [$clog2(`N+1)-1:0] ROB_free_entries_left;
    // logic [$clog2(`N+1)-1:0] freeList_free_entries_left;
    // logic [$clog2(`N+1)-1:0] RS_free_entries_left;
    //
    //
    //
    // logic [(`N-1):0] [`XLEN-1:0] RRAT_reg_data;
    //
    // // Wire for writeback.out
    logic [`SUPERSCALAR_WAYS_BITS-1:0] ROB_entries_retired;
   // logic [(`SUPERSCALAR_WAYS-1):0] [$clog2(`N_ARCH_REG_BITS)-1:0] ar_idx;//dest_reg_retire
    //logic [(`SUPERSCALAR_WAYS-1):0] [`XLEN-1:0] target_pc; //ROB_PC;
    //logic [(`SUPERSCALAR_WAYS-1):0] [`XLEN-1:0] ROB_retire_data;              // data of retiring entries
    // // Misspec
    // logic ROBhead_isMisspeculated;
    // logic [`XLEN-1:0] ROB_NPC;
    //
    //
    // // Debug signals
    // ROB_PACKET [`ROB_SIZE-1:0] _ROBTable;
    // logic [$clog2(`ROB_SIZE)-1:0] _ROBhead, _ROBtail, _ROBnext_head, _ROBnext_tail;
    //
    // RAT_PACKET [`ARCH_REG_SIZE-1:0] _RATOutput;
    // logic [`ARCH_REG_SIZE-1:0] [$clog2(`PHYSICAL_REG_SIZE)-1:0] _RRAT_data;
    //
    // logic [`FREELIST_SIZE-1:0] [$clog2(`PHYSICAL_REG_SIZE)-1:0] _freeListTable;
    // logic [$clog2(`FREELIST_SIZE)-1:0] _FLhead, _FLnext_head, _FLtail, _FLnext_tail;
    //
    // logic [`PHYSICAL_REG_SIZE-1:0] [`XLEN-1:0] registers_debug;
    //
    // RS_PACKET [(`RS_SIZE-1):0] _RS_Table;
    // RS_ISSUE_PACKET [(`FU_NUMS-1):0] _rs_packet_out;
    //
    // logic [1:0] _alus_en;
    // ALU_OUT_PACKET _alu_packet_out_0;
    // ALU_OUT_PACKET _alu_packet_out_1;
    // BR_OUT_PACKET _br_packet_out;
    // MEM_OUT_PACKET _mem_packet_out;
    // LSQ_OUT_PACKET _lsq_packet_out;
    // MULT_OUT_PACKET _mult_packet_out;
    // ISSUE_EX_PACKET [`FU_NUMS-1:0] _issue_ex_packet_out;
    //
    // CDB_PACKET [(`N-1):0] _CDB;
    //
    // logic [`FU_NUMS-1:0] [`XLEN-1:0] _rda_out;
    // logic [`FU_NUMS-1:0] [`XLEN-1:0] _rdb_out;
    //
    //


    //project 3
    logic clock, reset;
    logic [`SUPERSCALAR_WAYS-1:0][63:0]         Imem2proc_data;
    logic [`SUPERSCALAR_WAYS-1:0][3:0]  	    mem2proc_response;
    logic [63:0]                                  mem2proc_data;
    logic [`SUPERSCALAR_WAYS-1:0][3:0]  	    mem2proc_tag;
    logic [1:0]  							    proc2mem_command;
    logic [`XLEN-1:0] 					        proc2mem_addr;
    logic [63:0] 							    proc2mem_data;
    logic        							    halt;
    logic [2:0]  							    inst_count;

    //Test Hook

    // Outputs from Fetch-Stage
    logic [`SUPERSCALAR_WAYS-1:0][`XLEN-1:0] 	fetch_PC_out;
    logic [`SUPERSCALAR_WAYS-1:0][`XLEN-1:0] 	fetch_NPC_out;
    logic [`SUPERSCALAR_WAYS-1:0][31:0] 		fetch_IR_out;
    logic [`SUPERSCALAR_WAYS-1:0] 				fetch_valid_inst_out;

    // Outputs from Fetch/Dispatch Pipeline Register
    logic [`SUPERSCALAR_WAYS-1:0][`XLEN-1:0] 	fetch_dispatch_NPC_out;
    logic [`SUPERSCALAR_WAYS-1:0][31:0] 		fetch_dispatch_IR_out;
    logic [`SUPERSCALAR_WAYS-1:0] 				fetch_dispatch_valid_inst_out;


    // Outputs from Dispatch-Stage
    logic [`SUPERSCALAR_WAYS-1:0][`XLEN-1:0] 	dispatch_NPC_out;
    logic [`SUPERSCALAR_WAYS-1:0][31:0] 		dispatch_IR_out;
    logic [`SUPERSCALAR_WAYS-1:0] 				dispatch_valid_inst_out;

    // Outputs from Issue-Stage
    logic [`SUPERSCALAR_WAYS-1:0][`XLEN-1:0] 	issue_NPC_out;
    logic [`SUPERSCALAR_WAYS-1:0][31:0] 		issue_IR_out;
    logic [`SUPERSCALAR_WAYS-1:0] 				issue_valid_inst_out;

    // Outputs from Issue/Execute Pipeline Register
    logic [`SUPERSCALAR_WAYS-1:0][`XLEN-1:0] 	issue_execute_NPC_out;
    logic [`SUPERSCALAR_WAYS-1:0][31:0] 		issue_execute_IR_out;
    logic [`SUPERSCALAR_WAYS-1:0] 				issue_execute_valid_inst_out;


    // Outputs of FETCH stage
    logic [`SUPERSCALAR_WAYS-1:0][`XLEN-1:0]         proc2Imem_addr;
    FETCH_DISPATCH_PACKET [`SUPERSCALAR_WAYS-1:0]    fetch_packet;
    FETCH_DISPATCH_PACKET [`SUPERSCALAR_WAYS-1:0]    fetch_dispatch_packet;

    // Outputs of the DISPATCH stage
    DISPATCH_FETCH_PACKET                            dispatch_fetch_packet;
    DISPATCH_RS_PACKET [`SUPERSCALAR_WAYS-1:0]       dispatch_rs_packet;
    DISPATCH_ROB_PACKET [`SUPERSCALAR_WAYS-1:0]      dispatch_rob_packet;
    DISPATCH_MAPTABLE_PACKET [`SUPERSCALAR_WAYS-1:0] dispatch_maptable_packet;
    DISPATCH_FREELIST_PACKET 			             dispatch_freelist_packet;

    // Outputs of the ISSUE stage
    ISSUE_FU_PACKET [`SUPERSCALAR_WAYS-1:0]          issue_packet;
    ISSUE_FU_PACKET [`SUPERSCALAR_WAYS-1:0]          issue_fu_packet;

    // Outputs of the EXECUTE stage
    FU_RS_PACKET                                     fu_rs_packet;
    FU_PRF_PACKET [6:0]                             fu_prf_packet;
    FU_COMPLETE_PACKET [`SUPERSCALAR_WAYS-1:0]       fu_packet;
    FU_COMPLETE_PACKET [`SUPERSCALAR_WAYS-1:0]       fu_complete_packet;

    // Outputs of the COMPLETE stage
    logic                                            branch_flush_en;
    logic [`XLEN-1:0]                                complete_target_pc;
    COMPLETE_ROB_PACKET [`SUPERSCALAR_WAYS-1:0]      complete_rob_packet;
    CDB_PACKET                                       cdb_packet;

    // Outputs of the RETIRE stage
    logic                                            br_recover_enable;
    MAPTABLE_PACKET                                  recovery_maptable;
    RETIRE_PACKET [`SUPERSCALAR_WAYS-1:0]            retire_packet;
    RETIRE_FREELIST_PACKET [`SUPERSCALAR_WAYS-1:0]   retire_freelist_packet;

    logic retire_wfi_halt;
    logic [2:0]                                         	done_fu_sel;
    logic [5:0]  done_fu_out;
    logic [1:0] proc2Dmem_command;
    logic [`XLEN-1:0] proc2Dmem_addr;
    logic [`XLEN-1:0] proc2Dmem_data;
    logic [1:0] proc2Dmem_fu_command;
    logic [`XLEN-1:0] proc2Dmem_fu_addr;


    // Debug display
    `ifdef TEST_MODE
    ROB_PACKET 	[`N_ROB_ENTRIES-1:0]                rob_table_display;
    ROB_PACKET 	[`SUPERSCALAR_WAYS-1:0]		        rob_retire_packet;
    ROB_DISPATCH_PACKET 	                        rob_dispatch_packet;
    RS_ISSUE_PACKET [`SUPERSCALAR_WAYS-1:0] 		rs_issue_packet;
    DISPATCH_RS_PACKET [`N_RS_ENTRIES-1:0]       	rs_table;
    MAPTABLE_PACKET					                maptable_packet;
    logic [`N_PHYS_REG-1:0][`XLEN-1:0]              physical_register_display;
    `endif

    mem memory (
		// Inputs
		.clk               (clock),
		.proc2mem_command  (proc2mem_command),
		.proc2mem_addr     (proc2mem_addr),
		.proc2mem_data     (proc2mem_data),
        `ifndef CACHE_MODE
		    .proc2mem_size     (proc2mem_size),
        `endif

		// Outputs

		.mem2proc_response (mem2proc_response),
		.mem2proc_data     (mem2proc_data),
		.mem2proc_tag      (mem2proc_tag)
	);



    pipeline DUT (
                    .clock(clock),
                    .reset(reset),
                    .mem2proc_response(mem2proc_response),
                    .mem2proc_data(mem2proc_data),
                    .Imem2proc_data(Imem2proc_data),
                    .mem2proc_tag(mem2proc_tag),
                    .proc2mem_command(proc2mem_command),
                    .proc2mem_addr(proc2mem_addr),
                    .proc2mem_data(proc2mem_data),
                    .halt(halt),
                    .inst_count(inst_count) //projec3 pipeline

                    // Outputs from Fetch-Stage 
                    ,.fetch_PC_out(fetch_PC_out)
                    ,.fetch_NPC_out(fetch_NPC_out)
                    ,.fetch_IR_out(fetch_IR_out)
                    ,.fetch_valid_inst_out(fetch_valid_inst_out)

                    // Outputs from Fetch/Dispatch Pipeline Register
                    ,.fetch_dispatch_NPC_out(fetch_dispatch_NPC_out)
                    ,.fetch_dispatch_IR_out(fetch_dispatch_IR_out)
                    ,.fetch_dispatch_valid_inst_out(fetch_dispatch_valid_inst_out)

                    // Outputs from Dispatch-Stage
                    ,.dispatch_NPC_out(dispatch_NPC_out)
                    ,.dispatch_IR_out(dispatch_IR_out)
                    ,.dispatch_valid_inst_out(dispatch_valid_inst_out)


                    // Outputs from Issue-Stage
                    ,.issue_NPC_out(issue_NPC_out)
                    ,.issue_IR_out(issue_IR_out)
                    ,.issue_valid_inst_out(issue_valid_inst_out)

                    // Outputs from Issue/Execute Pipeline Register
                    ,.issue_execute_NPC_out(issue_execute_NPC_out)
                    ,.issue_execute_IR_out(issue_execute_IR_out)
                    ,.issue_execute_valid_inst_out(issue_execute_valid_inst_out),



                    // Outputs of FETCH stage
                    .proc2Imem_addr(proc2Imem_addr),
                    .fetch_packet(fetch_packet),
                    .fetch_dispatch_packet(fetch_dispatch_packet),

                    // Outputs of the DISPATCH stage
                    .dispatch_fetch_packet(dispatch_fetch_packet),
                    .dispatch_rs_packet(dispatch_rs_packet),
                    .dispatch_rob_packet(dispatch_rob_packet),
                    .dispatch_maptable_packet(dispatch_maptable_packet),
                    .dispatch_freelist_packet(dispatch_freelist_packet),

                    // Outputs of the ISSUE stage
                    .issue_packet(issue_packet),
                    .issue_fu_packet(issue_fu_packet),

                    // Outputs of the EXECUTE stage
                    .fu_rs_packet(fu_rs_packet),
                    .fu_prf_packet(fu_prf_packet),
                    .fu_packet(fu_packet),
                    .fu_complete_packet(fu_complete_packet),

                    // Outputs of the COMPLETE stage
                    .branch_flush_en(branch_flush_en),
                    .target_pc(complete_target_pc),
                    .complete_rob_packet(complete_rob_packet),
                    .cdb_packet(cdb_packet),

                    // Outputs of the RETIRE stage
                    .br_recover_enable(br_recover_enable),
                    .recovery_maptable(recovery_maptable),
                    .retire_packet(retire_packet),
                    .retire_freelist_packet(retire_freelist_packet),
		            .retire_wfi_halt(retire_wfi_halt),

                    //done_fu_sel from fu
                    .done_fu_sel(done_fu_sel),
                    .done_fu_out(done_fu_out),

                    .proc2Dmem_command(proc2Dmem_command),
                    .proc2Dmem_addr(proc2Dmem_addr),
                    .proc2Dmem_data(proc2Dmem_data),
                    .proc2Dmem_fu_command(proc2Dmem_fu_command),
		            .proc2Dmem_fu_addr(proc2Dmem_fu_addr)

                    // Testmode display
                    `ifdef TEST_MODE
                    ,.rob_table_display(rob_table_display)
                    ,.rob_retire_packet_display(rob_retire_packet)
                    ,.rob_dispatch_packet_display(rob_dispatch_packet)
		            ,.rs_issue_packet_display(rs_issue_packet)

		            ,.rs_table_display(rs_table)
		            ,.maptable_packet_display(maptable_packet)
                    ,.physical_register_display(physical_register_display)
                    `endif
    );

    function string fu_name(FU_SELECT value);
        case(value)
            LS_1: return "LS_1";
            LS_2: return "LS_2";
            ALU_1: return "ALU_1";
            ALU_2: return "ALU_2";
            ALU_3: return "ALU_3";
            MULT_1: return "MULT_1";
            MULT_2: return "MULT_2";
            BRANCH: return "BRANCH";
            FU_NONE: return "";
        endcase
    endfunction

    function string op_name(OP_SELECT value);
        case(value)
            alu: return "alu";
            mult: return "mult";
            br: return "brch";
            OP_NONE: return "";
        endcase
    endfunction

    function string inst_name(INST value, logic valid);
        if (valid) begin
            casez(value)
                `NOP: return "NOP";
                `RV32_LUI: return "LUI";
                `RV32_AUIPC: return "AUIPC";
                `RV32_JAL: return "JAL";
                `RV32_JALR: return "JALR";
                `RV32_BEQ: return "BEQ";
                `RV32_BNE: return "BNE";
                `RV32_BLT: return "BLT";
                `RV32_BGE: return "BGE";
                `RV32_BLTU: return "BLTU";
                `RV32_BGEU: return "BGEU";
                `RV32_LB: return "LB";
                `RV32_LH: return "LH";
                `RV32_LW: return "LW";
                `RV32_LBU: return "LBU";
                `RV32_LHU: return "LHU";
                `RV32_SB: return "SB";
                `RV32_SH: return "SH";
                `RV32_SW: return "SW";
                `RV32_ADDI: return "ADDI";
                `RV32_SLTI: return "SLTI";
                `RV32_SLTIU: return "SLTIU";
                `RV32_ANDI: return "ANDI";
                `RV32_ORI: return "ORI";
                `RV32_XORI: return "XORI";
                `RV32_SLLI: return "SLLI";
                `RV32_SRLI: return "SRLI";
                `RV32_SRAI: return "SRAI";
                `RV32_ADD: return "ADD";
                `RV32_SUB: return "SUB";
                `RV32_SLT: return "SLT";
                `RV32_SLTU: return "SLTU";
                `RV32_AND: return "AND";
                `RV32_OR: return "OR";
                `RV32_XOR: return "XOR";
                `RV32_SLL: return "SLL";
                `RV32_SRL: return "SRL";
                `RV32_SRA: return "SRA";
                `RV32_MUL: return "MUL";
                `RV32_MULH: return "MULH";
                `RV32_MULHSU: return "MULHSU";
                `RV32_MULHU: return "MULHU";
                `RV32_CSRRW: return "CSRRW";
                `RV32_CSRRS: return "CSRRS";
                `RV32_CSRRC: return "CSRRC";
                `WFI: return "WFI";
            endcase
        end else
            return "xxx";
    endfunction


    function dump_output;
        // Modules
            $fdisplay(pipe_out, "ROB Table");
                $fdisplay(pipe_out, "  | t | to| ar|c|h|p|targetPC|  dest_val |   NPC  ");
                for (int i = 0; i < `N_ROB_ENTRIES; i++)
                    $fdisplay(pipe_out, "%2d| %2d| %2d| %2d|%b|%b|%b|%h| %10d|%x",
                        i, rob_table_display[i].t_idx, rob_table_display[i].told_idx, rob_table_display[i].ar_idx, rob_table_display[i].complete, rob_table_display[i].halt, rob_table_display[i].precise_state_enable, rob_table_display[i].target_pc, rob_table_display[i].dest_value, rob_table_display[i].NPC);

            $fdisplay(pipe_out, "Physical Register File");
                $fdisplay(pipe_out, "  |  value  |  |  value  ");
                for (int i = 0; i < (`N_PHYS_REG / 2); i++)
                    $fdisplay(pipe_out,"%2d| %h|%2d| %h", 
                        i, physical_register_display[i], i + 32, physical_register_display[i + 32]);

            $fdisplay(pipe_out, "RS Table");
                // NPC | PC | reg1_pr_idx | reg2_pr_idx | pr_idx | rob_idx | ar_idx | inst | alu_func | mult_func
                $fdisplay(pipe_out, "  |      NPC|       PC| r1| r2| pr|rob| ar|      inst     |alu|mul");
                for (int i = 0; i < `N_RS_ENTRIES ; i++)
                    $fdisplay(pipe_out, "%2d|%h|%h| %2d| %2d| %2d| %2d| %2d|%5s: %h| %d| %d",
                        i, rs_table[i].NPC, rs_table[i].PC, rs_table[i].reg1_pr_idx, rs_table[i].reg2_pr_idx, rs_table[i].pr_idx, rs_table[i].rob_idx, rs_table[i].ar_idx, inst_name(rs_table[i].inst, rs_table[i].valid), rs_table[i].inst, rs_table[i].alu_func, rs_table[i].mult_func);
                
                $fdisplay(pipe_out, "  |asl|bsl|fu_sel|opsl|r1+|r2+|rdm|wrm|cb|ub|halt|ilg|csr_op|vld");
                for (int i = 0; i < `N_RS_ENTRIES; i++)
                    $fdisplay(pipe_out, "%2d| %2d| %2d|%6s|%4s| %b | %b | %b | %b | %b| %b|  %b | %b |   %b  | %b ",
                        i, rs_table[i].opa_select, rs_table[i].opb_select, fu_name(rs_table[i].fu_sel), op_name(rs_table[i].op_sel), rs_table[i].reg1_ready, rs_table[i].reg2_ready, rs_table[i].rd_mem, rs_table[i].wr_mem, rs_table[i].cond_branch, rs_table[i].uncond_branch, rs_table[i].halt, rs_table[i].illegal, rs_table[i].csr_op, rs_table[i].valid);

            $fdisplay(pipe_out, "Maptable");
                for (int i = 0; i < `N_ARCH_REG; i++) begin
                    if (maptable_packet.done[i])
                        $fdisplay(pipe_out, "  %2d+ ", 
                            maptable_packet.map[i]);
                    else
                        $fdisplay(pipe_out, "  %2d  ", 
                            maptable_packet.map[i]);
                end

        $fdisplay(pipe_out, "FETCH");
            for (int i = 0; i < `SUPERSCALAR_WAYS; i++)
                $fdisplay(pipe_out, " %1d | %8h", 
                    i, proc2Imem_addr[i]);
            $fdisplay(pipe_out, " |      inst     |   NPC   |    PC   |vld");
            for (int i = 0; i < `SUPERSCALAR_WAYS; i++)
                $fdisplay(pipe_out, "%1d|%5s: %h| %h| %h| %b ", 
                    i, inst_name(fetch_packet[i].inst, fetch_packet[i].valid), fetch_packet[i].inst, fetch_packet[i].NPC, fetch_packet[i].PC, fetch_packet[i].valid);
            $fdisplay(pipe_out, " |      inst     |   NPC   |    PC   |vld");
            for (int i = 0; i < `SUPERSCALAR_WAYS; i++)
                $fdisplay(pipe_out, "%1d|%5s: %h| %h| %h| %b ", 
                    i, inst_name(fetch_dispatch_packet[i].inst, fetch_dispatch_packet[i].valid), fetch_dispatch_packet[i].inst, fetch_dispatch_packet[i].NPC, fetch_dispatch_packet[i].PC, fetch_dispatch_packet[i].valid);

        $fdisplay(pipe_out, "DISPATCH");
            $fdisplay(pipe_out, " |stall|new");
            // rob_dispatch_packet
            for (int i = 0; i < `SUPERSCALAR_WAYS; i++)
                $fdisplay(pipe_out, "%1d|  %b  | %2d", 
                    i, rob_dispatch_packet.stall[i], rob_dispatch_packet.new_entry_idx[i]);

            // dispatch_fetch_packet
            $fdisplay(pipe_out, "first_stall_idx: %2d", 
                dispatch_fetch_packet.first_stall_idx);
            $fdisplay(pipe_out, "enable: %b", 
                dispatch_fetch_packet.enable);

            // dispatch_rs_packet
            $fdisplay(pipe_out, " |      inst     |   NPC   |    PC   | r1| r2| pr|rob| ar|asl|bsl|fu_sel|opsl|alu|mul|r1+|r2+|rdm|wrm|cb|ub|halt|ilg|csr_op|en|vld");
            for (int i = 0; i < `SUPERSCALAR_WAYS ; i++)
                $fdisplay(pipe_out, "%1d|%5s: %h| %h| %h| %2d| %2d| %2d| %2d| %2d| %2d| %2d|%6s|%4s| %d| %d| %b | %b | %b | %b | %b| %b|  %b | %b |   %b  | %b| %b ",
                    i, 
                    inst_name(dispatch_rs_packet[i].inst, dispatch_rs_packet[i].valid), dispatch_rs_packet[i].inst, dispatch_rs_packet[i].NPC, dispatch_rs_packet[i].PC, dispatch_rs_packet[i].reg1_pr_idx, dispatch_rs_packet[i].reg2_pr_idx, dispatch_rs_packet[i].pr_idx, dispatch_rs_packet[i].rob_idx, dispatch_rs_packet[i].ar_idx, 
                    dispatch_rs_packet[i].opa_select, dispatch_rs_packet[i].opb_select, fu_name(dispatch_rs_packet[i].fu_sel), op_name(dispatch_rs_packet[i].op_sel), dispatch_rs_packet[i].alu_func, dispatch_rs_packet[i].mult_func,
                    dispatch_rs_packet[i].reg1_ready, dispatch_rs_packet[i].reg2_ready, dispatch_rs_packet[i].rd_mem, dispatch_rs_packet[i].wr_mem, dispatch_rs_packet[i].cond_branch, dispatch_rs_packet[i].uncond_branch, dispatch_rs_packet[i].halt, dispatch_rs_packet[i].illegal, dispatch_rs_packet[i].csr_op, dispatch_rs_packet[i].enable, dispatch_rs_packet[i].valid
                    );

            // dispatch_rob_packet
            $fdisplay(pipe_out, " | t | to| ar|e|   NPC   ");
            for (int i = 0; i < `SUPERSCALAR_WAYS; i++)
                $fdisplay(pipe_out, "%1d| %2d| %2d| %2d|%b| %h", 
                    i, dispatch_rob_packet[i].t_idx, dispatch_rob_packet[i].told_idx, dispatch_rob_packet[i].ar_idx, dispatch_rob_packet[i].enable, dispatch_rob_packet[i].NPC);
            
            // dispatch_maptable_packet
                $fdisplay(pipe_out, " | pr| ar|e");
                for (int i = 0; i < `SUPERSCALAR_WAYS; i++)
                    $fdisplay(pipe_out, "%1d| %2d| %2d|%b", 
                        i, dispatch_maptable_packet[i].pr_idx, dispatch_maptable_packet[i].ar_idx, dispatch_maptable_packet[i].enable);

        $fdisplay(pipe_out, "ISSUE");

            // rs_issue_packet
            $fdisplay(pipe_out, " |      inst     |   NPC   |    PC   | r1| r2| pr|rob| ar|asl|bsl|fu_sel|opsl|alu|mul|rdm|wrm|cb|ub|halt|ilg|csr_op|vld");
            for (int i = 0; i < `SUPERSCALAR_WAYS; i++)
                $fdisplay(pipe_out, "%1d|%5s: %h| %h| %h| %2d| %2d| %2d| %2d| %2d| %2d| %2d|%6s|%4s| %d| %d| %b | %b | %b| %b|  %b | %b |   %b  | %b ", 
                    i, inst_name(issue_packet[i].inst, issue_packet[i].valid), issue_packet[i].inst, issue_packet[i].NPC, issue_packet[i].PC, rs_issue_packet[i].reg1_pr_idx, rs_issue_packet[i].reg2_pr_idx, issue_packet[i].pr_idx, issue_packet[i].rob_idx, issue_packet[i].ar_idx, 
                    issue_packet[i].opa_select, issue_packet[i].opb_select, fu_name(issue_packet[i].fu_select), op_name(issue_packet[i].op_sel), issue_packet[i].alu_func, issue_packet[i].mult_func,
                    issue_packet[i].rd_mem, issue_packet[i].wr_mem, issue_packet[i].cond_branch, issue_packet[i].uncond_branch, issue_packet[i].halt, issue_packet[i].illegal, issue_packet[i].csr_op, issue_packet[i].valid
                    );
            
            // issue
            $fdisplay(pipe_out, " | rs1_value| rs2_value");
            for (int i = 0; i < `SUPERSCALAR_WAYS; i++)
                $fdisplay(pipe_out, "%1d|%d|%d", 
                    i, issue_packet[i].rs1_value, issue_packet[i].rs2_value);

            // issue_fu_packet
            $fdisplay(pipe_out, " |      inst     |   NPC   |    PC   | rs1_value| rs2_value| pr|rob| ar|asl|bsl|fu_sel|opsl|alu|mul|rdm|wrm|cb|ub|halt|ilg|csr_op|vld");
            for (int i = 0; i < `SUPERSCALAR_WAYS; i++)
                $fdisplay(pipe_out, "%1d|%5s: %h| %h| %h|%d|%d| %2d| %2d| %2d| %2d| %2d|%6s|%4s| %d| %d| %b | %b | %b| %b|  %b | %b |   %b  | %b ", 
                    i, inst_name(issue_fu_packet[i].inst, issue_fu_packet[i].valid), issue_fu_packet[i].inst, issue_fu_packet[i].NPC, issue_fu_packet[i].PC, issue_fu_packet[i].rs1_value, issue_fu_packet[i].rs2_value, issue_fu_packet[i].pr_idx, issue_fu_packet[i].rob_idx, issue_fu_packet[i].ar_idx, 
                    issue_fu_packet[i].opa_select, issue_fu_packet[i].opb_select, fu_name(issue_fu_packet[i].fu_select), op_name(issue_fu_packet[i].op_sel), issue_fu_packet[i].alu_func, issue_fu_packet[i].mult_func,
                    issue_fu_packet[i].rd_mem, issue_fu_packet[i].wr_mem, issue_fu_packet[i].cond_branch, issue_fu_packet[i].uncond_branch, issue_fu_packet[i].halt, issue_fu_packet[i].illegal, issue_fu_packet[i].csr_op, issue_fu_packet[i].valid
                    );


        $fdisplay(pipe_out, "EXECUTE");

            // fu_packet
            $fdisplay(pipe_out, " | pr|rob| ar|targetPC|dest_value|rdm|wrm|halt|tkb|sel|vld| done | opa | opb |");
            for (int i = 0; i < `SUPERSCALAR_WAYS; i++)
                $fdisplay(pipe_out, "%1d| %2d| %2d| %2d|%h|%d| %b | %b |  %b | %b | %d | %b |%6b | %h | %h ",
                    i, fu_packet[i].pr_idx, fu_packet[i].rob_idx, fu_packet[i].ar_idx, fu_packet[i].target_pc, fu_packet[i].dest_value, fu_packet[i].rd_mem, fu_packet[i].wr_mem, fu_packet[i].halt, fu_packet[i].take_branch,  done_fu_sel, fu_packet[i].valid , done_fu_out, fu_packet[i].opa, fu_packet[i].opb);


            // fu_rs_packet
            $fdisplay(pipe_out, "    alu_1: %b ", fu_rs_packet.alu_1);
            $fdisplay(pipe_out, "    alu_2: %b ", fu_rs_packet.alu_2);
            $fdisplay(pipe_out, "    alu_3: %b ", fu_rs_packet.alu_3);
            $fdisplay(pipe_out, "   mult_1: %b ", fu_rs_packet.mult_1);
            $fdisplay(pipe_out, "   mult_2: %b ", fu_rs_packet.mult_2);
            $fdisplay(pipe_out, " branch_1: %b ", fu_rs_packet.branch_1);

            // fu_prf_packet
            $fdisplay(pipe_out, "id|  value   ");
            for (int i = 0; i < 7; i++) 
                $fdisplay(pipe_out,"%2d|%d",
                    fu_prf_packet[i].idx, fu_prf_packet[i].value);

        $fdisplay(pipe_out, "COMPLETE");

            // complete_rob_packet
            $fdisplay(pipe_out," |rob| dest_value|c");
            for (int i = 0; i < `SUPERSCALAR_WAYS; i++)
                $fdisplay(pipe_out, "%1d| %2d| %d|%b", 
                    i, complete_rob_packet[i].rob_idx, complete_rob_packet[i].dest_value, complete_rob_packet[i].complete);

            // cdb_packet
            $fdisplay(pipe_out," | t ");
            for (int i = 0; i < `SUPERSCALAR_WAYS; i++)
                $fdisplay(pipe_out, "%1d| %2d", i, cdb_packet.t_idx[i]);


        $fdisplay(pipe_out, "RETIRE");
            
            // rob_retire_packet
            $fdisplay(pipe_out, " | t|to|ar|halt|pr|cp|targetPC| dest_value|   NPC  ");
            for (int i = 0; i < `SUPERSCALAR_WAYS; i++)
                $fdisplay(pipe_out, "%1d|%2d|%2d|%2d|  %b | %b| %b|%h| %d|%h", 
                    i, rob_retire_packet[i].t_idx, rob_retire_packet[i].told_idx,rob_retire_packet[i].ar_idx,rob_retire_packet[i].halt, rob_retire_packet[i].precise_state_enable, rob_retire_packet[i].complete, rob_retire_packet[i].target_pc, rob_retire_packet[i].dest_value ,rob_retire_packet[i].NPC);
            
            // retire_packet
            $fdisplay(pipe_out, " | t|ar|   NPC  |c");
            for (int i = 0; i < `SUPERSCALAR_WAYS; i++)
                $fdisplay(pipe_out, "%1d|%2d|%2d|%h|%b",
                    i, retire_packet[i].t_idx, retire_packet[i].ar_idx, retire_packet[i].NPC, retire_packet[i].complete );

            // retire_freelist_packet
            $fdisplay(pipe_out, " | told | vld ");
            for (int i = 0; i < `SUPERSCALAR_WAYS; i++)
                $fdisplay(pipe_out, "%1d|  %2d  |  %b   ", 
                    i, retire_freelist_packet[i].told_idx, retire_freelist_packet[i].valid);

            // retire_wfi_halt
            $fdisplay(pipe_out, "       %b       ", retire_wfi_halt);

            // halt
            $fdisplay(pipe_out, "  %b |   %d  |   %h   |  %b | %h | %b |  %d   |  %d  |  %h ", halt, rob_retire_packet[0].dest_value, rob_retire_packet[0].opb, proc2mem_command, rob_retire_packet[0].NPC, proc2Dmem_fu_command, proc2Dmem_fu_addr, proc2mem_addr, proc2mem_data);

    endfunction

    always @(negedge clock) begin
        if (~reset) begin
            $fdisplay(pipe_out,"cycle %d", clock_count);
            dump_output();
        end
        else begin
            // $fdisplay(pipe_out,"@@ Resetting --------------------------------------------------------------");
            // $fdisplay(pipe_out, "");
        end
    end


    // Task to display # of elapsed clock edges
    task show_clk_count (input int fileno);
        real cpi;

        begin
            cpi = (clock_count + 1.0) / instr_count;
            $fdisplay(fileno, "@@  %0d cycles / %0d instrs = %f CPI\n@@",
                clock_count+1, instr_count, cpi);
            $fdisplay(fileno, "@@  %4.2f ns total time to execute\n@@\n",
                clock_count*`VERILOG_CLOCK_PERIOD);
        end
    endtask  // task show_clk_count


    // Count the number of posedges and number of instructions completed
    // till simulation ends
    always @(posedge clock) begin
        if(reset) begin
            clock_count <= `SD 0;
            //instr_count <= `SD 0;
        end else begin
            clock_count <= `SD (clock_count + 1);
            //instr_count <= `SD (instr_count + ROB_entries_retired);
        end
    end

    always_comb begin
        if(reset) begin
            instr_count = 0;
        end else begin
            for (int i = 0; i < `SUPERSCALAR_WAYS; i++)
                instr_count = (instr_count + rob_retire_packet[i].complete);
        end
    end


    always begin
        #(`VERILOG_CLOCK_PERIOD/2.0); //clock "interval" ... AKA 1/2 the period
        clock=~clock;
    end

    // ignore superscalar
    always_comb begin
        for (int i = 0; i < `SUPERSCALAR_WAYS; i++)
            Imem2proc_data[i] = tb_mem[fetch_PC_out[i][`XLEN-1:3]];
    end
/*
    always@(posedge clock)
	    begin
		show_clk_count(cpi_fileno);
        $display("@@@ mem address = %d", proc2mem_addr[31:3]);
	    end
*/
    always @(negedge clock) begin
        if(reset) begin
            $display("@@\n@@  %t : System STILL at reset, can't show anything\n@@",
                $realtime);
            debug_counter <= 0;
        end else begin
            `SD;
            `SD;
    

            for (int i = 0; i < `SUPERSCALAR_WAYS; i++) begin
                if(retire_packet[i].complete) begin
                    if(retire_packet[i].ar_idx != `ZERO_REG)  begin
                        $fdisplay(wb_fileno, "PC=%x, REG[%d]=%x",
                            retire_packet[i].NPC-4 , retire_packet[i].ar_idx, retire_packet[i].dest_value);
                        // if (br_recover_enable)
                        //     $fdisplay(wb_fileno, "branch taken");
                    end
                    else begin
                        $fdisplay(wb_fileno, "PC=%x, ---",retire_packet[i].NPC-4);
                    end
                end
            end



            // deal with any halting conditions
            if(halt == 1'b1) begin
                show_mem_with_decimal(0,`MEM_64BIT_LINES - 1);
                $display("@@  %t : System halted\n@@", $realtime);
                $display("@@@ System halted on WFI instruction");
                $display("@@@\n@@");
                show_clk_count(cpi_fileno);
                // show_clk_count(wb_fileno);
                $fclose(wb_fileno);
                #1
                $fclose(pipe_out);
                $finish;
            end
            debug_counter <= debug_counter + 1;
        end  // if(reset)
    end

    // Show contents of a range of Unified Memory, in both hex and decimal
    task show_mem_with_decimal;
        input [31:0] start_addr;
        input [31:0] end_addr;
        int showing_data;
        begin
            $display("@@@");
            showing_data=0;
            for(int k=start_addr;k<=end_addr; k=k+1)
                if (tb_mem[k] != 0) begin
                    $display("@@@ mem[%5d] = %x : %0d", k*8, tb_mem[k],
                        tb_mem[k]);
                    showing_data=1;
                end else if(showing_data!=0) begin
                    $display("@@@");
                    showing_data=0;
                end
            $display("@@@");
        end
    endtask  // task show_mem_with_decimal


    always@(posedge clock)
	begin
		show_clk_count(cpi_fileno);
	end

    initial begin
        $dumpvars;
        $display("STARTING TESTBENCH!\n");

        if ($value$plusargs("FILENAME=%s", filename)) begin
            $display("Loading memory file: %s", filename);
        end else begin
            $display("Loading default memory file: btest1.mem");
            filename = "btest1";
        end

        wb_fileno = $fopen({"output/", filename, ".wb"},"w");
        cpi_fileno = $fopen({"output/", filename, ".cpi"}, "w");
        pipe_out = $fopen("./visual_debugger/pipeline.out","w");
        $fdisplay(pipe_out, "superscalar_ways");
        $fdisplay(pipe_out, "%d", `SUPERSCALAR_WAYS);
        // $fdisplayh(wb_fileno, "%p",tb_mem[1]);
        enable = 1;
        clock = 1;

        reset = 1'b0;
        // Pulse the reset signal
        // $fdisplay(wb_fileno, "@@\n@@\n@@  %t  Asserting System reset......", $realtime);
        reset = 1'b1;
        @(posedge clock);
        @(posedge clock);
        

        $readmemh({"programs/", filename, ".mem"}, tb_mem);
	@(posedge clock);
        @(posedge clock);
        // $fdisplayh(wb_fileno, "%p",tb_mem[1]);
        `SD;
        show_clk_count(cpi_fileno);
        //dump_output();
        // This reset is at an odd time to avoid the pos & neg clock edges
        reset = 1'b0;
        $display("@@  %t  Deasserting System reset......\n@@\n@@", $realtime);
        $display("@@@ Unified Memory contents hex on left, decimal on right: ");
        // show_mem_with_decimal(0,`MEM_64BIT_LINES - 1);
        show_clk_count(cpi_fileno);
/*        repeat (1000) begin
            #100
            $display(wb_fileno, "@@  %0d cycles / %0d instrs = %f CPI\n@@",
                clock_count+1, instr_count, 3.24);

        end    */
        //$fdisplay(wb_fileno, "@@  %4.2f ns total time to execute\n@@\n",
        //        clock_count*`VERILOG_CLOCK_PERIOD);
        #100000
        $display("@@  %t  Can't STOP!!!!!!!!!!!!!!!!!......\n@@\n@@", $realtime);
	    $finish;

    end


endmodule
