#include <stdio.h>


int main (int argc, char** argv){
  int depth, k;
  FILE* fp;
  unsigned int data;
  fp = fopen(argv[1],"rb");
  sscanf(argv[2],"%x",&depth);
  printf("WIDTH = 32;\n");
  printf("DEPTH = %d;\n",depth>>2);
  printf("ADDRESS_RADIX = HEX;\n");
  printf("DATA_RADIX = HEX;\n");
  printf("CONTENT BEGIN\n");
  for(k=0;k<depth;k=k+4) {
    data = 0;
    data = data | (0x000000ff & ((feof(fp) ? 0 : ((unsigned char)fgetc(fp)))<<0));
    data = data | (0x0000ff00 & ((feof(fp) ? 0 : ((unsigned char)fgetc(fp)))<<8));
    data = data | (0x00ff0000 & ((feof(fp) ? 0 : ((unsigned char)fgetc(fp)))<<16));
    data = data | (0xff000000 & ((feof(fp) ? 0 : ((unsigned char)fgetc(fp)))<<24));
    printf("%x :  %x;\n",(k>>2),data);
  }
  fclose(fp);
  printf("END;\n");
  return 0;
}
