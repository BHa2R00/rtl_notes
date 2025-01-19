ENTRY(boot)
SECTIONS
{
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
}
