// Copyright (c) 2010 The Chromium OS Authors. All rights reserved.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

#include <efi.h>
#include <efilib.h>

// Here's a struct to locate the pointers we need to update in the zeropage
// structure. Everything else should already be hardcoded at compile time.
// See arch/x86/include/asm/bootparam.h in the kernel source for the real deal.
struct hacked_params {
    uint8_t  pad0[0x1c0];
    uint32_t v0206_efi_signature;          /* 1c0 */
    uint32_t v0206_efi_system_table;       /* 1c4 */
    uint32_t v0206_efi_mem_desc_size;      /* 1c8 */
    uint32_t v0206_efi_mem_desc_version;   /* 1cc */
    uint32_t v0206_efi_mmap;               /* 1d0 */
    uint32_t v0206_efi_mmap_size;          /* 1d4 */
    uint32_t v0206_efi_system_table_hi;    /* 1d8 */
    uint32_t v0206_efi_mmap_hi;            /* 1dc */
    uint8_t  pad1[0x214 - 0x1e0];
    uint32_t code32_start;                 /* 214 */
    uint8_t  pad2[0x228 - 0x218];
    uint32_t cmd_line_ptr;                 /* 228 */
} __attribute__ ((packed));


// Find where the preloaded params struct is located in RAM. At the moment
// we're assuming that it immediately precedes the start of the bootstub,
// aligned to a 4K boundary, because that's where our build system puts it.
struct hacked_params *find_params_struct(UINTN bootstub_location)
{
    return (struct hacked_params *)(bootstub_location - 0x1000);
}

// Copy a string to the right within a buffer.
static void shove_over(char *src, char *dst)
{
    int i = 0;
    for (i=0; src[i]; i++)
        ;                               // find strlen(src)
    dst += i;
    src += i;
    i++;                                // also terminating '\0';
    while (i--)
        *dst-- = *src--;
}

// sprintf(dst,"%02x",val)
static void one_byte(char *dst, uint8_t val)
{
    dst[0] = "0123456789abcdef"[(val >> 4) & 0x0F];
    dst[1] = "0123456789abcdef"[val & 0x0F];
}

// Display a GUID in canonical form
static void emit_guid(char *dst, uint8_t *guid)
{
    one_byte(dst, guid[3]); dst += 2;
    one_byte(dst, guid[2]); dst += 2;
    one_byte(dst, guid[1]); dst += 2;
    one_byte(dst, guid[0]); dst += 2;
    *dst++ = '-';
    one_byte(dst, guid[5]); dst += 2;
    one_byte(dst, guid[4]); dst += 2;
    *dst++ = '-';
    one_byte(dst, guid[7]); dst += 2;
    one_byte(dst, guid[6]); dst += 2;
    *dst++ = '-';
    one_byte(dst, guid[8]); dst += 2;
    one_byte(dst, guid[9]); dst += 2;
    *dst++ = '-';
    one_byte(dst, guid[10]); dst += 2;
    one_byte(dst, guid[11]); dst += 2;
    one_byte(dst, guid[12]); dst += 2;
    one_byte(dst, guid[13]); dst += 2;
    one_byte(dst, guid[14]); dst += 2;
    one_byte(dst, guid[15]); dst += 2;
}


// Replace any %D with the device letter, and replace any %P with the partition
// number. For example, ("root=/dev/sd%D%P",2,3) gives "root=/dev/sdc3".
// Replace any %U with the human-readable form of the GUID (if provided). The
// input string must be mutable and end with a trailing '\0', and have enough
// room for all the expansion.
static void update_cmdline_inplace(char *src, int devnum, int partnum,
                                   uint8_t *guid)
{
    char *dst;

    // Use sane values (sda3) for ridiculous inputs.
    if (devnum < 0 || devnum > 25 || partnum < 1 || partnum > 99)
    {
        devnum = 0;
        partnum = 3;
    }

    for( dst = src; *src; src++, dst++ )
    {
        if ( src[0] == '%' )
        {
            switch (src[1])
            {
            case 'P':
                if (partnum > 9)
                    *dst++ = '0' + (partnum / 10);
                *dst = '0' + partnum % 10;
                src++;
                break;
            case 'D':
                *dst = 'a' + devnum;
                src++;
                break;
            case 'U':
                if (guid) {
                    shove_over(src+2, dst+36);
                    emit_guid(dst, guid);
                    src = dst+35;
                    dst += 35;
                }
            default:
                *dst = *src;
            }
        }
        else if (dst != src)
            *dst = *src;
    }
    *dst = '\0';
}

