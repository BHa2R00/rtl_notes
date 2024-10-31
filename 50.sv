`timescale 1ns/1ps


`define LPUART_FIFO_AMSB 3 
module lpuart (                           //# bus: slave=u_lpuart, addrs={ctrl,baud,data,fifo}; "half-duplex low power uart"
  output tx, rts, 
  input rx, cts, 
  output reg uclk, 
  output reg intr,                        //# bus: addr=fifo, data[16:16], type=ro  ; dma: req=x ; intr;
  output full, empty,                     //# bus: addr=fifo, data[15:14], type=ro ; "write fifo full and empty signal"
  input pop, push,                        //# bus: addr=fifo, data[13:12], type=w1p; dma: ack=tx, ack=rx, nil;
  input [`LPUART_FIFO_AMSB:0] lht, hlt,   //# bus: addr=fifo, data[11: 4]=h0, type=rw  ; "write fifo interrupt low2high and high2low trigger"
  output [`LPUART_FIFO_AMSB:0] cnt,       //# bus: addr=fifo, data[ 3: 0], type=ro ; "read and write fifo counter"
  output [7:0] rchar,                     //# bus: addr=data, data[ 7: 0], type=ro ; "read char"
  input [7:0] wchar,                      //# bus: addr=data, data[ 7: 0], type=rw ; "write char"
  input [15:0] divisor, dividend,         //# bus: addr=baud, data[31: 0]=h0, type=rw ;
  input fc,                               //# bus: addr=ctrl, data[ 7: 7]=b0, type=rw ; "enable flow control"
  input [4:0] mode,                       //# bus: addr=ctrl, data[ 6: 2]=h0, type=rw ; "mode[4] = enable tx, mode[3] = even, mode[2] = parity, mode[1:0] = b00:9bits, b01:8bits, b10:7bits, b11:6bits"
  input clear, setb,                      //# bus: addr=ctrl, data[ 1: 0]=b00, type=rw ;
  input frstb, fclk,                      //# rc: frstb, fclk;
  input rstb, clk                         //# rc: rstb, clk;
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
reg [7:0] b[0:((2**`LPUART_FIFO_AMSB)-1)];
reg [`LPUART_FIFO_AMSB:0] ba1, ba0;
assign cnt = ba1 - ba0;
assign full  = cnt == (2**`LPUART_FIFO_AMSB);
assign empty = cnt == 4'h0;
reg [3:0] a, na;
wire [7:0] wbc = ena_tx ? b[ba0[(`LPUART_FIFO_AMSB-1):0]] : 8'hff;
wire [7:0] rbc = ena_tx ? 8'hff : b[ba1[(`LPUART_FIFO_AMSB-1):0]];
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
  (a >= 4'ha) ? 1'b0 : 
  (a >= 4'h9) ? 1'b1 : 
  (ena_parity && (a == 4'h8)) ? (even ? ~xortx : xortx) : 
  b[ba0[(`LPUART_FIFO_AMSB-1):0]][a[2:0]]) : 
  1'b1;
reg [1:0] clear_d, push_d, pop_d;
wire clear_p = clear_d == 2'b01;
wire push_p = push_d == 2'b01;
wire pop_p = pop_d == 2'b01;
reg valid;
assign rchar = ena_tx ? 8'hff : b[ba0[(`LPUART_FIFO_AMSB-1):0]];
assign rts = (a==4'h9) && (na==4'h9);
reg [1:0] fclear_d;
wire fclear_p = fclear_d == 2'b01;
reg [1:0] fsetb_d;
wire fsetb_1 = fsetb_d == 2'b11;

always@(negedge frstb or posedge fclk) begin
  if(~frstb) begin
    fclear_d <= 2'b00;
    fsetb_d <= 2'b00;
  end
  else begin
    fclear_d <= {fclear_d[0],(ena_tx ? clear : ((a==4'h9)&&(~rx)))};
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
  if(~rstb) a <= 4'h9;
  else if(~setb || clear_p) a <= 4'h9;
  else if(setb && uclk_n) a <= na;
end
always@(*) begin
  na = a;
  case(a)
    4'h9: if(fc ? cts : (ena_tx ? (~empty) : (~rx))) na = 4'ha;
    4'ha: na = 4'h0;
    4'h4: na = ena_6bit ? (ena_parity ? 4'h8 : 4'h9) : a + 4'h1;
    4'h5: na = ena_7bit ? (ena_parity ? 4'h8 : 4'h9) : a + 4'h1;
    4'h6: na = ena_8bit ? (ena_parity ? 4'h8 : 4'h9) : a + 4'h1;
    4'h7: na = ena_parity ? 4'h8 : 4'h9;
    default: na = a + 4'h1;
  endcase
end

always@(posedge clk) begin
  if(setb) begin
    if(push_p & ena_tx) b[ba1[(`LPUART_FIFO_AMSB-1):0]] <= wchar[7:0];
    else if((~ena_tx) && uclk_n && (4'h7 >= na)) b[ba1[(`LPUART_FIFO_AMSB-1):0]][na[2:0]] <= rx;
  end
end
always@(negedge rstb or posedge clk) begin
  if(~rstb) valid <= 1'b0;
  else if(setb && (~ena_tx) && uclk_n) begin
    if(~ena_parity) valid <= 1'b1;
    else if(4'h8 == na) valid <= (even ? ~xorrx : xorrx) == rx;
  end
end

always@(negedge rstb or posedge clk) begin
  if(~rstb) {ba1,ba0} <= {((`LPUART_FIFO_AMSB+1)*2){1'b0}};
  else if(clear_p) {ba1,ba0} <= {((`LPUART_FIFO_AMSB+1)*2){1'b0}};
  else begin
    if(ena_tx && push_p) ba1 <= ba1 + 'd1;
    if(ena_tx && (na==4'h9) && uclk_n && (~empty)) ba0 <= ba0 + 'd1;
    if((~ena_tx) && (a!=4'h9) && (na==4'h9) && uclk_n && (~full) && valid) ba1 <= ba1 + 'd1;
    if((~ena_tx) && pop_p) ba0 <= ba0 + 'd1;
  end
end

always@(negedge rstb or posedge clk) begin
  if(~rstb) intr <= 1'b0;
  else if(clear_p) intr <= 1'b0;
  else if(
    (intr && (~ena_tx) && push_p && (cnt == hlt))||
    ((~intr) && (~ena_tx) && (na==4'h9) && uclk_n && (cnt == lht))||
    (intr && (na==4'h9) && ena_tx && uclk_n && (cnt == hlt))||
    ((~intr) && ena_tx && pop_p && (cnt == lht))
    ) intr <= ~intr;
end

endmodule


`ifdef SIM
module lpuart_tb1;

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

wire rts, cts;
wire x;
reg fc;
wire rintr, wintr;
reg [`LPUART_FIFO_AMSB:0] rlht, rhlt;
reg [`LPUART_FIFO_AMSB:0] wlht, whlt;
wire rfull, rempty;
wire wfull, wempty;
wire [`LPUART_FIFO_AMSB:0] rcnt;
wire [`LPUART_FIFO_AMSB:0] wcnt;
wire [7:0] rchar;
reg [7:0] wchar;
reg [15:0] dividend1, dividend2;
reg [15:0] divisor1, divisor2;
reg [3:0] mode;
reg push, pop;
reg clear1, clear2;
reg frstb, rstb, setb;
reg [((8*(2**`LPUART_FIFO_AMSB))-1):0] ruint;
reg [((8*(2**`LPUART_FIFO_AMSB))-1):0] wuint;
logic check;
integer k;

integer baudm[0:17];
integer baud;
integer bauda;
initial begin
  baudm[ 0] = 115200;
  baudm[ 1] =  76800;
  baudm[ 2] =  57600;
  baudm[ 3] =  38400;
  baudm[ 4] =  28800;
  baudm[ 5] =  19200;
  baudm[ 6] =   9600;
  baudm[ 7] =   4800;
  baudm[ 8] =   2400;
  baudm[ 9] =   1200;
  baudm[10] =    600;
  baudm[11] =    300;
  baudm[12] =    200;
  baudm[13] =    150;
  baudm[14] =    134;
  baudm[15] =    110;
  baudm[16] =     75;
  baudm[17] =     50;
end
task random_baud;
  begin
  bauda = $urandom_range(0,0);
  baud = baudm[bauda];
  dividend1 = $urandom_range(16'h7fff,16'h7fff);
  dividend2 = $urandom_range(16'h7fff,16'h7fff);
  divisor1 = (dividend1*baud)/freq_fclk1;
  divisor2 = (dividend1*baud)/freq_fclk2;
  $write("baud=%d, dividend1=%x, divisor1=%x\n", baud, dividend1, divisor1);
  $write("baud=%d, dividend2=%x, divisor2=%x\n", baud, dividend2, divisor2);
  end
endtask

lpuart u_uat (
  .rts(rts), 
  .tx(x), .cts(cts), 
  .fc(fc), 
  .intr(wintr), 
  .lht(wlht), .hlt(whlt), 
  .full(wfull), .empty(wempty), 
  .cnt(wcnt), 
  .mode({1'b1,mode}), 
  .wchar(wchar), 
  .dividend(dividend1), 
  .divisor(divisor1), 
  .clear(clear1), .push(push), 
  .setb(setb), 
  .frstb(frstb), .fclk(fclk1), 
  .rstb(rstb), .clk(fclk1) 
);

lpuart u_uar (
  .rx(x), .rts(cts),  
  .cts(rts),  
  .fc(fc), 
  .intr(rintr), 
  .lht(rlht), .hlt(rhlt), 
  .full(rfull), .empty(rempty), 
  .cnt(rcnt), 
  .mode({1'b0,mode}), 
  .rchar(rchar), 
  .dividend(dividend2), 
  .divisor(divisor2), 
  .clear(clear2), .pop(pop), 
  .setb(setb), 
  .frstb(frstb), .fclk(fclk2), 
  .rstb(rstb), .clk(fclk2) 
);

initial begin
  `ifdef FST
  $dumpfile("a.fst");
  $dumpvars(0,lpuart_tb1);
  `endif
  `ifdef FSDB
  $fsdbDumpfile("a.fsdb");
  $fsdbDumpvars(0,lpuart_tb1);
  `endif
  random_sel_clk;
  rstb = 1'b0;
  frstb = 1'b0;
  setb = 1'b0;
  clear1 = 1'b0;
  clear2 = 1'b0;
  push = 1'b0;
  pop = 1'b0;
  rlht = 4'd1;
  rhlt = 4'd1;
  wlht = 4'd1;
  whlt = 4'd1;
  check = 1;
  mode = 4'b0000;
  random_baud;
  fc = 1'b0;
  repeat(55) begin
    repeat(5) @(posedge clk); rstb = 1'b1;
    repeat(5) @(posedge clk); frstb = 1'b1;
    repeat(5) @(posedge clk); setb = 1'b1;
    repeat(5) begin
    random_baud;
    fc = 1'b0;//$urandom_range(0,1);
    mode = $urandom_range(0,4'b1111);
    mode[2] = 0;
    if(mode[2]) $write("parity, ");
    if(mode[3]) $write("even, ");
    case(mode[1:0])
      2'b01: $write("8bits\n");
      2'b10: $write("7bits\n");
      2'b11: $write("6bits\n");
      default: $write("9bits\n");
    endcase
    rlht = $urandom_range(1,6);
    rhlt = $urandom_range(1,6);
    wlht = $urandom_range(1,6);
    whlt = $urandom_range(1,6);
	fork
		begin
    		repeat($urandom_range(1,1)) @(posedge fclk1); clear1 = 1'b1;
    		repeat($urandom_range(2,2)) @(posedge fclk1); clear1 = 1'b0;
		end
		begin
    		repeat($urandom_range(1,1)) @(posedge fclk2); clear2 = 1'b1;
    		repeat($urandom_range(2,2)) @(posedge fclk2); clear2 = 1'b0;
		end
	join
	check = 1;
	k = 0;
  while(check&&(k<10)) begin
    push = 1'b0; pop = 1'b0;
    fork
      begin
        do @(posedge clk); while(~wempty);
		    repeat(8) @(posedge CLK[0]);
          repeat(1) @(posedge clk);
          repeat(2**`LPUART_FIFO_AMSB) begin
            wuint = wuint >> 8;
            case(mode[1:0])
              2'b00: wchar = $urandom_range(0,8'b11111111);
              2'b01: wchar = $urandom_range(0,8'b01111111);
              2'b10: wchar = $urandom_range(0,8'b00111111);
              2'b11: wchar = $urandom_range(0,8'b00011111);
            endcase
            wuint[((8*(2**`LPUART_FIFO_AMSB))-1):((8*(2**`LPUART_FIFO_AMSB))-8)] = wchar;
            repeat(2) @(posedge clk); push = 1'b1;
            repeat(2) @(posedge clk); push = 1'b0;
          end
          $write("push: wuint = %x, ", wuint); 
        end
		  fork
		    begin
			    repeat(64) @(posedge CLK[0]);
			    $write("pop time out, ");
          /*if(check) begin
            check = wuint == ruint;
            $write("check = %b, ", check);
          end*/
		    end
        begin
          @(posedge rfull);
          //repeat($urandom_range(55,555)) @(posedge clk);
          repeat(2**`LPUART_FIFO_AMSB) begin
            case(mode[1:0])
              2'b00: ruint[((8*(2**`LPUART_FIFO_AMSB))-1):((8*(2**`LPUART_FIFO_AMSB))-8)] = rchar & 8'b11111111;
              2'b01: ruint[((8*(2**`LPUART_FIFO_AMSB))-1):((8*(2**`LPUART_FIFO_AMSB))-8)] = rchar & 8'b01111111;
              2'b10: ruint[((8*(2**`LPUART_FIFO_AMSB))-1):((8*(2**`LPUART_FIFO_AMSB))-8)] = rchar & 8'b00111111;
              2'b11: ruint[((8*(2**`LPUART_FIFO_AMSB))-1):((8*(2**`LPUART_FIFO_AMSB))-8)] = rchar & 8'b00011111;
            endcase
            repeat(2) @(posedge clk); pop = 1'b1;
            repeat(2) @(posedge clk); pop = 1'b0;
            if(~rempty) ruint = ruint >> 8;
          end
          $write("pop: ruint = %x, ", ruint); 
          if(check) begin
            check = wuint == ruint;
            $write("check = %b, ", check);
          end
        end
		join_any
    join $write("\n");
    k = k+1;
    end
    end
    repeat(5) @(posedge clk); setb = 1'b0;
    repeat(5) @(posedge clk); frstb = 1'b0;
    repeat(5) @(posedge clk); rstb = 1'b0;
    random_sel_clk;
  end
  $finish;
end

endmodule
`endif


module lpuart_ft1 (
  output tx, uclk, 
  output reg clk2m, 
  input rst, clk 
);

wire rstb = ~rst;
reg [15:0] cnt2m;
always@(negedge rstb or posedge clk) begin
  if(~rstb) begin
    cnt2m <= 16'd0;
    clk2m <= 1'b0;
  end
  else begin
    if(cnt2m >= 25) begin
      cnt2m <= cnt2m-25+1;
      clk2m <= 1'b1;
    end
    else begin
      cnt2m <= cnt2m+1;
      if(cnt2m >= (25>>1)) clk2m <= 1'b0;
    end
  end
end

wire empty;
reg [2:0] a;
wire [7:0] char =
  (a==3'd0) ? "o" : 
  (a==3'd1) ? "h" : 
  (a==3'd2) ? "," : 
  (a==3'd3) ? "s" : 
  (a==3'd4) ? "h" : 
  (a==3'd5) ? "i" : 
  (a==3'd6) ? "t" : 
  (a==3'd7) ? "!" : 
  " ";
reg clear, push;
reg setb;
lpuart u_uat (
  .tx(tx), 
  .fc(1'b0), 
  .uclk(uclk),
  .empty(empty), 
  .mode({1'b1,4'b0000}), 
  .wchar(char), 
  .dividend(16'h7fff), 
  .divisor(16'h0755), 
  .clear(clear), .push(push), 
  .setb(setb), 
  .frstb(rstb), .fclk(clk2m), 
  .rstb(rstb), .clk(clk2m) 
);

always@(negedge rstb or posedge clk2m) begin
  if(~rstb) begin
    a <= 3'd0;
    push <= 1'b0;
  end
  else begin
    if(push) push <= 1'b0;
    else if(empty) begin
      push <= 1'b1;
      a <= a + 3'd1;
    end
  end
end

always@(negedge rstb or posedge clk2m) begin
  if(~rstb) begin
    clear <= 1'b0;
    setb <= 1'b0;
  end
  else begin
    if(~setb) setb <= 1'b1;
    else if(~clear) clear <= 1'b1;
  end
end

endmodule


module lpuart_ft2 (
  input rx, 
  output tx, uclk, 
  output reg clk2m, 
  input rst, clk 
);

wire rstb = ~rst;
reg [15:0] cnt2m;
always@(negedge rstb or posedge clk) begin
  if(~rstb) begin
    cnt2m <= 16'd0;
    clk2m <= 1'b0;
  end
  else begin
    if(cnt2m >= 25) begin
      cnt2m <= cnt2m-25+1;
      clk2m <= 1'b1;
    end
    else begin
      cnt2m <= cnt2m+1;
      if(cnt2m >= (25>>1)) clk2m <= 1'b0;
    end
  end
end

wire wempty, rempty;
reg [7:0] wchar;
wire [7:0] rchar;
reg clear, push, pop;
reg setb;
lpuart u_uat (
  .tx(tx), 
  .fc(1'b0), 
  .uclk(uclk),
  .empty(wempty), 
  .mode({1'b1,4'b0000}), 
  .wchar(wchar), 
  .dividend(16'h7fff), 
  .divisor(16'h0755), 
  .clear(clear), .push(push), 
  .setb(setb), 
  .frstb(rstb), .fclk(clk2m), 
  .rstb(rstb), .clk(clk2m) 
);
lpuart u_uar (
  .rx(rx), 
  .fc(1'b0), 
  .empty(rempty), 
  .mode({1'b0,4'b0000}), 
  .rchar(rchar), 
  .dividend(16'h7fff), 
  .divisor(16'h0755), 
  .clear(clear), .pop(pop), 
  .setb(setb), 
  .frstb(rstb), .fclk(clk2m), 
  .rstb(rstb), .clk(clk2m) 
);

always@(negedge rstb or posedge clk2m) begin
  if(~rstb) begin
    push <= 1'b0;
    pop <= 1'b0;
    wchar <= 8'd0;
  end
  else begin
    if(pop) begin
      if(rempty) begin
        pop <= 1'b0;
        push <= 1'b1;
      end
    end
    else begin
      if(!rempty) begin
        pop <= 1'b1;
        wchar <= rchar;
        push <= 1'b0;
      end
    end
  end
end

always@(negedge rstb or posedge clk2m) begin
  if(~rstb) begin
    clear <= 1'b0;
    setb <= 1'b0;
  end
  else begin
    if(~setb) setb <= 1'b1;
    else if(~clear) clear <= 1'b1;
  end
end

endmodule
/*
# quartus_sh -t 50_EP4CE10E22C8.tcl 
load_package flow
project_new "lpuart_ft2" -overwrite
set_global_assignment -name FAMILY "Cyclone IV E"
set_global_assignment -name DEVICE EP4CE10E22C8
set_global_assignment -name TOP_LEVEL_ENTITY lpuart_ft2
set_global_assignment -name VERILOG_FILE 50.sv
set_global_assignment -name PROJECT_OUTPUT_DIRECTORY ./quartus_output_files
set_global_assignment -name DEVICE_FILTER_SPEED_GRADE 8
set_global_assignment -name MIN_CORE_JUNCTION_TEMP 0
set_global_assignment -name MAX_CORE_JUNCTION_TEMP 85
set_global_assignment -name VERILOG_SHOW_LMF_MAPPING_MESSAGES ON
set_global_assignment -name STRATIX_DEVICE_IO_STANDARD "2.5 V"
set_location_assignment PIN_91 -to clk
set_location_assignment PIN_88 -to rst
set_location_assignment PIN_100 -to clk2m
set_location_assignment PIN_99 -to uclk
set_location_assignment PIN_55 -to rx
set_location_assignment PIN_58 -to tx
execute_flow -compile
export_assignments
project_close

 */

`ifdef SIM
module lpuart_tb2;

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
  sel_fclk1 = $urandom_range(8,26);
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

wire rts, cts;
wire x;
reg fc;
wire rintr, wintr;
reg [`LPUART_FIFO_AMSB:0] rlht, rhlt;
reg [`LPUART_FIFO_AMSB:0] wlht, whlt;
wire rfull, rempty;
wire wfull, wempty;
wire [`LPUART_FIFO_AMSB:0] rcnt;
wire [`LPUART_FIFO_AMSB:0] wcnt;
wire [7:0] rchar;
reg [7:0] wchar;
reg [15:0] dividend1, dividend2;
reg [15:0] divisor1, divisor2;
reg [3:0] mode;
reg push, pop;
reg clear1, clear2;
reg frstb, rstb, setb;
logic check;
integer k;

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

lpuart u_uat (
  .rts(rts), 
  .tx(x), .cts(cts), 
  .fc(fc), 
  .intr(wintr), 
  .lht(wlht), .hlt(whlt), 
  .full(wfull), .empty(wempty), 
  .cnt(wcnt), 
  .mode({1'b1,mode}), 
  .wchar(wchar), 
  .dividend(dividend1), 
  .divisor(divisor1), 
  .clear(clear1), .push(push), 
  .setb(setb), 
  .frstb(frstb), .fclk(fclk1), 
  .rstb(rstb), .clk(fclk1) 
);

lpuart u_uar (
  .rx(x), .rts(cts),  
  .cts(rts),  
  .fc(fc), 
  .intr(rintr), 
  .lht(rlht), .hlt(rhlt), 
  .full(rfull), .empty(rempty), 
  .cnt(rcnt), 
  .mode({1'b0,mode}), 
  .rchar(rchar), 
  .dividend(dividend2), 
  .divisor(divisor2), 
  .clear(clear2), .pop(pop), 
  .setb(setb), 
  .frstb(frstb), .fclk(fclk2), 
  .rstb(rstb), .clk(fclk2) 
);

initial begin
  `ifdef FST
  $dumpfile("a.fst");
  $dumpvars(0,lpuart_tb2);
  `endif
  `ifdef FSDB
  $fsdbDumpfile("a.fsdb");
  $fsdbDumpvars(0,lpuart_tb2);
  `endif
  random_sel_clk;
  rstb = 1'b0;
  frstb = 1'b0;
  setb = 1'b0;
  clear1 = 1'b0;
  clear2 = 1'b0;
  push = 1'b0;
  pop = 1'b0;
  rlht = 4'd1;
  rhlt = 4'd1;
  wlht = 4'd1;
  whlt = 4'd1;
  check = 1;
  mode = 4'b0000;
  random_baud;
  fc = 1'b0;
  repeat(55) begin
    repeat(5) @(posedge clk); rstb = 1'b1;
    repeat(5) @(posedge clk); frstb = 1'b1;
    repeat(5) @(posedge clk); setb = 1'b1;
    random_sel_clk;
    random_baud;
    fc = 1'b0;//$urandom_range(0,1);
    mode = $urandom_range(0,4'b1111);
    mode[2] = 0;
    if(mode[2]) $write("parity, ");
    if(mode[3]) $write("even, ");
    case(mode[1:0])
      2'b01: $write("8bits\n");
      2'b10: $write("7bits\n");
      2'b11: $write("6bits\n");
      default: $write("9bits\n");
    endcase
    rlht = $urandom_range(1,6);
    rhlt = $urandom_range(1,6);
    wlht = $urandom_range(1,6);
    whlt = $urandom_range(1,6);
    repeat(1) begin
    wchar = 8'b01010101;
    repeat($urandom_range(2,2)) @(posedge fclk1); clear1 = 1'b1;
    repeat($urandom_range(2,2)) @(posedge fclk1); clear1 = 1'b0;
    check = 1;
    k = 0;
    while(check&&(k<55)) begin
      push = 1'b0; pop = 1'b0;
      fork
        begin
          do @(posedge clk); while(~wempty);
          repeat(2) @(posedge clk); push = 1'b1;
          repeat(2) @(posedge clk); push = 1'b0;
        end
        begin
          do @(posedge clk); while(rempty);
          if(rchar!=wchar) begin
            check = 0;
            $write("mismatch: rchar = %b\n", rchar);
          end
          repeat(2) @(posedge clk); pop = 1'b1;
          repeat(2) @(posedge clk); pop = 1'b0;
          k=k+1;
        end
      join
    end
    if(k>=55) $write("\033[42mPASS\033[0m\n");
    else $write("\033[41mFAIL: %d\033[0m\n", k);
    end
  end
  $finish;
end

endmodule
`endif


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
  input [1:0] paddr, 
  input pwrite, psel, penable, prstb, pclk 
);

wire u_lpuart_intr;
reg intr_ena;
assign intr = intr_ena ? u_lpuart_intr : 1'b0;
reg [1:0] dma_ack_d;
wire dma_ack_p = dma_ack_d == 2'b01;
reg dma_ena;
wire full, empty;
reg pop, push;
reg [3:0] lht, hlt;
wire [3:0] cnt;
wire [7:0] rchar;
reg [7:0] wchar;
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
wire baud_ena = (paddr == 'h1) && penable && psel;
wire data_ena = (paddr == 'h2) && penable && psel;
wire fifo_ena = (paddr == 'h3) && penable && psel;

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
    prdata[7:0] = rchar;
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
    wchar <= pwdata[7:0];
  end
  else if(fifo_ena && pwrite) begin
    hlt <= pwdata[7:4];
    lht <= pwdata[11:8];
    push <= push? 'h0:pwdata[12];
    pop <= pop? 'h0:pwdata[13];
  end
end

endmodule
/*
# sdc 
create_clock -name pclk [get_ports pclk]  -period 500  -waveform {0 250}
create_clock -name fclk [get_ports fclk]  -period 500  -waveform {0 250}
set_false_path -from [get_ports prstb]
set_false_path -from [get_ports frstb]
# dft 
set_scan_configuration -clock_mixing mix_clocks
set_scan_configuration -add_lockup true
set_scan_configuration -internal_clocks multi
set_scan_configuration -chain_count 1
set_dft_signal -port test_se   -type scanenable  -view existing_dft -active_state 1 
set_dft_signal -port clk       -type scanclock   -view existing_dft -timing {50 100} 
set_dft_signal -port test_si   -type scandatain  -view existing_dft 
set_dft_signal -port test_so   -type scandataout -view existing_dft 
set_scan_path 1 -view existing_dft -scan_enable test_se -scan_data_in test_si -scan_data_out test_so -scan_master_clock pclk
create_test_protocol -infer_clock -infer_asynch
preview_dft
insert_dft
dft_drc
# tmax -shell
read_netlist ${top}_mapped.v 
read_netlist ../lib/isf8l/verilog/isf8l_ers_generic_core_21.lib.src -library 
read_netlist ../lib/isf8l/verilog/isf8l_ers_generic_core_30.lib.src -library 
run_build_model ${top}
run_drc ${top}_mapped.spf
set_faults -model stuck
add_faults -all
set_atpg -merge high -verbose -abort_limit 256 -coverage 100 -decision random
run_atpg
set_faults -summary verbose
set_faults -report collapsed
report_summaries
write_faults ${top}_tmax_faults.rpt -all -replace
write_patterns ${top}_mapped.stil -format stil -replace

 */


`ifdef SIM
`ifdef UVM
`ifndef LPUART_REG_MODEL__SV
`define LPUART_REG_MODEL__SV

class LPUART_REG_ctrl extends uvm_reg;
  rand uvm_reg_field setb;
  rand uvm_reg_field clear;
  rand uvm_reg_field mode;
  rand uvm_reg_field fc;
  rand uvm_reg_field dma_ena;
  rand uvm_reg_field unused0;
  function new(string name = "LPUART_REG_ctrl");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction : new
  virtual function void build();
    this.setb = uvm_reg_field::type_id::create("setb", , get_full_name());
    this.clear = uvm_reg_field::type_id::create("clear", , get_full_name());
    this.mode = uvm_reg_field::type_id::create("mode", , get_full_name());
    this.fc = uvm_reg_field::type_id::create("fc", , get_full_name());
    this.dma_ena = uvm_reg_field::type_id::create("dma_ena", , get_full_name());
    this.unused0 = uvm_reg_field::type_id::create("unused0", , get_full_name());
    this.setb.configure(this, 1, 0, "RW", 0, 1'h0, 1, 0, 1);
    this.clear.configure(this, 1, 1, "RW", 0, 1'h0, 1, 0, 1);
    this.mode.configure(this, 5, 2, "RW", 0, 5'h0, 1, 0, 1);
    this.fc.configure(this, 1, 7, "RW", 0, 1'h0, 1, 0, 1);
    this.dma_ena.configure(this, 1, 8, "RW", 0, 1'h0, 1, 0, 1);
    this.unused0.configure(this, 23, 9, "RO", 0, 23'h0, 1, 0, 1);
  endfunction : build
  `uvm_object_utils(LPUART_REG_ctrl)
endclass : LPUART_REG_ctrl

class LPUART_REG_baud extends uvm_reg;
  rand uvm_reg_field dividend;
  rand uvm_reg_field divisor;
  function new(string name = "LPUART_REG_baud");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction : new
  virtual function void build();
    this.dividend = uvm_reg_field::type_id::create("dividend", , get_full_name());
    this.divisor = uvm_reg_field::type_id::create("divisor", , get_full_name());
    this.dividend.configure(this, 16, 0, "RW", 0, 16'h0, 1, 0, 1);
    this.divisor.configure(this, 16, 16, "RW", 0, 16'h0, 1, 0, 1);
  endfunction : build
  `uvm_object_utils(LPUART_REG_baud)
endclass : LPUART_REG_baud

class LPUART_REG_data extends uvm_reg;
  rand uvm_reg_field bchar;
  rand uvm_reg_field unused1;
  function new(string name = "LPUART_REG_data");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction : new
  virtual function void build();
    this.bchar = uvm_reg_field::type_id::create("bchar", , get_full_name());
    this.unused1 = uvm_reg_field::type_id::create("unused1", , get_full_name());
    this.bchar.configure(this, 8, 0, "RW", 0, 8'h0, 1, 0, 1);
    this.unused1.configure(this, 24, 8, "RO", 0, 24'h0, 1, 0, 1);
  endfunction : build
  `uvm_object_utils(LPUART_REG_data)
endclass : LPUART_REG_data

class LPUART_REG_fifo extends uvm_reg;
  rand uvm_reg_field cnt;
  rand uvm_reg_field hlt;
  rand uvm_reg_field lht;
  rand uvm_reg_field push;
  rand uvm_reg_field pop;
  rand uvm_reg_field empty;
  rand uvm_reg_field full;
  rand uvm_reg_field intr;
  rand uvm_reg_field unused2;
  function new(string name = "LPUART_REG_fifo");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction : new
  virtual function void build();
    this.cnt = uvm_reg_field::type_id::create("cnt", , get_full_name());
    this.hlt = uvm_reg_field::type_id::create("hlt", , get_full_name());
    this.lht = uvm_reg_field::type_id::create("lht", , get_full_name());
    this.push = uvm_reg_field::type_id::create("push", , get_full_name());
    this.pop = uvm_reg_field::type_id::create("pop", , get_full_name());
    this.empty = uvm_reg_field::type_id::create("empty", , get_full_name());
    this.full = uvm_reg_field::type_id::create("full", , get_full_name());
    this.intr = uvm_reg_field::type_id::create("intr", , get_full_name());
    this.unused2 = uvm_reg_field::type_id::create("unused2", , get_full_name());
    this.cnt.configure(this, 4, 0, "RW", 0, 4'h0, 1, 0, 1);
    this.hlt.configure(this, 4, 4, "RW", 0, 4'h0, 1, 0, 1);
    this.lht.configure(this, 4, 8, "RW", 0, 4'h0, 1, 0, 1);
    this.push.configure(this, 1, 12, "W1P", 0, 1'h0, 1, 0, 1);
    this.pop.configure(this, 1, 13, "W1P", 0, 1'h0, 1, 0, 1);
    this.empty.configure(this, 1, 14, "RO", 0, 1'h0, 1, 0, 1);
    this.full.configure(this, 1, 15, "RO", 0, 1'h0, 1, 0, 1);
    this.intr.configure(this, 1, 16, "RO", 0, 1'h0, 1, 0, 1);
    this.unused2.configure(this, 15, 17, "RO", 0, 15'h0, 1, 0, 1);
  endfunction : build
  `uvm_object_utils(LPUART_REG_fifo)
endclass : LPUART_REG_fifo

`endif//LPUART_REG_MODEL__SV
`endif
`endif
