`timescale 1ns/1ps


module link0 (output full, empty, input fill, drain, rstb, syc, clk);
reg [1:0] q;
assign full = ^q;
assign empty = ~full;
wire [1:0] ck = syc ? {clk,clk} : {drain,fill};
always@(negedge rstb or posedge ck[0]) begin
  if(~rstb) q[0] <= 1'b0;
  else if(syc) begin
    if(fill) q[0] <= ~q[0];
  end
  else q[0] <= ~q[0];
end
always@(negedge rstb or posedge ck[1]) begin
  if(~rstb) q[1] <= 1'b0;
  else if(syc) begin
    if(drain) q[1] <= ~q[1];
  end
  else q[1] <= ~q[1];
end
endmodule


module link1 (output full, empty, input fill, drain, rstb, syc, clk);
reg [1:0] q;
assign full = ^q;
assign empty = ~full;
wire [1:0] ck = syc ? {clk,clk} : {drain,fill};
always@(negedge rstb or posedge ck[0]) begin
  if(~rstb) q[0] <= 1'b1;
  else if(syc) begin
    if(fill) q[0] <= ~q[0];
  end
  else q[0] <= ~q[0];
end
always@(negedge rstb or posedge ck[1]) begin
  if(~rstb) q[1] <= 1'b0;
  else if(syc) begin
    if(drain) q[1] <= ~q[1];
  end
  else q[1] <= ~q[1];
end
endmodule


module joint_dly (output o, input i);
assign #2.0 o = i;
endmodule


module joint_adly (output o, input i);
wire d;
joint_dly u_d(.o(d),.i(i));
assign o = d && i;
endmodule


module joint (input full, empty, output fire, input syc);
wire [1:0] i;
assign i[0] = full && empty;
joint_adly u_i1(.o(i[1]), .i(i[0]));
assign fire = syc ? i[0] : i[1];
endmodule


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


module clkdiv #(
  parameter INIT = 1'b0, 
  parameter MSB = 15 
)(
  output reg lck, 
  input [3:0] delay, 
  input [MSB:0] dividend, divisor, 
  input setb, 
  input rstb, clk 
);

reg [MSB:0] cnt;
always@(negedge rstb or posedge clk) begin  
  if(~rstb) begin
    cnt <= {(MSB+1){1'b0}};
    lck <= INIT;
  end
  else if(setb) begin
    if(cnt >= dividend) begin
      cnt <= cnt - dividend + divisor;
      lck <= INIT;
    end
    else begin
      cnt <= cnt + divisor;
      if(cnt >= (dividend >> 1)) lck <= ~INIT;
    end
  end
  else begin
    cnt <= (dividend >> delay);
    lck <= INIT;
  end
end

endmodule


/*module sdio (
  output [3:0] dato, 
  input [3:0] dati, 
  output datoe, 
  input oneline, 
  output reg [7:0] rchar, 
  input [7:0] wchar, 
  input clear, push, pop, 
  output reg [131:0] rrsp, 
  input [131:0] wrsp, 
  output reg [43:0] rcmd, 
  input [43:0] wcmd, 
  output cmdo, 
  input cmdi, 
  output cmdoe, 
  input even, 
  output reg sclko, 
  input sclki, 
  output reg sclkoe, 
  input [15:0] dividend, divisior, 
  input fclk, 
  input setb, 
  input rstb, clk 
);

wire sclk = sclkoe ? sclko : sclki;

endmodule*/


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
  output reg [3:0] sb, 
  output uclk, 
  input [3:0] delay, 
  input [15:0] divisor, dividend, 
  input setb, 
  input rstb, clk, frstb, fclk 
);

wire checkena = HDUART_FIFO_DMSB >= HDUART_CHECK_SB;
reg uclkena;
clkdiv #(
  .INIT(1'b0), 
  .MSB(15) 
) u_uclk (
  .lck(uclk), 
  .delay(delay), 
  .dividend(dividend), .divisor(divisor), 
  .setb(setb && uclkena), 
  .rstb(frstb), .clk(fclk) 
);
reg [1:0] uclk_d, push_d, pop_d, clear_d, even_d;
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
reg [HDUART_FIFO_DMSB:0] mem[0:((2**HDUART_FIFO_AMSB)-1)];
reg [HDUART_FIFO_AMSB:0] ma1, ma0;
assign cnt = ma1 - ma0;
assign full  = cnt >= (2**HDUART_FIFO_AMSB);
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
    else if(uclk_n) begin
      if(endena) begin
        sb <= 4'd0;
        uclkena <= 1'b0;
      end
      else sb <= sb + 4'd1;
      sb <= endena ? 4'd0 : sb + 4'd1;
    end
    else if(uclk_p && checkena && charena) bx <= bx ^ (txe ? tx : rx);
  end
  else begin
    sb <= 4'd0;
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
reg err;
always@(negedge rstb or posedge clk) begin
  if(~rstb) err <= 1'b0;
  else if(rxe && uclk_n) begin
    if(startena) err <= rx;
    else if(parityena && (~stopena)) err <= (bx != rx);
    else if(stopena) err <= ~rx;
  end
end
always@(posedge clk) begin
  if({push_p,full} == 2'b10) mem[ma1[(HDUART_FIFO_AMSB-1):0]] <= wchar;
  else if(rxe && uclk_p) begin
    if(charena) mem[ma1[(HDUART_FIFO_AMSB-1):0]][charbit] <= rx;
    else if(checkena && parityena) mem[ma1[(HDUART_FIFO_AMSB-1):0]][HDUART_CHECK_SB] <= err;
  end
end
wire [HDUART_FIFO_DMSB:0] rmask = ((1<<HDUART_CHECK_SB)|((1<<(cmsb+1))-1));
assign rchar = mem[ma0[(HDUART_FIFO_AMSB-1):0]] & rmask;
assign match = endena && (mchar == mem[ma1[(HDUART_FIFO_AMSB-1):0]]);

endmodule


module hduart_ft1 (
  output tx, uclk, 
  output reg clk2m, 
  input setb, 
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
reg push;
hduart #(
  .HDUART_CHECK_SB(9), 
  .HDUART_FIFO_AMSB(4), 
  .HDUART_FIFO_DMSB(9) 
) u_hduart (
  .startena(), .stopena(), .match(), 
  .full(), .empty(empty), 
  .cnt(), 
  .rchar(), 
  .wchar({2'b00,char}), .mchar(10'd0), 
  .pop(1'b0), .push(push), .clear(1'b0),
  .tx(tx), 
  .rx(1'b1), 
  .rxe(1'b0), .txe(1'b1), 
  .parity(1'b0), .even(1'b0), 
  .smsb(1'b0),
  .cmsb(4'd7),
  .sb(), 
  .uclk(uclk), 
  .delay(4'd0), 
  .divisor(16'h03b1), .dividend(16'h4004), 
  .setb(setb), 
  .rstb(rstb), .clk(clk), .frstb(rstb), .fclk(clk2m) 
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

endmodule


module hduart_ft2 (
  input rx, 
  output tx, 
  output uclk, 
  output reg clk2m, 
  input setb, 
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
wire empty, full;
reg [2:0] a;
wire [9:0] rchar;
wire [9:0] wchar = {2'b00,rchar};
reg fire;
hduart #(
  .HDUART_CHECK_SB(9), 
  .HDUART_FIFO_AMSB(4), 
  .HDUART_FIFO_DMSB(9) 
) u_hduart0 (
  .startena(), .stopena(), .match(), 
  .full(), .empty(empty), 
  .cnt(), 
  .rchar(), 
  .wchar(wchar), .mchar(10'd0), 
  .pop(1'b0), .push(fire), .clear(1'b0),
  .tx(tx), 
  .rx(1'b1), 
  .rxe(1'b0), .txe(1'b1), 
  .parity(1'b0), .even(1'b0), 
  .smsb(1'b0),
  .cmsb(4'd7),
  .sb(), 
  .uclk(), 
  .delay(4'd1), 
  .divisor(16'h03b1), .dividend(16'h4004), 
  .setb(setb), 
  .rstb(rstb), .clk(clk), .frstb(rstb), .fclk(clk2m) 
);
hduart #(
  .HDUART_CHECK_SB(9), 
  .HDUART_FIFO_AMSB(4), 
  .HDUART_FIFO_DMSB(9) 
) u_hduart1 (
  .startena(), .stopena(), .match(), 
  .full(full), .empty(), 
  .cnt(), 
  .rchar(rchar), 
  .wchar(10'd0), .mchar(10'd0), 
  .pop(fire), .push(1'b0), .clear(1'b0),
  .tx(), 
  .rx(rx), 
  .rxe(1'b1), .txe(1'b0), 
  .parity(1'b0), .even(1'b0), 
  .smsb(1'b0),
  .cmsb(4'd7),
  .sb(), 
  .uclk(uclk), 
  .delay(4'd1), 
  .divisor(16'h03b1), .dividend(16'h4004), 
  .setb(setb), 
  .rstb(rstb), .clk(clk), .frstb(rstb), .fclk(clk2m) 
);

always@(negedge rstb or posedge clk2m) begin
  if(~rstb) begin
    fire <= 1'b0;
  end
  else begin
    if(fire) fire <= 1'b0;
    else if(full && empty) fire <= 1'b1;
  end
end

endmodule
/*
# hduart_ft2_EP4CE10E22C8.tcl
load_package flow
project_new "hduart_ft2" -overwrite
set_global_assignment -name FAMILY "Cyclone IV E"
set_global_assignment -name DEVICE EP4CE10E22C8
set_global_assignment -name TOP_LEVEL_ENTITY hduart_ft2
set_global_assignment -name ORIGINAL_QUARTUS_VERSION 15.0.0
set_global_assignment -name PROJECT_CREATION_TIME_DATE "09:48:50  JUNE 30, 2023"
set_global_assignment -name LAST_QUARTUS_VERSION 15.0.0
set_global_assignment -name VERILOG_FILE 72.sv
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
set_location_assignment PIN_89 -to setb
set_location_assignment PIN_98 -to clk2m
set_location_assignment PIN_99 -to uclk
set_location_assignment PIN_100 -to tx
set_location_assignment PIN_103 -to rx
set_instance_assignment -name PARTITION_HIERARCHY root_partition -to | -section_id Top
execute_flow -compile
export_assignments
project_close
 */


module hduartbist #(
  parameter HDUARTBIST_AMSB = 3, 
  parameter HDUARTBIST_DMSB = 8 
)(
  output loopcheck, 
  output reg loopend, 
  input [HDUARTBIST_DMSB:0] wchar, rchar, 
  input loopback, stop, 
  input rstb, clk 
);

reg [1:0] stop_d;
always@(negedge rstb or posedge clk) begin
  if(~rstb) stop_d <= 2'b00;
  else stop_d <= {stop_d[0],stop};
end
wire stop_n = stop_d == 2'b10;
reg loopcheck1;
reg [HDUARTBIST_AMSB:0] loopcnt;
always@(negedge rstb or posedge clk) begin
  if(~rstb) begin
    loopcheck1 <= 1'b1;
    loopcnt <= 'd0;
    loopend <= 1'b0;
  end
  else if(loopback) begin
    if(stop_n) begin
      if(&loopcnt) loopend <= 1'b1;
      else begin
        loopcnt <= loopcnt + 'd1;
        loopcheck1 <= loopcheck1 && (loopcnt[0] ? rchar : ~rchar) == wchar;
      end
    end
  end
  else begin
    loopcheck1 <= 1'b1;
    loopcnt <= 'd0;
    loopend <= 1'b0;
  end
end
assign loopcheck = &{loopcnt,loopcheck1};

endmodule


module apb_hduart #(
  parameter HDUART_CHECK_SB  = 9, 
  parameter HDUART_FIFO_AMSB = 4, 
  parameter HDUART_FIFO_DMSB = 9 
)(
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
reg [1:0] trig_d;
wire trig_p = trig_d == 2'b01;
always@(negedge prstb or posedge pclk) begin
  if(~prstb) trig_d <= 2'b00;
  else trig_d <= {trig_d[0],nxt_trig};
end
wire [9:0] rchar;
reg [9:0] wchar, mchar;
wire pop  = rxe && (enadma ? dma_ack : (data_ena && penable && (~pwrite)));
wire push = txe && (enadma ? dma_ack : (data_ena && penable &&   pwrite ));
reg clear;
reg parity, even;
reg smsb;
reg [3:0] cmsb;
wire [3:0] sb;
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
reg loopback;
wire loopend, loopcheck;
hduartbist #(
  .HDUARTBIST_AMSB(HDUART_FIFO_AMSB-1), 
  .HDUARTBIST_DMSB(HDUART_FIFO_DMSB-1)
) u_hduartbist (
  .loopcheck(loopcheck), 
  .loopend(loopend), 
  .wchar(wchar[(HDUART_FIFO_DMSB-1):0]), .rchar(rchar[(HDUART_FIFO_DMSB-1):0]), 
  .loopback(loopback), .stop(stop), 
  .rstb(prstb), .clk(pclk) 
);
hduart #(
  .HDUART_CHECK_SB(HDUART_CHECK_SB), 
  .HDUART_FIFO_AMSB(HDUART_FIFO_AMSB), 
  .HDUART_FIFO_DMSB(HDUART_FIFO_DMSB) 
) u_hduart (
  .startena(start), .stopena(stop), .match(match), 
  .full(full), .empty(empty), 
  .cnt(cnt[HDUART_FIFO_AMSB:0]), 
  .rchar(rchar[HDUART_FIFO_DMSB:0]), 
  .wchar(wchar[HDUART_FIFO_DMSB:0]), .mchar(mchar[HDUART_FIFO_DMSB:0]), 
  .pop(pop), .push(push), .clear(clear),
  .tx(tx), 
  .rx(loopback ? (~tx) : rx), 
  .rxe(rxe), .txe(txe), 
  .parity(parity), .even(even), 
  .smsb(smsb),
  .cmsb(cmsb),
  .sb(sb), 
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
    prdata[4:0] = cnt[4:0];
    prdata[9:5] = th[4:0] ;
    prdata[10]  = clear   ;
    prdata[11]  = trig    ;
    prdata[12]  = empty   ;
    prdata[13]  = full    ;
    prdata[14]  = start   ;
    prdata[15]  = stop    ;
    prdata[16]  = match   ;
    prdata[17]  = enadma  ;
    // prdata[31:18] = unused2[13:0];
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
    dividend[15:0] <= 'h4004;
    divisor[15:0]  <= 'h03b1;
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
      th[4:0]  <= pwdata[9:5];
      clear    <= pwdata[10] ;
      trig     <= pwdata[11] ? 1'b0 : trig;
      enadma   <= pwdata[17] ;
    end
    if(trig_p) trig <= 1'b1;
  end
end
assign debug[3:0] = sb[3:0];
assign debug[4] = uclk;

endmodule


module link_hduart (
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
  input  paddr_fill,  pwdata_fill,  prdata_drain, 
  output paddr_empty, pwdata_empty, prdata_full, 
  input prstb, pclk, syc 
);

wire [2:0] full, empty, fill, drain;
link0 link_0 (.full(full[0]), .empty(empty[0]), .fill(fill[0]), .drain(drain[0]), .rstb(prstb), .syc(syc), .clk(pclk));
link0 link_1 (.full(full[1]), .empty(empty[1]), .fill(fill[1]), .drain(drain[1]), .rstb(prstb), .syc(syc), .clk(pclk));
link0 link_2 (.full(full[2]), .empty(empty[2]), .fill(fill[2]), .drain(drain[2]), .rstb(prstb), .syc(syc), .clk(pclk));
joint u_fire_2 (.full(full[0]||full[1]), .empty(empty[2]), .fire(fill[2]), .syc(syc));
assign fill[0]  = paddr_fill;   assign paddr_empty  = empty[0];
assign fill[1]  = pwdata_fill;  assign pwdata_empty = empty[1];
assign drain[2] = prdata_drain; assign prdata_full  = full[2];
assign drain[1:0] = {fill[2],fill[2]};
wire psel = full[0];
wire penable = full[0] && empty[2];
wire pwrite = full[1];
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
wire fifo_full, fifo_empty;
reg [4:0] th;
wire [4:0] cnt;
reg trig;
reg enadma;
wire nxt_trig = txe ? (th >= cnt) : rxe ? (cnt >= th) : 1'b0;
assign dma_req = enadma && nxt_trig;
reg [1:0] trig_d;
wire trig_p = trig_d == 2'b01;
always@(negedge prstb or posedge pclk) begin
  if(~prstb) trig_d <= 2'b00;
  else trig_d <= {trig_d[0],nxt_trig};
end
wire [9:0] rchar;
reg [9:0] wchar, mchar;
wire pop  = rxe && (enadma ? dma_ack : (data_ena && penable && (~pwrite)));
wire push = txe && (enadma ? dma_ack : (data_ena && penable &&   pwrite ));
reg clear;
reg parity, even;
reg smsb;
reg [3:0] cmsb;
wire [3:0] sb;
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
  (irqena_empty && fifo_empty)||
  (irqena_full && fifo_full)||
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
reg loopback;
wire loopend, loopcheck;
hduartbist #(
  .HDUARTBIST_AMSB(3), 
  .HDUARTBIST_DMSB(8)
) u_hduartbist (
  .loopcheck(loopcheck), 
  .loopend(loopend), 
  .wchar(wchar[8:0]), .rchar(rchar[8:0]), 
  .loopback(loopback), .stop(stop), 
  .rstb(prstb), .clk(pclk) 
);
hduart #(
  .HDUART_CHECK_SB(9), 
  .HDUART_FIFO_AMSB(4), 
  .HDUART_FIFO_DMSB(9) 
) u_hduart (
  .startena(start), .stopena(stop), .match(match), 
  .full(fifo_full), .empty(fifo_empty), 
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
  .sb(sb), 
  .uclk(uclk), 
  .delay(delay), 
  .divisor(divisor), .dividend(dividend), 
  .setb(setb), 
  .rstb(prstb), .clk(clk), .frstb(prstb_d[1]), .fclk(fclk) 
);

always@(negedge prstb or posedge fill[2]) begin
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
    prdata[10]  = fifo_empty   ;
    prdata[11]  = fifo_full    ;
    prdata[12]  = start   ;
    prdata[13]  = stop    ;
    prdata[14]  = match   ;
    prdata[15]  = enadma  ;
    // prdata[31:16] = unused2[15:0];
  end
end
always@(negedge prstb or posedge fill[1]) begin
  if(~prstb) begin //default 
    setb         = 'h0;
    txe          = 'h0;
    rxe          = 'h0;
    clk_sel      = 'h0;
    cmsb[3:0]    = 'h8;
    smsb         = 'h0;
    parity       = 'h0;
    even         = 'h0;
    irqena_trig  = 'h0;
    irqena_full  = 'h0;
    irqena_empty = 'h0;
    irqena_start = 'h0;
    irqena_stop  = 'h0;
    irqena_match = 'h0;
    delay[3:0]   = 'h0;
    dividend[15:0] = 'h4004;
    divisor[15:0]  = 'h03b1;
    wchar[9:0] = 'h0;
    mchar[9:0] = 'h0;
    th[3:0]  = 'h0;
    clear    = 'h0;
    trig     = 'h0;
    enadma   = 'h0;
    loopback   = 'h0;
  end
  else begin
    if(ctrl_ena) begin
      setb         = pwdata[0]    ;
      txe          = pwdata[1]    ;
      rxe          = pwdata[2]    ;
      clk_sel      = pwdata[3]    ;
      cmsb[3:0]    = pwdata[9:6]  ;
      smsb         = pwdata[10]   ;
      parity       = pwdata[11]   ;
      even         = pwdata[12]   ;
      irqena_trig  = pwdata[13]   ;
      irqena_full  = pwdata[14]   ;
      irqena_empty = pwdata[15]   ;
      irqena_start = pwdata[16]   ;
      irqena_stop  = pwdata[17]   ;
      irqena_match = pwdata[19]   ;
      delay[3:0]   = pwdata[22:19];
      loopback     = pwdata[23]   ;
    end
    if(baud_ena) begin
      dividend[15:0] = pwdata[15:0] ;
      divisor[15:0]  = pwdata[31:16];
    end
    if(data_ena) begin
      wchar[9:0] = pwdata[9:0]  ;
      mchar[9:0] = pwdata[19:10];
    end
    if(fifo_ena) begin
      th[3:0]  = pwdata[7:4];
      clear    = pwdata[8]  ;
      trig     = pwdata[9] ? 1'b0 : trig;
      enadma   = pwdata[15] ;
    end
    if(trig_p) trig = 1'b1;
  end
end
assign debug[3:0] = sb[3:0];
assign debug[4] = uclk;

endmodule


module apb_timer #(
  parameter LOCK = 1'b0, 
  parameter INC = 1'b1 
)(
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
wire lock = LOCK ? lr : 1'b0;
wire eq = cntr == (INC ? load_d : 0);
wire run = en && (~(halt && he));
reg [1:0] run_d, ld_d, hit_d;
wire err = es && ee;
assign irq = (is && ie) || err;
wire run_1 = run_d==2'b11;
wire ld_1 = ld_d==2'b11;
wire hit = eq && run;
wire hit_1 = hit_d==2'b11;
wire hit_p = hit_d==2'b01;

always@(negedge prstb or posedge fclk) begin
  if(~prstb) begin
    run_d <= 2'b00;
    ld_d <= 2'b00;
    load_d <= 32'd0;
  end
  else begin
    run_d <= {run_d[0],run};
    ld_d <= {ld_d[0],(ld || (eq && ~fr))};
    load_d <= load;
  end
end
always@(negedge prstb or posedge pclk) begin
  if(~prstb) begin
    hit_d <= 2'b00;
  end
  else begin
    hit_d <= {hit_d[0],hit};
  end
end
always@(negedge prstb or posedge fclk) begin
  if(~prstb) cntr <= 32'd0;
  else if(ld_1) cntr <= (INC ? 32'd0 : load_d);
  else if(run_1) cntr <= eq ? 
    (INC ? 32'd0 : load_d): 
    (INC ? (cntr + 32'd1) : (cntr - 32'd1));
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
    if(hit_p && os) en <= 1'b0;
    if(hit_p) is <= 1'b1;
    if(hit_1 && is) es <= 1'b1;
  end
end

endmodule


module iic #(
  parameter IIC_FIFO_AMSB = 3 
)(
  output reg aack, dack, 
  output full, empty, idleena, 
  input [IIC_FIFO_AMSB:0] dth,
  output [IIC_FIFO_AMSB:0] cnt,
  output [7:0] rchar, 
  input [7:0] wchar,
  input pop, push, clear,
  output reg [10:0] raddr, 
  input [10:0] waddr, 
  input addr10bit, 
  input sdai, 
  output sdaoe, sdao, 
  output sclo, 
  input master, scli, 
  input [7:0] divisor, dividend, 
  output reg [4:0] bs, 
  input setb, 
  input rstb, clk, fclk 
);

wire scl = master ? sclo : scli;
wire rw  = master ? waddr[0] : raddr[0];
wire [4:0] startbit = bs - 5'd20 - (addr10bit ? 5'd3 : 5'd0);
wire [4:0]  addrbit = bs - 5'd12;
wire [4:0]    rwbit = bs - 5'd12;
wire [4:0]  aackbit = bs - 5'd11;
wire [4:0]  databit = bs - 5'd3;
wire [4:0]  dackbit = bs - 5'd2;
wire [4:0]  stopbit = bs - 5'd1;
wire [4:0]  idlebit = bs - 5'd0;
wire  startena = ( 5'd0  == startbit);
wire   addrena = (((addr10bit ? 5'd10 : 5'd7) >=  addrbit) && ( addrbit >= 5'd0));
wire     rwena = ( 5'd0  ==    rwbit);
wire   aackena = ( 5'd0  ==  aackbit);
wire   dataena = ((5'd7  >=  databit) && ( databit >= 5'd0));
wire   dackena = ( 5'd0  ==  dackbit);
wire   stopena = ( 5'd0  ==  stopbit);
assign idleena = ( 5'd0  ==  idlebit);
reg sclena;
clkdiv #(
  .INIT(1'b1), 
  .MSB(7) 
) u_sclo (
  .lck(sclo), 
  .delay(4'd0), 
  .dividend(dividend), .divisor(divisor), 
  .setb(setb && sclena), 
  .rstb(rstb), .clk(fclk) 
);
assign sdaoe = 
  (startena||addrena||rwena||stopena) ?   master                 :
  aackena                             ? ({master,aack} == 2'b00) :
  dataena                             ?   master^rw              :
  dackena                             ? ({master,dack} == 2'b00) :
  1'b0;
reg [7:0] m[0:((2**IIC_FIFO_AMSB)-1)];
reg [IIC_FIFO_AMSB:0] ma1, ma0;
assign cnt = ma1 - ma0;
assign full = cnt == dth;
assign empty = cnt == 'h0;
assign sdao = 
  startena ? 1'b0 : 
   addrena ? waddr[addrbit[IIC_FIFO_AMSB:0]] : 
     rwena ? waddr[0] : 
   aackena ? aack : 
   dataena ? m[ma0[(IIC_FIFO_AMSB-1):0]][databit[2:0]] : 
   dackena ? dack : 
   stopena ? 1'b0 : 
  1'b1;
wire sda = sdaoe ? sdao : sdai;
reg [2:0] scl_d, sda_d;
wire scl_1 = scl_d == 3'b111;
wire scl_p = scl_d == 3'b011;
wire scl_n = scl_d == 3'b100;
wire sda_p = sda_d == 3'b011;
wire sda_n = sda_d == 3'b100;
reg [1:0] pop_d, push_d, clear_d;
wire pop_p = pop_d == 2'b01;
wire push_p = push_d == 2'b01;
wire clear_p = clear_d == 2'b01;
always@(negedge rstb or posedge clk) begin
  if(~rstb) begin
    scl_d <= 3'b111;
    sda_d <= 3'b111;
    pop_d <= 2'b11;
    push_d <= 2'b11;
    pop_d <= 2'b11;
    clear_d <= 2'b11;
  end
  else begin
    scl_d <= {scl_d[1:0],scl};
    sda_d <= {sda_d[1:0],sda};
    pop_d <= {pop_d[0],pop};
    push_d <= {push_d[0],push};
    clear_d <= {clear_d[0],clear};
  end
end
always@(negedge rstb or posedge clk) begin
  if(~rstb) begin
    bs <= 5'd0;
    aack <= 1'b1;
    dack <= 1'b1;
    raddr <= 11'd0;
    sclena <= 1'b0;
  end
  else if(setb) begin
    if(idleena) begin
      if((~master) && sda_n && scl_1) begin
        bs <= 5'd20 + (addr10bit ? 5'd3 : 5'd0);
        aack <= 1'b1;
        dack <= 1'b1;
        sclena <= 1'b0;
        raddr <= 11'd0;
      end
      else if(master && (rw ? 1'b1 : (~empty)) && scl_1) begin
        bs <= 5'd20 + (addr10bit ? 5'd3 : 5'd0);
        aack <= 1'b1;
        dack <= 1'b1;
        sclena <= 1'b1;
        raddr <= 11'd0;
      end
    end
    if(startena) begin
      if(scl_n) bs <= bs - 5'd1;
    end
    if(addrena && ~rwena) begin
      if(scl_p) raddr[addrbit[IIC_FIFO_AMSB:0]] <= sda;
      else if(scl_n) bs <= bs - 5'd1;
    end
    if(rwena) begin
      if(scl_p) raddr[0] <= sda;
      else if(scl_n) begin
        bs <= bs - 5'd1;
        if(~master) aack <= waddr[10:1] != raddr[10:1];
      end
    end
    if(aackena) begin
      if(scl_p && master) aack <= sda;
      else if(scl_n) bs <= aack ? 5'd1 : (bs - 5'd1);
    end
    if(dataena) begin
      if(scl_n) begin
        bs <= bs - 5'd1;
        if(~master && (databit == 5'd0)) dack <= (rw ? empty : full);
      end
    end
    if(dackena) begin
      if(scl_p && master) dack <= sda;
      else if(scl_n) bs <= dack ? (bs - 5'd1) : 5'd10;
    end
    if(stopena) begin
      if(scl_p) begin
        sclena <= 1'b0;
        bs <= 5'd0;
      end
    end
  end
  else bs <= 5'd0;
end
//reg [IIC_FIFO_AMSB:0] m_i;
always@(negedge rstb or posedge clk) begin
  if(~rstb) begin
    ma0 <= {(IIC_FIFO_AMSB+1){1'b0}};
    ma1 <= {(IIC_FIFO_AMSB+1){1'b0}};
    //for(m_i=0;m_i<=((2**IIC_FIFO_AMSB)-1);m_i=m_i+1) m[m_i] <= 8'd0;
  end
  else if(clear_p) begin
    ma0 <= {(IIC_FIFO_AMSB+1){1'b0}};
    ma1 <= {(IIC_FIFO_AMSB+1){1'b0}};
  end
  else if(push_p && (~full)) begin
    ma1 <= ma1 + 'd1;
    m[ma1[(IIC_FIFO_AMSB-1):0]] <= wchar;
  end
  else if(pop_p && (~empty)) ma0 <= ma0 + 'd1;
  else if(master ^ rw) begin
    if(( databit == 5'd0) && scl_n && (~empty)) ma0 <= ma0 + 'd1;
  end
  else if(master ~^ rw) begin
    if(( databit == 5'd0) && scl_n && (~full)) ma1 <= ma1 + 'd1;
    if(dataena && scl_p) m[ma1[(IIC_FIFO_AMSB-1):0]][databit[2:0]] <= sda;
  end
end
assign rchar = m[ma0[(IIC_FIFO_AMSB-1):0]];

endmodule


module apb_iic #(
  parameter IIC_FIFO_AMSB = 3 
) ( 
  output [4:0] debug, 
  output dma_req, 
  input dma_ack, 
  output irq, 
  input sdai, 
  output sdaoe, sdao, 
  output sclo, scloe, 
  input scli, 
  input fclk, 
  output reg [31:0] prdata, 
  input [31:0] pwdata, 
  input [3:0] paddr, 
  input prstb, pclk, psel, pwrite, penable 
);

reg  setb;
wire sdao0, sdaoe0;
reg  [6:0] sdao0_d, sdaoe0_d;
wire [7:0] sdao0_dn  = {sdao0_d[6:0],sdao0};
wire [7:0] sdaoe0_dn = {sdaoe0_d[6:0],sdaoe0};
reg  [2:0] setup;
assign sdao  = sdao0_dn[setup];
assign sdaoe = sdaoe0_dn[setup];
always@(negedge prstb or posedge fclk) begin
  if(~prstb) begin
    sdao0_d  <= 'h7f;
    sdaoe0_d <= 'h7f;
  end
  else begin
    sdao0_d  <= {sdao0_d[5:0],sdao0};
    sdaoe0_d <= {sdaoe0_d[5:0],sdaoe0};
  end
end
wire ctrl_ena = (paddr == 'h0) && psel;
wire cdiv_ena = (paddr == 'h4) && psel;
wire data_ena = (paddr == 'h8) && psel;
wire fifo_ena = (paddr == 'hc) && psel;
wire aack, dack;
wire full, empty;
reg [IIC_FIFO_AMSB:0] dth;
wire [IIC_FIFO_AMSB:0] cnt;
reg [3:0] th;
reg  trig, dmaena;
wire [10:0] raddr;
reg  [10:0] waddr;
wire [7:0] rchar;
reg  [7:0] wchar;
reg  clear;
reg  addr10bit;
reg  master;
assign scloe = master;
reg  [7:0] divisor, dividend;
wire [4:0] bs;
wire rw = master ? waddr[0] : raddr[0];
wire push = dmaena ? ((~rw) && dma_ack) : (data_ena && penable &&   pwrite );
wire pop  = dmaena ? (  rw  && dma_ack) : (data_ena && penable && (~pwrite));
wire idleena;
iic #(
  .IIC_FIFO_AMSB(IIC_FIFO_AMSB)
)
u_iic (
  .aack(aack), .dack(dack), 
  .full(full), .empty(empty), .idleena(idleena), 
  .dth(dth),
  .cnt(cnt),
  .rchar(rchar), 
  .wchar(wchar),
  .pop(pop), .push(push), .clear(clear),
  .raddr(raddr), 
  .waddr(waddr), 
  .addr10bit(addr10bit), 
  .sdai(sdai), 
  .sdaoe(sdaoe0), .sdao(sdao0), 
  .sclo(sclo), 
  .master(master), .scli(scli), 
  .divisor(divisor), .dividend(dividend), 
  .bs(bs), 
  .setb(setb), 
  .rstb(prstb), .clk(pclk), .fclk(fclk) 
);
reg irqena_aack, irqena_dack;
reg irqena_empty, irqena_full, irqena_trig;
assign irq = 
  (irqena_aack  && aack )||
  (irqena_dack  && dack )||
  (irqena_empty && empty)||
  (irqena_full  && full )||
  (irqena_trig  && trig );
wire nxt_trig = rw ? (cnt>=th) : (th>=cnt);
assign dma_req = dmaena && nxt_trig;
reg  [1:0] nxt_trig_d;
wire nxt_trig_p = nxt_trig_d == 2'b01;
always@(negedge prstb or posedge pclk) begin
  if(~prstb) nxt_trig_d <= 2'b00;
  else nxt_trig_d <= {nxt_trig_d[0],nxt_trig};
end
always@(*) begin
  prdata = 32'd0;
  if(ctrl_ena) begin
    prdata[0]     = setb        ;
    prdata[1]     = master      ;
    prdata[2]     = addr10bit   ;
    prdata[13:3]  = waddr[10:0] ;
    prdata[24:14] = raddr[10:0] ;
    prdata[25]    = aack        ;
    prdata[26]    = dack        ;
    prdata[27]    = irqena_aack ;
    prdata[28]    = irqena_dack ;
    prdata[29]    = irqena_empty;
    prdata[30]    = irqena_full ;
    prdata[31]    = irqena_trig ;
  end
  if(cdiv_ena) begin
    prdata[7:0]  = dividend[7:0];
    prdata[15:8] = divisor[7:0] ;
  end
  if(data_ena) begin
    // replace rchar[7:0] bchar[7:0] 
    prdata[7:0] = rchar[7:0];
    // prdata[31:8] = unused1[23:0];
  end
  if(fifo_ena) begin
    prdata[3:0]   = cnt[3:0]  ;
    prdata[7:4]   = th[3:0]   ;
    prdata[8]     = empty     ;
    prdata[9]     = full      ;
    prdata[10]    = idleena   ;
    prdata[11]    = clear     ;
    prdata[12]    = trig      ;
    prdata[13]    = dmaena    ;
    prdata[16:14] = setup[2:0];
    prdata[20:17] = dth[3:0]  ;
    // prdata[31:21] = unused0[10:0];
  end
end
always@(negedge prstb or posedge pclk) begin
  if(~prstb) begin //default 
    setb <= 'h0;
    master <= 'h0;
    addr10bit <= 'h0;
    waddr[10:0] <= 'h0;
    irqena_aack  <= 'h0;
    irqena_dack  <= 'h0;
    irqena_empty <= 'h0;
    irqena_full  <= 'h0;
    irqena_trig  <= 'h0;
    dividend[7:0] <= 'h7e;
    divisor[7:0] <= 'h0c;
    wchar[7:0] <= 'h0;
    th[3:0] <= 'h0;
    trig <= 'h0;
    dmaena <= 'h0;
    clear <= 'h0;
    trig <= 'h0;
    setup <= 'h0;
    dth <= 'h8;
  end
  else begin
    if(nxt_trig_p) trig <= 1'b1;
    if(pwrite) begin
      if(ctrl_ena) begin
        setb         <= pwdata[0]   ;
        master       <= pwdata[1]   ;
        addr10bit    <= pwdata[2]   ;
        waddr[10:0]  <= pwdata[13:3];
        irqena_aack  <= pwdata[27]  ;
        irqena_dack  <= pwdata[28]  ;
        irqena_empty <= pwdata[29]  ;
        irqena_full  <= pwdata[30]  ;
        irqena_trig  <= pwdata[31]  ;
      end
      if(cdiv_ena) begin
        dividend[7:0] <= pwdata[7:0] ;
        divisor[7:0]  <= pwdata[15:8];
      end
      if(data_ena) begin
        // replace wchar[7:0] bchar[7:0] 
        wchar[7:0]  <= pwdata[7:0] ;
      end
      if(fifo_ena) begin
        th[3:0]    <= pwdata[7:4]  ;
        clear      <= pwdata[11]   ;
        trig       <= pwdata[12] ? 'h0 : trig; // w1c
        dmaena     <= pwdata[13]   ;
        setup[2:0] <= pwdata[16:14];
        dth[3:0]   <= pwdata[20:17];
      end
    end
  end
end
assign debug[4:0] = bs[4:0];

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
reg [31:0] mem[1:31];
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
wire [31:0] xrs1 = (rs1==5'd0)? 32'd0:mem[rs1];
wire [31:0] xrs2 = (rs2==5'd0)? 32'd0:mem[rs2];
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
//reg [5:0] mem_i;
assign addr = xrs1 + imm;
always@(negedge rstb or posedge clk) begin
  if(~rstb) begin
    wdata <= 32'd0;
    enable <= 1'b0;
    pc <= 32'd0;
    //for(mem_i=0;mem_i<=31;mem_i=mem_i+1) mem[mem_i] <= 32'd0;
  end
  else if(setb && instp) begin
    if(load) begin
      enable <= 1'b1;
    end
    else if(loaded && unlock) begin
      enable <= 1'b0;
      if((rd != 5'd0) && (~i_nop)) mem[rd] <= xrd;
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
      if((rd != 5'd0) && (~i_nop)) mem[rd] <= xrd;
      if(fetch) pc <= npc;
    end
  end
  else pc <= pc0;
end

endmodule


module rv32e (
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
  output reg instreq, 
  input setb, fetch, 
  input rstb, clk 
);

assign idle = pc == pc1;
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
assign busreq = (fmtil || fmts);
assign write = fmts && grant;
assign sel = busreq && grant;
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
wire load = {sel,write,enable} == 3'b100;
wire loaded = {sel,write,enable,ready} == 4'b1011;
wire store = {sel,write,enable} == 3'b110;
wire stored = {sel,write,enable,ready} == 4'b1111;
//reg [5:0] mem_i;
assign addr = xrs1 + imm;
always@(negedge rstb or posedge clk) begin
  if(~rstb) begin
    wdata <= 32'd0;
    enable <= 1'b0;
    pc <= 32'd0;
    //for(mem_i=0;mem_i<=31;mem_i=mem_i+1) mem[mem_i] <= 32'd0;
    instreq <= 1'b0;
  end
  else if(setb) begin
    if(~idle) begin
      if(fetch && instreq) begin
        instreq <= 1'b0;
        if(instp) begin
          if(load) enable <= 1'b1;
          else if(loaded) begin
            enable <= 1'b0;
            if((rd != 5'd0) && (~i_nop)) mem[rd[3:0]] <= xrd;
            pc <= npc;
          end
          else if(store) begin
            enable <= 1'b1;
            if(i_sb) wdata[31:0] <= {rdata[31:8],xrs2[7:0]};
            else if(i_sh) wdata[31:0] <= {rdata[31:16],xrs2[15:0]};
            else if(i_sw) wdata[31:0] <= xrs2[31:0];
          end
          else if(stored) begin
            enable <= 1'b0;
            pc <= npc;
          end
          else begin
            if((rd != 5'd0) && (~i_nop)) mem[rd[3:0]] <= xrd;
            pc <= npc;
          end
        end
      end
      else instreq <= 1'b1;
    end
  end
  else begin
    pc <= pc0;
    instreq <= 1'b0;
  end
end

endmodule


module link_rv32e (
  output idle, 
  input [31:0] rdata, 
  output reg [31:0] wdata, 
  output [31:0] addr, 
  input [31:0] inst, 
  output reg [31:0] pc, 
  input [31:0] pc0, pc1, 
  input  pc0_fill,  pc_drain, inst_fill,  addr_drain, wdata_drain, rdata_fill, 
  output pc0_empty, pc_full,  inst_empty, addr_full,  wdata_full,  rdata_empty, 
  input rstb, clk, syc 
);

assign idle = pc == pc1;
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
assign addr = xrs1 + imm;
wire [5:0] full, empty, fill, drain;
link0 link_0 (.full(full[0]), .empty(empty[0]), .fill(fill[0]), .drain(drain[0]), .rstb(rstb), .syc(syc), .clk(clk));
link0 link_1 (.full(full[1]), .empty(empty[1]), .fill(fill[1]), .drain(drain[1]), .rstb(rstb), .syc(syc), .clk(clk));
link0 link_2 (.full(full[2]), .empty(empty[2]), .fill(fill[2]), .drain(drain[2]), .rstb(rstb), .syc(syc), .clk(clk));
link0 link_3 (.full(full[3]), .empty(empty[3]), .fill(fill[3]), .drain(drain[3]), .rstb(rstb), .syc(syc), .clk(clk));
link0 link_4 (.full(full[4]), .empty(empty[4]), .fill(fill[4]), .drain(drain[4]), .rstb(rstb), .syc(syc), .clk(clk));
link0 link_5 (.full(full[5]), .empty(empty[5]), .fill(fill[5]), .drain(drain[5]), .rstb(rstb), .syc(syc), .clk(clk));
assign  fill[0] =    pc0_fill;  assign   pc0_empty = empty[0];
assign drain[1] =    pc_drain;  assign     pc_full =  full[1];
assign  fill[2] =   inst_fill;  assign  inst_empty = empty[2];
assign drain[3] =  addr_drain;  assign   addr_full =  full[3];
assign drain[4] = wdata_drain;  assign  wdata_full =  full[4];
assign  fill[5] =  rdata_fill;  assign rdata_empty = empty[5];
wire exec = full[0] || ((~idle) && full[2] && (fmtil ? full[5]:1'b1));
joint u_fire_1 (.full(exec        ), .empty(empty[1]), .fire(fill[1]), .syc(syc));
joint u_fire_3 (.full(exec && fmts), .empty(empty[3]), .fire(fill[3]), .syc(syc));
joint u_fire_4 (.full(exec && fmts), .empty(empty[4]), .fire(fill[4]), .syc(syc));
assign drain[0] = fill[1]; assign drain[2] = fill[1]; assign drain[5] = fill[1];
always@(posedge fill[1]) begin
  pc <= full[0] ? pc0 : npc;
  if(full[2] && (rd != 5'd0) && (~i_nop)) mem[rd] <= xrd;
end
always@(posedge fill[4]) begin
  if(i_sb) wdata[31:0] <= {rdata[31:8],xrs2[7:0]};
  else if(i_sh) wdata[31:0] <= {rdata[31:16],xrs2[15:0]};
  else if(i_sw) wdata[31:0] <= xrs2[31:0];
end

endmodule


module rv32i (
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
  output reg instreq, 
  input setb, fetch, 
  input rstb, clk 
);

assign idle = pc == pc1;
reg [31:0] mem[1:31];
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
assign busreq = (fmtil || fmts);
assign write = fmts && grant;
assign sel = busreq && grant;
wire [31:0] xrs1 = (rs1==5'd0)? 32'd0:mem[rs1[4:0]];
wire [31:0] xrs2 = (rs2==5'd0)? 32'd0:mem[rs2[4:0]];
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
wire load = {sel,write,enable} == 3'b100;
wire loaded = {sel,write,enable,ready} == 4'b1011;
wire store = {sel,write,enable} == 3'b110;
wire stored = {sel,write,enable,ready} == 4'b1111;
//reg [5:0] mem_i;
assign addr = xrs1 + imm;
always@(negedge rstb or posedge clk) begin
  if(~rstb) begin
    wdata <= 32'd0;
    enable <= 1'b0;
    pc <= 32'd0;
    //for(mem_i=0;mem_i<=31;mem_i=mem_i+1) mem[mem_i] <= 32'd0;
    instreq <= 1'b0;
  end
  else if(setb) begin
    if(~idle) begin
      if(fetch && instreq) begin
        instreq <= 1'b0;
        if(instp) begin
          if(load) enable <= 1'b1;
          else if(loaded) begin
            enable <= 1'b0;
            if((rd[4:0] != 5'd0) && (~i_nop)) mem[rd[4:0]] <= xrd;
            pc <= npc;
          end
          else if(store) begin
            enable <= 1'b1;
            if(i_sb) wdata[31:0] <= {rdata[31:8],xrs2[7:0]};
            else if(i_sh) wdata[31:0] <= {rdata[31:16],xrs2[15:0]};
            else if(i_sw) wdata[31:0] <= xrs2[31:0];
          end
          else if(stored) begin
            enable <= 1'b0;
            pc <= npc;
          end
          else begin
            if((rd[4:0] != 5'd0) && (~i_nop)) mem[rd[4:0]] <= xrd;
            pc <= npc;
          end
        end
      end
      else instreq <= 1'b1;
    end
  end
  else begin
    pc <= pc0;
    instreq <= 1'b0;
  end
end

endmodule


`ifdef FPGA
module rom #(
  parameter AMSB = 11, 
  parameter DMSB = 31 
)(
	input	[AMSB:0]  addr,
	input	  clk,
	output	[DMSB:0]  rdata
);
parameter AMSB1 = AMSB-2;
wire [AMSB1:0] addr1 = addr[AMSB:2];
	altsyncram	altsyncram_component (
				.address_a (addr1),
				.clock0 (clk),
				.q_a (rdata),
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
				.data_a ({(AMSB+1){1'b1}}),
				.data_b (1'b1),
				.eccstatus (),
				.q_b (),
				.rden_a (1'b1),
				.rden_b (1'b1),
				.wren_a (1'b0),
				.wren_b (1'b0));
	defparam
		altsyncram_component.byte_size = 8,
		altsyncram_component.address_aclr_a = "NONE",
		altsyncram_component.clock_enable_input_a = "BYPASS",
		altsyncram_component.clock_enable_output_a = "BYPASS",
		altsyncram_component.init_file = "./altera_rom.mif",
		altsyncram_component.intended_device_family = "Cyclone IV E",
		altsyncram_component.lpm_hint = "ENABLE_RUNTIME_MOD=NO",
		altsyncram_component.lpm_type = "altsyncram",
		//altsyncram_component.numwords_a = (1<<(AMSB-1)),
		altsyncram_component.operation_mode = "ROM",
		altsyncram_component.outdata_aclr_a = "NONE",
		altsyncram_component.outdata_reg_a = "CLOCK0",
		altsyncram_component.widthad_a = (AMSB1+1),
		altsyncram_component.width_a = (DMSB+1),
		altsyncram_component.width_byteena_a = 1;
endmodule
module ram #(
  parameter AMSB = 7, 
  parameter DMSB = 31 
)(
	input	[DMSB:0]  wdata,
  input write,
	input	[AMSB:0]  addr,
	input	  clk,
	output	[DMSB:0]  rdata
);
parameter AMSB1 = AMSB-2;
wire [AMSB1:0] addr1 = addr[AMSB:2];
	altsyncram	altsyncram_component (
				.address_a (addr1),
				.clock0 (clk),
				.q_a (rdata),
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
				.data_a (wdata),
				.data_b (1'b1),
				.eccstatus (),
				.q_b (),
				.rden_a (1'b1),
				.rden_b (1'b1),
				.wren_a (~write),
				.wren_b (1'b0));
	defparam
		//altsyncram_component.byte_size = 8,
		altsyncram_component.clock_enable_input_a = "BYPASS",
		altsyncram_component.clock_enable_output_a = "BYPASS",
		//altsyncram_component.init_file = "./altera_ram.mif",
		altsyncram_component.intended_device_family = "Cyclone IV E",
		altsyncram_component.lpm_hint = "ENABLE_RUNTIME_MOD=NO",
		altsyncram_component.lpm_type = "altsyncram",
		//altsyncram_component.numwords_a = (1<<(AMSB-1)),
		altsyncram_component.operation_mode = "SINGLE_PORT",
		altsyncram_component.outdata_aclr_a = "NONE",
		altsyncram_component.outdata_reg_a = "CLOCK0",
		altsyncram_component.power_up_uninitialized = "FALSE",
		altsyncram_component.read_during_write_mode_port_a = "DONT_CARE",
		altsyncram_component.widthad_a = (AMSB1+1),
		altsyncram_component.width_a = (DMSB+1),
		altsyncram_component.width_byteena_a = 1;
endmodule
`endif


`ifdef SIM
module rom #(
  parameter AMSB = 11, 
  parameter DMSB = 31 
)(
	input	[AMSB:0]  addr,
	input	  clk,
	output	reg [DMSB:0]  rdata
);
reg [7:0] mem[0:((1<<(AMSB+1))-1)];
always@(posedge clk) begin
  rdata[7:0] <= mem[addr];
  rdata[15:8] <= mem[addr+1];
  rdata[23:16] <= mem[addr+2];
  rdata[31:24] <= mem[addr+3];
end
endmodule
module link_rom #(
  parameter AMSB = 11, 
  parameter DMSB = 31 
)(
  output empty_addr, full_rdata, 
  input fill_addr, drain_rdata, 
  input rstb, 
	input	[AMSB:0]  addr,
	input	  clk,
	output	reg [DMSB:0]  rdata
);
reg [7:0] mem[0:((1<<(AMSB+1))-1)];
always@(posedge clk) begin
  rdata[7:0] <= mem[addr];
  rdata[15:8] <= mem[addr+1];
  rdata[23:16] <= mem[addr+2];
  rdata[31:24] <= mem[addr+3];
end
endmodule
module ram #(
  parameter AMSB = 7, 
  parameter DMSB = 31 
)(
	input	[DMSB:0]  wdata,
  input write, 
	input	[AMSB:0]  addr,
	input	  clk,
	output	[DMSB:0]  rdata
);
reg [7:0] mem[0:((1<<(AMSB+1))-1)];
assign rdata[7:0] = mem[addr];
assign rdata[15:8] = mem[addr+1];
assign rdata[23:16] = mem[addr+2];
assign rdata[31:24] = mem[addr+3];
always@(posedge clk) begin
  if(write) begin
    mem[addr] <= wdata[7:0];
    mem[addr+1] <= wdata[15:8];
    mem[addr+2] <= wdata[23:16];
    mem[addr+3] <= wdata[31:24];
   end
end
endmodule
`endif


module ft1(
  output [2:0] sdao, sdaoe, 
  output [2:0] sclo, scloe, 
  input [2:0] scli, sdai, 
  output [2:0] tx, 
  input [2:0] rx, 
  output idle, 
  input setb,
  input rst, clk 
);

wire rstb = ~rst;
wire [3:0] fclk;
reg [15:0] dividend[0:3];
reg [15:0] divisor[0:3];
clkdiv #(.INIT(1'b0), .MSB(15)) u_fclk0 (
  .lck(fclk[0]), 
  .delay(4'd0), .dividend(dividend[0]), .divisor(divisor[0]), 
  .setb(setb), .rstb(rstb), .clk(clk)
);
clkdiv #(.INIT(1'b0), .MSB(15)) u_fclk1 (
  .lck(fclk[1]), 
  .delay(4'd0), .dividend(dividend[1]), .divisor(divisor[1]), 
  .setb(setb), .rstb(rstb), .clk(clk)
);
clkdiv #(.INIT(1'b0), .MSB(15)) u_fclk2 (
  .lck(fclk[2]), 
  .delay(4'd0), .dividend(dividend[2]), .divisor(divisor[2]), 
  .setb(setb), .rstb(rstb), .clk(clk)
);
clkdiv #(.INIT(1'b0), .MSB(15)) u_fclk3 (
  .lck(fclk[3]), 
  .delay(4'd0), .dividend(dividend[3]), .divisor(divisor[3]), 
  .setb(setb), .rstb(rstb), .clk(clk)
);

wire prstb = rstb;
wire pclk = clk;
wire psel, pwrite, penable;
wire [31:0] paddr;
wire [31:0] pwdata;

`define RAM_A0                  'h0000
`define RAM_A1         (`RAM_A0+'h0fff)
`define APB_A0                  'h1000
`define APB_HDUART0_A0 (`APB_A0+'h0000)
`define APB_HDUART0_A1 (`APB_A0+'h000f)
`define APB_HDUART1_A0 (`APB_A0+'h0100)
`define APB_HDUART1_A1 (`APB_A0+'h010f)
`define APB_HDUART2_A0 (`APB_A0+'h0200)
`define APB_HDUART2_A1 (`APB_A0+'h020f)
`define APB_TIMER0_A0  (`APB_A0+'h0300)
`define APB_TIMER0_A1  (`APB_A0+'h0307)
`define APB_TIMER1_A0  (`APB_A0+'h0400)
`define APB_TIMER1_A1  (`APB_A0+'h0407)
`define APB_TIMER2_A0  (`APB_A0+'h0500)
`define APB_TIMER2_A1  (`APB_A0+'h0507)
`define APB_IIC0_A0    (`APB_A0+'h0600)
`define APB_IIC0_A1    (`APB_A0+'h060f)
`define APB_IIC1_A0    (`APB_A0+'h0700)
`define APB_IIC1_A1    (`APB_A0+'h070f)
`define APB_IIC2_A0    (`APB_A0+'h0800)
`define APB_IIC2_A1    (`APB_A0+'h080f)
`define APB_SYS_A0     (`APB_A0+'h0900)
`define APB_SYS_A1     (`APB_A0+'h09ff)

wire [31:0] paddr_hduart0 = paddr - `APB_HDUART0_A0;
wire psel_hduart0 = psel && (`APB_HDUART0_A1 >= paddr) && (paddr >= `APB_HDUART0_A0);
wire [31:0] prdata_hduart0;
apb_hduart #(
  .HDUART_CHECK_SB  ( 9), 
  .HDUART_FIFO_AMSB ( 3), 
  .HDUART_FIFO_DMSB ( 9) 
) u_apb_hduart0 (
  .debug(), 
  .irq(), 
  .dma_req(), 
  .dma_ack(), 
  .tx(tx[0]), 
  .rx(rx[0]), 
  .rxe(), .txe(), 
  .fclk(fclk[3]), 
  .prdata(prdata_hduart0), 
  .pwdata(pwdata), 
  .paddr(paddr_hduart0[3:0]), 
  .prstb(prstb), .pclk(pclk), .psel(psel_hduart0), .pwrite(pwrite), .penable(penable)
);

wire [31:0] paddr_hduart1 = paddr - `APB_HDUART1_A0;
wire psel_hduart1 = psel && (`APB_HDUART1_A1 >= paddr) && (paddr >= `APB_HDUART1_A0);
wire [31:0] prdata_hduart1;
apb_hduart #(
  .HDUART_CHECK_SB  ( 9), 
  .HDUART_FIFO_AMSB ( 3), 
  .HDUART_FIFO_DMSB ( 9) 
) u_apb_hduart1 (
  .debug(), 
  .irq(), 
  .dma_req(), 
  .dma_ack(), 
  .tx(tx[1]), 
  .rx(rx[1]), 
  .rxe(), .txe(), 
  .fclk(fclk[3]), 
  .prdata(prdata_hduart1), 
  .pwdata(pwdata), 
  .paddr(paddr_hduart1[3:0]), 
  .prstb(prstb), .pclk(pclk), .psel(psel_hduart1), .pwrite(pwrite), .penable(penable)
);

wire [31:0] paddr_hduart2 = paddr - `APB_HDUART2_A0;
wire psel_hduart2 = psel && (`APB_HDUART2_A1 >= paddr) && (paddr >= `APB_HDUART2_A0);
wire [31:0] prdata_hduart2;
apb_hduart #(
  .HDUART_CHECK_SB  ( 9), 
  .HDUART_FIFO_AMSB ( 3), 
  .HDUART_FIFO_DMSB ( 9) 
) u_apb_hduart2 (
  .debug(), 
  .irq(), 
  .dma_req(), 
  .dma_ack(), 
  .tx(tx[2]), 
  .rx(rx[2]), 
  .rxe(), .txe(), 
  .fclk(fclk[3]), 
  .prdata(prdata_hduart2), 
  .pwdata(pwdata), 
  .paddr(paddr_hduart2[3:0]), 
  .prstb(prstb), .pclk(pclk), .psel(psel_hduart2), .pwrite(pwrite), .penable(penable)
);

wire [31:0] paddr_timer0 = paddr - `APB_TIMER0_A0;
wire psel_timer0 = psel && (`APB_TIMER0_A1 >= paddr) && (paddr >= `APB_TIMER0_A0);
wire [31:0] prdata_timer0;
apb_timer #(
  .LOCK(1'b0), 
  .INC(1'b1) 
) u_apb_timer0 (
  .irq(), 
  .halt(1'b0), 
  .fclk(fclk[0]), 
  .prdata(prdata_timer0), 
  .pwdata(pwdata), 
  .paddr(paddr_timer0[2:0]), 
  .psel(psel_timer0), .pwrite(pwrite), .penable(penable), 
  .prstb(prstb), .pclk(pclk) 
);

wire [31:0] paddr_timer1 = paddr - `APB_TIMER1_A0;
wire psel_timer1 = psel && (`APB_TIMER1_A1 >= paddr) && (paddr >= `APB_TIMER1_A0);
wire [31:0] prdata_timer1;
apb_timer #(
  .LOCK(1'b0), 
  .INC(1'b1) 
) u_apb_timer1 (
  .irq(), 
  .halt(1'b0), 
  .fclk(fclk[1]), 
  .prdata(prdata_timer1), 
  .pwdata(pwdata), 
  .paddr(paddr_timer1[2:0]), 
  .psel(psel_timer1), .pwrite(pwrite), .penable(penable), 
  .prstb(prstb), .pclk(pclk) 
);

wire [31:0] paddr_timer2 = paddr - `APB_TIMER2_A0;
wire psel_timer2 = psel && (`APB_TIMER2_A1 >= paddr) && (paddr >= `APB_TIMER2_A0);
wire [31:0] prdata_timer2;
apb_timer #(
  .LOCK(1'b0), 
  .INC(1'b1) 
) u_apb_timer2 (
  .irq(), 
  .halt(1'b0), 
  .fclk(fclk[2]), 
  .prdata(prdata_timer2), 
  .pwdata(pwdata), 
  .paddr(paddr_timer2[2:0]), 
  .psel(psel_timer2), .pwrite(pwrite), .penable(penable), 
  .prstb(prstb), .pclk(pclk) 
);

wire [31:0] paddr_iic0 = paddr - `APB_IIC0_A0;
wire psel_iic0 = psel && (`APB_IIC0_A1 >= paddr) && (paddr >= `APB_IIC0_A0);
wire [31:0] prdata_iic0;
apb_iic #(
  .IIC_FIFO_AMSB(3)
)
u_apb_iic0 (
  .debug(), 
  .dma_req(), 
  .dma_ack(1'b0), 
  .irq(), 
  .sdai(sdai[0]), 
  .sdaoe(sdaoe[0]), .sdao(sdao[0]), 
  .sclo(sclo[0]), .scloe(scloe[0]), 
  .scli(scli[0]), 
  .fclk(fclk[3]), 
  .prdata(prdata_iic0), 
  .pwdata(pwdata), 
  .paddr(paddr_iic0[3:0]), 
  .prstb(prstb), .pclk(pclk), .psel(psel_iic0), .pwrite(pwrite), .penable(penable) 
);

wire [31:0] paddr_iic1 = paddr - `APB_IIC1_A0;
wire psel_iic1 = psel && (`APB_IIC1_A1 >= paddr) && (paddr >= `APB_IIC1_A0);
wire [31:0] prdata_iic1;
apb_iic #(
  .IIC_FIFO_AMSB(3)
)
u_apb_iic1 (
  .debug(), 
  .dma_req(), 
  .dma_ack(1'b0), 
  .irq(), 
  .sdai(sdai[1]), 
  .sdaoe(sdaoe[1]), .sdao(sdao[1]), 
  .sclo(sclo[1]), .scloe(scloe[1]), 
  .scli(scli[1]), 
  .fclk(fclk[3]), 
  .prdata(prdata_iic1), 
  .pwdata(pwdata), 
  .paddr(paddr_iic1[3:0]), 
  .prstb(prstb), .pclk(pclk), .psel(psel_iic1), .pwrite(pwrite), .penable(penable) 
);

wire [31:0] paddr_iic2 = paddr - `APB_IIC2_A0;
wire psel_iic2 = psel && (`APB_IIC2_A1 >= paddr) && (paddr >= `APB_IIC2_A0);
wire [31:0] prdata_iic2;
apb_iic #(
  .IIC_FIFO_AMSB(3)
) 
u_apb_iic2 (
  .debug(), 
  .dma_req(), 
  .dma_ack(1'b0), 
  .irq(), 
  .sdai(sdai[2]), 
  .sdaoe(sdaoe[2]), .sdao(sdao[2]), 
  .sclo(sclo[2]), .scloe(scloe[2]), 
  .scli(scli[2]), 
  .fclk(fclk[3]), 
  .prdata(prdata_iic2), 
  .pwdata(pwdata), 
  .paddr(paddr_iic2[3:0]), 
  .prstb(prstb), .pclk(pclk), .psel(psel_iic2), .pwrite(pwrite), .penable(penable) 
);

wire [31:0] paddr_sys = paddr - `APB_SYS_A0;
wire psel_sys = psel && (`APB_SYS_A1 >= paddr) && (paddr >= `APB_SYS_A0);
reg [31:0] prdata_sys;
wire syscdiv0_ena = (paddr_sys == 'h0) && psel_sys;
wire syscdiv1_ena = (paddr_sys == 'h4) && psel_sys;
wire syscdiv2_ena = (paddr_sys == 'h8) && psel_sys;
wire syscdiv3_ena = (paddr_sys == 'hc) && psel_sys;
always@(*) begin
  if(syscdiv0_ena) begin
    prdata_sys[15:00] = dividend[0][15:0]; 
    prdata_sys[31:16] = divisor[0][15:0];
  end
  if(syscdiv1_ena) begin
    prdata_sys[15:00] = dividend[1][15:0]; 
    prdata_sys[31:16] = divisor[1][15:0];
  end
  if(syscdiv2_ena) begin
    prdata_sys[15:00] = dividend[2][15:0]; 
    prdata_sys[31:16] = divisor[2][15:0];
  end
  if(syscdiv3_ena) begin
    prdata_sys[15:00] = dividend[3][15:0]; 
    prdata_sys[31:16] = divisor[3][15:0];
  end
end
always@(negedge prstb or posedge pclk) begin
  if(~prstb) begin
    dividend[0] <= 16'd50000;
    divisor[0] <= 16'd32;
    dividend[1] <= 16'd50000;
    divisor[1] <= 16'd512;
    dividend[2] <= 16'd50;
    divisor[2] <= 16'd1;
    dividend[3] <= 16'd50;
    divisor[3] <= 16'd2;
  end
  else if(pwrite && penable) begin
    if(syscdiv0_ena) begin
      dividend[0][15:0] <= pwdata[15:00];
      divisor[0][15:0]  <= pwdata[31:16];
    end
    if(syscdiv1_ena) begin
      dividend[1][15:0] <= pwdata[15:00];
      divisor[1][15:0]  <= pwdata[31:16];
    end
    if(syscdiv2_ena) begin
      dividend[2][15:0] <= pwdata[15:00];
      divisor[2][15:0]  <= pwdata[31:16];
    end
    if(syscdiv3_ena) begin
      dividend[3][15:0] <= pwdata[15:00];
      divisor[3][15:0]  <= pwdata[31:16];
    end
  end
end

wire instreq;
wire [31:0] pc, inst;
rom #(.AMSB(11), .DMSB(31)) u_rom0(.addr(pc[11:0]), .clk(pclk), .rdata(inst));

reg [31:0] ram[0:(`RAM_A1>>2)];
wire [31:0] paddr_ram = paddr - `RAM_A0;
wire [31:0] prdata_ram;
wire psel_ram = psel && (`RAM_A1 >= paddr_ram) && (paddr_ram >= `RAM_A0);
ram #(
  .AMSB(11), 
  .DMSB(31) 
) u_ram0(
	.wdata(pwdata),
  .write(pwrite), 
	.addr(paddr_ram[11:0]),
	.clk(pclk),
	.rdata(prdata_ram)
);

wire busreq;
wire grant = busreq;
wire [31:0] prdata =
  psel_iic0 ? prdata_iic0 : 
  psel_iic1 ? prdata_iic1 : 
  psel_iic2 ? prdata_iic2 : 
  psel_timer0 ? prdata_timer0 : 
  psel_timer1 ? prdata_timer1 : 
  psel_timer2 ? prdata_timer2 : 
  psel_hduart0 ? prdata_hduart0 : 
  psel_hduart1 ? prdata_hduart1 : 
  psel_hduart2 ? prdata_hduart2 : 
  prdata_ram;
reg pready;
reg [1:0]fetch;
always@(negedge prstb or posedge pclk) if(~prstb) pready <= 1'b0; else pready <= penable;
always@(negedge prstb or posedge pclk) if(~prstb) fetch <= 2'b00; else fetch <= {fetch[0],instreq};
rv32e u_cpu0 (
  .rdata(prdata), 
  .wdata(pwdata), 
  .write(pwrite), .sel(psel), .enable(penable), .busreq(busreq), 
  .ready(1'b1), .grant(grant), 
  .addr(paddr), 
  .idle(idle), 
  .inst(inst), 
  .pc(pc), 
  .pc0(32'h0), .pc1(32'h8), 
  .instreq(instreq),
  .setb(setb), .fetch(&fetch[1:0]), 
  .rstb(prstb), .clk(pclk) 
);

endmodule


`ifdef SIM
module ft1_tb1;

reg rst, clk, setb;
wire idle;

wire [2:0] tx, rx;
assign rx[0] = tx[1];
assign rx[1] = tx[2];
assign rx[2] = tx[0];

supply1 vcc;
supply0 gnd;
tri sda, scl;
wire [2:0] sdaoe, scloe;
wire [2:0] sdao, sclo;
pullup u_pu_sda (sda);
pullup u_pu_scl (scl);
nmos u_pd_sda0 (sda,gnd,(sdaoe[0]&&(~sdao[0])));
nmos u_pd_sda1 (sda,gnd,(sdaoe[1]&&(~sdao[1])));
nmos u_pd_sda2 (sda,gnd,(sdaoe[2]&&(~sdao[2])));
nmos u_pd_scl0 (scl,gnd,(scloe[0]&&(~sclo[0])));
nmos u_pd_scl1 (scl,gnd,(scloe[1]&&(~sclo[1])));
nmos u_pd_scl2 (scl,gnd,(scloe[2]&&(~sclo[2])));

ft1 u_ft1 (
  .sdao(sdao), .sdaoe(sdaoe), 
  .sclo(sclo), .scloe(scloe), 
  .scli({scl,scl,scl}), .sdai({sda,sda,sda}), 
  .tx(tx), 
  .rx(rx), 
  .idle(idle), 
  .setb(setb),
  .rst(rst), .clk(clk)
);

reg [31:0] pc0, pc1;

integer fp;
task load_rom;
  begin
    $write("load_rom from 72.bin\n");
/*
riscv32-unknown-elf-gcc -march=rv32e -mabi=ilp32e -nostartfiles -mno-relax -O4 -c 72.c -g -o 72.o
riscv32-unknown-elf-ld -T 72.ld -o 72.elf 72.o
riscv32-unknown-elf-objcopy -O binary 72.elf 72.bin
riscv32-unknown-elf-objdump -S 72.o
 */
    fp = $fopen("72.bin","rb");
    pc0='h0;
    for(pc1=pc0;pc1<=('hfff-pc0);pc1=pc1+1) u_ft1.u_rom0.mem[pc1] = 8'd0;
    pc1 = pc0;
    while(!$feof(fp)) begin
      u_ft1.u_rom0.mem[pc1] = $fgetc(fp);
      pc1=pc1+1;
    end
    pc1 = pc1-1;
    $fclose(fp);
    $write("done pc1=%x\n",pc1);
  end
endtask

always #20 clk = ~clk;
//integer ram_i;

always@(posedge u_ft1.u_apb_timer0.hit) $write("%d ns: timer0.hit\n",$time);
always@(posedge u_ft1.u_apb_timer1.hit) $write("%d ns: timer1.hit\n",$time);
always@(posedge u_ft1.u_apb_timer2.hit) $write("%d ns: timer2.hit\n",$time);
always@(posedge u_ft1.u_apb_timer0.en) $write("%d ns: timer0.en\n",$time);
always@(posedge u_ft1.u_apb_timer1.en) $write("%d ns: timer1.en\n",$time);
always@(posedge u_ft1.u_apb_timer2.en) $write("%d ns: timer2.en\n",$time);
always@(posedge u_ft1.u_apb_hduart0.setb) $write("%d ns: hduart0.setb\n",$time);
always@(posedge u_ft1.u_apb_hduart1.setb) $write("%d ns: hduart1.setb\n",$time);
always@(posedge u_ft1.u_apb_hduart2.setb) $write("%d ns: hduart2.setb\n",$time);
always@(posedge u_ft1.u_apb_iic0.setb) $write("%d ns: iic0.setb\n",$time);
always@(posedge u_ft1.u_apb_iic1.setb) $write("%d ns: iic1.setb\n",$time);
always@(posedge u_ft1.u_apb_iic2.setb) $write("%d ns: iic2.setb\n",$time);

initial begin
  `ifdef FST
  $dumpfile("a.fst");
  $dumpvars(0,ft1_tb1);
  `endif
  `ifdef FSDB
  $fsdbDumpfile("a.fsdb");
  $fsdbDumpvars(0,ft1_tb1);
  `endif
  clk = 0;
  rst = 1;
  setb = 0;
  repeat(2) begin
    //for(ram_i=0;ram_i<='h3f;ram_i=ram_i+1) u_ft1.u_ram.mem[ram_i] <= 32'd0;
    load_rom;
    #100 @(posedge clk); rst = 0;
    repeat(3) @(posedge clk); setb = 1;
    @(posedge idle);
    repeat(1) @(posedge clk); setb = 0;
    #100 rst = 1;
  end
  $finish;
end

endmodule
`endif
