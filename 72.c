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
#define hduart0 ((volatile hduart_t *) APB_HDUART0_A0)
#define hduart1 ((volatile hduart_t *) APB_HDUART1_A0)
#define hduart2 ((volatile hduart_t *) APB_HDUART2_A0)
#define timer0  ((volatile timer_t  *) APB_TIMER0_A0 )
#define timer1  ((volatile timer_t  *) APB_TIMER1_A0 )
#define timer2  ((volatile timer_t  *) APB_TIMER2_A0 )
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
void tx0rx2(){
  int k;
  hduart0->ctrl.f.txe = 0x1;
  hduart0->ctrl.f.rxe = 0x0;
  hduart2->ctrl.f.txe = 0x0;
  hduart2->ctrl.f.rxe = 0x1;
  hduart0->ctrl.f.cmsb = 8;
  hduart2->ctrl.f.cmsb = 8;
  hduart0->ctrl.f.smsb = 1;
  hduart2->ctrl.f.smsb = 1;
  hduart0->ctrl.f.parity = 1;
  hduart2->ctrl.f.parity = 1;
  hduart0->ctrl.f.even = 1;
  hduart2->ctrl.f.even = 1;
  timer2->cntr.f.cntr = 10;
  timer2->ctrl.f.os = 1;
  timer2->ctrl.f.is = 1;
  timer2->ctrl.f.en = 1;
  while(timer2->ctrl.f.is==0);
  hduart2->ctrl.f.setb = 0x1;
  k=0; 
  while(hduart0->fifo.f.full==0) hduart0->data.f.bchar = (0x01ff & ('@'+(k++)));
  hduart0->ctrl.f.setb = 0x1;
  while(hduart2->fifo.f.full==0);
  while(hduart2->fifo.f.empty==0) k = hduart2->data.f.bchar;
  hduart2->ctrl.f.setb = 0x0;
  hduart0->ctrl.f.setb = 0x0;
}
void tx1bist(){
  int k;
  hduart1->ctrl.f.txe = 0x1;
  hduart1->ctrl.f.rxe = 0x1;
  hduart1->ctrl.f.cmsb = 8;
  hduart1->ctrl.f.loopback = 0x1;
  hduart1->data.f.bchar = 0xaa;
  hduart1->ctrl.f.setb = 0x1;
  while(hduart1->ctrl.f.loopend == 0);
  k = hduart1->ctrl.f.loopcheck;
  hduart1->ctrl.f.setb = 0x0;
}
void main() {
  int k;
  //if(set_baud()==0){
    timer1->cntr.f.cntr = 10;
    timer1->ctrl.f.en = 1;
    for(k=0;k<=3;k++){
      timer1->ctrl.f.is = 1;
      while(timer1->ctrl.f.is==0);
      tx0rx2();
      tx1bist();
    }
  //}
}
