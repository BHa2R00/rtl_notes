void boot() {
  __asm__("li sp, 0x1ff");
  __asm__("jal main");
}
#define B1_A0                0x00000000 
#define B1_RAM0_A0    (B1_A0+0x00000000)
#define B1_RAM0_A1    (B1_A0+0x000001ff)
#define B1_TIMER0_A0  (B1_A0+0x00000200)
#define B1_TIMER0_A1  (B1_A0+0x00000207)
#define B1_TIMER1_A0  (B1_A0+0x00000300)
#define B1_TIMER1_A1  (B1_A0+0x00000307)
#define B1_TIMER2_A0  (B1_A0+0x00000400)
#define B1_TIMER2_A1  (B1_A0+0x00000407)
#define B1_TIMER3_A0  (B1_A0+0x00000500)
#define B1_TIMER3_A1  (B1_A0+0x00000507)
#define B1_FCLK0_A0   (B1_A0+0x00000600)
#define B1_FCLK0_A1   (B1_A0+0x00000607)
#define B1_FCLK1_A0   (B1_A0+0x00000700)
#define B1_FCLK1_A1   (B1_A0+0x00000707)
#define B1_FCLK2_A0   (B1_A0+0x00000800)
#define B1_FCLK2_A1   (B1_A0+0x00000807)
#define B1_FCLK3_A0   (B1_A0+0x00000900)
#define B1_FCLK3_A1   (B1_A0+0x00000907)
#define B1_UART0_A0   (B1_A0+0x00000a00)
#define B1_UART0_A1   (B1_A0+0x00000a0b)
#define B1_UART1_A0   (B1_A0+0x00000b00)
#define B1_UART1_A1   (B1_A0+0x00000b0b)
#define B1_UART2_A0   (B1_A0+0x00000c00)
#define B1_UART2_A1   (B1_A0+0x00000c0b)
#define B1_UART3_A0   (B1_A0+0x00000d00)
#define B1_UART3_A1   (B1_A0+0x00000d0b)
#define B1_IO0_A0     (B1_A0+0x00000e00)
#define B1_IO0_A1     (B1_A0+0x00000e07)
typedef union
{
  volatile unsigned int r;
  struct
  {
    volatile unsigned int en           :  1 ;
    volatile unsigned int ld           :  1 ;
    volatile unsigned int os           :  1 ;
    volatile unsigned int hit          :  1 ;
    volatile unsigned int err          :  1 ;
    volatile unsigned int ldd          :  1 ;
    volatile unsigned int unused0      : 26 ;
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
    volatile unsigned int init         :  1 ;
    volatile unsigned int delay        :  4 ;
    volatile unsigned int unused0      : 26 ;
  }f;
}fclk_t_ctrl;
typedef union
{
  volatile unsigned int r;
  struct
  {
    volatile unsigned int dividend     : 16 ;
    volatile unsigned int divisor      : 16 ;
  }f;
}fclk_t_cntr;
typedef struct
{
  volatile fclk_t_ctrl ctrl;
  volatile fclk_t_cntr cntr;
}fclk_t;
typedef union
{
  volatile unsigned int r;
  struct
  {
    volatile unsigned int setb         :  1 ;
    volatile unsigned int sb           :  4 ;
    volatile unsigned int cmsb         :  4 ;
    volatile unsigned int smsb         :  1 ;
    volatile unsigned int parity       :  1 ;
    volatile unsigned int even         :  1 ;
    volatile unsigned int rxe          :  1 ;
    volatile unsigned int txe          :  1 ;
    volatile unsigned int mchar        : 10 ;
    volatile unsigned int unused0      :  8 ;
  }f;
}uart_t_ctrl;
typedef union
{
  volatile unsigned int r;
  struct
  {
    volatile unsigned int bchar        : 10 ;
    volatile unsigned int unused0      : 22 ;
  }f;
}uart_t_data;
typedef union
{
  volatile unsigned int r;
  struct
  {
    volatile unsigned int clear        :  1 ;
    volatile unsigned int full         :  1 ;
    volatile unsigned int empty        :  1 ;
    volatile unsigned int cnt          :  3 ;
    volatile unsigned int unused0      : 26 ;
  }f;
}uart_t_fifo;
typedef struct
{
  volatile uart_t_ctrl ctrl;
  volatile uart_t_data data;
  volatile uart_t_fifo fifo;
}uart_t;
typedef union
{
  volatile unsigned int r;
  struct
  {
    volatile unsigned int omask        :  4 ;
    volatile unsigned int imask        :  4 ;
    volatile unsigned int pu           :  4 ;
    volatile unsigned int pd           :  4 ;
    volatile unsigned int unused0      : 16 ;
  }f;
}io_t_ctrl;
typedef union
{
  volatile unsigned int r;
  struct
  {
    volatile unsigned int oesel0       :  2 ;
    volatile unsigned int iesel0       :  2 ;
    volatile unsigned int  osel0       :  2 ;
    volatile unsigned int  isel0       :  2 ;
    volatile unsigned int oesel1       :  2 ;
    volatile unsigned int iesel1       :  2 ;
    volatile unsigned int  osel1       :  2 ;
    volatile unsigned int  isel1       :  2 ;
    volatile unsigned int oesel2       :  2 ;
    volatile unsigned int iesel2       :  2 ;
    volatile unsigned int  osel2       :  2 ;
    volatile unsigned int  isel2       :  2 ;
    volatile unsigned int oesel3       :  2 ;
    volatile unsigned int iesel3       :  2 ;
    volatile unsigned int  osel3       :  2 ;
    volatile unsigned int  isel3       :  2 ;
  }f;
}io_t_mux;
typedef struct
{
  volatile io_t_ctrl ctrl;
  volatile io_t_mux  mux ;
}io_t;
#define timer0  ((volatile timer_t  *) B1_TIMER0_A0 )
#define timer1  ((volatile timer_t  *) B1_TIMER1_A0 )
#define timer2  ((volatile timer_t  *) B1_TIMER2_A0 )
#define timer3  ((volatile timer_t  *) B1_TIMER3_A0 )
#define fclk0   ((volatile fclk_t   *) B1_FCLK0_A0  )
#define fclk1   ((volatile fclk_t   *) B1_FCLK1_A0  )
#define fclk2   ((volatile fclk_t   *) B1_FCLK2_A0  )
#define fclk3   ((volatile fclk_t   *) B1_FCLK3_A0  )
#define uart0   ((volatile uart_t   *) B1_UART0_A0  )
#define uart1   ((volatile uart_t   *) B1_UART1_A0  )
#define uart2   ((volatile uart_t   *) B1_UART2_A0  )
#define uart3   ((volatile uart_t   *) B1_UART3_A0  )
#define io0     ((volatile io_t     *) B1_IO0_A0    )
#define nth_mem(type, addr) *((volatile type *)((type *)addr))
void timer0_oneshot(unsigned int cnt) {
  timer0->ctrl.f.en = 0;
  while(timer0->ctrl.f.en != 0);
  timer0->ctrl.f.ld = 0;
  while(timer0->ctrl.f.ld != 0);
  timer0->cntr.f.cntr = cnt;
  timer0->ctrl.f.ld = 1;
  while(timer0->ctrl.f.ld != 1);
  timer0->ctrl.f.os = 1;
  timer0->ctrl.f.ld = 0;
  while(timer0->ctrl.f.ld != 0);
  timer0->ctrl.f.en = 1;
  while(timer0->ctrl.f.en != 1);
  while(timer0->ctrl.f.hit==0);
  timer0->ctrl.f.en = 0;
  while(timer0->ctrl.f.en != 0);
}
void timer1_oneshot(unsigned int cnt) {
  timer1->ctrl.f.en = 0;
  while(timer1->ctrl.f.en != 0);
  timer1->ctrl.f.ld = 0;
  while(timer1->ctrl.f.ld != 0);
  timer1->cntr.f.cntr = cnt;
  timer1->ctrl.f.ld = 1;
  while(timer1->ctrl.f.ld != 1);
  timer1->ctrl.f.os = 1;
  timer1->ctrl.f.ld = 0;
  while(timer1->ctrl.f.ld != 0);
  timer1->ctrl.f.en = 1;
  while(timer1->ctrl.f.en != 1);
  while(timer1->ctrl.f.hit==0);
  timer1->ctrl.f.en = 0;
  while(timer1->ctrl.f.en != 0);
}
void timer2_oneshot(unsigned int cnt) {
  timer2->ctrl.f.en = 0;
  while(timer2->ctrl.f.en != 0);
  timer2->ctrl.f.ld = 0;
  while(timer2->ctrl.f.ld != 0);
  timer2->cntr.f.cntr = cnt;
  timer2->ctrl.f.ld = 1;
  while(timer2->ctrl.f.ld != 1);
  timer2->ctrl.f.os = 1;
  timer2->ctrl.f.ld = 0;
  while(timer2->ctrl.f.ld != 0);
  timer2->ctrl.f.en = 1;
  while(timer2->ctrl.f.en != 1);
  while(timer2->ctrl.f.hit==0);
  timer2->ctrl.f.en = 0;
  while(timer2->ctrl.f.en != 0);
}
void timer3_oneshot(unsigned int cnt) {
  timer3->ctrl.f.en = 0;
  while(timer3->ctrl.f.en != 0);
  timer3->ctrl.f.ld = 0;
  while(timer3->ctrl.f.ld != 0);
  timer3->cntr.f.cntr = cnt;
  timer3->ctrl.f.ld = 1;
  while(timer3->ctrl.f.ld != 1);
  timer3->ctrl.f.os = 1;
  timer3->ctrl.f.ld = 0;
  while(timer3->ctrl.f.ld != 0);
  timer3->ctrl.f.en = 1;
  while(timer3->ctrl.f.en != 1);
  while(timer3->ctrl.f.hit==0);
  timer3->ctrl.f.en = 0;
  while(timer3->ctrl.f.en != 0);
}
void enable_uart(){
  io0->mux.f.oesel0 = 0;
  io0->mux.f.osel0 = 0;
  io0->mux.f.iesel0 = 1;
  io0->mux.f.isel0 = 1;
  io0->mux.f.oesel1 = 0;
  io0->mux.f.osel1 = 0;
  io0->mux.f.iesel1 = 1;
  io0->mux.f.isel1 = 1;
  io0->ctrl.f.pu = 0x3;
  io0->ctrl.f.pd = 0x0;
  io0->ctrl.f.omask = 0x1;
  io0->ctrl.f.imask = 0x2;
  fclk0->ctrl.f.delay = 0;
  fclk0->cntr.r = 0x00010364;
  fclk1->ctrl.f.delay = 2;
  fclk1->cntr.r = 0x00010364;
  uart0->fifo.f.clear = 0;
  uart1->fifo.f.clear = 0;
  uart0->fifo.f.clear = 1;
  uart1->fifo.f.clear = 1;
  uart0->ctrl.f.txe = 1;
  uart0->ctrl.f.rxe = 0;
  uart1->ctrl.f.txe = 0;
  uart1->ctrl.f.rxe = 1;
  uart0->ctrl.f.cmsb = 7;
  uart1->ctrl.f.cmsb = 7;
  uart0->ctrl.f.smsb = 1;
  uart1->ctrl.f.smsb = 1;
  uart0->ctrl.f.parity = 0;
  uart1->ctrl.f.parity = 0;
  fclk0->ctrl.f.setb = 0;
  fclk1->ctrl.f.setb = 0;
  uart0->ctrl.f.setb = 1;
  uart1->ctrl.f.setb = 1;
}
void disable_uart(){
  uart0->ctrl.f.setb = 0;
  uart1->ctrl.f.setb = 0;
  io0->ctrl.f.omask = 0x0;
  io0->ctrl.f.imask = 0x0;
  io0->ctrl.f.pu = 0;
  io0->ctrl.f.pd = 0;
}
char putc(char c){
  while(uart0->fifo.f.full!=0);
  uart0->data.f.bchar = 0xff & c;
  return c;
}
char getc(){
  char c;
  while(uart1->fifo.f.empty!=0); 
  c = 0xff & uart1->data.f.bchar;
  return c;
}
void test_timers(){
  int k;
  fclk0->ctrl.f.setb = 0;
  fclk0->cntr.r = 0x00010034;
  fclk0->ctrl.f.setb = 1;
  fclk1->ctrl.f.setb = 0;
  fclk1->cntr.r = 0x00010056;
  fclk1->ctrl.f.setb = 1;
  fclk2->ctrl.f.setb = 0;
  fclk2->cntr.r = 0x00010078;
  fclk2->ctrl.f.setb = 1;
  fclk3->ctrl.f.setb = 0;
  fclk3->cntr.r = 0x0001009a;
  fclk3->ctrl.f.setb = 1;
  for(k=50;k<60;k++){
    timer0_oneshot(k);
    timer1_oneshot(k);
    timer2_oneshot(k);
    timer3_oneshot(k);
  }
  fclk0->ctrl.f.setb = 0;
  fclk1->ctrl.f.setb = 0;
  fclk2->ctrl.f.setb = 0;
  fclk3->ctrl.f.setb = 0;
  fclk2->cntr.r = 0x00010364;
  fclk2->ctrl.f.setb = 1;
  timer2_oneshot(5);
  fclk2->ctrl.f.setb = 0;
  fclk3->cntr.r = 0x00010364;
  fclk3->ctrl.f.setb = 1;
  timer3_oneshot(5);
  fclk3->ctrl.f.setb = 0;
}
void test_uart(){
  int k;
  char s[10] = "oh shit! \n";
  enable_uart();
  for(k=0;k<sizeof(s);k++) putc(s[k]);
  while(uart0->fifo.f.empty==0);
  disable_uart();
}
//#define EMPTY_MAIN
int main() {
#ifndef EMPTY_MAIN
  test_timers();
  test_uart();
#endif 
  //while(1);
  return 0;
}
