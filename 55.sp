*lib
.temp 25
.model n12ll nmos level=54 vth0=0.5  k1=0.48 dvt0=3.8  u0=0.016 vsat=8.8e4
.model p12ll pmos level=54 vth0=-0.5 k1=0.48 dvt0=0.25 u0=0.008 vsat=8.7e4
*mn d g s b n12ll l=60n w=130n
*mp d g s b p12ll l=60n w=150n

*cdl
*.subckt invx0 i o vcc gnd vccnw 
*mn0 o i gnd gnd   n12ll l=1u w=130n
*mp0 o i vcc vccnw p12ll l=1u w=150n
*.ends

.subckt invx1 i o vcc gnd vccnw 
mn0 o i gnd gnd   n12ll l=60n w=130n
mp0 o i vcc vccnw p12ll l=60n w=150n
.ends

.subckt schmittx1 i o vcc gnd vccnw 
mn0 o    ob gnd  gnd   n12ll l=60n w=130n
mp0 o    ob vcc  vccnw p12ll l=60n w=150n
mn1 vcc  ob net1 gnd   n12ll l=60n w=130n
mp1 gnd  ob net2 vccnw p12ll l=60n w=150n
mn2 ob   i  net1 gnd   n12ll l=60n w=130n
mp2 ob   i  net2 vccnw p12ll l=60n w=150n
mn3 net1 i  gnd  gnd   n12ll l=60n w=130n
mp3 net2 i  vcc  vccnw p12ll l=60n w=150n
.ends

.subckt nand2x1 i1 i2 o vcc gnd vccnw 
mn0 net1 i2 gnd  gnd   n12ll l=60n w=260n
mn1 o    i1 net1 gnd   n12ll l=60n w=260n
mp0 o    i1 vcc  vccnw p12ll l=60n w=150n
mp1 o    i2 vcc  vccnw p12ll l=60n w=150n
.ends

.subckt and2x1 i1 i2 o vcc gnd vccnw 
x1 i1 i2 ob  vcc gnd   vccnw nand2x1
x2 ob o  vcc gnd vccnw invx1
.ends

*.subckt sbrblah sb rb q qb vcc gnd vccnw 
*xq  sb qb q  vcc gnd vccnw nand2x1
*xqb rb q  qb vcc gnd vccnw nand2x1
*.ends

.subckt nor2x0 i1 i2 o vcc gnd vccnw 
mp0 net1 i2 vcc  vccnw p12ll l=10u w=300n
mp1 o    i1 net1 vccnw p12ll l=10u w=300n
mn0 o    i1 gnd  gnd   n12ll l=10u w=130n
mn1 o    i2 gnd  gnd   n12ll l=10u w=130n
.ends

.subckt srlahx0 s r q qb vcc gnd vccnw 
xq  r qb q  vcc gnd vccnw nor2x0
xqb s q  qb vcc gnd vccnw nor2x0
.ends

.subckt sw off s d vcc gnd vccnw 
mn0 d    offb s   gnd   n12ll l=60n w=1.3u
mp0 d    off  s   vccnw p12ll l=60n w=1.5u
mn1 offb off  gnd gnd   n12ll l=60n w=130n
mp1 offb off  vcc vccwn p12ll l=60n w=150n
.ends

.subckt varcap8 
+ d
+ cal[7] cal[6] cal[5] cal[4] 
+ cal[3] cal[2] cal[1] cal[0] 
+ vcc gnd vccnw 
xcal7 cal[7] net7 d vcc gnd vccnw sw 
xcal6 cal[6] net6 d vcc gnd vccnw sw 
xcal5 cal[5] net5 d vcc gnd vccnw sw 
xcal4 cal[4] net4 d vcc gnd vccnw sw 
xcal3 cal[3] net3 d vcc gnd vccnw sw 
xcal2 cal[2] net2 d vcc gnd vccnw sw 
xcal1 cal[1] net1 d vcc gnd vccnw sw 
xcal0 cal[0] net0 d vcc gnd vccnw sw 
mnc7 gnd net7 gnd gnd n12ll l=0.84u w=1.36u
mnc6 gnd net6 gnd gnd n12ll l=0.59u w=0.96u
mnc5 gnd net5 gnd gnd n12ll l=0.42u w=0.68u
mnc4 gnd net4 gnd gnd n12ll l=0.30u w=0.48u
mnc3 gnd net3 gnd gnd n12ll l=0.21u w=0.34u
mnc2 gnd net2 gnd gnd n12ll l=0.15u w=0.24u
mnc1 gnd net1 gnd gnd n12ll l=0.11u w=0.17u
mnc0 gnd net0 gnd gnd n12ll l=0.07u w=0.12u
.ends

