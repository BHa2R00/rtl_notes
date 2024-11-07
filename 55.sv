`timescale 1ns/1ps


`ifdef SIM
module osc8_cosim (input rstb, input [7:0] cal, output [2:0] clk);
endmodule
`endif


module freq_trim (
  output reg trim_done, 
  output reg [15:0] trim, 
  input [3:0] from_msb, 
  input setb, 
  input [15:0] ref_cnt, 
  input [7:0] ref_div, 
  input rstb, osc_clk, ref_clk 
);

reg [1:0] osc_rstb_d;
wire osc_rstb = osc_rstb_d[1];
reg [2:0] refclk_d;
wire refclk_1 = refclk_d[2];
wire refclk_n = refclk_d[2:1] == 2'b10;
reg refclk;
reg [15:0] osc_cnt;
wire sign = osc_cnt == ref_cnt;
reg [15:0] num_cnt;
reg [7:0] rcnt, ref_div_d;

always@(negedge rstb or posedge osc_clk) begin
  if(~rstb) begin
    osc_rstb_d <= 2'b00;
    trim_done <= 1'b0;
  end
  else if(~setb) begin
    osc_rstb_d <= 2'b00;
    trim_done <= 1'b0;
  end
  else begin
    osc_rstb_d <= {osc_rstb_d[0],1'b1};
    if(num_cnt[0]&&refclk_n) trim_done <= 1'b1;
  end
end

always@(negedge rstb or posedge ref_clk) begin
  if(~rstb) begin
    refclk <= 1'b0;
    rcnt <= 8'h0;
    ref_div_d <= 8'h0;
  end
  else if(~setb) begin
    refclk <= 1'b0;
    ref_div_d <= ref_div;
  end
  else if(~trim_done) begin
    if(rcnt == 8'h0) begin
      refclk <= ~refclk;
      rcnt <= ref_div_d;
    end
    else rcnt <= rcnt - 8'h1;
  end
end

always@(negedge rstb or posedge osc_clk) begin
  if(~rstb) begin
    refclk_d <= 3'b000;
    osc_cnt <= 16'd0;
    num_cnt <= {1'b1,15'd0};
    trim <= {1'b1,15'd0};
  end
  else if(~setb) begin
    refclk_d <= 3'b000;
    osc_cnt <= 16'd0;
    num_cnt <= (1<<from_msb);
    trim <= (1<<from_msb);
  end
  else if(~trim_done) begin
    refclk_d <= {refclk_d[1:0],refclk};
    if(~refclk_1) osc_cnt <= 16'd0;
    else if(~sign) osc_cnt <= osc_cnt + 16'd1;
    if(refclk_n) begin
      num_cnt <= {1'b0,num_cnt[15:1]};
      case(1'b1)
        num_cnt[15]: trim[15:14] <= {~sign,1'b1};
        num_cnt[14]: trim[14:13] <= {~sign,1'b1};
        num_cnt[13]: trim[13:12] <= {~sign,1'b1};
        num_cnt[12]: trim[12:11] <= {~sign,1'b1};
        num_cnt[11]: trim[11:10] <= {~sign,1'b1};
        num_cnt[10]: trim[10: 9] <= {~sign,1'b1};
        num_cnt[ 9]: trim[ 9: 8] <= {~sign,1'b1};
        num_cnt[ 8]: trim[ 8: 7] <= {~sign,1'b1};
        num_cnt[ 7]: trim[ 7: 6] <= {~sign,1'b1};
        num_cnt[ 6]: trim[ 6: 5] <= {~sign,1'b1};
        num_cnt[ 5]: trim[ 5: 4] <= {~sign,1'b1};
        num_cnt[ 4]: trim[ 4: 3] <= {~sign,1'b1};
        num_cnt[ 3]: trim[ 3: 2] <= {~sign,1'b1};
        num_cnt[ 2]: trim[ 2: 1] <= {~sign,1'b1};
        num_cnt[ 1]: trim[ 1: 0] <= {~sign,1'b1};
        num_cnt[ 0]: trim[ 0]    <= ~sign;
      endcase
    end
  end
end

endmodule


`ifdef SIM
module freq_trim_tb1;

integer clk_sel;
wire [2:0] osc_clk;
wire [15:0] trim;
wire [7:0] cal8=trim[7:0];
reg [15:0] trim_d;
reg rstb;

osc8_cosim u_osc8_cosim (.rstb(rstb), .cal(cal8[7:0]), .clk(osc_clk[2:0]));
/*
bus_format [%d];
use_spice -cell osc8_cosim;
choose xa -n 55.sp -c xa.cfg -mt 16;
 */

wire trim_done;
reg ref_clk;
initial ref_clk='b0;
always #20.833333333333337 ref_clk = ~ref_clk;
reg [7:0] ref_div;
wire [15:0] ref_cnt[0:7];
assign ref_cnt[0] = (8000000/2)/(24000000/(2*ref_div));
assign ref_cnt[1] = (4000000/2)/(24000000/(2*ref_div));
assign ref_cnt[2] = (2000000/2)/(24000000/(2*ref_div));
reg [3:0] from_msb;
reg setb;

freq_trim u_req_trim_osc (
  .trim_done(trim_done), 
  .trim(trim), 
  .from_msb(from_msb), 
  .setb(setb), 
  .ref_cnt(ref_cnt[clk_sel]), 
  .ref_div(ref_div),
  .rstb(rstb), 
  .osc_clk(osc_clk[clk_sel]), 
  .ref_clk(ref_clk[clk_sel]) 
);

always@(negedge rstb or posedge ref_clk) begin
  if(~rstb) begin
    trim_d = trim;
  end
  else begin
    if(trim_d!=trim) begin
      trim_d = trim;
      $write("trim=%x\n", trim);
    end
  end
end

initial begin
  `ifdef FST
  $dumpfile("a.fst");
  $dumpvars(0,freq_trim_tb1);
  `endif
  `ifdef FSDB
  $fsdbDumpfile("a.fsdb");
  $fsdbDumpvars(0,freq_trim_tb1);
  clk_sel = 0;
  rstb = 0;
  setb = 0;
  ref_div = 8'd92;
  repeat(2) begin
  ref_div = $urandom_range(8'h0f,8'hef);
  $write("ref_div=%d, ref_cnt[0]=%d, ref_cnt[1]=%d, ref_cnt[2]=%d\n",ref_div,ref_cnt[0],ref_cnt[1],ref_cnt[2]);
  fork 
    begin
      repeat(100000) @(posedge ref_clk);
      $write("time out\n");
    end
    for(clk_sel=0;clk_sel<=2;clk_sel=clk_sel+1) begin
      #10000 rstb = 1;
      from_msb = 7;
      #10000 setb = 1;
      @(posedge trim_done);
      $write("clk_sel=%x, trim done\n", clk_sel);
      #10000 setb = 0;
      #10000 rstb = 0;
    end
  join_any
  end
  `endif
  $finish;
end

endmodule
`endif
