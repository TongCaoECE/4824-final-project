
`timescale 1ns/100ps

module prf (
    input                                     clock,
    input                                     reset,
    input FU_PRF_PACKET [6:0]                 prf_fu_in,
    output logic [`N_PHYS_REG-1:0][`XLEN-1:0] physical_register
);
    always_ff @(posedge clock) begin
        if (reset)
            physical_register <= `SD '0;
        else begin
            for (int i = 0; i < `N_FU_UNITS; i++) begin
                if (prf_fu_in[i].idx)
                    physical_register[prf_fu_in[i].idx] <= `SD prf_fu_in[i].value;   //adjust according to the number of ALU port
            end  // for each fu unit
        end  // if (~reset)
    end  // always_ff @(posedge clock)
endmodule  // prf