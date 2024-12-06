void boot() {
  __asm__("li sp, 0x00ef");
  __asm__("jal main");
}
#define RAM_A0  ((unsigned int)0x0000)
#define RAM_A1         (RAM_A0+0x0fff)
#define APB_A0  ((unsigned int)0x1000)
#define APB_HDUART0_A0 (APB_A0+0x0000)
#define APB_HDUART1_A0 (APB_A0+0x0100)
#define APB_HDUART2_A0 (APB_A0+0x0200)
#define APB_TIMER0_A0  (APB_A0+0x0300)
#define APB_TIMER1_A0  (APB_A0+0x0400)
#define APB_TIMER2_A0  (APB_A0+0x0500)
#define APB_IIC0_A0    (APB_A0+0x0600)
#define APB_IIC1_A0    (APB_A0+0x0700)
#define APB_IIC2_A0    (APB_A0+0x0800)
#define APB_SYS_A0     (APB_A0+0x0900)
typedef union
{
  volatile unsigned int r;
  struct
  {
    volatile unsigned int setb         :  1 ;
    volatile unsigned int txe          :  1 ;
    volatile unsigned int rxe          :  1 ;
    volatile unsigned int clk_sel      :  1 ;
    volatile unsigned int pclk_vld     :  1 ;
    volatile unsigned int fclk_vld     :  1 ;
    volatile unsigned int cmsb         :  4 ;
    volatile unsigned int smsb         :  1 ;
    volatile unsigned int parity       :  1 ;
    volatile unsigned int even         :  1 ;
    volatile unsigned int irqena_trig  :  1 ;
    volatile unsigned int irqena_full  :  1 ;
    volatile unsigned int irqena_empty :  1 ;
    volatile unsigned int irqena_start :  1 ;
    volatile unsigned int irqena_stop  :  1 ;
    volatile unsigned int irqena_match :  1 ;
    volatile unsigned int delay        :  4 ;
    volatile unsigned int loopback     :  1 ;
    volatile unsigned int loopcheck    :  1 ;
    volatile unsigned int loopend      :  1 ;
    volatile unsigned int unused0      :  6 ;
  }f;
}hduart_t_ctrl;
typedef union
{
  volatile unsigned int r;
  struct
  {
    volatile unsigned int dividend     : 16 ;
    volatile unsigned int divisor      : 16 ;
  }f;
}hduart_t_baud;
typedef union
{
  volatile unsigned int r;
  struct
  {
    volatile unsigned int bchar        : 10 ;
    volatile unsigned int mchar        : 10 ;
    volatile unsigned int unused1      : 12 ;
  }f;
}hduart_t_data;
typedef union
{
  volatile unsigned int r;
  struct
  {
    volatile unsigned int cnt          :  5 ;
    volatile unsigned int th           :  5 ;
    volatile unsigned int clear        :  1 ;
    volatile unsigned int trig         :  1 ;
    volatile unsigned int empty        :  1 ;
    volatile unsigned int full         :  1 ;
    volatile unsigned int start        :  1 ;
    volatile unsigned int stop         :  1 ;
    volatile unsigned int match        :  1 ;
    volatile unsigned int enadma       :  1 ;
    volatile unsigned int unused2      : 14 ;
  }f;
}hduart_t_fifo;
typedef struct
{
  volatile hduart_t_ctrl ctrl;
  volatile hduart_t_baud baud;
  volatile hduart_t_data data;
  volatile hduart_t_fifo fifo;
}hduart_t;
typedef union
{
  volatile unsigned int r;
  struct
  {
    volatile unsigned int en           :  1 ;
    volatile unsigned int ld           :  1 ;
    volatile unsigned int os           :  1 ;
    volatile unsigned int fr           :  1 ;
    volatile unsigned int ie           :  1 ;
    volatile unsigned int ee           :  1 ;
    volatile unsigned int is           :  1 ;
    volatile unsigned int es           :  1 ;
    volatile unsigned int he           :  1 ;
    volatile unsigned int lr           :  1 ;
    volatile unsigned int unused0      : 22 ;
  }f;
}timer_t_ctrl;
typedef union
{
  volatile unsigned int r;
  struct
  {
    volatile unsigned int cntr         : 32 ;
  }f;
}timer_t_cntr;
typedef struct
{
  volatile timer_t_ctrl ctrl;
  volatile timer_t_cntr cntr;
}timer_t;
typedef union
{
  volatile unsigned int r;
  struct
  {
    volatile unsigned int setb         :  1 ;
    volatile unsigned int master       :  1 ;
    volatile unsigned int addr10bit    :  1 ;
    volatile unsigned int waddr        : 11 ;
    volatile unsigned int raddr        : 11 ;
    volatile unsigned int aack         :  1 ;
    volatile unsigned int dack         :  1 ;
    volatile unsigned int irqena_aack  :  1 ;
    volatile unsigned int irqena_dack  :  1 ;
    volatile unsigned int irqena_empty :  1 ;
    volatile unsigned int irqena_full  :  1 ;
    volatile unsigned int irqena_trig  :  1 ;
  }f;
}iic_t_ctrl;
typedef union
{
  volatile unsigned int r;
  struct
  {
    volatile unsigned int dividend     :  8 ;
    volatile unsigned int divisor      :  8 ;
    volatile unsigned int unused0      : 16 ;
  }f;
}iic_t_cdiv;
typedef union
{
  volatile unsigned int r;
  struct
  {
    volatile unsigned int bchar        :  8 ;
    volatile unsigned int unused0      : 24 ;
  }f;
}iic_t_data;
typedef union
{
  volatile unsigned int r;
  struct
  {
    volatile unsigned int cnt          :  4 ;
    volatile unsigned int th           :  4 ;
    volatile unsigned int empty        :  1 ;
    volatile unsigned int full         :  1 ;
    volatile unsigned int idleena      :  1 ;
    volatile unsigned int clear        :  1 ;
    volatile unsigned int trig         :  1 ;
    volatile unsigned int dmaena       :  1 ;
    volatile unsigned int setup        :  3 ;
    volatile unsigned int dth          :  4 ;
    volatile unsigned int unused0      : 11 ;
  }f;
}iic_t_fifo;
typedef struct
{
  volatile iic_t_ctrl ctrl;
  volatile iic_t_cdiv cdiv;
  volatile iic_t_data data;
  volatile iic_t_fifo fifo;
}iic_t;
typedef union
{
  volatile unsigned int r;
  struct
  {
    volatile unsigned int dividend     : 16 ;
    volatile unsigned int divisor      : 16 ;
  }f;
}sys_t_cdiv0;
typedef union
{
  volatile unsigned int r;
  struct
  {
    volatile unsigned int dividend     : 16 ;
    volatile unsigned int divisor      : 16 ;
  }f;
}sys_t_cdiv1;
typedef union
{
  volatile unsigned int r;
  struct
  {
    volatile unsigned int dividend     : 16 ;
    volatile unsigned int divisor      : 16 ;
  }f;
}sys_t_cdiv2;
typedef union
{
  volatile unsigned int r;
  struct
  {
    volatile unsigned int dividend     : 16 ;
    volatile unsigned int divisor      : 16 ;
  }f;
}sys_t_cdiv3;
typedef struct
{
  volatile sys_t_cdiv0 cdiv0;
  volatile sys_t_cdiv1 cdiv1;
  volatile sys_t_cdiv2 cdiv2;
  volatile sys_t_cdiv3 cdiv3;
}sys_t;
#define hduart0 ((volatile hduart_t *) APB_HDUART0_A0)
#define hduart1 ((volatile hduart_t *) APB_HDUART1_A0)
#define hduart2 ((volatile hduart_t *) APB_HDUART2_A0)
#define timer0  ((volatile timer_t  *) APB_TIMER0_A0 )
#define timer1  ((volatile timer_t  *) APB_TIMER1_A0 )
#define timer2  ((volatile timer_t  *) APB_TIMER2_A0 )
#define iic0    ((volatile iic_t    *) APB_IIC0_A0   )
#define iic1    ((volatile iic_t    *) APB_IIC1_A0   )
#define iic2    ((volatile iic_t    *) APB_IIC2_A0   )
#define sys     ((volatile sys_t    *) APB_SYS_A0    )
int softimul(int a, int b){
  int m, neg;
  if(a<0) { a=-a; neg=!neg; }
  if(b<0) { b=-b; neg=!neg; }
  while(b>0){
    if(b&1) m+=a;
    a<<=1;
    b>>=1;
  }
  return neg? -m:m;
}
unsigned int softumul(unsigned int a, unsigned int b){
  unsigned int m;
  while(b>0){
    if(b&1) m+=a;
    a<<=1;
    b>>=1;
  }
  return m;
}
int softidiv(int a, int b){
  int q, r, neg, i;
  if(a<0) { a=-a; neg=!neg; }
  if(b<0) { b=-b; neg=!neg; }
  q=0; r=0;
  for(i=31;i>0;i--){
    r<<=1;
    r|=(b>>1)&1;
    q<<=1;
    if(r>a){ r-=a; q|=1; }
  }
  return neg ? -q:q;
}
unsigned int softudiv(unsigned int a, unsigned int b){
  unsigned int q, r;
  int i;
  q=0; r=0;
  for(i=31;i>0;i--){
    r<<=1;
    r|=(b>>1)&1;
    q<<=1;
    if(r>a){ r-=a; q|=1; }
  }
  return q;
}
int softirem(int a, int b){
  int q, r, neg, i;
  if(a<0) { a=-a; neg=!neg; }
  if(b<0) { b=-b; neg=!neg; }
  q=0; r=0;
  for(i=31;i>0;i--){
    r<<=1;
    r|=(b>>1)&1;
    q<<=1;
    if(r>a){ r-=a; q|=1; }
  }
  return neg ? -r:r;
}
unsigned int softurem(unsigned int a, unsigned int b){
  unsigned int q, r;
  int i;
  q=0; r=0;
  for(i=31;i>0;i--){
    r<<=1;
    r|=(b>>1)&1;
    q<<=1;
    if(r>a){ r-=a; q|=1; }
  }
  return r;
}
/*int set_baud(){
  int k;
  unsigned int divisor[3], dividend[3], baud, delay[3], fclk[3];
  baud =  1152;
  fclk[0] = 20000;
  fclk[1] = 20000;
  fclk[2] = 20000;
  for(k=0;k<=2;k++){
    dividend[k]=0;
    for(divisor[k]=1;dividend[k]<0x3fff;divisor[k]++) dividend[k] = divisor[k]*fclk[k]/baud;
    if(dividend[k] > 0x7fff) return -1;
    if(divisor[k] > dividend[k]) return -1;
    delay[k] = dividend[k]/divisor[k];
  }
  hduart0->ctrl.f.setb = 0x0;
  hduart1->ctrl.f.setb = 0x0;
  hduart2->ctrl.f.setb = 0x0;
  hduart0->baud.r = 0;
  hduart1->baud.r = 0;
  hduart2->baud.r = 0;
  hduart0->baud.r = dividend[0] | (divisor[0]<<16);
  hduart1->baud.r = dividend[1] | (divisor[1]<<16);
  hduart2->baud.r = dividend[2] | (divisor[2]<<16);
  hduart0->ctrl.f.delay = delay[0] & 0x1f;
  hduart1->ctrl.f.delay = delay[0] & 0x1f;
  hduart2->ctrl.f.delay = delay[2] & 0x1f;
  return 0;
}*/
void timer0_oneshot(unsigned int cnt) {
  timer0->cntr.f.cntr = cnt;
  timer0->ctrl.f.os = 1;
  timer0->ctrl.f.is = 1;
  timer0->ctrl.f.en = 1;
  while(timer0->ctrl.f.is==0);
}
void timer1_oneshot(unsigned int cnt) {
  timer1->cntr.f.cntr = cnt;
  timer1->ctrl.f.os = 1;
  timer1->ctrl.f.is = 1;
  timer1->ctrl.f.en = 1;
  while(timer1->ctrl.f.is==0);
}
void timer2_oneshot(unsigned int cnt) {
  timer2->cntr.f.cntr = cnt;
  timer2->ctrl.f.os = 1;
  timer2->ctrl.f.is = 1;
  timer2->ctrl.f.en = 1;
  while(timer2->ctrl.f.is==0);
}
void tx0rx2(){
  int k;
  hduart0->ctrl.f.txe = 1;
  hduart0->ctrl.f.rxe = 0;
  hduart2->ctrl.f.txe = 0;
  hduart2->ctrl.f.rxe = 1;
  hduart0->ctrl.f.cmsb = 6;
  hduart2->ctrl.f.cmsb = 6;
  hduart0->ctrl.f.smsb = 1;
  hduart2->ctrl.f.smsb = 1;
  hduart0->ctrl.f.parity = 1;
  hduart2->ctrl.f.parity = 1;
  hduart0->ctrl.f.even = 1;
  hduart2->ctrl.f.even = 1;
  timer2_oneshot(10);
  hduart2->ctrl.f.setb = 1;
  k=0; 
  while(hduart0->fifo.f.full==0) hduart0->data.f.bchar = (0x01ff & ('@'+(k++)));
  hduart0->ctrl.f.setb = 1;
  while(hduart2->fifo.f.full==0);
  while(hduart2->fifo.f.empty==0) k = hduart2->data.f.bchar;
  hduart2->ctrl.f.setb = 0;
  hduart0->ctrl.f.setb = 0;
}
int tx1bist(){
  int r;
  hduart1->ctrl.f.txe = 1;
  hduart1->ctrl.f.rxe = 1;
  hduart1->ctrl.f.cmsb = 8;
  hduart1->ctrl.f.loopback = 1;
  hduart1->data.f.bchar = 0xaa;
  hduart1->ctrl.f.setb = 1;
  while(hduart1->ctrl.f.loopend == 0);
  r = hduart1->ctrl.f.loopcheck;
  hduart1->ctrl.f.setb = 0;
  return r;
}
void iic_test1(){
  int k;
  unsigned short addr[3];
  unsigned char data;
  addr[0] = ((0x55<<1)|0x0);
  addr[1] = ((0x55<<1)|0x1);
  addr[2] = ((0x56<<1)|0x0);
  iic0->ctrl.f.master = 1;
  iic0->ctrl.f.addr10bit = 0;
  iic0->ctrl.f.waddr = addr[0];
  iic1->ctrl.f.master = 0;
  iic1->ctrl.f.addr10bit = 0;
  iic1->ctrl.f.waddr = addr[1];
  iic2->ctrl.f.master = 0;
  iic2->ctrl.f.addr10bit = 0;
  iic2->ctrl.f.waddr = addr[2];
  k = 0; while(iic0->fifo.f.full == 0) iic0->data.f.bchar = 0xa0+(k++);
  timer2_oneshot(10);
  iic2->ctrl.f.setb = 1;
  iic1->ctrl.f.setb = 1;
  iic0->ctrl.f.setb = 1;
  while(iic1->fifo.f.full == 0);
  timer2_oneshot(10);
  iic0->ctrl.f.setb = 0;
  iic1->ctrl.f.setb = 0;
  iic2->ctrl.f.setb = 0;
  while(iic1->fifo.f.empty == 0) data = iic1->data.f.bchar;
}
void iic_test2(){
  int k;
  unsigned short addr[3];
  unsigned char data;
  addr[0] = ((0x26<<1)|0x1);
  addr[1] = ((0x25<<1)|0x1);
  addr[2] = ((0x26<<1)|0x0);
  iic0->ctrl.f.master = 1;
  iic0->ctrl.f.addr10bit = 1;
  iic0->ctrl.f.waddr = addr[0];
  iic1->ctrl.f.master = 0;
  iic1->ctrl.f.addr10bit = 1;
  iic1->ctrl.f.waddr = addr[1];
  iic2->ctrl.f.master = 0;
  iic2->ctrl.f.addr10bit = 1;
  iic2->ctrl.f.waddr = addr[2];
  k = 0; while(iic2->fifo.f.full == 0) iic2->data.f.bchar = 0xb0+(k++);
  timer2_oneshot(10);
  iic2->ctrl.f.setb = 1;
  iic1->ctrl.f.setb = 1;
  iic0->ctrl.f.setb = 1;
  while(iic0->fifo.f.full == 0);
  timer2_oneshot(10);
  iic0->ctrl.f.setb = 0;
  iic1->ctrl.f.setb = 0;
  iic2->ctrl.f.setb = 0;
  while(iic0->fifo.f.empty == 0) data = iic0->data.f.bchar;
}
void main() {
  int k;
  //if(set_baud()==0){
    timer0->cntr.f.cntr = 10;
    timer0->ctrl.f.en = 1;
    for(k=0;k<3;k++){
      tx0rx2();
      timer0->ctrl.f.is = 1;
      while(timer0->ctrl.f.is==0);
      if(tx1bist()) timer1_oneshot(10);
      iic_test1();
      iic_test2();
    }
  //}
}
