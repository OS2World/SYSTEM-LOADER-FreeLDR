/* freeldrc.c 2/7/99 dcz */

#include <dos.h>

char CMsgBuff[200];

char fName[25];
unsigned long int fSize;
char far * farpfName;
unsigned long int far * farpfSize;

int (far * muOpen) (char far * fileName,unsigned long int far * fileSize);
unsigned long int (far * muRead) (unsigned long int seekOffset,
			 unsigned char far * dataBuffer,
			 unsigned long int bufferSize);
void (far * muClose)();
void (far * muTerminate)();

void auxil()
{
 sprintf(CMsgBuff,"freeldrc.c: This displays on main console %d\x00d\x00a",7993);
 DispNTS(CMsgBuff);

 /* */
 sprintf(CMsgBuff,"freeldrc.c: This displays on debug console %d\x00d\x00a",7423);
 DebugNTS(CMsgBuff);
 /* */

}

void KernelLoader(void far * filetbl)
{
 unsigned short int word1,word2;
 struct SREGS segs;
 int rc;

 segread(&segs);

 /* Open is 1A and 1C */
 word1 = *(unsigned short int *)(((unsigned char *) filetbl) + 0x1a);
 word2 = *(unsigned short int *)(((unsigned char *) filetbl) + 0x1c);

 sprintf(CMsgBuff,"freeldrc.c: for Open: word1 is %04x,word2 is %04x\x00d\x00a",
      word1,word2);
 DispNTS(CMsgBuff);
 DebugNTS(CMsgBuff);

 muOpen = *
   /* here's the cast! */
   ( int (far * far *) (char far *,unsigned long int far *) )
   (((unsigned char far *) filetbl) + 0x1a);

 strcpy(fName,"OS2KRNL");

 farpfName = MK_FP(segs.ds,fName);
 farpfSize = MK_FP(segs.ds,&fSize);

 rc = (*muOpen) (farpfName,farpfSize);

 sprintf(CMsgBuff,"freeldrc.c: fSize is %08x\x00d\x00a",
      fSize);
 DispNTS(CMsgBuff);
 DebugNTS(CMsgBuff);


}
