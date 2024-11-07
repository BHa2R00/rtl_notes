`timescale 1ns/1ps


module freq_trim (
  output reg done, 
  output reg [15:0] trim, 
  input [3:0] msb, 
  input [15:0] rdiv, odiv, // odiv/rdiv=oclk/rclk 
  input setb, 
  input rstb, rclk, oclk 
);

reg [3:0] sb;
reg [15:0] rcnt, ocnt;
wire req = rcnt==16'h0;
wire oeq = ocnt==16'h0;
reg ph;
reg [1:0] rsetb_d, oph_d;
wire rsetb_0 = rsetb_d==2'b00;
wire oph_x = ^oph_d;
always@(negedge rstb or posedge rclk) begin
  if(~rstb) rsetb_d <= 2'b00;
  else rsetb_d <= {rsetb_d[0],setb};
end
always@(negedge rstb or posedge oclk) begin
  if(~rstb) oph_d <= 2'b00;
  else oph_d <= {oph_d[0],ph};
end
always@(negedge rstb or posedge rclk) begin
  if(~rstb) begin
    rcnt <= 16'h0;
    ph <= 1'b0;
  end
  else if(rsetb_0) rcnt <= rdiv;
  else if(req) begin
    if(sb!=4'h0) begin
      rcnt <= rdiv;
      ph <= ~ph;
    end
  end
  else if(~req) rcnt <= rcnt-16'h1;
end
always@(negedge rstb or posedge oclk) begin
  if(~rstb) ocnt <= 16'h0;
  else if(~setb) ocnt <= odiv;
  else if(oph_x) ocnt <= odiv;
  else if(~oeq) ocnt <= ocnt-16'h1;
end
always@(negedge rstb or posedge oclk) begin
  if(~rstb) begin
    done <= 1'b0;
    sb <= 4'h0;
  end
  else if(~setb) begin
    done <= 1'b0;
    sb <= msb;
    trim <= (1<<msb);
  end
  else if(oph_x && (~done)) begin
    if(sb==4'h0) begin
      trim[sb] <= ~oeq;
    end
    else begin
      sb <= sb-4'h1;
      trim[sb] <= ~oeq;
      trim[sb-1] <= 1'b1;
    end
  end
  else if(req && (sb==4'h0)) done <= 1'b1;
end

endmodule


`ifdef SIM
module osc8_cosim (input rstb, input [7:0] cal, output [2:0] clk);
endmodule
module osc12_cosim (input rstb, input [11:0] cal, output [2:0] clk);
endmodule
`endif


`ifdef SIM
module freq_trim_tb1;

integer clk_sel;
wire [5:0] oclkm;
wire [15:0] trim;
wire [7:0] cal8=((clk_sel>=0)&&(2>=clk_sel))? trim[7:0]:(1<<7);
wire [11:0] cal12=((clk_sel>=3)&&(5>=clk_sel))? trim[11:0]:(1<<11);
reg [15:0] trim_d;
reg rstb;

osc8_cosim u_osc8_cosim (.rstb(rstb), .cal(cal8[7:0]), .clk(oclkm[2:0]));
osc12_cosim u_osc12_cosim (.rstb(rstb), .cal(cal12[11:0]), .clk(oclkm[5:3]));
/*
bus_format [%d];
use_spice -cell osc8_cosim;
use_spice -cell osc12_cosim;
choose xa -n 61.sp -c xa.cfg -mt 16;
 */

wire done;
reg rclk;
initial rclk='b0;
always #20.833333333333337 rclk = ~rclk;
reg [15:0] rdiv, odiv;
wire [15:0] odivm[0:7];
assign odivm[0] = rdiv*8/24;
assign odivm[1] = rdiv*4/24;
assign odivm[2] = rdiv*2/24;
assign odivm[3] = rdiv*8/24;
assign odivm[4] = rdiv*4/24;
assign odivm[5] = rdiv*2/24;
reg [3:0] msb;
reg setb;

freq_trim u_req_trim (
  .done(done), 
  .trim(trim), 
  .msb(msb), 
  .rdiv(rdiv), .odiv(odivm[clk_sel]),
  .setb(setb), 
  .rstb(rstb), .rclk(rclk), .oclk(oclkm[clk_sel]) 
);

always@(negedge rstb or posedge rclk) begin
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

real rclk_time_d[0:1];
real oclk_time_d[0:1];
real rclk_period, oclk_period;
real rclk_freq, oclk_freq;

always@(negedge rstb or posedge rclk) begin
  if(~rstb) begin
    rclk_time_d[1] = $time;
    rclk_time_d[0] = $time;
  end
  else begin
    rclk_time_d[1] = rclk_time_d[0];
    rclk_time_d[0] = $time;
    rclk_period = rclk_time_d[0] - rclk_time_d[1];
    rclk_freq = 1.0/rclk_period;
  end
end

always@(negedge rstb or posedge oclkm[clk_sel]) begin
  if(~rstb) begin
    oclk_time_d[1] = $time;
    oclk_time_d[0] = $time;
  end
  else begin
    oclk_time_d[1] = oclk_time_d[0];
    oclk_time_d[0] = $time;
    oclk_period = oclk_time_d[0] - oclk_time_d[1];
    oclk_freq = 1.0/oclk_period;
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
  `endif
  clk_sel = 0;
  rstb = 0;
  setb = 0;
  rdiv = 8'd92;
  repeat(10) begin
    rdiv = $urandom_range(16'h0007,16'h00ff);
    $write("rdiv=%d, odivm[0]=%d, odivm[1]=%d, odivm[2]=%d\n",rdiv,odivm[0],odivm[1],odivm[2]);
    fork 
      begin
        repeat(100000) @(posedge rclk);
        $write("time out\n");
      end
      begin
        for(clk_sel=0;clk_sel<=2;clk_sel=clk_sel+1) begin
          #10000 rstb = 1;
          msb = 7;
          #10000 setb = 1;
          @(posedge done);
          $write("clk_sel=%x, trim done\n", clk_sel);
          #10000 setb = 0;
          #10000 rstb = 0;
        end
        for(clk_sel=3;clk_sel<=5;clk_sel=clk_sel+1) begin
          #10000 rstb = 1;
          msb = 11;
          #10000 setb = 1;
          @(posedge done);
          $write("clk_sel=%x, trim done\n", clk_sel);
          #10000 setb = 0;
          #10000 rstb = 0;
        end
      end
    join_any
  end
  $finish;
end

endmodule
`endif
