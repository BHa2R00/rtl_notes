`timescale 1ns/1ps


module lpuart (               //# bus: slave=u_lpuart, addr0=h010a ;
  output test_so, 
  input test_se, test_si,
  output tx,                  //# io: mux={1,3,5} ;
  input rx,                   //# io: mux={0,2,4} ;
  output reg rintr, wintr,    //# bus: addr=h0003, data[25:24], type=ro  ; dma: req=rx, req=tx ; intr;
  input [3:0] rlht, rhlt,     //# bus: addr=h0003, data[23:18], type=rw  ; "read fifo interrupt low2high and high2low trigger"
  input [3:0] wlht, whlt,     //# bus: addr=h0003, data[17:12], type=rw  ; "write fifo interrupt low2high and high2low trigger"
  output rfull, rempty,       //# bus: addr=h0003, data[11:10], type=ro  ; "read fifo full and empty signal"
  output wfull, wempty,       //# bus: addr=h0003, data[ 9: 8], type=ro  ; "write fifo full and empty signal"
  output [3:0] rcnt, wcnt,    //# bus: addr=h0003, data[ 7: 0], type=ro  ; "read and write fifo counter"
  input pop, push, clear,     //# bus: addr=h0000, data[ 7: 5], type=w1p ; dma: ack=tx, ack=rx, nil;
  input [3:0] mode,           //# bus: addr=h0000, data[ 4: 2], type=rw  ; "mode[3] = even, mode[2] = parity, mode[1:0] = b00:9bits, b01:8bits, b10:7bits, b11:6bits"
  output [7:0] rchar,         //# bus: addr=h0002, data[15: 8], type=ro  ; "read char"
  input [7:0] wchar,          //# bus: addr=h0002, data[ 7: 0], type=rw  ; "write char"
  input [7:0] div,            //# bus: addr=h0001, data[ 7: 0], type=rw  ; "clock dividend of baud clock"
  input setb,                 //# bus: addr=h0000, data[ 0: 0], type=rw  ; "module enable and clock gating"
  input frstb, fclk,          //# rc: frstb, fclk=2M ;
  input rstb, clk             //# rc: rstb, clk;
);

wire ena_8bit = mode[1:0] == 2'b01;
wire ena_7bit = mode[1:0] == 2'b10;
wire ena_6bit = mode[1:0] == 2'b11;
wire ena_parity = mode[2];
wire even = mode[3];
wire cts;
reg [1:0] cts_d;
wire cts_p = cts_d == 2'b01;
reg [7:0] cnt;
wire eq = cnt == 8'd0;
reg [1:0] eq_d;
wire xclk = eq_d == 2'b10;
reg [7:0] rb[0:7];
reg [7:0] wb[0:7];
reg [3:0] ra1, ra0;
reg [3:0] wa1, wa0;
assign rcnt = ra1 - ra0;
assign wcnt = wa1 - wa0;
assign rfull  = rcnt == 4'd8;
assign rempty = rcnt == 4'd0;
assign wfull  = wcnt == 4'd8;
assign wempty = wcnt == 4'd0;
reg [3:0] ra, ta;
wire [7:0] wbc = wb[wa0[2:0]];
wire [7:0] rbc = rb[ra1[2:0]];
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
assign tx =
  (ta >= 4'd10) ? 1'b0 : 
  (ta >= 4'd9) ? 1'b1 : 
  (ena_parity && (ta == 4'd8)) ? (even ? ~xortx : xortx) : 
  wb[wa0[2:0]][ta[2:0]];
reg [1:0] clear_d, push_d, pop_d;
wire clear_p = clear_d == 2'b01;
wire push_p = push_d == 2'b01;
wire pop_p = pop_d == 2'b01;
wire tidle = ta == 4'd9;
wire ridle = ra == 4'd9;
reg valid;
assign rchar = rb[ra0[2:0]];
assign cts = (~wempty) || ((~rfull) && (~rx));

always@(negedge frstb or posedge fclk) begin
  if(~frstb) cts_d <= 2'b11;
  else cts_d <= {cts_d[0],cts};
end
always@(negedge rstb or posedge clk) begin
  if(~rstb) eq_d <= 2'b11;
  else eq_d <= {eq_d[0],eq};
end

always@(negedge frstb or posedge fclk) begin
  if(~frstb) cnt <= 8'd0;
  else if(setb) begin
    if(cts_p) cnt <= div;
    else cnt <= eq ? div : cnt - 8'd1;
  end
end

always@(negedge rstb or posedge clk) begin
  if(~rstb) ra <= 4'd9;
  else if(~setb) ra <= 4'd9;
  else if(xclk) ra <= ta;
end
always@(*) begin
  ta = ra;
  case(ra)
    4'd9 : if(cts) ta = 4'd10;
    4'd10: ta = 4'd0;
    4'd4 : ta = ena_6bit ? (ena_parity ? 4'd8 : 4'd9) : ta + 4'd1;
    4'd5 : ta = ena_7bit ? (ena_parity ? 4'd8 : 4'd9) : ta + 4'd1;
    4'd6 : ta = ena_8bit ? (ena_parity ? 4'd8 : 4'd9) : ta + 4'd1;
    4'd7 : ta = ena_parity ? 4'd8 : 4'd9;
    default: ta = ta + 4'd1;
  endcase
end

always@(posedge clk) begin
  if(setb) begin
    if(4'd7 >= ta) rb[ra1[2:0]][ta[2:0]] <= rx;
  end
end
always@(negedge rstb or posedge clk) begin
  if(~rstb) valid <= 1'b0;
  else if(setb) begin
    if(~ena_parity) valid <= 1'b1;
    else if(4'd8 == ta) valid <= (even ? ~xorrx : xorrx) == rx;
  end
end

always@(negedge rstb or posedge clk) begin
  if(~rstb) clear_d <= 2'b11;
  else clear_d <= {clear_d[0],clear};
end

always@(negedge rstb or posedge clk) begin
  if(~rstb) push_d <= 2'b11;
  else push_d <= {push_d[0],push};
end

always@(negedge rstb or posedge clk) begin
  if(~rstb) pop_d <= 2'b11;
  else pop_d <= {pop_d[0],pop};
end

always@(negedge rstb or posedge clk) begin
  if(~rstb) wa1 <= 4'd0;
  else if(setb) begin
    if(clear_p) wa1 <= 4'd0;
    else if(push_p) wa1 <= wa1 + 4'd1;
  end
end

always@(negedge rstb or posedge clk) begin
  if(~rstb) ra0 <= 4'd0;
  else if(setb) begin
    if(clear_p) ra0 <= 4'd0;
    else if(pop_p) ra0 <= ra0 + 4'd1;
  end
end

always@(negedge rstb or posedge clk) begin
  if(~rstb) wa0 <= 4'd0;
  else if(setb) begin
    if(clear_p) wa0 <= 4'd0;
    else if(tidle && xclk && (~wempty)) wa0 <= wa0 + 4'd1;
  end
end

always@(negedge rstb or posedge clk) begin
  if(~rstb) ra1 <= 4'd0;
  else if(setb) begin
    if(clear_p) ra1 <= 4'd0;
    else if(tidle && ~ridle && xclk && (~rfull) && valid) ra1 <= ra1 + 4'd1;
  end
end

always@(posedge clk) begin
  if(setb && push_p) wb[wa1[2:0]] <= wchar[7:0];
end

always@(negedge rstb or posedge clk) begin
  if(~rstb) rintr <= 1'b0;
  else if(setb && 
      (
        (rintr && push_p && (rcnt == rhlt))||
        ((~rintr) && ridle && xclk && (rcnt == rlht))
      )
    ) rintr <= ~rintr;
end

always@(negedge rstb or posedge clk) begin
  if(~rstb) wintr <= 1'b0;
  else if(setb && 
      (
        (wintr && tidle && xclk && (wcnt == whlt))||
        ((~wintr) && pop_p && (wcnt == wlht))
      )
    ) wintr <= ~wintr;
end

endmodule


`ifdef SIM
module lpuart_tb;

