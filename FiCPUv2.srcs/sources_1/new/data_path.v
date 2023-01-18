`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/27/2022 08:09:13 PM
// Design Name: 
// Module Name: data_path
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


module data_path(
    input         clk,
    input         reset,
    input         reg_write,
    input         acc_write,
    input         transfer_a,
    input         psh,
    input         pop,
    input         alu_to_reg,
    input         update_flags,
    input         bra,
    input         brz,
    input         brn,
    input         brc,
    input         bro,
    input         reg_as_addr,
    input         hlt,
    input         psh_pc,
    input         pop_pc,
    input         fpu_to_acc,
    input  [15:0] instr,
    input  [15:0] read_data,
    input  [15:0] read_stack,
    output [15:0] pc,
    output [15:0] data_addr,
    output [15:0] write_data,
    output [15:0] write_stack,
    output [15:0] sp,
    output [15:0] a,
    output [15:0] x,
    output [15:0] y
);

wire zero;
wire negative;
wire carry;
wire overflow;
wire branch;

wire [3:0] flags;

wire [15:0] imm_ex;
wire [15:0] pc_inc;
wire [15:0] pc_next;
wire [15:0] alu_result;
wire [15:0] rf_data;
wire [15:0] se_imm;
wire [15:0] pc_branch;
wire [15:0] pc_val;
wire [15:0] fpu_result;

// sign extend immediate value
sign_extension extend_imm(
    instr[8:0],
    se_imm
);

// decides if to use value stored in register as address or if to use the immediate
mux2 #(16) d_addr(
    se_imm, instr[0] ? y << 1 : x << 1, reg_as_addr, 
    data_addr
);

// decides if to branch or not
assign branch = bra | (brz & flags[3]) | (brn & flags[2]) | (brc & flags[1]) | (bro & flags[0]);

// inc PC to next instruction, word aligned
adder inc_pc(
    pc, 16'b10,
    pc_inc
);

// branch address
adder add_pc(
    pc, se_imm << 1,
    pc_branch
);

// next instruction select
// if hlt is asserted then stop at the current instruction
one_hot_encoder pc_source(
    pc_inc, pc_branch, pc, read_stack, {pop_pc, hlt, branch}, 
    pc_next
);

// update PC on posedge clk
flopr #(16) pc_reg(
    clk, reset, pc_next, 
    pc
);

// write/read to/from x or y
// select source from data memory, stack, acc register or alu
one_hot_encoder wd_reg(
    read_data, read_stack, a, alu_result, {alu_to_reg, transfer_a, pop}, 
    rf_data
);     
reg_file rf(
    clk, reg_write, instr[9], rf_data, 
    x, y
);

// write/read to/from acc register
acc_reg acc(
    clk, reset, acc_write, fpu_to_acc ? fpu_result : alu_result, 
    a
);

// write to data memory
mux2 #(16) wd_mux(x, y, instr[9], write_data);

// select source to write to stack memory
one_hot_encoder write_stack_source(
    x, y, pc_inc, 16'bx, {1'b0, psh_pc, instr[9]},
    write_stack
);

// compute alu operations
alu alu(
    instr[15:10], instr[9] ? y : x, alu_to_reg ? se_imm : a,
    zero, negative, carry, overflow, alu_result
);

flopr_en #(4) flag_reg(
    clk, reset, update_flags, {zero, negative, carry, overflow}, 
    flags
);

// stack logic 
stack st(
    clk, reset, psh | psh_pc, pop | pop_pc,
    sp
);

// FPU logic
fpu fp(
    instr[15:10], a, instr[9] ? y : x,
    fpu_result
);

always @(negedge clk) begin
    if(!reset) begin
        $display("\tX: %d Y: %d A: %d", $signed(x), $signed(y), $signed(a));
        $display("\tX: %h Y: %h A: %h", x, y, a);
        $display("\tIMMEDIATE %d", $signed(se_imm));
        $display("\tZNCV");
        $display("\t%b", flags);
        $display("\tHLT: %b", hlt);
        $display("\tBRANCH %b", branch);
    end
end

endmodule
