void boot() {
  __asm__("li sp, 0x00ef");
  __asm__("jal main");
}
#define RAM_A0 ((unsigned int)0x0000)
#define RAM_A1 (RAM_A0+0x00ff)
#define APB_A0 ((unsigned int)0x1000)
#define APB_HDUART0_A0 (APB_A0+0x0000)
#define APB_HDUART1_A0 (APB_A0+0x0100)
#define APB_HDUART2_A0 (APB_A0+0x0200)
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
    volatile unsigned int cnt          :  4 ;
    volatile unsigned int th           :  4 ;
    volatile unsigned int clear        :  1 ;
    volatile unsigned int trig         :  1 ;
    volatile unsigned int empty        :  1 ;
    volatile unsigned int full         :  1 ;
    volatile unsigned int start        :  1 ;
    volatile unsigned int stop         :  1 ;
    volatile unsigned int match        :  1 ;
    volatile unsigned int enadma       :  1 ;
    volatile unsigned int unused2      : 16 ;
  }f;
}hduart_t_fifo;
typedef struct
{
  volatile hduart_t_ctrl ctrl;
  volatile hduart_t_baud baud;
  volatile hduart_t_data data;
  volatile hduart_t_fifo fifo;
}hduart_t;
#define hduart0 ((volatile hduart_t *) APB_HDUART0_A0)
#define hduart1 ((volatile hduart_t *) APB_HDUART1_A0)
#define hduart2 ((volatile hduart_t *) APB_HDUART2_A0)
int set_baud(){
  unsigned int divisor, dividend, baud, fclk, delay;
  baud =  9216;
  fclk = 20000;
  dividend=0;
  for(divisor=1;dividend<0x0fff;divisor++) dividend = (divisor * fclk) / baud;
  if(dividend > 0x7ffe) return -1;
  if(divisor > dividend) return -1;
  delay = dividend / divisor;
  hduart0->ctrl.f.setb = 0x0;
  hduart1->ctrl.f.setb = 0x0;
  hduart2->ctrl.f.setb = 0x0;
  hduart0->baud.r = 0;
  hduart1->baud.r = 0;
  hduart2->baud.r = 0;
  hduart0->baud.r = dividend | (divisor<<16);
  hduart1->baud.r = dividend | (divisor<<16);
  hduart2->baud.r = dividend | (divisor<<16);
  hduart0->ctrl.f.delay = delay;
  hduart1->ctrl.f.delay = delay;
  hduart2->ctrl.f.delay = delay;
  return 0;
}
void test1(){
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
  hduart2->ctrl.f.setb = 0x1;
  k=0; while(hduart0->fifo.f.full==0) hduart0->data.f.bchar = 0xa0+(k++);
  hduart0->ctrl.f.setb = 0x1;
  while(hduart2->fifo.f.full==0);
  while(hduart2->fifo.f.empty==0) k = hduart2->data.f.bchar;
  hduart2->ctrl.f.setb = 0x0;
  hduart0->ctrl.f.setb = 0x0;
}
void test2(){
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
  if(set_baud()==0){
    test1();
    test2();
  }
}
