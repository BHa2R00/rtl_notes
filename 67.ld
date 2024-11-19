ENTRY(boot)
SECTIONS
{
  . = 0x0;
  .text :
  {
    *(.text*)
  }
  .data :
  {
    *(.data*)
  }
  .bss :
  {
    *(.bss*)
  }
  __stack_pointer = 0xf8;
  __global_pointer = 0xf8;
}
