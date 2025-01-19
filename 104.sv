`ifdef SIM
`include "MX25L1005.v"
`include "W25Q128JVxIM.v"
`include "MX25LM51245G.v"
`include "MX25R1035F.v"
`include "MX25U1001E.v"
`include "MX25L12835F.v"
`include "104.xip.W25Q128JVxIM.v"
`include "104.xip.MX25L1005.v"
`include "s80ks2563.v"
//`include "s25hs01gt.sv"
//`include "N25Q128A13B.v"
`endif
`timescale 1ns/1ps
`ifndef DLY
  `define DLY 1
`endif


module rv32e (
  input             lok_data, rdy_data, 
  input      [31:0] rdata, 
  output reg [31:0] wdata, 
  output            we, 
  output reg [31:0] addr, 
  output            sel_addr, ena_addr, 
  input      [31:0] inst, 
  input             lok_inst, rdy_inst, 
  output reg [31:0] pc, 
  output            sel_pc, ena_pc, 
  input      [31:0] pc0, pc1, 
  output            idle, 
  input             setb, 
  input             rstb, clk 
);

reg [31:0] mem[1:15];
wire [6:0] opcode = inst[6:0];
wire fmtr   = (opcode == 7'b0110011);
wire fmti   = (opcode == 7'b0010011);
wire fmtil  = (opcode == 7'b0000011);
wire fmts   = (opcode == 7'b0100011);
wire fmtb   = (opcode == 7'b1100011);
wire fmtj   = (opcode == 7'b1101111);
wire fmtijr = (opcode == 7'b1100111);
wire fmtu   = (opcode == 7'b0110111);
wire fmtup  = (opcode == 7'b0010111);
//wire fmtie  = (opcode == 7'b1110011);
wire [2:0] funct3 = inst[14:12];
wire [6:0] funct7 = inst[31:25];
wire [4:0] rd  = (|{fmtr,fmti,fmtil,fmtu,fmtup,fmtj,fmtijr})? inst[11:7]:5'd0;
wire [4:0] rs1 = (|{fmtr,fmti,fmtil,fmts,fmtb,fmtijr})? inst[19:15]:5'd0;
wire [4:0] rs2 = (|{fmtr,fmts,fmtb})? inst[24:20]:5'd0;
wire [31:0] imm = 
  (fmti || fmtil || fmtijr)? {{20{inst[31]}},inst[31:20]}:
  fmts? {{20{inst[31]}},inst[31:25],inst[11:7]}:
  fmtb? {{19{inst[31]}},inst[31],inst[7],inst[30:25],inst[11:8],1'b0}:
  (fmtu || fmtup)? {inst[31:12],12'd0}:
  fmtj? {{12{inst[31]}},inst[31],inst[19:12],inst[20],inst[30:21],1'b0}:
  32'd0;
wire instp = inst[1:0] == 2'b11;
wire i_nop    = fmti   && (~|inst[31:7]);
wire i_add    = fmtr   && (funct3==3'h0) && (funct7==7'h00);
wire i_sub    = fmtr   && (funct3==3'h0) && (funct7==7'h20);
wire i_xor    = fmtr   && (funct3==3'h4) && (funct7==7'h00);
wire i_or     = fmtr   && (funct3==3'h6) && (funct7==7'h00);
wire i_and    = fmtr   && (funct3==3'h7) && (funct7==7'h00);
wire i_sll    = fmtr   && (funct3==3'h1) && (funct7==7'h00);
wire i_srl    = fmtr   && (funct3==3'h5) && (funct7==7'h00);
wire i_sra    = fmtr   && (funct3==3'h5) && (funct7==7'h20);
wire i_slt    = fmtr   && (funct3==3'h2) && (funct7==7'h00);
wire i_sltu   = fmtr   && (funct3==3'h3) && (funct7==7'h00);
wire i_addi   = fmti   && (funct3==3'h0);
wire i_xori   = fmti   && (funct3==3'h4);
wire i_ori    = fmti   && (funct3==3'h6);
wire i_andi   = fmti   && (funct3==3'h7);
wire i_slli   = fmti   && (funct3==3'h1) && (imm[11:5]==7'h00);
wire i_srli   = fmti   && (funct3==3'h5) && (imm[11:5]==7'h00);
wire i_srai   = fmti   && (funct3==3'h5) && (imm[11:5]==7'h20);
wire i_slti   = fmti   && (funct3==3'h2);
wire i_sltiu  = fmti   && (funct3==3'h3);
wire i_lb     = fmtil  && (funct3==3'h0);
wire i_lh     = fmtil  && (funct3==3'h1);
wire i_lw     = fmtil  && (funct3==3'h2);
wire i_lbu    = fmtil  && (funct3==3'h4);
wire i_lhu    = fmtil  && (funct3==3'h5);
wire i_sb     = fmts   && (funct3==3'h0);
wire i_sh     = fmts   && (funct3==3'h1);
wire i_sw     = fmts   && (funct3==3'h2);
wire i_beq    = fmtb   && (funct3==3'h0);
wire i_bne    = fmtb   && (funct3==3'h1);
wire i_blt    = fmtb   && (funct3==3'h4);
wire i_bge    = fmtb   && (funct3==3'h5);
wire i_bltu   = fmtb   && (funct3==3'h6);
wire i_bgeu   = fmtb   && (funct3==3'h7);
wire i_jal    = fmtj;
wire i_jalr   = fmtijr && (funct3==3'h0);
wire i_lui    = fmtu;
wire i_auipc  = fmtup;
//wire i_ecall  = fmtie  && (funct3==3'h0) && (funct7==7'h0);
//wire i_ebreak = fmtie  && (funct3==3'h0) && (funct7==7'h1);
assign we = fmts;
wire [31:0] xrs1 = (rs1==5'd0)? 32'd0:mem[rs1[3:0]];
wire [31:0] xrs2 = (rs2==5'd0)? 32'd0:mem[rs2[3:0]];
wire xrs1s = xrs1[31];
wire xrs2s = xrs2[31];
wire imms = imm[31];
wire [31:0] xrs1u = xrs1s? ((~xrs1) + 32'd1):xrs1;
wire [31:0] xrs2u = xrs2s? ((~xrs2) + 32'd1):xrs2;
wire [31:0] immu = imms? ((~imm) + 32'd1):imm;
wire ltu = xrs1u < xrs2u;
wire geu = ~ltu;
wire lt = 
  ({xrs1s,xrs2s}==2'b11) ? ~ltu:
  ({xrs1s,xrs2s}==2'b10) ? 1'b1:
  ({xrs1s,xrs2s}==2'b01) ? 1'b0:
  ltu;
wire eq = xrs1 == xrs2;
wire ne = ~eq;
wire ge = ~lt;
wire ltiu = xrs1u < immu;
wire lti = 
  ({xrs1s,imms}==2'b11)? ~ltiu:
  ({xrs1s,imms}==2'b10)? 1'b1:
  ({xrs1s,imms}==2'b01)? 1'b0:
  ltiu;
wire [31:0] xrd = 
  i_add    ? (xrs1 +  xrs2):
  i_sub    ? (xrs1 +  ~xrs2 + 32'd1):
  i_xor    ? (xrs1 ^  xrs2):
  i_or     ? (xrs1 |  xrs2):
  i_and    ? (xrs1 &  xrs2):
  i_sll    ? (xrs1 << xrs2[4:0]):
  i_srl    ? (xrs1 >> xrs2[4:0]):
  i_sra    ? (xrs1s? (~((~xrs1) >> xrs2[4:0])):(xrs1 >> xrs2[4:0])):
  i_slt    ? (lt? 32'd1:32'd0):
  i_sltu   ? (ltu? 32'd1:32'd0):
  i_addi   ? (xrs1 +  imm):
  i_xori   ? (xrs1 ^  imm):
  i_ori    ? (xrs1 |  imm):
  i_andi   ? (xrs1 &  imm):
  i_slli   ? (xrs1 << imm[4:0]):
  i_srli   ? (xrs1 >> imm[4:0]):
  i_srai   ? (xrs1s? (~((~xrs1) >> imm[4:0])):(xrs1 >> imm[4:0])):
  i_slti   ? (lti? 32'd1:32'd0):
  i_sltiu  ? (ltiu? 32'd1:32'd0):
  i_jal    ? (pc + 32'd4):
  i_jalr   ? (pc + 32'd4):
  i_lui    ? imm:
  i_auipc  ? (pc + imm):
  i_lb     ? ({{24{rdata[7]}},rdata[7:0]}):
  i_lh     ? ({{16{rdata[15]}},rdata[15:0]}):
  i_lw     ? (rdata[31:0]):
  i_lbu    ? ({{24{1'b0}},rdata[7:0]}):
  i_lhu    ? ({{16{1'b0}},rdata[15:0]}):
  32'd0;
wire [31:0] npc = 
  (i_jal ) ? (pc + imm):
  (i_jalr) ? (xrs1 + imm):
  (i_bgeu && geu) ? (pc + imm):
  (i_bltu && ltu) ? (pc + imm):
  (i_bge  && ge ) ? (pc + imm):
  (i_blt  && lt ) ? (pc + imm):
  (i_bne  && ne ) ? (pc + imm):
  (i_beq  && eq ) ? (pc + imm):
  pc + 32'd4;
assign idle = pc == pc1;
wire exec, ld, st, jmp;
integer mem_i;
always@(negedge rstb or posedge clk) begin
  if(~rstb) for(mem_i=1;15>=mem_i;mem_i=mem_i+1) mem[mem_i] <= 32'd0;
  else if(exec) begin
    if((rd != 5'd0) && (~i_nop)) mem[rd[3:0]] <= xrd;
  end
end
always@(negedge rstb or posedge clk) begin
  if(~rstb) addr <= 32'd0;
  else if(ld) addr <= xrs1 + imm;
end
always@(negedge rstb or posedge clk) begin
  if(~rstb) wdata <= 32'd0;
  else if(st) begin
    wdata <= 
      i_sb ? {rdata[31:8],xrs2[7:0]} : 
      i_sh ? {rdata[31:16],xrs2[15:0]} : 
      i_sw ? xrs2[31:0] : 
      rdata;
  end
end
always@(negedge rstb or posedge clk) begin
  if(~rstb) pc <= 32'd0;
  else if(setb) begin
    if(jmp) pc <= npc;
  end
  else pc <= pc0;
end
reg [2:0] cst, nst;
parameter [2:0] IDLE   = 3'b000;
parameter [2:0] FETCH  = 3'b001;
parameter [2:0] EXEC   = 3'b011;
parameter [2:0] LOAD   = 3'b010;
parameter [2:0] LOADED = 3'b110;
parameter [2:0] STORE  = 3'b111;
parameter [2:0] STORED = 3'b101;
always@(negedge rstb or posedge clk) begin
  if(~rstb) cst <= IDLE;
  else if(setb) cst <= nst;
  else cst <= IDLE;
end
always@(*) begin
  nst = cst;
  case(cst)
    IDLE   : nst = FETCH;
    FETCH  : if(sel_pc && lok_inst && rdy_inst && instp) nst = fmtil ? LOAD : fmts ? STORE : EXEC;
    LOAD   : if(sel_addr && lok_data && rdy_data) nst = LOADED;
    LOADED : nst = FETCH;
    STORE  : if(sel_addr && lok_data && rdy_data) nst = STORED;
    STORED : nst = FETCH;
    EXEC   : nst = FETCH;
  endcase
end
assign sel_pc = setb && (~idle);
assign ena_pc = (cst==FETCH);
assign sel_addr = |{fmtil,fmts};
assign ena_addr = |{(cst==LOAD),(cst==STORE)};
assign exec = |{(cst==LOADED),(cst==STORE),(cst==EXEC)};
assign ld = (cst==FETCH);
assign st = (cst==FETCH);
assign jmp = |{(cst==LOADED),(cst==STORED),(cst==EXEC)};

endmodule


module pulse #(
  parameter CYCLEMSB = 3, 
  parameter INIT = 1'b0, 
  parameter MSB = 7 
)(
  input haltena, halt, dummy, 
  input cki, ie, 
  output cs, 
  output [3:0] phase, 
  output reg [CYCLEMSB:0] cycle, 
  output setb_p, setb_n, err, 
  output reg cko, rise, fall, 
  input [MSB:0] td, tr, tf, pw, period, 
  input v1, invcs, 
  output reg [MSB:0] cnt, 
  input setb, 
  input rstb, clk 
);

wire cki_p = {cko,cki} == 2'b01;
wire cki_n = {cko,cki} == 2'b10;
wire cki_1 = {cko,cki} == 2'b11;
wire cki_0 = {cko,cki} == 2'b00;
wire v2 = ~v1;
wire [MSB:0] td_cnt = td - cnt;
wire [MSB:0] tr_cnt = (td + tr) - cnt;
wire [MSB:0] pw_cnt = (td + tr + pw) - cnt;
wire [MSB:0] tf_cnt = (td + tr + pw + tf) - cnt;
wire [MSB:0] period_cnt = (td + period) - cnt;
wire [MSB:0] period_tf = period - (tr + pw + tf);
assign err = (~|tr) || (~|tf) || tr[MSB] || tf[MSB] || period_tf[MSB];
always@(negedge rstb or posedge clk) begin
  if(~rstb) cnt <= {(MSB+1){1'b0}};
  else if(setb && (~err) && (~ie)) begin
    if(~(halt&&haltena)) cnt <= (~|period_cnt) ? (td + {{MSB{1'b0}},1'b1}) : (cnt + {{MSB{1'b0}},1'b1});
  end
  else cnt <= {(MSB+1){1'b0}};
end
wire rise0 = ie ? cki_p : (td_cnt[MSB] && (~tr_cnt[MSB]));
wire fall0 = ie ? cki_n : (pw_cnt[MSB] && (~tf_cnt[MSB]));
always@(*) begin
  rise = 1'b0;
  fall = 1'b0;
  if(setb && (~err)) begin
    rise = v1 ? fall0 : rise0;
    fall = v1 ? rise0 : fall0;
  end
end
always@(negedge rstb or posedge clk) begin
  if(~rstb) cko <= INIT;
  else if(setb && (~err) && (~ie)) begin
    case(1)
      ((~|tr_cnt) && (cko == v1)) : cko <= v2;
      ((~|tf_cnt) && (cko == v2)) : cko <= v1;
    endcase
  end
  else if(ie) cko <= cki;
  else cko <= v1;
end
reg [1:0] setb_d;
always@(negedge rstb or posedge clk) begin
  if(~rstb) setb_d <= 2'b00;
  else setb_d <= {setb_d[0],setb};
end
assign setb_p = setb_d == 2'b01;
assign setb_n = setb_d == 2'b10;
always@(negedge rstb or posedge clk) begin
  if(~rstb) cycle <= {(CYCLEMSB+1){1'b0}};
  else if(setb) begin
    if((~|period_cnt) && (~dummy) && (~(halt&&haltena))) cycle <= (cycle + {{CYCLEMSB{1'b0}},1'b1});
  end
  else cycle <= {(CYCLEMSB+1){1'b0}};
end
assign phase[0] = setb && ({cko,rise,fall} == 3'b000);
assign phase[1] = setb && ({cko,rise,fall} == 3'b010);
assign phase[2] = setb && ({cko,rise,fall} == 3'b100);
assign phase[3] = setb && ({cko,rise,fall} == 3'b101);
assign cs = invcs ? ~setb : setb;

endmodule


module xipdif (
  input [6:0] cycle, 
  input [3:0] phase, 
  output reg mosi, oe, ie, 
  input miso, 
  output reg ready, 
  output reg [31:0] rdata, 
  input [31:0] addr, 
  input sel, ena, 
  input rstb, clk 
);

wire [3:0] launchmask  = 4'b0111;
wire [3:0] capturemask = 4'b1000;
wire [3:0] oemask      = 4'b0110;
wire [3:0] iemask      = 4'b1001;
wire [3:0] readymask   = 4'b0001;
wire bytemode = 1'b1;
wire [15:0] cmd = 16'h03;
wire  [6:0] cmdmsb = 'd7;
wire  [6:0] addrmsb = 'd23;
wire  [6:0] dummy = 'd0;
wire launch  = |(phase & launchmask);
wire capture = |(phase & capturemask);
wire selcmd   = sel && (cycle <  (cmdmsb + 'd1));
wire seladdr  = sel && (cycle < (cmdmsb + 'd1 + addrmsb + 'd1)) && (~selcmd);
wire seldummy = sel && (cycle < (cmdmsb + 'd1 + addrmsb + 'd1 + dummy)) && (~selcmd) && (~seladdr);
wire seldata  = sel && (cycle[6:5]!=2'b11) && (~selcmd) && (~seladdr) && (~seldummy);
wire [3:0] selbitcmd   = cmdmsb[3:0]  - cycle[3:0];
wire [4:0] selbitaddr  = 5'd31 - cycle[4:0];
wire [4:0] selbitdata  = 5'd31 -(cycle[4:0] - dummy[4:0]);
wire [1:0] selbitbyte  =(2'b11 - selbitdata[4:3]);
wire [4:0] bth = bytemode ? {selbitbyte,selbitdata[2:0]} : selbitdata;
always@(*) begin
  mosi = miso;
  if(launch) begin
    case(1)
      selcmd   : mosi = cmd[selbitcmd];
      seladdr  : mosi = addr[selbitaddr];
    endcase
  end
end
always@(negedge rstb or posedge clk) begin
  if(~rstb) rdata <= 32'd0;
  else if(capture) begin
    if(seldata) rdata[bth] <= miso;
  end
end
always@(*) begin
  oe = |(phase & oemask);
  ie = |(phase & iemask);
  ready = (|(phase & readymask)) && ena && seldata && (selbitdata[4:0] == 5'd0);
end

endmodule


module bio (inout pad, input oe, ie, di, pu, pd, output dc);
`ifdef FPGA
assign pad = oe ? di : 1'bz;
assign dc = pad != 1'b0;
`elsif SIM
supply0 gnd;
supply1 vcc;
rnmos u_pd (pad,gnd,pd);
rpmos u_pu (pad,vcc,~pu);
assign #`DLY pad = oe ? di : 1'bz;
assign #`DLY dc = pad != 1'b0;
`elsif TSMC28
PDUW04SDGZ_H_G u_bio(.I(di), .OEN(~oe), .REN(~pu), .PAD(pad), .C(dc));
`endif
endmodule


