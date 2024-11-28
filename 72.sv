`timescale 1ns/1ps


module clksw (
  output reg [1:0] vld, 
  output lck, 
  input sel, 
  input [1:0] rstb, clk 
);

reg [1:0] d;
always@(negedge rstb[0] or posedge clk[0]) begin
  if(~rstb[0]) begin
    d[0] <= 1'b1;
    vld[0] <= 1'b1;
  end
  else begin
    d[0] <= {vld[1],sel} == 2'b00;
    vld[0] <= d[0];
  end
end
always@(negedge rstb[1] or posedge clk[1]) begin
  if(~rstb[1]) begin
    d[1] <= 1'b0;
    vld[1] <= 1'b0;
  end
  else begin
    d[1] <= {vld[0],sel} == 2'b01;
    vld[1] <= d[1];
  end
end
assign lck = |(vld&clk);

endmodule


module hduart #(
  parameter HDUART_CHECK_SB  = 9, 
  parameter HDUART_FIFO_AMSB = 4, 
  parameter HDUART_FIFO_DMSB = 9 
)(
  output startena, stopena, match, 
  output full, empty, 
  output [HDUART_FIFO_AMSB:0] cnt, 
  output [HDUART_FIFO_DMSB:0] rchar, 
  input [HDUART_FIFO_DMSB:0] wchar, mchar, 
  input pop, push, clear,
  output tx, 
  input rx, 
  input rxe, txe, 
  input parity, even, 
  input smsb,         // stop msb
  input [3:0] cmsb,   // char msb
  output reg [3:0] bs, 
  output reg uclk, 
  input [3:0] delay, 
  input [15:0] divisor, dividend, 
  input setb, 
  input rstb, clk, frstb, fclk 
);

wire checkena = HDUART_FIFO_DMSB >= HDUART_CHECK_SB;
reg uclkena;
reg [15:0] fcnt;
always@(negedge frstb or posedge fclk) begin  
  if(~frstb) begin
    fcnt <= 'd0;
    uclk <= 1'b0;
  end
  else if(setb && uclkena) begin
    if(fcnt >= dividend) begin
      fcnt <= fcnt - dividend + divisor;
      uclk <= 1'b0;
    end
    else begin
      fcnt <= fcnt + divisor;
      if(fcnt >= (dividend >> 1)) uclk <= 1'b1;
    end
  end
  else begin
    fcnt <= (dividend >> delay);
    uclk <= 1'b0;
  end
end
reg [1:0] uclk_d, push_d, pop_d, clear_d;
wire uclk_p = uclk_d[1:0] == 2'b01;
wire uclk_n = uclk_d[1:0] == 2'b10;
wire push_p = push_d[1:0] == 2'b01;
wire pop_p = pop_d[1:0] == 2'b01;
wire clear_p = clear_d[1:0] == 2'b01;
always@(negedge rstb or posedge clk) begin
  if(~rstb) begin
    uclk_d <= 2'b11;
    push_d <= 2'b00;
    pop_d <= 2'b00;
    clear_d <= 2'b00;
  end
  else begin
    uclk_d <= {uclk_d[0],uclk};
    push_d <= {push_d[0],push};
    pop_d <= {pop_d[0],pop};
    clear_d <= {clear_d[0],clear};
  end
end
wire [3:0]   idlebit = bs - 4'd0;
wire [3:0]  startbit = bs - 4'd1;
wire [3:0]   charbit = bs - 4'd2;
wire [3:0] paritybit = bs - (4'd3 + cmsb);
wire [3:0]   stopbit = bs - (4'd3 + cmsb + (parity ? 4'd1 : 4'd0));
wire [3:0]    endbit = bs - (4'd3 + cmsb + (parity ? 4'd1 : 4'd0));
wire     idleena = ( 4'd0       ==   idlebit);
assign  startena = ( 4'd0       ==  startbit);
wire     charena = ( cmsb       >=   charbit) && (charbit >= 4'd0);
wire   parityena = ( 4'd0       == paritybit);
assign   stopena = ({3'd0,smsb} >=   stopbit) && (stopbit >= 4'd0);
wire      endena = ({3'd0,smsb} ==    endbit);
reg [HDUART_FIFO_DMSB:0] mem[0:((2**HDUART_FIFO_AMSB)-1)];
reg [HDUART_FIFO_AMSB:0] ma1, ma0;
assign cnt = ma1 - ma0;
assign full  = cnt == (2**HDUART_FIFO_AMSB);
assign empty = cnt == 'd0;
wire [HDUART_FIFO_DMSB:0] wbc = mem[ma1[(HDUART_FIFO_AMSB-1):0]];
wire [HDUART_FIFO_DMSB:0] rbc = mem[ma0[(HDUART_FIFO_AMSB-1):0]];
reg bx;
assign tx = 
    startena               ? 1'b0 : 
     charena               ? mem[ma0[(HDUART_FIFO_AMSB-1):0]][charbit] : 
  (parityena & (~stopena)) ? bx : 
     stopena               ? 1'b1 : 
  1'b1;
always@(negedge rstb or posedge clk) begin
  if(~rstb) begin
    bs <= 4'd0;
    uclkena <= 1'b0;
    bx <= 1'b0;
  end
  else if(setb && (txe || rxe)) begin
    if(idleena) begin
      if(({txe,empty} == 2'b10) || ({rxe,full,rx} == 3'b100)) begin
        bs <= 4'd1;
        uclkena <= 1'b1;
        if(checkena) bx <= even;
      end
    end
    else if(uclk_n) begin
      if(endena) begin
        bs <= 4'd0;
        uclkena <= 1'b0;
      end
      else bs <= bs + 4'd1;
      bs <= endena ? 4'd0 : bs + 4'd1;
    end
    else if(uclk_p && checkena && charena) bx <= bx ^ (txe ? tx : rx);
  end
  else begin
    bs <= 4'd0;
    uclkena <= 1'b0;
  end
end
always@(negedge rstb or posedge clk) begin
  if(~rstb) ma0 <= {(HDUART_FIFO_AMSB+1){1'b0}};
  else if(clear_p) ma0 <= {(HDUART_FIFO_AMSB+1){1'b0}};
  else if({pop_p,empty} == 2'b10) ma0 <= ma0 + 'd1;
  else if({txe,endena,uclk_p,empty} == 4'b1110) ma0 <= ma0 + 'd1;
end
always@(negedge rstb or posedge clk) begin
  if(~rstb) ma1 <= {(HDUART_FIFO_AMSB+1){1'b0}};
  else if(clear_p) ma1 <= {(HDUART_FIFO_AMSB+1){1'b0}};
  else if({push_p,full} == 2'b10) ma1 <= ma1 + 'd1;
  else if({rxe,endena,uclk_p,full} == 4'b1110) ma1 <= ma1 + 'd1;
end
wire [2:0] err = checkena & {
  (startena && rx),
  (stopena && (~rx)),
  (parityena && (~stopena) && (bx != rx))
  };
always@(posedge clk) begin
  if({push_p,full} == 2'b10) mem[ma1[(HDUART_FIFO_AMSB-1):0]] <= wchar;
  else if(rxe && uclk_p) begin
    if(charena) mem[ma1[(HDUART_FIFO_AMSB-1):0]][charbit] <= rx;
    else if(|err) mem[ma1[(HDUART_FIFO_AMSB-1):0]][HDUART_CHECK_SB] <= 1'b1;
  end
end
assign rchar = mem[ma0[(HDUART_FIFO_AMSB-1):0]];
assign match = endena && (mchar == mem[ma1[(HDUART_FIFO_AMSB-1):0]]);

endmodule


module apb_hduart (
  output [4:0] debug, 
  output irq, 
  output dma_req, 
  input dma_ack, 
  output tx, 
  input rx, 
  output reg rxe, txe, 
  input fclk, 
  output reg [31:0] prdata, 
  input [31:0] pwdata, 
  input [3:0] paddr, 
  input prstb, pclk, psel, pwrite, penable
);

wire ctrl_ena = (paddr == 'h0) && psel;
wire baud_ena = (paddr == 'h4) && psel;
wire data_ena = (paddr == 'h8) && psel;
wire fifo_ena = (paddr == 'hc) && psel;
reg [1:0] prstb_d;
wire frstb = prstb_d[1];
always@(negedge prstb or posedge fclk) begin
  if(~prstb) prstb_d <= 2'b00;
  else prstb_d <= {prstb_d[0],1'b1};
end
wire start, stop, match;
wire full, empty;
reg [4:0] th;
wire [4:0] cnt;
reg trig;
reg enadma;
wire nxt_trig = txe ? (th >= cnt) : rxe ? (cnt >= th) : 1'b0;
assign dma_req = enadma && nxt_trig;
reg [1:0] trig_d, stop_d;
wire trig_p = trig_d == 2'b01;
wire stop_n = stop_d == 2'b10;
always@(negedge prstb or posedge pclk) begin
  if(~prstb) begin
    trig_d <= 2'b00;
    stop_d <= 2'b00;
  end
  else begin
    trig_d <= {trig_d[0],nxt_trig};
    stop_d <= {stop_d[0],stop};
  end
end
wire [9:0] rchar;
reg [9:0] wchar, mchar;
wire pop  = rxe && (enadma ? dma_ack : (data_ena && penable && (~pwrite)));
wire push = txe && (enadma ? dma_ack : (data_ena && penable &&   pwrite ));
reg clear;
reg parity, even;
reg smsb;
reg [3:0] cmsb;
wire [3:0] bs;
wire uclk;
reg [3:0] delay;
reg [15:0] divisor, dividend;
reg setb;
reg irqena_trig;
reg irqena_full, irqena_empty;
reg irqena_start, irqena_stop, irqena_match;
assign irq =
  (irqena_match && match)||
  (irqena_stop && stop)||
  (irqena_start && start)||
  (irqena_empty && empty)||
  (irqena_full && full)||
  (irqena_trig && trig);
wire fclk_vld, pclk_vld;
wire clk;
reg clk_sel;
clksw u_clk(
  .vld({fclk_vld,pclk_vld}), 
  .lck(clk), 
  .sel(clk_sel), 
  .rstb({frstb,prstb}), .clk({fclk,pclk}) 
);
reg loopback, loopcheck1, loopend;
reg [3:0] loopcnt;
always@(negedge prstb or posedge pclk) begin
  if(~prstb) begin
    loopcheck1 <= 1'b1;
    loopcnt <= 4'd0;
    loopend <= 1'b0;
  end
  else if(setb && loopback) begin
    if(stop_n) begin
      if(loopcnt == 4'hf) loopend <= 1'b1;
      else begin
        loopcnt <= loopcnt + 4'd1;
        loopcheck1 <= loopcheck1 && (loopcnt[0] ? rchar[8:0] : ~rchar[8:0]) == wchar[8:0];
      end
    end
  end
  else begin
    loopcheck1 <= 1'b1;
    loopcnt <= 4'd0;
    loopend <= 1'b0;
  end
end
wire loopcheck = (loopcnt == 4'hf) && loopcheck1;

hduart #(
  .HDUART_CHECK_SB(9), 
  .HDUART_FIFO_AMSB(4), 
  .HDUART_FIFO_DMSB(9) 
) u_hduart(
  .startena(start), .stopena(stop), .match(match), 
  .full(full), .empty(empty), 
  .cnt(cnt), 
  .rchar(rchar), 
  .wchar(wchar), .mchar(mchar), 
  .pop(pop), .push(push), .clear(clear),
  .tx(tx), 
  .rx(loopback ? (~tx) : rx), 
  .rxe(rxe), .txe(txe), 
  .parity(parity), .even(even), 
  .smsb(smsb),
  .cmsb(cmsb),
  .bs(bs), 
  .uclk(uclk), 
  .delay(delay), 
  .divisor(divisor), .dividend(dividend), 
  .setb(setb), 
  .rstb(prstb), .clk(clk), .frstb(prstb_d[1]), .fclk(fclk) 
);

always@(*) begin
  prdata = 32'd0;
  if(ctrl_ena) begin
    prdata[0]     = setb        ;
    prdata[1]     = txe         ;
    prdata[2]     = rxe         ;
    prdata[3]     = clk_sel     ;
    prdata[4]     = pclk_vld    ;
    prdata[5]     = fclk_vld    ;
    prdata[9:6]   = cmsb[3:0]   ;
    prdata[10]    = smsb        ;
    prdata[11]    = parity      ;
    prdata[12]    = even        ;
    prdata[13]    = irqena_trig ;
    prdata[14]    = irqena_full ;
    prdata[15]    = irqena_empty;
    prdata[16]    = irqena_start;
    prdata[17]    = irqena_stop ;
    prdata[19]    = irqena_match;
    prdata[22:19] = delay[3:0]  ;
    prdata[23]    = loopback    ;
    prdata[24]    = loopcheck   ;
    prdata[25]    = loopend     ;
    // prdata[31:26] = unused0[5:0];
  end
  if(baud_ena) begin
    prdata[15:0]  = dividend[15:0];
    prdata[31:16] = divisor[15:0] ;
  end
  if(data_ena) begin
    // replace rchar[9:0] bchar[9:0] 
    prdata[9:0]   = rchar[9:0];
    prdata[19:10] = mchar[9:0];
    // prdata[31:20] = unused1[11:0];
  end
  if(fifo_ena) begin
    prdata[3:0] = cnt[3:0];
    prdata[7:4] = th[3:0] ;
    prdata[8]   = clear   ;
    prdata[9]   = trig    ;
    prdata[10]  = empty   ;
    prdata[11]  = full    ;
    prdata[12]  = start   ;
    prdata[13]  = stop    ;
    prdata[14]  = match   ;
    prdata[15]  = enadma  ;
    // prdata[31:16] = unused2[15:0];
  end
end
always@(negedge prstb or posedge pclk) begin
  if(~prstb) begin //default 
    setb         <= 'h0;
    txe          <= 'h0;
    rxe          <= 'h0;
    clk_sel      <= 'h0;
    cmsb[3:0]    <= 'h8;
    smsb         <= 'h0;
    parity       <= 'h0;
    even         <= 'h0;
    irqena_trig  <= 'h0;
    irqena_full  <= 'h0;
    irqena_empty <= 'h0;
    irqena_start <= 'h0;
    irqena_stop  <= 'h0;
    irqena_match <= 'h0;
    delay[3:0]   <= 'h0;
    dividend[15:0] <= 'h7ffe;
    divisor[15:0]  <= 'h0754;
    wchar[9:0] <= 'h0;
    mchar[9:0] <= 'h0;
    th[3:0]  <= 'h0;
    clear    <= 'h0;
    trig     <= 'h0;
    enadma   <= 'h0;
    loopback   <= 'h0;
  end
  else begin
    if(ctrl_ena && pwrite) begin
      setb         <= pwdata[0]    ;
      txe          <= pwdata[1]    ;
      rxe          <= pwdata[2]    ;
      clk_sel      <= pwdata[3]    ;
      cmsb[3:0]    <= pwdata[9:6]  ;
      smsb         <= pwdata[10]   ;
      parity       <= pwdata[11]   ;
      even         <= pwdata[12]   ;
      irqena_trig  <= pwdata[13]   ;
      irqena_full  <= pwdata[14]   ;
      irqena_empty <= pwdata[15]   ;
      irqena_start <= pwdata[16]   ;
      irqena_stop  <= pwdata[17]   ;
      irqena_match <= pwdata[19]   ;
      delay[3:0]   <= pwdata[22:19];
      loopback     <= pwdata[23]   ;
    end
    if(baud_ena && pwrite) begin
      dividend[15:0] <= pwdata[15:0] ;
      divisor[15:0]  <= pwdata[31:16];
    end
    if(data_ena && pwrite) begin
      wchar[9:0] <= pwdata[9:0]  ;
      mchar[9:0] <= pwdata[19:10];
    end
    if(fifo_ena && pwrite) begin
      th[3:0]  <= pwdata[7:4];
      clear    <= pwdata[8]  ;
      trig     <= pwdata[9] ? 1'b0 : trig;
      enadma   <= pwdata[15] ;
    end
    if(trig_p) trig <= 1'b1;
  end
end
assign debug[3:0] = bs[3:0];
assign debug[4] = uclk;

endmodule


module mcyc2 (output done, clk2, input setb, rstb, clk);
reg [1:0] d;
always@(negedge rstb or posedge clk) begin
  if(~rstb) d <= 2'b00;
  else d <= {d[0],setb};
end
assign done = {d[1:0],setb}==3'b111;
assign clk2 = d[1:0]==2'b11;
endmodule


module muldivuu (
  output reg error, 
  output done, 
  input setb, mul, 
  output reg [63:0] r, 
  output reg [31:0] q, 
  input [31:0] a, b, 
  input rstb, clk 
);

wire clk2;
mcyc2 u_clk2(.done(done), .clk2(clk2), .setb(setb), .rstb(rstb), .clk(clk));
always@(negedge rstb or posedge clk2) begin
  if(~rstb) begin
    r <= 64'd0;
    q <= 32'd0;
    error <= 1'b0;
  end
  else begin
    if(mul) begin
      r <= a * b;
      error <= 1'b0;
    end
    else begin
      if(b == 32'd0) error <= 1'b1;
      else begin
        r <= a % b;
        q <= a / b;
        error <= 1'b0;
      end
    end
  end
end

endmodule


module rv32im (
  input [31:0] rdata, 
  output reg [31:0] wdata, 
  output reg enable, 
  output write, sel, busreq, 
  input ready, grant, 
  output [31:0] addr, 
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
wire m_mul    = fmtr   && (funct3==3'h0) && (funct7==7'h01);
wire m_mulh   = fmtr   && (funct3==3'h1) && (funct7==7'h01);
wire m_mulhsu = fmtr   && (funct3==3'h2) && (funct7==7'h01);
wire m_mulhu  = fmtr   && (funct3==3'h3) && (funct7==7'h01);
wire m_div    = fmtr   && (funct3==3'h4) && (funct7==7'h01);
wire m_divu   = fmtr   && (funct3==3'h5) && (funct7==7'h01);
wire m_rem    = fmtr   && (funct3==3'h6) && (funct7==7'h01);
wire m_remu   = fmtr   && (funct3==3'h7) && (funct7==7'h01);
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
wire mul_ena = |{m_mul,m_mulh,m_mulhsu,m_mulhu};
wire div_ena = |{m_div,m_divu,m_rem,m_remu};
wire muldivuu_done;
wire muldivuu_setb = |{mul_ena,div_ena};
wire [63:0] mulremuu;
wire [31:0] divuu;
muldivuu u_muldivuu (
  .done(muldivuu_done), .error(), 
  .setb(muldivuu_setb), .mul(mul_ena), 
  .r(mulremuu), .q(divuu), .a(xrs1u), .b(xrs2u), 
  .rstb(rstb), .clk(clk) 
);
wire [63:0] muluu = mulremuu;
wire [31:0] remuu = mulremuu[31:0];
wire [63:0] mulsu = xrs1s ? (~muluu + 64'd1) : muluu;
wire [63:0] mulss = (xrs1s^xrs2s) ? (~muluu + 64'd1) : muluu;
wire [32:0] divss = (xrs1s^xrs2s) ? (~divuu + 64'd1) : divuu;
wire [32:0] remss = (xrs1s^xrs2s) ? (~remuu + 64'd1) : remuu;
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
  m_mul    ? mulss[31:0]:
  m_mulh   ? mulss[63:32]:
  m_mulhsu ? mulsu[63:32]:
  m_mulhu  ? muluu[63:32]:
  m_div    ? divss:
  m_divu   ? divuu:
  m_rem    ? remss:
  m_remu   ? remuu:
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
wire unlock = {muldivuu_setb,muldivuu_done} != 2'b10;
wire load = {sel,write,enable} == 3'b100;
wire loaded = {sel,write,enable,ready} == 4'b1011;
wire store = {sel,write,enable} == 3'b110;
wire stored = {sel,write,enable,ready} == 4'b1111;
reg [5:0] x_i;
assign addr = xrs1 + imm;
always@(negedge rstb or posedge clk) begin
  if(~rstb) begin
    wdata <= 32'd0;
    enable <= 1'b0;
    pc <= 32'd0;
    for(x_i=0;x_i<=31;x_i=x_i+1) x[x_i] <= 32'd0;
  end
  else if(setb && instp) begin
    if(load) begin
      enable <= 1'b1;
    end
    else if(loaded && unlock) begin
      enable <= 1'b0;
      if((rd != 5'd0) && (~i_nop)) x[rd] <= xrd;
      if(fetch) pc <= npc;
    end
    else if(store) begin
      enable <= 1'b1;
      if(i_sb) wdata[31:0] <= {rdata[31:8],xrs2[7:0]};
      else if(i_sh) wdata[31:0] <= {rdata[31:16],xrs2[15:0]};
      else if(i_sw) wdata[31:0] <= xrs2[31:0];
    end
    else if(stored && unlock) begin
      enable <= 1'b0;
      if(fetch) pc <= npc;
    end
    else if(unlock) begin
      if((rd != 5'd0) && (~i_nop)) x[rd] <= xrd;
      if(fetch) pc <= npc;
    end
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
`define RAM_A1 (`RAM_A0+'hff)
`define APB_A0 'h1000
`define APB_HDUART0_A0 (`APB_A0+'h0000)
`define APB_HDUART0_A1 (`APB_A0+'h000f)
`define APB_HDUART1_A0 (`APB_A0+'h0100)
`define APB_HDUART1_A1 (`APB_A0+'h010f)
`define APB_HDUART2_A0 (`APB_A0+'h0200)
`define APB_HDUART2_A1 (`APB_A0+'h020f)

wire [2:0] tx;

wire [31:0] paddr_hduart0 = paddr - `APB_HDUART0_A0;
wire psel_hduart0 = psel && (`APB_HDUART0_A1 >= paddr) && (paddr >= `APB_HDUART0_A0);
wire [31:0] prdata_hduart0;
apb_hduart u_apb_hduart0 (
  .debug(), 
  .irq(), 
  .dma_req(), 
  .dma_ack(), 
  .tx(tx[0]), 
  .rx(tx[1]), 
  .rxe(), .txe(), 
  .fclk(fclk), 
  .prdata(prdata_hduart0), 
  .pwdata(pwdata), 
  .paddr(paddr_hduart0[3:0]), 
  .prstb(prstb), .pclk(pclk), .psel(psel_hduart0), .pwrite(pwrite), .penable(penable)
);

wire [31:0] paddr_hduart1 = paddr - `APB_HDUART1_A0;
wire psel_hduart1 = psel && (`APB_HDUART1_A1 >= paddr) && (paddr >= `APB_HDUART1_A0);
wire [31:0] prdata_hduart1;
apb_hduart u_apb_hduart1 (
  .debug(), 
  .irq(), 
  .dma_req(), 
  .dma_ack(), 
  .tx(tx[1]), 
  .rx(tx[2]), 
  .rxe(), .txe(), 
  .fclk(fclk), 
  .prdata(prdata_hduart1), 
  .pwdata(pwdata), 
  .paddr(paddr_hduart1[3:0]), 
  .prstb(prstb), .pclk(pclk), .psel(psel_hduart1), .pwrite(pwrite), .penable(penable)
);

wire [31:0] paddr_hduart2 = paddr - `APB_HDUART2_A0;
wire psel_hduart2 = psel && (`APB_HDUART2_A1 >= paddr) && (paddr >= `APB_HDUART2_A0);
wire [31:0] prdata_hduart2;
apb_hduart u_apb_hduart2 (
  .debug(), 
  .irq(), 
  .dma_req(), 
  .dma_ack(), 
  .tx(tx[2]), 
  .rx(tx[0]), 
  .rxe(), .txe(), 
  .fclk(fclk), 
  .prdata(prdata_hduart2), 
  .pwdata(pwdata), 
  .paddr(paddr_hduart2[3:0]), 
  .prstb(prstb), .pclk(pclk), .psel(psel_hduart2), .pwrite(pwrite), .penable(penable)
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
  psel_hduart0 ? prdata_hduart0 : 
  psel_hduart1 ? prdata_hduart1 : 
  psel_hduart2 ? prdata_hduart2 : 
  prdata_ram;
reg pready;
always@(negedge prstb or posedge pclk) if(~prstb) pready <= 1'b0; else pready <= penable;
rv32im u_cpu (
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
    $write("load_rom from 72.bin\n");
/*
riscv32-unknown-elf-gcc -march=rv32im -mabi=ilp32 -nostartfiles -mno-relax -O0 -c 72.c -g -o 72.o
riscv32-unknown-elf-ld -T 72.ld -o 72.elf 72.o
riscv32-unknown-elf-objcopy -O binary 72.elf 72.bin
riscv32-unknown-elf-objdump -S 72.o
 */
    fp = $fopen("72.bin","rb");
    pc0='h0;
    for(pc1=pc0;pc1<=('hfff-pc0);pc1=pc1+1) rom[pc1] = 8'd0;
    pc1 = pc0;
    while(!$feof(fp)) begin
      rom[pc1] = $fgetc(fp);
      pc1=pc1+1;
    end
    pc1 = pc1-13;
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
