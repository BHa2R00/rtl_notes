`timescale 1ns/1ps


`define LPUART_FIFO_AMSB 3 
module lpuart (
  output tx, rts, 
  input rx, cts, 
  output reg uclk, 
  output reg intr,
  output full, empty,
  input pop, push,
  input [`LPUART_FIFO_AMSB:0] lht, hlt,
  output [`LPUART_FIFO_AMSB:0] cnt,
  output [9:0] rchar,
  input [9:0] wchar,
  input [15:0] divisor, dividend,
  input fc,
  input [4:0] mode,
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
reg [15:0] fcnt;
reg [1:0] uclk_d;
wire uclk_p = uclk_d == 2'b01;
wire uclk_n = uclk_d == 2'b10;
reg [9:0] b[0:((2**`LPUART_FIFO_AMSB)-1)];
reg [`LPUART_FIFO_AMSB:0] ba1, ba0;
assign cnt = ba1 - ba0;
assign full  = cnt == (2**`LPUART_FIFO_AMSB);
assign empty = cnt == 'h0;
reg [3:0] a, na;
wire [9:0] wbc = ena_tx ? b[ba0[(`LPUART_FIFO_AMSB-1):0]] : 10'h3ff;
wire [9:0] rbc = ena_tx ? 10'h3ff : b[ba1[(`LPUART_FIFO_AMSB-1):0]];
wire xortx = 
  ena_8bit ? ^(wbc[6:0]) : 
  ena_7bit ? ^(wbc[5:0]) : 
  ena_6bit ? ^(wbc[4:0]) : 
  ^wbc;
wire xorrx = 
  ena_8bit ? ^(rbc[6:0]) : 
  ena_7bit ? ^(rbc[5:0]) : 
  ena_6bit ? ^(rbc[4:0]) : 
  ^rbc;
assign tx = ena_tx ? (
  (a >= 4'hc) ? 1'b0 : 
  (a >= 4'hb) ? 1'b1 : 
  (ena_parity && (a == 4'ha)) ? (even ? ~xortx : xortx) : 
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
    fcnt <= dividend >> (ena_tx ? 1 : 2);
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
  else if(setb && uclk_n) a <= na;
end
always@(*) begin
  na = a;
  case(a)
    4'hb: if(fc? cts:(ena_tx? (~empty):(~rx))) na = 4'hc;
    4'hc: na = 4'h0;
    4'h6: na = ena_6bit? (ena_parity? 4'ha:4'hb): a + 4'h1;
    4'h7: na = ena_7bit? (ena_parity? 4'ha:4'hb): a + 4'h1;
    4'h8: na = ena_8bit? (ena_parity? 4'ha:4'hb): a + 4'h1;
    4'h9: na = ena_parity? 4'ha:4'hb;
    default: na = a + 4'h1;
  endcase
end

always@(posedge clk) begin
  if(setb) begin
    if(push_p & ena_tx) b[ba1[(`LPUART_FIFO_AMSB-1):0]] <= wchar[9:0];
    else if((~ena_tx) && uclk_n && (4'h9 >= na)) b[ba1[(`LPUART_FIFO_AMSB-1):0]][na] <= rx;
    else if((~ena_tx) && uclk_n && (4'ha == na)) err <= ena_parity? ((even? ~xorrx:xorrx)!=rx):1'b0;
    else if((~ena_tx) && uclk_n && (4'hb == na)) b[ba1[(`LPUART_FIFO_AMSB-1):0]][na] <= err;
  end
end

always@(negedge rstb or posedge clk) begin
  if(~rstb) {ba1,ba0} <= {((`LPUART_FIFO_AMSB+1)*2){1'b0}};
  else if(clear_p) {ba1,ba0} <= {((`LPUART_FIFO_AMSB+1)*2){1'b0}};
  else begin
    if(ena_tx && push_p) ba1 <= ba1 + 'd1;
    if(ena_tx && (na==4'hb) && uclk_n && (~empty)) ba0 <= ba0 + 'd1;
    if((~ena_tx) && (a!=4'hb) && (na==4'hb) && uclk_n && (~full)) ba1 <= ba1 + 'd1;
    if((~ena_tx) && pop_p) ba0 <= ba0 + 'd1;
  end
end

always@(negedge rstb or posedge clk) begin
  if(~rstb) intr <= 1'b0;
  else if(clear_p) intr <= 1'b0;
  else if(
    (intr && (~ena_tx) && push_p && (cnt == hlt))||
    ((~intr) && (~ena_tx) && (na==4'hb) && uclk_n && (cnt == lht))||
    (intr && (na==4'hb) && ena_tx && uclk_n && (cnt == hlt))||
    ((~intr) && ena_tx && pop_p && (cnt == lht))
    ) intr <= ~intr;
end

endmodule


module apb_lpuart (
  input dma_ack, 
  output reg dma_req, 
  output tx, rts, 
  input rx, cts, 
  output uclk, 
  output intr, 
  input frstb, fclk, 
  output reg [31:0] prdata, 
  input [31:0] pwdata, 
  input [3:0] paddr, 
  input pwrite, psel, penable, prstb, pclk 
);

wire u_lpuart_intr;
reg intr_ena;
assign intr = intr_ena? u_lpuart_intr:1'b0;
reg [1:0] dma_ack_d;
wire dma_ack_p = dma_ack_d == 2'b01;
reg dma_ena;
wire full, empty;
reg pop, push;
reg [3:0] lht, hlt;
wire [3:0] cnt;
wire [9:0] rchar;
reg [9:0] wchar;
reg [15:0] divisor, dividend;
reg fc;
reg [4:0] mode;
reg clear, setb;

lpuart u_lpuart (
  .tx(tx), .rts(rts), 
  .rx(rx), .cts(cts), 
  .uclk(uclk), 
  .intr(u_lpuart_intr), 
  .full(full), .empty(empty), 
  .pop(dma_ena? dma_ack:pop), .push(dma_ena? dma_ack:push), 
  .lht(lht), .hlt(hlt), 
  .cnt(cnt), 
  .rchar(rchar), 
  .wchar(wchar), 
  .divisor(divisor), .dividend(dividend), 
  .fc(fc), 
  .mode(mode), 
  .clear(clear), .setb(setb), 
  .frstb(frstb), .fclk(fclk), 
  .rstb(prstb), .clk(pclk) 
);

always@(negedge prstb or posedge pclk) begin
  if(~prstb) begin
    dma_ack_d <= 2'b11;
    dma_req <= 1'b0;
  end
  else begin
    dma_ack_d <= {dma_ack_d[0],dma_ack};
    if(dma_ack_p) dma_req <= 1'b0;
    else if(intr) dma_req <= 1'b1;
  end
end

wire ctrl_ena = (paddr == 'h0) && penable && psel;
wire baud_ena = (paddr == 'h4) && penable && psel;
wire data_ena = (paddr == 'h8) && penable && psel;
wire fifo_ena = (paddr == 'hc) && penable && psel;

always@(*) begin
  prdata = 32'd0;
  if(ctrl_ena) begin
    prdata[0] = setb;
    prdata[1] = clear;
    prdata[6:2] = mode;
    prdata[7] = fc;
    prdata[8] = dma_ena;
    prdata[9] = intr_ena;
  end
  else if(baud_ena) begin
    prdata[15:0] = dividend;
    prdata[31:16] = divisor;
  end
  else if(data_ena) begin
    prdata[9:0] = rchar;
  end
  else if(fifo_ena) begin
    prdata[3:0] = cnt;
    prdata[7:4] = hlt;
    prdata[11:8] = lht;
    prdata[12] = push;
    prdata[13] = pop;
    prdata[14] = empty;
    prdata[15] = full;
    prdata[16] = intr;
  end
end

always@(negedge prstb or posedge pclk) begin
  if(~prstb) begin
    setb <= 'h1;
    clear <= 'h0;
    mode <= 'h0;
    fc <= 'h0;
    dma_ena <= 'h0;
    intr_ena <= 'h0;
    dividend <= 'h7ffe;
    divisor <= 'h0755;
    wchar <= 'h0;
    hlt <= 'h0;
    lht <= 'h0;
    push <= 'h0;
    pop <= 'h0;
  end
  else if(ctrl_ena && pwrite) begin
    setb <= pwdata[0];
    clear <= pwdata[1];
    mode <= pwdata[6:2];
    fc <= pwdata[7];
    dma_ena <= pwdata[8];
    intr_ena <= pwdata[9];
  end
  else if(baud_ena && pwrite) begin
    dividend <= pwdata[15:0];
    divisor <= pwdata[31:16];
  end
  else if(data_ena && pwrite) begin
    wchar <= pwdata[9:0];
  end
  else if(fifo_ena && pwrite) begin
    hlt <= pwdata[7:4];
    lht <= pwdata[11:8];
    push <= push? 'h0:pwdata[12];
    pop <= pop? 'h0:pwdata[13];
  end
end

endmodule


`ifdef SIM
module apb_lpuart_tb1;

reg [31:0] CLK;
always #15258.789 CLK[ 0] = ~CLK[ 0]; // 32768
always #976.56256 CLK[ 1] = ~CLK[ 1]; // 512K
always #250.0     CLK[ 2] = ~CLK[ 2]; // 2M
always #125.0     CLK[ 3] = ~CLK[ 3]; // 4M
always #62.50     CLK[ 4] = ~CLK[ 4]; // 8M
always #31.25     CLK[ 5] = ~CLK[ 5]; // 16M
always #15.626    CLK[ 6] = ~CLK[ 6]; // 24M
always #250.0     CLK[ 7] = ~CLK[ 7]; // 2M
always #248.8     CLK[ 8] = ~CLK[ 8]; // 2.01M
always #247.5     CLK[ 9] = ~CLK[ 9]; // 2.02M
always #246.3     CLK[10] = ~CLK[10]; // 2.03M
always #245.1     CLK[11] = ~CLK[11]; // 2.04M
always #243.9     CLK[12] = ~CLK[12]; // 2.05M
always #242.7     CLK[13] = ~CLK[13]; // 2.06M
always #241.5     CLK[14] = ~CLK[14]; // 2.07M
always #240.4     CLK[15] = ~CLK[15]; // 2.08M
always #239.2     CLK[16] = ~CLK[16]; // 2.09M
always #238.1     CLK[17] = ~CLK[17]; // 2.1M
always #251.3     CLK[18] = ~CLK[18]; // 1.99M
always #252.5     CLK[19] = ~CLK[19]; // 1.98M
always #253.8     CLK[20] = ~CLK[20]; // 1.97M
always #255.1     CLK[21] = ~CLK[21]; // 1.96M
always #256.4     CLK[22] = ~CLK[22]; // 1.95M
always #257.7     CLK[23] = ~CLK[23]; // 1.94M
always #259.1     CLK[24] = ~CLK[24]; // 1.93M
always #260.4     CLK[25] = ~CLK[25]; // 1.92M
always #261.8     CLK[26] = ~CLK[26]; // 1.91M
initial CLK = 7'd0;
reg [7:0] sel_clk, sel_fclk1, sel_fclk2;
wire clk=CLK[sel_clk];
wire fclk1=CLK[sel_fclk1];
wire fclk2=CLK[sel_fclk2];
integer CLKM[0:31];
initial begin
  CLKM[ 0] =    32768;
  CLKM[ 1] =   512000;
  CLKM[ 2] =  2000000;
  CLKM[ 3] =  4000000;
  CLKM[ 4] =  8000000;
  CLKM[ 5] = 16000000;
  CLKM[ 6] = 24000000;
  CLKM[ 7] =  2000000;
  CLKM[ 8] =  2010000;
  CLKM[ 9] =  2020000;
  CLKM[10] =  2030000;
  CLKM[11] =  2040000;
  CLKM[12] =  2050000;
  CLKM[13] =  2060000;
  CLKM[14] =  2070000;
  CLKM[15] =  2080000;
  CLKM[16] =  2090000;
  CLKM[17] =  2100000;
  CLKM[18] =  1990000;
  CLKM[19] =  1980000;
  CLKM[20] =  1970000;
  CLKM[21] =  1960000;
  CLKM[22] =  1950000;
  CLKM[23] =  1940000;
  CLKM[24] =  1930000;
  CLKM[25] =  1920000;
  CLKM[26] =  1910000;
end
integer freq_clk, freq_fclk1, freq_fclk2;
task random_sel_clk;
  begin
  sel_clk   = $urandom_range(7,7);
  sel_fclk1 = $urandom_range(7,7);
  sel_fclk2 = $urandom_range(8,26);
  while(sel_fclk2 == sel_fclk1) sel_fclk2 = $urandom_range(8,26);
  freq_clk = CLKM[sel_clk];
  freq_fclk1 = CLKM[sel_fclk1];
  freq_fclk2 = CLKM[sel_fclk2];
  $write("sel clk %dHz\n",freq_clk);
  $write("sel fclk1 %dHz\n",freq_fclk1);
  $write("sel fclk2 %dHz\n",freq_fclk2);
  end
endtask

integer baudm[0:31];
integer baud;
integer bauda;
initial begin
  baudm[ 0] = 921600;
  baudm[ 1] = 576000;
  baudm[ 2] = 460800;
  baudm[ 3] = 230400;
  baudm[ 4] = 115200;
  baudm[ 5] =  76800;
  baudm[ 6] =  57600;
  baudm[ 7] =  38400;
  baudm[ 8] =  28800;
  baudm[ 9] =  19200;
  baudm[10] =   9600;
  baudm[11] =   4800;
  baudm[12] =   2400;
  baudm[13] =   1200;
  baudm[14] =    600;
  baudm[15] =    300;
  baudm[16] =    200;
  baudm[17] =    150;
  baudm[18] =    134;
  baudm[19] =    110;
  baudm[20] =     75;
  baudm[21] =     50;
end
reg [15:0] dividend1, dividend2;
reg [15:0] divisor1, divisor2;
task random_baud;
  begin
  bauda = $urandom_range(4,4);
  while(bauda==3) bauda = $urandom_range(0,10);
  baud = baudm[bauda];
  /*dividend1 = 16'd2;
  while(dividend1<(16*(freq_fclk1/baud))) begin
    dividend1 = dividend1<<1;
    divisor1 = (dividend1*baud)/freq_fclk1;
  end
  dividend2 = 16'd2;
  while(dividend2<(16*(freq_fclk2/baud))) begin
    dividend2 = dividend2<<1;
    divisor2 = (dividend1*baud)/freq_fclk2;
  end*/
  //dividend1 = 'hefff; while(((dividend1*baud)%freq_fclk1)>1) dividend1 = dividend1 - 'h1;
  //dividend2 = 'hefff; while(((dividend2*baud)%freq_fclk2)>1) dividend2 = dividend2 - 'h1;
  dividend1 = $urandom_range(16'h7ffe,16'h7ffe);
  dividend2 = $urandom_range(16'h7ffe,16'h7ffe);
  divisor1 = (dividend1*baud)/freq_fclk1;
  divisor2 = (dividend1*baud)/freq_fclk2;
  $write("baud=%d, dividend1=%x, divisor1=%x\n", baud, dividend1, divisor1);
  $write("baud=%d, dividend2=%x, divisor2=%x\n", baud, dividend2, divisor2);
  end
endtask

wire x;
reg rx_frstb, tx_frstb;
wire rx_fclk = fclk1;
wire tx_fclk = fclk2;
wire [31:0] rx_prdata, tx_prdata;
reg [31:0] rx_pwdata, tx_pwdata;
reg [3:0] rx_paddr, tx_paddr;
reg rx_pwrite, rx_psel, rx_penable, rx_prstb;
reg tx_pwrite, tx_psel, tx_penable, tx_prstb;
wire rx_pclk = clk;
wire tx_pclk = clk;

apb_lpuart u_apb_lpuar (
  .dma_ack(), 
  .dma_req(), 
  .tx(), .rts(), 
  .rx(x), .cts(), 
  .uclk(), 
  .intr(), 
  .frstb(rx_frstb), .fclk(rx_fclk), 
  .prdata(rx_prdata), 
  .pwdata(rx_pwdata), 
  .paddr(rx_paddr), 
  .pwrite(rx_pwrite), .psel(rx_psel), .penable(rx_penable), .prstb(rx_prstb), .pclk(rx_pclk) 
);

apb_lpuart u_apb_lpuat (
  .dma_ack(), 
  .dma_req(), 
  .tx(x), .rts(), 
  .rx(), .cts(), 
  .uclk(), 
  .intr(), 
  .frstb(tx_frstb), .fclk(tx_fclk), 
  .prdata(tx_prdata), 
  .pwdata(tx_pwdata), 
  .paddr(tx_paddr), 
  .pwrite(tx_pwrite), .psel(tx_psel), .penable(tx_penable), .prstb(tx_prstb), .pclk(tx_pclk) 
);

task rx_opr_apb(input _write, input [31:0] _addr, input [31:0] _wdata);
begin
  //$write("rx_opr_apb ");
	rx_psel = 1'b0;
	rx_penable = 1'b0;
	@(posedge rx_pclk); #0.2;
	rx_paddr = _addr;
	rx_pwdata = _wdata;
	rx_psel = 1'b1;
	rx_pwrite = _write;
	@(posedge rx_pclk); #0.2;
	rx_penable = 1'b1;
  /*if(tx_pwrite) begin
    $write("write *&%x=%x", rx_paddr, rx_pwdata);
  end
  else begin
    $write("read *&%x=%x", rx_paddr, rx_prdata);
  end*/
	@(posedge rx_pclk); #0.2;
	rx_psel = 1'b0;
	rx_penable = 1'b0;
  //$write("\n");
end
endtask

task tx_opr_apb(input _write, input [31:0] _addr, input [31:0] _wdata);
begin
  //$write("tx_opr_apb ");
	tx_psel = 1'b0;
	tx_penable = 1'b0;
	@(posedge tx_pclk); #0.2;
	tx_paddr = _addr;
	tx_pwdata = _wdata;
	tx_psel = 1'b1;
	tx_pwrite = _write;
	@(posedge tx_pclk); #0.2;
	tx_penable = 1'b1;
  /*if(tx_pwrite) begin
    $write("write *&%x=%x", tx_paddr, tx_pwdata);
  end
  else begin
    $write("read *&%x=%x", tx_paddr, tx_prdata);
  end*/
	@(posedge tx_pclk); #0.2;
	tx_psel = 1'b0;
	tx_penable = 1'b0;
  //$write("\n");
end
endtask

reg rempty, wempty;
reg [9:0] rchar, wchar;
reg [4:0] mode;
logic check;
integer k;

initial begin
  `ifdef FST
  $dumpfile("a.fst");
  $dumpvars(0,apb_lpuart_tb1);
  `endif
  `ifdef FSDB
  $fsdbDumpfile("a.fsdb");
  $fsdbDumpvars(0,apb_lpuart_tb1);
  `endif
  rx_frstb = 1'b0;
  tx_frstb = 1'b0;
  rx_prstb = 1'b0;
  tx_prstb = 1'b0;
  random_sel_clk;
  random_baud;
  repeat(55) begin
    fork
      repeat(5) @(posedge tx_pclk); tx_prstb = 1'b1;
      repeat(5) @(posedge rx_pclk); rx_prstb = 1'b1;
    join
    fork
      repeat(5) @(posedge tx_fclk); tx_frstb = 1'b1;
      repeat(5) @(posedge rx_fclk); rx_frstb = 1'b1;
    join
    random_sel_clk;
    random_baud;
    mode = $urandom_range(0,5'b01111);
    mode[2] = 0;
    if(mode[2]) $write("parity, ");
    if(mode[3]) $write("even, ");
    case(mode[1:0])
      2'b01: $write("8bits\n");
      2'b10: $write("7bits\n");
      2'b11: $write("6bits\n");
      default: $write("9bits\n");
    endcase
    rx_pwdata = {divisor2,dividend2}; rx_opr_apb('b1, 'h4, rx_pwdata);
    rx_opr_apb('b0, 'h0, rx_pwdata); rx_pwdata = rx_prdata;
    rx_pwdata[6:2] = {1'b0,mode[3:0]}; rx_opr_apb('b1, 'h0, rx_pwdata);
    tx_pwdata = {divisor1,dividend1}; tx_opr_apb('b1, 'h4, tx_pwdata);
    tx_opr_apb('b0, 'h0, tx_pwdata); tx_pwdata = tx_prdata;
    tx_pwdata[1] = 1'b1; tx_pwdata[6:2] = {1'b1,mode[3:0]}; tx_opr_apb('b1, 'h0, tx_pwdata);
    repeat(1) begin
      wchar = 9'b101010101;
      check = 1;
      k = 0;
      while(check&&(k<55)) begin
        tx_opr_apb('b0, 'hc, tx_pwdata);
        tx_pwdata = tx_prdata;
        tx_pwdata[12] = 1'b0;
        tx_pwdata[13] = 1'b0;
        tx_opr_apb('b1, 'hc, tx_pwdata);
        rx_opr_apb('b0, 'hc, rx_pwdata);
        rx_pwdata = rx_prdata;
        rx_pwdata[12] = 1'b0;
        rx_pwdata[13] = 1'b0;
        rx_opr_apb('b1, 'hc, rx_pwdata);
        fork
          begin
            wchar = $urandom_range(0,9'b111111111);
            tx_pwdata[9:0] = wchar;
            tx_opr_apb('b1, 'h8, tx_pwdata);
            do begin
              tx_opr_apb('b0, 'hc, tx_pwdata);
              wempty = tx_prdata[14];
            end while(~wempty);
            // tx push w1p
            tx_opr_apb('b0, 'hc, tx_pwdata);
            tx_pwdata = tx_prdata;
            tx_pwdata[12] = 1'b1;
            tx_pwdata[13] = 1'b0;
            tx_opr_apb('b1, 'hc, tx_pwdata);
            tx_opr_apb('b0, 'hc, tx_pwdata);
            tx_pwdata = tx_prdata;
            tx_pwdata[12] = 1'b0;
            tx_pwdata[13] = 1'b0;
            tx_opr_apb('b1, 'hc, tx_pwdata);
          end
          begin
            do begin
              rx_opr_apb('b0, 'hc, rx_pwdata);
              rempty = rx_prdata[14];
            end while(rempty);
            rx_opr_apb('b0, 'h8, rx_pwdata);
            rchar = rx_prdata[9:0];
            case(mode[1:0])
              2'b01: rchar = rchar & 10'b1011111111;
              2'b10: rchar = rchar & 10'b1001111111;
              2'b11: rchar = rchar & 10'b1000111111;
            endcase
            case(mode[1:0])
              2'b01: wchar = wchar & 10'b1011111111;
              2'b10: wchar = wchar & 10'b1001111111;
              2'b11: wchar = wchar & 10'b1000111111;
            endcase
            if(rchar!=wchar) begin
              check = 0;
              $write("mismatch: %b != %b\n", rchar, wchar);
            end
            // rx pop w1p
            rx_opr_apb('b0, 'hc, rx_pwdata);
            rx_pwdata = rx_prdata;
            rx_pwdata[12] = 1'b0;
            rx_pwdata[13] = 1'b1;
            rx_opr_apb('b1, 'hc, rx_pwdata);
            rx_opr_apb('b0, 'hc, rx_pwdata);
            rx_pwdata = rx_prdata;
            rx_pwdata[12] = 1'b0;
            rx_pwdata[13] = 1'b0;
            rx_opr_apb('b1, 'hc, rx_pwdata);
            k=k+1;
          end
        join
      end
      if(k>=55) $write("\033[42mPASS\033[0m\n");
      else $write("\033[41mFAIL: %d\033[0m\n", k);
    end
    fork
      repeat(5) @(posedge tx_fclk); tx_frstb = 1'b0;
      repeat(5) @(posedge rx_fclk); rx_frstb = 1'b0;
    join
    fork
      repeat(5) @(posedge tx_pclk); tx_prstb = 1'b0;
      repeat(5) @(posedge rx_pclk); rx_prstb = 1'b0;
    join
  end
  $finish;
end

endmodule
`endif
