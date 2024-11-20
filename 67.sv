`timescale 1ns/1ps


`define LPTIMER_USE_LOCK 1'b0 
`define LPTIMER_INC_MODE 1'b1
module timer ( // u_timer slave 532
  output irq, 
  input halt, 
  input fclk, 
  output reg [31:0] prdata, 
  input [31:0] pwdata, 
  input [2:0] paddr, 
  input psel, pwrite, penable, 
  input prstb, pclk 
);

reg en, ld, os, fr, ie, ee, is, es, he, lr;
reg [31:0] cntr, load, load_d;
wire lock = `LPTIMER_USE_LOCK ? lr : 1'b0;
wire eq = cntr == (`LPTIMER_INC_MODE ? load_d : 0);
wire run = en && (~(halt && he));
reg [1:0] run_d, ld_d, eq_d, hit_d;
wire err = es && ee;
assign irq = (is && ie) || err;
wire run_1 = run_d==2'b11;
wire ld_1 = ld_d==2'b11;
wire eq_1 = eq_d==2'b11;
wire hit = eq_1 && run;
wire hit_1 = hit_d==2'b11;

always@(negedge prstb or posedge fclk) begin
  if(~prstb) begin
    run_d <= 2'b00;
    ld_d <= 2'b00;
    load_d <= 32'd0;
    hit_d <= 2'b00;
  end
  else begin
    run_d <= {run_d[0],run};
    ld_d <= {ld_d[0],(ld || (eq && ~fr))};
    load_d <= load;
    hit_d <= {hit_d[0],hit};
  end
end
always@(negedge prstb or posedge pclk) begin
  if(~prstb) begin
    eq_d <= 2'b00;
  end
  else begin
    eq_d <= {eq_d[0],eq};
  end
end
always@(negedge prstb or posedge fclk) begin
  if(~prstb) cntr <= 32'd0;
  else if(ld_1) cntr <= (`LPTIMER_INC_MODE ? 32'd0 : load_d);
  else if(run_1) cntr <= eq ? 
    (`LPTIMER_INC_MODE ? 32'd0 : load_d): 
    (`LPTIMER_INC_MODE ? (cntr + 32'd1) : (cntr - 32'd1));
end

wire ctrl_ena = (paddr == 'h0) && psel;
wire cntr_ena = (paddr == 'h4) && psel;

always@(*) begin
  prdata = 32'd0;
  if(ctrl_ena && penable) begin
    prdata[0] = en; // "timer enable"
    prdata[1] = ld; // "force reload"
    prdata[2] = os; // "one-shot mode"
    prdata[3] = fr; // "free-run mode"
    prdata[4] = ie; // "timer interrupt enable"
    prdata[5] = ee; // "timer error enable"
    prdata[6] = is; // "timer interrupt status"
    prdata[7] = es; // "timer error status"
    prdata[8] = he; // "timer halt enable"
    prdata[9] = lr; // "lock register"
    // prdata[31:10] = unused0[21:0];
  end
  else if(cntr_ena && penable) begin
    prdata[31:0] = cntr[31:0];
  end
end

always@(negedge prstb or posedge pclk) begin
  if(~prstb) begin //default
    en <= 'h0;
    ld <= 'h0;
    os <= 'h0;
    fr <= 'h0;
    ie <= 'h0;
    ee <= 'h0;
    is <= 'h0;
    es <= 'h0;
    he <= 'h0;
    lr <= 'h0;
    load[31:0] <= 'h0;
  end
  else if(ctrl_ena && pwrite && penable) begin
    if(~lock) begin
      en <= pwdata[0];
      os <= pwdata[2];
      fr <= pwdata[3];
      ie <= pwdata[4];
      ee <= pwdata[5];
      is <= pwdata[6] ? 1'b0 : is; // w1c
      es <= pwdata[7] ? 1'b0 : es; // w1c
      he <= pwdata[8];
    end
    ld <= pwdata[1];
    lr <= pwdata[9];
  end
  else if(cntr_ena && pwrite && penable && ~lock) begin
    // replace load cntr
    load[31:0] <= pwdata[31:0];
  end
  else begin
    if(hit && os) en <= 1'b0;
    if(hit) is <= 1'b1;
    if(hit_1) es <= 1'b1;
  end
end

endmodule


`define LPUART_FIFO_AMSB 4 
module lpuart (
  output tx, rts, 
  input rx, cts, 
  output reg uclk, 
  output intr,
  output full, empty,
  input pop, push,
  input [`LPUART_FIFO_AMSB:0] th, 
  output [`LPUART_FIFO_AMSB:0] cnt,
  output [9:0] rchar,
  input [9:0] wchar,
  input [15:0] divisor, dividend,
  input fc,
  input [5:0] mode,
  output reg [3:0] a, na, 
  input clear, setb,
  input frstb, fclk,
  input rstb, clk
);

wire ena_8bit = mode[1:0] == 2'b01;
wire ena_7bit = mode[1:0] == 2'b10;
wire ena_6bit = mode[1:0] == 2'b11;
wire ena_parity = mode[2];
wire even = mode[3];
wire ena_tx = mode[4];
wire ena_2stop = mode[5];
reg [15:0] fcnt;
reg [1:0] uclk_d;
wire uclk_p = uclk_d == 2'b01;
wire uclk_n = uclk_d == 2'b10;
reg [9:0] b[0:((2**`LPUART_FIFO_AMSB)-1)];
reg [`LPUART_FIFO_AMSB:0] ba1, ba0;
assign cnt = ba1 - ba0;
assign full  = cnt == (2**`LPUART_FIFO_AMSB);
assign empty = cnt == 'h0;
wire [9:0] wbc = ena_tx ? b[ba0[(`LPUART_FIFO_AMSB-1):0]] : 10'h3ff;
wire [9:0] rbc = ena_tx ? 10'h3ff : b[ba1[(`LPUART_FIFO_AMSB-1):0]];
wire xortx = 
  ena_8bit ? ^(wbc[6:0]) : 
  ena_7bit ? ^(wbc[5:0]) : 
  ena_6bit ? ^(wbc[4:0]) : 
  ^wbc;
