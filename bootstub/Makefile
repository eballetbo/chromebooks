#
#  Copyright (C) 1999-2001 Hewlett-Packard Co.
#	Contributed by David Mosberger <davidm@hpl.hp.com>
#	Contributed by Stephane Eranian <eranian@hpl.hp.com>
#
# This file is part of the gnu-efi package.
#
#  GNU-EFI is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2, or (at your option)
#  any later version.
#
#  GNU-EFI is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with GNU-EFI; see the file COPYING.  If not, write to the Free
#  Software Foundation, 59 Temple Place - Suite 330, Boston, MA
#  02111-1307, USA.
#

PREFIX 	   ?= /usr/bin/x86_64-pc-linux-gnu-
CC    	   ?= $(PREFIX)gcc
LD         ?= $(PREFIX)ld
OBJCOPY    ?= $(PREFIX)objcopy


EFIINC     = /usr/include/efi
EFILIB     = /usr/lib
EFICRT0    = /usr/lib

ARCH       = $(shell uname -m | sed s,i[3456789]86,ia32,)

INCDIR     = -I$(EFIINC) -I$(EFIINC)/$(ARCH)

CPPFLAGS   = -DCONFIG_$(ARCH) 

OPTIMFLAGS = -O2 
DEBUGFLAGS = -Wall
CFLAGS     = $(OPTIMFLAGS) -fpic -fshort-wchar $(DEBUGFLAGS)
CFLAGS     += -DEFI_FUNCTION_WRAPPER
LDFLAGS    = -nostdlib -znocombreloc


CRTOBJS       = $(EFICRT0)/crt0-efi-$(ARCH).o
LDSCRIPT      = $(EFICRT0)/elf_$(ARCH)_efi.lds

LDFLAGS		+= -T $(LDSCRIPT) -shared -Bsymbolic -L$(EFILIB) $(CRTOBJS)
LOADLIBES	= -lefi -lgnuefi $(shell $(CC) -print-libgcc-file-name)
FORMAT		= efi-app-$(ARCH)


TARGETS = bootstub.efi

all:	$(TARGETS)

clean:
	rm -f $(TARGETS) *~ *.o *.so

install: bootstub.efi
	mkdir -p $(DESTDIR)
	cp -f $^ $(DESTDIR)

.PHONY: all clean install


bootstub.so: bootstub.o trampoline.o
	$(LD) $(LDFLAGS) $^ -o $@ $(LOADLIBES)

%.efi: %.so 
	$(OBJCOPY) -j .text -j .sdata -j .data -j .dynamic -j .dynsym -j .rel \
		   -j .rela -j .reloc --target=$(FORMAT) $*.so $@

%.so: %.o 
	$(LD) $(LDFLAGS) $^ -o $@ $(LOADLIBES)

%.o: %.c
	$(CC) $(INCDIR) $(CFLAGS) $(CPPFLAGS) -c $< -o $@

%.o: %.S 
	$(CC) $(INCDIR) $(CFLAGS) $(CPPFLAGS) -c $< -o $@