wire x1, x2;
wire rintr1, wintr1;
wire rintr2, wintr2;
reg [3:0] rlht1, rhlt1;
reg [3:0] rlht2, rhlt2;
reg [3:0] wlht1, whlt1;
reg [3:0] wlht2, whlt2;
wire rfull1, rempty1;
wire rfull2, rempty2;
wire wfull1, wempty1;
wire wfull2, wempty2;
wire [3:0] wcnt1, rcnt1;
wire [3:0] wcnt2, rcnt2;
wire [7:0] rchar1, rchar2;
reg [7:0] wchar1, wchar2;
reg [7:0] div1, div2;
reg [3:0] mode;
reg clear1, push1, pop1;
reg clear2, push2, pop2;
reg frstb, rstb, setb, clk, fclk1, fclk2;
reg [63:0] wuint1, wuint2;
reg [63:0] ruint1, ruint2;
logic check1, check2;
reg [16:0] baudm[0:17];
reg [16:0] baud;
reg [5:0] bauda;

lpuart u_lpuart1 (
  .rx(x2), 
  .tx(x1), 
  .rintr(rintr1), .wintr(wintr1), 
  .rlht(rlht1), .rhlt(rhlt1), 
  .wlht(wlht1), .whlt(whlt1), 
  .rfull(rfull1), .rempty(rempty1), 
  .wfull(wfull1), .wempty(wempty1), 
  .wcnt(wcnt1), .rcnt(rcnt1), 
  .mode(mode), 
  .rchar(rchar1), 
  .wchar(wchar1), 
  .div(div1), 
  .clear(clear1), .push(push1), .pop(pop1), 
  .setb(setb), 
  .frstb(frstb), .fclk(fclk1), 
  .rstb(rstb), .clk(fclk1) 
);