.subckt tspcfreqdiv ck q vcc gnd vccnw
mp00 net1 qb vcc  vccnw p12ll l=60n w=150n
mp01 b    ck net1 vccnw p12ll l=60n w=150n
mn02 b    qb gnd  gnd   n12ll l=60n w=130n
mp10 a    ck vcc  vccnw p12ll l=60n w=150n
mn11 a    b  net2 gnd   n12ll l=60n w=130n
mn12 net2 ck gnd  gnd   n12ll l=60n w=130n
mp20 qb   a  vcc  vccnw p12ll l=60n w=150n
mn21 qb   ck net3 gnd   n12ll l=60n w=130n
mn22 net3 a  gnd  gnd   n12ll l=60n w=130n
xq   qb   q  vcc  gnd   vccnw invx1
.ends

.subckt osc8
+ rstb 
+ cal[7] cal[6] cal[5] cal[4] 
+ cal[3] cal[2] cal[1] cal[0] 
+ clk[2] clk[1] clk[0] 
+ vcc gnd vccnw 
xrstbb  rstb  rstbb  vcc gnd vccnw invx1 
xrstbbb rstbb rstbbb vcc gnd vccnw invx1 
xclkbb  s0    rstbbb q   qb  vcc   gnd       vccnw srlahx0
xs0     qb    s0     vcc gnd vccnw schmittx1 
xc1 
+ qb
+ cal[7] cal[6] cal[5] cal[4] 
+ cal[3] cal[2] cal[1] cal[0] 
+ vcc gnd vccnw 
+ varcap8
xclk0b  rstb  s0     clk0b vcc gnd   vccnw       and2x1 
xclk[0] clk0b clk[0] vcc   gnd vccnw invx1 
xs1     clk0b s1     vcc   gnd vccnw tspcfreqdiv
xclk1b  rstb  s1     clk1b vcc gnd   vccnw       and2x1 
xclk[1] clk1b clk[1] vcc   gnd vccnw invx1 
xs2     clk1b s2     vcc   gnd vccnw tspcfreqdiv
xclk2b  rstb  s2     clk2b vcc gnd   vccnw       and2x1 
xclk[2] clk2b clk[2] vcc   gnd vccnw invx1 
.ends

.subckt osc8_cosim 
+ rstb 
+ cal[7] cal[6] cal[5] cal[4] 
+ cal[3] cal[2] cal[1] cal[0] 
+ clk[2] clk[1] clk[0] 
x1
+ rstb 
+ cal[7] cal[6] cal[5] cal[4] 
+ cal[3] cal[2] cal[1] cal[0] 
+ clk[2] clk[1] clk[0] 
+ vcc gnd vccnw 
+ osc8
.ends

*tb
x1
+ rstb 
+ cal[7] cal[6] cal[5] cal[4] 
+ cal[3] cal[2] cal[1] cal[0] 
+ x1clk[2] x1clk[1] x1clk[0] 
+ vcc gnd vccnw 
+ osc8
vrstb rstb gnd dc=0 pwl 
+ 0n 0.0
+ 100n 0.0
+ 101n 1.2
vcal[7] cal[7] gnd pulse 0 1.2 0 50p 50p 10u*128 10u*256
vcal[6] cal[6] gnd pulse 0 1.2 0 50p 50p 10u*64  10u*128
vcal[5] cal[5] gnd pulse 0 1.2 0 50p 50p 10u*32  10u*64
vcal[4] cal[4] gnd pulse 0 1.2 0 50p 50p 10u*16  10u*32
vcal[3] cal[3] gnd pulse 0 1.2 0 50p 50p 10u*8   10u*16
vcal[2] cal[2] gnd pulse 0 1.2 0 50p 50p 10u*4   10u*8
vcal[1] cal[1] gnd pulse 0 1.2 0 50p 50p 10u*2   10u*4
vcal[0] cal[0] gnd pulse 0 1.2 0 50p 50p 10u*1   10u*2
cx1clk[2] x1clk[2] gnd 0.69f*1
cx1clk[1] x1clk[1] gnd 0.69f*1
cx1clk[0] x1clk[0] gnd 0.69f*1
.tran 1p 10u*256*2
vgnd gnd 0 0
vvcc vcc gnd dc=0 pwl 0n 0.0 50n 1.2
vvccnw vccnw 0 1.2
.option post=2
.global gnd vcc vccnw
.probe v(*) i(*)
.end
