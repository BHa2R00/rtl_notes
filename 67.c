void boot() {
  __asm__("li sp, 0xf8");
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
void wait_timer(){ while((*timer_ctrl & (0x1<<6)) == 0x0); }
void test_vanilla_mode (char* b){
  int k;
  *timer_cntr = 0xc;
  *timer_ctrl = 0x0;
  *timer_ctrl = *timer_ctrl | (0x1<<0);
  k=0;
  while(k<10) {
    wait_timer();
    *timer_ctrl = *timer_ctrl | (0x1<<6);
    *lpuart_data = 0x7f & b[k++];
  }
  *timer_ctrl = *timer_ctrl &~(0x1<<0);
}
void test_one_shot_mode (char* b){
  int k;
  *timer_cntr = 0x8;
  *timer_ctrl = 0x0;
  *timer_ctrl = *timer_ctrl | (0x1<<2);
  *timer_ctrl = *timer_ctrl | (0x1<<0);
  for(k=0;k<10;k++) {
    wait_timer();
    *timer_ctrl = *timer_ctrl &~(0x1<<0);
    *lpuart_data = 0x7f & b[k];
    *timer_ctrl = *timer_ctrl | (0x1<<0);
  }
  *timer_ctrl = *timer_ctrl &~(0x1<<0);
}
void test_free_run_mode (char* b){
  int k;
  *timer_cntr = 0x1c;
  *timer_ctrl = 0x0;
  *timer_ctrl = *timer_ctrl | (0x1<<3);
  *timer_ctrl = *timer_ctrl | (0x1<<0);
  for(k=0;k<10;k++) {
    wait_timer();
    *timer_ctrl = *timer_ctrl | (0x1<<6);
    *lpuart_data = 0x7f & b[k];
  }
  *timer_ctrl = *timer_ctrl &~(0x1<<0);
}
void main() {
  int k;
  char b[10] = "shit! 123#";
  *lpuart_ctrl = *lpuart_ctrl | (0x1<<6) | (0x1<<2);
  *lpuart_ctrl = *lpuart_ctrl | (0x1<<0);
  for(k=0;k<3;k++){
    test_vanilla_mode(b);
    test_one_shot_mode(b); 
    test_free_run_mode(b); 
  }
}
