# FREELDR.MAK: Makefile for test OS/2 Loader. 2/6/99 dcz

freeldr.com : freeldrc.obj freeldra.obj periphs.obj
     tlink /s /m /t freeldra.obj+freeldrc.obj+periphs.obj, \
	 freeldr,freeldr,\tc\lib\cs.lib+\tc\lib\maths.lib

freeldrc.obj : freeldrc.c
     tcc -c -mt freeldrc.c

freeldra.obj : freeldra.asm
     tasm freeldra.asm

periphs.obj : periphs.asm
     tasm periphs.asm
