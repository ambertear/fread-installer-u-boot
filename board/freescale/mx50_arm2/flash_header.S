/*
 * Copyright (C) 2010 Freescale Semiconductor, Inc.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston,
 * MA 02111-1307 USA
 */

#include <config.h>
#include <asm/arch/mx50.h>

#ifdef	CONFIG_FLASH_HEADER
#ifndef CONFIG_FLASH_HEADER_OFFSET
# error "Must define the offset of flash header"
#endif

.section ".text.flasheader", "x"
	b	_start
	.org	CONFIG_FLASH_HEADER_OFFSET

/* First IVT to copy the plugin that initializes the system into OCRAM */
ivt_header:        .long 0x402000D1    /* Tag=0xD1, Len=0x0020, Ver=0x40 */
app_code_jump_v:   .long 0xF8006458    /* Plugin entry point */
reserv1:           .long 0x0
dcd_ptr:           .long 0x0
boot_data_ptr:     .long 0xF8006420
self_ptr:          .long 0xF8006400
app_code_csf:      .long 0x0 	       /* reserve 4K for csf */
reserv2:           .long 0x0
boot_data:         .long 0xF8006000
image_len:         .long 8*1024        /* Can copy upto 72K, OCRAM free space */
plugin:            .long 0x1  	       /* Enable plugin flag */

/* Second IVT to give entry point into the bootloader copied to DDR */
ivt2_header:       .long 0x402000D1    //Tag=0xD1, Len=0x0020, Ver=0x40
app2_code_jump_v:  .long _start   // Entry point for the bootloader
reserv3:           .long 0x0
dcd2_ptr:          .long 0x0
boot_data2_ptr:    .long boot_data2
self_ptr2:         .long ivt2_header
app_code_csf2:     .long 0x0 // reserve 4K for csf
reserv4:           .long 0x0
boot_data2:        .long TEXT_BASE
image_len2:        .long _end - TEXT_BASE
plugin2:           .long 0x0

/*=============================================================================
 * Here starts the plugin code
 *===========================================================================*/

plugin_start:
/* Save the return address and the function arguments */
	push    {r0-r2, lr}

/*=============================================================================
 *init script for codex LPDDR1-200MHz CPU board
 *===========================================================================*/

/* Setup PLL1 to be 800 MHz */
	ldr r0, =CCM_BASE_ADDR

