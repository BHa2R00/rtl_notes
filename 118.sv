`timescale 1ns/1ps
`ifndef DLY
  `define DLY 0.1
`endif//DLY


module alu #(
  parameter MSB = 7 
)(
  input      [  7:0] f, 
  output reg         co, 
  output reg [MSB:0] z, 
  input              ci, 
  input      [MSB:0] x, y 
);

wire [MSB:0] x1 = f[0] ? {(MSB+1){1'b0}} : x;
wire         c1 = f[0] ? 1'b0 : ci;
wire [MSB:0] y1 = f[1] ? {(MSB+1){1'b0}} : y;
wire [MSB:0] x2 = f[2] ? ~x1 : x1;
wire         c2 = f[2] ? ~c1 : c1;
wire [MSB:0] y2 = f[3] ? ~y1 : y1;
reg          c3;
reg  [MSB:0] z1, z2;
integer z2_i;
always@(*) begin
  case(f[5:4])
    2'b01 : begin
      if(y2[MSB]) begin
        if(x2[MSB]) {z1,c3} = {c2,~((~x2) >> ((~y2+{{MSB{1'b0}},1'b1})+{(MSB+1){1'b1}}))};
        else {z1,c3} = {c2,(x2 >> ((~y2+{{MSB{1'b0}},1'b1})+{(MSB+1){1'b1}}))};
      end
      else {c3,z1} = {(x2 << (y2+{(MSB+1){1'b1}})),c2};
    end
    2'b10 : begin
      z1 = x2 + y2;
      c3 = c2;
    end
    2'b11 : {c3,z1} = x2 + y2 + {{MSB{1'b0}},c2};
    default: begin
      z1 = x2 & y2;
      c3 = 1'b0;
    end
  endcase
  if(f[6]) begin
    for(z2_i=0;MSB>=z2_i;z2_i=z2_i+1) z2[z2_i] = z1[MSB-z2_i];
  end
  else z2 = z1;
  {co,z} = f[7] ? ~{c3,z2} : {c3,z2};
end

endmodule


module cpu #(
  parameter IMSB = 15, // IMSB >= 15
  parameter AMSB = 14, // AMSB <  IMSB 
  parameter  MSB = 7 
)(
  input               ack_data, 
  input      [ MSB:0] rdata, 
  output     [ MSB:0] wdata, 
  output              we, 
  output reg [AMSB:0] addr, 
  output              req_addr, 
  input               ack_inst, 
  input      [IMSB:0] inst, 
  output reg [AMSB:0] pc, 
  output reg          req_pc, 
  output              idle, 
  input      [AMSB:0] pc0, pc1, 
  input               setb, 
  input               rstb, clk 
);

wire   ctrl  = inst[IMSB];
wire   jgt   = inst[14];
wire   jlt   = inst[13];
wire   jeq   = inst[12];
wire   dat   = inst[11];
wire   adr   = inst[10];
wire   write = inst[ 9];
wire   read  = inst[ 8];
wire [7:0] f = inst[ 7:0];
wire [MSB:0] z, x, y;
reg [MSB:0] d;
reg ci;
wire co;
alu #(.MSB(MSB)) u_alu (.f(f), .co(co), .z(z), .ci(ci), .x(x), .y(y));
assign x = d;
assign y = read ? (write ? pc[MSB:0] : rdata) : addr[MSB:0];
assign wdata = z;
assign we = &{write,~read};
wire eq = ~|z;
wire lt = z[MSB];
wire gt = ~|{eq,lt};
wire jmp = |({gt,lt,eq}&{jgt,jlt,jeq});
assign idle = (pc == pc1) || (&inst);
assign req_addr = &{^{write,read},ack_inst,req_pc};
always@(negedge rstb or posedge clk) begin
  if(~rstb) req_pc <= 1'b0;
  else if(&{setb,~idle}) begin
    case({ack_inst,req_pc})
      2'b00 : req_pc <= 1'b1;
      2'b11 : begin
        if(^{write,read}) begin
          if(&{req_addr,ack_data}) req_pc <= 1'b0;
        end
        else req_pc <= 1'b0;
      end
      default: req_pc <= req_pc;
    endcase
  end
  else req_pc <= 1'b0;
end
wire exec = &{setb,~idle,ack_inst,req_pc,(^{write,read} ? &{req_addr,ack_data} : 1'b1)};
always@(negedge rstb or posedge clk) begin
  if(~rstb) pc <= {(AMSB+1){1'b0}};
  else if(~setb) pc <= pc0;
  else if(exec) pc <= &{ctrl,jmp} ? addr : pc + {{AMSB{1'b0}},1'b1};
end
always@(negedge rstb or posedge clk) begin
  if(~rstb) begin
    addr <= {(AMSB+1){1'b0}};
    d <= {(MSB+1){1'b0}};
    ci <= 1'b0;
  end
  else if(exec) begin
    if(ctrl) begin
      if(adr) addr[MSB:0] <= z;
      if(dat) {ci,d} <= {co,z};
    end
    else addr <= inst[AMSB:0];
  end
end

endmodule


module heap #(
  parameter  MSB = 7, 
  parameter AMSB = 3 
)(
  output [ MSB:0] rdata, 
  input           we, 
  input  [ MSB:0] wdata, 
  input  [AMSB:0] addr, 
  input           setb, 
  input           clk 
);

reg [MSB:0] mem[0:(1<<(AMSB+1))-1];
assign rdata = mem[addr];
always@(posedge clk) begin
  if(&{setb,we}) mem[addr] <= wdata;
end

endmodule


module stack #(
  parameter  MSB = 7, 
  parameter AMSB = 3 
)(
  output [MSB:0] rdata, 
  input          we, 
  input  [MSB:0] wdata, 
  input          setb, 
  input          rstb, clk 
);

reg [AMSB:0] sp;
always@(negedge rstb or posedge clk) begin
  if(~rstb) sp <= {(AMSB+1){1'b0}};
  else if(setb) begin
    sp <= we ? (sp + 'h1) : (sp - 'h1);
  end
end
reg [MSB:0] mem[0:(1<<(AMSB+1))-1];
assign rdata = mem[sp-1];
always@(posedge clk) begin
  if(&{setb,we}) mem[sp] <= wdata;
end

endmodule


module lfsr #(
  parameter  MSB  = 7, 
  parameter  INIT = 'h1 
)(
  output reg [MSB:0] q, 
  input              setb, 
  input              rstb, clk 
);

wire [MSB:0] nxt_q;
assign nxt_q = {q[MSB-1:0],^q[MSB:MSB-1]};
always@(negedge rstb or posedge clk) begin
  if(~rstb) q <= INIT;
  else if(setb) q <= nxt_q;
end

endmodule


`include "sys_rom.v"
/*
sbcl --script 118.lisp -c 118_sys.lisp -s sys.asm -o sys.bin -v sys_rom.v sys_rom -ramdump -romdump -srcdump
 */


module sys #(
  parameter HAMSB =  3, // heap address msb
  parameter SAMSB =  3, // stack address msb
  parameter  IMSB = 15, // IMSB >= 15
  parameter  AMSB = 14, // AMSB <  IMSB 
  parameter   MSB = 7 
)(
  output reg [MSB:0] io0pu, 
  output reg [MSB:0] io0pd, 
  output reg [MSB:0] io0w, 
  output reg [MSB:0] io0e, 
  input      [MSB:0] io0q, 
  output reg [MSB:0] io0d, 
  output             idle, 
  input              setb, 
  input              rstb, clk 
);

reg           ack_data;
reg  [ MSB:0] rdata;
wire [ MSB:0] wdata;
wire          we;
wire [AMSB:0] addr;
wire          req_addr;
reg           ack_inst;
wire [IMSB:0] inst;
wire [AMSB:0] pc;
wire          req_pc;

sys_rom u_rom (.inst(inst), .pc(pc), .rstb(rstb), .clk(clk));

always@(*) begin
  if(~rstb) ack_inst = 1'b0;
  else if(setb) ack_inst = req_pc;
  else ack_inst = 1'b0;
end

cpu #(
  . IMSB (IMSB), // IMSB >= 15
  . AMSB (AMSB), // AMSB <  IMSB 
  .  MSB ( MSB) 
) u_cpu (
  .ack_data(ack_data), 
  .rdata(rdata), 
  .wdata(wdata), 
  .we(we), 
  .addr(addr), 
  .req_addr(req_addr), 
  .ack_inst(ack_inst), 
  .inst(inst), 
  .pc(pc), 
  .req_pc(req_pc), 
  .idle(idle), 
  .pc0({(AMSB+1){1'b0}}), .pc1({(AMSB+1){1'b1}}), 
  .setb(setb), 
  .rstb(rstb), .clk(clk) 
);

reg  [MSB:0] t0;
wire [MSB:0] s0;
reg sel_s0;
stack #(
  .MSB(MSB), 
  .AMSB(SAMSB) 
) u_s0 (
  .rdata(s0), 
  .we(we), 
  .wdata(wdata), 
  .setb(&{setb,req_addr,sel_s0}), 
  .rstb(rstb), .clk(clk) 
);

reg  [MSB:0] ap;
wire [MSB:0] h0;
reg  sel_h0;
reg [HAMSB:0] addr_h0;
heap #(
  .MSB(MSB), 
  .AMSB(HAMSB) 
) u_h0 (
  .rdata(h0), 
  .we(we), 
  .wdata(wdata), 
  .addr(addr_h0), 
  .setb(&{setb,req_addr,sel_h0}), 
  .clk(clk) 
);

wire [MSB:0] lfsr;
reg lfsre;
lfsr #(
  .MSB (MSB), 
  .INIT('b101) 
) u_lfsr (
  .q(lfsr), 
  .setb(lfsre), 
  .rstb(rstb), .clk(clk) 
);

always@(*) begin
  #`DLY;
  rdata = {(MSB+1){1'b0}};
  if(addr == 'h0000) rdata[MSB:0] = t0   ;
  if(addr == 'h0001) rdata[MSB:0] = ap   ;
  sel_s0 = 1'b0;
  if(addr == 'h0002) begin
    rdata[MSB:0] = s0;
    sel_s0 = 1'b1;
  end
  if(addr == 'h0003) rdata[MSB:0] = io0d ;
  if(addr == 'h0004) rdata[MSB:0] = io0q ;
  if(addr == 'h0005) rdata[MSB:0] = io0e ;
  if(addr == 'h0006) rdata[MSB:0] = io0w ;
  if(addr == 'h0007) rdata[MSB:0] = io0pu;
  if(addr == 'h0008) rdata[MSB:0] = io0pd;
  if(addr == 'h0009) rdata[MSB:0] = lfsr ;
  addr_h0 = addr-'h000a+ap;
  sel_h0 = 1'b0;
  if(addr >= 'h000a) begin
    rdata[MSB:0] = h0;
    sel_h0 = 1'b1;
  end
  ack_data = req_addr;
end
always@(negedge rstb or posedge clk) begin
  if(~rstb) begin
    t0 <= 'h0;
    ap <= 'h0;
    io0d <= 'h0;
    io0e <= 'h0;
    io0w <= 'h0;
    io0pu <= 'h0;
    io0pd <= 'h0;
    lfsre <= 'h0;
  end
  else begin
    if(&{setb,req_addr,we}) begin
      if(addr == 'h0000) t0     <= wdata[MSB:0];
      if(addr == 'h0001) ap     <= wdata[MSB:0];
      if(addr == 'h0003) io0d   <= wdata[MSB:0];
      if(addr == 'h0005) io0e   <= wdata[MSB:0];
      if(addr == 'h0006) io0w   <= wdata[MSB:0];
      if(addr == 'h0007) io0pu  <= wdata[MSB:0];
      if(addr == 'h0008) io0pd  <= wdata[MSB:0];
      if(addr == 'h0009) lfsre  <= wdata[  0:0];
    end
  end
end

endmodule


`ifdef SIM
module tb1;

parameter HAMSB =  4; // heap address msb
parameter SAMSB =  4; // stack address msb
parameter  IMSB = 15; // IMSB >= 15
parameter  AMSB = 14; // AMSB <  IMSB 
parameter   MSB =  7;

wire idle;
reg  setb;
reg  rstb, clk;
sys #(
  .HAMSB  (HAMSB), // heap address msb
  .SAMSB  (SAMSB), // stack address msb
  .  IMSB ( IMSB), // IMSB >= 15
  .  AMSB ( AMSB), // AMSB <  IMSB 
  .   MSB (  MSB)
) u_sys (
  .idle(idle), 
  .setb(setb), 
  .rstb(rstb), .clk(clk) 
);

initial clk = 0;
always #2.5 clk = ~clk;

initial begin
  `ifdef FST
  $dumpfile("a.fst");
  $dumpvars(0,tb1);
  `endif
  `ifdef FSDB
  $fsdbDumpfile("a.fsdb");
  $fsdbDumpvars(0,tb1);
  `endif
  rstb = 0;
  setb = 0;
  repeat(2) begin
    #500 rstb = 1;
    repeat(2) begin
      #500 setb = 1;
      @(posedge idle);
      $write("%t cpu stop at pc %t\n", $time, u_sys.pc);
      #500 setb = 0;
    end
    #500 rstb = 0;
  end
  $finish;
end

endmodule
`endif