wire xorrx = 
  ena_8bit ? ^(rbc[7:0]) : 
  ena_7bit ? ^(rbc[6:0]) : 
  ena_6bit ? ^(rbc[5:0]) : 
  ^rbc[8:0];
assign tx = ena_tx ? (
  (a >= 4'hc) ? 1'b0 : 
  (a >= 4'hb) ? 1'b1 : 
  (a >= 4'ha) ? 1'b1 : 
  (ena_parity && (a == 4'h9)) ? (even ? ~xortx : xortx) : 
  b[ba0[(`LPUART_FIFO_AMSB-1):0]][a]) : 
  1'b1;
reg [1:0] clear_d, push_d, pop_d;
wire clear_p = clear_d == 2'b01;
wire push_p = push_d == 2'b01;
wire pop_p = pop_d == 2'b01;
assign rchar = ena_tx? 8'hff:b[ba0[(`LPUART_FIFO_AMSB-1):0]];
assign rts = (a==4'hb) && (na==4'hb);
reg [1:0] fclear_d;
wire fclear_p = fclear_d == 2'b01;
reg [1:0] fsetb_d;
wire fsetb_1 = fsetb_d == 2'b11;
reg err;

always@(negedge frstb or posedge fclk) begin
  if(~frstb) begin
    fclear_d <= 2'b00;
    fsetb_d <= 2'b00;
  end
  else begin
    fclear_d <= {fclear_d[0],(ena_tx? clear:((a==4'hb)&&(~rx)))};
    fsetb_d <= {fsetb_d[0],setb};
  end
end
always@(negedge rstb or posedge clk) begin
  if(~rstb) begin
    uclk_d <= 2'b11;
    clear_d <= 2'b11;
    pop_d <= 2'b11;
    push_d <= 2'b11;
  end
  else begin
    uclk_d <= {uclk_d[0],uclk};
    clear_d <= {clear_d[0],clear};
    pop_d <= {pop_d[0],pop};
    push_d <= {push_d[0],push};
  end
end

always@(negedge frstb or posedge fclk) begin  
  if(~frstb) begin
    fcnt <= 16'd0;
    uclk <= 1'b0;
  end
  else if(fsetb_1) begin
  if(fclear_p) begin
    fcnt <= dividend >> (ena_tx ? 1 : 3);
    uclk <= 1'b1;
  end
  else begin
    if(fcnt >= dividend) begin
      fcnt <= fcnt - dividend + divisor;
      uclk <= 1'b1;
    end
    else begin
      fcnt <= fcnt + divisor;
      if(fcnt >= (dividend >> 1)) uclk <= 1'b0;
    end
  end
  end
end

always@(negedge rstb or posedge clk) begin
  if(~rstb) a <= 4'hb;
  else if((~setb)||clear_p) a <= 4'hb;
  else if(setb && uclk_n && (~fclear_p)) a <= na;
end
always@(*) begin
  na = a;
  case(a)
    4'hb: if(fc? cts:(ena_tx? (~empty):(~rx))) na = 4'hc;
    4'hc: na = 4'h0;
    4'h5: na = ena_6bit? (ena_parity? 4'h9:(ena_2stop? 4'ha:4'hb)): a + 4'h1;
    4'h6: na = ena_7bit? (ena_parity? 4'h9:(ena_2stop? 4'ha:4'hb)): a + 4'h1;
    4'h7: na = ena_8bit? (ena_parity? 4'h9:(ena_2stop? 4'ha:4'hb)): a + 4'h1;
    4'h8: na = ena_parity? 4'h9:(ena_2stop? 4'ha:4'hb);
    4'h9: na = ena_2stop? 4'ha:4'hb;
    default: na = a + 4'h1;
  endcase
end

always@(posedge clk) begin
  if(setb) begin
    if(push_p & ena_tx) b[ba1[(`LPUART_FIFO_AMSB-1):0]] <= wchar[9:0];
    else if((~ena_tx) && uclk_n && (4'h8 >= na)) begin
      b[ba1[(`LPUART_FIFO_AMSB-1):0]][na] <= rx;
      err <= 1'b0;
    end
    else if((~ena_tx) && uclk_n && (4'h9 == na)) err <= ((even? ~xorrx:xorrx)!=rx);
    else if((~ena_tx) && uclk_n && (4'ha == na)) err <= ((~rx)||err);
    else if((~ena_tx) && uclk_n && (4'hb == na)) 
      b[ba1[(`LPUART_FIFO_AMSB-1):0]][9] <= ((~rx)||(ena_parity? err:1'b0));
  end
end

always@(negedge rstb or posedge clk) begin
  if(~rstb) {ba1,ba0} <= {((`LPUART_FIFO_AMSB+1)*2){1'b0}};
  else if(clear_p) {ba1,ba0} <= {((`LPUART_FIFO_AMSB+1)*2){1'b0}};
  else begin
    if(ena_tx && push_p && (~full)) ba1 <= ba1 + 'd1;
    if(ena_tx && (na==4'hb) && uclk_n && (~empty)) ba0 <= ba0 + 'd1;
    if((~ena_tx) && (a!=4'hb) && (na==4'hb) && uclk_n && (~full)) ba1 <= ba1 + 'd1;
    if((~ena_tx) && pop_p && (~empty)) ba0 <= ba0 + 'd1;
  end
end

assign intr = ena_tx? (th>=cnt):(cnt>=th);

endmodule


module apb_lpuart ( // u_lpuart1 slave 512  u_lpuart2 slave 528 
  output [8:0] debug,
  input dma_ack, 
  output reg dma_req, 
  output reg irq, 
  output tx, rts, 
  input rx, cts, 
  input frstb, fclk, 
  output reg [31:0] prdata, 
  input [31:0] pwdata, 
  input [3:0] paddr, 
  input pwrite, psel, penable, prstb, pclk 
);

reg [1:0] dma_ack_d;
wire dma_ack_p = dma_ack_d == 2'b01;
reg dma_ena;
wire full, empty;
wire pop, push;
reg [4:0] th;
wire [4:0] cnt;
wire [9:0] rchar;
reg [9:0] wchar;
reg [15:0] divisor, dividend;
reg fc;
reg [5:0] mode;
reg clear, setb;
wire [3:0] a, na;
wire uclk;
reg intr_ena;
wire intr;
reg empty_ena, full_ena;
reg wire_start_ena, wire_stop_ena;
wire wire_start = na==4'hd;
wire wire_stop = (a==4'hb)||(a==4'hc);
wire nxt_irq = 
  (wire_stop_ena && wire_stop)||
  (wire_start_ena && wire_start)||
  (full_ena && full)||
  (empty_ena && empty)||
  (intr_ena && intr);
reg [1:0] nxt_irq_d;
wire nxt_irq_p = nxt_irq_d == 2'b01;
reg clear_irq;

lpuart u_lpuart (
  .tx(tx), .rts(rts), 
  .rx(rx), .cts(cts), 
  .uclk(uclk), 
  .intr(intr), 
  .full(full), .empty(empty), 
  .pop(dma_ena? dma_ack:pop), .push(dma_ena? dma_ack:push), 
  .th(th), 
  .cnt(cnt), 
  .rchar(rchar), 
  .wchar(wchar), 
  .divisor(divisor), .dividend(dividend), 
  .fc(fc), 
  .mode(mode), 
  .a(a), .na(na), 
  .clear(clear), .setb(setb), 
  .frstb(frstb), .fclk(fclk), 
  .rstb(prstb), .clk(pclk) 
);

always@(negedge prstb or posedge pclk) begin
  if(~prstb) begin
    dma_ack_d <= 2'b11;
    dma_req <= 1'b0;
    nxt_irq_d <= 2'b11;
  end
  else begin
    dma_ack_d <= {dma_ack_d[0],dma_ack};
    if(dma_ack_p) dma_req <= 1'b0;
    else if(intr) dma_req <= 1'b1;
    nxt_irq_d <= {nxt_irq_d[0],nxt_irq};
  end
end

wire ctrl_ena = (paddr == 'h0) && psel;
wire baud_ena = (paddr == 'h4) && psel;
wire data_ena = (paddr == 'h8) && psel;
wire fifo_ena = (paddr == 'hc) && psel;

always@(*) begin
  prdata = 32'd0;
  if(ctrl_ena) begin
    prdata[0] = setb;
    prdata[1] = clear;
    prdata[7:2] = mode[5:0];
    prdata[8] = fc;
    prdata[9] = dma_ena;
    prdata[10] = intr_ena;
    prdata[11] = empty_ena;
    prdata[12] = full_ena;
    prdata[13] = wire_start_ena;
    prdata[14] = wire_stop_ena;
    prdata[15] = clear_irq;
    // prdata[31:16] = unused0[15:0];
  end
  else if(baud_ena) begin
    prdata[15:0] = dividend[15:0];
    prdata[31:16] = divisor[15:0];
  end
  else if(data_ena) begin
    // replace rchar[9:0] bchar[9:0] 
    prdata[9:0] = rchar[9:0];
    // prdata[31:10] = unused1[21:0];
  end
  else if(fifo_ena) begin
    prdata[3:0] = cnt[3:0];
    prdata[7:4] = th[3:0];
    prdata[8] = empty;
    prdata[9] = full;
    prdata[10] = intr;
    // prdata[31:11] = unused2[20:0];
  end
end

always@(negedge prstb or posedge pclk) begin
  if(~prstb) begin //default 
    setb <= 'h0;
    clear <= 'h0;
    mode <= 'h1;
    fc <= 'h0;
    dma_ena <= 'h0;
    intr_ena <= 'h0;
    empty_ena <= 'h0;
    full_ena <= 'h0;
    wire_start_ena <= 'h0;
    wire_stop_ena <= 'h0;
    clear_irq <= 'h0;
    dividend <= 'h7ffe;
    divisor <= 'h075f;
    // replace wchar[9:0] bchar[9:0] 
    wchar <= 'h0;
    th <= 'h0;
  end
  else if(ctrl_ena && pwrite) begin
    setb <= pwdata[0];
    clear <= pwdata[1];
    mode[5:0] <= pwdata[7:2];
    fc <= pwdata[8];
    dma_ena <= pwdata[9];
    intr_ena <= pwdata[10];
    empty_ena <= pwdata[11];
    full_ena <= pwdata[12];
    wire_start_ena <= pwdata[13];
    wire_stop_ena <= pwdata[14];
    if(clear_irq) clear_irq <= 1'b0; 
    else clear_irq <= pwdata[15]; //w1c
  end
  else if(baud_ena && pwrite) begin
    dividend[15:0] <= pwdata[15:0];
    divisor[15:0] <= pwdata[31:16];
  end
  else if(data_ena && pwrite) begin
    wchar[9:0] <= pwdata[9:0];
  end
  else if(fifo_ena && pwrite) begin
    th[3:0] <= pwdata[7:4];
    th[4] <= 1'b0;
  end
end

always@(negedge prstb or posedge pclk) begin
  if(~prstb) irq <= 'h0;
  else begin
    if(clear_irq) irq <= 'h0;
    else if(nxt_irq_p) irq <= 'h1;
  end
end
assign push = data_ena && pwrite && psel && penable;
assign pop = data_ena && (~pwrite) && psel && penable;

assign debug[3:0] = a[3:0];
assign debug[7:4] = na[3:0];
assign debug[8] = uclk;

endmodule


module rv32i (
  input [31:0] rdata, 
  output reg [31:0] wdata, 
  output reg enable, 
  output write, sel, busreq, 
  input ready, grant, 
  output reg [31:0] addr, 
  output idle, 
  input [31:0] inst, 
  output reg [31:0] pc, 
  input [31:0] pc0, pc1, 
  input setb, fetch, 
  input rstb, clk 
);

assign idle = (pc >= pc1) || (pc0 > pc1);
reg [31:0] x[1:31];
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
wire i_nop   = fmti   && (~|inst[31:7]);
wire i_add   = fmtr   && (funct3==3'h0) && (funct7==7'h00);
wire i_sub   = fmtr   && (funct3==3'h0) && (funct7==7'h20);
wire i_xor   = fmtr   && (funct3==3'h4) && (funct7==7'h00);
wire i_or    = fmtr   && (funct3==3'h6) && (funct7==7'h00);
wire i_and   = fmtr   && (funct3==3'h7) && (funct7==7'h00);
wire i_sll   = fmtr   && (funct3==3'h1) && (funct7==7'h00);
wire i_srl   = fmtr   && (funct3==3'h5) && (funct7==7'h00);
wire i_sra   = fmtr   && (funct3==3'h5) && (funct7==7'h20);
wire i_slt   = fmtr   && (funct3==3'h2) && (funct7==7'h00);
wire i_sltu  = fmtr   && (funct3==3'h3) && (funct7==7'h00);
wire i_addi  = fmti   && (funct3==3'h0);
wire i_xori  = fmti   && (funct3==3'h4);
wire i_ori   = fmti   && (funct3==3'h6);
wire i_andi  = fmti   && (funct3==3'h7);
wire i_slli  = fmti   && (funct3==3'h1) && (imm[11:5]==7'h00);
wire i_srli  = fmti   && (funct3==3'h5) && (imm[11:5]==7'h00);
wire i_srai  = fmti   && (funct3==3'h5) && (imm[11:5]==7'h20);
wire i_slti  = fmti   && (funct3==3'h2);
wire i_sltiu = fmti   && (funct3==3'h3);
wire i_lb    = fmtil  && (funct3==3'h0);
wire i_lh    = fmtil  && (funct3==3'h1);
wire i_lw    = fmtil  && (funct3==3'h2);
wire i_lbu   = fmtil  && (funct3==3'h4);
wire i_lhu   = fmtil  && (funct3==3'h5);
wire i_sb    = fmts   && (funct3==3'h0);
wire i_sh    = fmts   && (funct3==3'h1);
wire i_sw    = fmts   && (funct3==3'h2);
wire i_beq   = fmtb   && (funct3==3'h0);
wire i_bne   = fmtb   && (funct3==3'h1);
wire i_blt   = fmtb   && (funct3==3'h4);
wire i_bge   = fmtb   && (funct3==3'h5);
wire i_bltu  = fmtb   && (funct3==3'h6);
wire i_bgeu  = fmtb   && (funct3==3'h7);
wire i_jal   = fmtj;
wire i_jalr  = fmtijr && (funct3==3'h0);
wire i_lui   = fmtu;
wire i_auipc = fmtup;
//wire i_ecall  = fmtie  && (funct3==3'h0) && (funct7==7'h0);
//wire i_ebreak = fmtie  && (funct3==3'h0) && (funct7==7'h1);
assign busreq = (fmtil || fmts);
assign write = fmts && grant;
assign sel = busreq && grant;
wire [31:0] xrs1 = (rs1==5'd0)? 32'd0:x[rs1];
wire [31:0] xrs2 = (rs2==5'd0)? 32'd0:x[rs2];
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
  i_add   ? (xrs1 +  xrs2):
  i_sub   ? (xrs1 +  ~xrs2 + 32'd1):
  i_xor   ? (xrs1 ^  xrs2):
  i_or    ? (xrs1 |  xrs2):
  i_and   ? (xrs1 &  xrs2):
  i_sll   ? (xrs1 << xrs2):
  i_srl   ? (xrs1 >> xrs2):
  i_sra   ? (xrs1s? (~((~xrs1) >> xrs2)):(xrs1 >> xrs2)):
  i_slt   ? (lt? 32'd1:32'd0):
  i_sltu  ? (ltu? 32'd1:32'd0):
  i_addi  ? (xrs1 +  imm):
  i_xori  ? (xrs1 ^  imm):
  i_ori   ? (xrs1 |  imm):
  i_andi  ? (xrs1 &  imm):
  i_slli  ? (xrs1 << imm[4:0]):
  i_srli  ? (xrs1 >> imm[4:0]):
  i_srai  ? (xrs1s? (~((~xrs1) >> imm[4:0])):(xrs1 >> imm[4:0])):
  i_slti  ? (lti? 32'd1:32'd0):
  i_sltiu ? (ltiu? 32'd1:32'd0):
  i_jal   ? (pc + 32'd4):
  i_jalr  ? (pc + 32'd4):
  i_lui   ? (imm << 12):
  i_auipc ? (pc + (imm << 12)):
  i_lb    ? ({{24{rdata[7]}},rdata[7:0]}):
  i_lh    ? ({{16{rdata[15]}},rdata[15:0]}):
  i_lw    ? (rdata[31:0]):
  i_lbu   ? ({{24{1'b0}},rdata[7:0]}):
  i_lhu   ? ({{16{1'b0}},rdata[15:0]}):
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

//reg [5:0] x_i;
always@(negedge rstb or posedge clk) begin
  if(~rstb) begin
    addr <= 32'd0;
    wdata <= 32'd0;
    enable <= 1'b0;
    pc <= 32'd0;
    //for(x_i=0;x_i<=31;x_i=x_i+1) x[x_i] <= 32'd0;
  end
  else if(setb && instp) begin
    if(sel) begin
      addr <= xrs1 + imm;
      if(i_sb) wdata[7:0] <= xrs2[7:0];
      else if(i_sh) wdata[15:0] <= xrs2[15:0];
      else if(i_sw) wdata[31:0] <= xrs2[31:0];
      if(~enable) enable <= 1'b1;
      else if(enable && ready) begin
        enable <= 1'b0;
        if(fetch) pc <= npc;
        if((rd != 5'd0) && (~i_nop)) x[rd] <= xrd;
      end
    end
    else if(fetch) pc <= npc;
    if((rd != 5'd0) && (~i_nop)) x[rd] <= xrd;
  end
  else pc <= pc0;
end

endmodule


`ifdef SIM
module tb1;

reg prstb, pclk, setb;
wire psel, pwrite, penable;
wire [31:0] paddr;
wire [31:0] pwdata;
reg fclk;
reg halt;
wire irq;

`define RAM_A0 'h0
`define RAM_A1 'hfc
`define APB_LPTIMER_A0 (`RAM_A1+'h4)
`define APB_LPTIMER_A1 (`APB_LPTIMER_A0+'h4)
`define APB_LPUART_A0 (`APB_LPTIMER_A1+'h4)
`define APB_LPUART_A1 (`APB_LPUART_A0+'hc)

wire [31:0] paddr_timer = paddr - `APB_LPTIMER_A0;
wire psel_timer = psel && (`APB_LPTIMER_A1 >= paddr) && (paddr >= `APB_LPTIMER_A0);
wire [31:0] prdata_timer;
timer u_timer (
  .irq(irq), 
  .halt(halt), 
  .fclk(fclk), 
  .prdata(prdata_timer), 
  .pwdata(pwdata), 
  .paddr(paddr_timer[2:0]), 
  .psel(psel_timer), .pwrite(pwrite), .penable(penable), 
  .prstb(prstb), .pclk(pclk) 
);
always begin
  repeat($urandom_range(10,100)) @(posedge pclk);
  halt = ~halt;
end

wire [31:0] paddr_lpuart = paddr - `APB_LPUART_A0;
wire psel_lpuart = psel && (`APB_LPUART_A1 >= paddr) && (paddr >= `APB_LPUART_A0);
wire [31:0] prdata_lpuart;
apb_lpuart u_apb_lpuart (
  .debug(),
  .dma_ack(1'b0), 
  .dma_req(), 
  .irq(), 
  .tx(), .rts(), 
  .rx(1'b0), .cts(), 
  .frstb(prstb), .fclk(fclk), 
  .prdata(prdata_lpuart), 
  .pwdata(pwdata), 
  .paddr(paddr_lpuart[3:0]), 
  .pwrite(pwrite), .psel(psel_lpuart), .penable(penable), .prstb(prstb), .pclk(pclk) 
);

reg [31:0] pc0, pc1;
wire [31:0] pc;
wire [31:0] pcoffset = pc-pc0;
reg [7:0] rom[0:'hfff];
wire [31:0] inst = {rom[pc+3],rom[pc+2],rom[pc+1],rom[pc]};
wire idle;
reg [7:0] ram[0:'hff];
integer ram_i;
wire [31:0] paddr_ram = paddr - `RAM_A0;
wire [31:0] prdata_ram = {ram[paddr_ram+3],ram[paddr_ram+2],ram[paddr_ram+1],ram[paddr_ram]};
wire pwrite_ram = pwrite;
wire psel_ram = psel && (`RAM_A1 >= paddr_ram) && (paddr_ram >= `RAM_A0);
wire penable_ram = penable;
always@(negedge prstb or posedge pclk) begin
  if(~prstb) begin
    for(ram_i=0;ram_i<='hff;ram_i=ram_i+1) ram[ram_i] <= 8'd0;
  end
  else if(psel_ram && pwrite && penable) begin
    ram[paddr_ram] <= pwdata[7:0];
    ram[paddr_ram+1] <= pwdata[15:8];
    ram[paddr_ram+2] <= pwdata[23:16];
    ram[paddr_ram+3] <= pwdata[31:24];
   end
end
wire busreq;
wire grant = busreq;
wire [31:0] prdata =
  psel_lpuart ? prdata_lpuart : 
  psel_timer ? prdata_timer : 
  prdata_ram;
rv32i u_cpu (
  .rdata(prdata), 
  .wdata(pwdata), 
  .write(pwrite), .sel(psel), .enable(penable), .busreq(busreq), 
  .ready(1'b1), .grant(grant), 
  .addr(paddr), 
  .idle(idle), 
  .inst(inst), 
  .pc(pc), 
  .pc0(pc0), .pc1(pc1), 
  .setb(setb), .fetch(1'b1), 
  .rstb(prstb), .clk(pclk) 
);
integer fp;
task load_rom;
  begin
    $write("load_rom from 67.bin\n");
/*
riscv32-unknown-elf-gcc -march=rv32i -mabi=ilp32 -nostartfiles -mno-relax -O4 -c 67.c
riscv32-unknown-elf-ld -T 67.ld -o 67.elf 67.o
riscv32-unknown-elf-objcopy -O binary 67.elf 67.bin
riscv32-unknown-elf-objdump -D 67.elf 
 */
    fp = $fopen("67.bin","rb");
    pc0='h0;
    for(pc1=pc0;pc1<=('hfff-pc0);pc1=pc1+1) rom[pc1] = 8'd0;
    pc1 = pc0;
    while(!$feof(fp)) begin
      rom[pc1] = $fgetc(fp);
      pc1=pc1+1;
    end
    pc1 = pc1+3-32;
    $fclose(fp);
    $write("done pc1=%x\n",pc1);
  end
endtask

always #20.8 pclk = ~pclk;
always #250.0 fclk = ~fclk;

wire [31:0] x_ra  = u_cpu.x[1];
wire [31:0] x_sp  = u_cpu.x[2];
wire [31:0] x_gp  = u_cpu.x[3];
wire [31:0] x_tp  = u_cpu.x[4];
wire [31:0] x_t0  = u_cpu.x[5];
wire [31:0] x_t1  = u_cpu.x[6];
wire [31:0] x_t2  = u_cpu.x[7];
wire [31:0] x_s0  = u_cpu.x[8];
wire [31:0] x_s1  = u_cpu.x[9];
wire [31:0] x_a0  = u_cpu.x[10];
wire [31:0] x_a1  = u_cpu.x[11];
wire [31:0] x_a2  = u_cpu.x[12];
wire [31:0] x_a3  = u_cpu.x[13];
wire [31:0] x_a4  = u_cpu.x[14];
wire [31:0] x_a5  = u_cpu.x[15];
wire [31:0] x_a6  = u_cpu.x[16];
wire [31:0] x_a7  = u_cpu.x[17];
wire [31:0] x_s2  = u_cpu.x[18];
wire [31:0] x_s3  = u_cpu.x[19];
wire [31:0] x_s4  = u_cpu.x[20];
wire [31:0] x_s5  = u_cpu.x[21];
wire [31:0] x_s6  = u_cpu.x[22];
wire [31:0] x_s7  = u_cpu.x[23];
wire [31:0] x_s8  = u_cpu.x[24];
wire [31:0] x_s9  = u_cpu.x[25];
wire [31:0] x_s10 = u_cpu.x[26];
wire [31:0] x_s11 = u_cpu.x[27];
wire [31:0] x_t3  = u_cpu.x[28];
wire [31:0] x_t4  = u_cpu.x[29];
wire [31:0] x_t5  = u_cpu.x[30];
wire [31:0] x_t6  = u_cpu.x[31];

initial begin
  `ifdef FST
  $dumpfile("a.fst");
  $dumpvars(0,tb1);
  `endif
  `ifdef FSDB
  $fsdbDumpfile("a.fsdb");
  $fsdbDumpvars(0,tb1);
  `endif
  pclk = 0;
  fclk = 0;
  halt = 0;
  prstb = 0;
  setb = 0;
  repeat(2) begin
    load_rom;
    #100 @(posedge pclk); prstb = 1;
    repeat(3) @(posedge pclk); setb = 1;
    @(posedge idle);
    repeat(1) @(posedge pclk); setb = 0;
    #100 prstb = 0;
  end
  $finish;
end

endmodule
`endif