/* Switch ARM domain to be clocked from LP-APM */
	mov r1, #0x4
	str r1, [r0, #CLKCTL_CCSR]

	ldr r0, =PLL1_BASE_ADDR
	ldr r1, =0x1232
	str r1, [r0, #PLL_DP_CTL]     /* Set DPLL ON (set UPEN bit); BRMO=1 */
	ldr r1, =0x2
	str r1, [r0, #PLL_DP_CONFIG]  /* Enable auto-restart AREN bit */

	ldr r1, =DP_OP_800
	str r1, [r0, #PLL_DP_OP]
	str r1, [r0, #PLL_DP_HFS_OP]

	ldr r1, =DP_MFD_800
	str r1, [r0, #PLL_DP_MFD]
	str r1, [r0, #PLL_DP_HFS_MFD]

	ldr r1, =DP_MFN_800
	str r1, [r0, #PLL_DP_MFN]
	str r1, [r0, #PLL_DP_HFS_MFN]

	/* Now restart PLL */
	ldr r1, =0x1232
	str r1, [r0, #PLL_DP_CTL]
wait_pll1_lock:
	ldr r1, [r0, #PLL_DP_CTL]
	ands r1, r1, #0x1
	beq wait_pll1_lock

/* Switch ARM back to PLL1 */
	ldr r0, =CCM_BASE_ADDR
	ldr r1, =0x0
	str r1, [r0,#CLKCTL_CCSR]

/*=============================================================================
 * Enable all clocks (they are disabled by ROM code)
 *===========================================================================*/

	mov r1, #0xffffffff
	str r1, [r0, #0x68]
	str r1, [r0, #0x6c]
	str r1, [r0, #0x70]
	str r1, [r0, #0x74]
	str r1, [r0, #0x78]
	str r1, [r0, #0x7c]
	str r1, [r0, #0x80]
	str r1, [r0, #0x84]

#if defined(CONFIG_LPDDR2)

/* DDR clock setting -- Set DDR to be div 3 to get 266MHz */
/* setmem /32 0x53FD4098 = 0x80000003 */
	ldr r1, =0x80000003
	str r1, [r0, #0x98]

/* poll to make sure DDR dividers take effect */
1:
	ldr r1, [r0, #0x8c]
	ands r1, r1, #0x4
	bne 1b

/*=============================================================================
 * IOMUX
 *===========================================================================*/
	ldr r0, =0x53fa8000
	mov r1, #0x04000000
	str r1, [r0, #0x6ac]
	mov r2, #0x00380000
	str r2, [r0, #0x6a4]
	str r2, [r0, #0x668]
	str r2, [r0, #0x698]
	str r2, [r0, #0x6a0]
	str r2, [r0, #0x6a8]
	str r2, [r0, #0x6b4]
	str r2, [r0, #0x498]
	str r2, [r0, #0x49c]
        str r2, [r0, #0x4f0]
        str r2, [r0, #0x500]
        str r2, [r0, #0x4c8]
        str r2, [r0, #0x528]
        str r2, [r0, #0x4f4]
        str r2, [r0, #0x4fc]
        str r2, [r0, #0x4cc]
        str r2, [r0, #0x524]

/*=============================================================================
 * DDR setting
 *===========================================================================*/

	ldr r0, =DATABAHN_BASE_ADDR
/* setmem /32 0x14000000	= 0x00000500 */
	ldr r1, =0x00000500
	str r1, [r0, #0x0]
/* setmem /32 0x14000004	= 0x00000000 */
	ldr r1, =0x00000000
	str r1, [r0, #0x4]
/* setmem /32 0x14000008	= 0x0000001b */
	ldr r1, =0x0000001b
	str r1, [r0, #0x8]
/* setmem /32 0x1400000c	= 0x0000d056 */
	ldr r1, =0x0000d056
	str r1, [r0, #0xc]
/* setmem /32 0x14000010	= 0x0000010b */
	ldr r1, =0x0000010b
	str r1, [r0, #0xc]
/* setmem /32 0x14000014	= 0x00000a6b */
	ldr r1, =0x00000a6b
	str r1, [r0, #0x14]
/* setmem /32 0x14000018	= 0x02020d0c */
        ldr r1, =0x02020d0c
        str r1, [r0, #0x18]
/* setmem /32 0x1400001c	= 0x0c110302 */
	ldr r1, =0x0c110302
	str r1, [r0, #0x1c]
/* setmem /32 0x14000020	= 0x05020503 */
	ldr r1, =0x05020503
	str r1, [r0, #0x20]
/* setmem /32 0x14000024	= 0x00000105 */
	ldr r1, =0x00000105
	str r1, [r0, #0x24]
/* setmem /32 0x14000028	= 0x01000403 */
	ldr r1, =0x01000403
	str r1, [r0, #0x28]
/* setmem /32 0x1400002c	= 0x09040501 */
	ldr r1, =0x09040501
	str r1, [r0, #0x2c]
/* setmem /32 0x14000030	= 0x02000000 */
	ldr r1, =0x02000000
	str r1, [r0, #0x30]
/* setmem /32 0x14000034	= 0x00000e02 */
	ldr r1, =0x00000e02
	str r1, [r0, #0x34]
/* setmem /32 0x14000038	= 0x00000006 */
	ldr r1, =0x00000006
	str r1, [r0, #0x38]
/* setmem /32 0x1400003c	= 0x00002301 */
	ldr r1, =0x00002301
	str r1, [r0, #0x3c]
/* setmem /32 0x14000040	= 0x00050408 */
	ldr r1, =0x00050408
	str r1, [r0, #0x40]
/* setmem /32 0x14000044	= 0x00000300 */
	ldr r1, =0x00000300
	str r1, [r0, #0x44]
/* setmem /32 0x14000048	= 0x00260026 */
	ldr r1, =0x00260026
	str r1, [r0, #0x48]
/* setmem /32 0x1400004c	= 0x00010000 */
	ldr r1, =0x00010000
	str r1, [r0, #0x4c]
/* setmem /32 0x1400005c	= 0x02000000 */
	ldr r1, =0x02000000
	str r1, [r0, #0x5c]
/* setmem /32 0x14000060	= 0x00000002 */
	ldr r1, =0x00000002
	str r1, [r0, #0x60]
/* setmem /32 0x14000064	= 0x00000000 */
	ldr r1, =0x00000000
	str r1, [r0, #0x64]
/* setmem /32 0x14000068	= 0x00000000 */
	ldr r1, =0x00000000
	str r1, [r0, #0x68]
/* setmem /32 0x1400006c	= 0x00040042 */
	ldr r1, =0x00040042
	str r1, [r0, #0x6c]
/* setmem /32 0x14000070	= 0x00000001 */
	ldr r1, =0x00000001
	str r1, [r0, #0x70]
/* setmem /32 0x14000074	= 0x00000000 */
	ldr r1, =0x00000001
	str r1, [r0, #0x74]
/* setmem /32 0x14000078	= 0x00040042 */
	ldr r1, =0x00040042
	str r1, [r0, #0x78]
/* setmem /32 0x1400007c	= 0x00000001 */
	ldr r1, =0x00000001
	str r1, [r0, #0x7c]
/* setmem /32 0x14000080	= 0x010b0000 */
	ldr r1, =0x010b0000
	str r1, [r0, #0x80]
/* setmem /32 0x14000084	= 0x00000060 */
	ldr r1, =0x00000060
	str r1, [r0, #0x84]
/* setmem /32 0x14000088	= 0x02400018 */
        ldr r1, =0x02400018
        str r1, [r0, #0x88]
/* setmem /32 0x1400008c	= 0x01000e00 */
        ldr r1, =0x01000e00
        str r1, [r0, #0x8c]
/* setmem /32 0x14000090	= 0x0a010101 */
        ldr r1, =0x0a010101
        str r1, [r0, #0x90]
/* setmem /32 0x14000094	= 0x01011f1f */
        ldr r1, =0x01011f1f
        str r1, [r0, #0x94]
/* setmem /32 0x14000098	= 0x01010101 */
        ldr r1, =0x01010101
        str r1, [r0, #0x98]
/* setmem /32 0x1400009c	= 0x00030101 */
        ldr r1, =0x00030101
        str r1, [r0, #0x9c]
/* setmem /32 0x140000a0	= 0x00010000 */
        ldr r1, =0x00010000
        str r1, [r0, #0xa0]
/* setmem /32 0x140000a4	= 0x00010000 */
        ldr r1, =0x00010000
        str r1, [r0, #0xa4]
/* setmem /32 0x140000a8	= 0x00000000 */
        ldr r1, =0x00000000
        str r1, [r0, #0xa8]
/* setmem /32 0x140000ac	= 0x0000ffff */
        ldr r1, =0x0000ffff
        str r1, [r0, #0xac]
/* setmem /32 0x140000c8	= 0x02020101 */
        ldr r1, =0x02020101
        str r1, [r0, #0xc8]
/* setmem /32 0x140000cc	= 0x01000000 */
        ldr r1, =0x01000000
        str r1, [r0, #0xcc]
/* setmem /32 0x140000d0	= 0x01000201 */
        ldr r1, =0x01000201
        str r1, [r0, #0xd0]
/* setmem /32 0x140000d4	= 0x00000200 */
        ldr r1, =0x00000200
        str r1, [r0, #0xd4]
/* setmem /32 0x140000d8	= 0x00000102 */
        ldr r1, =0x00000102
        str r1, [r0, #0xd8]
/* setmem /32 0x140000dc	= 0x0000ffff */
        ldr r1, =0x0000ffff
        str r1, [r0, #0xdc]
/* setmem /32 0x140000e0	= 0x0000ffff */
        ldr r1, =0x0000ffff
        str r1, [r0, #0xdc]
/* setmem /32 0x140000e4	= 0x02020000 */
        ldr r1, =0x02020000
        str r1, [r0, #0xe4]
/* setmem /32 0x140000e8	= 0x02020202 */
        ldr r1, =0x02020202
        str r1, [r0, #0xe8]
/* setmem /32 0x140000ec	= 0x00000202 */
        ldr r1, =0x00000202
        str r1, [r0, #0xec]
/* setmem /32 0x140000f0	= 0x01010064 */
        ldr r1, =0x01010064
        str r1, [r0, #0xf0]
/* setmem /32 0x140000f4	= 0x01010101 */
        ldr r1, =0x01010101
        str r1, [r0, #0xf4]
/* setmem /32 0x140000f8	= 0x00010101 */
        ldr r1, =0x00010101
        str r1, [r0, #0xf8]
/* setmem /32 0x140000fc	= 0x00000064 */
        ldr r1, =0x00000064
        str r1, [r0, #0xfc]
/* setmem /32 0x14000100	= 0x00000000 */
        ldr r1, =0x00000000
        str r1, [r0, #0x100]
/* setmem /32 0x14000104	= 0x02000802 */
        ldr r1, =0x02000802
        str r1, [r0, #0x104]
/* setmem /32 0x14000108	= 0x04080000 */
        ldr r1, =0x04080000
        str r1, [r0, #0x108]
/* setmem /32 0x1400010c	= 0x04080408 */
        ldr r1, =0x04080408
        str r1, [r0, #0x10c]
/* setmem /32 0x14000110	= 0x04080408 */
        ldr r1, =0x04080408
        str r1, [r0, #0x110]
/* setmem /32 0x14000114	= 0x03060408 */
        ldr r1, =0x03060408
        str r1, [r0, #0x114]
/* setmem /32 0x14000118	= 0x01010002 */
        ldr r1, =0x01010002
        str r1, [r0, #0x118]
/* setmem /32 0x1400011c	= 0x00000000 */
        ldr r1, =0x00000000
        str r1, [r0, #0x11c]
/* setmem /32 0x14000200	= 0x00000000 */
	ldr r1, =0x00000000
	str r1, [r0, #0x200]
/* setmem /32 0x14000204	= 0x00000000 */
	ldr r1, =0x00000000
	str r1, [r0, #0x204]
/* setmem /32 0x14000208	= 0xf5003a27 */
	ldr r1, =0xf5003a27
	str r1, [r0, #0x208]
/* setmem /32 0x1400020c	= 0x074002e1 */
	ldr r1, =0x074002e1
	str r1, [r0, #0x20c]
/* setmem /32 0x14000210	= 0xf5003a27 */
	ldr r1, =0xf5003a27
	str r1, [r0, #0x210]
/* setmem /32 0x14000214	= 0x074002e1 */
	ldr r1, =0x074002e1
	str r1, [r0, #0x214]
/* setmem /32 0x14000218	= 0xf5003a27 */
	ldr r1, =0xf5003a27
	str r1, [r0, #0x218]
/* setmem /32 0x1400021c	= 0x074002e1 */
	ldr r1, =0x074002e1
	str r1, [r0, #0x21c]
/* setmem /32 0x14000220	= 0xf5003a27 */
	ldr r1, =0xf5003a27
	str r1, [r0, #0x220]
/* setmem /32 0x14000224	= 0x074002e1 */
	ldr r1, =0x074002e1
	str r1, [r0, #0x224]
/* setmem /32 0x14000228	= 0xf5003a27 */
	ldr r1, =0xf5003a27
	str r1, [r0, #0x228]
/* setmem /32 0x1400022c	= 0x074002e1 */
	ldr r1, =0x074002e1
	str r1, [r0, #0x22c]
/* setmem /32 0x14000230	= 0x00000000 */
	ldr r1, =0x00000000
	str r1, [r0, #0x230]
/* setmem /32 0x14000234	= 0x00810006 */
	ldr r1, =0x00810006
	str r1, [r0, #0x234]
/* setmem /32 0x14000238	= 0x20099414 */
	ldr r1, =0x20099414
	str r1, [r0, #0x238]
/* setmem /32 0x1400023c	= 0x000a1401 */
	ldr r1, =0x000a1401
	str r1, [r0, #0x23c]
/* setmem /32 0x14000240	= 0x20099414 */
	ldr r1, =0x20099414
	str r1, [r0, #0x240]
/* setmem /32 0x14000244	= 0x000a1401 */
	ldr r1, =0x000a1401
	str r1, [r0, #0x244]
/* setmem /32 0x14000248	= 0x20099414 */
	ldr r1, =0x20099414
	str r1, [r0, #0x248]
/* setmem /32 0x1400024c	= 0x000a1401 */
	ldr r1, =0x000a1401
	str r1, [r0, #0x24c]
/* setmem /32 0x14000250	= 0x20099414 */
	ldr r1, =0x20099414
	str r1, [r0, #0x250]
/* setmem /32 0x14000254	= 0x000a1401 */
	ldr r1, =0x000a1401
	str r1, [r0, #0x254]
/* setmem /32 0x14000258	= 0x20099414 */
	ldr r1, =0x000a1401
	str r1, [r0, #0x258]
/* setmem /32 0x1400025c	= 0x000a1401 */
	ldr r1, =0x000a1401
	str r1, [r0, #0x25c]

/* Start ddr */
/* setmem /32 0x14000000 = 0x00000501  // bit[0]: start */
	ldr r1, =0x00000501
	str r1, [r0, #0x0]
/* poll to make sure it is done */
1:
	ldr r1, [r0, #0xa8]
	ands r1, r1, #0x10
	beq 1b
#else

/*==================================================================
 * lpddr1-mddr
 *=================================================================*/

/* DDR clock setting -- Set DDR to be div 4 to get 200MHz */
/* setmem /32 0x53FD4098 = 0x80000004 */
	ldr r1, =0x80000004
	str r1, [r0, #0x98]

/* poll to make sure DDR dividers take effect */
1:
    ldr r1, [r0, #0x8c]
    ands r1, r1, #0x4
    bne 1b

/*==================================================================
 * IOMUX
 *=================================================================*/
	ldr r0, =0x53fa8600
	mov r1, #0x02000000
	mov r3, #0x00200000
	mov r2, #0x0
	str r1, [r0, #0xac]
	str r2, [r0, #0x6c]
	str r2, [r0, #0x8c]
	str r3, [r0, #0xa4]
	str r3, [r0, #0x68]
	str r3, [r0, #0x98]
	str r3, [r0, #0xa0]
	str r3, [r0, #0xa8]
	str r3, [r0, #0xb4]

	ldr r0, =0x53fa8400
	str r3, [r0, #0x98]
	str r3, [r0, #0x9c]
	str r3, [r0, #0xf0]
	str r3, [r0, #0x100]
	str r3, [r0, #0xc8]
	str r3, [r0, #0x128]
	str r3, [r0, #0xf4]
	str r3, [r0, #0xfc]
	str r3, [r0, #0xcc]
	str r3, [r0, #0x124]
	str r2, [r0, #0x270]

/*==============================================================
 *  DDR setting
 *=============================================================*/
	ldr r0, =DATABAHN_BASE_ADDR
/* setmem /32 0x14000000 = 0x00000100 */
	ldr r1, =0x00000100
	str r1, [r0, #0x0]
/* setmem /32 0x14000008 = 0x00009c40 */
	ldr r1, =0x00009c40
	str r1, [r0, #0x8]
/* setmem /32 0x14000014 = 0x02000000 */
	ldr r1, =0x02000000
	str r1, [r0, #0x14]
/* setmem /32 0x14000018 = 0x01010706 */
	ldr r1, =0x01010706
	str r1, [r0, #0x018]
/* setmem /32 0x1400001c = 0x080b0201 */
	ldr r1, =0x080b0201
	str r1, [r0, #0x01c]
/* setmem /32 0x14000020 = 0x02000303 */
	ldr r1, =0x02000303
	str r1, [r0, #0x020]
/* setmem /32 0x14000024 = 0x0136b002 */
	ldr r1, =0x0136b002
	str r1, [r0, #0x024]
/* setmem /32 0x14000028 = 0x01000101 */
	ldr r1, =0x01000101
	str r1, [r0, #0x028]
/* setmem /32 0x1400002c = 0x06030301 */
	ldr r1, =0x06030301
	str r1, [r0, #0x02c]
/* setmem /32 0x14000030 = 0x00000000 */
	ldr r1, =0x00000000
	str r1, [r0, #0x030]
/* setmem /32 0x14000034 = 0x00000a02 */
	ldr r1, =0x00000a02
	str r1, [r0, #0x034]
/* setmem /32 0x14000038 = 0x00000003 */
	ldr r1, =0x00000003
	str r1, [r0, #0x038]
/* setmem /32 0x1400003c = 0x00001401 */
	ldr r1, =0x00001401
	str r1, [r0, #0x03c]
/* setmem /32 0x14000040 = 0x0005030f */
	ldr r1, =0x0005030f
	str r1, [r0, #0x040]
/* setmem /32 0x14000044 = 0x00000200 */
	ldr r1, =0x00000200
	str r1, [r0, #0x044]
/* setmem /32 0x14000048 = 0x00180018 */
	ldr r1, =0x00180018
	str r1, [r0, #0x048]
/* setmem /32 0x1400004c = 0x00010000 */
	ldr r1, =0x00010000
	str r1, [r0, #0x04c]
/* setmem /32 0x1400005c = 0x01000000 */
	ldr r1, =0x01000000
	str r1, [r0, #0x05c]
/* setmem /32 0x14000060 = 0x00000001 */
	ldr r1, =0x00000001
	str r1, [r0, #0x060]
/* setmem /32 0x14000064 = 0x00000000 */
	ldr r1, =0x00000000
	str r1, [r0, #0x064]
/* setmem /32 0x14000068 = 0x00320000 */
	ldr r1, =0x00320000
	str r1, [r0, #0x068]
/* setmem /32 0x1400006c = 0x00000000 */
	ldr r1, =0x00000000
	str r1, [r0, #0x06c]
/* setmem /32 0x14000070 = 0x00000000 */
	ldr r1, =0x00000000
	str r1, [r0, #0x070]
/* setmem /32 0x14000074 = 0x00320000 */
	ldr r1, =0x00320000
	str r1, [r0, #0x074]
/* setmem /32 0x14000080 = 0x02000000 */
	ldr r1, =0x02000000
	str r1, [r0, #0x080]
/* setmem /32 0x14000084 = 0x00000100 */
	ldr r1, =0x00000100
	str r1, [r0, #0x084]
/* setmem /32 0x14000088 = 0x02400040 */
	ldr r1, =0x02400040
	str r1, [r0, #0x088]
/* setmem /32 0x1400008c = 0x01000000 */
	ldr r1, =0x01000000
	str r1, [r0, #0x08c]
/* setmem /32 0x14000090 = 0x0a000100 */
	ldr r1, =0x0a000100
	str r1, [r0, #0x090]
/* setmem /32 0x14000094 = 0x01011f1f */
	ldr r1, =0x01011f1f
	str r1, [r0, #0x094]
/* setmem /32 0x14000098 = 0x01010101 */
	ldr r1, =0x01010101
	str r1, [r0, #0x098]
/* setmem /32 0x1400009c = 0x00030101 */
	ldr r1, =0x00030101
	str r1, [r0, #0x09c]
/* setmem /32 0x140000a4 = 0x00010000 */
	ldr r1, =0x00010000
	str r1, [r0, #0x0a4]
/* setmem /32 0x140000ac = 0x0000ffff */
	ldr r1, =0x0000ffff
	str r1, [r0, #0x0ac]
/* setmem /32 0x140000c8 = 0x02020101 */
	ldr r1, =0x02020101
	str r1, [r0, #0x0c8]
/* setmem /32 0x140000cc = 0x00000000 */
	ldr r1, =0x00000000
	str r1, [r0, #0x0cc]
/* setmem /32 0x140000d0 = 0x01000202 */
	ldr r1, =0x01000202
	str r1, [r0, #0x0d0]
/* setmem /32 0x140000d4 = 0x02030302 */
	ldr r1, =0x02030302
	str r1, [r0, #0x0d4]
/*  setmem /32 0x140000d8 = 0x00000001 */
	ldr r1, =0x00000001
	str r1, [r0, #0x0d8]
/* setmem /32 0x140000dc = 0x0000ffff */
	ldr r1, =0x0000ffff
	str r1, [r0, #0x0dc]
/* setmem /32 0x140000e0 = 0x0000ffff */
	ldr r1, =0x0000ffff
	str r1, [r0, #0x0e0]
/* setmem /32 0x140000e4 = 0x02020000 */
	ldr r1, =0x02020000
	str r1, [r0, #0x0e4]
/* setmem /32 0x140000e8 = 0x02020202 */
	ldr r1, =0x02020202
	str r1, [r0, #0x0e8]
/* setmem /32 0x140000ec = 0x00000202 */
	ldr r1, =0x00000202
	str r1, [r0, #0x0ec]
/* setmem /32 0x140000f0 = 0x01010064 */
	ldr r1, =0x01010064
	str r1, [r0, #0x0f0]
/* setmem /32 0x140000f4 = 0x01010101 */
	ldr r1, =0x01010101
	str r1, [r0, #0x0f4]
/* setmem /32 0x140000f8 = 0x00010101 */
	ldr r1, =0x00010101
	str r1, [r0, #0x0f8]
/* setmem /32 0x140000fc = 0x00000064 */
	ldr r1, =0x00000064
	str r1, [r0, #0x0fc]
/* setmem /32 0x14000104 = 0x02000602 */
	ldr r1, =0x02000602
	str r1, [r0, #0x0104]
/* setmem /32 0x14000108 = 0x06120000 */
	ldr r1, =0x06120000
	str r1, [r0, #0x0108]
/* setmem /32 0x1400010c = 0x06120612 */
	ldr r1, =0x06120612
	str r1, [r0, #0x010c]
/* setmem /32 0x14000110 = 0x06120612 */
	ldr r1, =0x06120612
	str r1, [r0, #0x0110]
/* setmem /32 0x14000114 = 0x01030612 */
	ldr r1, =0x01030612
	str r1, [r0, #0x0114]
/* setmem /32 0x14000118 = 0x01010002 */
	ldr r1, =0x01010002
	str r1, [r0, #0x0118]

/*=============================================================
 *  DDR PHY setting
 *===========================================================*/

/* setmem /32 0x14000200 = 0x00000000 */
	ldr r1, =0x00000000
	str r1, [r0, #0x200]
/* setmem /32 0x14000204 = 0x00000000 */
	ldr r1, =0x00000000
	str r1, [r0, #0x0204]

/* setmem /32 0x14000208 = 0xf5002725 */
	ldr r1, =0xf5002725
	str r1, [r0, #0x0208]
/* setmem /32 0x14000210 = 0xf5002725 */
	ldr r1, =0xf5002725
	str r1, [r0, #0x210]
/* setmem /32 0x14000218 = 0xf5002725 */
	ldr r1, =0xf5002725
	str r1, [r0, #0x218]
/* setmem /32 0x14000220 = 0xf5002725 */
	ldr r1, =0xf5002725
	str r1, [r0, #0x0220]
/* setmem /32 0x14000228 = 0xf5002725 */
	ldr r1, =0xf5002725
	str r1, [r0, #0x0228]

/* setmem /32 0x1400020c = 0x070002d0 */
	ldr r1, =0x070002d0
	str r1, [r0, #0x020c]

/* setmem /32 0x14000214 = 0x074002d0 */
	ldr r1, =0x074002d0
	str r1, [r0, #0x0214]

/* setmem /32 0x1400021c = 0x074002d0 */
	ldr r1, =0x074002d0
	str r1, [r0, #0x021c]

/* setmem /32 0x14000224 = 0x074002d0 */
	ldr r1, =0x074002d0
	str r1, [r0, #0x0224]

/* setmem /32 0x1400022c = 0x074002d0 */
	ldr r1, =0x074002d0
	str r1, [r0, #0x022c]
/* setmem /32 0x14000230 = 0x00000000 */
	ldr r1, =0x00000000
	str r1, [r0, #0x0230]
/* setmem /32 0x14000234 = 0x00800006 */
	ldr r1, =0x00800006
	str r1, [r0, #0x0234]

/* setmem /32 0x14000238 = 0x200e1014 */
	ldr r1, =0x200e1014
	str r1, [r0, #0x0238]
/* setmem /32 0x14000240 = 0x200e1014 */
	ldr r1, =0x200e1014
	str r1, [r0, #0x0240]
/* setmem /32 0x14000248 = 0x200e1014 */
	ldr r1, =0x200e1014
	str r1, [r0, #0x0248]
/* setmem /32 0x14000250 = 0x200e1014 */
	ldr r1, =0x200e1014
	str r1, [r0, #0x0250]
/* setmem /32 0x14000258 = 0x200e1014 */
	ldr r1, =0x200e1014
	str r1, [r0, #0x0258]

/* setmem /32 0x1400023c = 0x000d9f01 */
	ldr r1, =0x000d9f01
	str r1, [r0, #0x023c]
/* setmem /32 0x14000244 = 0x000d9f01 */
	ldr r1, =0x000d9f01
	str r1, [r0, #0x0244]
/* setmem /32 0x1400024c = 0x000d9f01 */
	ldr r1, =0x000d9f01
	str r1, [r0, #0x024c]
/* setmem /32 0x14000254 = 0x000d9f01 */
	ldr r1, =0x000d9f01
	str r1, [r0, #0x0254]
/* setmem /32 0x1400025c = 0x000d9f01 */
	ldr r1, =0x000d9f01
	str r1, [r0, #0x025c]

/* Start ddr */
/* setmem /32 0x14000000 = 0x00000101  // bit[0]: start */
	ldr r1, =0x00000101
	str r1, [r0, #0x0]
/* poll to make sure it is done */
1:
	ldr r1, [r0, #0xa8]
	ands r1, r1, #0x10
	beq 1b

#endif

/*
 * The following is to fill in those arguments for this ROM function
 * pu_irom_hwcnfg_setup(void **start, size_t *bytes, const void *boot_data)
 *
 * This function is used to copy data from the storage media into DDR.

 * start - Initial (possibly partial) image load address on entry.
 * Final image load address on exit.
 * bytes - Initial (possibly partial) image size on entry.
 * Final image size on exit.
 * boot_data - Initial @ref ivt Boot Data load address.
 */
	adr r0, DDR_DEST_ADDR
	adr r1, COPY_SIZE
	adr r2, BOOT_DATA

before_calling_rom___pu_irom_hwcnfg_setup:
	mov r4, #0x2a00
	add r4, r4, #0x19
	blx r4 // This address might change in future ROM versions
after_calling_rom___pu_irom_hwcnfg_setup:


/* To return to ROM from plugin, we need to fill in these argument.
 * Here is what need to do:
 * Need to construct the paramters for this function before return to ROM:
 * plugin_download(void **start, size_t *bytes, UINT32 *ivt_offset)
 */
	pop {r0-r2, lr}
	ldr r3, DDR_DEST_ADDR
	str r3, [r0]
	ldr r3, COPY_SIZE
	str r3, [r1]
	mov r3, #0x400  /* Point to the second IVT table at offset 0x42C */
	add r3, r3, #0x2C
	str r3, [r2]
	mov r0, #1
	bx lr          /* return back to ROM code */

DDR_DEST_ADDR:    .word   0x77800000
COPY_SIZE:        .word   0x40000
BOOT_DATA:        .word   0x77800000
                  .word   0x40000 /*data be copied by pu_irom_hwcnfg_setup()*/
                  .word   0

#endif