lpuart u_lpuart2 (
  .rx(x1), 
  .tx(x2), 
  .rintr(rintr2), .wintr(wintr2), 
  .rlht(rlht2), .rhlt(rhlt2), 
  .wlht(wlht2), .whlt(whlt2), 
  .rfull(rfull2), .rempty(rempty2), 
  .wfull(wfull2), .wempty(wempty2), 
  .wcnt(wcnt2), .rcnt(rcnt2), 
  .mode(mode), 
  .rchar(rchar2), 
  .wchar(wchar2), 
  .div(div2), 
  .clear(clear2), .push(push2), .pop(pop2), 
  .setb(setb), 
  .frstb(frstb), .fclk(fclk2), 
  .rstb(rstb), .clk(fclk2) 
);

always #250 clk = ~clk;
always #250 fclk1 = ~fclk1;
always #250 fclk2 = ~fclk2;

initial begin
  `ifdef FST
  $dumpfile("a.fst");
  $dumpvars(0,lpuart_tb);
  `endif
  `ifdef FSDB
  $fsdbDumpfile("a.fsdb");
  $fsdbDumpvars(0,lpuart_tb);
  `endif
  clk = 1'b0;
  fclk1 = 1'b0;
  fclk2 = 1'b0;
  rstb = 1'b0;
  frstb = 1'b0;
  setb = 1'b0;
  clear1 = 1'b0;
  clear2 = 1'b0;
  push1 = 1'b0;
  pop1 = 1'b0;
  push2 = 1'b0;
  pop2 = 1'b0;
  rlht1 = 4'd1;
  rhlt1 = 4'd1;
  rlht2 = 4'd1;
  rhlt2 = 4'd1;
  wlht1 = 4'd1;
  whlt1 = 4'd1;
  wlht2 = 4'd1;
  whlt2 = 4'd1;
  check1 = 1;
  check2 = 1;
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
  mode = 4'b0000;
  bauda = $urandom_range(0,6);
  baud = baudm[bauda];
  div1 = 2000000/baud; div1[0]=1'b0; $write("baud=%d, div1=%x\n", baud, div1);
  div2 = 2000000/baud; div2[0]=1'b0; $write("baud=%d, div2=%x\n", baud, div2);
  repeat(5) begin
    repeat(5) @(posedge clk); rstb = 1'b1;
    repeat(5) @(posedge clk); frstb = 1'b1;
    repeat(5) @(posedge clk); setb = 1'b1;
    repeat(5) begin
    bauda = $urandom_range(0,6);
    baud = baudm[bauda];
    div1 = 2000000/baud; div1[0]=1'b0; $write("baud=%d, div1=%x\n", baud, div1);
    div2 = 2000000/baud; div2[0]=1'b0; $write("baud=%d, div2=%x\n", baud, div2);
    mode = $urandom_range(0,4'b1111);
    if(mode[2]) $write("parity, ");
    if(mode[3]) $write("even, ");
    case(mode[1:0])
      2'b01: $write("8bits\n");
      2'b10: $write("7bits\n");
      2'b11: $write("6bits\n");
      default: $write("9bits\n");
    endcase
    rlht1 = $urandom_range(1,6);
    rhlt1 = $urandom_range(1,6);
    rlht2 = $urandom_range(1,6);
    rhlt2 = $urandom_range(1,6);
    wlht1 = $urandom_range(1,6);
    whlt1 = $urandom_range(1,6);
    wlht2 = $urandom_range(1,6);
    whlt2 = $urandom_range(1,6);
    repeat(5) @(posedge clk); clear1 = 1'b1;
    repeat(5) @(posedge clk); clear1 = 1'b0;
    repeat(5) @(posedge clk); clear2 = 1'b1;
    repeat(5) @(posedge clk); clear2 = 1'b0;
    repeat($urandom_range(1,55)) @(posedge clk);
    repeat(5) begin
      //repeat($urandom_range(1,55)) @(posedge clk);
      wuint1 = {$urandom_range(0,{32{1'b1}}),$urandom_range(0,{32{1'b1}})};
      wuint2 = {$urandom_range(0,{32{1'b1}}),$urandom_range(0,{32{1'b1}})};
      push1 = 1'b0; pop1 = 1'b0;
      push2 = 1'b0; pop2 = 1'b0;
      fork
        begin
          do @(posedge clk); while(~wempty1);
          repeat($urandom_range(1,5)) @(posedge clk);
          $write("push1: wuint1 = %x, ", wuint1); 
          wchar1 = wuint1[07:00];
          repeat(2) @(posedge clk); push1 = 1'b1;
          repeat(2) @(posedge clk); push1 = 1'b0;
          wchar1 = wuint1[15:08];
          repeat(2) @(posedge clk); push1 = 1'b1;
          repeat(2) @(posedge clk); push1 = 1'b0;
          wchar1 = wuint1[23:16];
          repeat(2) @(posedge clk); push1 = 1'b1;
          repeat(2) @(posedge clk); push1 = 1'b0;
          wchar1 = wuint1[31:24];
          repeat(2) @(posedge clk); push1 = 1'b1;
          repeat(2) @(posedge clk); push1 = 1'b0;
          wchar1 = wuint1[39:32];
          repeat(2) @(posedge clk); push1 = 1'b1;
          repeat(2) @(posedge clk); push1 = 1'b0;
          wchar1 = wuint1[47:40];
          repeat(2) @(posedge clk); push1 = 1'b1;
          repeat(2) @(posedge clk); push1 = 1'b0;
          wchar1 = wuint1[55:48];
          repeat(2) @(posedge clk); push1 = 1'b1;
          repeat(2) @(posedge clk); push1 = 1'b0;
          wchar1 = wuint1[63:56];
          repeat(2) @(posedge clk); push1 = 1'b1;
          repeat(2) @(posedge clk); push1 = 1'b0;
        end
        begin
          do @(posedge clk); while(~wempty2);
          repeat($urandom_range(1,5)) @(posedge clk);
          $write("push2: wuint2 = %x, ", wuint2); 
          wchar2 = wuint2[07:00];
          repeat(2) @(posedge clk); push2 = 1'b1;
          repeat(2) @(posedge clk); push2 = 1'b0;
          wchar2 = wuint2[15:08];
          repeat(2) @(posedge clk); push2 = 1'b1;
          repeat(2) @(posedge clk); push2 = 1'b0;
          wchar2 = wuint2[23:16];
          repeat(2) @(posedge clk); push2 = 1'b1;
          repeat(2) @(posedge clk); push2 = 1'b0;
          wchar2 = wuint2[31:24];
          repeat(2) @(posedge clk); push2 = 1'b1;
          repeat(2) @(posedge clk); push2 = 1'b0;
          wchar2 = wuint2[39:32];
          repeat(2) @(posedge clk); push2 = 1'b1;
          repeat(2) @(posedge clk); push2 = 1'b0;
          wchar2 = wuint2[47:40];
          repeat(2) @(posedge clk); push2 = 1'b1;
          repeat(2) @(posedge clk); push2 = 1'b0;
          wchar2 = wuint2[55:48];
          repeat(2) @(posedge clk); push2 = 1'b1;
          repeat(2) @(posedge clk); push2 = 1'b0;
          wchar2 = wuint2[63:56];
          repeat(2) @(posedge clk); push2 = 1'b1;
          repeat(2) @(posedge clk); push2 = 1'b0;
        end
        begin
          @(posedge rfull1);
          repeat($urandom_range(1,5)) @(posedge clk);
          ruint1[07:00] = rchar1;
          repeat(2) @(posedge clk); pop1 = 1'b1;
          repeat(2) @(posedge clk); pop1 = 1'b0;
          ruint1[15:08] = rchar1;
          repeat(2) @(posedge clk); pop1 = 1'b1;
          repeat(2) @(posedge clk); pop1 = 1'b0;
          ruint1[23:16] = rchar1;
          repeat(2) @(posedge clk); pop1 = 1'b1;
          repeat(2) @(posedge clk); pop1 = 1'b0;
          ruint1[31:24] = rchar1;
          repeat(2) @(posedge clk); pop1 = 1'b1;
          repeat(2) @(posedge clk); pop1 = 1'b0;
          ruint1[39:32] = rchar1;
          repeat(2) @(posedge clk); pop1 = 1'b1;
          repeat(2) @(posedge clk); pop1 = 1'b0;
          ruint1[47:40] = rchar1;
          repeat(2) @(posedge clk); pop1 = 1'b1;
          repeat(2) @(posedge clk); pop1 = 1'b0;
          ruint1[55:48] = rchar1;
          repeat(2) @(posedge clk); pop1 = 1'b1;
          repeat(2) @(posedge clk); pop1 = 1'b0;
          ruint1[63:56] = rchar1;
          repeat(2) @(posedge clk); pop1 = 1'b1;
          repeat(2) @(posedge clk); pop1 = 1'b0;
          $write("pop1: ruint1 = %x, ", ruint1); 
        end
        begin
          @(posedge rfull2);
          repeat($urandom_range(1,5)) @(posedge clk);
          ruint2[07:00] = rchar2;
          repeat(2) @(posedge clk); pop2 = 1'b1;
          repeat(2) @(posedge clk); pop2 = 1'b0;
          ruint2[15:08] = rchar2;
          repeat(2) @(posedge clk); pop2 = 1'b1;
          repeat(2) @(posedge clk); pop2 = 1'b0;
          ruint2[23:16] = rchar2;
          repeat(2) @(posedge clk); pop2 = 1'b1;
          repeat(2) @(posedge clk); pop2 = 1'b0;
          ruint2[31:24] = rchar2;
          repeat(2) @(posedge clk); pop2 = 1'b1;
          repeat(2) @(posedge clk); pop2 = 1'b0;
          ruint2[39:32] = rchar2;
          repeat(2) @(posedge clk); pop2 = 1'b1;
          repeat(2) @(posedge clk); pop2 = 1'b0;
          ruint2[47:40] = rchar2;
          repeat(2) @(posedge clk); pop2 = 1'b1;
          repeat(2) @(posedge clk); pop2 = 1'b0;
          ruint2[55:48] = rchar2;
          repeat(2) @(posedge clk); pop2 = 1'b1;
          repeat(2) @(posedge clk); pop2 = 1'b0;
          ruint2[63:56] = rchar2;
          repeat(2) @(posedge clk); pop2 = 1'b1;
          repeat(2) @(posedge clk); pop2 = 1'b0;
          $write("pop2: ruint2 = %x, ", ruint2); 
        end
      join $write("\n");
      fork
        if(check1) begin
          if(mode[1:0]==2'b01) begin
            wuint2[31: 0] = wuint2[31: 0] & 32'h7f7f7f7f;
            wuint2[63:32] = wuint2[63:32] & 32'h7f7f7f7f;
            ruint1[31: 0] = ruint1[31: 0] & 32'h7f7f7f7f;
            ruint1[63:32] = ruint1[63:32] & 32'h7f7f7f7f;
          end
          else if(mode[1:0]==2'b10) begin
            wuint2[31: 0] = wuint2[31: 0] & 32'h3f3f3f3f;
            wuint2[63:32] = wuint2[63:32] & 32'h3f3f3f3f;
            ruint1[31: 0] = ruint1[31: 0] & 32'h3f3f3f3f;
            ruint1[63:32] = ruint1[63:32] & 32'h3f3f3f3f;
          end
          else if(mode[1:0]==2'b11) begin
            wuint2[31: 0] = wuint2[31: 0] & 32'h1f1f1f1f;
            wuint2[63:32] = wuint2[63:32] & 32'h1f1f1f1f;
            ruint1[31: 0] = ruint1[31: 0] & 32'h1f1f1f1f;
            ruint1[63:32] = ruint1[63:32] & 32'h1f1f1f1f;
          end
          check1 = wuint2 == ruint1;
          $write("wuint2 = %x, ruint1 = %x, check1 = %b, ", wuint2, ruint1, check1);
        end
        if(check2) begin
          if(mode[1:0]==2'b01) begin
            wuint1[31: 0] = wuint1[31: 0] & 32'h7f7f7f7f;
            wuint1[63:32] = wuint1[63:32] & 32'h7f7f7f7f;
            ruint2[31: 0] = ruint2[31: 0] & 32'h7f7f7f7f;
            ruint2[63:32] = ruint2[63:32] & 32'h7f7f7f7f;
          end
          else if(mode[1:0]==2'b10) begin
            wuint1[31: 0] = wuint1[31: 0] & 32'h3f3f3f3f;
            wuint1[63:32] = wuint1[63:32] & 32'h3f3f3f3f;
            ruint2[31: 0] = ruint2[31: 0] & 32'h3f3f3f3f;
            ruint2[63:32] = ruint2[63:32] & 32'h3f3f3f3f;
          end
          else if(mode[1:0]==2'b11) begin
            wuint1[31: 0] = wuint1[31: 0] & 32'h1f1f1f1f;
            wuint1[63:32] = wuint1[63:32] & 32'h1f1f1f1f;
            ruint2[31: 0] = ruint2[31: 0] & 32'h1f1f1f1f;
            ruint2[63:32] = ruint2[63:32] & 32'h1f1f1f1f;
          end
          check2 = wuint1 == ruint2;
          $write("wuint1 = %x, ruint2 = %x, check2 = %b, ", wuint1, ruint2, check2);
        end
      join $write("\n");
    end
    end
    repeat(5) @(posedge clk); setb = 1'b0;
    repeat(5) @(posedge clk); frstb = 1'b0;
    repeat(5) @(posedge clk); rstb = 1'b0;
  end
  if(check1 && check2) $write("\npass\n"); else $write("\nfail\n");
  $finish;
end

endmodule
`endif
/*
# sdc 
create_clock -name clk [get_ports clk]  -period 500  -waveform {0 250}
create_clock -name fclk [get_ports fclk]  -period 500  -waveform {0 250}
set_false_path -from [get_ports rstb]
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
set_scan_path 1 -view existing_dft -scan_enable test_se -scan_data_in test_si -scan_data_out test_so -scan_master_clock clk
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
# quartus lpuart_EP4CE10E22C8.tcl
load_package flow
project_new "ir_txer" -overwrite
set_global_assignment -name FAMILY "Cyclone IV E"
set_global_assignment -name DEVICE EP4CE10E22C8
set_global_assignment -name TOP_LEVEL_ENTITY ir_txer
set_global_assignment -name ORIGINAL_QUARTUS_VERSION 15.0.0
set_global_assignment -name PROJECT_CREATION_TIME_DATE "09:48:50  JUNE 30, 2023"
set_global_assignment -name LAST_QUARTUS_VERSION 15.0.0
set_global_assignment -name VERILOG_FILE 41.sv
set_global_assignment -name PROJECT_OUTPUT_DIRECTORY ./quartus_output_files
set_global_assignment -name DEVICE_FILTER_PIN_COUNT 484
set_global_assignment -name DEVICE_FILTER_SPEED_GRADE 8
set_global_assignment -name ERROR_CHECK_FREQUENCY_DIVISOR 256
set_global_assignment -name MIN_CORE_JUNCTION_TEMP 0
set_global_assignment -name MAX_CORE_JUNCTION_TEMP 85
set_global_assignment -name EDA_SIMULATION_TOOL VCS
set_global_assignment -name EDA_TIME_SCALE "1 ps" -section_id eda_simulation
set_global_assignment -name EDA_OUTPUT_DATA_FORMAT "VERILOG HDL" -section_id eda_simulation
set_global_assignment -name POWER_PRESET_COOLING_SOLUTION "23 MM HEAT SINK WITH 200 LFPM AIRFLOW"
set_global_assignment -name POWER_BOARD_THERMAL_MODEL "NONE (CONSERVATIVE)"
set_global_assignment -name VERILOG_SHOW_LMF_MAPPING_MESSAGES OFF
set_global_assignment -name VERILOG_MACRO "FPGA="
set_global_assignment -name STRATIX_DEVICE_IO_STANDARD "2.5 V"
set_global_assignment -name PARTITION_NETLIST_TYPE SOURCE -section_id Top
set_global_assignment -name PARTITION_FITTER_PRESERVATION_LEVEL PLACEMENT_AND_ROUTING -section_id Top
set_global_assignment -name PARTITION_COLOR 16764057 -section_id Top
set_location_assignment PIN_91 -to clk
set_location_assignment PIN_88 -to rst
set_location_assignment PIN_100 -to ir_test_protocol[0]
set_location_assignment PIN_99 -to ir_test_protocol[1]
set_location_assignment PIN_98 -to ir_test_protocol[2]
set_location_assignment PIN_51 -to tx 
set_instance_assignment -name PARTITION_HIERARCHY root_partition -to | -section_id Top
execute_flow -compile
export_assignments
project_close
#
 */