// This is handy to write status codes to the LEDs for debugging.
static __inline void port80w (unsigned short int value)
{
    __asm__ __volatile__ ("outw %w0,$0x80": :"a" (value));
}


// The code to switch to 32-bit mode and start the kernel.
extern void trampoline(unsigned long, void *);


// Reserve some space for the EFI memory map.
// Danger Will Robinson: this is just a guess at the size and alignment. If
// it's too small, the EFI GetMemoryMap() call will fail.
// FIXME: Make the size dynamic? Retry with larger size on failure?
static unsigned char mmap_buf[0x2000] __attribute__ ((aligned(0x200)));

// Parameters that we're given by the BIOS
typedef struct cros_boot_info {
    UINTN drive_number;                 // 0 - 25
    UINTN partition_number;             // 1 - 99
    UINTN original_address;             // our RAM address prior to execution
    // The guid stuff was added later, so we need to consider it optional, at
    // least for testing.
    uint8_t partition_guid[16];         // kernel partition GUID
} cros_boot_info_t;


// Here's the entry point. It will be loaded by the BIOS as a standard EFI
// application, which means it will be relocated.
EFI_STATUS efi_main (EFI_HANDLE image, EFI_SYSTEM_TABLE *systab)
{
    UINTN mmap_size = sizeof(mmap_buf);
    UINTN mmap_key = 0;
    UINTN desc_size = 0;
    UINT32 desc_version = 0;
    EFI_LOADED_IMAGE *loaded_image;
    EFI_GUID loaded_image_protocol = LOADED_IMAGE_PROTOCOL;
    EFI_GUID zero_guid = {0, 0, 0, {0, 0, 0, 0, 0, 0, 0, 0}};
    void *guid_ptr;

    // I'm here.
    port80w(0xb0b0);

    // Find the parameters that the BIOS has passed to us.
    if (uefi_call_wrapper(systab->BootServices->HandleProtocol, 3,
                          image,
                          &loaded_image_protocol,
                          &loaded_image) != 0)
    {
        uefi_call_wrapper(systab->ConOut->OutputString, 3, systab->ConOut,
                          L"Can't locate protocol\r\n");
        goto fail;
    }
    cros_boot_info_t *booting = loaded_image->LoadOptions;
    if (loaded_image->LoadOptionsSize < 40) // DWR: min size including guid
        guid_ptr = &zero_guid;
    else
        guid_ptr = booting->partition_guid;

    // Find the parameters that we're passing to the kernel.
    struct hacked_params *params = find_params_struct(booting->original_address);

    // Update the kernel command-line string with the correct rootfs device
    update_cmdline_inplace((char *)(unsigned long)(params->cmd_line_ptr),
                           booting->drive_number,
                           booting->partition_number + 1,
                           guid_ptr);

    // Obtain the EFI memory map.
    if (uefi_call_wrapper(systab->BootServices->GetMemoryMap, 5,
                          &mmap_size, mmap_buf, &mmap_key,
                          &desc_size, &desc_version) != 0)
    {
        uefi_call_wrapper(systab->ConOut->OutputString, 2, systab->ConOut,
                          L"Can't get memory map\r\n");
        goto fail;
    }

    // Update the pointers to the EFI memory map and system table.
    params->v0206_efi_signature = ('4' << 24 | '6' << 16 | 'L' << 8 | 'E');
    params->v0206_efi_system_table = (uint32_t) (unsigned long)systab;
    params->v0206_efi_mem_desc_size = desc_size;
    params->v0206_efi_mem_desc_version = desc_version;
    params->v0206_efi_mmap = (uint32_t) (unsigned long)mmap_buf;
    params->v0206_efi_mmap_size = mmap_size;
    params->v0206_efi_mmap_hi = (uint32_t)((uint64_t)mmap_buf >> 32);
    params->v0206_efi_system_table_hi = (uint32_t) ((uint64_t)systab >> 32);


    // Done with BIOS.
    if (uefi_call_wrapper(systab->BootServices->ExitBootServices, 2,
                          image, mmap_key) != 0)
    {
        uefi_call_wrapper(systab->ConOut->OutputString, 2, systab->ConOut,
                          L"Can't exit boot services\r\n");
        goto fail;
    }


    // Trampoline to 32-bit entry point. Should never return.
    trampoline(params->code32_start, params);

fail:

    // Bad Things happened.
    port80w(0xeeee);

    return EFI_LOAD_ERROR;
}
