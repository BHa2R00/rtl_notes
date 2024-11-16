void boot() {
  __asm__("li  x1,  0x0");
  __asm__("li  x2,  0xfc");
  __asm__("li  x3,  0xfc");
  __asm__("li  x4,  0x0");
  __asm__("li  x5,  0x0");
  __asm__("li  x6,  0x0");
  __asm__("li  x7,  0x0");
  __asm__("li  x8,  0x0");
  __asm__("li  x9,  0x0");
  __asm__("li  x10, 0x0");
  __asm__("li  x11, 0x0");
  __asm__("li  x12, 0x0");
  __asm__("li  x13, 0x0");
  __asm__("li  x14, 0x0");
  __asm__("li  x15, 0x0");
  __asm__("li  x16, 0x0");
  __asm__("li  x17, 0x0");
  __asm__("li  x18, 0x0");
  __asm__("li  x19, 0x0");
  __asm__("li  x20, 0x0");
  __asm__("li  x21, 0x0");
  __asm__("li  x22, 0x0");
  __asm__("li  x23, 0x0");
  __asm__("li  x24, 0x0");
  __asm__("li  x25, 0x0");
  __asm__("li  x26, 0x0");
  __asm__("li  x27, 0x0");
  __asm__("li  x28, 0x0");
  __asm__("li  x29, 0x0");
  __asm__("li  x30, 0x0");
  __asm__("li  x31, 0x0");
  __asm__("la  sp,  __stack_pointer");
  __asm__("la  gp,  __global_pointer");
  __asm__("jal main");
}
#define RAM_A0 0x0
#define RAM_A1 0xfc
#define APB_TIMER_A0 (RAM_A1+0x4)
volatile unsigned int *const timer_ctrl = (unsigned int *)(APB_TIMER_A0+0x0);
volatile unsigned int *const timer_cntr = (unsigned int *)(APB_TIMER_A0+0x4);
#define APB_TIMER_A1 (APB_TIMER_A0+0x4)
#define APB_UART_A0 (APB_TIMER_A1+0x4)
volatile unsigned int *const lpuart_ctrl = (unsigned int *)(APB_UART_A0+0x0);
volatile unsigned int *const lpuart_baud = (unsigned int *)(APB_UART_A0+0x4);
volatile unsigned int *const lpuart_data = (unsigned int *)(APB_UART_A0+0x8);
volatile unsigned int *const lpuart_fifo = (unsigned int *)(APB_UART_A0+0xc);
#define APB_UART_A1 (APB_UART_A0+0xc)
//int f1(int c, int d) {return c*d;}
void main() {
  int k;
  char b[10] = "shit! 123#";
  int c,d;
  *timer_cntr = 0x50;
  *timer_ctrl = 0x0;
  *timer_ctrl = *timer_ctrl | (0x1<<0);
  *lpuart_ctrl = *lpuart_ctrl | (0x1<<6) | (0x1<<2);
  *lpuart_ctrl = *lpuart_ctrl | (0x1<<0);
  c = 12;
  d = 7;
  for(k=0;k<10;k++) {
    while((*timer_ctrl & (0x1<<6)) == 0x0);
    *lpuart_data = 0x7f & b[k];
    *timer_cntr = 0x5 + c;
    d = (c++)*d;
    *timer_ctrl = *timer_ctrl | (0x1<<1);
    *timer_ctrl = *timer_ctrl & ~(0x1<<1);
    if((k & 0x3) == 0){
      // flop ie -- timer interrupt enable
      *timer_ctrl = 
        ((*timer_ctrl & (0x1<<4)) == 0x0) ? 
        (*timer_ctrl | (0x1<<4)) : 
        (*timer_ctrl & ~(0x1<<4));
    }
    if((k & 0x3) == 0x1){
      // flop ee -- timer error enable
      *timer_ctrl = 
        ((*timer_ctrl & (0x1<<5)) == 0x0) ? 
        (*timer_ctrl | (0x1<<5)) : 
        (*timer_ctrl & ~(0x1<<5));
    }
    if((k & 0x3) == 0x2){
      // flop he -- timer halt enable
      *timer_ctrl = 
        ((*timer_ctrl & (0x1<<8)) == 0x0) ? 
        (*timer_ctrl | (0x1<<8)) : 
        (*timer_ctrl & ~(0x1<<8));
    }
  }
  *timer_ctrl = *timer_ctrl & ~(0x1<<0);
  // vanilla mode 
  *timer_ctrl = *timer_ctrl & ~(0x1<<2);
  *timer_ctrl = *timer_ctrl & ~(0x1<<3);
  *timer_cntr = 0x123;
  *timer_ctrl = *timer_ctrl | (0x1<<0);
  while((*timer_ctrl & (0x1<<6)) == 0x0);
  for(k=0;k<500;k++);
  *timer_ctrl = *timer_ctrl & ~(0x1<<0);
  // one-shot mode 
  *timer_ctrl = *timer_ctrl | (0x1<<2);
  *timer_cntr = 0x123;
  *timer_ctrl = *timer_ctrl | (0x1<<0);
  while((*timer_ctrl & (0x1<<6)) == 0x0);
  for(k=0;k<500;k++);
  *timer_ctrl = *timer_ctrl & ~(0x1<<0);
  *timer_ctrl = *timer_ctrl & ~(0x1<<2);
  // free-run mode 
  *timer_ctrl = *timer_ctrl | (0x1<<3);
  *timer_cntr = 0x123;
  *timer_ctrl = *timer_ctrl | (0x1<<0);
  while((*timer_ctrl & (0x1<<6)) == 0x0);
  for(k=0;k<500;k++);
  *timer_ctrl = *timer_ctrl & ~(0x1<<0);
  *timer_ctrl = *timer_ctrl & ~(0x1<<3);
}