module xip (
	output            lok_data, rdy_data, 
	output     [31:0] rdata, 
	input	     [31:0] addr,
	input	            sel_addr, ena_addr, 
  inout             CSB, SIO, SCL, 
  input             rstb, clk 
);

assign lok_data = sel_addr;
wire lok = sel_addr && lok_data;
wire mosie, misoe;
wire mosi;
wire miso;
wire cs, scl;
bio u_CSB (.pad(CSB), .oe(1'b1), .ie(1'b0), .di(cs), .pu(1'b1), .pd(1'b0), .dc());
bio u_SIO (.pad(SIO), .oe(mosie), .ie(misoe), .di(mosi), .pu(1'b0), .pd(1'b0), .dc(miso));
bio u_SCL (.pad(SCL), .oe(1'b1), .ie(1'b0), .di(scl), .pu(1'b0), .pd(1'b1), .dc());
wire [3:0] phase;
wire [6:0] cycle;
pulse #(
  .CYCLEMSB(6), 
  .INIT(1'b0), 
  .MSB(7) 
) u_scl (
  .haltena(1'b0), .halt(1'b0), .dummy(1'b0), 
  .cki(1'b0), .ie(1'b0), 
  .cs(cs), 
  .phase(phase), 
  .cycle(cycle), 
  .setb_p(), .setb_n(), .err(), 
  .cko(scl), .rise(), .fall(), 
  .td(8'd1), .tr(8'd1), .tf(8'd1), .pw(8'd1), .period(8'd4), 
  .v1(1'b0), .invcs(1'b1), 
  .cnt(), 
  .setb(ena_addr), 
  .rstb(rstb), .clk(clk) 
);

xipdif u_xipdif (
  .cycle(cycle), 
  .phase(phase), 
  .mosi(mosi), .oe(mosie), .ie(misoe), 
  .miso(miso), 
  .ready(rdy_data), 
  .rdata(rdata), 
  .addr(addr), 
  .sel(lok), .ena(ena_addr), 
  .rstb(rstb), .clk(clk) 
);

endmodule


module ram #(
  parameter AMSB = 9 
)(
	output            lok_data, rdy_data, 
	output reg [31:0] rdata,
	input	     [31:0] wdata,
  input             we, 
	input	     [31:0] addr,
	input	            sel_addr, ena_addr, 
	input	            rstb, clk
);
assign lok_data = sel_addr;
wire lok = lok_data && sel_addr;
reg [1:0] bs;
assign rdy_data = bs==2'd3;
wire [AMSB:0] A = addr[AMSB:0]+bs[1:0];
always@(negedge rstb or posedge clk) begin
  if(~rstb) bs <= 2'd0;
  else begin
    if(lok) begin
      case(bs)
        2'd0 : if(ena_addr) bs <= 2'd1;
        2'd3 : bs <= 2'd0;
        default : bs <= bs + 2'd1;
      endcase
    end
  end
end
`ifdef SIM
reg [7:0] mem[0:((1<<(AMSB+1))-1)];
always@(negedge rstb or posedge clk) begin
  if(~rstb) rdata <= 32'd0;
  else if(lok) begin
    case(bs)
      2'd0 : if(ena_addr) begin
        if(we) mem[A] <= wdata[7:0];
        rdata[7:0] <= mem[A];
      end
      2'd1 : begin
        if(we) mem[A] <= wdata[15:8];
        rdata[15:8] <= mem[A];
      end
      2'd2 : begin
        if(we) mem[A] <= wdata[23:16];
        rdata[23:16] <= mem[A];
      end
      2'd3 : begin
        if(we) mem[A] <= wdata[31:24];
        rdata[31:24] <= mem[A];
      end
    endcase
  end
end
`elsif FPGA
wire [7:0] D = 
  (bs==2'd0) ? wdata[ 7: 0] : 
  (bs==2'd1) ? wdata[15: 8] : 
  (bs==2'd2) ? wdata[23:16] : 
  (bs==2'd3) ? wdata[31:24] : 
  8'd0;
wire [7:0] Q0, Q1;
wire [7:0] Q = (A[9]==1'b1) ? Q1 : Q0;
altsyncram	u_mem0 (
			.address_a (A),
			.clock0 (clk),
			.q_a (Q0),
			.aclr0 (1'b0),
			.aclr1 (1'b0),
			.address_b (1'b1),
			.addressstall_a (1'b0),
			.addressstall_b (1'b0),
			.byteena_a (1'b1),
			.byteena_b (1'b1),
			.clock1 (1'b1),
			.clocken0 (1'b1),
			.clocken1 (1'b1),
			.clocken2 (1'b1),
			.clocken3 (1'b1),
			.data_a (D),
			.data_b (1'b1),
			.eccstatus (),
			.q_b (),
			.rden_a (lok && (A[9]==1'b0)),
			.rden_b (1'b1),
			.wren_a (we && (lok && (A[9]==1'b0))),
			.wren_b (1'b0));
defparam
	u_mem0.byte_size = 8,
	u_mem0.clock_enable_input_a = "BYPASS",
	u_mem0.clock_enable_output_a = "BYPASS",
	u_mem0.intended_device_family = "Cyclone IV E",
	u_mem0.lpm_hint = "ENABLE_RUNTIME_MOD=NO",
	u_mem0.lpm_type = "altsyncram",
	u_mem0.numwords_a = (1<<(AMSB+1)),
	u_mem0.operation_mode = "SINGLE_PORT",
	u_mem0.outdata_aclr_a = "NONE",
	//u_mem0.outdata_reg_a = "CLOCK0",
	u_mem0.outdata_reg_a = "UNREGISTERED",
	u_mem0.power_up_uninitialized = "FALSE",
	u_mem0.read_during_write_mode_port_a = "DONT_CARE",
	u_mem0.widthad_a = (AMSB+1),
	u_mem0.width_a = 8,
	u_mem0.width_byteena_a = 1;
altsyncram	u_mem1 (
			.address_a (A),
			.clock0 (clk),
			.q_a (Q1),
			.aclr0 (1'b0),
			.aclr1 (1'b0),
			.address_b (1'b1),
			.addressstall_a (1'b0),
			.addressstall_b (1'b0),
			.byteena_a (1'b1),
			.byteena_b (1'b1),
			.clock1 (1'b1),
			.clocken0 (1'b1),
			.clocken1 (1'b1),
			.clocken2 (1'b1),
			.clocken3 (1'b1),
			.data_a (D),
			.data_b (1'b1),
			.eccstatus (),
			.q_b (),
			.rden_a (lok && (A[9]==1'b1)),
			.rden_b (1'b1),
			.wren_a (we && (lok && (A[9]==1'b1))),
			.wren_b (1'b0));
defparam
	u_mem1.byte_size = 8,
	u_mem1.clock_enable_input_a = "BYPASS",
	u_mem1.clock_enable_output_a = "BYPASS",
	u_mem1.intended_device_family = "Cyclone IV E",
	u_mem1.lpm_hint = "ENABLE_RUNTIME_MOD=NO",
	u_mem1.lpm_type = "altsyncram",
	u_mem1.numwords_a = (1<<(AMSB+1)),
	u_mem1.operation_mode = "SINGLE_PORT",
	u_mem1.outdata_aclr_a = "NONE",
	//u_mem1.outdata_reg_a = "CLOCK0",
	u_mem1.outdata_reg_a = "UNREGISTERED",
	u_mem1.power_up_uninitialized = "FALSE",
	u_mem1.read_during_write_mode_port_a = "DONT_CARE",
	u_mem1.widthad_a = (AMSB+1),
	u_mem1.width_a = 8,
	u_mem1.width_byteena_a = 1;
always@(negedge rstb or posedge clk) begin
  if(~rstb) rdata <= 32'd0;
  else if(lok) begin
    case(bs)
      2'd0 : if(ena_addr) rdata[7:0] <= Q;
      2'd1 : rdata[15:8] <= Q;
      2'd2 : rdata[23:16] <= Q;
      2'd3 : rdata[31:24] <= Q;
    endcase
  end
end
`elsif TSMC28
wire [7:0] D = 
  (bs==2'd0) ? wdata[ 7: 0] : 
  (bs==2'd1) ? wdata[15: 8] : 
  (bs==2'd2) ? wdata[23:16] : 
  (bs==2'd3) ? wdata[31:24] : 
  8'd0;
wire [7:0] Q0, Q1;
wire [7:0] Q = (A[9]==1'b1) ? Q1 : Q0;
TEM5N28HPCPLVTA512X8M4SWSO u_mem0 (
.SLP(1'b0),
.SD(1'b0),
.A(A[8:0]),
.D(D),
.BWEB({8{1'b0}}),
.Q(Q0),
.WEB(~we),.CEB(~(lok && (A[9]==1'b0))),.CLK(clk)
);
TEM5N28HPCPLVTA512X8M4SWSO u_mem1 (
.SLP(1'b0),
.SD(1'b0),
.A(A[8:0]),
.D(D),
.BWEB({8{1'b0}}),
.Q(Q1),
.WEB(~we),.CEB(~(lok && (A[9]==1'b1))),.CLK(clk)
);
always@(negedge rstb or posedge clk) begin
  if(~rstb) rdata <= 32'd0;
  else if(lok) begin
    case(bs)
      2'd0 : if(ena_addr) rdata[7:0] <= Q;
      2'd1 : rdata[15:8] <= Q;
      2'd2 : rdata[23:16] <= Q;
      2'd3 : rdata[31:24] <= Q;
    endcase
  end
end
`endif
endmodule


module timer (
	output            lok_data, rdy_data, 
	output reg [31:0] rdata,
	input      [31:0] wdata,
	input             we,
  input      [31:0] addr, 
	input	            sel_addr, ena_addr, 
  output            hit, 
  input             halt, 
  input             rstb, clk, fclk 
);

assign rdy_data = ena_addr;
assign lok_data = sel_addr;
wire lok = lok_data && sel_addr;
reg [31:0] cntr;
reg [31:0] load;
reg en, ld, os;
assign hit = (cntr == 32'd0);
reg [1:0] hit_d, ld_d, en_d;
wire err = hit_d == 2'b11;
wire ldd = ld_d == 2'b11;
always@(negedge rstb or posedge clk) begin
  if(~rstb) begin
    hit_d <= 2'b00;
  end
  else begin
    hit_d <= {hit_d[0],hit};
  end
end
always@(negedge rstb or posedge fclk) begin
  if(~rstb) begin
    ld_d <= 2'b00;
    en_d <= 2'b00;
  end
  else begin
    ld_d <= {ld_d[0],ld};
    en_d <= {en_d[0],en};
  end
end
always@(negedge rstb or posedge fclk) begin
  if(~rstb) cntr <= 32'd0;
  else if(ld) cntr <= load;
  else if(hit && (~os)) cntr <= load;
  else if((~hit) && (~halt) && en_d[1]) cntr <= cntr - 32'd1;
end
wire lok_addr_ctrl = (addr>='h0)&&('h3>=addr) && lok;
wire lok_addr_cntr = (addr>='h4)&&('h7>=addr) && lok;
always@(*) begin
  rdata = 32'd0;
  case(1)
    lok_addr_ctrl : begin
      rdata[0] = en_d[1];
      rdata[1] = ld_d[1];
      rdata[2] = os;
      rdata[3] = hit_d[1];
      rdata[4] = err;
      rdata[5] = ldd;
    end
    lok_addr_cntr : begin
      rdata[31:0] = cntr;
    end
  endcase
end
always@(negedge rstb or posedge clk) begin
  if(~rstb) begin
    en <= 'h0;
    ld <= 'h0;
    os <= 'h0;
    load <= 'h0;
  end
  else if(ena_addr && we) begin
    case(1)
      lok_addr_ctrl : begin
        en <= wdata[0];
        ld <= wdata[1];
        os <= wdata[2];
      end
      lok_addr_cntr : begin
        load <= wdata[31:0];
      end
    endcase
  end
end

endmodule


module clkdiv (
	output            lok_data, rdy_data, 
	output reg [31:0] rdata,
	input	     [31:0] wdata,
  input             we, 
	input	     [31:0] addr,
	input	            sel_addr, ena_addr, 
  output            lck,
  input             hwena, rstb, clk 
);

assign lok_data = sel_addr;
wire lok = lok_data && sel_addr;
assign rdy_data = ena_addr;
reg init;
reg [3:0] delay;
reg [15:0] dividend, divisor;
reg setb;
reg lck0;
wire valid = dividend > divisor;
reg [15:0] cnt;
always@(negedge rstb or posedge clk) begin  
  if(~rstb) begin
    cnt <= 16'd0;
    lck0 <= 1'b0;
  end
  else if((setb|hwena) && valid) begin
    if(cnt >= dividend) begin
      cnt <= cnt - dividend + divisor;
      lck0 <= init;
    end
    else begin
      cnt <= cnt + divisor;
      if(cnt >= (dividend >> 1)) lck0 <= ~init;
    end
  end
  else begin
    cnt <= (dividend >> delay);
    lck0 <= init;
  end
end
assign lck = valid ? lck0 : clk;
wire lok_addr_ctrl = (addr>='h0)&&('h3>=addr) && lok;
wire lok_addr_cntr = (addr>='h4)&&('h7>=addr) && lok;
always@(*) begin
  rdata = 32'd0;
  case(1)
    lok_addr_ctrl : begin
      rdata[0]   = setb ;
      rdata[1]   = init ;
      rdata[5:2] = delay;
    end
    lok_addr_cntr : begin
      rdata[15: 0] = dividend;
      rdata[31:16] = divisor ;
    end
  endcase
end
always@(negedge rstb or posedge clk) begin
  if(~rstb) begin
    setb <= 'h0;
    init <= 'h0;
    delay <= 'h0;
    dividend <= 'h1;
    divisor <= 'h2;
  end
  else if(ena_addr && we) begin
    case(1)
      lok_addr_ctrl : begin
        setb  <= wdata[0]  ;
        init  <= wdata[1]  ;
        delay <= wdata[5:2];
      end
      lok_addr_cntr : begin
        dividend <= wdata[15: 0];
        divisor  <= wdata[31:16];
      end
    endcase
  end
end

endmodule


module uart #(
  parameter CHECK_SB  = 9, 
  parameter FIFO_AMSB = 2, 
  parameter FIFO_DMSB = 9 
)(
  output            lok_data, rdy_data, 
	output reg [31:0] rdata,
	input	     [31:0] wdata,
  input             we, 
	input	     [31:0] addr,
	input	            sel_addr, ena_addr, 
  output            startena, stopena, match,
  output reg        rxe, txe, 
  output            tx, 
  input             rx, 
  output reg        uclkena,
  input             rstb, clk, uclk 
);

wire full, empty;
wire [FIFO_AMSB:0] cnt;
wire [FIFO_DMSB:0] rchar;
reg  [FIFO_DMSB:0] wchar, mchar;
reg  pop, push, clear;
reg  parity, even;
reg  smsb;         // stop msb
reg  [3:0] cmsb;   // char msb
reg  [3:0] sb;
reg  setb;
wire checkena = FIFO_DMSB >= CHECK_SB;
reg [1:0] uclk_d, push_d, pop_d, clear_d, even_d;
wire uclk_p = uclk_d[1:0] == 2'b01;
wire uclk_n = uclk_d[1:0] == 2'b10;
wire push_n = push_d[1:0] == 2'b10;
wire pop_p = pop_d[1:0] == 2'b01;
wire clear_p = clear_d[1:0] == 2'b01;
always@(negedge rstb or posedge clk) begin
  if(~rstb) begin
    uclk_d <= 2'b11;
    push_d <= 2'b00;
    pop_d <= 2'b00;
    clear_d <= 2'b00;
    even_d <= 2'b00;
  end
  else begin
    uclk_d <= {uclk_d[0],uclk};
    push_d <= {push_d[0],push};
    pop_d <= {pop_d[0],pop};
    clear_d <= {clear_d[0],clear};
    even_d <= {even_d[0],even};
  end
end
wire [3:0]   idlebit = sb - 4'd0;
wire [3:0]  startbit = sb - 4'd1;
wire [3:0]   charbit = sb - 4'd2;
wire [3:0] paritybit = sb - (4'd3 + cmsb);
wire [3:0]   stopbit = sb - (4'd3 + cmsb + (parity ? 4'd1 : 4'd0));
wire [3:0]    endbit = sb - (4'd3 + cmsb + (parity ? 4'd1 : 4'd0));
wire     idleena = ( 4'd0       ==   idlebit);
assign  startena = ( 4'd0       ==  startbit);
wire     charena = ( cmsb       >=   charbit) && (charbit >= 4'd0);
wire   parityena = ( 4'd0       == paritybit);
assign   stopena = ({3'd0,smsb} >=   stopbit) && (stopbit >= 4'd0);
wire      endena = ({3'd0,smsb} ==    endbit);
reg [FIFO_DMSB:0] mem[0:((2**FIFO_AMSB)-1)];
reg [FIFO_AMSB:0] ma1, ma0;
assign cnt = ma1 - ma0;
assign full  = cnt >= (2**FIFO_AMSB);
assign empty = cnt == 'd0;
wire [FIFO_DMSB:0] wbc = mem[ma1[(FIFO_AMSB-1):0]];
wire [FIFO_DMSB:0] rbc = mem[ma0[(FIFO_AMSB-1):0]];
reg bx;
assign tx = txe ? (
    startena               ? 1'b0 : 
     charena               ? mem[ma0[(FIFO_AMSB-1):0]][charbit] : 
  (parityena & (~stopena)) ? bx : 
     stopena               ? 1'b1 : 
  1'b1) : 1'b1;
always@(negedge rstb or posedge clk) begin
  if(~rstb) begin
    sb <= 4'd0;
    uclkena <= 1'b0;
    bx <= 1'b0;
  end
  else if(setb && (txe || rxe)) begin
    if(idleena) begin
      if(({txe,empty} == 2'b10) || ({rxe,full,rx} == 3'b100)) begin
        sb <= 4'd1;
        uclkena <= 1'b1;
        if(checkena) bx <= ~even_d[1];
      end
    end
    else begin
      if(({rxe,txe}==2'b10) ? uclk_p : uclk_n) begin
        if(endena) begin
          sb <= 4'd0;
          uclkena <= 1'b0;
        end
        else sb <= sb + 4'd1;
      end
      if(uclk_p && checkena && charena) bx <= bx ^ (txe ? tx : rx);
    end
  end
  else begin
    sb <= 4'd0;
    uclkena <= 1'b0;
  end
end
always@(negedge rstb or posedge clk) begin
  if(~rstb) ma0 <= {(FIFO_AMSB+1){1'b0}};
  else if(clear_p) ma0 <= {(FIFO_AMSB+1){1'b0}};
  else if({pop_p,empty} == 2'b10) ma0 <= ma0 + 'd1;
  else if({txe,endena,uclk_p,empty} == 4'b1110) ma0 <= ma0 + 'd1;
end
always@(negedge rstb or posedge clk) begin
  if(~rstb) ma1 <= {(FIFO_AMSB+1){1'b0}};
  else if(clear_p) ma1 <= {(FIFO_AMSB+1){1'b0}};
  else if({push_n,full} == 2'b10) ma1 <= ma1 + 'd1;
  else if({rxe,endena,uclk_p,full} == 4'b1110) ma1 <= ma1 + 'd1;
end
reg err;
always@(negedge rstb or posedge clk) begin
  if(~rstb) err <= 1'b0;
  else if(rxe && uclk_p) begin
    if(startena) err <= rx;
    else if(parityena && (~stopena) && (~err)) err <= (bx != rx);
    else if(stopena && (~err)) err <= ~rx;
  end
end
always@(posedge clk) begin
  if({push_n,full} == 2'b10) mem[ma1[(FIFO_AMSB-1):0]] <= wchar;
  else if(rxe && uclk_p) begin
    if(charena) mem[ma1[(FIFO_AMSB-1):0]][charbit] <= rx;
    else if(checkena && parityena) mem[ma1[(FIFO_AMSB-1):0]][CHECK_SB] <= err;
  end
end
wire [FIFO_DMSB:0] rmask = ((1<<CHECK_SB)|((1<<(cmsb+1))-1));
assign rchar = mem[ma0[(FIFO_AMSB-1):0]] & rmask;
assign match = endena && (mchar == (mem[ma1[(FIFO_AMSB-1):0]] & rmask));
assign lok_data = sel_addr;
wire lok =lok_data && sel_addr;
assign rdy_data = ena_addr;
wire lok_addr_ctrl = (addr>='h0)&&('h3>=addr) && lok;
wire lok_addr_data = (addr>='h4)&&('h7>=addr) && lok;
wire lok_addr_fifo = (addr>='h8)&&('hb>=addr) && lok;
always@(*) begin
  rdata = 32'd0;
  case(1)
    lok_addr_ctrl : begin
      rdata[ 0]    = setb  ;
      rdata[ 4: 1] = sb    ;
      rdata[ 8: 5] = cmsb  ;
      rdata[ 9]    = smsb  ;
      rdata[10]    = parity;
      rdata[11]    = even  ;
      rdata[12]    = rxe   ;
      rdata[13]    = txe   ;
      rdata[FIFO_DMSB+14:14] = mchar;
    end
    lok_addr_data : begin
      rdata[FIFO_DMSB:0] = rchar;
    end
    lok_addr_fifo : begin
      rdata[ 0]    = clear;
      rdata[ 1]    = full ;
      rdata[ 2]    = empty;
      rdata[FIFO_AMSB+3:3] = cnt;
    end
  endcase
  push = lok_addr_data && we && txe;
  pop = lok_addr_data && (~we) && rxe;
end
always@(negedge rstb or posedge clk) begin
  if(~rstb) begin
    setb <= 'h0;
    txe <= 'h0;
    rxe <= 'h0;
    cmsb <= 'h8;
    smsb <= 'h0;
    parity <= 'h0;
    even <= 'h0;
    wchar <= 'h0;
    mchar <= 'h0;
    clear <= 'h0;
  end
  else if(ena_addr && we) begin
    case(1)
      lok_addr_ctrl : begin
        setb   <= wdata[ 0]   ;
        cmsb   <= wdata[ 8: 5];
        smsb   <= wdata[ 9]   ;
        parity <= wdata[10]   ;
        even   <= wdata[11]   ;
        rxe    <= wdata[12]   ;
        txe    <= wdata[13]   ;
        mchar <= wdata[FIFO_DMSB+14:14];
      end
      lok_addr_data : begin
        wchar <= wdata[FIFO_DMSB:0];
      end
      lok_addr_fifo : begin
        clear <= wdata[ 0];
      end
    endcase
  end
end

endmodule


module i4o4p4cf ( // input:4, output:4, pad:4, connect:full
	output            lok_data, rdy_data, 
	output reg [31:0] rdata,
	input	     [31:0] wdata,
  input             we, 
	input	     [31:0] addr,
	input	            sel_addr, ena_addr,
  inout       [3:0] pad, 
  input       [3:0] oe, 
  input       [3:0] ie, 
  input       [3:0] di, 
  output      [3:0] dc, 
  input             rstb, clk
);

reg [3:0] imask, omask, pu, pd;
reg [1:0] oesel0, iesel0, osel0, isel0;
reg [1:0] oesel1, iesel1, osel1, isel1;
reg [1:0] oesel2, iesel2, osel2, isel2;
reg [1:0] oesel3, iesel3, osel3, isel3;
wire [3:0] DC;
bio u_bio0 (.pad(pad[0]), .pu(pu[0]), .pd(pd[0]), .oe(omask[0]&&oe[oesel0]), .ie(imask[0]&&ie[iesel0]), .di(di[osel0]), .dc(DC[0]));
bio u_bio1 (.pad(pad[1]), .pu(pu[1]), .pd(pd[1]), .oe(omask[1]&&oe[oesel1]), .ie(imask[1]&&ie[iesel1]), .di(di[osel1]), .dc(DC[1]));
bio u_bio2 (.pad(pad[2]), .pu(pu[2]), .pd(pd[2]), .oe(omask[2]&&oe[oesel2]), .ie(imask[2]&&ie[iesel2]), .di(di[osel2]), .dc(DC[2]));
bio u_bio3 (.pad(pad[3]), .pu(pu[3]), .pd(pd[3]), .oe(omask[3]&&oe[oesel3]), .ie(imask[3]&&ie[iesel3]), .di(di[osel3]), .dc(DC[3]));
assign dc[0] = DC[isel0];
assign dc[1] = DC[isel1];
assign dc[2] = DC[isel2];
assign dc[3] = DC[isel3];
assign lok_data = sel_addr;
wire lok = lok_data && sel_addr;
assign rdy_data = ena_addr;
wire lok_addr_ctrl = (addr>='h0)&&('h3>=addr) && lok;
wire lok_addr_mux  = (addr>='h4)&&('h7>=addr) && lok;
always@(*) begin
  rdata = 32'd0;
  case(1)
    lok_addr_ctrl : begin
      rdata[ 3: 0] = omask;
      rdata[ 7: 4] = imask;
      rdata[11: 8] = pu   ;
      rdata[15:12] = pd   ;
    end
    lok_addr_mux : begin
      rdata[ 1: 0] = oesel0;
      rdata[ 3: 2] = iesel0;
      rdata[ 5: 4] =  osel0;
      rdata[ 7: 6] =  isel0;
      rdata[ 9: 8] = oesel1;
      rdata[11:10] = iesel1;
      rdata[13:12] =  osel1;
      rdata[15:14] =  isel1;
      rdata[17:16] = oesel2;
      rdata[19:18] = iesel2;
      rdata[21:20] =  osel2;
      rdata[23:22] =  isel2;
      rdata[25:24] = oesel3;
      rdata[27:26] = iesel3;
      rdata[29:28] =  osel3;
      rdata[31:30] =  isel3;
    end
  endcase
end
always@(negedge rstb or posedge clk) begin
  if(~rstb) begin
    omask <= 'h0;
    imask <= 'h0;
    pu <= 'h0;
    pd <= 'h0;
    oesel0 <= 'h0+'h0;
    iesel0 <= 'h0+'h1;
     osel0 <= 'h0+'h0;
     isel0 <= 'h0+'h1;
    oesel1 <= 'h1+'h0;
    iesel1 <= 'h1+'h1;
     osel1 <= 'h1+'h0;
     isel1 <= 'h1+'h1;
    oesel2 <= 'h2+'h0;
    iesel2 <= 'h2+'h1;
     osel2 <= 'h2+'h0;
     isel2 <= 'h2+'h1;
    oesel3 <= 'h3+'h0;
    iesel3 <= 'h3+'h1;
     osel3 <= 'h3+'h0;
     isel3 <= 'h3+'h1;
  end
  else if(ena_addr && we) begin
    case(1)
      lok_addr_ctrl : begin
        omask <= wdata[ 3: 0];
        imask <= wdata[ 7: 4];
        pu    <= wdata[11: 8];
        pd    <= wdata[15:12];
      end
      lok_addr_mux : begin
        oesel0 <= wdata[ 1: 0];
        iesel0 <= wdata[ 3: 2];
         osel0 <= wdata[ 5: 4];
         isel0 <= wdata[ 7: 6];
        oesel1 <= wdata[ 9: 8];
        iesel1 <= wdata[11:10];
         osel1 <= wdata[13:12];
         isel1 <= wdata[15:14];
        oesel2 <= wdata[17:16];
        iesel2 <= wdata[19:18];
         osel2 <= wdata[21:20];
         isel2 <= wdata[23:22];
        oesel3 <= wdata[25:24];
        iesel3 <= wdata[27:26];
         osel3 <= wdata[29:28];
         isel3 <= wdata[31:30];
      end
    endcase
  end
end

endmodule


module top (
`ifndef FPGA
  input  scan_ena, scan_clk, 
`endif
  inout  csb, sio, scl, 
  inout  [3:0] pad,
  output idle, 
  input  setb, 
  input  rstb, clk
);

wire [3:0] tx, rx, txe, rxe, hit;

wire        lok_data_i_cpu0, rdy_data_i_cpu0;
wire [31:0] rdata_i_cpu0;
wire [31:0] wdata_o_cpu0;
wire        we_o_cpu0;
wire [31:0] addr_o_cpu0;
wire        sel_addr_o_cpu0, ena_addr_o_cpu0;
wire [31:0] inst_i_cpu0;
wire        lok_inst_i_cpu0, rdy_inst_i_cpu0;
wire [31:0] pc_o_cpu0;
wire        sel_pc_o_cpu0, ena_pc_o_cpu0;
rv32e u_cpu0 (
  .lok_data(lok_data_i_cpu0), .rdy_data(rdy_data_i_cpu0), 
  .rdata(rdata_i_cpu0), 
  .wdata(wdata_o_cpu0), 
  .we(we_o_cpu0), 
  .addr(addr_o_cpu0), 
  .sel_addr(sel_addr_o_cpu0), .ena_addr(ena_addr_o_cpu0), 
  .inst(inst_i_cpu0), 
  .lok_inst(lok_inst_i_cpu0), .rdy_inst(rdy_inst_i_cpu0), 
  .pc(pc_o_cpu0), 
  .sel_pc(sel_pc_o_cpu0), .ena_pc(ena_pc_o_cpu0), 
  .pc0(32'h0), .pc1(32'h8), 
  .idle(idle), 
  .setb(setb), 
  .rstb(rstb), .clk(clk) 
);

wire        lok_data_o_rom0, rdy_data_o_rom0;
wire [31:0] rdata_o_rom0;
wire [31:0] addr_i_rom0;
wire	      sel_addr_i_rom0, ena_addr_i_rom0;
xip u_rom0 (
  .lok_data(lok_data_o_rom0), .rdy_data(rdy_data_o_rom0), 
	.rdata(rdata_o_rom0), 
	.addr(addr_i_rom0),
	.sel_addr(sel_addr_i_rom0), .ena_addr(ena_addr_i_rom0), 
  .CSB(csb), .SIO(sio), .SCL(scl), 
	.rstb(rstb), .clk(clk)
);

wire        lok_data_o_ram0, rdy_data_o_ram0;
wire [31:0] rdata_o_ram0;
wire [31:0] wdata_i_ram0;
wire        we_i_ram0;
wire [31:0] addr_i_ram0;
wire	      sel_addr_i_ram0, ena_addr_i_ram0;
ram #(
  .AMSB(9)
) u_ram0 (
	.lok_data(lok_data_o_ram0), .rdy_data(rdy_data_o_ram0), 
	.rdata(rdata_o_ram0), 
	.wdata(wdata_i_ram0), 
  .we(we_i_ram0),
	.addr(addr_i_ram0),
	.sel_addr(sel_addr_i_ram0), .ena_addr(ena_addr_i_ram0), 
	.rstb(rstb), .clk(clk)
);

wire [3:0] fclk, fclkena;

wire        lok_data_o_timer0, rdy_data_o_timer0; 
wire [31:0] rdata_o_timer0;
wire [31:0] wdata_i_timer0;
wire        we_i_timer0;
wire [31:0] addr_i_timer0;
wire	      sel_addr_i_timer0, ena_addr_i_timer0;
timer u_timer0 (
	.lok_data(lok_data_o_timer0), .rdy_data(rdy_data_o_timer0), 
	.rdata(rdata_o_timer0),
	.wdata(wdata_i_timer0),
	.we(we_i_timer0),
  .addr(addr_i_timer0), 
	.sel_addr(sel_addr_i_timer0), .ena_addr(ena_addr_i_timer0), 
  .hit(hit[0]), 
  .halt(1'b0), 
  .rstb(rstb), .clk(clk), .fclk(fclk[0]) 
);

wire        lok_data_o_timer1, rdy_data_o_timer1; 
wire [31:0] rdata_o_timer1;
wire [31:0] wdata_i_timer1;
wire        we_i_timer1;
wire [31:0] addr_i_timer1;
wire	      sel_addr_i_timer1, ena_addr_i_timer1;
timer u_timer1 (
	.lok_data(lok_data_o_timer1), .rdy_data(rdy_data_o_timer1), 
	.rdata(rdata_o_timer1),
	.wdata(wdata_i_timer1),
	.we(we_i_timer1),
  .addr(addr_i_timer1), 
	.sel_addr(sel_addr_i_timer1), .ena_addr(ena_addr_i_timer1), 
  .hit(hit[1]), 
  .halt(1'b0), 
  .rstb(rstb), .clk(clk), .fclk(fclk[1]) 
);

wire        lok_data_o_timer2, rdy_data_o_timer2; 
wire [31:0] rdata_o_timer2;
wire [31:0] wdata_i_timer2;
wire        we_i_timer2;
wire [31:0] addr_i_timer2;
wire	      sel_addr_i_timer2, ena_addr_i_timer2;
timer u_timer2 (
	.lok_data(lok_data_o_timer2), .rdy_data(rdy_data_o_timer2), 
	.rdata(rdata_o_timer2),
	.wdata(wdata_i_timer2),
	.we(we_i_timer2),
  .addr(addr_i_timer2), 
	.sel_addr(sel_addr_i_timer2), .ena_addr(ena_addr_i_timer2), 
  .hit(hit[2]), 
  .halt(1'b0), 
  .rstb(rstb), .clk(clk), .fclk(fclk[2]) 
);

wire        lok_data_o_timer3, rdy_data_o_timer3; 
wire [31:0] rdata_o_timer3;
wire [31:0] wdata_i_timer3;
wire        we_i_timer3;
wire [31:0] addr_i_timer3;
wire	      sel_addr_i_timer3, ena_addr_i_timer3;
timer u_timer3 (
	.lok_data(lok_data_o_timer3), .rdy_data(rdy_data_o_timer3), 
	.rdata(rdata_o_timer3),
	.wdata(wdata_i_timer3),
	.we(we_i_timer3),
  .addr(addr_i_timer3), 
	.sel_addr(sel_addr_i_timer3), .ena_addr(ena_addr_i_timer3), 
  .hit(hit[3]), 
  .halt(1'b0), 
  .rstb(rstb), .clk(clk), .fclk(fclk[3]) 
);

wire        lok_data_o_fclk0, rdy_data_o_fclk0;
wire [31:0] rdata_o_fclk0;
wire [31:0] wdata_i_fclk0;
wire        we_i_fclk0; 
wire [31:0] addr_i_fclk0;
wire        sel_addr_i_fclk0, ena_addr_i_fclk0;
clkdiv u_fclk0 (
	.lok_data(lok_data_o_fclk0), .rdy_data(rdy_data_o_fclk0), 
	.rdata(rdata_o_fclk0),
	.wdata(wdata_i_fclk0),
  .we(we_i_fclk0), 
	.addr(addr_i_fclk0),
	.sel_addr(sel_addr_i_fclk0), .ena_addr(ena_addr_i_fclk0), 
  .lck(fclk[0]),
  .hwena(fclkena[0]), .rstb(rstb), .clk(clk) 
);

wire        lok_data_o_fclk1, rdy_data_o_fclk1;
wire [31:0] rdata_o_fclk1;
wire [31:0] wdata_i_fclk1;
wire        we_i_fclk1; 
wire [31:0] addr_i_fclk1;
wire        sel_addr_i_fclk1, ena_addr_i_fclk1;
clkdiv u_fclk1 (
	.lok_data(lok_data_o_fclk1), .rdy_data(rdy_data_o_fclk1), 
	.rdata(rdata_o_fclk1),
	.wdata(wdata_i_fclk1),
  .we(we_i_fclk1), 
	.addr(addr_i_fclk1),
	.sel_addr(sel_addr_i_fclk1), .ena_addr(ena_addr_i_fclk1), 
  .lck(fclk[1]),
  .hwena(fclkena[1]), .rstb(rstb), .clk(clk) 
);

wire        lok_data_o_fclk2, rdy_data_o_fclk2;
wire [31:0] rdata_o_fclk2;
wire [31:0] wdata_i_fclk2;
wire        we_i_fclk2; 
wire [31:0] addr_i_fclk2;
wire        sel_addr_i_fclk2, ena_addr_i_fclk2;
clkdiv u_fclk2 (
	.lok_data(lok_data_o_fclk2), .rdy_data(rdy_data_o_fclk2), 
	.rdata(rdata_o_fclk2),
	.wdata(wdata_i_fclk2),
  .we(we_i_fclk2), 
	.addr(addr_i_fclk2),
	.sel_addr(sel_addr_i_fclk2), .ena_addr(ena_addr_i_fclk2), 
  .lck(fclk[2]),
  .hwena(fclkena[2]), .rstb(rstb), .clk(clk) 
);

wire        lok_data_o_fclk3, rdy_data_o_fclk3;
wire [31:0] rdata_o_fclk3;
wire [31:0] wdata_i_fclk3;
wire        we_i_fclk3; 
wire [31:0] addr_i_fclk3;
wire        sel_addr_i_fclk3, ena_addr_i_fclk3;
clkdiv u_fclk3 (
	.lok_data(lok_data_o_fclk3), .rdy_data(rdy_data_o_fclk3), 
	.rdata(rdata_o_fclk3),
	.wdata(wdata_i_fclk3),
  .we(we_i_fclk3), 
	.addr(addr_i_fclk3),
	.sel_addr(sel_addr_i_fclk3), .ena_addr(ena_addr_i_fclk3), 
  .lck(fclk[3]),
  .hwena(fclkena[3]), .rstb(rstb), .clk(clk) 
);

wire        lok_data_o_uart0, rdy_data_o_uart0;
wire [31:0] rdata_o_uart0;
wire [31:0] wdata_i_uart0;
wire        we_i_uart0;
wire [31:0] addr_i_uart0;
wire        sel_addr_i_uart0, ena_addr_i_uart0;
uart #(
  .CHECK_SB(9), 
  .FIFO_AMSB(2), 
  .FIFO_DMSB(9) 
) u_uart0 (
  .lok_data(lok_data_o_uart0), .rdy_data(rdy_data_o_uart0), 
	.rdata(rdata_o_uart0),
	.wdata(wdata_i_uart0),
  .we(we_i_uart0), 
	.addr(addr_i_uart0),
	.sel_addr(sel_addr_i_uart0), .ena_addr(ena_addr_i_uart0), 
  .startena(), .stopena(), .match(),
  .rxe(rxe[0]), .txe(txe[0]), 
  .tx(tx[0]), 
  .rx(rx[0]), 
  .uclkena(fclkena[0]),
  .rstb(rstb), .clk(clk), .uclk(fclk[0]) 
);

wire        lok_data_o_uart1, rdy_data_o_uart1;
wire [31:0] rdata_o_uart1;
wire [31:0] wdata_i_uart1;
wire        we_i_uart1;
wire [31:0] addr_i_uart1;
wire        sel_addr_i_uart1, ena_addr_i_uart1;
uart #(
  .CHECK_SB(9), 
  .FIFO_AMSB(2), 
  .FIFO_DMSB(9) 
) u_uart1 (
  .lok_data(lok_data_o_uart1), .rdy_data(rdy_data_o_uart1), 
	.rdata(rdata_o_uart1),
	.wdata(wdata_i_uart1),
  .we(we_i_uart1), 
	.addr(addr_i_uart1),
	.sel_addr(sel_addr_i_uart1), .ena_addr(ena_addr_i_uart1), 
  .startena(), .stopena(), .match(),
  .rxe(rxe[1]), .txe(txe[1]), 
  .tx(tx[1]), 
  .rx(rx[1]), 
  .uclkena(fclkena[1]),
  .rstb(rstb), .clk(clk), .uclk(fclk[1]) 
);

wire        lok_data_o_uart2, rdy_data_o_uart2;
wire [31:0] rdata_o_uart2;
wire [31:0] wdata_i_uart2;
wire        we_i_uart2;
wire [31:0] addr_i_uart2;
wire        sel_addr_i_uart2, ena_addr_i_uart2;
uart #(
  .CHECK_SB(9), 
  .FIFO_AMSB(2), 
  .FIFO_DMSB(9) 
) u_uart2 (
  .lok_data(lok_data_o_uart2), .rdy_data(rdy_data_o_uart2), 
	.rdata(rdata_o_uart2),
	.wdata(wdata_i_uart2),
  .we(we_i_uart2), 
	.addr(addr_i_uart2),
	.sel_addr(sel_addr_i_uart2), .ena_addr(ena_addr_i_uart2), 
  .startena(), .stopena(), .match(),
  .rxe(rxe[2]), .txe(txe[2]), 
  .tx(tx[2]), 
  .rx(rx[2]), 
  .uclkena(fclkena[2]),
  .rstb(rstb), .clk(clk), .uclk(fclk[2]) 
);

wire        lok_data_o_uart3, rdy_data_o_uart3;
wire [31:0] rdata_o_uart3;
wire [31:0] wdata_i_uart3;
wire        we_i_uart3;
wire [31:0] addr_i_uart3;
wire        sel_addr_i_uart3, ena_addr_i_uart3;
uart #(
  .CHECK_SB(9), 
  .FIFO_AMSB(2), 
  .FIFO_DMSB(9) 
) u_uart3 (
  .lok_data(lok_data_o_uart3), .rdy_data(rdy_data_o_uart3), 
	.rdata(rdata_o_uart3),
	.wdata(wdata_i_uart3),
  .we(we_i_uart3), 
	.addr(addr_i_uart3),
	.sel_addr(sel_addr_i_uart3), .ena_addr(ena_addr_i_uart3), 
  .startena(), .stopena(), .match(),
  .rxe(rxe[3]), .txe(txe[3]), 
  .tx(tx[3]), 
  .rx(rx[3]), 
  .uclkena(fclkena[3]),
  .rstb(rstb), .clk(clk), .uclk(fclk[3]) 
);

wire        lok_data_o_io0, rdy_data_o_io0;
wire [31:0] rdata_o_io0;
wire [31:0] wdata_i_io0;
wire        we_i_io0;
wire [31:0] addr_i_io0;
wire        sel_addr_i_io0, ena_addr_i_io0;
i4o4p4cf u_io0 ( // input:4, output:4, pad:4, connect:full
	.lok_data(lok_data_o_io0), .rdy_data(rdy_data_o_io0), 
	.rdata(rdata_o_io0),
	.wdata(wdata_i_io0),
  .we(we_i_io0), 
	.addr(addr_i_io0),
	.sel_addr(sel_addr_i_io0), .ena_addr(ena_addr_i_io0),
  .pad(pad[3:0]), 
  .oe(txe[3:0]), 
  .ie(rxe[3:0]), 
  .di(tx[3:0]), 
  .dc(rx[3:0]), 
  .rstb(rstb), .clk(clk)
);

wire        sel_addr0, lok_data0;
wire [31:0] addr0, wdata0, rdata0;
wire        ena_addr0, rdy_data0, we0;
assign sel_addr0        = sel_pc_o_cpu0;
assign addr0            = pc_o_cpu0;
assign addr_i_rom0      = addr0;
assign sel_addr_i_rom0  = sel_addr0;
assign lok_data0        = lok_data_o_rom0;
assign lok_inst_i_cpu0  = lok_data0;
assign ena_addr0        = ena_pc_o_cpu0;
assign ena_addr_i_rom0  = ena_addr0;
assign wdata0           = 32'h0;
assign we0              = 1'b0;
assign rdata0           = rdata_o_rom0;
assign inst_i_cpu0      = rdata0;
assign rdy_data0        = rdy_data_o_rom0;
assign rdy_inst_i_cpu0  = rdy_data0;

wire        sel_addr1, lok_data1;
wire [31:0] addr1, wdata1, rdata1;
wire        ena_addr1, rdy_data1, we1;
parameter [31:0] B1_A0         =        32'h00000000 ;
parameter [31:0] B1_RAM0_A0    = (B1_A0+32'h00000000);
parameter [31:0] B1_RAM0_A1    = (B1_A0+32'h000001ff);
parameter [31:0] B1_TIMER0_A0  = (B1_A0+32'h00000200);
parameter [31:0] B1_TIMER0_A1  = (B1_A0+32'h00000207);
parameter [31:0] B1_TIMER1_A0  = (B1_A0+32'h00000300);
parameter [31:0] B1_TIMER1_A1  = (B1_A0+32'h00000307);
parameter [31:0] B1_TIMER2_A0  = (B1_A0+32'h00000400);
parameter [31:0] B1_TIMER2_A1  = (B1_A0+32'h00000407);
parameter [31:0] B1_TIMER3_A0  = (B1_A0+32'h00000500);
parameter [31:0] B1_TIMER3_A1  = (B1_A0+32'h00000507);
parameter [31:0] B1_FCLK0_A0   = (B1_A0+32'h00000600);
parameter [31:0] B1_FCLK0_A1   = (B1_A0+32'h00000607);
parameter [31:0] B1_FCLK1_A0   = (B1_A0+32'h00000700);
parameter [31:0] B1_FCLK1_A1   = (B1_A0+32'h00000707);
parameter [31:0] B1_FCLK2_A0   = (B1_A0+32'h00000800);
parameter [31:0] B1_FCLK2_A1   = (B1_A0+32'h00000807);
parameter [31:0] B1_FCLK3_A0   = (B1_A0+32'h00000900);
parameter [31:0] B1_FCLK3_A1   = (B1_A0+32'h00000907);
parameter [31:0] B1_UART0_A0   = (B1_A0+32'h00000a00);
parameter [31:0] B1_UART0_A1   = (B1_A0+32'h00000a0b);
parameter [31:0] B1_UART1_A0   = (B1_A0+32'h00000b00);
parameter [31:0] B1_UART1_A1   = (B1_A0+32'h00000b0b);
parameter [31:0] B1_UART2_A0   = (B1_A0+32'h00000c00);
parameter [31:0] B1_UART2_A1   = (B1_A0+32'h00000c0b);
parameter [31:0] B1_UART3_A0   = (B1_A0+32'h00000d00);
parameter [31:0] B1_UART3_A1   = (B1_A0+32'h00000d0b);
parameter [31:0] B1_IO0_A0     = (B1_A0+32'h00000e00);
parameter [31:0] B1_IO0_A1     = (B1_A0+32'h00000e07);
wire sel_addr1_ram0    = ((addr1>=B1_RAM0_A0   )&&(B1_RAM0_A1   >=addr1));
wire sel_addr1_timer0  = ((addr1>=B1_TIMER0_A0 )&&(B1_TIMER0_A1 >=addr1));
wire sel_addr1_timer1  = ((addr1>=B1_TIMER1_A0 )&&(B1_TIMER1_A1 >=addr1));
wire sel_addr1_timer2  = ((addr1>=B1_TIMER2_A0 )&&(B1_TIMER2_A1 >=addr1));
wire sel_addr1_timer3  = ((addr1>=B1_TIMER3_A0 )&&(B1_TIMER3_A1 >=addr1));
wire sel_addr1_fclk0   = ((addr1>=B1_FCLK0_A0  )&&(B1_FCLK0_A1  >=addr1));
wire sel_addr1_fclk1   = ((addr1>=B1_FCLK1_A0  )&&(B1_FCLK1_A1  >=addr1));
wire sel_addr1_fclk2   = ((addr1>=B1_FCLK2_A0  )&&(B1_FCLK2_A1  >=addr1));
wire sel_addr1_fclk3   = ((addr1>=B1_FCLK3_A0  )&&(B1_FCLK3_A1  >=addr1));
wire sel_addr1_uart0   = ((addr1>=B1_UART0_A0  )&&(B1_UART0_A1  >=addr1));
wire sel_addr1_uart1   = ((addr1>=B1_UART1_A0  )&&(B1_UART1_A1  >=addr1));
wire sel_addr1_uart2   = ((addr1>=B1_UART2_A0  )&&(B1_UART2_A1  >=addr1));
wire sel_addr1_uart3   = ((addr1>=B1_UART3_A0  )&&(B1_UART3_A1  >=addr1));
wire sel_addr1_io0     = ((addr1>=B1_IO0_A0    )&&(B1_IO0_A1    >=addr1));
assign sel_addr1 = sel_addr_o_cpu0;
assign addr1      = addr_o_cpu0;
assign addr_i_ram0    = addr1-B1_RAM0_A0   ;
assign addr_i_timer0  = addr1-B1_TIMER0_A0 ;
assign addr_i_timer1  = addr1-B1_TIMER1_A0 ;
assign addr_i_timer2  = addr1-B1_TIMER2_A0 ;
assign addr_i_timer3  = addr1-B1_TIMER3_A0 ;
assign addr_i_fclk0   = addr1-B1_FCLK0_A0  ;
assign addr_i_fclk1   = addr1-B1_FCLK1_A0  ;
assign addr_i_fclk2   = addr1-B1_FCLK2_A0  ;
assign addr_i_fclk3   = addr1-B1_FCLK3_A0  ;
assign addr_i_uart0   = addr1-B1_UART0_A0  ;
assign addr_i_uart1   = addr1-B1_UART1_A0  ;
assign addr_i_uart2   = addr1-B1_UART2_A0  ;
assign addr_i_uart3   = addr1-B1_UART3_A0  ;
assign addr_i_io0     = addr1-B1_IO0_A0    ;
assign sel_addr_i_ram0    = sel_addr1_ram0    ? sel_addr1 : 1'b0;
assign sel_addr_i_timer0  = sel_addr1_timer0  ? sel_addr1 : 1'b0;
assign sel_addr_i_timer1  = sel_addr1_timer1  ? sel_addr1 : 1'b0;
assign sel_addr_i_timer2  = sel_addr1_timer2  ? sel_addr1 : 1'b0;
assign sel_addr_i_timer3  = sel_addr1_timer3  ? sel_addr1 : 1'b0;
assign sel_addr_i_fclk0   = sel_addr1_fclk0   ? sel_addr1 : 1'b0;
assign sel_addr_i_fclk1   = sel_addr1_fclk1   ? sel_addr1 : 1'b0;
assign sel_addr_i_fclk2   = sel_addr1_fclk2   ? sel_addr1 : 1'b0;
assign sel_addr_i_fclk3   = sel_addr1_fclk3   ? sel_addr1 : 1'b0;
assign sel_addr_i_uart0   = sel_addr1_uart0   ? sel_addr1 : 1'b0;
assign sel_addr_i_uart1   = sel_addr1_uart1   ? sel_addr1 : 1'b0;
assign sel_addr_i_uart2   = sel_addr1_uart2   ? sel_addr1 : 1'b0;
assign sel_addr_i_uart3   = sel_addr1_uart3   ? sel_addr1 : 1'b0;
assign sel_addr_i_io0     = sel_addr1_io0     ? sel_addr1 : 1'b0;
assign lok_data1 = 
  sel_addr1_ram0    ? lok_data_o_ram0    : 
  sel_addr1_timer0  ? lok_data_o_timer0  : 
  sel_addr1_timer1  ? lok_data_o_timer1  : 
  sel_addr1_timer2  ? lok_data_o_timer2  : 
  sel_addr1_timer3  ? lok_data_o_timer3  : 
  sel_addr1_fclk0   ? lok_data_o_fclk0   : 
  sel_addr1_fclk1   ? lok_data_o_fclk1   : 
  sel_addr1_fclk2   ? lok_data_o_fclk2   : 
  sel_addr1_fclk3   ? lok_data_o_fclk3   : 
  sel_addr1_uart0   ? lok_data_o_uart0   : 
  sel_addr1_uart1   ? lok_data_o_uart1   : 
  sel_addr1_uart2   ? lok_data_o_uart2   : 
  sel_addr1_uart3   ? lok_data_o_uart3   : 
  sel_addr1_io0     ? lok_data_o_io0     : 
  1'b0;
assign lok_data_i_cpu0 = lok_data1;
assign ena_addr1  = ena_addr_o_cpu0;
assign ena_addr_i_ram0    =  ena_addr1;
assign ena_addr_i_timer0  =  ena_addr1;
assign ena_addr_i_timer1  =  ena_addr1;
assign ena_addr_i_timer2  =  ena_addr1;
assign ena_addr_i_timer3  =  ena_addr1;
assign ena_addr_i_fclk0   =  ena_addr1;
assign ena_addr_i_fclk1   =  ena_addr1;
assign ena_addr_i_fclk2   =  ena_addr1;
assign ena_addr_i_fclk3   =  ena_addr1;
assign ena_addr_i_uart0   =  ena_addr1;
assign ena_addr_i_uart1   =  ena_addr1;
assign ena_addr_i_uart2   =  ena_addr1;
assign ena_addr_i_uart3   =  ena_addr1;
assign ena_addr_i_io0     =  ena_addr1;
assign wdata1 = wdata_o_cpu0;
assign wdata_i_ram0    = wdata1;
assign wdata_i_timer0  = wdata1;
assign wdata_i_timer1  = wdata1;
assign wdata_i_timer2  = wdata1;
assign wdata_i_timer3  = wdata1;
assign wdata_i_fclk0   = wdata1;
assign wdata_i_fclk1   = wdata1;
assign wdata_i_fclk2   = wdata1;
assign wdata_i_fclk3   = wdata1;
assign wdata_i_uart0   = wdata1;
assign wdata_i_uart1   = wdata1;
assign wdata_i_uart2   = wdata1;
assign wdata_i_uart3   = wdata1;
assign wdata_i_io0     = wdata1;
assign we1 = we_o_cpu0;
assign we_i_ram0    = we1;
assign we_i_timer0  = we1;
assign we_i_timer1  = we1;
assign we_i_timer2  = we1;
assign we_i_timer3  = we1;
assign we_i_fclk0   = we1;
assign we_i_fclk1   = we1;
assign we_i_fclk2   = we1;
assign we_i_fclk3   = we1;
assign we_i_uart0   = we1;
assign we_i_uart1   = we1;
assign we_i_uart2   = we1;
assign we_i_uart3   = we1;
assign we_i_io0     = we1;
assign rdata1 = 
  sel_addr1_ram0    ? rdata_o_ram0    : 
  sel_addr1_timer0  ? rdata_o_timer0  : 
  sel_addr1_timer1  ? rdata_o_timer1  : 
  sel_addr1_timer2  ? rdata_o_timer2  : 
  sel_addr1_timer3  ? rdata_o_timer3  : 
  sel_addr1_fclk0   ? rdata_o_fclk0   : 
  sel_addr1_fclk1   ? rdata_o_fclk1   : 
  sel_addr1_fclk2   ? rdata_o_fclk2   : 
  sel_addr1_fclk3   ? rdata_o_fclk3   : 
  sel_addr1_uart0   ? rdata_o_uart0   : 
  sel_addr1_uart1   ? rdata_o_uart1   : 
  sel_addr1_uart2   ? rdata_o_uart2   : 
  sel_addr1_uart3   ? rdata_o_uart3   : 
  sel_addr1_io0     ? rdata_o_io0     : 
  32'd0;
assign rdata_i_cpu0 = rdata1;
assign rdy_data1 = 
  sel_addr1_ram0    ? rdy_data_o_ram0    : 
  sel_addr1_timer0  ? rdy_data_o_timer0  : 
  sel_addr1_timer1  ? rdy_data_o_timer1  : 
  sel_addr1_timer2  ? rdy_data_o_timer2  : 
  sel_addr1_timer3  ? rdy_data_o_timer3  : 
  sel_addr1_fclk0   ? rdy_data_o_fclk0   : 
  sel_addr1_fclk1   ? rdy_data_o_fclk1   : 
  sel_addr1_fclk2   ? rdy_data_o_fclk2   : 
  sel_addr1_fclk3   ? rdy_data_o_fclk3   : 
  sel_addr1_uart0   ? rdy_data_o_uart0   : 
  sel_addr1_uart1   ? rdy_data_o_uart1   : 
  sel_addr1_uart2   ? rdy_data_o_uart2   : 
  sel_addr1_uart3   ? rdy_data_o_uart3   : 
  sel_addr1_io0     ? rdy_data_o_io0     : 
  1'b0;
assign rdy_data_i_cpu0 = rdy_data1;

endmodule


`ifdef SIM
module tb1;

reg rstb, clk, setb;
wire idle;
tri [3:0] pad;
tri csb, sio, scl;

top u_top (
`ifndef FPGA
  .scan_ena(1'b0), .scan_clk(1'b0), 
`endif
  .csb(csb), .sio(sio), .scl(scl), 
  .pad(pad),
  .idle(idle), 
  .setb(setb), 
  .rstb(rstb), .clk(clk)
);

//s80ks2563 u_psram (.DQ7(pad[19]),.DQ6(pad[18]),.DQ5(pad[17]),.DQ4(pad[16]),.DQ3(pad[15]),.DQ2(pad[14]),.DQ1(pad[13]),.DQ0(pad[12]),.RWDS(),.CSNeg(pad[5]),.CK(~pad[9]),.CKn(pad[9]),.RESET(rstb));
//MX25LM51245G u_flash ( .SCLK(pad[9]), .CS(pad[5]), .SIO(pad[19:12]),  .DQS(), .ECSB(), .RESET(rstb) );
//MX25L1005 u_flash ( .SCLK(pad[9]), .CS(pad[5]), .SI(pad[12]), .SO(pad[12]), .WP(), .HOLD() );
//W25Q128JVxIM u_flash (.CSn(pad[5]), .CLK(pad[9]), .DIO(pad[12]), .DO(pad[12]), .WPn(), .HOLDn() );
//MX25L12835F u_flash( .SCLK(pad[9]), .CS(pad[5]),  .SI(pad[12]), .SO(pad[13]), .WP(pad[14]), .RESET(rstb), .SIO3(pad[15]) );
xip_W25Q128JVxIM u_xip (.CSn(csb), .CLK(scl), .DIO(sio), .DO(sio), .WPn(), .HOLDn() );
//xip_MX25L1005 u_xip ( .SCLK(scl), .CS(cs), .SI(sio), .SO(sio), .WP(), .HOLD() );
/*
riscv32-unknown-elf-gcc -march=rv32e -mabi=ilp32e -nostartfiles -nostdinc -nostdlib -mno-relax -O1 -c 104.c -g -o 104.o && riscv32-unknown-elf-ld -T 104.ld -o 104.elf 104.o && riscv32-unknown-elf-objcopy -O binary 104.elf 104.bin && riscv32-unknown-elf-objdump -S 104.o && ./bin2memh 104.bin 0x4000 > rom.memh 
*/

always #10 clk = ~clk;

always@(posedge u_top.u_timer0.en) $write("%d ns: timer0.en\n",$time);
always@(posedge u_top.u_timer1.en) $write("%d ns: timer1.en\n",$time);
always@(posedge u_top.u_timer2.en) $write("%d ns: timer2.en\n",$time);
always@(posedge u_top.u_timer3.en) $write("%d ns: timer3.en\n",$time);
always@(negedge u_top.u_timer0.en) $write("%d ns: timer0.enb\n",$time);
always@(negedge u_top.u_timer1.en) $write("%d ns: timer1.enb\n",$time);
always@(negedge u_top.u_timer2.en) $write("%d ns: timer2.enb\n",$time);
always@(negedge u_top.u_timer3.en) $write("%d ns: timer3.enb\n",$time);
always@(posedge u_top.u_timer0.hit) $write("%d ns: timer0.hit\n",$time);
always@(posedge u_top.u_timer1.hit) $write("%d ns: timer1.hit\n",$time);
always@(posedge u_top.u_timer2.hit) $write("%d ns: timer2.hit\n",$time);
always@(posedge u_top.u_timer3.hit) $write("%d ns: timer3.hit\n",$time);
always@(posedge u_top.u_fclk0.setb) $write("%d ns: flck0.setb\n",$time);
always@(posedge u_top.u_fclk1.setb) $write("%d ns: flck1.setb\n",$time);
always@(posedge u_top.u_fclk2.setb) $write("%d ns: flck2.setb\n",$time);
always@(posedge u_top.u_fclk3.setb) $write("%d ns: flck3.setb\n",$time);
always@(negedge u_top.u_fclk0.setb) $write("%d ns: flck0.set\n",$time);
always@(negedge u_top.u_fclk1.setb) $write("%d ns: flck1.set\n",$time);
always@(negedge u_top.u_fclk2.setb) $write("%d ns: flck2.set\n",$time);
always@(negedge u_top.u_fclk3.setb) $write("%d ns: flck3.set\n",$time);
always@(posedge u_top.u_uart0.setb) $write("%d ns: uart0.setb\n",$time);
always@(posedge u_top.u_uart1.setb) $write("%d ns: uart1.setb\n",$time);
always@(posedge u_top.u_uart2.setb) $write("%d ns: uart2.setb\n",$time);
always@(posedge u_top.u_uart3.setb) $write("%d ns: uart3.setb\n",$time);
always@(negedge u_top.u_uart0.setb) $write("%d ns: uart0.set\n",$time);
always@(negedge u_top.u_uart1.setb) $write("%d ns: uart1.set\n",$time);
always@(negedge u_top.u_uart2.setb) $write("%d ns: uart2.set\n",$time);
always@(negedge u_top.u_uart3.setb) $write("%d ns: uart3.set\n",$time);
always@(posedge u_top.u_uart0.full) $write("%d ns: uart0.full\n",$time);
always@(posedge u_top.u_uart1.full) $write("%d ns: uart1.full\n",$time);
always@(posedge u_top.u_uart2.full) $write("%d ns: uart2.full\n",$time);
always@(posedge u_top.u_uart3.full) $write("%d ns: uart3.full\n",$time);
always@(negedge u_top.u_uart0.full) $write("%d ns: uart0.fullb\n",$time);
always@(negedge u_top.u_uart1.full) $write("%d ns: uart1.fullb\n",$time);
always@(negedge u_top.u_uart2.full) $write("%d ns: uart2.fullb\n",$time);
always@(negedge u_top.u_uart3.full) $write("%d ns: uart3.fullb\n",$time);
always@(posedge u_top.u_uart0.empty) $write("%d ns: uart0.empty\n",$time);
always@(posedge u_top.u_uart1.empty) $write("%d ns: uart1.empty\n",$time);
always@(posedge u_top.u_uart2.empty) $write("%d ns: uart2.empty\n",$time);
always@(posedge u_top.u_uart3.empty) $write("%d ns: uart3.empty\n",$time);
always@(negedge u_top.u_uart0.empty) $write("%d ns: uart0.emptyb\n",$time);
always@(negedge u_top.u_uart1.empty) $write("%d ns: uart1.emptyb\n",$time);
always@(negedge u_top.u_uart2.empty) $write("%d ns: uart2.emptyb\n",$time);
always@(negedge u_top.u_uart3.empty) $write("%d ns: uart3.emptyb\n",$time);
//always@(posedge u_top.u_uart0.push) $write("%c",u_top.u_uart0.wchar[7:0]);

initial begin
  `ifdef FST
  $dumpfile("a.fst");
  $dumpvars(0,tb1);
  `endif
  `ifdef FSDB
  $fsdbDumpfile("a.fsdb");
  $fsdbDumpvars(0,tb1);
  `endif
  clk = 0;
  rstb = 0;
  setb = 0;
  repeat(2) begin
    //for(ram_i=0;ram_i<='h3f;ram_i=ram_i+1) u_top.u_ram.mem[ram_i] <= 32'd0;
    #100 @(posedge clk); rstb = 1;
    repeat(10) @(posedge clk); setb = 1;
    while(~idle) @(posedge clk);
    repeat(10) @(posedge clk); setb = 0;
    #100 rstb = 0;
  end
  $finish;
end

endmodule
`endif
