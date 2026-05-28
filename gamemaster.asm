; Game Master (MSX, Konami, 1985, RC-735)
; Disassembled by Ricardo Bittencourt (bluepenguin@gmail.com)
; Last update at 2026-05-28
;
	output "gamemaster.bin"
	org 04000h

RLE_COMPRESSED_OUTPUT            equ     0C002h    ; Output buffer for RLE_COMPRESS_VRAM_BUFFER (encoded form of RLE_RAW_INPUT)
RETURN_FROM_DISK_BASIC_RAM       equ     0C800h    ; RAM-resident copy of RETURN_FROM_DISK_BASIC; jp here returns from Disk BASIC
RLE_RAW_INPUT                    equ     0C802h    ; 2KB uncompressed VRAM mirror; source of RLE_COMPRESS_VRAM_BUFFER
INTERSLOT_CALL_TARGET_PTR_DUP    equ     0D0A3h    ; Backup pointer to INTERSLOT_CALL_TARGET written by SETUP_INTERSLOT_CALL
FCB_BUFFER                       equ     0D100h    ; FCB scratch buffer (also default destination via FCB_POINTER)
FCB_NAME                         equ     0D101h    ; FCB+1: 8-byte filename area
FCB_EXT                          equ     0D109h    ; FCB+9: 3-byte extension area
FCB_CURRENT_BLOCK                equ     0D10Ch    ; FCB+0Ch: current block field (cleared before BDOS ops)
FCB_POINTER                      equ     0D125h    ; Pointer to a 0Ch+ byte FCB used by BDOS file operations
SP_SAVE_FOR_BDOS                 equ     0D127h    ; Saved SP before disk/print operations; restored on abort/error
TOP_MENU_MODE                    equ     0D129h    ; 1=SELF/GAME, 2=MODIFY — set by the top-menu handler before dispatch
GAME_DISPLAY_SAVED               equ     0D12Ah    ; FFh once SAVE_GAME_DISPLAY stashed it; cleared by RESTORE_GAME_DISPLAY
SAVED_PSG_VOL_A                  equ     0D12Bh    ; Channel A volume saved before the menu mutes the PSG
SAVED_PSG_VOL_B                  equ     0D12Ch    ; Channel B volume saved before the menu mutes the PSG
SAVED_PSG_VOL_C                  equ     0D12Dh    ; Channel C volume saved before the menu mutes the PSG
OWN_SLOT_RAW                     equ     0D12Eh    ; This cart's slot byte from GET_PAGE1_SLOT; used to skip self during scan
GAME_CART_SLOT                   equ     0D12Fh    ; Assumed game-cart slot byte = OWN_SLOT_RAW + (4 if expanded else 1)
GAME_TICK_CALLBACK_PTR           equ     0D130h    ; Word read by the ISR as IX before BIOS_CALSLT (game's per-frame tick handler)
GAME_CART_INIT_POINTER           equ     0D132h    ; Init address read from the game cart's header word at 4002h
MENU_ACTIVE_FLIPFLOP             equ     0D134h    ; Toggled by TOGGLE_MENU_FROM_GAME each F5 press (open / close the menu)
GAME_STATE                       equ     0D135h    ; Game-state byte; ISR dispatches to in-game handler when nonzero
IN_GAME_MENU_PARAM               equ     0D136h    ; Byte read from IN_GAME_MENU_PARAMS for the selected in-game menu entry
GAME_INPUT_BITFIELD              equ     0D137h    ; Last-frame-detected input keys (F5/cursor); used for edge detection
GAME_INPUT_PREVIOUS              equ     0D138h    ; Previous-frame input bitfield from READ_CURSOR_AND_SPACE (edge-detect base)
ISR_SCRATCH_BYTE_1               equ     0D139h    ; Cleared by HKEYI_ON_F5_PRESS — unknown ISR scratch byte
ISR_SCRATCH_BYTE_2               equ     0D13Ah    ; Cleared by HKEYI_ON_F5_PRESS — unknown ISR scratch byte
IN_ISR_LOCK                      equ     0D13Bh    ; Set to 1 around the ISR body so a long routine can't re-enter the ISR
GAME_CART_VALID_FLAG             equ     0D13Ch    ; FFh after successful game-cart verify+identify; 00h on BOOT_SKIP_INIT
GAME_DISPLAY_ACTIVE              equ     0D13Dh    ; FFh when game's pattern/name-table is on screen (gates save/restore)
RLE_RUN_HEADER_BYTE              equ     0D13Eh    ; In-progress run-header byte (high bit = run vs literal, low 7 = length)
RLE_RUN_HEADER_PTR               equ     0D13Fh    ; Pointer into RLE_COMPRESSED_OUTPUT where the in-progress run header byte goes
SAVED_GAME_ID                    equ     0D141h    ; ENTER_SELF stash slot for GAME_ID (restored by SELF_EXIT_RESTORE_GAME_ID)
NAME_INPUT_BUFFER                equ     0D142h    ; 32-byte working buffer used by RUN_NAME_INPUT_LOOP (typed chars)
MENU_RICH_BLINK_STATE            equ     0D144h    ; MENU_SELECT_RICH animation tick state (which tile half is shown)
MENU_RICH_BLINK_COUNTER          equ     0D147h    ; 16-bit idle counter incremented on every menu poll (drives blink)
MENU_SELECTED_INDEX              equ     0D163h    ; Final cursor index after MENU_SELECT picks (SPACE) — pre-restored on cancel
MENU_MAX_INDEX                   equ     0D164h    ; B-1 captured by MENU_SELECT — clamp for cursor up/down
MENU_CURRENT_INDEX               equ     0D165h    ; Live cursor index during MENU_SELECT navigation (clamped via MENU_MAX_INDEX)
NAME_INPUT_DECIMAL_FLAG          equ     0D166h    ; RUN_NAME_INPUT_LOOP: set when '.' was typed (FEh escape mode)
NAME_INPUT_FE_FLAG               equ     0D167h    ; RUN_NAME_INPUT_LOOP: state byte tracking the FEh escape-prefix toggle
MENU_CURSOR_VRAM_ADDR            equ     0D168h    ; VRAM tile address of the cursor cell on the currently-highlighted row
MENU_TABLE_PTR                   equ     0D16Ah    ; Source-table pointer captured by MENU_SELECT
SUBMENU_HEADING_VRAM_BASE        equ     0D16Ch    ; Default heading VRAM row base for the active screen (3A21h or 3921h)
MENU_CLEAR_RANGE_THRESHOLD       equ     0D16Dh    ; Compared to 3Ah at 62C4 to pick top vs bottom VRAM clear-row base
SUBMENU_BODY_VRAM_BASE           equ     0D16Eh    ; Default body VRAM row base for the active screen (3A2Ch or 392Ch)
GAME_RC_CODE_HIGH                equ     0D300h    ; High byte of the 2-byte BCD RC catalog code; paired with GAME_ID
GAME_ID                          equ     0D301h    ; Selected game's catalog code byte; FFh = none (BOOT_SKIP_INIT default)
GAME_STAGE_CHEAT_FLAG            equ     0D302h    ; FFh when no per-game STAGE cheat available (skips STAGE_CHEAT_DISPATCH lookup)
GAME_STAGE_LUT_SELECT            equ     0D303h    ; 0=use STAGE_ANTARCTIC_LUT_DEFAULT, !=0=use _VARIANT for stage-cheat
GAME_RAM_TRIGGER_PTR             equ     0D304h    ; Game RAM word: state-transition byte address (ON_GAME_STATE writes 7/9)
GAME_RAM_RANKING_PTR             equ     0D306h    ; Game RAM word: pointer to the ranking-enable flag byte (CD-header bit 6)
GAME_RAM_LIVES_PTR               equ     0D308h    ; Game RAM word: address of the game's LIVES counter (LIVES cheat target)
GAME_RAM_STAGE_PTR               equ     0D30Ah    ; Game RAM word: address of the game's STAGE counter (STAGE cheat target)
GAME_RAM_HISCORE_PTR             equ     0D30Ch    ; Game RAM word: address of the game's HI SCORE byte (HISCORE save/load)
GAME_RAM_SCORE_1P_PTR            equ     0D30Eh    ; Game RAM word: address of the 1P score (ranking-record source 1)
GAME_RAM_SCORE_2P_PTR            equ     0D310h    ; Game RAM word: address of the 2P score (ranking-record source 2)
GAME_STATE_TRIGGER_VAL           equ     0D312h    ; Value the game-state byte must transition to before cheats fire (default 04h)
GAME_STAGE_COUNT                 equ     0D313h    ; Stage modulus: CHEAT_STAGE_GENERIC computes ((D31A-1) mod D313)+1
GAME_CHEAT_CALLBACK_PTR          equ     0D314h    ; IX-loaded by INVOKE_GAME_CHEAT_CALLBACK: game's per-cheat-trigger callback
GAME_PREV_STATE_BYTE             equ     0D316h    ; ISR cache of the previous game-state value (edge-detect for cheat trigger)
MODIFY_FLAGS                     equ     0D317h    ; Bit field: bit0=LIVES set, bit1/2=STAGE set, bit7=ranking-init set
CHEAT_LIVES_DECIMAL              equ     0D318h    ; LIVES value as decimal (set by MODIFY_LIVES_DEFAULT_PROMPT)
CHEAT_LIVES_HEX                  equ     0D319h    ; LIVES value as packed-BCD byte (paired with CHEAT_LIVES_DECIMAL)
CHEAT_STAGE_DECIMAL              equ     0D31Ah    ; STAGE value as decimal (set by MODIFY_STAGE_DEFAULT_PROMPT)
CHEAT_STAGE_HEX                  equ     0D31Bh    ; STAGE value as packed-BCD byte (paired with CHEAT_STAGE_DECIMAL)
RANKING_INPUT_BUFFER_1P          equ     0D31Ch    ; 1P ranking-entry working area (score block fed to RANKING_RECORD_SCORE)
RANKING_INPUT_BUFFER_2P          equ     0D31Fh    ; 2P ranking-entry working area (paired with RANKING_INPUT_BUFFER_1P)
RANKING_NAME_INPUT_1P            equ     0D322h    ; 8-byte 1P player name typed via RUN_NAME_INPUT_LOOP
RANKING_NAME_INPUT_2P            equ     0D32Ah    ; 8-byte 2P player name typed via RUN_NAME_INPUT_LOOP
RANKING_AVAILABLE_FLAG           equ     0D332h    ; Nonzero when ranking save/load/view is allowed for the current game
SCORE_BACKUP_TAIL                equ     0D333h    ; 3-byte backup buffer chained from SCORE_1P/2P_BACKUP_3B for the ISR alt path
SCORE_1P_BACKUP                  equ     0D335h    ; 3-byte backup of (GAME_RAM_SCORE_1P_PTR) maintained by the ISR
SCORE_2P_BACKUP                  equ     0D338h    ; 3-byte backup of (GAME_RAM_SCORE_2P_PTR) maintained by the ISR
ISR_DISPATCH_FLAG                equ     0D339h    ; Bit 0 selects which ISR position-pair path runs (0=primary, 1=alt)
DISK_BASIC_CALSLT_PAIR           equ     0D33Ah    ; Word whose high byte = DISK_BASIC_SLOT; used as IY for inter-slot CALSLT
DISK_BASIC_SLOT                  equ     0D33Bh    ; Slot/subslot byte where Disk BASIC ROM was located, or unset if absent
INTERSLOT_CALL_TARGET            equ     0D33Ch    ; Trampoline target pointer stashed by SETUP_INTERSLOT_CALL
INTERSLOT_CALL_TRAMPOLINE_RAM    equ     0D33Eh    ; 13-byte trampoline (push iy/ix, rst CALSLT, slot+target, pop, ret)
FILE_LIST_COUNT                  equ     0D34Eh    ; Number of filenames in the file picker list (0..14h, max 20)
SCRATCH_HEADER_OR_DTA            equ     0D351h    ; 108h-byte multi-use scratch: CD-header copy at boot, BDOS DTA, tape header
FILE_PICKER_DTA                  equ     0D352h    ; Disk Transfer Address for F_SFIRST/F_SNEXT during directory scans
FILE_LIST_BUFFER                 equ     0D372h    ; Start of the file-picker's array of 8/11-byte filename slots
RANKING_SCORE_BLOCK              equ     0D459h    ; 30 bytes (10 entries × 3-byte score) for the per-game ranking table
RANKING_NAME_BLOCK               equ     0D477h    ; 90 bytes (10 entries × 9-byte name) paired with RANKING_SCORE_BLOCK
BIOS_WORK_AREA_COPY              equ     0D500h    ; 314h-byte saved copy of BIOS work area F100..F413 (held across game-cart runs)
SAVE_VRAM_NAMETABLE_TOP          equ     0D7B0h    ; 100h-byte save of VRAM 3A00..3AFFh (top half of name table)
GAME_CART_TRAMPOLINE_RAM_END     equ     0D84Fh    ; End of the D814 trampoline; used as offset base by the call-into-cart math
SAVE_VRAM_NAMETABLE_BOT          equ     0D8B0h    ; 100h-byte save of VRAM 3B00..3BFFh (bottom half of name table)
BIOS_WORK_AREA_BACKUP            equ     0D94Fh    ; 2CAh-byte saved BIOS work area FD00..FFC9h, swapped each cart enter/exit
PRINTER_PIXEL_BUFFER             equ     0D9B1h    ; 3C0h-byte printer scratch / pixel-row buffer (cleared with 20h spaces)
SCRATCH_HEX_OUTPUT               equ     0DA00h    ; WRITE_BYTE_AS_ASCII_HEX 2-byte scratch; also title-cursor blink count
TITLE_CURSOR_VRAM_ADDR           equ     0DA01h    ; VRAM address of the title-screen flashing cursor (decremented each frame)
PRINTER_RANKING_VRAM_TGT         equ     0DA41h    ; VRAM target word for the ranking-print routine (DD71 base after init)
PRINTER_CURSOR_PIXEL_XY          equ     0DD71h    ; 16-bit pixel position: low byte = x, high byte = y (printer raster cursor)
PRINTER_CURSOR_Y_BYTE            equ     0DD72h    ; Y byte of PRINTER_CURSOR_PIXEL_XY (high half of the pair)
PRINTER_PIXEL_BYTE_LO            equ     0DD73h    ; Output-byte accumulator low half (printer 16-bit pixel-pair LSB)
PRINTER_PAGE_WIDTH               equ     0DD75h    ; Inner-loop column count for the printer page (typically C0h)
PRINTER_PAGE_HEIGHT              equ     0DD76h    ; Outer-loop row count for the printer page; PRINT_VRAM_AS_GRAPHICS uses /4
STACK_BASE                       equ     0DF80h    ; Top-of-stack address set by GAME_BOOT (`ld sp,STACK_BASE`)
CHEAT_TARGET_ROAD_FIGHTER_E000   equ     0E000h    ; CHEAT_STAGE_ROAD_FIGHTER: game-state byte (set to 8)
CHEAT_TARGET_ROAD_FIGHTER_E001   equ     0E001h    ; CHEAT_STAGE_ROAD_FIGHTER: game-state byte (set to 4)
CHEAT_TARGET_HYPER_OLYMPIC_EVENT equ     0E015h    ; CHEAT_STAGE_HYPER_OLYMPIC: Hyper Olympic event-pair byte
CHEAT_TARGET_ROAD_FIGHTER_LAP    equ     0E042h    ; CHEAT_STAGE_ROAD_FIGHTER: lap/page byte (divmod 6 quotient)
CHEAT_TARGET_LIVES               equ     0E050h    ; LIVES byte for early Konami games (Mopi, Athletic Land, Monkey Academy, ...)
CHEAT_TARGET_LIVES_BCD           equ     0E051h    ; Companion LIVES-BCD byte at E051; Mopiranger pairs this with E050
CHEAT_TARGET_MOPIRANGER_STAGE    equ     0E053h    ; Mopiranger decimal stage (clamped to 50)
CHEAT_TARGET_STAGE_BIN           equ     0E054h    ; Shared binary stage byte (CHEAT_STAGE_BCD/YAK/MT/KV)
CHEAT_TARGET_STAGE_TRIGGER       equ     0E056h    ; Shared stage state byte (CHEAT_STAGE_YAK/MT/KV)
CHEAT_TARGET_KINGS_VALLEY_HI     equ     0E058h    ; King's Valley stage-page byte (KV state at HI-3 and HI-1 too)
CHEAT_TARGET_STAGE_BCD_LO        equ     0E059h    ; Shared BCD-of-(stage-1)*10 byte (CHEAT_STAGE_BCD/YAK)
CHEAT_TARGET_STAGE_BCD_HI        equ     0E05Ah    ; CHEAT_STAGE_BCD: BCD of next-stage*10
CHEAT_TARGET_HYPER_RALLY_PAIR    equ     0E05Bh    ; Hyper Rally: 2-byte course pair copied from HR_TABLE
CHEAT_TARGET_MAGICAL_TREE_E05C   equ     0E05Ch    ; Magical Tree: stage byte
CHEAT_TARGET_MAGICAL_TREE_E05D   equ     0E05Dh    ; Magical Tree: object/index byte (from MT_TABLE_2)
CHEAT_TARGET_HYPER_RALLY_COURSE  equ     0E060h    ; Hyper Rally: course number (1..13)
CHEAT_TARGET_YIE_AR_KUNG_FU_2_MODE equ     0E06Ah    ; Yie Ar Kung-Fu II: mode byte (set to 2)
CHEAT_TARGET_ANTARCTIC_INDEX     equ     0E0E1h    ; Antarctic Adventure: stage index (mod 10)
CHEAT_TARGET_ANTARCTIC_BYTE      equ     0E0E2h    ; Antarctic Adventure: looked-up stage byte from STAGE_E0E2_LUT
CHEAT_TARGET_ANTARCTIC_BACKUP    equ     0E0E8h    ; Antarctic Adventure: stage backup (mirror of E0E1)
CHEAT_TARGET_PIPPOLS_STAGE       equ     0E103h    ; Pippols: stage byte (divmod 8 quotient)
CHEAT_TARGET_BOXING_OPPONENT     equ     0E206h    ; Konami's Boxing: opponent index byte
CHEAT_TARGET_BOXING_ROUND        equ     0E207h    ; Konami's Boxing: encoded round byte
GAME_RAM_SHADOW_E280             equ     0E280h    ; 1100h-byte shadow buffer at E280..F37F for cart-RAM swap (PREPARE/RESTORE_RAM)
GAME_RAM_E000_LAST               equ     0F0FFh    ; Last byte of the E000h game-RAM block (LDDR src in PREPARE_RAM_FOR_BDOS)
BIOS_KEY_REPEAT_STATE            equ     0F1C0h    ; 2-byte BIOS work-area entry zeroed before BDOS calls
GAME_RAM_SHADOW_END              equ     0F37Fh    ; Last byte of GAME_RAM_SHADOW_E280 (LDDR dest in PREPARE_RAM_FOR_BDOS)

HEADER_NONE                      equ     00000h    ; GAME_HEADER marker: no per-game STAGE_CHEAT_DISPATCH (D302 stays 0)
VARIANT_NO                       equ     00000h    ; GAME_VARIANT marker: use STAGE_ANTARCTIC_LUT_DEFAULT (D303 = 0)
VARIANT_YES                      equ     00001h    ; GAME_VARIANT marker: use STAGE_ANTARCTIC_LUT_VARIANT (D303 != 0)
BIOS_H_DISK_RETURN_HOOK          equ     0FEDAh    ; BIOS hook patched by cart with jp RETURN_FROM_DISK_BASIC_RAM
BIOS_H_DISK_INIT_RESUME          equ     0FECBh    ; jp target after BIOS_CALSLT into Disk BASIC's init routine
CART_MAGIC_AB                    equ     04241h    ; Cart header magic for 'AB' format: bytes 'A','B' read as LE word
CART_MAGIC_CD                    equ     04443h    ; Cart header magic for 'CD' format: bytes 'C','D' read as LE word
GAME_START_ADDRESS               equ     04012h    ; Per-game data block on the game cart (GAME_START_ADDRESS..4024h)
CHEAT_TARGET_YIE_AR_KUNG_FU_LIVES_CAP equ     0E052h    ; Per-game alias for E052 — YAK LIVES-cap flag (FFh)
CHEAT_TARGET_HYPER_RALLY_DIFFICULTY equ     0E052h    ; Per-game alias for E052 — HR difficulty (also CC stage residue)
CHEAT_TARGET_MOPIRANGER_STAGE_BCD equ     0E052h    ; Per-game alias for E052 — Mopiranger BCD-stage byte
CHEAT_TARGET_SKY_JAGUAR_EXTRA    equ     0E1B8h    ; Per-game alias for E1B8 — Sky Jaguar stage extra (high byte of stage word)
CHEAT_TARGET_PIPPOLS_EXTRA       equ     0E1B8h    ; Per-game alias for E1B8 — Pippols level flag (always 00C0h)
CHAR_BACKSPACE                   equ     00008h    ; BIOS_CHGET return code: BS / backspace key
CHAR_LF                          equ     0000Ah    ; ASCII line-feed (LF); used as a printer-output byte
CHAR_RETURN                      equ     0000Dh    ; BIOS_CHGET return code: RETURN / ENTER (CR)
CHAR_KEY_LEFT                    equ     0001Dh    ; BIOS_CHGET return code: cursor left
CHAR_KEY_UP                      equ     0001Eh    ; BIOS_CHGET return code: cursor up
CHAR_KEY_DOWN                    equ     0001Fh    ; BIOS_CHGET return code: cursor down
CHAR_SPACE                       equ     00020h    ; BIOS_CHGET return code: SPACE
PRINTER_MODE_TOC                 equ     00070h    ; Printer mode 70h: header / table-of-contents only (no bottom graphics)
PRINTER_MODE_NARROW              equ     00071h    ; Printer mode 71h: bottom graphics at S384 width, no characters
PRINTER_MODE_WIDE                equ     00072h    ; Printer mode 72h: bottom graphics at S768 width, with characters
Z80_RET                          equ     000C9h    ; Z80 opcode: RET — sentinel at a BIOS hook when no extension is installed
Z80_JP                           equ     000C3h    ; Z80 opcode: JP nn — first byte of a 3-byte hook entry
BIOS_RDSLT                       equ     0000Ch    ; MSX BIOS: read byte at (HL) from slot in A, returned in A
BIOS_CALSLT                      equ     0001Ch    ; MSX BIOS: inter-slot call to address in IX, slot in IY
BIOS_ENASLT                      equ     00024h    ; MSX BIOS: enable slot containing (HL) — A=slot, HL=address
BIOS_WRTVDP                      equ     00047h    ; MSX BIOS: write byte B to VDP register C
BIOS_RDVRM                       equ     0004Ah    ; MSX BIOS: read byte at VRAM address HL into A
BIOS_WRTVRM                      equ     0004Dh    ; MSX BIOS: write A to VRAM address HL
BIOS_SETWRT                      equ     00053h    ; MSX BIOS: set VDP write pointer to HL
BIOS_FILVRM                      equ     00056h    ; MSX BIOS: fill BC bytes of VRAM at HL with value A
BIOS_LDIRMV                      equ     00059h    ; MSX BIOS: copy BC bytes from VRAM(HL) to RAM(DE)
BIOS_LDIRVM                      equ     0005Ch    ; MSX BIOS: copy BC bytes from RAM(HL) to VRAM(DE)
BIOS_CHGCLR                      equ     00062h    ; MSX BIOS: apply FORCLR/BAKCLR/BDRCLR to current screen mode
BIOS_CHSNS                       equ     0009Ch    ; MSX BIOS: check keyboard sense; Z if no key pending
BIOS_CHGET                       equ     0009Fh    ; MSX BIOS: read one keypress from keyboard
BIOS_WRTPSG                      equ     00093h    ; MSX BIOS: write byte E to PSG register A
BIOS_RDPSG                       equ     00096h    ; MSX BIOS: read PSG register A into A
BIOS_RSLREG                      equ     00138h    ; MSX BIOS: read primary slot register (port A8h) into A
BIOS_SNSMAT                      equ     00141h    ; MSX BIOS: read keyboard matrix row A into A (each bit = key state)
BIOS_RDVDP                       equ     0013Eh    ; MSX BIOS: read VDP status register into A (also clears VBLANK flag)
BIOS_LPTOUT                      equ     000A5h    ; MSX BIOS: send character A to printer; carry set on failure
BIOS_LPTSTT                      equ     000A8h    ; MSX BIOS: test printer status; A=FFh+NZ if ready, A=00h+Z if not
BIOS_DISSCR                      equ     00132h    ; MSX BIOS: disable screen (blank the VDP output)
BIOS_KILBUF                      equ     00156h    ; MSX BIOS: empty the keyboard type-ahead buffer
BIOS_TAPION                      equ     000E1h    ; MSX BIOS: open tape input + read header; carry set on fail
BIOS_TAPIN                       equ     000E4h    ; MSX BIOS: read one byte from tape into A; carry set on fail
BIOS_TAPIOF                      equ     000E7h    ; MSX BIOS: stop reading from tape (close tape input)
BIOS_TAPOON                      equ     000EAh    ; MSX BIOS: open tape output + write header; A=0 short, A!=0 long
BIOS_TAPOUT                      equ     000EDh    ; MSX BIOS: write byte A to tape; carry set on fail
BIOS_TAPOOF                      equ     000F0h    ; MSX BIOS: stop writing to tape (close tape output)
BIOS_STMOTR                      equ     000F3h    ; MSX BIOS: set cassette motor (A=00 stop, 01 start, FF reverse)
BDOS_OPEN                        equ     0000Fh    ; BDOS: open file with FCB at DE; returns A=00 on success
BDOS_CLOSE                       equ     00010h    ; BDOS: close file with FCB at DE
BDOS_CREATE                      equ     00016h    ; BDOS: create (make) file with FCB at DE
BDOS_SEARCH_FIRST                equ     00011h    ; BDOS: find-first matching file (FCB at DE, wildcards in name); result to DTA
BDOS_SEARCH_NEXT                 equ     00012h    ; BDOS: find-next after a prior F_SFIRST; ret with result code in A
BDOS_SET_DTA                     equ     0001Ah    ; BDOS: set DTA (Disk Transfer Address) to DE
BDOS_WRBLK                       equ     00026h    ; BDOS: write HL bytes from DTA to file at FCB DE
BDOS_RDBLK                       equ     00027h    ; BDOS: read HL bytes from file at FCB DE into DTA
BIOS_BDRCLR                      equ     0F3EBh    ; MSX BIOS work area: border colour
BIOS_RG7SAV                      equ     0F3E6h    ; MSX BIOS work area: mirror of VDP register 7 (border/text colour)
BDOS                             equ     0F37Dh    ; MSX-DOS / Disk BASIC: 3-byte JP at the BDOS entry vector
RANKING_MOPI                     equ     0E001h    ; GAME_DATA marker: ranking enabled via Mopiranger game-state byte at E001
BIOS_SCRMOD                      equ     0FCAFh    ; MSX BIOS work area: current screen mode byte
BIOS_CHARSET                     equ     00004h    ; MSX BIOS RAM pointer to the character pattern table (CGTBL) base
BIOS_VDP_DR                      equ     00006h    ; MSX BIOS byte at BIOS_VDP_DR: VDP data-port I/O address (typically 98h)
BIOS_EXPTBL                      equ     0FCC1h    ; MSX BIOS work area: expansion slot flags (bit 7 set if expanded)
BIOS_HKEYI                       equ     0FD9Ah    ; MSX BIOS hook: keyboard ISR entry (5-byte JP-or-RST block)
BIOS_HTIMI                       equ     0FD9Fh    ; MSX BIOS hook: timer ISR entry (5-byte JP-or-RST block, called every VBlank)
BIOS_H_PHYDIO                    equ     0FFA7h    ; MSX BIOS H.PHYDIO hook: physical disk I/O — C9h = no disk extension
BIOS_WORK_AREA                   equ     0F100h    ; MSX BIOS work area start (F100..F3FF; cart copies F100..F413)
BIOS_HOOK_AREA                   equ     0FD00h    ; MSX BIOS hook area start (FD00..FFC9; cart swaps with BIOS_WORK_AREA_BACKUP)
VRAM_ROW_BACK_STEP               equ     0FFE0h    ; -32 in 16-bit two's complement (one row up on a 32-col Screen-1 name table)
SLOT_SCANNER_ROM                 equ     040DCh    ; ROM source of the slot scanner (= SCAN_ALL_SLOTS_FOR_DISK_BASIC, before phase)
RC_GAME_ATHLETIC_LAND            equ     00700h    ; Athletic Land — RC-700 catalog code (BCD)
RC_GAME_ANTARCTIC_ADVENTURE      equ     00701h    ; Antarctic Adventure — RC-701 (BCD); JP and EU revisions share this code
RC_GAME_MONKEY_ACADEMY           equ     00702h    ; Monkey Academy (Donkey Kong-style) — RC-702 (BCD)
RC_GAME_TIME_PILOT               equ     00703h    ; Time Pilot — RC-703 (BCD)
RC_GAME_FROGGER                  equ     00704h    ; Frogger — RC-704 (BCD)
RC_GAME_SUPER_COBRA              equ     00705h    ; Super Cobra — RC-705 (BCD)
RC_GAME_VIDEO_HUSTLER            equ     00706h    ; Video Hustler / Konami Billiards — RC-706 (BCD)
RC_GAME_MAHJONG_DOJO             equ     00707h    ; Konami's Mahjong Dojo — RC-707 (BCD)
RC_GAME_HYPER_OLYMPIC_1          equ     00710h    ; Hyper Olympic 1 — RC-710 (BCD)
RC_GAME_HYPER_OLYMPIC_2          equ     00711h    ; Hyper Olympic 2 — RC-711 (BCD)
RC_GAME_CIRCUS_CHARLIE           equ     00712h    ; Circus Charlie — RC-712 (BCD)
RC_GAME_MAGICAL_TREE             equ     00713h    ; Magical Tree — RC-713 (BCD)
RC_GAME_COMIC_BAKERY             equ     00714h    ; Comic Bakery — RC-714 (BCD)
RC_GAME_HYPER_SPORTS_1           equ     00715h    ; Hyper Sports 1 — RC-715 (BCD)
RC_GAME_CABBAGE_PATCH_KIDS       equ     00716h    ; Cabbage Patch Kids — RC-716 (BCD)
RC_GAME_HYPER_SPORTS_2           equ     00717h    ; Hyper Sports 2 — RC-717 (BCD)
RC_GAME_HYPER_RALLY              equ     00718h    ; Hyper Rally — RC-718 (BCD)
RC_GAME_TENNIS                   equ     00720h    ; Konami's Tennis — RC-720 (BCD)
RC_GAME_SKY_JAGUAR               equ     00721h    ; Sky Jaguar — RC-721 (BCD)
RC_GAME_GOLF                     equ     00723h    ; Konami's Golf — RC-723 (BCD)
RC_GAME_BASEBALL                 equ     00724h    ; Konami's Baseball — RC-724 (BCD)
RC_GAME_YIE_AR_KUNG_FU           equ     00725h    ; Yie Ar Kung-Fu — RC-725 (BCD)
RC_GAME_KINGS_VALLEY             equ     00727h    ; King's Valley — RC-727 (BCD)
RC_GAME_MOPIRANGER               equ     00728h    ; Mopiranger — RC-728 (BCD)
RC_GAME_PIPPOLS                  equ     00729h    ; Pippols — RC-729 (BCD)
RC_GAME_ROAD_FIGHTER             equ     00730h    ; Road Fighter — RC-730 (BCD)
RC_GAME_PING_PONG                equ     00731h    ; Konami's Ping-Pong — RC-731 (BCD)
RC_GAME_HYPER_SPORTS_3           equ     00733h    ; Hyper Sports 3 — RC-733 (BCD)
RC_GAME_KONAMIS_SOCCER           equ     00732h    ; Konami's Soccer — RC-732 (BCD)
RC_GAME_KONAMIS_BOXING           equ     00736h    ; Konami's Boxing — RC-736 (BCD)
RC_GAME_YIE_AR_KUNG_FU_2         equ     00737h    ; Yie Ar Kung-Fu II — RC-737 (BCD)
RC_GAME_KNIGHTMARE               equ     00739h    ; Knightmare (Majō Densetsu) — RC-739 (BCD)
ID_GAME_ATHLETIC_LAND            equ     00000h    ; matches RC_GAME_ATHLETIC_LAND       (RC-700)
ID_GAME_ANTARCTIC_ADVENTURE      equ     00001h    ; matches RC_GAME_ANTARCTIC_ADVENTURE (RC-701)
ID_GAME_MONKEY_ACADEMY           equ     00002h    ; matches RC_GAME_MONKEY_ACADEMY      (RC-702)
ID_GAME_TIME_PILOT               equ     00003h    ; matches RC_GAME_TIME_PILOT          (RC-703)
ID_GAME_FROGGER                  equ     00004h    ; matches RC_GAME_FROGGER             (RC-704)
ID_GAME_SUPER_COBRA              equ     00005h    ; matches RC_GAME_SUPER_COBRA         (RC-705)
ID_GAME_VIDEO_HUSTLER            equ     00006h    ; matches RC_GAME_VIDEO_HUSTLER       (RC-706)
ID_GAME_HYPER_OLYMPIC_1          equ     00010h    ; matches RC_GAME_HYPER_OLYMPIC_1     (RC-710)
ID_GAME_HYPER_OLYMPIC_2          equ     00011h    ; matches RC_GAME_HYPER_OLYMPIC_2     (RC-711)
ID_GAME_CIRCUS_CHARLIE           equ     00012h    ; matches RC_GAME_CIRCUS_CHARLIE      (RC-712)
ID_GAME_MAGICAL_TREE             equ     00013h    ; matches RC_GAME_MAGICAL_TREE        (RC-713)
ID_GAME_COMIC_BAKERY             equ     00014h    ; matches RC_GAME_COMIC_BAKERY        (RC-714)
ID_GAME_HYPER_SPORTS_1           equ     00015h    ; matches RC_GAME_HYPER_SPORTS_1      (RC-715)
ID_GAME_CABBAGE_PATCH_KIDS       equ     00016h    ; matches RC_GAME_CABBAGE_PATCH_KIDS  (RC-716)
ID_GAME_HYPER_SPORTS_2           equ     00017h    ; matches RC_GAME_HYPER_SPORTS_2      (RC-717)
ID_GAME_HYPER_RALLY              equ     00018h    ; matches RC_GAME_HYPER_RALLY         (RC-718)
ID_GAME_SKY_JAGUAR               equ     00021h    ; matches RC_GAME_SKY_JAGUAR          (RC-721)
ID_GAME_YIE_AR_KUNG_FU           equ     00025h    ; matches RC_GAME_YIE_AR_KUNG_FU      (RC-725)
ID_GAME_KINGS_VALLEY             equ     00027h    ; matches RC_GAME_KINGS_VALLEY        (RC-727)
ID_GAME_MOPIRANGER               equ     00028h    ; matches RC_GAME_MOPIRANGER          (RC-728)
ID_GAME_PIPPOLS                  equ     00029h    ; matches RC_GAME_PIPPOLS             (RC-729)
ID_GAME_ROAD_FIGHTER             equ     00030h    ; matches RC_GAME_ROAD_FIGHTER        (RC-730)
ID_GAME_KONAMIS_SOCCER           equ     00032h    ; matches RC_GAME_KONAMIS_SOCCER      (RC-732)
ID_GAME_HYPER_SPORTS_3           equ     00033h    ; matches RC_GAME_HYPER_SPORTS_3      (RC-733)
ID_GAME_KONAMIS_BOXING           equ     00036h    ; matches RC_GAME_KONAMIS_BOXING      (RC-736)
ID_GAME_YIE_AR_KUNG_FU_2         equ     00037h    ; matches RC_GAME_YIE_AR_KUNG_FU_2    (RC-737)
GAME_RANKING_FROGGER             equ     0E000h    ; per-game alias for CHEAT_TARGET_ROAD_FIGHTER_E000
GAME_RANKING_TIME_PILOT          equ     0E000h    ; per-game alias for CHEAT_TARGET_ROAD_FIGHTER_E000
GAME_STATE_ANTARCTIC_EU          equ     0E000h    ; per-game alias for CHEAT_TARGET_ROAD_FIGHTER_E000
GAME_STATE_ANTARCTIC_JP          equ     0E000h    ; per-game alias for CHEAT_TARGET_ROAD_FIGHTER_E000
GAME_STATE_ATHLETIC_LAND         equ     0E000h    ; per-game alias for CHEAT_TARGET_ROAD_FIGHTER_E000
GAME_STATE_CABBAGE_PATCH_KIDS    equ     0E000h    ; per-game alias for CHEAT_TARGET_ROAD_FIGHTER_E000
GAME_STATE_CIRCUS_CHARLIE        equ     0E000h    ; per-game alias for CHEAT_TARGET_ROAD_FIGHTER_E000
GAME_STATE_COMIC_BAKERY          equ     0E000h    ; per-game alias for CHEAT_TARGET_ROAD_FIGHTER_E000
GAME_STATE_HYPER_RALLY           equ     0E000h    ; per-game alias for CHEAT_TARGET_ROAD_FIGHTER_E000
GAME_STATE_HYPER_SPORTS_1        equ     0E000h    ; per-game alias for CHEAT_TARGET_ROAD_FIGHTER_E000
GAME_STATE_HYPER_SPORTS_2        equ     0E000h    ; per-game alias for CHEAT_TARGET_ROAD_FIGHTER_E000
GAME_STATE_HYPER_SPORTS_3        equ     0E000h    ; per-game alias for CHEAT_TARGET_ROAD_FIGHTER_E000
GAME_STATE_KINGS_VALLEY          equ     0E000h    ; per-game alias for CHEAT_TARGET_ROAD_FIGHTER_E000
GAME_STATE_MAGICAL_TREE          equ     0E000h    ; per-game alias for CHEAT_TARGET_ROAD_FIGHTER_E000
GAME_STATE_MONKEY_ACADEMY        equ     0E000h    ; per-game alias for CHEAT_TARGET_ROAD_FIGHTER_E000
GAME_STATE_MOPIRANGER            equ     0E000h    ; per-game alias for CHEAT_TARGET_ROAD_FIGHTER_E000
GAME_STATE_PIPPOLS               equ     0E000h    ; per-game alias for CHEAT_TARGET_ROAD_FIGHTER_E000
GAME_STATE_ROAD_FIGHTER          equ     0E000h    ; per-game alias for CHEAT_TARGET_ROAD_FIGHTER_E000
GAME_STATE_SKY_JAGUAR            equ     0E000h    ; per-game alias for CHEAT_TARGET_ROAD_FIGHTER_E000
GAME_STATE_SUPER_COBRA           equ     0E000h    ; per-game alias for CHEAT_TARGET_ROAD_FIGHTER_E000
GAME_STATE_VIDEO_HUSTLER         equ     0E000h    ; per-game alias for CHEAT_TARGET_ROAD_FIGHTER_E000
GAME_STATE_YIE_AR_KUNG_FU        equ     0E000h    ; per-game alias for CHEAT_TARGET_ROAD_FIGHTER_E000
GAME_RANKING_MOPIRANGER          equ     0E001h    ; per-game alias for CHEAT_TARGET_ROAD_FIGHTER_E001
GAME_LIVES_FROGGER               equ     0E002h    ; per-game alias for GAME_LIVES_FROGGER
GAME_LIVES_TIME_PILOT            equ     0E002h    ; per-game alias for GAME_LIVES_FROGGER
GAME_RANKING_ATHLETIC_LAND       equ     0E002h    ; per-game alias for GAME_LIVES_FROGGER
GAME_RANKING_CABBAGE_PATCH_KIDS  equ     0E002h    ; per-game alias for GAME_LIVES_FROGGER
GAME_RANKING_CIRCUS_CHARLIE      equ     0E002h    ; per-game alias for GAME_LIVES_FROGGER
GAME_RANKING_COMIC_BAKERY        equ     0E002h    ; per-game alias for GAME_LIVES_FROGGER
GAME_RANKING_HYPER_SPORTS_1      equ     0E002h    ; per-game alias for GAME_LIVES_FROGGER
GAME_RANKING_HYPER_SPORTS_3      equ     0E002h    ; per-game alias for GAME_LIVES_FROGGER
GAME_RANKING_MAGICAL_TREE        equ     0E002h    ; per-game alias for GAME_LIVES_FROGGER
GAME_RANKING_MONKEY_ACADEMY      equ     0E002h    ; per-game alias for GAME_LIVES_FROGGER
GAME_RANKING_ROAD_FIGHTER        equ     0E002h    ; per-game alias for GAME_LIVES_FROGGER
GAME_RANKING_SUPER_COBRA         equ     0E002h    ; per-game alias for GAME_LIVES_FROGGER
GAME_RANKING_VIDEO_HUSTLER       equ     0E002h    ; per-game alias for GAME_LIVES_FROGGER
GAME_STATE_FROGGER               equ     0E002h    ; per-game alias for GAME_LIVES_FROGGER
GAME_STATE_TIME_PILOT            equ     0E002h    ; per-game alias for GAME_LIVES_FROGGER
GAME_SCORE_1P_FROGGER            equ     0E00Bh    ; per-game alias for GAME_RAM_TIME_PILOT_FROGGER_SCORE_1P
GAME_SCORE_1P_TIME_PILOT         equ     0E00Bh    ; per-game alias for GAME_RAM_TIME_PILOT_FROGGER_SCORE_1P
GAME_SCORE_2P_FROGGER            equ     0E00Eh    ; per-game alias for GAME_RAM_TIME_PILOT_FROGGER_SCORE_2P
GAME_SCORE_2P_TIME_PILOT         equ     0E00Eh    ; per-game alias for GAME_RAM_TIME_PILOT_FROGGER_SCORE_2P
GAME_HISCORE_FROGGER             equ     0E011h    ; per-game alias for GAME_RAM_TIME_PILOT_FROGGER_HISCORE
GAME_HISCORE_TIME_PILOT          equ     0E011h    ; per-game alias for GAME_RAM_TIME_PILOT_FROGGER_HISCORE
GAME_STAGE_HYPER_OLYMPIC_1       equ     0E016h    ; per-game alias for GAME_RAM_HYPER_OLYMPIC_STAGE
GAME_STAGE_HYPER_OLYMPIC_2       equ     0E016h    ; per-game alias for GAME_RAM_HYPER_OLYMPIC_STAGE
GAME_RANKING_HYPER_OLYMPIC_1     equ     0E01Bh    ; per-game alias for GAME_RAM_HYPER_OLYMPIC_RANKING
GAME_RANKING_HYPER_OLYMPIC_2     equ     0E01Bh    ; per-game alias for GAME_RAM_HYPER_OLYMPIC_RANKING
GAME_HISCORE_ROAD_FIGHTER        equ     0E03Ch    ; per-game alias for GAME_HISCORE_ROAD_FIGHTER
GAME_SCORE_1P_ROAD_FIGHTER       equ     0E03Fh    ; per-game alias for GAME_SCORE_1P_ROAD_FIGHTER
GAME_HISCORE_ANTARCTIC_EU        equ     0E040h    ; per-game alias for GAME_RAM_HISCORE_BYTE
GAME_HISCORE_ANTARCTIC_JP        equ     0E040h    ; per-game alias for GAME_RAM_HISCORE_BYTE
GAME_HISCORE_ATHLETIC_LAND       equ     0E040h    ; per-game alias for GAME_RAM_HISCORE_BYTE
GAME_HISCORE_MONKEY_ACADEMY      equ     0E040h    ; per-game alias for GAME_RAM_HISCORE_BYTE
GAME_HISCORE_SUPER_COBRA         equ     0E040h    ; per-game alias for GAME_RAM_HISCORE_BYTE
GAME_HISCORE_VIDEO_HUSTLER       equ     0E040h    ; per-game alias for GAME_RAM_HISCORE_BYTE
GAME_HISCORE_CIRCUS_CHARLIE      equ     0E043h    ; per-game alias for GAME_RAM_SCORE_1P_BYTE
GAME_HISCORE_COMIC_BAKERY        equ     0E043h    ; per-game alias for GAME_RAM_SCORE_1P_BYTE
GAME_HISCORE_KINGS_VALLEY        equ     0E043h    ; per-game alias for GAME_RAM_SCORE_1P_BYTE
GAME_HISCORE_MAGICAL_TREE        equ     0E043h    ; per-game alias for GAME_RAM_SCORE_1P_BYTE
GAME_HISCORE_PIPPOLS             equ     0E043h    ; per-game alias for GAME_RAM_SCORE_1P_BYTE
GAME_HISCORE_SKY_JAGUAR          equ     0E043h    ; per-game alias for GAME_RAM_SCORE_1P_BYTE
GAME_HISCORE_YIE_AR_KUNG_FU      equ     0E043h    ; per-game alias for GAME_RAM_SCORE_1P_BYTE
GAME_SCORE_1P_ANTARCTIC_EU       equ     0E043h    ; per-game alias for GAME_RAM_SCORE_1P_BYTE
GAME_SCORE_1P_ANTARCTIC_JP       equ     0E043h    ; per-game alias for GAME_RAM_SCORE_1P_BYTE
GAME_SCORE_1P_ATHLETIC_LAND      equ     0E043h    ; per-game alias for GAME_RAM_SCORE_1P_BYTE
GAME_SCORE_1P_MONKEY_ACADEMY     equ     0E043h    ; per-game alias for GAME_RAM_SCORE_1P_BYTE
GAME_SCORE_1P_VIDEO_HUSTLER      equ     0E043h    ; per-game alias for GAME_RAM_SCORE_1P_BYTE
GAME_SCORE_2P_SUPER_COBRA        equ     0E043h    ; per-game alias for GAME_RAM_SCORE_1P_BYTE
GAME_STAGE_ROAD_FIGHTER          equ     0E043h    ; per-game alias for GAME_RAM_SCORE_1P_BYTE
GAME_HISCORE_HYPER_SPORTS_1      equ     0E044h    ; per-game alias for GAME_HISCORE_HYPER_SPORTS_1
GAME_HISCORE_CABBAGE_PATCH_KIDS  equ     0E046h    ; per-game alias for GAME_RAM_SCORE_2P_BYTE
GAME_SCORE_1P_PIPPOLS            equ     0E046h    ; per-game alias for GAME_RAM_SCORE_2P_BYTE
GAME_SCORE_1P_SUPER_COBRA        equ     0E046h    ; per-game alias for GAME_RAM_SCORE_2P_BYTE
GAME_SCORE_2P_ATHLETIC_LAND      equ     0E046h    ; per-game alias for GAME_RAM_SCORE_2P_BYTE
GAME_SCORE_2P_CIRCUS_CHARLIE     equ     0E046h    ; per-game alias for GAME_RAM_SCORE_2P_BYTE
GAME_SCORE_2P_COMIC_BAKERY       equ     0E046h    ; per-game alias for GAME_RAM_SCORE_2P_BYTE
GAME_SCORE_2P_MAGICAL_TREE       equ     0E046h    ; per-game alias for GAME_RAM_SCORE_2P_BYTE
GAME_SCORE_2P_MONKEY_ACADEMY     equ     0E046h    ; per-game alias for GAME_RAM_SCORE_2P_BYTE
GAME_SCORE_2P_VIDEO_HUSTLER      equ     0E046h    ; per-game alias for GAME_RAM_SCORE_2P_BYTE
GAME_HISCORE_MOPIRANGER          equ     0E047h    ; per-game alias for GAME_RAM_CABBAGE_PATCH_KIDS_SCORE_2P
GAME_SCORE_2P_HYPER_SPORTS_1     equ     0E047h    ; per-game alias for GAME_RAM_CABBAGE_PATCH_KIDS_SCORE_2P
GAME_SCORE_1P_CABBAGE_PATCH_KIDS equ     0E049h    ; per-game alias for GAME_RAM_RANK_BYTE
GAME_SCORE_1P_CIRCUS_CHARLIE     equ     0E049h    ; per-game alias for GAME_RAM_RANK_BYTE
GAME_SCORE_1P_COMIC_BAKERY       equ     0E049h    ; per-game alias for GAME_RAM_RANK_BYTE
GAME_SCORE_1P_KINGS_VALLEY       equ     0E049h    ; per-game alias for GAME_RAM_RANK_BYTE
GAME_SCORE_1P_MAGICAL_TREE       equ     0E049h    ; per-game alias for GAME_RAM_RANK_BYTE
GAME_SCORE_1P_SKY_JAGUAR         equ     0E049h    ; per-game alias for GAME_RAM_RANK_BYTE
GAME_SCORE_1P_YIE_AR_KUNG_FU     equ     0E049h    ; per-game alias for GAME_RAM_RANK_BYTE
GAME_SCORE_1P_HYPER_SPORTS_1     equ     0E04Ah    ; per-game alias for GAME_SCORE_1P_HYPER_SPORTS_1
GAME_SCORE_2P_CABBAGE_PATCH_KIDS equ     0E04Ch    ; per-game alias for GAME_SCORE_2P_CABBAGE_PATCH_KIDS
GAME_SCORE_1P_MOPIRANGER         equ     0E04Dh    ; per-game alias for GAME_SCORE_1P_MOPIRANGER
GAME_LIVES_ATHLETIC_LAND         equ     0E050h    ; per-game alias for CHEAT_TARGET_LIVES
GAME_LIVES_CABBAGE_PATCH_KIDS    equ     0E050h    ; per-game alias for CHEAT_TARGET_LIVES
GAME_LIVES_CIRCUS_CHARLIE        equ     0E050h    ; per-game alias for CHEAT_TARGET_LIVES
GAME_LIVES_COMIC_BAKERY          equ     0E050h    ; per-game alias for CHEAT_TARGET_LIVES
GAME_LIVES_KINGS_VALLEY          equ     0E050h    ; per-game alias for CHEAT_TARGET_LIVES
GAME_LIVES_MAGICAL_TREE          equ     0E050h    ; per-game alias for CHEAT_TARGET_LIVES
GAME_LIVES_MONKEY_ACADEMY        equ     0E050h    ; per-game alias for CHEAT_TARGET_LIVES
GAME_LIVES_MOPIRANGER            equ     0E050h    ; per-game alias for CHEAT_TARGET_LIVES
GAME_LIVES_PIPPOLS               equ     0E050h    ; per-game alias for CHEAT_TARGET_LIVES
GAME_LIVES_SKY_JAGUAR            equ     0E050h    ; per-game alias for CHEAT_TARGET_LIVES
GAME_LIVES_SUPER_COBRA           equ     0E050h    ; per-game alias for CHEAT_TARGET_LIVES
GAME_LIVES_VIDEO_HUSTLER         equ     0E050h    ; per-game alias for CHEAT_TARGET_LIVES
GAME_LIVES_YIE_AR_KUNG_FU        equ     0E050h    ; per-game alias for CHEAT_TARGET_LIVES
GAME_STAGE_ATHLETIC_LAND         equ     0E051h    ; per-game alias for CHEAT_TARGET_LIVES_BCD
GAME_STAGE_CABBAGE_PATCH_KIDS    equ     0E051h    ; per-game alias for CHEAT_TARGET_LIVES_BCD
GAME_STAGE_CIRCUS_CHARLIE        equ     0E051h    ; per-game alias for CHEAT_TARGET_LIVES_BCD
GAME_STAGE_COMIC_BAKERY          equ     0E051h    ; per-game alias for CHEAT_TARGET_LIVES_BCD
GAME_STAGE_KINGS_VALLEY          equ     0E051h    ; per-game alias for CHEAT_TARGET_LIVES_BCD
GAME_STAGE_MAGICAL_TREE          equ     0E051h    ; per-game alias for CHEAT_TARGET_LIVES_BCD
GAME_STAGE_MONKEY_ACADEMY        equ     0E051h    ; per-game alias for CHEAT_TARGET_LIVES_BCD
GAME_STAGE_PIPPOLS               equ     0E051h    ; per-game alias for CHEAT_TARGET_LIVES_BCD
GAME_STAGE_SKY_JAGUAR            equ     0E051h    ; per-game alias for CHEAT_TARGET_LIVES_BCD
GAME_STAGE_YIE_AR_KUNG_FU        equ     0E051h    ; per-game alias for CHEAT_TARGET_LIVES_BCD
GAME_STAGE_HYPER_SPORTS_1        equ     0E052h    ; per-game alias for E052 (Hyper Sports 1 STAGE byte)
GAME_STAGE_MOPIRANGER            equ     0E053h    ; per-game alias for CHEAT_TARGET_MOPIRANGER_STAGE
GAME_HISCORE_HYPER_RALLY         equ     0E055h    ; per-game alias for E055 (Hyper Rally HISCORE byte)
GAME_SCORE_1P_HYPER_RALLY        equ     0E058h    ; per-game alias for CHEAT_TARGET_KINGS_VALLEY_HI
GAME_HISCORE_HYPER_SPORTS_2      equ     0E060h    ; per-game alias for CHEAT_TARGET_HYPER_RALLY_COURSE
GAME_HISCORE_HYPER_SPORTS_3      equ     0E060h    ; per-game alias for CHEAT_TARGET_HYPER_RALLY_COURSE
GAME_STAGE_HYPER_RALLY           equ     0E060h    ; per-game alias for CHEAT_TARGET_HYPER_RALLY_COURSE
GAME_SCORE_1P_HYPER_SPORTS_2     equ     0E063h    ; per-game alias for GAME_RAM_HS2_SCORE_1P
GAME_SCORE_2P_HYPER_SPORTS_3     equ     0E063h    ; per-game alias for GAME_RAM_HS2_SCORE_1P
GAME_SCORE_1P_HYPER_SPORTS_3     equ     0E066h    ; per-game alias for GAME_SCORE_1P_HYPER_SPORTS_3
GAME_STAGE_HYPER_SPORTS_3        equ     0E06Ah    ; per-game alias for CHEAT_TARGET_YIE_AR_KUNG_FU_2_MODE
GAME_HISCORE_HYPER_OLYMPIC_1     equ     0E080h    ; per-game alias for GAME_RAM_HYPER_OLYMPIC_HISCORE
GAME_HISCORE_HYPER_OLYMPIC_2     equ     0E080h    ; per-game alias for GAME_RAM_HYPER_OLYMPIC_HISCORE
GAME_STAGE_HYPER_SPORTS_2        equ     0E080h    ; per-game alias for GAME_RAM_HYPER_OLYMPIC_HISCORE
GAME_SCORE_1P_HYPER_OLYMPIC_1    equ     0E083h    ; per-game alias for GAME_RAM_HYPER_OLYMPIC_SCORE_1P
GAME_SCORE_1P_HYPER_OLYMPIC_2    equ     0E083h    ; per-game alias for GAME_RAM_HYPER_OLYMPIC_SCORE_1P
GAME_SCORE_2P_HYPER_OLYMPIC_1    equ     0E086h    ; per-game alias for GAME_RAM_HYPER_OLYMPIC_SCORE_2P
GAME_SCORE_2P_HYPER_OLYMPIC_2    equ     0E086h    ; per-game alias for GAME_RAM_HYPER_OLYMPIC_SCORE_2P
GAME_STAGE_ANTARCTIC_EU          equ     0E0E0h    ; per-game alias for GAME_RAM_ANTARCTIC_STAGE
GAME_STAGE_ANTARCTIC_JP          equ     0E0E0h    ; per-game alias for GAME_RAM_ANTARCTIC_STAGE
GAME_STATE_HYPER_OLYMPIC_1       equ     0E162h    ; per-game alias for GAME_STATE_HYPER_OLYMPIC_1
GAME_STATE_HYPER_OLYMPIC_2       equ     0E162h    ; per-game alias for GAME_STATE_HYPER_OLYMPIC_1

        ; TEXT_SEPARATOR / TEXT_TERMINATOR
        ; The two control bytes DRAW_TEXT_STREAM (6113h) watches for inside
        ; a text stream. FEh restarts with the next 2 bytes as a new VRAM
        ; target word; FFh ends the stream. Used as macros (not equs) so
        ; they sit on their own line in the asm.
        macro TEXT_SEPARATOR
                db      0FEh
        endm
        macro TEXT_TERMINATOR
                db      0FFh
        endm

        ; PRINTER_ESC
        ; Leading 1Bh of a printer ESC sequence emitted by
        ; PRINTER_SEND_SEQ_TO_FF (7533h). The sequence payload follows
        ; and ends with TEXT_TERMINATOR (0FFh).
        macro PRINTER_ESC
                db      1Bh
        endm

        ; GAME_TRAILER field macros (see KONAMI.md). Together they hold the
        ; Japanese title (byte-reversed katakana, 00h separators) plus the
        ; size, RC catalog suffix, and AAh terminator at the very end of
        ; every Konami MSX cart.
        macro GAME_NAME s
                dh      s
        endm
        macro GAME_NAME_SIZE n
                db      n
        endm
        macro RC_NUMBER n
                db      n
        endm
        macro GAME_TERMINATOR
                db      0AAh
        endm

        ; NAME_TABLE row, col
        ; Emit a 2-byte VRAM nametable pointer for screen-mode-1
        ; cell (row, col): base 3800h + row*32 + col.
        macro NAME_TABLE row, col
                dw      3800h + row*32 + col
        endm

        ; LOAD_NAME_TABLE reg, row, col
        ; Load the screen-mode-1 VRAM nametable address for cell
        ; (row, col) into the named register: ld reg, 3800h + row*32 + col.
        macro LOAD_NAME_TABLE reg, row, col
                ld      reg, 3800h + row*32 + col
        endm

        ; LOAD_VRAM_ADDRESS reg, addr
        ; Load a raw VRAM address (in the SCREEN 2 layout: pattern table
        ; 0000h-17FFh, color table 2000h-37FFh, name table 3800h-3AFFh) into
        ; the named register. Identical to `ld reg, addr` — the macro just
        ; flags the immediate as a VRAM address at the call site.
        macro LOAD_VRAM_ADDRESS reg, addr
                ld      reg, addr
        endm

        ; LD_BC_SIZE label
        ; Emit `ld bc, label_END - label`. Used before LDIR/LDDR to
        ; express the copy length as the size of the source region; if
        ; instructions are added inside the region the diff updates
        ; automatically. The trailing `?` in the parameter name lets
        ; sjasmplus paste `_END` onto the substituted token.
        macro LD_BC_SIZE label?
                ld      bc, label?_END - label?
        endm

        ; GAME_FINGERPRINT chk, ptr
        ; Emit one entry of GAME_FINGERPRINT_TABLE: a 2-byte checksum
        ; followed by a 2-byte pointer to the matching 19-byte data block.
        ; chk is a 4-character hex string ("XXYY") — sjasmplus's `dh` reads
        ; pairs of hex digits and emits the corresponding bytes (XX, YY)
        ; in source order, so the resulting checksum word is YYXXh.
        macro GAME_FINGERPRINT chk, ptr
                dh      chk
                dw      ptr
        endm

        ; GAME_RC_CODE rc
        ; First 2 bytes of a GAME_DATA record: the cart's Konami catalog
        ; code (RC-XXXX) packed as 4 BCD digits, stored big-endian (high
        ; byte at offset +0, variable digits at +1). The natural reading
        ; is the BCD value itself (e.g. 0701h = RC-701), so this macro
        ; byte-swaps before emitting via little-endian dw. The default
        ; fallback record uses 00FFh as a sentinel — not a valid RC code.
        ; The runtime only consults the low byte (offset +1) for dispatch.
        macro GAME_RC_CODE rc
                dw      ((rc & 0FFh) << 8) | ((rc >> 8) & 0FFh)
        endm

        ; GAME_HEADER n — record offset +2 → D302 (GAME_STAGE_CHEAT_FLAG).
        ; 0 = walk STAGE_CHEAT_DISPATCH for a per-game STAGE handler.
        ; FFh (force-set by the CD-format unpacker) skips that branch.
        macro GAME_HEADER n
                db      n
        endm

        ; GAME_VARIANT n — record offset +3 → D303 (GAME_STAGE_LUT_SELECT).
        ; 0 picks STAGE_ANTARCTIC_LUT_DEFAULT, anything else picks _VARIANT
        ; (Antarctic EU is the only record with a non-zero value here).
        macro GAME_VARIANT n
                db      n
        endm

        ; GAME_STATE_POINTER p — record offset +4..+5 (LE word) →
        ; D304/D305 (GAME_RAM_TRIGGER_PTR). Address of the per-game state
        ; byte the ISR polls for a transition to GAME_STATE_TRIGGER_VAL
        ; before firing ON_GAME_STATE_TRANSITION.
        macro GAME_STATE_POINTER p
                dw      p
        endm

        ; GAME_RAM_RANKING / _LIVES / _STAGE / _HISCORE / _SCORE_1P / _SCORE_2P
        ; (RANKING_ENABLE is the ranking-availability flag byte the cart bit-tests;
        ; SCORE_1P and SCORE_2P are the actual scores recorded into the leaderboard.)
        ; The six 16-bit LE pointers at GAME_DATA record offsets +6..+17.
        ; Each macro emits one 2-byte pointer into the running game's RAM
        ; (E0xxh / E1xxh) and is named after the role of the matching D-page
        ; slot (GAME_RAM_<role>_PTR at D306/D308/D30A/D30C/D30E/D310).
        macro GAME_RAM_RANKING addr
                dw      addr
        endm
        macro GAME_RAM_LIVES addr
                dw      addr
        endm
        macro GAME_RAM_STAGE addr
                dw      addr
        endm
        macro GAME_RAM_HISCORE addr
                dw      addr
        endm
        macro GAME_RAM_SCORE_1P addr
                dw      addr
        endm
        macro GAME_RAM_SCORE_2P addr
                dw      addr
        endm

        ; GAME_STATE_TRIGGER t
        ; Last byte (offset +18) of each GAME_DATA record. Unpacked at boot
        ; into D312h (GAME_STATE_TRIGGER_VAL). The ISR fires
        ; ON_GAME_STATE_TRANSITION when (GAME_RAM_TRIGGER_PTR) transitions to
        ; this value — i.e., this is the per-game "trigger value" that says
        ; "now apply pending cheats".
        macro GAME_STATE_TRIGGER t
                db      t
        endm

        ; CHEAT_LIVES game_id, addr
        ; One entry of LIVES_CHEAT_DISPATCH_TABLE: 1-byte game id followed
        ; by a 2-byte LE handler pointer. DISPATCH_BY_GAME_ID_JP walks the
        ; table comparing the id against GAME_ID (D301).
        macro CHEAT_LIVES game_id, addr
                db      game_id
                dw      addr
        endm

        ; CHEAT_STAGE game_id, addr
        ; Same layout as CHEAT_LIVES but for STAGE_CHEAT_DISPATCH_TABLE.
        macro CHEAT_STAGE game_id, addr
                db      game_id
                dw      addr
        endm


ROM_HEADER:
        ; Cartridge header (magic, init, statement, device, BASIC, reserved)
        db      "AB" ; magic                                   ;#4000: 41 42
        dw      GAME_BOOT ; init address                       ;#4002: 10 40
        dw      0 ; CALL statement handler                     ;#4004: 00 00
        dw      0 ; device handler                             ;#4006: 00 00
        dw      0 ; BASIC program                              ;#4008: 00 00
        dw      0 ; reserved                                   ;#400A: 00 00
        dw      0 ; reserved                                   ;#400C: 00 00
        dw      0 ; reserved                                   ;#400E: 00 00

GAME_BOOT:
        ; Entry point for ROM startup; init address pointed to by header
        di                                                     ;#4010: F3
        ld      hl,SLOT_SCANNER_RAM                            ;#4011: 21 00 C0
        ld      de,SLOT_SCANNER_RAM+1                          ;#4014: 11 01 C0
        ld      (hl),0                                         ;#4017: 36 00
        ld      bc,1FFFh                                       ;#4019: 01 FF 1F
        ldir                                                   ;#401C: ED B0
        ld      a,0FFh                                         ;#401E: 3E FF
        ld      (IN_ISR_LOCK),a                                ;#4020: 32 3B D1
        call    GET_PAGE1_SLOT                                 ;#4023: CD A1 40
        ld      (OWN_SLOT_RAW),a                               ;#4026: 32 2E D1
        ; Derive GAME_CART_SLOT from OWN_SLOT_RAW. The Game Master cartridge
        ; does not search the slot table for the game cart — it assumes the
        ; cart sits in the slot or subslot immediately following its own.
        ; For an expanded slot byte (high bit set) the +4 increments the
        ; SS subslot field at bits 2-3; for a non-expanded byte the +1
        ; increments the primary slot at bits 0-1. This is why the manual
        ; instructs the user to put Game Master in slot 1 (or A) and the
        ; game in slot 2 (or B).
        or      a                                              ;#4029: B7
        ld      b,4                                            ;#402A: 06 04
        jp      m,BOOT_SLOT_ID_MERGE                           ;#402C: FA 31 40
        ld      b,1                                            ;#402F: 06 01
BOOT_SLOT_ID_MERGE:
        ; Merge after expanded/non-expanded slot offset; A += B and store GAME_CART_SLOT
        add     a,b                                            ;#4031: 80
        ld      (GAME_CART_SLOT),a                             ;#4032: 32 2F D1
        call    COPY_SLOT_SCANNER_TO_RAM                       ;#4035: CD CE 40
        jr      nc,BOOT_VERIFY_AND_INIT                        ;#4038: 30 0F
        jp      BOOT_INTO_DISK_BASIC                           ;#403A: C3 60 41

RELOAD_GAME_FROM_RAM:
        ; Restore the 1100h-byte image from GAME_RAM_SHADOW_E280 into SLOT_SCANNER_RAM
        di                                                     ;#403D: F3
        ld      hl,GAME_RAM_SHADOW_E280                        ;#403E: 21 80 E2
        ld      de,SLOT_SCANNER_RAM                            ;#4041: 11 00 C0
        ld      bc,1100h                                       ;#4044: 01 00 11
        ldir                                                   ;#4047: ED B0
BOOT_VERIFY_AND_INIT:
        ; Verify game cart's 'AB' magic, capture its init pointer, install hooks, jp main
        di                                                     ;#4049: F3
        ld      sp,STACK_BASE                                  ;#404A: 31 80 DF
        ld      hl,ROM_HEADER                                  ;#404D: 21 00 40
        call    READ_WORD_FROM_GAME_CART                       ;#4050: CD BA 40
        ld      hl,CART_MAGIC_AB                               ;#4053: 21 41 42
        rst     20h                                            ;#4056: E7
        jp      nz,BOOT_SKIP_INIT                              ;#4057: C2 87 40
        ld      hl,ROM_HEADER+2                                ;#405A: 21 02 40
        call    READ_WORD_FROM_GAME_CART                       ;#405D: CD BA 40
        jp      z,BOOT_SKIP_INIT                               ;#4060: CA 87 40
        ex      de,hl                                          ;#4063: EB
        ld      (GAME_CART_INIT_POINTER),hl                    ;#4064: 22 32 D1

SETUP_GAME_CART_RAM:
        ; Copy BIOS work area F100..F413 to D500, verify+patch cart, install ISR, identify
        ld      hl,BIOS_WORK_AREA                              ;#4067: 21 00 F1
        ld      de,BIOS_WORK_AREA_COPY                         ;#406A: 11 00 D5
        ld      bc,314h                                        ;#406D: 01 14 03
        ldir                                                   ;#4070: ED B0
        call    VERIFY_AND_PATCH_GAME_CART                     ;#4072: CD A4 4B
        jp      nz,BOOT_SKIP_INIT                              ;#4075: C2 87 40
        call    INSTALL_ISR_TO_RAM                             ;#4078: CD EB 4B
        call    IDENTIFY_GAME_CART_DISPATCH                    ;#407B: CD BF 5C
        ld      hl,GAME_CART_VALID_FLAG                        ;#407E: 21 3C D1
        ld      a,(hl)                                         ;#4081: 7E
        or      a                                              ;#4082: B7
        jr      nz,LAUNCH_GAME_CART                            ;#4083: 20 0C
        dec     a                                              ;#4085: 3D
        ld      (hl),a                                         ;#4086: 77
BOOT_SKIP_INIT:
        ; Init pointer was zero: clear init flag bytes and fall into MAIN_ENTRY
        xor     a                                              ;#4087: AF
        ld      (TOP_MENU_MODE),a                              ;#4088: 32 29 D1
        ld      (GAME_DISPLAY_ACTIVE),a                        ;#408B: 32 3D D1
        jp      MAIN_ENTRY                                     ;#408E: C3 5E 4E

LAUNCH_GAME_CART:
        ; Set hook flags, jp LAUNCH_GAME_CART_TRAMPOLINE_RAM (ENASLTs game cart at page 1)
        di                                                     ;#4091: F3
        ld      a,0FFh                                         ;#4092: 3E FF
        ld      (GAME_DISPLAY_ACTIVE),a                        ;#4094: 32 3D D1
        xor     a                                              ;#4097: AF
        ld      (IN_ISR_LOCK),a                                ;#4098: 32 3B D1
        ld      (DISK_BASIC_CALSLT_PAIR),a                     ;#409B: 32 3A D3
        jp      LAUNCH_GAME_CART_TRAMPOLINE_RAM                ;#409E: C3 3B D8

GET_PAGE1_SLOT:
        ; Combine primary slot register and EXPTBL/SLTTBL into full page-1 slot byte
        call    BIOS_RSLREG                                    ;#40A1: CD 38 01
        rrca                                                   ;#40A4: 0F
        rrca                                                   ;#40A5: 0F
        and     3                                              ;#40A6: E6 03
        ld      c,a                                            ;#40A8: 4F
        ld      b,0                                            ;#40A9: 06 00
        ld      hl,BIOS_EXPTBL                                 ;#40AB: 21 C1 FC
        add     hl,bc                                          ;#40AE: 09
        or      (hl)                                           ;#40AF: B6
        ld      c,a                                            ;#40B0: 4F
        inc     hl                                             ;#40B1: 23
        inc     hl                                             ;#40B2: 23
        inc     hl                                             ;#40B3: 23
        inc     hl                                             ;#40B4: 23
        ld      a,(hl)                                         ;#40B5: 7E
        and     0Ch                                            ;#40B6: E6 0C
        or      c                                              ;#40B8: B1
        ret                                                    ;#40B9: C9

READ_WORD_FROM_GAME_CART:
        ; Read 2-byte word at (HL) from GAME_CART_SLOT into DE; Z if both bytes zero
        ld      a,(GAME_CART_SLOT)                             ;#40BA: 3A 2F D1
        ld      c,a                                            ;#40BD: 4F
READ_WORD_FROM_SLOT_C:
        ; Read word at (HL) from slot byte already loaded in C; into DE
        call    READ_BYTE_OR_INTO_E                            ;#40BE: CD C2 40
        ld      e,d                                            ;#40C1: 5A
READ_BYTE_OR_INTO_E:
        ; RDSLT byte at (HL) from slot C; D=byte, A=byte|E (running OR), inc HL
        ld      a,c                                            ;#40C2: 79
        push    bc                                             ;#40C3: C5
        push    de                                             ;#40C4: D5
        call    BIOS_RDSLT                                     ;#40C5: CD 0C 00
        pop     de                                             ;#40C8: D1
        pop     bc                                             ;#40C9: C1
        ld      d,a                                            ;#40CA: 57
        or      e                                              ;#40CB: B3
        inc     hl                                             ;#40CC: 23
        ret                                                    ;#40CD: C9

COPY_SLOT_SCANNER_TO_RAM:
        ; Copy the 84h-byte slot-scan routine to SLOT_SCANNER_RAM and jump into RAM
        ld      hl,SLOT_SCANNER_ROM                            ;#40CE: 21 DC 40
        ld      de,SLOT_SCANNER_RAM                            ;#40D1: 11 00 C0
        LD_BC_SIZE SLOT_SCANNER_ROM                            ;#40D4: 01 84 00
        ldir                                                   ;#40D7: ED B0
        jp      SLOT_SCANNER_RAM                               ;#40D9: C3 00 C0

SCAN_ALL_SLOTS_FOR_DISK_BASIC:
        ; Outer loop over 4 primary slots; runs from RAM at SLOT_SCANNER_RAM

        phase   0C000h
SLOT_SCANNER_RAM:
        ; Page-3 scratch base: slot scanner runtime copy, disk save/load record buffers
        ld      bc,400h                                        ;#C000: 01 00 04
        ld      hl,BIOS_EXPTBL                                 ;#C003: 21 C1 FC
SCAN_ALL_SLOTS_LOOP:
        ; Outer-loop body: try one primary slot
        push    bc                                             ;#C006: C5
        push    hl                                             ;#C007: E5
        ld      a,(hl)                                         ;#C008: 7E
        bit     7,a                                            ;#C009: CB 7F
        jr      nz,SCAN_ALL_SLOTS_EXPANDED                     ;#C00B: 20 1D
        ld      b,c                                            ;#C00D: 41
        call    IS_OWN_SLOT                                    ;#C00E: CD 2F C0
        jr      z,SCAN_ALL_SLOTS_NEXT                          ;#C011: 28 04
        ld      a,c                                            ;#C013: 79
        call    FIND_DISK_BASIC_IN_SLOT                        ;#C014: CD 4B C0
SCAN_ALL_SLOTS_NEXT:
        ; Restore HL/BC and either exit (carry) or advance to the next slot
        pop     hl                                             ;#C017: E1
        pop     bc                                             ;#C018: C1
        jr      c,SCAN_ALL_SLOTS_RESTORE_OWN                   ;#C019: 38 04
        inc     hl                                             ;#C01B: 23
        inc     c                                              ;#C01C: 0C
        djnz    SCAN_ALL_SLOTS_LOOP                            ;#C01D: 10 E7
SCAN_ALL_SLOTS_RESTORE_OWN:
        ; Re-enable own slot at page 1 before returning
        push    af                                             ;#C01F: F5
        ld      a,(OWN_SLOT_RAW)                               ;#C020: 3A 2E D1
        ld      h,40h                                          ;#C023: 26 40
        call    BIOS_ENASLT                                    ;#C025: CD 24 00
        pop     af                                             ;#C028: F1
        ret                                                    ;#C029: C9

SCAN_ALL_SLOTS_EXPANDED:
        ; Expanded-slot path: dispatch into SCAN_SUBSLOTS_FOR_DISK_BASIC
        call    SCAN_SUBSLOTS_FOR_DISK_BASIC                   ;#C02A: CD 34 C0
        jr      SCAN_ALL_SLOTS_NEXT                            ;#C02D: 18 E8

IS_OWN_SLOT:
        ; Z flag set when A equals the cart's own slot byte (OWN_SLOT_RAW)
        ld      a,(OWN_SLOT_RAW)                               ;#C02F: 3A 2E D1
        cp      b                                              ;#C032: B8
        ret                                                    ;#C033: C9

SCAN_SUBSLOTS_FOR_DISK_BASIC:
        ; Inner loop over the 4 subslots of an expanded slot
        and     80h                                            ;#C034: E6 80
        or      c                                              ;#C036: B1
        ld      b,4                                            ;#C037: 06 04
SCAN_SUBSLOTS_LOOP:
        ; Subslot-loop body: build slot byte, skip self, try the slot
        push    bc                                             ;#C039: C5
        ld      b,a                                            ;#C03A: 47
        call    IS_OWN_SLOT                                    ;#C03B: CD 2F C0
        jr      z,SCAN_SUBSLOTS_NEXT                           ;#C03E: 28 04
        ld      a,b                                            ;#C040: 78
        call    FIND_DISK_BASIC_IN_SLOT                        ;#C041: CD 4B C0
SCAN_SUBSLOTS_NEXT:
        ; Pop, return on carry, else advance to the next subslot
        pop     bc                                             ;#C044: C1
        ret     c                                              ;#C045: D8
        add     a,4                                            ;#C046: C6 04
        djnz    SCAN_SUBSLOTS_LOOP                             ;#C048: 10 EF
        ret                                                    ;#C04A: C9

FIND_DISK_BASIC_IN_SLOT:
        ; Map A to page 1, search 8KB for "Disk BASIC", record slot on hit
        push    af                                             ;#C04B: F5
        ld      h,40h                                          ;#C04C: 26 40
        call    BIOS_ENASLT                                    ;#C04E: CD 24 00
        ld      hl,ROM_HEADER                                  ;#C051: 21 00 40
        ld      de,TXT_DISK_BASIC_TAIL                         ;#C054: 11 7B C0
        ld      bc,2000h                                       ;#C057: 01 00 20
FIND_DISK_BASIC_SCAN_LOOP:
        ; cpir for 'D', then 9-byte compare against TXT_DISK_BASIC_TAIL
        ld      a,44h                                          ;#C05A: 3E 44
        cpir                                                   ;#C05C: ED B1
        jr      nz,FIND_DISK_BASIC_NOT_HERE                    ;#C05E: 20 18
        push    bc                                             ;#C060: C5
        push    de                                             ;#C061: D5
        push    hl                                             ;#C062: E5
        ld      b,9                                            ;#C063: 06 09
FIND_DISK_BASIC_COMPARE:
        ; 9-byte compare loop: (DE) vs (HL)
        ld      a,(de)                                         ;#C065: 1A
        cp      (hl)                                           ;#C066: BE
        jr      nz,FIND_DISK_BASIC_MISMATCH                    ;#C067: 20 04
        inc     hl                                             ;#C069: 23
        inc     de                                             ;#C06A: 13
        djnz    FIND_DISK_BASIC_COMPARE                        ;#C06B: 10 F8
FIND_DISK_BASIC_MISMATCH:
        ; Compare failed: pop registers and resume the cpir search
        pop     hl                                             ;#C06D: E1
        pop     de                                             ;#C06E: D1
        pop     bc                                             ;#C06F: C1
        jr      nz,FIND_DISK_BASIC_SCAN_LOOP                   ;#C070: 20 E8
        pop     af                                             ;#C072: F1
        ld      (DISK_BASIC_SLOT),a                            ;#C073: 32 3B D3
        scf                                                    ;#C076: 37
        ret                                                    ;#C077: C9

FIND_DISK_BASIC_NOT_HERE:
        ; Restore AF and return with carry clear (no Disk BASIC in this slot)
        pop     af                                             ;#C078: F1
        and     a                                              ;#C079: A7
        ret                                                    ;#C07A: C9

TXT_DISK_BASIC_TAIL:
        ; 9-byte reference "isk BASIC" — the bytes the scanner matches after the 'D'
        db      "isk BASIC"                                    ;#C07B: 69 73 6B 20 42 41 53 49 43
        dephase

SLOT_SCANNER_ROM_END:
BOOT_INTO_DISK_BASIC:
        ; Disk BASIC located: border=1 + CHGCLR, install return hook, CALSLT into init
        ld      a,1                                            ;#4160: 3E 01
        ld      (BIOS_BDRCLR),a                                ;#4162: 32 EB F3
        call    BIOS_CHGCLR                                    ;#4165: CD 62 00
        ld      a,(DISK_BASIC_SLOT)                            ;#4168: 3A 3B D3
        ld      c,a                                            ;#416B: 4F
        ld      hl,ROM_HEADER+2                                ;#416C: 21 02 40
        call    READ_WORD_FROM_SLOT_C                          ;#416F: CD BE 40
        ld      iy,(DISK_BASIC_CALSLT_PAIR)                    ;#4172: FD 2A 3A D3
        push    de                                             ;#4176: D5
        pop     ix                                             ;#4177: DD E1
        ld      hl,RETURN_FROM_DISK_BASIC                      ;#4179: 21 95 41
        ld      de,RETURN_FROM_DISK_BASIC_RAM                  ;#417C: 11 00 C8
        LD_BC_SIZE RETURN_FROM_DISK_BASIC                      ;#417F: 01 0B 00
        ldir                                                   ;#4182: ED B0
        ld      hl,TRAMPOLINE_TO_RETURN_FROM_DISK_BASIC        ;#4184: 21 A0 41
        ld      de,BIOS_H_DISK_RETURN_HOOK                     ;#4187: 11 DA FE
        ld      bc,3                                           ;#418A: 01 03 00
        ldir                                                   ;#418D: ED B0
        call    BIOS_CALSLT                                    ;#418F: CD 1C 00
        jp      BIOS_H_DISK_INIT_RESUME                        ;#4192: C3 CB FE

RETURN_FROM_DISK_BASIC:
        ; Trampoline copied to its _RAM peer: re-enable own slot; jp RELOAD_GAME_FROM_RAM
        ld      a,(OWN_SLOT_RAW)                               ;#4195: 3A 2E D1
        ld      h,40h                                          ;#4198: 26 40
        call    BIOS_ENASLT                                    ;#419A: CD 24 00
        jp      RELOAD_GAME_FROM_RAM                           ;#419D: C3 3D 40

RETURN_FROM_DISK_BASIC_END:
TRAMPOLINE_TO_RETURN_FROM_DISK_BASIC:
        ; 3-byte stub copied to BIOS_H_DISK_RETURN_HOOK: jp RETURN_FROM_DISK_BASIC_RAM
        jp      RETURN_FROM_DISK_BASIC_RAM                     ;#41A0: C3 00 C8

IN_GAME_MENU:
        ; Show 6-item in-game menu; on pick, write IN_GAME_MENU_PARAMS[A] to D136 and jump
        call    SET_DEFAULT_HANDLERS                           ;#41A3: CD D5 41
IN_GAME_MENU_REENTRY:
        ; jp-target shared by every submenu handler: re-run the in-game menu loop
        call    SAVE_GAME_DISPLAY                              ;#41A6: CD F3 61
IN_GAME_MENU_REDRAW:
        ; jp-target for END/cancel: redraw the menu without re-running setup
        call    DRAW_IN_GAME_MENU                              ;#41A9: CD 21 44
        ld      hl,IN_GAME_MENU_ITEMS                          ;#41AC: 21 A6 44
        ld      b,6                                            ;#41AF: 06 06
        call    MENU_SELECT                                    ;#41B1: CD 00 64
        ld      b,a                                            ;#41B4: 47
        ld      hl,IN_GAME_MENU_PARAMS                         ;#41B5: 21 CF 41
        call    ADD_A_TO_HL                                    ;#41B8: CD ED 60
        ld      a,(hl)                                         ;#41BB: 7E
        ld      (IN_GAME_MENU_PARAM),a                         ;#41BC: 32 36 D1
        ld      a,b                                            ;#41BF: 78
        call    CALL_INDIRECT_A                                ;#41C0: CD E7 61
IN_GAME_MENU_HANDLERS:
        ; 6 word-pointer entries; consumed inline by CALL_INDIRECT_A at CALL_INDIRECT_A
        dw      SUBMENU_DISK_SAVE                              ;#41C3: E2 41
        dw      SUBMENU_DISK_LOAD                              ;#41C5: 87 42
        dw      SUBMENU_TAPE_SAVE                              ;#41C7: 05 43
        dw      SUBMENU_TAPE_LOAD                              ;#41C9: 5D 43
        dw      SUBMENU_RANKING_MODE                           ;#41CB: B0 43
        dw      SUBMENU_END                                    ;#41CD: 09 44

IN_GAME_MENU_PARAMS:
        ; 6 bytes paralleling IN_GAME_MENU_HANDLERS; entry K written to D136 on pick
        dh      "102030406000"                                 ;#41CF: 10 20 30 40 60 00

SET_DEFAULT_HANDLERS:
        ; Initialise D16C/D16E with the menu-entry default handler addresses (3A21/3A2C)
        LOAD_NAME_TABLE hl, 17, 1                              ;#41D5: 21 21 3A
        ld      (SUBMENU_HEADING_VRAM_BASE),hl                 ;#41D8: 22 6C D1
        LOAD_NAME_TABLE hl, 17, 12                             ;#41DB: 21 2C 3A
        ld      (SUBMENU_BODY_VRAM_BASE),hl                    ;#41DE: 22 6E D1
        ret                                                    ;#41E1: C9

SUBMENU_DISK_SAVE:
        ; In-game menu option 0: open DISK SAVE submenu (uses Disk BASIC slot if present)
        call    CHECK_DISK_BIOS_AVAILABLE                      ;#41E2: CD 7D 67
        jr      z,IN_GAME_MENU_REDRAW                          ;#41E5: 28 C2
        ld      hl,DISK_ERROR_RECOVER_AND_RETRY                ;#41E7: 21 5C 69
        call    SETUP_INTERSLOT_CALL                           ;#41EA: CD 29 69
        call    DRAW_SUBMENU_DISK_SAVE                         ;#41ED: CD B7 44
        call    DRAW_SUBMENU_HEADING                           ;#41F0: CD 47 45
        ld      hl,SUBMENU_DISK_SAVE_POSITIONS                 ;#41F3: 21 09 45
        ld      b,5                                            ;#41F6: 06 05
        call    MENU_SELECT                                    ;#41F8: CD 00 64
        ld      b,a                                            ;#41FB: 47
        add     a,10h                                          ;#41FC: C6 10
        ld      (IN_GAME_MENU_PARAM),a                         ;#41FE: 32 36 D1
        ld      a,b                                            ;#4201: 78
        call    CALL_INDIRECT_A                                ;#4202: CD E7 61
SUBMENU_DISK_SAVE_HANDLERS:
        ; 5-entry inline word-pointer table dispatched after DISK SAVE pick
        dw      SUBMENU_DISK_SAVE_HISCORE_PICK                 ;#4205: 1E 42
        dw      SUBMENU_DISK_SAVE_DATA_PICK                    ;#4207: 0F 42
        dw      SUBMENU_DISK_SAVE_DATA_PICK                    ;#4209: 0F 42
        dw      SUBMENU_DISK_SAVE_RANKING_PICK                 ;#420B: 35 42
        dw      IN_GAME_MENU_REDRAW                            ;#420D: A9 41

SUBMENU_DISK_SAVE_DATA_PICK:
        ; GAME or SCREEN pick in DISK SAVE: prompt + DISK_SAVE_GAME_FULL
        call    PROMPT_INPUT_FILE_NAME                         ;#420F: CD 4B 42
        jp      z,SUBMENU_DISK_SAVE                            ;#4212: CA E2 41
        call    RESTORE_GAME_DISPLAY                           ;#4215: CD 68 62
        call    DISK_SAVE_GAME_FULL                            ;#4218: CD 8B 64
        jp      IN_GAME_MENU_REENTRY                           ;#421B: C3 A6 41

SUBMENU_DISK_SAVE_HISCORE_PICK:
        ; Picked HI SCORE: prompt + DISK_SAVE_HISCORE if GAME_RAM_HISCORE_PTR set
        ld      hl,(GAME_RAM_HISCORE_PTR)                      ;#421E: 2A 0C D3
        ld      a,h                                            ;#4221: 7C
        or      l                                              ;#4222: B5
        jp      z,SUBMENU_DISK_SAVE                            ;#4223: CA E2 41
        call    PROMPT_INPUT_FILE_NAME                         ;#4226: CD 4B 42
        jp      z,SUBMENU_DISK_SAVE                            ;#4229: CA E2 41
        call    RESTORE_GAME_DISPLAY                           ;#422C: CD 68 62
        call    DISK_SAVE_HISCORE                              ;#422F: CD 11 65
        jp      IN_GAME_MENU_REENTRY                           ;#4232: C3 A6 41

SUBMENU_DISK_SAVE_RANKING_PICK:
        ; Picked RANKING: prompt + DISK_SAVE_RANKING if RANKING_AVAILABLE_FLAG != 0
        ld      a,(RANKING_AVAILABLE_FLAG)                     ;#4235: 3A 32 D3
        or      a                                              ;#4238: B7
        jp      z,SUBMENU_DISK_SAVE                            ;#4239: CA E2 41
        call    PROMPT_INPUT_FILE_NAME                         ;#423C: CD 4B 42
        jp      z,SUBMENU_DISK_SAVE                            ;#423F: CA E2 41
        call    RESTORE_GAME_DISPLAY                           ;#4242: CD 68 62
        call    DISK_SAVE_RANKING                              ;#4245: CD F8 64
        jp      IN_GAME_MENU_REENTRY                           ;#4248: C3 A6 41

PROMPT_INPUT_FILE_NAME:
        ; Subheading + "INPUT FILE NAME"; read 8-byte name via INPUT_FILE_NAME_INIT_FCB
        call    DRAW_SUBMENU_SUBHEADING                        ;#424B: CD 9F 45
        call    DRAW_FILE_NAME_PROMPT                          ;#424E: CD 57 42
        LOAD_NAME_TABLE hl, 19, 12                             ;#4251: 21 6C 3A
        jp      INPUT_FILE_NAME_INIT_FCB                       ;#4254: C3 08 67

DRAW_FILE_NAME_PROMPT:
        ; Pick between TXT_INPUT_FILE_NAME and TXT_SELECT_FILE_NAME based on op kind
        ld      hl,TXT_INPUT_FILE_NAME                         ;#4257: 21 66 42
        jr      DRAW_FILE_NAME_PROMPT_TAIL                     ;#425A: 18 03

DRAW_SELECT_FILE_NAME_PROMPT:
        ; Force "SELECT FILE NAME" variant: HL=TXT_SELECT_FILE_NAME, fall into tail
        ld      hl,TXT_SELECT_FILE_NAME                        ;#425C: 21 76 42
DRAW_FILE_NAME_PROMPT_TAIL:
        ; Common tail: DE=SUBMENU_BODY_VRAM_BASE; jp DRAW_TEXT_STREAM_AT_DE
        ld      de,(SUBMENU_BODY_VRAM_BASE)                    ;#425F: ED 5B 6E D1
        jp      DRAW_TEXT_STREAM_AT_DE                         ;#4263: C3 0F 61

TXT_INPUT_FILE_NAME:
        ; Encoded "INPUT FILE NAME" text stream (no leading dw target)
        db      "INPUT", 0, "FILE", 0, "NAME"                  ;#4266: 49 4E 50 55 54 00 46 49 4C 45 00 4E 41 4D 45
        TEXT_TERMINATOR                                        ;#4275: FF

TXT_SELECT_FILE_NAME:
        ; Encoded "SELECT FILE NAME" text stream (no leading dw target)
        db      "SELECT", 0, "FILE", 0, "NAME"                 ;#4276: 53 45 4C 45 43 54 00 46 49 4C 45 00 4E 41 4D 45
        TEXT_TERMINATOR                                        ;#4286: FF

SUBMENU_DISK_LOAD:
        ; In-game menu option 1: open DISK LOAD submenu
        call    CHECK_DISK_BIOS_AVAILABLE                      ;#4287: CD 7D 67
        jp      z,IN_GAME_MENU_REDRAW                          ;#428A: CA A9 41
        call    DRAW_SUBMENU_DISK_LOAD                         ;#428D: CD C3 44
        call    DRAW_SUBMENU_HEADING                           ;#4290: CD 47 45
        ld      hl,SUBMENU_DISK_LOAD_POSITIONS                 ;#4293: 21 3F 45
        ld      b,4                                            ;#4296: 06 04
        call    MENU_SELECT                                    ;#4298: CD 00 64
        ld      b,a                                            ;#429B: 47
        ld      hl,SUBMENU_DISK_LOAD_PARAMS                    ;#429C: 21 B2 42
        call    ADD_A_TO_HL                                    ;#429F: CD ED 60
        ld      a,(hl)                                         ;#42A2: 7E
        ld      (IN_GAME_MENU_PARAM),a                         ;#42A3: 32 36 D1
        ld      a,b                                            ;#42A6: 78
        call    CALL_INDIRECT_A                                ;#42A7: CD E7 61
SUBMENU_DISK_LOAD_HANDLERS:
        ; 4-entry inline word-pointer table dispatched after DISK LOAD pick
        dw      SUBMENU_DISK_LOAD_HISCORE_PICK                 ;#42AA: C4 42
        dw      SUBMENU_DISK_LOAD_GAME_PICK                    ;#42AC: B6 42
        dw      SUBMENU_DISK_LOAD_RANKING_PICK                 ;#42AE: DA 42
        dw      IN_GAME_MENU_REDRAW                            ;#42B0: A9 41

SUBMENU_DISK_LOAD_PARAMS:
        ; 4 bytes paralleling SUBMENU_DISK_LOAD_HANDLERS; written to D136 on pick
        dh      "20222300"                                     ;#42B2: 20 22 23 00

SUBMENU_DISK_LOAD_GAME_PICK:
        ; Picked GAME: select file via PROMPT_AND_SELECT_FILE, call DISK_LOAD_GAME
        call    PROMPT_AND_SELECT_FILE                         ;#42B6: CD EF 42
        jr      c,SUBMENU_DISK_LOAD                            ;#42B9: 38 CC
        call    RESTORE_GAME_DISPLAY                           ;#42BB: CD 68 62
        call    DISK_LOAD_GAME                                 ;#42BE: CD 27 65
        jp      IN_GAME_MENU_REENTRY                           ;#42C1: C3 A6 41

SUBMENU_DISK_LOAD_HISCORE_PICK:
        ; Picked HI SCORE in DISK LOAD: PROMPT_AND_SELECT_FILE + DISK_LOAD_HISCORE
        ld      hl,(GAME_RAM_HISCORE_PTR)                      ;#42C4: 2A 0C D3
        ld      a,h                                            ;#42C7: 7C
        or      l                                              ;#42C8: B5
        jp      z,SUBMENU_DISK_LOAD                            ;#42C9: CA 87 42
        call    PROMPT_AND_SELECT_FILE                         ;#42CC: CD EF 42
        jr      c,SUBMENU_DISK_LOAD                            ;#42CF: 38 B6
        call    RESTORE_GAME_DISPLAY                           ;#42D1: CD 68 62
        call    DISK_LOAD_HISCORE                              ;#42D4: CD 91 65
        jp      IN_GAME_MENU_REENTRY                           ;#42D7: C3 A6 41

SUBMENU_DISK_LOAD_RANKING_PICK:
        ; Picked RANKING in DISK LOAD: PROMPT_AND_SELECT_FILE + DISK_LOAD_RANKING
        ld      a,(RANKING_AVAILABLE_FLAG)                     ;#42DA: 3A 32 D3
        or      a                                              ;#42DD: B7
        jp      z,SUBMENU_DISK_LOAD                            ;#42DE: CA 87 42
        call    PROMPT_AND_SELECT_FILE                         ;#42E1: CD EF 42
        jr      c,SUBMENU_DISK_LOAD                            ;#42E4: 38 A1
        call    RESTORE_GAME_DISPLAY                           ;#42E6: CD 68 62
        call    DISK_LOAD_RANKING                              ;#42E9: CD 7B 65
        jp      IN_GAME_MENU_REENTRY                           ;#42EC: C3 A6 41

PROMPT_AND_SELECT_FILE:
        ; Setup CALSLT trampoline, draw subheading + "SEARCH FILE", run file picker
        ld      hl,DISK_ERROR_RETRY_NO_SAVE                    ;#42EF: 21 75 69
        call    SETUP_INTERSLOT_CALL                           ;#42F2: CD 29 69
        call    DRAW_SUBMENU_SUBHEADING                        ;#42F5: CD 9F 45
        call    DRAW_SEARCH_FILE_PROMPT                        ;#42F8: CD E3 45
        call    FILE_PICKER                                    ;#42FB: CD 4B 6A
        ret     c                                              ;#42FE: D8
        ld      hl,DISK_ERROR_RECOVER_AND_RETRY                ;#42FF: 21 5C 69
        jp      SETUP_INTERSLOT_CALL                           ;#4302: C3 29 69

SUBMENU_TAPE_SAVE:
        ; In-game menu option 2: open TAPE SAVE submenu (cassette save)
        call    DRAW_SUBMENU_DISK_SAVE                         ;#4305: CD B7 44
        call    DRAW_SUBMENU_HEADING                           ;#4308: CD 47 45
        ld      hl,SUBMENU_DISK_SAVE_POSITIONS                 ;#430B: 21 09 45
        ld      b,5                                            ;#430E: 06 05
        call    MENU_SELECT                                    ;#4310: CD 00 64
        ld      b,a                                            ;#4313: 47
        add     a,30h                                          ;#4314: C6 30
        ld      (IN_GAME_MENU_PARAM),a                         ;#4316: 32 36 D1
        ld      a,b                                            ;#4319: 78
        call    CALL_INDIRECT_A                                ;#431A: CD E7 61
SUBMENU_TAPE_SAVE_HANDLERS:
        ; 5-entry inline word-pointer table dispatched after TAPE SAVE pick
        dw      SUBMENU_TAPE_SAVE_HISCORE_PICK                 ;#431D: 39 43
        dw      SUBMENU_TAPE_SAVE_SCREEN_PICK                  ;#431F: 30 43
        dw      SUBMENU_TAPE_SAVE_GAME_PICK                    ;#4321: 27 43
        dw      SUBMENU_TAPE_SAVE_RANKING_PICK                 ;#4323: 4D 43
        dw      IN_GAME_MENU_REDRAW                            ;#4325: A9 41

SUBMENU_TAPE_SAVE_GAME_PICK:
        ; GAME pick: subheading + TAPE_SAVE_GAME_DATA + RESTORE_GAME_DISPLAY tail
        call    DRAW_SUBMENU_SUBHEADING                        ;#4327: CD 9F 45
        call    TAPE_SAVE_GAME_DATA                            ;#432A: CD F5 6C
        jp      IN_GAME_MENU_REENTRY                           ;#432D: C3 A6 41

SUBMENU_TAPE_SAVE_SCREEN_PICK:
        ; SCREEN pick: subheading + TAPE_SAVE_SCREEN
        call    DRAW_SUBMENU_SUBHEADING                        ;#4330: CD 9F 45
        call    TAPE_SAVE_SCREEN                               ;#4333: CD 14 6D
        jp      IN_GAME_MENU_REENTRY                           ;#4336: C3 A6 41

SUBMENU_TAPE_SAVE_HISCORE_PICK:
        ; HI SCORE pick: validate GAME_RAM_HISCORE_PTR ptr, subheading + TAPE_SAVE_HISCORE
        ld      hl,(GAME_RAM_HISCORE_PTR)                      ;#4339: 2A 0C D3
        ld      a,h                                            ;#433C: 7C
        or      l                                              ;#433D: B5
        jp      z,SUBMENU_TAPE_SAVE                            ;#433E: CA 05 43
        call    DRAW_SUBMENU_SUBHEADING                        ;#4341: CD 9F 45
        call    TAPE_SAVE_HISCORE                              ;#4344: CD 3F 6D
        call    RESTORE_GAME_DISPLAY                           ;#4347: CD 68 62
        jp      IN_GAME_MENU_REENTRY                           ;#434A: C3 A6 41

SUBMENU_TAPE_SAVE_RANKING_PICK:
        ; RANKING pick: validate RANKING_AVAILABLE_FLAG; subheading + TAPE_SAVE_RANKING
        ld      a,(RANKING_AVAILABLE_FLAG)                     ;#434D: 3A 32 D3
        or      a                                              ;#4350: B7
        jp      z,SUBMENU_TAPE_SAVE                            ;#4351: CA 05 43
        call    DRAW_SUBMENU_SUBHEADING                        ;#4354: CD 9F 45
        call    TAPE_SAVE_RANKING                              ;#4357: CD 28 6D
        jp      IN_GAME_MENU_REENTRY                           ;#435A: C3 A6 41

SUBMENU_TAPE_LOAD:
        ; In-game menu option 3: open TAPE LOAD submenu (cassette load)
        call    DRAW_SUBMENU_DISK_LOAD                         ;#435D: CD C3 44
        call    DRAW_SUBMENU_HEADING                           ;#4360: CD 47 45
        ld      hl,SUBMENU_DISK_LOAD_POSITIONS                 ;#4363: 21 3F 45
        ld      b,4                                            ;#4366: 06 04
        call    MENU_SELECT                                    ;#4368: CD 00 64
        ld      b,a                                            ;#436B: 47
        ld      hl,SUBMENU_TAPE_LOAD_PARAMS                    ;#436C: 21 82 43
        call    ADD_A_TO_HL                                    ;#436F: CD ED 60
        ld      a,(hl)                                         ;#4372: 7E
        ld      (IN_GAME_MENU_PARAM),a                         ;#4373: 32 36 D1
        ld      a,b                                            ;#4376: 78
        call    CALL_INDIRECT_A                                ;#4377: CD E7 61
SUBMENU_TAPE_LOAD_HANDLERS:
        ; 4-entry inline word-pointer table dispatched after TAPE LOAD pick
        dw      SUBMENU_TAPE_LOAD_HISCORE_PICK                 ;#437A: 8F 43
        dw      SUBMENU_TAPE_LOAD_GAME_PICK                    ;#437C: 86 43
        dw      SUBMENU_TAPE_LOAD_RANKING_PICK                 ;#437E: A0 43
        dw      IN_GAME_MENU_REDRAW                            ;#4380: A9 41

SUBMENU_TAPE_LOAD_PARAMS:
        ; 4 bytes paralleling SUBMENU_TAPE_LOAD_HANDLERS; written to D136 on pick
        dh      "40424300"                                     ;#4382: 40 42 43 00

SUBMENU_TAPE_LOAD_GAME_PICK:
        ; GAME pick: subheading + TAPE_LOAD_GAME_DATA
        call    DRAW_SUBMENU_SUBHEADING                        ;#4386: CD 9F 45
        call    TAPE_LOAD_GAME_DATA                            ;#4389: CD 53 6D
        jp      IN_GAME_MENU_REENTRY                           ;#438C: C3 A6 41

SUBMENU_TAPE_LOAD_HISCORE_PICK:
        ; HI SCORE pick: validate GAME_RAM_HISCORE_PTR, subheading + TAPE_LOAD_HISCORE
        ld      hl,(GAME_RAM_HISCORE_PTR)                      ;#438F: 2A 0C D3
        ld      a,h                                            ;#4392: 7C
        or      l                                              ;#4393: B5
        jp      z,SUBMENU_TAPE_LOAD                            ;#4394: CA 5D 43
        call    DRAW_SUBMENU_SUBHEADING                        ;#4397: CD 9F 45
        call    TAPE_LOAD_HISCORE                              ;#439A: CD A4 6D
        jp      IN_GAME_MENU_REENTRY                           ;#439D: C3 A6 41

SUBMENU_TAPE_LOAD_RANKING_PICK:
        ; RANKING pick: validate RANKING_AVAILABLE_FLAG, subheading + TAPE_LOAD_RANKING
        ld      a,(RANKING_AVAILABLE_FLAG)                     ;#43A0: 3A 32 D3
        or      a                                              ;#43A3: B7
        jp      z,SUBMENU_TAPE_LOAD                            ;#43A4: CA 5D 43
        call    DRAW_SUBMENU_SUBHEADING                        ;#43A7: CD 9F 45
        call    TAPE_LOAD_RANKING                              ;#43AA: CD 90 6D
        jp      IN_GAME_MENU_REENTRY                           ;#43AD: C3 A6 41

SUBMENU_RANKING_MODE:
        ; In-game menu option 4: open RANKING (high-score) view
        ld      a,(RANKING_AVAILABLE_FLAG)                     ;#43B0: 3A 32 D3
        or      a                                              ;#43B3: B7
        jp      z,IN_GAME_MENU_REDRAW                          ;#43B4: CA A9 41
        call    DRAW_SUBMENU_RANKING                           ;#43B7: CD F9 45
        call    DRAW_SUBMENU_HEADING                           ;#43BA: CD 47 45
        ld      hl,SUBMENU_RANKING_POSITIONS                   ;#43BD: 21 35 46
        ld      b,4                                            ;#43C0: 06 04
        call    MENU_SELECT                                    ;#43C2: CD 00 64
        call    CALL_INDIRECT_A                                ;#43C5: CD E7 61
SUBMENU_RANKING_HANDLERS:
        ; 4-entry inline word-pointer table dispatched after RANKING pick
        dw      SUBMENU_RANKING_DISPLAY_DATA                   ;#43C8: DF 43
        dw      SUBMENU_RANKING_CHANGE_NAME                    ;#43CA: D0 43
        dw      SUBMENU_RANKING_PRINT_DATA                     ;#43CC: E8 43
        dw      IN_GAME_MENU_REDRAW                            ;#43CE: A9 41

SUBMENU_RANKING_CHANGE_NAME:
        ; CHANGE NAME item: clear name area, draw, run DRAW_RANKING_DISPLAY
        call    CLEAR_NAME_BOTTOM                              ;#43D0: CD CE 62
        call    DRAW_RC_CATALOG_CODE                           ;#43D3: CD 2A 44
        call    DRAW_SUBMENU_HEADING                           ;#43D6: CD 47 45
        call    DRAW_RANKING_DISPLAY                           ;#43D9: CD 11 54
        jp      IN_GAME_MENU_REDRAW                            ;#43DC: C3 A9 41

SUBMENU_RANKING_DISPLAY_DATA:
        ; DISPLAY DATA: RANKING_RECORD_BOTH (purge old) + VIEW_RANKING_TABLE (show table)
        call    RANKING_RECORD_BOTH                            ;#43DF: CD 74 55
        call    VIEW_RANKING_TABLE                             ;#43E2: CD 67 56
        jp      IN_GAME_MENU_REDRAW                            ;#43E5: C3 A9 41

SUBMENU_RANKING_PRINT_DATA:
        ; PRINT DATA item: print the ranking via the printer module
        call    RANKING_RECORD_BOTH                            ;#43E8: CD 74 55
        call    RESTORE_GAME_DISPLAY                           ;#43EB: CD 68 62
        call    PRINT_RANKING_TABLE_TO_PRINTER                 ;#43EE: CD E7 57
        call    SAVE_GAME_DISPLAY                              ;#43F1: CD F3 61
        jp      IN_GAME_MENU_REDRAW                            ;#43F4: C3 A9 41
        db      "@@PRINT", 0, "RANKING@@"                      ;#43F7: 40 40 50 52 49 4E 54 00 52 41 4E 4B 49 4E 47 40 40
        TEXT_TERMINATOR                                        ;#4408: FF

SUBMENU_END:
        ; In-game menu option 5: END — return to the game
        call    RESTORE_GAME_DISPLAY                           ;#4409: CD 68 62
        xor     a                                              ;#440C: AF
        ld      (GAME_STATE),a                                 ;#440D: 32 35 D1
        ld      (IN_GAME_MENU_PARAM),a                         ;#4410: 32 36 D1
        ld      a,6                                            ;#4413: 3E 06
        ; SNSMAT row 6 → AND 3 keeps bits 0,1 (SHIFT/CTRL).
        ; Boot-time override: if either modifier is held the routine returns
        ; early, clears GAME_CART_VALID_FLAG, and jumps to RESET_FOR_GAME_MODE
        ; (skip the game-cart launch path).
        call    BIOS_SNSMAT                                    ;#4415: CD 41 01
        and     3                                              ;#4418: E6 03
        ret     nz                                             ;#441A: C0
        ld      (GAME_CART_VALID_FLAG),a                       ;#441B: 32 3C D1
        jp      RESET_FOR_GAME_MODE                            ;#441E: C3 13 4F

DRAW_IN_GAME_MENU:
        ; Render the in-game menu title and 6 items to VRAM via DRAW_TEXT_STREAM
        call    CLEAR_NAME_BOTTOM                              ;#4421: CD CE 62
        ld      hl,IN_GAME_MENU_TEXT                           ;#4424: 21 56 44
        call    DRAW_TEXT_STREAM                               ;#4427: CD 13 61
DRAW_RC_CATALOG_CODE:
        ; Draw the "RC 7XX" Konami catalog code (TXT_RC_PREFIX + 2 hex digits of D301)
        ld      hl,(SUBMENU_HEADING_VRAM_BASE)                 ;#442A: 2A 6C D1
        ld      bc,0A0h                                        ;#442D: 01 A0 00
        add     hl,bc                                          ;#4430: 09
        ex      de,hl                                          ;#4431: EB
DRAW_RC_CATALOG_CODE_AT_DE:
        ; Alternate entry: caller pre-sets VRAM target in DE (ENTER_MODIFY uses DE=384Dh)
        ld      a,(GAME_ID)                                    ;#4432: 3A 01 D3
        inc     a                                              ;#4435: 3C
        ret     z                                              ;#4436: C8
        ld      hl,TXT_RC_PREFIX                               ;#4437: 21 B2 44
        push    de                                             ;#443A: D5
        call    DRAW_TEXT_STREAM_AT_DE                         ;#443B: CD 0F 61
        ld      a,(GAME_ID)                                    ;#443E: 3A 01 D3
        ld      hl,SCRATCH_HEX_OUTPUT                          ;#4441: 21 00 DA
        call    WRITE_BYTE_AS_ASCII_HEX                        ;#4444: CD 5D 67
        pop     hl                                             ;#4447: E1
        ld      bc,4                                           ;#4448: 01 04 00
        add     hl,bc                                          ;#444B: 09
        ld      de,SCRATCH_HEX_OUTPUT                          ;#444C: 11 00 DA
        ex      de,hl                                          ;#444F: EB
        ld      bc,2                                           ;#4450: 01 02 00
        jp      BIOS_LDIRVM                                    ;#4453: C3 5C 00

IN_GAME_MENU_TEXT:
        ; Encoded text stream: title + 6 options (DISK/TAPE SAVE/LOAD, RANKING, END)
        ; Encoded text-stream format consumed by DRAW_TEXT_STREAM:
        ; a 2-byte VRAM target word, then bytes that are written to VRAM
        ; one per cell. Two control bytes interrupt the run: FFh ends the
        ; stream, FEh restarts it (the next 2 bytes are read as a new
        ; VRAM target word). Used by every menu / submenu / title text
        ; block in the cart.
        NAME_TABLE 17, 1                                       ;#4456: 21 3A
        db      "@@MENU@@"                                     ;#4458: 40 40 4D 45 4E 55 40 40
        TEXT_SEPARATOR                                         ;#4460: FE
        NAME_TABLE 17, 12                                      ;#4461: 2C 3A
        db      "DISK", 0, "SAVE"                              ;#4463: 44 49 53 4B 00 53 41 56 45
        TEXT_SEPARATOR                                         ;#446C: FE
        NAME_TABLE 18, 12                                      ;#446D: 4C 3A
        db      "DISK", 0, "LOAD"                              ;#446F: 44 49 53 4B 00 4C 4F 41 44
        TEXT_SEPARATOR                                         ;#4478: FE
        NAME_TABLE 19, 12                                      ;#4479: 6C 3A
        db      "TAPE", 0, "SAVE"                              ;#447B: 54 41 50 45 00 53 41 56 45
        TEXT_SEPARATOR                                         ;#4484: FE
        NAME_TABLE 20, 12                                      ;#4485: 8C 3A
        db      "TAPE", 0, "LOAD"                              ;#4487: 54 41 50 45 00 4C 4F 41 44
        TEXT_SEPARATOR                                         ;#4490: FE
        NAME_TABLE 21, 12                                      ;#4491: AC 3A
        db      "RANKING", 0, "MODE"                           ;#4493: 52 41 4E 4B 49 4E 47 00 4D 4F 44 45
        TEXT_SEPARATOR                                         ;#449F: FE
        NAME_TABLE 22, 12                                      ;#44A0: CC 3A
        db      "END"                                          ;#44A2: 45 4E 44
        TEXT_TERMINATOR                                        ;#44A5: FF

IN_GAME_MENU_ITEMS:
        ; 6-entry word-pointer table fed to MENU_SELECT for the in-game menu
        NAME_TABLE 17, 11                                      ;#44A6: 2B 3A
        NAME_TABLE 18, 11                                      ;#44A8: 4B 3A
        NAME_TABLE 19, 11                                      ;#44AA: 6B 3A
        NAME_TABLE 20, 11                                      ;#44AC: 8B 3A
        NAME_TABLE 21, 11                                      ;#44AE: AB 3A
        NAME_TABLE 22, 11                                      ;#44B0: CB 3A

TXT_RC_PREFIX:
        ; 4-byte "RC 7" prefix + FFh terminator; D301 hex appended by DRAW_RC_CATALOG_CODE
        db      "RC@7"                                         ;#44B2: 52 43 40 37
        TEXT_TERMINATOR                                        ;#44B6: FF

DRAW_SUBMENU_DISK_SAVE:
        ; Render the DISK SAVE submenu text and reset menu state via DRAW_RC_CATALOG_CODE
        call    CLEAR_NAME_BOTTOM                              ;#44B7: CD CE 62
        ld      hl,SUBMENU_DISK_SAVE_TEXT                      ;#44BA: 21 CF 44
        call    DRAW_TEXT_STREAM                               ;#44BD: CD 13 61
        jp      DRAW_RC_CATALOG_CODE                           ;#44C0: C3 2A 44

DRAW_SUBMENU_DISK_LOAD:
        ; Render the DISK LOAD submenu text and reset menu state via DRAW_RC_CATALOG_CODE
        call    CLEAR_NAME_BOTTOM                              ;#44C3: CD CE 62
        ld      hl,SUBMENU_DISK_LOAD_TEXT                      ;#44C6: 21 13 45
        call    DRAW_TEXT_STREAM                               ;#44C9: CD 13 61
        jp      DRAW_RC_CATALOG_CODE                           ;#44CC: C3 2A 44

SUBMENU_DISK_SAVE_TEXT:
        ; Encoded text stream for the DISK SAVE submenu (5 items)
        NAME_TABLE 17, 12                                      ;#44CF: 2C 3A
        db      "HI", 0, "SCORE"                               ;#44D1: 48 49 00 53 43 4F 52 45
        TEXT_SEPARATOR                                         ;#44D9: FE
        NAME_TABLE 18, 12                                      ;#44DA: 4C 3A
        db      "SCREEN", 0, "DATA"                            ;#44DC: 53 43 52 45 45 4E 00 44 41 54 41
        TEXT_SEPARATOR                                         ;#44E7: FE
        NAME_TABLE 19, 12                                      ;#44E8: 6C 3A
        db      "GAME", 0, "DATA"                              ;#44EA: 47 41 4D 45 00 44 41 54 41
        TEXT_SEPARATOR                                         ;#44F3: FE
        NAME_TABLE 20, 12                                      ;#44F4: 8C 3A
        db      "RANKING", 0, "DATA"                           ;#44F6: 52 41 4E 4B 49 4E 47 00 44 41 54 41
        TEXT_SEPARATOR                                         ;#4502: FE
        NAME_TABLE 22, 12                                      ;#4503: CC 3A
        db      "END"                                          ;#4505: 45 4E 44
        TEXT_TERMINATOR                                        ;#4508: FF

SUBMENU_DISK_SAVE_POSITIONS:
        ; 5 VRAM-row addresses for the DISK SAVE submenu cursor
        NAME_TABLE 17, 11                                      ;#4509: 2B 3A
        NAME_TABLE 18, 11                                      ;#450B: 4B 3A
        NAME_TABLE 19, 11                                      ;#450D: 6B 3A
        NAME_TABLE 20, 11                                      ;#450F: 8B 3A
        NAME_TABLE 22, 11                                      ;#4511: CB 3A

SUBMENU_DISK_LOAD_TEXT:
        ; Encoded text stream for the DISK LOAD submenu (4 items)
        NAME_TABLE 17, 12                                      ;#4513: 2C 3A
        db      "HI", 0, "SCORE"                               ;#4515: 48 49 00 53 43 4F 52 45
        TEXT_SEPARATOR                                         ;#451D: FE
        NAME_TABLE 18, 12                                      ;#451E: 4C 3A
        db      "GAME", 0, "DATA"                              ;#4520: 47 41 4D 45 00 44 41 54 41
        TEXT_SEPARATOR                                         ;#4529: FE
        NAME_TABLE 19, 12                                      ;#452A: 6C 3A
        db      "RANKING", 0, "DATA"                           ;#452C: 52 41 4E 4B 49 4E 47 00 44 41 54 41
        TEXT_SEPARATOR                                         ;#4538: FE
        NAME_TABLE 21, 12                                      ;#4539: AC 3A
        db      "END"                                          ;#453B: 45 4E 44
        TEXT_TERMINATOR                                        ;#453E: FF

SUBMENU_DISK_LOAD_POSITIONS:
        ; 4 VRAM-row addresses for the DISK LOAD submenu cursor
        NAME_TABLE 17, 11                                      ;#453F: 2B 3A
        NAME_TABLE 18, 11                                      ;#4541: 4B 3A
        NAME_TABLE 19, 11                                      ;#4543: 6B 3A
        NAME_TABLE 21, 11                                      ;#4545: AB 3A

DRAW_SUBMENU_HEADING:
        ; Draw the section title (DISK SAVE / TAPE LOAD / etc.) at the top of the submenu
        ld      hl,SUBMENU_HEADING_TABLE                       ;#4547: 21 59 45
        ld      a,(IN_GAME_MENU_PARAM)                         ;#454A: 3A 36 D1
        and     0F0h                                           ;#454D: E6 F0
        rrca                                                   ;#454F: 0F
        rrca                                                   ;#4550: 0F
        rrca                                                   ;#4551: 0F
        rrca                                                   ;#4552: 0F
        dec     a                                              ;#4553: 3D
        ld      bc,0                                           ;#4554: 01 00 00
        jr      DRAW_TEXT_FROM_TABLE_AT_OFFSET                 ;#4557: 18 54

SUBMENU_HEADING_TABLE:
        ; 7-entry word pointer table indexed by (IN_GAME_MENU_PARAM >> 4) - 1
        dw      TXT_DISK_SAVE                                  ;#4559: 67 45
        dw      TXT_DISK_LOAD                                  ;#455B: 71 45
        dw      TXT_TAPE_SAVE                                  ;#455D: 7B 45
        dw      TXT_TAPE_LOAD                                  ;#455F: 85 45
        dw      0                                              ;#4561: 00 00
        dw      TXT_RANKING                                    ;#4563: 8F 45
        dw      TXT_PRINTER                                    ;#4565: 97 45

TXT_DISK_SAVE:
        ; "DISK SAVE" submenu heading
        db      "DISK@SAVE"                                    ;#4567: 44 49 53 4B 40 53 41 56 45
        TEXT_TERMINATOR                                        ;#4570: FF

TXT_DISK_LOAD:
        ; "DISK LOAD" submenu heading
        db      "DISK@LOAD"                                    ;#4571: 44 49 53 4B 40 4C 4F 41 44
        TEXT_TERMINATOR                                        ;#457A: FF

TXT_TAPE_SAVE:
        ; "TAPE SAVE" submenu heading
        db      "TAPE@SAVE"                                    ;#457B: 54 41 50 45 40 53 41 56 45
        TEXT_TERMINATOR                                        ;#4584: FF

TXT_TAPE_LOAD:
        ; "TAPE LOAD" submenu heading
        db      "TAPE@LOAD"                                    ;#4585: 54 41 50 45 40 4C 4F 41 44
        TEXT_TERMINATOR                                        ;#458E: FF

TXT_RANKING:
        ; "RANKING" submenu heading
        db      "RANKING"                                      ;#458F: 52 41 4E 4B 49 4E 47
        TEXT_TERMINATOR                                        ;#4596: FF

TXT_PRINTER:
        ; "PRINTER" submenu heading
        db      "PRINTER"                                      ;#4597: 50 52 49 4E 54 45 52
        TEXT_TERMINATOR                                        ;#459E: FF

DRAW_SUBMENU_SUBHEADING:
        ; Draw the item-kind subtitle (GAME / SCREEN / HI SCORE / RANKING)
        call    CLEAR_MENU_DISPLAY_AREA                        ;#459F: CD DD 61
        ld      a,(IN_GAME_MENU_PARAM)                         ;#45A2: 3A 36 D1
        and     0Fh                                            ;#45A5: E6 0F
        ld      hl,SUBMENU_SUBHEADING_TABLE                    ;#45A7: 21 BE 45
        ld      bc,40h                                         ;#45AA: 01 40 00
DRAW_TEXT_FROM_TABLE_AT_OFFSET:
        ; Common tail: deref table[A*2] and jp DRAW_TEXT_STREAM_AT_DE at D16C+BC
        ex      de,hl                                          ;#45AD: EB
        ld      hl,(SUBMENU_HEADING_VRAM_BASE)                 ;#45AE: 2A 6C D1
        add     hl,bc                                          ;#45B1: 09
        ex      de,hl                                          ;#45B2: EB
        add     a,a                                            ;#45B3: 87
        call    ADD_A_TO_HL                                    ;#45B4: CD ED 60
        ld      a,(hl)                                         ;#45B7: 7E
        inc     hl                                             ;#45B8: 23
        ld      h,(hl)                                         ;#45B9: 66
        ld      l,a                                            ;#45BA: 6F
        jp      DRAW_TEXT_STREAM_AT_DE                         ;#45BB: C3 0F 61

SUBMENU_SUBHEADING_TABLE:
        ; 4-entry word pointer table indexed by (IN_GAME_MENU_PARAM & 0Fh)
        dw      TXT_HI_SCORE                                   ;#45BE: D2 45
        dw      TXT_SCREEN                                     ;#45C0: CB 45
        dw      TXT_GAME                                       ;#45C2: C6 45
        dw      TXT_RANKING_DATA                               ;#45C4: DB 45

TXT_GAME:
        ; "GAME" subheading
        db      "GAME"                                         ;#45C6: 47 41 4D 45
        TEXT_TERMINATOR                                        ;#45CA: FF

TXT_SCREEN:
        ; "SCREEN" subheading
        db      "SCREEN"                                       ;#45CB: 53 43 52 45 45 4E
        TEXT_TERMINATOR                                        ;#45D1: FF

TXT_HI_SCORE:
        ; "HI SCORE" subheading
        db      "HI", 0, "SCORE"                               ;#45D2: 48 49 00 53 43 4F 52 45
        TEXT_TERMINATOR                                        ;#45DA: FF

TXT_RANKING_DATA:
        ; "RANKING" subheading (full word, distinct from TXT_RANKING heading)
        db      "RANKING"                                      ;#45DB: 52 41 4E 4B 49 4E 47
        TEXT_TERMINATOR                                        ;#45E2: FF

DRAW_SEARCH_FILE_PROMPT:
        ; Render TXT_SEARCH_FILE_2 at the current menu cursor row SUBMENU_BODY_VRAM_BASE
        ld      de,(SUBMENU_BODY_VRAM_BASE)                    ;#45E3: ED 5B 6E D1
        ld      hl,TXT_SEARCH_FILE_2                           ;#45E7: 21 ED 45
        jp      DRAW_TEXT_STREAM_AT_DE                         ;#45EA: C3 0F 61

TXT_SEARCH_FILE_2:
        ; 12-byte "SEARCH FILE" prompt (mirror of TXT_SEARCH_FILE in the tape module)
        db      "SEARCH", 0, "FILE"                            ;#45ED: 53 45 41 52 43 48 00 46 49 4C 45
        TEXT_TERMINATOR                                        ;#45F8: FF

DRAW_SUBMENU_RANKING:
        ; Render SUBMENU_RANKING_TEXT and reset menu state via DRAW_RC_CATALOG_CODE
        call    CLEAR_NAME_BOTTOM                              ;#45F9: CD CE 62
        ld      hl,SUBMENU_RANKING_TEXT                        ;#45FC: 21 05 46
        call    DRAW_TEXT_STREAM                               ;#45FF: CD 13 61
        jp      DRAW_RC_CATALOG_CODE                           ;#4602: C3 2A 44

SUBMENU_RANKING_TEXT:
        ; Encoded text stream for the RANKING submenu (4 items)
        NAME_TABLE 17, 12                                      ;#4605: 2C 3A
        db      "DISPLAY", 0, "DATA"                           ;#4607: 44 49 53 50 4C 41 59 00 44 41 54 41
        TEXT_SEPARATOR                                         ;#4613: FE
        NAME_TABLE 18, 12                                      ;#4614: 4C 3A
        db      "CHANGE", 0, "NAME"                            ;#4616: 43 48 41 4E 47 45 00 4E 41 4D 45
        TEXT_SEPARATOR                                         ;#4621: FE
        NAME_TABLE 19, 12                                      ;#4622: 6C 3A
        db      "PRINT", 0, "DATA"                             ;#4624: 50 52 49 4E 54 00 44 41 54 41
        TEXT_SEPARATOR                                         ;#462E: FE
        NAME_TABLE 22, 12                                      ;#462F: CC 3A
        db      "END"                                          ;#4631: 45 4E 44
        TEXT_TERMINATOR                                        ;#4634: FF

SUBMENU_RANKING_POSITIONS:
        ; 4 VRAM-row addresses for the RANKING submenu cursor
        NAME_TABLE 17, 11                                      ;#4635: 2B 3A
        NAME_TABLE 18, 11                                      ;#4637: 4B 3A
        NAME_TABLE 19, 11                                      ;#4639: 6B 3A
        NAME_TABLE 22, 11                                      ;#463B: CB 3A

ENTER_SELF:
        ; SELF screen: stash GAME_ID, run common setup, render SELF_SCREEN_TEXT
        ld      hl,GAME_ID                                     ;#463D: 21 01 D3
        ld      a,(hl)                                         ;#4640: 7E
        ld      (hl),0FFh                                      ;#4641: 36 FF
        ld      (SAVED_GAME_ID),a                              ;#4643: 32 41 D1
SELF_MENU_RESHOW:
        ; Re-entry into SELF menu (skips D301 stash): redraw screen, MENU_SELECT, dispatch
        call    SETUP_MODIFY_DEFAULTS                          ;#4646: CD 89 46
        call    DRAW_TOP_BOTTOM_BORDERS                        ;#4649: CD AF 4F
        call    CLEAR_MIDDLE_NAME_AREA                         ;#464C: CD 4D 4B
        ld      hl,SELF_SCREEN_TEXT                            ;#464F: 21 CE 47
        call    DRAW_TEXT_STREAM                               ;#4652: CD 13 61
        ld      hl,SELF_MENU_POSITIONS                         ;#4655: 21 11 48
        ld      b,3                                            ;#4658: 06 03
        call    MENU_SELECT                                    ;#465A: CD 00 64
        call    CALL_INDIRECT_A                                ;#465D: CD E7 61
SELF_MENU_HANDLERS:
        ; 3-entry inline word-pointer table dispatched after SELF pick
        dw      SELF_COLOR_TEST_HANDLER                        ;#4660: 7A 46
        dw      DRAW_SELF_OPTION_1_SCREEN                      ;#4662: 96 46
        dw      SELF_EXIT_TO_MAIN                              ;#4664: 66 46

SELF_EXIT_TO_MAIN:
        ; Cancel option: restore D129/D301 and jp MAIN_ENTRY
        ld      hl,MODIFY_FLAGS                                ;#4666: 21 17 D3
        ld      a,(hl)                                         ;#4669: 7E
        or      a                                              ;#466A: B7
        jr      nz,SELF_EXIT_RESTORE_GAME_ID                   ;#466B: 20 03
        ld      (TOP_MENU_MODE),a                              ;#466D: 32 29 D1
SELF_EXIT_RESTORE_GAME_ID:
        ; Merge point in SELF_EXIT_TO_MAIN: restore D301 from D141 and jp MAIN_ENTRY
        ld      hl,GAME_ID                                     ;#4670: 21 01 D3
        ld      a,(SAVED_GAME_ID)                              ;#4673: 3A 41 D1
        ld      (hl),a                                         ;#4676: 77
        jp      MAIN_ENTRY                                     ;#4677: C3 5E 4E

SELF_COLOR_TEST_HANDLER:
        ; SELF option 0 ("COLOR TEST PATTERN"): full-screen pattern + screen-mode submenu
        call    DRAW_FULL_SCREEN_PATTERN                       ;#467A: CD F4 4A
        call    DRAW_SELF_OPTION_0_SCREEN                      ;#467D: CD 54 47
SELF_LOAD_SCREEN_FINISH:
        ; Common tail: CLEAR_NAME_TABLE + INIT_TITLE_SCREEN, jp SELF_MENU_RESHOW
        call    CLEAR_NAME_TABLE                               ;#4680: CD 2A 61
        call    INIT_TITLE_SCREEN                              ;#4683: CD 4F 4F
        jp      SELF_MENU_RESHOW                               ;#4686: C3 46 46

SETUP_MODIFY_DEFAULTS:
        ; Set D16C=3921h, D16E=392Ch — the modify-screen default handlers
        LOAD_NAME_TABLE hl, 9, 1                               ;#4689: 21 21 39
        ld      (SUBMENU_HEADING_VRAM_BASE),hl                 ;#468C: 22 6C D1
        LOAD_NAME_TABLE hl, 9, 12                              ;#468F: 21 2C 39
        ld      (SUBMENU_BODY_VRAM_BASE),hl                    ;#4692: 22 6E D1
        ret                                                    ;#4695: C9

DRAW_SELF_OPTION_1_SCREEN:
        ; Render the SELF option 1 sub-screen ("LOAD SCREEN") and prep its 3-item submenu
        call    CLEAR_MIDDLE_NAME_AREA                         ;#4696: CD 4D 4B
        ld      hl,SELF_OPTION_1_TEXT                          ;#4699: 21 B0 46
        call    DRAW_TEXT_STREAM                               ;#469C: CD 13 61
        ld      hl,SELF_OPTION_1_POSITIONS                     ;#469F: 21 EA 46
        ld      b,3                                            ;#46A2: 06 03
        call    MENU_SELECT                                    ;#46A4: CD 00 64
        call    CALL_INDIRECT_A                                ;#46A7: CD E7 61
SELF_OPTION_1_HANDLERS:
        ; 3-entry inline word-pointer table dispatched after option 1 pick
        dw      LOAD_SCREEN_FROM_DISK                          ;#46AA: F0 46
        dw      LOAD_SCREEN_FROM_TAPE                          ;#46AC: 31 47
        dw      SELF_MENU_RESHOW                               ;#46AE: 46 46

SELF_OPTION_1_TEXT:
        ; Encoded text stream for the SELF option 1 ("LOAD SCREEN") sub-screen
        NAME_TABLE 6, 6                                        ;#46B0: C6 38
        db      "@@LOAD", 0, "SCREEN@@"                        ;#46B2: 40 40 4C 4F 41 44 00 53 43 52 45 45 4E 40 40
        TEXT_SEPARATOR                                         ;#46C1: FE
        NAME_TABLE 9, 7                                        ;#46C2: 27 39
        db      "LOAD", 0, "DISK", 0, "DATA"                   ;#46C4: 4C 4F 41 44 00 44 49 53 4B 00 44 41 54 41
        TEXT_SEPARATOR                                         ;#46D2: FE
        NAME_TABLE 11, 7                                       ;#46D3: 67 39
        db      "LOAD", 0, "TAPE", 0, "DATA"                   ;#46D5: 4C 4F 41 44 00 54 41 50 45 00 44 41 54 41
        TEXT_SEPARATOR                                         ;#46E3: FE
        NAME_TABLE 13, 7                                       ;#46E4: A7 39
        db      "END"                                          ;#46E6: 45 4E 44
        TEXT_TERMINATOR                                        ;#46E9: FF

SELF_OPTION_1_POSITIONS:
        ; 3 VRAM-row addresses for the SELF option 1 cursor
        NAME_TABLE 9, 6                                        ;#46EA: 26 39
        NAME_TABLE 11, 6                                       ;#46EC: 66 39
        NAME_TABLE 13, 6                                       ;#46EE: A6 39

LOAD_SCREEN_FROM_DISK:
        ; Disk variant: pick file, load screen-dump bytes, display them
        call    CHECK_DISK_BIOS_AVAILABLE                      ;#46F0: CD 7D 67
        jr      z,DRAW_SELF_OPTION_1_SCREEN                    ;#46F3: 28 A1
        ld      a,21h                                          ;#46F5: 3E 21
        ld      (IN_GAME_MENU_PARAM),a                         ;#46F7: 32 36 D1
        call    SETUP_RANKING_MODE_MENU                        ;#46FA: CD 30 4A
        call    ENTER_FILE_PICKER_AT_VRAM                      ;#46FD: CD 60 6A
        jp      c,SELF_MENU_RESHOW                             ;#4700: DA 46 46
        ld      hl,DISK_ERROR_RECOVER_AND_RETRY                ;#4703: 21 5C 69
        call    SETUP_INTERSLOT_CALL                           ;#4706: CD 29 69
        call    CLEAR_MIDDLE_NAME_AREA                         ;#4709: CD 4D 4B
        call    DISK_LOAD_SCREEN                               ;#470C: CD 62 65
        jp      c,SELF_MENU_RESHOW                             ;#470F: DA 46 46
        ld      a,0FFh                                         ;#4712: 3E FF
        ld      (GAME_DISPLAY_ACTIVE),a                        ;#4714: 32 3D D1
        call    DRAW_SELF_OPTION_0_SCREEN                      ;#4717: CD 54 47
        ld      a,6                                            ;#471A: 3E 06
        ; SNSMAT row 6 → AND 3 keeps bits 0,1 (SHIFT/CTRL).
        ; Same SHIFT/CTRL hold-to-skip check used by the SELF option-0 path
        ; after DRAW_SELF_OPTION_0_SCREEN — either modifier held bypasses the
        ; disk-save path and jumps to LOAD_SCREEN_FROM_DISK_FINISH.
        call    BIOS_SNSMAT                                    ;#471C: CD 41 01
        and     3                                              ;#471F: E6 03
        jp      nz,LOAD_SCREEN_FROM_DISK_FINISH                ;#4721: C2 2A 47
        call    SET_DEFAULT_HANDLERS                           ;#4724: CD D5 41
        call    DISK_SAVE_SCREEN                               ;#4727: CD CB 64
LOAD_SCREEN_FROM_DISK_FINISH:
        ; Clear GAME_DISPLAY_ACTIVE, jp SELF_LOAD_SCREEN_FINISH
        xor     a                                              ;#472A: AF
        ld      (GAME_DISPLAY_ACTIVE),a                        ;#472B: 32 3D D1
        jp      SELF_LOAD_SCREEN_FINISH                        ;#472E: C3 80 46

LOAD_SCREEN_FROM_TAPE:
        ; Tape variant: load a screen dump from cassette and display
        ld      a,41h                                          ;#4731: 3E 41
        ld      (IN_GAME_MENU_PARAM),a                         ;#4733: 32 36 D1
        call    CLEAR_MIDDLE_NAME_AREA                         ;#4736: CD 4D 4B
        call    DRAW_SUBMENU_HEADING                           ;#4739: CD 47 45
        call    DRAW_SUBMENU_SUBHEADING                        ;#473C: CD 9F 45
        call    TAPE_LOAD_SCREEN                               ;#473F: CD 7C 6D
        jp      c,SELF_MENU_RESHOW                             ;#4742: DA 46 46
        ld      a,0FFh                                         ;#4745: 3E FF
        ld      (GAME_DISPLAY_ACTIVE),a                        ;#4747: 32 3D D1
        call    DRAW_SELF_OPTION_0_SCREEN                      ;#474A: CD 54 47
        xor     a                                              ;#474D: AF
        ld      (GAME_DISPLAY_ACTIVE),a                        ;#474E: 32 3D D1
        jp      SELF_LOAD_SCREEN_FINISH                        ;#4751: C3 80 46

DRAW_SELF_OPTION_0_SCREEN:
        ; Render the SELF option 0 sub-screen text and prep its 3-item submenu
        call    SAVE_GAME_DISPLAY                              ;#4754: CD F3 61
        ld      hl,SELF_OPTION_0_TEXT                          ;#4757: 21 84 47
        call    DRAW_TEXT_STREAM                               ;#475A: CD 13 61
        ld      hl,SELF_OPTION_0_POSITIONS                     ;#475D: 21 C8 47
        ld      b,3                                            ;#4760: 06 03
        call    MENU_SELECT                                    ;#4762: CD 00 64
        call    CALL_INDIRECT_A                                ;#4765: CD E7 61
SELF_OPTION_0_HANDLERS:
        ; 3-entry inline word-pointer table dispatched after SELF option 0 pick
        dw      SELF_OPT0_HANDLER_DISPLAY                      ;#4768: 6E 47
        dw      SELF_OPT0_HANDLER_PRINT                        ;#476A: 79 47
        dw      SELF_OPT0_HANDLER_END                          ;#476C: 81 47

SELF_OPT0_HANDLER_DISPLAY:
        ; Option 0 "DISPLAY ALL SCREEN": RESTORE_GAME_DISPLAY + wait key + redraw screen
        call    RESTORE_GAME_DISPLAY                           ;#476E: CD 68 62
        call    BIOS_KILBUF                                    ;#4771: CD 56 01
        call    BIOS_CHGET                                     ;#4774: CD 9F 00
        jr      DRAW_SELF_OPTION_0_SCREEN                      ;#4777: 18 DB

SELF_OPT0_HANDLER_PRINT:
        ; Option 1 "PRINT SCREEN": RESTORE_GAME_DISPLAY + ENTER_PRINTER_MENU + redraw
        call    RESTORE_GAME_DISPLAY                           ;#4779: CD 68 62
        call    ENTER_PRINTER_MENU                             ;#477C: CD 8D 70
        jr      DRAW_SELF_OPTION_0_SCREEN                      ;#477F: 18 D3

SELF_OPT0_HANDLER_END:
        ; Option 2 "END": jp RESTORE_GAME_DISPLAY (return to SELF menu)
        jp      RESTORE_GAME_DISPLAY                           ;#4781: C3 68 62

SELF_OPTION_0_TEXT:
        ; Encoded text stream for the SELF option 0 sub-screen
        NAME_TABLE 17, 6                                       ;#4784: 26 3A
        db      "@@SCREEN", 0, "DISPLAY", 0, "MODE@@"          ;#4786: 40 40 53 43 52 45 45 4E 00 44 49 53 50 4C 41 59 00 4D 4F 44 45 40 40
        TEXT_SEPARATOR                                         ;#479D: FE
        NAME_TABLE 19, 7                                       ;#479E: 67 3A
        db      "DISPLAY", 0, "ALL", 0, "SCREEN"               ;#47A0: 44 49 53 50 4C 41 59 00 41 4C 4C 00 53 43 52 45 45 4E
        TEXT_SEPARATOR                                         ;#47B2: FE
        NAME_TABLE 20, 7                                       ;#47B3: 87 3A
        db      "PRINT", 0, "SCREEN"                           ;#47B5: 50 52 49 4E 54 00 53 43 52 45 45 4E
        TEXT_SEPARATOR                                         ;#47C1: FE
        NAME_TABLE 21, 7                                       ;#47C2: A7 3A
        db      "END"                                          ;#47C4: 45 4E 44
        TEXT_TERMINATOR                                        ;#47C7: FF

SELF_OPTION_0_POSITIONS:
        ; 3 VRAM-row addresses for the SELF option 0 cursor
        NAME_TABLE 19, 6                                       ;#47C8: 66 3A
        NAME_TABLE 20, 6                                       ;#47CA: 86 3A
        NAME_TABLE 21, 6                                       ;#47CC: A6 3A

SELF_SCREEN_TEXT:
        ; Encoded text stream for the SELF screen header & 3 menu items
        NAME_TABLE 6, 6                                        ;#47CE: C6 38
        db      "@@SELF", 0, "MODE", 0, "MENU@@"               ;#47D0: 40 40 53 45 4C 46 00 4D 4F 44 45 00 4D 45 4E 55 40 40
        TEXT_SEPARATOR                                         ;#47E2: FE
        NAME_TABLE 9, 7                                        ;#47E3: 27 39
        db      "COLOR", 0, "TEST", 0, "PATTERN"               ;#47E5: 43 4F 4C 4F 52 00 54 45 53 54 00 50 41 54 54 45 52 4E
        TEXT_SEPARATOR                                         ;#47F7: FE
        NAME_TABLE 11, 7                                       ;#47F8: 67 39
        db      "LOAD", 0, "SCREEN", 0, "DATA"                 ;#47FA: 4C 4F 41 44 00 53 43 52 45 45 4E 00 44 41 54 41
        TEXT_SEPARATOR                                         ;#480A: FE
        NAME_TABLE 13, 7                                       ;#480B: A7 39
        db      "END"                                          ;#480D: 45 4E 44
        TEXT_TERMINATOR                                        ;#4810: FF

SELF_MENU_POSITIONS:
        ; 3 VRAM-row addresses for the SELF menu cursor
        NAME_TABLE 9, 6                                        ;#4811: 26 39
        NAME_TABLE 11, 6                                       ;#4813: 66 39
        NAME_TABLE 13, 6                                       ;#4815: A6 39

ENTER_MODIFY:
        ; MODIFY screen entry: run common setup, render modify data at MODIFY_SCREEN_TEXT
        call    SETUP_MODIFY_DEFAULTS                          ;#4817: CD 89 46
        call    DRAW_TOP_BOTTOM_BORDERS                        ;#481A: CD AF 4F
        call    CLEAR_MIDDLE_NAME_AREA                         ;#481D: CD 4D 4B
        ld      hl,MODIFY_SCREEN_TEXT                          ;#4820: 21 6E 4A
        call    DRAW_TEXT_STREAM                               ;#4823: CD 13 61
        LOAD_NAME_TABLE de, 2, 13                              ;#4826: 11 4D 38
        call    DRAW_RC_CATALOG_CODE_AT_DE                     ;#4829: CD 32 44
        ld      hl,MODIFY_MENU_POSITIONS                       ;#482C: 21 E3 4A
        ld      b,5                                            ;#482F: 06 05
        call    MENU_SELECT                                    ;#4831: CD 00 64
        call    CALL_INDIRECT_A                                ;#4834: CD E7 61
MODIFY_MENU_HANDLERS:
        ; 5-entry inline word-pointer table dispatched after MODIFY pick
        dw      MODIFY_OPTION_STAGE                            ;#4837: 46 48
        dw      MODIFY_OPTION_LIVES                            ;#4839: BB 48
        dw      MODIFY_OPTION_RANKING                          ;#483B: 2C 49
        dw      MODIFY_OPTION_PATTERN                          ;#483D: 5B 4A
        dw      MODIFY_OPTION_START_GAME                       ;#483F: 6A 4A

CHECK_GAME_ID_VALID:
        ; Helper: load GAME_ID and inc; sets Z when D301 == FFh (no value loaded)
        ld      a,(GAME_ID)                                    ;#4841: 3A 01 D3
        inc     a                                              ;#4844: 3C
        ret                                                    ;#4845: C9

MODIFY_OPTION_STAGE:
        ; MODIFY option 0 ("STAGE NUMBER"): write input value to GAME_RAM_STAGE_PTR
        call    CHECK_GAME_ID_VALID                            ;#4846: CD 41 48
        jr      z,ENTER_MODIFY                                 ;#4849: 28 CC
        ld      a,(GAME_STAGE_CHEAT_FLAG)                      ;#484B: 3A 02 D3
        inc     a                                              ;#484E: 3C
        jr      nz,MODIFY_STAGE_PER_GAME_DISPATCH              ;#484F: 20 09
        ld      hl,(GAME_RAM_STAGE_PTR)                        ;#4851: 2A 0A D3
        ld      a,h                                            ;#4854: 7C
        or      l                                              ;#4855: B5
        jr      z,ENTER_MODIFY                                 ;#4856: 28 BF
        jr      MODIFY_STAGE_DEFAULT_PROMPT                    ;#4858: 18 08

MODIFY_STAGE_PER_GAME_DISPATCH:
        ; Try STAGE_CHEAT_DISPATCH_TABLE; on miss fall into MODIFY_STAGE_DEFAULT_PROMPT
        ld      hl,STAGE_CHEAT_DISPATCH_TABLE                  ;#485A: 21 81 59
        call    DISPATCH_BY_GAME_ID_Z                          ;#485D: CD 01 54
        jr      nz,ENTER_MODIFY                                ;#4860: 20 B5
MODIFY_STAGE_DEFAULT_PROMPT:
        ; Default STAGE handler when no per-game cheat: prompt, 2-digit input, store
        call    CLEAR_MIDDLE_NAME_AREA                         ;#4862: CD 4D 4B
        ld      hl,TXT_MODIFY_STAGE_SCREEN                     ;#4865: 21 91 48
        call    DRAW_TEXT_STREAM                               ;#4868: CD 13 61
        LOAD_NAME_TABLE hl, 11, 20                             ;#486B: 21 74 39
        call    RUN_2DIGIT_NUM_INPUT                           ;#486E: CD ED 4A
        jp      z,MODIFY_MENU_REDRAW                           ;#4871: CA 61 4A
        ld      hl,CHEAT_STAGE_DECIMAL                         ;#4874: 21 1A D3
        call    STORE_INPUT_AS_DECIMAL                         ;#4877: CD 57 4B
        ld      hl,CHEAT_STAGE_HEX                             ;#487A: 21 1B D3
        call    STORE_INPUT_AS_HEX_BYTE                        ;#487D: CD 7E 4B
        ld      hl,(GAME_CHEAT_CALLBACK_PTR)                   ;#4880: 2A 14 D3
        ld      a,h                                            ;#4883: 7C
        or      l                                              ;#4884: B5
        ld      hl,MODIFY_FLAGS                                ;#4885: 21 17 D3
        jr      z,MODIFY_STAGE_SET_FLAGS                       ;#4888: 28 02
        set     2,(hl)                                         ;#488A: CB D6
MODIFY_STAGE_SET_FLAGS:
        ; Set MODIFY_FLAGS bits 1+2 (stage written), jp MODIFY_MENU_REDRAW
        set     1,(hl)                                         ;#488C: CB CE
        jp      MODIFY_MENU_REDRAW                             ;#488E: C3 61 4A

TXT_MODIFY_STAGE_SCREEN:
        ; Encoded text stream for the MODIFY STAGE screen (NUMBER / STAGE / END)
        NAME_TABLE 6, 6                                        ;#4891: C6 38
        db      "@@MODIFY", 0, "STAGE", 0, "NUMBER@@"          ;#4893: 40 40 4D 4F 44 49 46 59 00 53 54 41 47 45 00 4E 55 4D 42 45 52 40 40
        TEXT_SEPARATOR                                         ;#48AA: FE
        NAME_TABLE 11, 7                                       ;#48AB: 67 39
        db      "STAGE", 0, "NUMBER>"                          ;#48AD: 53 54 41 47 45 00 4E 55 4D 42 45 52 3E
        TEXT_TERMINATOR                                        ;#48BA: FF

MODIFY_OPTION_LIVES:
        ; MODIFY option 1 ("PLAYER NUMBER"): write input value to GAME_RAM_LIVES_PTR
        call    CHECK_GAME_ID_VALID                            ;#48BB: CD 41 48
        jp      z,ENTER_MODIFY                                 ;#48BE: CA 17 48
        ld      a,(GAME_STAGE_CHEAT_FLAG)                      ;#48C1: 3A 02 D3
        inc     a                                              ;#48C4: 3C
        jr      nz,MODIFY_LIVES_PER_GAME_DISPATCH              ;#48C5: 20 0A
        ld      hl,(GAME_RAM_LIVES_PTR)                        ;#48C7: 2A 08 D3
        ld      a,h                                            ;#48CA: 7C
        or      l                                              ;#48CB: B5
        jp      z,ENTER_MODIFY                                 ;#48CC: CA 17 48
        jr      MODIFY_LIVES_DEFAULT_PROMPT                    ;#48CF: 18 09

MODIFY_LIVES_PER_GAME_DISPATCH:
        ; Try LIVES_CHEAT_DISPATCH_TABLE; on miss fall into MODIFY_LIVES_DEFAULT_PROMPT
        ld      hl,LIVES_CHEAT_DISPATCH_TABLE                  ;#48D1: 21 50 59
        call    DISPATCH_BY_GAME_ID_Z                          ;#48D4: CD 01 54
        jp      nz,ENTER_MODIFY                                ;#48D7: C2 17 48
MODIFY_LIVES_DEFAULT_PROMPT:
        ; Default LIVES handler when no per-game cheat: prompt, 2-digit input, store
        call    CLEAR_MIDDLE_NAME_AREA                         ;#48DA: CD 4D 4B
        ld      hl,TXT_MODIFY_LIVES_SCREEN                     ;#48DD: 21 00 49
        call    DRAW_TEXT_STREAM                               ;#48E0: CD 13 61
        LOAD_NAME_TABLE hl, 11, 21                             ;#48E3: 21 75 39
        call    RUN_2DIGIT_NUM_INPUT                           ;#48E6: CD ED 4A
        jp      z,MODIFY_MENU_REDRAW                           ;#48E9: CA 61 4A
        ld      hl,CHEAT_LIVES_DECIMAL                         ;#48EC: 21 18 D3
        call    STORE_INPUT_AS_DECIMAL                         ;#48EF: CD 57 4B
        ld      hl,CHEAT_LIVES_HEX                             ;#48F2: 21 19 D3
        call    STORE_INPUT_AS_HEX_BYTE                        ;#48F5: CD 7E 4B
        ld      hl,MODIFY_FLAGS                                ;#48F8: 21 17 D3
        set     0,(hl)                                         ;#48FB: CB C6
        jp      MODIFY_MENU_REDRAW                             ;#48FD: C3 61 4A

TXT_MODIFY_LIVES_SCREEN:
        ; Encoded text stream for the MODIFY LIVES screen (NUMBER / PLAYER / END)
        NAME_TABLE 6, 6                                        ;#4900: C6 38
        db      "@@MODIFY", 0, "PLAYER", 0, "NUMBER@@"         ;#4902: 40 40 4D 4F 44 49 46 59 00 50 4C 41 59 45 52 00 4E 55 4D 42 45 52 40 40
        TEXT_SEPARATOR                                         ;#491A: FE
        NAME_TABLE 11, 7                                       ;#491B: 67 39
        db      "PLAYER", 0, "NUMBER>"                         ;#491D: 50 4C 41 59 45 52 00 4E 55 4D 42 45 52 3E
        TEXT_TERMINATOR                                        ;#492B: FF

MODIFY_OPTION_RANKING:
        ; MODIFY option 2 ("RANKING MODE"): show sub-menu; needs GAME_RAM_SCORE_1P_PTR
        call    CHECK_GAME_ID_VALID                            ;#492C: CD 41 48
        jp      z,ENTER_MODIFY                                 ;#492F: CA 17 48
        ld      hl,(GAME_RAM_SCORE_1P_PTR)                     ;#4932: 2A 0E D3
        ld      a,h                                            ;#4935: 7C
        or      l                                              ;#4936: B5
        jp      z,ENTER_MODIFY                                 ;#4937: CA 17 48
RANKING_MODE_MENU_SHOW:
        ; Reached when GAME_RAM_SCORE_1P_PTR!=0: draw RANKING screen + 4-item menu
        call    CLEAR_MIDDLE_NAME_AREA                         ;#493A: CD 4D 4B
        ld      hl,TXT_RANKING_MODE_SCREEN                     ;#493D: 21 6A 49
        call    DRAW_TEXT_STREAM                               ;#4940: CD 13 61
RANKING_MODE_RUN_MENU:
        ; Skip-text entry: HL=positions, B=4 → MENU_SELECT + CALL_INDIRECT_A
        ld      hl,RANKING_MODE_POSITIONS                      ;#4943: 21 BA 49
        ld      b,4                                            ;#4946: 06 04
        call    MENU_SELECT                                    ;#4948: CD 00 64
        call    CALL_INDIRECT_A                                ;#494B: CD E7 61
RANKING_MODE_HANDLERS:
        ; 4-entry inline word-pointer table dispatched after RANKING MODE pick
        dw      SUBMENU_RANK_LOAD_DISK                         ;#494E: F3 49
        dw      SUBMENU_RANK_LOAD_TAPE                         ;#4950: 19 4A
        dw      RANKING_MODE_INIT_HANDLER                      ;#4952: 56 49
        dw      MODIFY_MENU_REDRAW                             ;#4954: 61 4A

RANKING_MODE_INIT_HANDLER:
        ; RANKING option 2: reset ranking table; set MODIFY_FLAGS bit 7; redraw
        call    RANKING_TABLE_RESET                            ;#4956: CD C2 49
RANKING_MODE_INIT_SET_FLAG:
        ; Set MODIFY_FLAGS bit 7 (ranking-init), jp MODIFY_MENU_REDRAW
        ld      hl,MODIFY_FLAGS                                ;#4959: 21 17 D3
        set     7,(hl)                                         ;#495C: CB FE
        jp      MODIFY_MENU_REDRAW                             ;#495E: C3 61 4A

TXT_KONAMI:
        ; "KONAMI" 6-byte string copied to ranking record at D478 by 49DCh
        db      "KONAMI"                                       ;#4961: 4B 4F 4E 41 4D 49

TXT_KONAMI_END:
RANK_INIT_DATA:
        ; 3-byte initial-score bytes (00 00 01) seeded at RANKING_SCORE_BLOCK
        dh      "000001"                                       ;#4967: 00 00 01

TXT_RANKING_MODE_SCREEN:
        ; Encoded text stream for the RANKING MODE submenu (4 items)
        NAME_TABLE 6, 6                                        ;#496A: C6 38
        db      "@@RANKING", 0, "MODE@@"                       ;#496C: 40 40 52 41 4E 4B 49 4E 47 00 4D 4F 44 45 40 40
        TEXT_SEPARATOR                                         ;#497C: FE
        NAME_TABLE 9, 7                                        ;#497D: 27 39
        db      "LOAD", 0, "DISK", 0, "DATA"                   ;#497F: 4C 4F 41 44 00 44 49 53 4B 00 44 41 54 41
        TEXT_SEPARATOR                                         ;#498D: FE
        NAME_TABLE 11, 7                                       ;#498E: 67 39
        db      "LOAD", 0, "TAPE", 0, "DATA"                   ;#4990: 4C 4F 41 44 00 54 41 50 45 00 44 41 54 41
        TEXT_SEPARATOR                                         ;#499E: FE
        NAME_TABLE 13, 7                                       ;#499F: A7 39
        db      "CLEAR", 0, "RANKING", 0, "DATA"               ;#49A1: 43 4C 45 41 52 00 52 41 4E 4B 49 4E 47 00 44 41 54 41
        TEXT_SEPARATOR                                         ;#49B3: FE
        NAME_TABLE 15, 7                                       ;#49B4: E7 39
        db      "END"                                          ;#49B6: 45 4E 44
        TEXT_TERMINATOR                                        ;#49B9: FF

RANKING_MODE_POSITIONS:
        ; 4 VRAM-row addresses for the RANKING MODE submenu cursor
        NAME_TABLE 9, 6                                        ;#49BA: 26 39
        NAME_TABLE 11, 6                                       ;#49BC: 66 39
        NAME_TABLE 13, 6                                       ;#49BE: A6 39
        NAME_TABLE 15, 6                                       ;#49C0: E6 39

RANKING_TABLE_RESET:
        ; Zero D459..D475 score block, fill D477..D4D0 with 3Ch, seed D478 with TXT_KONAMI
        ld      hl,RANKING_SCORE_BLOCK                         ;#49C2: 21 59 D4
        ld      de,RANKING_SCORE_BLOCK+1                       ;#49C5: 11 5A D4
        ld      (hl),0                                         ;#49C8: 36 00
        ld      bc,1Dh                                         ;#49CA: 01 1D 00
        ldir                                                   ;#49CD: ED B0
        ld      hl,RANKING_NAME_BLOCK                          ;#49CF: 21 77 D4
        ld      de,RANKING_NAME_BLOCK+1                        ;#49D2: 11 78 D4
        ld      (hl),3Ch                                       ;#49D5: 36 3C
        ld      bc,59h                                         ;#49D7: 01 59 00
        ldir                                                   ;#49DA: ED B0
        ld      de,RANKING_NAME_BLOCK+1                        ;#49DC: 11 78 D4
        ld      hl,TXT_KONAMI                                  ;#49DF: 21 61 49
        LD_BC_SIZE TXT_KONAMI                                  ;#49E2: 01 06 00
        ldir                                                   ;#49E5: ED B0
        ld      de,RANKING_SCORE_BLOCK                         ;#49E7: 11 59 D4
        ld      hl,RANK_INIT_DATA                              ;#49EA: 21 67 49
        ld      bc,3                                           ;#49ED: 01 03 00
        ldir                                                   ;#49F0: ED B0
        ret                                                    ;#49F2: C9

SUBMENU_RANK_LOAD_DISK:
        ; RANKING MODE > DISK: load ranking record via DISK_LOAD_RANKING
        call    CHECK_DISK_BIOS_AVAILABLE                      ;#49F3: CD 7D 67
        jp      z,RANKING_MODE_RUN_MENU                        ;#49F6: CA 43 49
        ld      a,23h                                          ;#49F9: 3E 23
        ld      (IN_GAME_MENU_PARAM),a                         ;#49FB: 32 36 D1
        call    SETUP_RANKING_MODE_MENU                        ;#49FE: CD 30 4A
        call    ENTER_FILE_PICKER_AT_VRAM                      ;#4A01: CD 60 6A
        jp      c,RANKING_MODE_MENU_SHOW                       ;#4A04: DA 3A 49
        ld      hl,DISK_ERROR_RECOVER_AND_RETRY                ;#4A07: 21 5C 69
        call    SETUP_INTERSLOT_CALL                           ;#4A0A: CD 29 69
        call    CLEAR_MIDDLE_NAME_AREA                         ;#4A0D: CD 4D 4B
        call    DISK_LOAD_RANKING                              ;#4A10: CD 7B 65
        jp      nc,RANKING_MODE_INIT_SET_FLAG                  ;#4A13: D2 59 49
        jp      RANKING_MODE_MENU_SHOW                         ;#4A16: C3 3A 49

SUBMENU_RANK_LOAD_TAPE:
        ; RANKING MODE > TAPE: load ranking record via TAPE_LOAD_RANKING
        ld      a,43h                                          ;#4A19: 3E 43
        ld      (IN_GAME_MENU_PARAM),a                         ;#4A1B: 32 36 D1
        call    CLEAR_MIDDLE_NAME_AREA                         ;#4A1E: CD 4D 4B
        call    DRAW_SUBMENU_HEADING                           ;#4A21: CD 47 45
        call    DRAW_SUBMENU_SUBHEADING                        ;#4A24: CD 9F 45
        call    TAPE_LOAD_RANKING                              ;#4A27: CD 90 6D
        jp      nc,RANKING_MODE_INIT_SET_FLAG                  ;#4A2A: D2 59 49
        jp      RANKING_MODE_MENU_SHOW                         ;#4A2D: C3 3A 49

SETUP_RANKING_MODE_MENU:
        ; Initialize the RANKING MODE submenu state (positions, max index, cursor)
        call    CLEAR_MIDDLE_NAME_AREA                         ;#4A30: CD 4D 4B
        call    SETUP_MODIFY_DEFAULTS                          ;#4A33: CD 89 46
        call    DRAW_SUBMENU_HEADING                           ;#4A36: CD 47 45
        call    DRAW_SUBMENU_SUBHEADING                        ;#4A39: CD 9F 45
        call    DRAW_SEARCH_FILE_PROMPT                        ;#4A3C: CD E3 45
        ld      hl,DISK_ERROR_RETRY_NO_SAVE                    ;#4A3F: 21 75 69
        call    SETUP_INTERSLOT_CALL                           ;#4A42: CD 29 69
        xor     a                                              ;#4A45: AF
        ld      (MENU_SELECTED_INDEX),a                        ;#4A46: 32 63 D1
        ld      (MENU_CURRENT_INDEX),a                         ;#4A49: 32 65 D1
        LOAD_NAME_TABLE hl, 11, 12                             ;#4A4C: 21 6C 39
        ld      (MENU_CURSOR_VRAM_ADDR),hl                     ;#4A4F: 22 68 D1
        ld      (MENU_TABLE_PTR),hl                            ;#4A52: 22 6A D1
        ld      a,80h                                          ;#4A55: 3E 80
        ld      (MENU_MAX_INDEX),a                             ;#4A57: 32 64 D1
        ret                                                    ;#4A5A: C9

MODIFY_OPTION_PATTERN:
        ; MODIFY option 3 ("COLOR TEST PATTERN"): full-screen test
        call    DRAW_FULL_SCREEN_PATTERN                       ;#4A5B: CD F4 4A
        call    DRAW_SELF_OPTION_0_SCREEN                      ;#4A5E: CD 54 47
MODIFY_MENU_REDRAW:
        ; Common return: draw borders + clear name area, jp ENTER_MODIFY (re-show)
        call    DRAW_TOP_BOTTOM_BORDERS                        ;#4A61: CD AF 4F
        call    CLEAR_MIDDLE_NAME_AREA                         ;#4A64: CD 4D 4B
        jp      ENTER_MODIFY                                   ;#4A67: C3 17 48

MODIFY_OPTION_START_GAME:
        ; MODIFY option 4 ("START GAME"): di + jp SETUP_GAME_MODE
        di                                                     ;#4A6A: F3
        jp      SETUP_GAME_MODE                                ;#4A6B: C3 FD 4E

MODIFY_SCREEN_TEXT:
        ; Encoded text stream for the MODIFY screen header & 5 menu items
        NAME_TABLE 6, 6                                        ;#4A6E: C6 38
        db      "@@MODIFY", 0, "MODE", 0, "MENU@@"             ;#4A70: 40 40 4D 4F 44 49 46 59 00 4D 4F 44 45 00 4D 45 4E 55 40 40
        TEXT_SEPARATOR                                         ;#4A84: FE
        NAME_TABLE 9, 7                                        ;#4A85: 27 39
        db      "MODIFY", 0, "STAGE", 0, "NUMBER"              ;#4A87: 4D 4F 44 49 46 59 00 53 54 41 47 45 00 4E 55 4D 42 45 52
        TEXT_SEPARATOR                                         ;#4A9A: FE
        NAME_TABLE 11, 7                                       ;#4A9B: 67 39
        db      "MODIFY", 0, "PLAYER", 0, "NUMBER"             ;#4A9D: 4D 4F 44 49 46 59 00 50 4C 41 59 45 52 00 4E 55 4D 42 45 52
        TEXT_SEPARATOR                                         ;#4AB1: FE
        NAME_TABLE 13, 7                                       ;#4AB2: A7 39
        db      "RANKING", 0, "MODE"                           ;#4AB4: 52 41 4E 4B 49 4E 47 00 4D 4F 44 45
        TEXT_SEPARATOR                                         ;#4AC0: FE
        NAME_TABLE 15, 7                                       ;#4AC1: E7 39
        db      "COLOR", 0, "TEST", 0, "PATTERN"               ;#4AC3: 43 4F 4C 4F 52 00 54 45 53 54 00 50 41 54 54 45 52 4E
        TEXT_SEPARATOR                                         ;#4AD5: FE
        NAME_TABLE 17, 7                                       ;#4AD6: 27 3A
        db      "START", 0, "GAME"                             ;#4AD8: 53 54 41 52 54 00 47 41 4D 45
        TEXT_TERMINATOR                                        ;#4AE2: FF

MODIFY_MENU_POSITIONS:
        ; 5 VRAM-row addresses for the MODIFY menu cursor
        NAME_TABLE 9, 6                                        ;#4AE3: 26 39
        NAME_TABLE 11, 6                                       ;#4AE5: 66 39
        NAME_TABLE 13, 6                                       ;#4AE7: A6 39
        NAME_TABLE 15, 6                                       ;#4AE9: E6 39
        NAME_TABLE 17, 6                                       ;#4AEB: 26 3A

RUN_2DIGIT_NUM_INPUT:
        ; A=FFh, B=2 max digits, jp RUN_NAME_INPUT_LOOP: accept a 2-digit number
        ld      a,0FFh                                         ;#4AED: 3E FF
        ld      b,2                                            ;#4AEF: 06 02
        jp      RUN_NAME_INPUT_LOOP                            ;#4AF1: C3 D8 62

DRAW_FULL_SCREEN_PATTERN:
        ; 16 rows of SELF_TEST_PATTERN_ROW + colour fill + corner marker
        call    CLEAR_NAME_TABLE                               ;#4AF4: CD 2A 61
        LOAD_NAME_TABLE de, 0, 0                               ;#4AF7: 11 00 38
        ld      b,10h                                          ;#4AFA: 06 10
DRAW_FULL_SCREEN_PATTERN_LOOP:
        ; Outer 16-row loop body: push regs, set up LDIRVM of one pattern row
        push    bc                                             ;#4AFC: C5
        push    de                                             ;#4AFD: D5
        ld      bc,20h                                         ;#4AFE: 01 20 00
        ld      hl,SELF_TEST_PATTERN_ROW                       ;#4B01: 21 2D 4B
        call    BIOS_LDIRVM                                    ;#4B04: CD 5C 00
        pop     hl                                             ;#4B07: E1
        ld      bc,20h                                         ;#4B08: 01 20 00
        add     hl,bc                                          ;#4B0B: 09
        ex      de,hl                                          ;#4B0C: EB
        pop     bc                                             ;#4B0D: C1
        djnz    DRAW_FULL_SCREEN_PATTERN_LOOP                  ;#4B0E: 10 EC
        LOAD_NAME_TABLE hl, 16, 7                              ;#4B10: 21 07 3A
        ld      bc,810h                                        ;#4B13: 01 10 08
        ld      a,0Fh                                          ;#4B16: 3E 0F
        call    FILVRM_RANGE                                   ;#4B18: CD AA 61
        LOAD_NAME_TABLE de, 23, 25                             ;#4B1B: 11 F9 3A
        ld      hl,SELF_TEST_INDICATOR_TILES                   ;#4B1E: 21 27 4B
        ld      bc,6                                           ;#4B21: 01 06 00
        jp      BIOS_LDIRVM                                    ;#4B24: C3 5C 00

SELF_TEST_INDICATOR_TILES:
        ; 6-byte tile-index sequence (88h..8Dh) drawn at VRAM 3AF9
        dh      "88898A8B8C8D"                                 ;#4B27: 88 89 8A 8B 8C 8D

SELF_TEST_PATTERN_ROW:
        ; 32-byte test pattern source row, copied to all 16 rows of the name table
        dh      "800E0E0E840A0A0A0A81070707850C0C"             ;#4B2D: 80 0E 0E 0E 84 0A 0A 0A 0A 81 07 07 07 85 0C 0C
        dh      "0C0C820D0D0D86060606068304040487"             ;#4B3D: 0C 0C 82 0D 0D 0D 86 06 06 06 06 83 04 04 04 87

CLEAR_MIDDLE_NAME_AREA:
        ; Fill VRAM 3880h..3A80h (16 rows starting row 4) with 0 via BIOS_FILVRM
        LOAD_NAME_TABLE hl, 4, 0                               ;#4B4D: 21 80 38
        ld      bc,200h                                        ;#4B50: 01 00 02
        xor     a                                              ;#4B53: AF
        jp      BIOS_FILVRM                                    ;#4B54: C3 56 00

STORE_INPUT_AS_DECIMAL:
        ; Store at (HL): nibble (1-digit) or hi*10+lo (2-digit) of NAME_INPUT_BUFFER
        xor     a                                              ;#4B57: AF
        ld      (hl),a                                         ;#4B58: 77
        ld      a,(MENU_SELECTED_INDEX)                        ;#4B59: 3A 63 D1
        or      a                                              ;#4B5C: B7
        ret     z                                              ;#4B5D: C8
        ld      de,NAME_INPUT_BUFFER                           ;#4B5E: 11 42 D1
        cp      1                                              ;#4B61: FE 01
        jr      nz,STORE_DECIMAL_TWO_DIGITS                    ;#4B63: 20 06
        ld      a,(de)                                         ;#4B65: 1A
        and     0Fh                                            ;#4B66: E6 0F
        ld      (hl),a                                         ;#4B68: 77
        or      a                                              ;#4B69: B7
        ret                                                    ;#4B6A: C9

STORE_DECIMAL_TWO_DIGITS:
        ; 2-digit decimal branch: build hi*10+lo via add/shift, store to (HL)
        cp      2                                              ;#4B6B: FE 02
        ret     nz                                             ;#4B6D: C0
        ld      a,(de)                                         ;#4B6E: 1A
        and     0Fh                                            ;#4B6F: E6 0F
        add     a,a                                            ;#4B71: 87
        ld      b,a                                            ;#4B72: 47
        add     a,a                                            ;#4B73: 87
        add     a,a                                            ;#4B74: 87
        add     a,b                                            ;#4B75: 80
        ld      b,a                                            ;#4B76: 47
        inc     de                                             ;#4B77: 13
        ld      a,(de)                                         ;#4B78: 1A
        and     0Fh                                            ;#4B79: E6 0F
        add     a,b                                            ;#4B7B: 80
        ld      (hl),a                                         ;#4B7C: 77
        ret                                                    ;#4B7D: C9

STORE_INPUT_AS_HEX_BYTE:
        ; Store at (HL): nibble or (hi<<4)|lo packed-BCD byte from NAME_INPUT_BUFFER
        xor     a                                              ;#4B7E: AF
        ld      (hl),a                                         ;#4B7F: 77
        ld      a,(MENU_SELECTED_INDEX)                        ;#4B80: 3A 63 D1
        or      a                                              ;#4B83: B7
        ret     z                                              ;#4B84: C8
        ld      de,NAME_INPUT_BUFFER                           ;#4B85: 11 42 D1
        cp      1                                              ;#4B88: FE 01
        jr      nz,STORE_HEX_TWO_DIGITS                        ;#4B8A: 20 06
        ld      a,(de)                                         ;#4B8C: 1A
        and     0Fh                                            ;#4B8D: E6 0F
        ld      (hl),a                                         ;#4B8F: 77
        or      a                                              ;#4B90: B7
        ret                                                    ;#4B91: C9

STORE_HEX_TWO_DIGITS:
        ; 2-digit hex branch: build (hi<<4)|lo via shifts, store to (HL)
        cp      2                                              ;#4B92: FE 02
        ret     nz                                             ;#4B94: C0
        ld      a,(de)                                         ;#4B95: 1A
        and     0Fh                                            ;#4B96: E6 0F
        add     a,a                                            ;#4B98: 87
        add     a,a                                            ;#4B99: 87
        add     a,a                                            ;#4B9A: 87
        add     a,a                                            ;#4B9B: 87
        ld      b,a                                            ;#4B9C: 47
        inc     de                                             ;#4B9D: 13
        ld      a,(de)                                         ;#4B9E: 1A
        and     0Fh                                            ;#4B9F: E6 0F
        add     a,b                                            ;#4BA1: 80
        ld      (hl),a                                         ;#4BA2: 77
        ret                                                    ;#4BA3: C9

VERIFY_AND_PATCH_GAME_CART:
        ; Install D814 trampoline, scan first 100h cart bytes for BIOS_HKEYI+1, patch 4BE6
        ld      hl,GAME_CART_TRAMPOLINE                        ;#4BA4: 21 F7 4B
        ld      de,GAME_CART_TRAMPOLINE_RAM                    ;#4BA7: 11 14 D8
        LD_BC_SIZE GAME_CART_TRAMPOLINE                        ;#4BAA: 01 3B 00
        ldir                                                   ;#4BAD: ED B0
        push    de                                             ;#4BAF: D5
        ld      hl,(GAME_CART_INIT_POINTER)                    ;#4BB0: 2A 32 D1
        ld      bc,100h                                        ;#4BB3: 01 00 01
        call    READ_BYTES_FROM_GAME_CART                      ;#4BB6: CD D3 4B
VERIFY_AND_PATCH_AFTER_READ:
        ; After cart-read: restore HL, BC=100h, fall into SCAN_HKEYI_HOOK_SIG_LOOP
        pop     hl                                             ;#4BB9: E1
        ld      bc,100h                                        ;#4BBA: 01 00 01
SCAN_HKEYI_HOOK_SIG_LOOP:
        ; Scan for BIOS_HKEYI+1 word; on match ldir 5 bytes to GAME_CART_PATCH_SLOT
        ld      a,low(BIOS_HKEYI+1)                            ;#4BBD: 3E 9B
        cpir                                                   ;#4BBF: ED B1
        ret     nz                                             ;#4BC1: C0
        ld      a,high(BIOS_HKEYI+1)                           ;#4BC2: 3E FD
        cp      (hl)                                           ;#4BC4: BE
        jr      nz,SCAN_HKEYI_HOOK_SIG_LOOP                    ;#4BC5: 20 F6
        dec     hl                                             ;#4BC7: 2B
        ld      de,GAME_CART_PATCH_SLOT                        ;#4BC8: 11 E6 4B
        ex      de,hl                                          ;#4BCB: EB
        ld      bc,5                                           ;#4BCC: 01 05 00
        ldir                                                   ;#4BCF: ED B0
        xor     a                                              ;#4BD1: AF
        ret                                                    ;#4BD2: C9

READ_BYTES_FROM_GAME_CART:
        ; Read BC bytes from (HL) in GAME_CART_SLOT into RAM at (DE) via BIOS_RDSLT
        push    bc                                             ;#4BD3: C5
        push    de                                             ;#4BD4: D5
        ld      a,(GAME_CART_SLOT)                             ;#4BD5: 3A 2F D1
        call    BIOS_RDSLT                                     ;#4BD8: CD 0C 00
        pop     de                                             ;#4BDB: D1
        pop     bc                                             ;#4BDC: C1
        ld      (de),a                                         ;#4BDD: 12
        inc     hl                                             ;#4BDE: 23
        inc     de                                             ;#4BDF: 13
        dec     bc                                             ;#4BE0: 0B
        ld      a,b                                            ;#4BE1: 78
        or      c                                              ;#4BE2: B1
        jr      nz,READ_BYTES_FROM_GAME_CART                   ;#4BE3: 20 EE
        ret                                                    ;#4BE5: C9

GAME_CART_PATCH_SLOT:
        ; 5-byte slot overwritten at runtime with the 5 bytes preceding BIOS_HKEYI+1
        jr      nc,VERIFY_AND_PATCH_AFTER_READ                 ;#4BE6: 30 D1
        call    GAME_CART_TRAMPOLINE_RAM                       ;#4BE8: CD 14 D8
INSTALL_ISR_TO_RAM:
        ; Copy ISR_GAME_RUNNING into ISR_GAME_RUNNING_RAM (14Ah bytes of RAM scratch)
        ld      hl,ISR_GAME_RUNNING                            ;#4BEB: 21 32 4C
        ld      de,ISR_GAME_RUNNING_RAM                        ;#4BEE: 11 70 D1
        LD_BC_SIZE ISR_GAME_RUNNING                            ;#4BF1: 01 4A 01
        ldir                                                   ;#4BF4: ED B0
        ret                                                    ;#4BF6: C9

GAME_CART_TRAMPOLINE:
        ; 3Bh-byte block copied to D814: cart-enter + return-to-ROM stubs

        phase   0D814h
GAME_CART_TRAMPOLINE_RAM:
        ; RAM-resident GAME_CART_TRAMPOLINE copy (3Bh bytes); jp (hl) cart-entry stub
        di                                                     ;#D814: F3
        ld      de,BIOS_HOOK_AREA                              ;#D815: 11 00 FD
        ld      hl,BIOS_WORK_AREA_BACKUP                       ;#D818: 21 4F D9
        ld      bc,2CAh                                        ;#D81B: 01 CA 02
        ldir                                                   ;#D81E: ED B0
        ld      a,Z80_JP                                       ;#D820: 3E C3
        ld      (BIOS_HKEYI),a                                 ;#D822: 32 9A FD
        ld      hl,ISR_HOOK_RESTART_ADDR                       ;#D825: 21 99 D2
        ld      (BIOS_HKEYI+1),hl                              ;#D828: 22 9B FD
        pop     hl                                             ;#D82B: E1
        dec     hl                                             ;#D82C: 2B
        dec     hl                                             ;#D82D: 2B
        dec     hl                                             ;#D82E: 2B
        ld      de,GAME_CART_TRAMPOLINE_RAM_END                ;#D82F: 11 4F D8
        and     a                                              ;#D832: A7
        sbc     hl,de                                          ;#D833: ED 52
        ld      de,(GAME_CART_INIT_POINTER)                    ;#D835: ED 5B 32 D1
        add     hl,de                                          ;#D839: 19
        jp      (hl)                                           ;#D83A: E9

LAUNCH_GAME_CART_TRAMPOLINE_RAM:
        ; RAM-resident jp target that ENASLTs the game cart at page 1
        ld      hl,BIOS_HOOK_AREA                              ;#D83B: 21 00 FD
        ld      de,BIOS_WORK_AREA_BACKUP                       ;#D83E: 11 4F D9
        ld      bc,2CAh                                        ;#D841: 01 CA 02
        ldir                                                   ;#D844: ED B0
        ld      a,(GAME_CART_SLOT)                             ;#D846: 3A 2F D1
        ld      hl,ROM_HEADER                                  ;#D849: 21 00 40
        call    BIOS_ENASLT                                    ;#D84C: CD 24 00
        dephase

GAME_CART_TRAMPOLINE_END:
ISR_GAME_RUNNING:
        ; Interrupt handler while the game cart executes (runs from ISR_GAME_RUNNING_RAM)

        phase   0D170h
ISR_GAME_RUNNING_RAM:
        ; RAM-resident copy of ISR_GAME_RUNNING (14Ah bytes; see INSTALL_ISR_TO_RAM)
        di                                                     ;#D170: F3
        ld      a,(IN_ISR_LOCK)                                ;#D171: 3A 3B D1
        or      a                                              ;#D174: B7
        ret     nz                                             ;#D175: C0
        call    BIOS_RDVDP                                     ;#D176: CD 3E 01
        call    BIOS_HTIMI                                     ;#D179: CD 9F FD
        ld      ix,(GAME_TICK_CALLBACK_PTR)                    ;#D17C: DD 2A 30 D1
        ld      iy,(SAVED_PSG_VOL_C)                           ;#D180: FD 2A 2D D1
        ld      a,7                                            ;#D184: 3E 07
        ; SNSMAT row 7 bit 4 — STOP key. After CPL the AND 10h
        ; isolates the STOP-pressed bit; bit 4 of GAME_INPUT_BITFIELD
        ; drives TOGGLE_MENU_FROM_GAME at 4C66h.
        call    BIOS_SNSMAT                                    ;#D186: CD 41 01
        cpl                                                    ;#D189: 2F
        and     10h                                            ;#D18A: E6 10
        ld      b,a                                            ;#D18C: 47
        ld      a,8                                            ;#D18D: 3E 08
        ; SNSMAT row 8 bits 2,3 — INS and DEL keys. After CPL the
        ; RRCA rotates row 8 right, then AND 6 keeps the rotated
        ; bits 1,2 (original bits 2,3 = INS/DEL). These end up at
        ; bits 1,2 of GAME_INPUT_BITFIELD, readable by the running
        ; game cart via GAME_INPUT_BITFIELD.
        call    BIOS_SNSMAT                                    ;#D18F: CD 41 01
        cpl                                                    ;#D192: 2F
        rrca                                                   ;#D193: 0F
        and     6                                              ;#D194: E6 06
        or      b                                              ;#D196: B0
        ld      hl,GAME_INPUT_BITFIELD                         ;#D197: 21 37 D1
        ld      c,(hl)                                         ;#D19A: 4E
        ld      (hl),a                                         ;#D19B: 77
        xor     c                                              ;#D19C: A9
        and     (hl)                                           ;#D19D: A6
        ld      c,a                                            ;#D19E: 4F
        di                                                     ;#D19F: F3
        bit     4,a                                            ;#D1A0: CB 67
        jr      z,ISR_CHECK_MODIFY_FLAGS                       ;#D1A2: 28 07
        ld      ix,TOGGLE_MENU_FROM_GAME                       ;#D1A4: DD 21 7C 4D
        jp      BIOS_CALSLT                                    ;#D1A8: C3 1C 00

ISR_CHECK_MODIFY_FLAGS:
        ; After game callback: load MODIFY_FLAGS, skip block if zero
        ld      a,(MODIFY_FLAGS)                               ;#D1AB: 3A 17 D3
        or      a                                              ;#D1AE: B7
        jr      z,ISR_CHECK_RANKING_AVAIL                      ;#D1AF: 28 18
        ; Per-frame cart-state monitor (runs from the relocated ISR copy at
        ; ISR_GAME_RUNNING_RAM+). Samples the game's main state byte at
        ; GAME_RAM_TRIGGER_PTR; when the
        ; value both *changed* (vs the cached previous in GAME_PREV_STATE_BYTE) AND equals
        ; GAME_STATE_TRIGGER_VAL, BIOS_CALSLT into ON_GAME_STATE_TRANSITION to apply any
        ; pending stage / lives / ranking cheats. GAME_STATE_TRIGGER_VAL is therefore the
        ; "magic value the game-state byte must reach for cheats to take
        ; effect" — set per game in the CD-header block A (cart 4017h) or
        ; in the GAME_DATA record trailer field.
        ld      hl,(GAME_RAM_TRIGGER_PTR)                      ;#D1B1: 2A 04 D3
        ld      a,(hl)                                         ;#D1B4: 7E
        ld      hl,GAME_PREV_STATE_BYTE                        ;#D1B5: 21 16 D3
        cp      (hl)                                           ;#D1B8: BE
        jr      z,ISR_CHECK_RANKING_AVAIL                      ;#D1B9: 28 0E
        ld      (hl),a                                         ;#D1BB: 77
        ld      a,(GAME_STATE_TRIGGER_VAL)                     ;#D1BC: 3A 12 D3
        cp      (hl)                                           ;#D1BF: BE
        jr      nz,ISR_CHECK_RANKING_AVAIL                     ;#D1C0: 20 07
        ld      ix,ON_GAME_STATE_TRANSITION                    ;#D1C2: DD 21 50 53
        jp      BIOS_CALSLT                                    ;#D1C6: C3 1C 00

ISR_CHECK_RANKING_AVAIL:
        ; Load RANKING_AVAILABLE_FLAG; skip score-backup block if zero
        ld      a,(RANKING_AVAILABLE_FLAG)                     ;#D1C9: 3A 32 D3
        or      a                                              ;#D1CC: B7
        jr      z,ISR_CHECK_MENU_TOGGLE                        ;#D1CD: 28 1F
        push    bc                                             ;#D1CF: C5
        ld      a,(ISR_DISPATCH_FLAG)                          ;#D1D0: 3A 39 D3
        rra                                                    ;#D1D3: 1F
        jr      c,ISR_BACKUP_SCORES                            ;#D1D4: 38 20
        ld      hl,(GAME_RAM_SCORE_1P_PTR)                     ;#D1D6: 2A 0E D3
        ld      de,(GAME_RAM_SCORE_2P_PTR)                     ;#D1D9: ED 5B 10 D3
ISR_PROCESS_POSITION_PAIR:
        ; push DE; copy SCORE_*_PTR words into D31E/D321 via ISR_UPDATE_IF_GREATER
        push    de                                             ;#D1DD: D5
        ld      de,RANKING_INPUT_BUFFER_1P+2                   ;#D1DE: 11 1E D3
        call    ISR_UPDATE_IF_GREATER                          ;#D1E1: CD 80 D2
        ld      de,RANKING_INPUT_BUFFER_2P+2                   ;#D1E4: 11 21 D3
        pop     hl                                             ;#D1E7: E1
        ld      a,h                                            ;#D1E8: 7C
        or      l                                              ;#D1E9: B5
        call    nz,ISR_UPDATE_IF_GREATER                       ;#D1EA: C4 80 D2
        pop     bc                                             ;#D1ED: C1
ISR_CHECK_MENU_TOGGLE:
        ; Load MENU_ACTIVE_FLIPFLOP bit 0; if set jump to F5/menu hook dispatch
        ld      a,(MENU_ACTIVE_FLIPFLOP)                       ;#D1EE: 3A 34 D1
        rra                                                    ;#D1F1: 1F
        jr      c,ISR_DISPATCH_MENU_HOOK                       ;#D1F2: 38 1C
        jp      (ix)                                           ;#D1F4: DD E9

ISR_BACKUP_SCORES:
        ; Copy 1P+2P scores via SCORE_*_PTR into SCORE_1P/2P_BACKUP (3 bytes each)
        ld      hl,(GAME_RAM_SCORE_1P_PTR)                     ;#D1F6: 2A 0E D3
        ld      de,SCORE_1P_BACKUP                             ;#D1F9: 11 35 D3
        call    ISR_COPY_DESCENDING                            ;#D1FC: CD 77 D2
        ld      hl,(GAME_RAM_SCORE_2P_PTR)                     ;#D1FF: 2A 10 D3
        ld      de,SCORE_2P_BACKUP                             ;#D202: 11 38 D3
        call    ISR_COPY_DESCENDING                            ;#D205: CD 77 D2
        ld      hl,SCORE_BACKUP_TAIL                           ;#D208: 21 33 D3
        ld      de,SCORE_BACKUP_TAIL+3                         ;#D20B: 11 36 D3
        jr      ISR_PROCESS_POSITION_PAIR                      ;#D20E: 18 CD

ISR_DISPATCH_MENU_HOOK:
        ; GAME_STATE==2 -> F5 path; else CALSLT into RUN_HKEYI_GUARDED
        ld      a,(GAME_STATE)                                 ;#D210: 3A 35 D1
        cp      2                                              ;#D213: FE 02
        jr      z,ISR_MENU_OPENING_INSTALL_HOOKS               ;#D215: 28 07
        ld      ix,RUN_HKEYI_GUARDED                           ;#D217: DD 21 C8 4D
        jp      BIOS_CALSLT                                    ;#D21B: C3 1C 00

ISR_MENU_OPENING_INSTALL_HOOKS:
        ; Inspect bits of C (saved input) and install/clear ISR_SCRATCH bytes
        ld      hl,ISR_SCRATCH_BYTE_2                          ;#D21E: 21 3A D1
        ld      de,ISR_SCRATCH_BYTE_1                          ;#D221: 11 39 D1
        bit     1,c                                            ;#D224: CB 49
        jr      z,ISR_MENU_OPENING_CHECK_DISPLAY_BIT           ;#D226: 28 24
        ld      a,(hl)                                         ;#D228: 7E
        or      a                                              ;#D229: B7
        ret     z                                              ;#D22A: C8
        sub     0Dh                                            ;#D22B: D6 0D
        jr      z,ISR_MENU_OPENING_INSTALL_SAVE_PSG            ;#D22D: 28 02
        jr      nc,ISR_MENU_OPENING_CLEAR_SCRATCHES            ;#D22F: 30 17
ISR_MENU_OPENING_INSTALL_SAVE_PSG:
        ; Bit 1 path: CALSLT into SAVE_PSG_VOLUMES_TO_RAM, then set scratches
        push    hl                                             ;#D231: E5
        push    de                                             ;#D232: D5
        ld      ix,SAVE_PSG_VOLUMES_TO_RAM                     ;#D233: DD 21 A0 4D
        call    BIOS_CALSLT                                    ;#D237: CD 1C 00
        ld      iy,(SAVED_PSG_VOL_C)                           ;#D23A: FD 2A 2D D1
        ld      ix,MUTE_ALL_PSG_CHANNELS                       ;#D23E: DD 21 91 4D
        call    BIOS_CALSLT                                    ;#D242: CD 1C 00
        pop     de                                             ;#D245: D1
        pop     hl                                             ;#D246: E1
        xor     a                                              ;#D247: AF
ISR_MENU_OPENING_CLEAR_SCRATCHES:
        ; Zero both ISR_SCRATCH bytes and return
        ld      (hl),a                                         ;#D248: 77
        xor     a                                              ;#D249: AF
        ld      (de),a                                         ;#D24A: 12
        ret                                                    ;#D24B: C9

ISR_MENU_OPENING_CHECK_DISPLAY_BIT:
        ; Bit 2 path: handle game-display save flag
        bit     2,c                                            ;#D24C: CB 51
        jr      z,ISR_MENU_OPENING_CHECK_SCRATCH_HL            ;#D24E: 28 16
        ld      a,0Dh                                          ;#D250: 3E 0D
        add     a,(hl)                                         ;#D252: 86
        jr      nc,ISR_MENU_OPENING_SET_DISPLAY_FF             ;#D253: 30 02
        ld      a,0FFh                                         ;#D255: 3E FF
ISR_MENU_OPENING_SET_DISPLAY_FF:
        ; Write FFh to scratch byte; if not in 'D' mode, fall through to clear-de
        ld      (hl),a                                         ;#D257: 77
        cp      0Dh                                            ;#D258: FE 0D
        jr      nz,ISR_MENU_OPENING_CLEAR_AND_RET              ;#D25A: 20 07
        ld      ix,RESTORE_PSG_VOLUMES_FROM_RAM                ;#D25C: DD 21 13 4E
        call    BIOS_CALSLT                                    ;#D260: CD 1C 00
ISR_MENU_OPENING_CLEAR_AND_RET:
        ; Zero (DE) and return — common cleanup tail
        xor     a                                              ;#D263: AF
        ld      (de),a                                         ;#D264: 12
        ret                                                    ;#D265: C9

ISR_MENU_OPENING_CHECK_SCRATCH_HL:
        ; Bit 2 reset path: (HL)=0 means no save active, dispatch mute via CALSLT
        ld      a,(hl)                                         ;#D266: 7E
        or      a                                              ;#D267: B7
        jr      z,ISR_MENU_OPENING_TRIGGER_MUTE_PSG            ;#D268: 28 06
        ld      a,(de)                                         ;#D26A: 1A
        add     a,(hl)                                         ;#D26B: 86
        ld      (de),a                                         ;#D26C: 12
        ret     nc                                             ;#D26D: D0
        jp      (ix)                                           ;#D26E: DD E9

ISR_MENU_OPENING_TRIGGER_MUTE_PSG:
        ; IX=MUTE_ALL_PSG_CHANNELS; jp BIOS_CALSLT to mute via the game slot
        ld      ix,MUTE_ALL_PSG_CHANNELS                       ;#D270: DD 21 91 4D
        jp      BIOS_CALSLT                                    ;#D274: C3 1C 00

ISR_COPY_DESCENDING:
        ; Runtime call (ROM 4D39h): copy 3 bytes from (HL) to (DE), HL+ / DE-
        ld      b,3                                            ;#D277: 06 03
ISR_COPY_DESCENDING_LOOP:
        ; Per-byte copy: ld a,(hl); ld (de),a; inc hl; dec de; djnz back
        ld      a,(hl)                                         ;#D279: 7E
        ld      (de),a                                         ;#D27A: 12
        inc     hl                                             ;#D27B: 23
        dec     de                                             ;#D27C: 1B
        djnz    ISR_COPY_DESCENDING_LOOP                       ;#D27D: 10 FA
        ret                                                    ;#D27F: C9

ISR_UPDATE_IF_GREATER:
        ; Runtime call (ROM 4D42h): if 3-byte BE (HL) > (DE), lddr 3 bytes
        inc     hl                                             ;#D280: 23
        inc     hl                                             ;#D281: 23
        push    hl                                             ;#D282: E5
        push    de                                             ;#D283: D5
        ld      b,3                                            ;#D284: 06 03
ISR_UPDATE_GT_COMPARE_LOOP:
        ; Compare loop: compare (DE) and (HL) per byte; jr c if HL > DE
        ld      a,(de)                                         ;#D286: 1A
        cp      (hl)                                           ;#D287: BE
        jr      c,ISR_UPDATE_GT_LDDR                           ;#D288: 38 07
        dec     hl                                             ;#D28A: 2B
        dec     de                                             ;#D28B: 1B
        djnz    ISR_UPDATE_GT_COMPARE_LOOP                     ;#D28C: 10 F8
        pop     de                                             ;#D28E: D1
        pop     hl                                             ;#D28F: E1
        ret                                                    ;#D290: C9

ISR_UPDATE_GT_LDDR:
        ; HL>DE confirmed: pop de/hl and lddr 3 bytes
        pop     de                                             ;#D291: D1
        pop     hl                                             ;#D292: E1
        ld      bc,3                                           ;#D293: 01 03 00
        lddr                                                   ;#D296: ED B8
        ret                                                    ;#D298: C9

ISR_HOOK_RESTART_ADDR:
        ; Address installed at FD9Bh by trampoline — re-entry on hook fire
        ld      hl,0                                           ;#D299: 21 00 00
        add     hl,sp                                          ;#D29C: 39
        ld      de,STACK_BASE                                  ;#D29D: 11 80 DF
        ld      bc,80h                                         ;#D2A0: 01 80 00
        ldir                                                   ;#D2A3: ED B0
        ld      sp,STACK_BASE                                  ;#D2A5: 31 80 DF
        ld      hl,BIOS_WORK_AREA_COPY                         ;#D2A8: 21 00 D5
        ld      de,BIOS_WORK_AREA                              ;#D2AB: 11 00 F1
        ld      bc,314h                                        ;#D2AE: 01 14 03
        ldir                                                   ;#D2B1: ED B0
        ld      hl,ISR_GAME_RUNNING_RAM                        ;#D2B3: 21 70 D1
        ld      (BIOS_HKEYI+1),hl                              ;#D2B6: 22 9B FD
        ret                                                    ;#D2B9: C9
        dephase

ISR_GAME_RUNNING_END:
TOGGLE_MENU_FROM_GAME:
        ; F5 trigger from ISR_GAME_RUNNING; flips MENU_ACTIVE_FLIPFLOP; opens or closes
        call    BIOS_RDVDP                                     ;#4D7C: CD 3E 01
        ld      hl,MENU_ACTIVE_FLIPFLOP                        ;#4D7F: 21 34 D1
        inc     (hl)                                           ;#4D82: 34
        ld      a,(hl)                                         ;#4D83: 7E
        rra                                                    ;#4D84: 1F
        jr      nc,CLOSE_MENU                                  ;#4D85: 30 32

OPEN_MENU:
        ; Save game state, mute PSG, snapshot PSG volumes; UI takeover starts
        xor     a                                              ;#4D87: AF
        ld      (GAME_STATE),a                                 ;#4D88: 32 35 D1
        call    BIOS_DISSCR                                    ;#4D8B: CD 32 01
        call    SAVE_PSG_VOLUMES_TO_RAM                        ;#4D8E: CD A0 4D
MUTE_ALL_PSG_CHANNELS:
        ; Write 0 to PSG R8/R9/R10 to silence channels A/B/C
        ld      e,0                                            ;#4D91: 1E 00
        ld      a,8                                            ;#4D93: 3E 08
        call    BIOS_WRTPSG                                    ;#4D95: CD 93 00
        inc     a                                              ;#4D98: 3C
        call    BIOS_WRTPSG                                    ;#4D99: CD 93 00
        inc     a                                              ;#4D9C: 3C
        jp      BIOS_WRTPSG                                    ;#4D9D: C3 93 00

SAVE_PSG_VOLUMES_TO_RAM:
        ; Read PSG R8/R9/R10 into D12B-D12D so the menu can restore them later
        ld      a,8                                            ;#4DA0: 3E 08
        call    BIOS_RDPSG                                     ;#4DA2: CD 96 00
        ld      (SAVED_PSG_VOL_A),a                            ;#4DA5: 32 2B D1
        ld      a,9                                            ;#4DA8: 3E 09
        call    BIOS_RDPSG                                     ;#4DAA: CD 96 00
        ld      (SAVED_PSG_VOL_B),a                            ;#4DAD: 32 2C D1
        ld      a,0Ah                                          ;#4DB0: 3E 0A
        call    BIOS_RDPSG                                     ;#4DB2: CD 96 00
        ld      (SAVED_PSG_VOL_C),a                            ;#4DB5: 32 2D D1
        ret                                                    ;#4DB8: C9

CLOSE_MENU:
        ; Restore PSG volumes, clear MENU_ACTIVE_FLIPFLOP and GAME_STATE; resume game
        ld      (hl),0                                         ;#4DB9: 36 00
        ld      a,0FFh                                         ;#4DBB: 3E FF
        call    BIOS_DISSCR                                    ;#4DBD: CD 32 01
        call    RESTORE_PSG_VOLUMES_FROM_RAM                   ;#4DC0: CD 13 4E
        xor     a                                              ;#4DC3: AF
        ld      (GAME_STATE),a                                 ;#4DC4: 32 35 D1
        ret                                                    ;#4DC7: C9

RUN_HKEYI_GUARDED:
        ; Set D13B=1 around the ISR call so re-entry from a long routine is suppressed
        ld      a,1                                            ;#4DC8: 3E 01
        ld      (IN_ISR_LOCK),a                                ;#4DCA: 32 3B D1
        call    HKEYI_HANDLER                                  ;#4DCD: CD D5 4D
        xor     a                                              ;#4DD0: AF
        ld      (IN_ISR_LOCK),a                                ;#4DD1: 32 3B D1
        ret                                                    ;#4DD4: C9

HKEYI_HANDLER:
        ; H.KEYI installed handler: pre-ISR work, then dispatch per game-state byte D135
        call    MUTE_ALL_PSG_CHANNELS                          ;#4DD5: CD 91 4D
        ld      ix,(GAME_TICK_CALLBACK_PTR)                    ;#4DD8: DD 2A 30 D1
        ld      iy,(OWN_SLOT_RAW)                              ;#4DDC: FD 2A 2E D1
        ld      a,(GAME_STATE)                                 ;#4DE0: 3A 35 D1
        or      a                                              ;#4DE3: B7
        jp      nz,IN_GAME_MENU                                ;#4DE4: C2 A3 41
        call    READ_CURSOR_AND_SPACE                          ;#4DE7: CD 2E 4E
        ld      a,c                                            ;#4DEA: 79
        rla                                                    ;#4DEB: 17
        jr      c,HKEYI_ON_GAME_LAUNCH                         ;#4DEC: 38 19
        rla                                                    ;#4DEE: 17
        jr      c,HKEYI_ON_STOP_PRESS                          ;#4DEF: 38 1C
        rla                                                    ;#4DF1: 17
        jr      c,HKEYI_ON_F5_PRESS                            ;#4DF2: 38 06
        bit     2,c                                            ;#4DF4: CB 51
        jp      nz,ENTER_PRINTER_MENU                          ;#4DF6: C2 8D 70
        ret                                                    ;#4DF9: C9

HKEYI_ON_F5_PRESS:
        ; F5 pressed: set GAME_STATE=2 and clear D139/D13A scratch
        ld      a,2                                            ;#4DFA: 3E 02
        ld      (GAME_STATE),a                                 ;#4DFC: 32 35 D1
        xor     a                                              ;#4DFF: AF
        ld      (ISR_SCRATCH_BYTE_2),a                         ;#4E00: 32 3A D1
        ld      (ISR_SCRATCH_BYTE_1),a                         ;#4E03: 32 39 D1
        ret                                                    ;#4E06: C9

HKEYI_ON_GAME_LAUNCH:
        ; Restore PSG volumes then jp BIOS_CALSLT to re-enter the game cart
        call    RESTORE_PSG_VOLUMES_FROM_RAM                   ;#4E07: CD 13 4E
        jp      BIOS_CALSLT                                    ;#4E0A: C3 1C 00

HKEYI_ON_STOP_PRESS:
        ; STOP key pressed: set GAME_STATE=1 (open in-game menu next ISR)
        ld      a,1                                            ;#4E0D: 3E 01
        ld      (GAME_STATE),a                                 ;#4E0F: 32 35 D1
        ret                                                    ;#4E12: C9

RESTORE_PSG_VOLUMES_FROM_RAM:
        ; Write D12B-D12D back into PSG R8/R9/R10
        ld      a,(SAVED_PSG_VOL_A)                            ;#4E13: 3A 2B D1
        ld      e,a                                            ;#4E16: 5F
        ld      a,8                                            ;#4E17: 3E 08
        call    BIOS_WRTPSG                                    ;#4E19: CD 93 00
        ld      a,(SAVED_PSG_VOL_B)                            ;#4E1C: 3A 2C D1
        ld      e,a                                            ;#4E1F: 5F
        ld      a,9                                            ;#4E20: 3E 09
        call    BIOS_WRTPSG                                    ;#4E22: CD 93 00
        ld      a,(SAVED_PSG_VOL_C)                            ;#4E25: 3A 2D D1
        ld      e,a                                            ;#4E28: 5F
        ld      a,0Ah                                          ;#4E29: 3E 0A
        jp      BIOS_WRTPSG                                    ;#4E2B: C3 93 00

READ_CURSOR_AND_SPACE:
        ; SNSMAT row 1 + row 6 → C bitfield: cursor keys, SPACE, STOP, etc.
        ld      a,1                                            ;#4E2E: 3E 01
        ; SNSMAT row 1 → AND 80h keeps bit 7 (SPACE-equivalent in
        ; this cart's matrix). Stored in D; later OR'd into bit 7 of the
        ; result word as the HKEYI_ON_GAME_LAUNCH trigger.
        call    BIOS_SNSMAT                                    ;#4E30: CD 41 01
        cpl                                                    ;#4E33: 2F
        and     80h                                            ;#4E34: E6 80
        ld      d,a                                            ;#4E36: 57
        ld      a,6                                            ;#4E37: 3E 06
        ; SNSMAT row 6 → AND E2h keeps bits 1, 5, 6, 7. Bit 1 (STOP)
        ; is tested separately and, if pressed, sets bit 3 via OR 8. The
        ; remaining bits feed E for OR-merge into C (printer-menu key at
        ; bit 7 → HKEYI dispatch bit 2).
        call    BIOS_SNSMAT                                    ;#4E39: CD 41 01
        cpl                                                    ;#4E3C: 2F
        and     0E2h                                           ;#4E3D: E6 E2
        bit     1,a                                            ;#4E3F: CB 4F
        jr      z,MAIN_ENTRY_FORCE_R1_BIT3                     ;#4E41: 28 02
        or      8                                              ;#4E43: F6 08
MAIN_ENTRY_FORCE_R1_BIT3:
        ; Merge after R#1 set: A &= E8h to clear extra bits, then re-init via BIOS_SNSMAT
        and     0E8h                                           ;#4E45: E6 E8
        ld      e,a                                            ;#4E47: 5F
        ld      a,7                                            ;#4E48: 3E 07
        ; SNSMAT row 7 → AND 7 keeps bits 0, 1, 2 (cursor/control keys
        ; on the cart's matrix). RLCA×3 shifts them up to bits 3, 4, 5 of
        ; the result, where bit 5 dispatches HKEYI_ON_F5_PRESS.
        call    BIOS_SNSMAT                                    ;#4E4A: CD 41 01
        cpl                                                    ;#4E4D: 2F
        and     7                                              ;#4E4E: E6 07
        or      e                                              ;#4E50: B3
        rlca                                                   ;#4E51: 07
        rlca                                                   ;#4E52: 07
        rlca                                                   ;#4E53: 07
        or      d                                              ;#4E54: B2
        ld      hl,GAME_INPUT_PREVIOUS                         ;#4E55: 21 38 D1
        ld      c,(hl)                                         ;#4E58: 4E
        ld      (hl),a                                         ;#4E59: 77
        xor     c                                              ;#4E5A: A9
        and     (hl)                                           ;#4E5B: A6
        ld      c,a                                            ;#4E5C: 4F
        ret                                                    ;#4E5D: C9

MAIN_ENTRY:
        ; Cart's main UI entry: clear VRAM, set border, init PSG/keyboard, run menu
        ld      a,2                                            ;#4E5E: 3E 02
        ld      (BIOS_SCRMOD),a                                ;#4E60: 32 AF FC
        ld      hl,0                                           ;#4E63: 21 00 00
        ld      bc,16384  ; 16KB = full VRAM, fill with 0      ;#4E66: 01 00 40
        xor     a                                              ;#4E69: AF
        call    BIOS_FILVRM                                    ;#4E6A: CD 56 00
        call    INIT_VDP_REGISTERS                             ;#4E6D: CD F2 60
        ld      a,0FFh                                         ;#4E70: 3E FF
        call    BIOS_DISSCR                                    ;#4E72: CD 32 01
        ld      bc,507h                                        ;#4E75: 01 07 05
        call    BIOS_WRTVDP                                    ;#4E78: CD 47 00
        call    CLEAR_NAME_TABLE                               ;#4E7B: CD 2A 61
        call    INIT_TITLE_SCREEN                              ;#4E7E: CD 4F 4F
        call    INIT_PRINTER_PATTERNS                          ;#4E81: CD 55 76
        call    INIT_TITLE_CURSOR_STATE                        ;#4E84: CD 43 4F
        call    BIOS_KILBUF                                    ;#4E87: CD 56 01
MAIN_ENTRY_WAIT_KEY:
        ; Wait for key with timeout (HL=120h count, B=1), then redraw title screen
        ld      hl,120h                                        ;#4E8A: 21 20 01
        ld      b,1                                            ;#4E8D: 06 01
        call    WAIT_KEY_TIMEOUT                               ;#4E8F: CD A3 4F
        jr      nz,MAIN_ENTRY_REDRAW                           ;#4E92: 20 13
        call    ADVANCE_TITLE_CURSOR                           ;#4E94: CD 6C 4F
        jr      nz,MAIN_ENTRY_WAIT_KEY                         ;#4E97: 20 F1
        ld      hl,GFX_TITLE_LOGO_PREFIX                       ;#4E99: 21 D6 4F
        call    DECOMPRESS_RLE_WITH_TARGET                     ;#4E9C: CD 76 61
        ld      b,1                                            ;#4E9F: 06 01
        ld      hl,0                                           ;#4EA1: 21 00 00
        call    WAIT_KEY_TIMEOUT                               ;#4EA4: CD A3 4F
MAIN_ENTRY_REDRAW:
        ; Redraw entry: CLEAR_NAME_TABLE + DRAW_PRINTER_SCREEN_LAYOUT (after timeout)
        call    CLEAR_NAME_TABLE                               ;#4EA7: CD 2A 61
        call    DRAW_PRINTER_SCREEN_LAYOUT                     ;#4EAA: CD 7B 76
MAIN_ENTRY_RUN_TOP_MENU:
        ; Load TOP_MENU_RICH_DATA + MENU_SELECT_RICH (3 entries, 4-col stride)
        ld      a,3                                            ;#4EAD: 3E 03
        ld      hl,TOP_MENU_RICH_DATA                          ;#4EAF: 21 C4 4E
        ld      bc,304h                                        ;#4EB2: 01 04 03
        LOAD_NAME_TABLE de, 13, 11                             ;#4EB5: 11 AB 39
        call    MENU_SELECT_RICH                               ;#4EB8: CD 7C 52
        call    CALL_INDIRECT_A                                ;#4EBB: CD E7 61
TOP_MENU_HANDLERS:
        ; 3-entry inline word-pointer table; consumed by CALL_INDIRECT_A at 4EBBh
        dw      TOP_MENU_HANDLER_GAME                          ;#4EBE: EE 4E
        dw      TOP_MENU_HANDLER_MODIFY                        ;#4EC0: 1C 4F
        dw      TOP_MENU_HANDLER_SELF                          ;#4EC2: 27 4F

TOP_MENU_RICH_DATA:
        ; 42-byte MENU_SELECT_RICH state block for the top-level GAME/MODIFY/SELF menu
        dh      "CA4ED64EE24E0000AEAFB5B6B7B8BE00"             ;#4EC4: CA 4E D6 4E E2 4E 00 00 AE AF B5 B6 B7 B8 BE 00
        dh      "0C0C00000C0CE4E5E7E7E6000C0C0000"             ;#4ED4: 0C 0C 00 00 0C 0C E4 E5 E7 E7 E6 00 0C 0C 00 00
        dh      "0C0CE8E9EC0CEAEBEDEE"                         ;#4EE4: 0C 0C E8 E9 EC 0C EA EB ED EE

TOP_MENU_HANDLER_GAME:
        ; GAME: tear down HKEYI, clear D134/D13B, jp 4067 → 4091 → D83B (game launch)
        ld      a,(GAME_CART_VALID_FLAG)                       ;#4EEE: 3A 3C D1
        inc     a                                              ;#4EF1: 3C
        jr      nz,MAIN_ENTRY_RUN_TOP_MENU                     ;#4EF2: 20 B9
        ld      bc,107h                                        ;#4EF4: 01 07 01
        call    BIOS_WRTVDP                                    ;#4EF7: CD 47 00
        call    CLEAR_NAME_TABLE                               ;#4EFA: CD 2A 61
SETUP_GAME_MODE:
        ; DI, install RET stubs at BIOS_HKEYI hook area, clear menu state, jp LAUNCH_GAME
        di                                                     ;#4EFD: F3
        ld      hl,BIOS_HKEYI                                  ;#4EFE: 21 9A FD
        ld      a,Z80_RET                                      ;#4F01: 3E C9
        ld      b,3                                            ;#4F03: 06 03
SETUP_GAME_MODE_HOOK_LOOP:
        ; Inner loop: write A (=C9 ret) to (HL), inc HL, djnz — 3 bytes at BIOS_HKEYI
        ld      (hl),a                                         ;#4F05: 77
        inc     hl                                             ;#4F06: 23
        djnz    SETUP_GAME_MODE_HOOK_LOOP                      ;#4F07: 10 FC
        xor     a                                              ;#4F09: AF
        ld      (MENU_ACTIVE_FLIPFLOP),a                       ;#4F0A: 32 34 D1
        ld      (IN_ISR_LOCK),a                                ;#4F0D: 32 3B D1
        jp      SETUP_GAME_CART_RAM                            ;#4F10: C3 67 40

RESET_FOR_GAME_MODE:
        ; END trampoline: clear D317/D332 then jr to mid-GAME setup at SETUP_GAME_MODE
        xor     a                                              ;#4F13: AF
        ld      (MODIFY_FLAGS),a                               ;#4F14: 32 17 D3
        ld      (RANKING_AVAILABLE_FLAG),a                     ;#4F17: 32 32 D3
        jr      SETUP_GAME_MODE                                ;#4F1A: 18 E1

TOP_MENU_HANDLER_MODIFY:
        ; MODIFY: requires D13C=FF; set D129=2; clear screen and dispatch to ENTER_MODIFY
        ld      a,(GAME_CART_VALID_FLAG)                       ;#4F1C: 3A 3C D1
        inc     a                                              ;#4F1F: 3C
        jp      nz,MAIN_ENTRY_RUN_TOP_MENU                     ;#4F20: C2 AD 4E
        ld      a,2                                            ;#4F23: 3E 02
        jr      TOP_MENU_SETUP_MODE_AND_DRAW                   ;#4F25: 18 02

TOP_MENU_HANDLER_SELF:
        ; SELF (no cart needed): set D129=1; clear screen and dispatch to ENTER_SELF
        ld      a,1                                            ;#4F27: 3E 01
TOP_MENU_SETUP_MODE_AND_DRAW:
        ; Common tail: store A as TOP_MENU_MODE, WRTVDP 107h, clear+init title
        ld      (TOP_MENU_MODE),a                              ;#4F29: 32 29 D1
        ld      bc,107h                                        ;#4F2C: 01 07 01
        call    BIOS_WRTVDP                                    ;#4F2F: CD 47 00
        call    CLEAR_NAME_TABLE                               ;#4F32: CD 2A 61
        call    INIT_TITLE_PATTERNS_TAIL                       ;#4F35: CD 63 4F
        ld      a,(TOP_MENU_MODE)                              ;#4F38: 3A 29 D1
        cp      2                                              ;#4F3B: FE 02
        jp      z,ENTER_MODIFY                                 ;#4F3D: CA 17 48
        jp      ENTER_SELF                                     ;#4F40: C3 3D 46

INIT_TITLE_CURSOR_STATE:
        ; Init title flashing cursor: SCRATCH_HEX_OUTPUT=0Eh, TITLE_CURSOR_VRAM_ADDR=3AAAh
        ld      a,0Eh                                          ;#4F43: 3E 0E
        ld      (SCRATCH_HEX_OUTPUT),a                         ;#4F45: 32 00 DA
        LOAD_NAME_TABLE hl, 21, 10                             ;#4F48: 21 AA 3A
        ld      (TITLE_CURSOR_VRAM_ADDR),hl                    ;#4F4B: 22 01 DA
        ret                                                    ;#4F4E: C9

INIT_TITLE_SCREEN:
        ; Load title-screen patterns to VRAM and run helper init routines
        ld      hl,TITLE_SCREEN_PATTERN_DATA                   ;#4F4F: 21 E7 4F
        LOAD_VRAM_ADDRESS de, 2080h                            ;#4F52: 11 80 20
        call    LOAD_PATTERN_TO_VRAM_3_BANKS                   ;#4F55: CD 63 61
        LOAD_VRAM_ADDRESS hl, 80h                              ;#4F58: 21 80 00
        ld      bc,0D8h                                        ;#4F5B: 01 D8 00
        ld      a,0F0h                                         ;#4F5E: 3E F0
        call    FILVRM_3_BANKS                                 ;#4F60: CD 3C 61
INIT_TITLE_PATTERNS_TAIL:
        ; Sub-entry skipping the initial pattern data load (used by SELF)
        call    LOAD_TITLE_PATTERN_SET2                        ;#4F63: CD 0A 51
        call    SETUP_TITLE_PATTERN_REGION                     ;#4F66: CD 7E 50
        jp      FINALIZE_TITLE_SCREEN                          ;#4F69: C3 F6 50

ADVANCE_TITLE_CURSOR:
        ; Each pass: TITLE_CURSOR_VRAM_ADDR -= 20h; draw 3 border rows; dec counter
        ld      hl,(TITLE_CURSOR_VRAM_ADDR)                    ;#4F6C: 2A 01 DA
        ld      de,VRAM_ROW_BACK_STEP                          ;#4F6F: 11 E0 FF
        add     hl,de                                          ;#4F72: 19
        ld      (TITLE_CURSOR_VRAM_ADDR),hl                    ;#4F73: 22 01 DA
        ld      a,10h                                          ;#4F76: 3E 10
        ld      b,3                                            ;#4F78: 06 03
        call    WRITE_INCREMENTING_VRAM_ROW                    ;#4F7A: CD 90 4F
        ld      bc,0B0Ch                                       ;#4F7D: 01 0C 0B
        call    WRITE_INCREMENTING_VRAM_ROW                    ;#4F80: CD 90 4F
        ld      b,c                                            ;#4F83: 41
        call    WRITE_INCREMENTING_VRAM_ROW                    ;#4F84: CD 90 4F
        xor     a                                              ;#4F87: AF
        call    BIOS_FILVRM                                    ;#4F88: CD 56 00
        ld      hl,SCRATCH_HEX_OUTPUT                          ;#4F8B: 21 00 DA
        dec     (hl)                                           ;#4F8E: 35
        ret                                                    ;#4F8F: C9

WRITE_INCREMENTING_VRAM_ROW:
        ; Write B incrementing bytes (A, A+1, ...) at VRAM (HL), then HL += 20h
        push    hl                                             ;#4F90: E5
DRAW_BORDER_ROW_INNER:
        ; Mid-row body: BIOS_WRTVRM, inc HL, inc A loop body
        call    BIOS_WRTVRM                                    ;#4F91: CD 4D 00
        inc     hl                                             ;#4F94: 23
        inc     a                                              ;#4F95: 3C
        djnz    DRAW_BORDER_ROW_INNER                          ;#4F96: 10 F9
        pop     hl                                             ;#4F98: E1
        ld      de,20h                                         ;#4F99: 11 20 00
        add     hl,de                                          ;#4F9C: 19
        ret                                                    ;#4F9D: C9
        ld      b,1                                            ;#4F9E: 06 01

WAIT_KEY_TIMEOUT_MAX:
        ; Entry to WAIT_KEY_TIMEOUT with HL pre-zeroed (longest wait)
        ld      hl,0                                           ;#4FA0: 21 00 00
WAIT_KEY_TIMEOUT:
        ; Poll keyboard via BIOS_CHSNS; return on keypress or after B × HL dec-loops
        dec     hl                                             ;#4FA3: 2B
        call    BIOS_CHSNS                                     ;#4FA4: CD 9C 00
        ret     nz                                             ;#4FA7: C0
        ld      a,h                                            ;#4FA8: 7C
        or      l                                              ;#4FA9: B5
        jr      nz,WAIT_KEY_TIMEOUT                            ;#4FAA: 20 F7
        djnz    WAIT_KEY_TIMEOUT_MAX                           ;#4FAC: 10 F2
        ret                                                    ;#4FAE: C9

DRAW_TOP_BOTTOM_BORDERS:
        ; Render border frame tiles to the top and bottom rows (3800h and 3A80h)
        LOAD_NAME_TABLE hl, 0, 0                               ;#4FAF: 21 00 38
        ld      b,2                                            ;#4FB2: 06 02
DRAW_TOP_BOTTOM_BORDERS_LOOP:
        ; 2-iteration body: push BC, call DRAW_BORDER_ROW, advance HL by row stride
        push    bc                                             ;#4FB4: C5
        ld      c,4                                            ;#4FB5: 0E 04
        call    DRAW_BORDER_ROW                                ;#4FB7: CD C1 4F
        pop     bc                                             ;#4FBA: C1
        LOAD_NAME_TABLE hl, 20, 0                              ;#4FBB: 21 80 3A
        djnz    DRAW_TOP_BOTTOM_BORDERS_LOOP                   ;#4FBE: 10 F4
        ret                                                    ;#4FC0: C9

DRAW_BORDER_ROW:
        ; Inner: write incrementing pattern indices 1..F (wrap) for one border row
        ld      b,10h                                          ;#4FC1: 06 10
        ld      a,1                                            ;#4FC3: 3E 01
DRAW_BORDER_ROW_LOOP:
        ; Per-tile body: WRTVRM the running pattern index, inc HL, wrap A
        call    BIOS_WRTVRM                                    ;#4FC5: CD 4D 00
        inc     hl                                             ;#4FC8: 23
        call    BIOS_WRTVRM                                    ;#4FC9: CD 4D 00
        inc     hl                                             ;#4FCC: 23
        inc     a                                              ;#4FCD: 3C
        and     0Fh                                            ;#4FCE: E6 0F
        djnz    DRAW_BORDER_ROW_LOOP                           ;#4FD0: 10 F3
        dec     c                                              ;#4FD2: 0D
        jr      nz,DRAW_BORDER_ROW                             ;#4FD3: 20 EC
        ret                                                    ;#4FD5: C9

GFX_TITLE_LOGO_PREFIX:
        ; 17-byte unknown header preceding TITLE_SCREEN_PATTERN_DATA (includes "SOFTWARE")
        dh      "4A390C2A806C3988534F465457415245"             ;#4FD6: 4A 39 0C 2A 80 6C 39 88 53 4F 46 54 57 41 52 45
        dh      "00"                                           ;#4FE6: 00

TITLE_SCREEN_PATTERN_DATA:
        ; Tile-pattern data for the title screen (3-banks via LOAD_PATTERN_TO_VRAM)
        dh      "0F000101060082FFFE080F84C3C7CFDF"             ;#4FE7: 0F 00 01 01 06 00 82 FF FE 08 0F 84 C3 C7 CF DF
        dh      "03FF89FEFCF8F0E0C080070705008303"             ;#4FF7: 03 FF 89 FE FC F8 F0 E0 C0 80 07 07 05 00 83 03
        dh      "CFDF050083E1F97D050083EFFFF70500"             ;#5007: CF DF 05 00 83 E1 F9 7D 05 00 83 EF FF F7 05 00
        dh      "83078F9E050083F0F878050083F7FFFB"             ;#5017: 83 07 8F 9E 05 00 83 F0 F8 78 05 00 83 F7 FF FB
        dh      "05008B8FDFF70C1E1E0C001E9E9E080F"             ;#5027: 05 00 8B 8F DF F7 0C 1E 1E 0C 00 1E 9E 9E 08 0F
        dh      "90FFFFDFCFC7C3C1C00787C7EFFFFFFF"             ;#5037: 90 FF FF DF CF C7 C3 C1 C0 07 87 C7 EF FF FF FF
        dh      "FC04DE849E9F0F03053D837DF9E108E3"             ;#5047: FC 04 DE 84 9E 9F 0F 03 05 3D 83 7D F9 E1 08 E3
        dh      "90DCC0C7DEDCDECFC33C7CFC3C3C7CFC"             ;#5057: 90 DC C0 C7 DE DC DE CF C3 3C 7C FC 3C 3C 7C FC
        dh      "DE08F108E308DE883844BAAAB2AA4438"             ;#5067: DE 08 F1 08 E3 08 DE 88 38 44 BA AA B2 AA 44 38
        dh      "030001FF040000"                               ;#5077: 03 00 01 FF 04 00 00

SETUP_TITLE_PATTERN_REGION:
        ; Fill VRAM 2400/2420, load GFX_TITLE_BORDER_PATTERN+GFX_TITLE_LOGO_PATTERN
        LOAD_VRAM_ADDRESS hl, 2400h                            ;#507E: 21 00 24
        ld      bc,20h                                         ;#5081: 01 20 00
        ld      a,3Fh                                          ;#5084: 3E 3F
        call    FILVRM_3_BANKS                                 ;#5086: CD 3C 61
        LOAD_VRAM_ADDRESS hl, 2420h                            ;#5089: 21 20 24
        ld      bc,20h                                         ;#508C: 01 20 00
        ld      a,0FCh                                         ;#508F: 3E FC
        call    FILVRM_3_BANKS                                 ;#5091: CD 3C 61
        ld      hl,GFX_TITLE_BORDER_PATTERN                    ;#5094: 21 B5 50
        LOAD_VRAM_ADDRESS de, 400h                             ;#5097: 11 00 04
        call    LOAD_PATTERN_TO_VRAM_3_BANKS                   ;#509A: CD 63 61
        ld      hl,GFX_TITLE_LOGO_PATTERN                      ;#509D: 21 C6 50
        LOAD_VRAM_ADDRESS de, 2440h                            ;#50A0: 11 40 24
        ld      bc,30h                                         ;#50A3: 01 30 00
        call    LDIRVM_TO_3_BLOCKS                             ;#50A6: CD 4D 61
        LOAD_VRAM_ADDRESS hl, 440h                             ;#50A9: 21 40 04
        ld      bc,30h                                         ;#50AC: 01 30 00
        ld      a,0F0h                                         ;#50AF: 3E F0
        call    FILVRM_3_BANKS                                 ;#50B1: CD 3C 61
        ret                                                    ;#50B4: C9

GFX_TITLE_BORDER_PATTERN:
        ; 17-byte tile-pattern data for the title-screen border tiles
        dh      "08E0087A08DC084608EA087C08D60840"             ;#50B5: 08 E0 08 7A 08 DC 08 46 08 EA 08 7C 08 D6 08 40
        dh      "00"                                           ;#50C5: 00

GFX_TITLE_LOGO_PATTERN:
        ; 48-byte tile-pattern data for the title-screen logo glyphs
        dh      "38449AA29A443800076E7C79796F6700"             ;#50C6: 38 44 9A A2 9A 44 38 00 07 6E 7C 79 79 6F 67 00
        dh      "00001CB6B6B61C000000F1D8D9DBD900"             ;#50D6: 00 00 1C B6 B6 B6 1C 00 00 00 F1 D8 D9 DB D9 00
        dh      "0000CF6DED6DED000600E6B6B6B6B600"             ;#50E6: 00 00 CF 6D ED 6D ED 00 06 00 E6 B6 B6 B6 B6 00

FINALIZE_TITLE_SCREEN:
        ; Last stage of INIT_TITLE_SCREEN: load menu font + fill helper masks
        ld      hl,GFX_MENU_FONT_PATTERNS                      ;#50F6: 21 13 51
        LOAD_VRAM_ADDRESS de, 2180h                            ;#50F9: 11 80 21
        call    LOAD_PATTERN_TO_VRAM_3_BANKS                   ;#50FC: CD 63 61
        ld      a,0F0h                                         ;#50FF: 3E F0
        LOAD_VRAM_ADDRESS hl, 180h                             ;#5101: 21 80 01
        ld      bc,158h                                        ;#5104: 01 58 01
        jp      FILVRM_3_BANKS                                 ;#5107: C3 3C 61

LOAD_TITLE_PATTERN_SET2:
        ; Load GFX_TITLE_PATTERN_SET2 into VRAM 0 via LOAD_PATTERN_TO_VRAM_3_BANKS
        ld      hl,GFX_TITLE_PATTERN_SET2                      ;#510A: 21 5B 52
        LOAD_VRAM_ADDRESS de, 0                                ;#510D: 11 00 00
        jp      LOAD_PATTERN_TO_VRAM_3_BANKS                   ;#5110: C3 63 61

GFX_MENU_FONT_PATTERNS:
        ; RLE pattern data: menu font tiles loaded at VRAM 3180h by SAVE_GAME_DISPLAY
        dh      "8B001C22636363221C0018380418F17E"             ;#5113: 8B 00 1C 22 63 63 63 22 1C 00 18 38 04 18 F1 7E
        dh      "003E63030E3C707F003E63030E03633E"             ;#5123: 00 3E 63 03 0E 3C 70 7F 00 3E 63 03 0E 03 63 3E
        dh      "000E1E3666667F06007F607E6303633E"             ;#5133: 00 0E 1E 36 66 66 7F 06 00 7F 60 7E 63 03 63 3E
        dh      "003E63607E63633E007F63060C181818"             ;#5143: 00 3E 63 60 7E 63 63 3E 00 7F 63 06 0C 18 18 18
        dh      "003E63633E63633E003E63633F03633E"             ;#5153: 00 3E 63 63 3E 63 63 3E 00 3E 63 63 3F 03 63 3E

GFX_MENU_FONT_TILES:
        ; 8-byte font-tile patch loaded by PATCH_MENU_FONT_TILES per GAME_DISPLAY_ACTIVE
        dh      "001018FCFEFC1810"                             ;#5163: 00 10 18 FC FE FC 18 10
        dh      "00000C0C00000C0C0000000000000C0C"             ;#516B: 00 00 0C 0C 00 00 0C 0C 00 00 00 00 00 00 0C 0C
        dh      "003636360000000000007E00007E0000"             ;#517B: 00 36 36 36 00 00 00 00 00 00 7E 00 00 7E 00 00
        dh      "001C22220C0800080400017E0400C11C"             ;#518B: 00 1C 22 22 0C 08 00 08 04 00 01 7E 04 00 C1 1C
        dh      "3663637F6363007E63637E63637E003E"             ;#519B: 36 63 63 7F 63 63 00 7E 63 63 7E 63 63 7E 00 3E
        dh      "63606060633E007C66636363667C007F"             ;#51AB: 63 60 60 60 63 3E 00 7C 66 63 63 63 66 7C 00 7F
        dh      "60607E60607F007F60607E606060003E"             ;#51BB: 60 60 7E 60 60 7F 00 7F 60 60 7E 60 60 60 00 3E
        dh      "63606763633F006363637F636363003C"             ;#51CB: 63 60 67 63 63 3F 00 63 63 63 7F 63 63 63 00 3C
        dh      "0518833C001F04068B663C0063666C78"             ;#51DB: 05 18 83 3C 00 1F 04 06 8B 66 3C 00 63 66 6C 78
        dh      "7C6E67000660937F0063777F7F6B6363"             ;#51EB: 7C 6E 67 00 06 60 93 7F 00 63 77 7F 7F 6B 63 63
        dh      "0063737B7F6F6763003E0563A33E007E"             ;#51FB: 00 63 73 7B 7F 6F 67 63 00 3E 05 63 A3 3E 00 7E
        dh      "6363637E6060003E6363636F663D007E"             ;#520B: 63 63 63 7E 60 60 00 3E 63 63 63 6F 66 3D 00 7E
        dh      "6363627C6663003E63603E03633E007E"             ;#521B: 63 63 62 7C 66 63 00 3E 63 60 3E 03 63 3E 00 7E
        dh      "061801000663823E000463A3361C0800"             ;#522B: 06 18 01 00 06 63 82 3E 00 04 63 A3 36 1C 08 00
        dh      "63636B6B7F77220063763C1C1E376300"             ;#523B: 63 63 6B 6B 7F 77 22 00 63 76 3C 1C 1E 37 63 00
        dh      "66667E3C181818007F070E1C38707F00"             ;#524B: 66 66 7E 3C 18 18 18 00 7F 07 0E 1C 38 70 7F 00

GFX_TITLE_PATTERN_SET2:
        ; Second RLE pattern stream loaded by LOAD_TITLE_PATTERN_SET2 (3-banks)
        dh      "08000811082208330844085508660877"             ;#525B: 08 00 08 11 08 22 08 33 08 44 08 55 08 66 08 77
        dh      "0888089908AA08BB08CC08DD08EE08FF"             ;#526B: 08 88 08 99 08 AA 08 BB 08 CC 08 DD 08 EE 08 FF
        dh      "00"                                           ;#527B: 00

MENU_SELECT_RICH:
        ; Like MENU_SELECT but takes BC + DE state — used by the top-level menu
        dec     a                                              ;#527C: 3D
        ld      (MENU_MAX_INDEX),a                             ;#527D: 32 64 D1
        ld      (NAME_INPUT_BUFFER),bc                         ;#5280: ED 43 42 D1
        ld      (MENU_TABLE_PTR),hl                            ;#5284: 22 6A D1
        ld      (MENU_CURSOR_VRAM_ADDR),de                     ;#5287: ED 53 68 D1
        call    RESET_MENU_STATE                               ;#528B: CD 42 53
MENU_SELECT_RICH_KEYLOOP:
        ; Inner key-poll loop entry: BIOS_CHSNS/CHGET, navigate cursor, dispatch on select
        call    BIOS_CHSNS                                     ;#528E: CD 9C 00
        jr      z,MENU_SELECT_RICH_TICK_BUMP                   ;#5291: 28 1D
        call    BIOS_CHGET                                     ;#5293: CD 9F 00
        cp      CHAR_SPACE                                     ;#5296: FE 20
        ld      b,a                                            ;#5298: 47
        jr      nz,MENU_SELECT_RICH_KEY_DECODE                 ;#5299: 20 08
        ld      a,(MENU_CURRENT_INDEX)                         ;#529B: 3A 65 D1
        ld      (MENU_SELECTED_INDEX),a                        ;#529E: 32 63 D1
        or      a                                              ;#52A1: B7
        ret                                                    ;#52A2: C9

MENU_SELECT_RICH_KEY_DECODE:
        ; Inner branch after CHGET: A=key, C=FFh mask; dispatch on cursor keys
        ld      c,0FFh                                         ;#52A3: 0E FF
        cp      CHAR_KEY_UP                                    ;#52A5: FE 1E
        jr      z,MENU_SELECT_RICH_NEXT_INDEX                  ;#52A7: 28 28
        ld      c,1                                            ;#52A9: 0E 01
        cp      CHAR_KEY_DOWN                                  ;#52AB: FE 1F
        jp      z,MENU_SELECT_RICH_NEXT_INDEX                  ;#52AD: CA D1 52
MENU_SELECT_RICH_TICK_BUMP:
        ; Idle-tick path: increment MENU_RICH_BLINK_COUNTER counter and redraw blink tile
        ld      bc,(MENU_RICH_BLINK_COUNTER)                   ;#52B0: ED 4B 47 D1
        inc     bc                                             ;#52B4: 03
        ld      (MENU_RICH_BLINK_COUNTER),bc                   ;#52B5: ED 43 47 D1
        ld      a,b                                            ;#52B9: 78
        and     7Fh                                            ;#52BA: E6 7F
        or      c                                              ;#52BC: B1
        jr      nz,MENU_SELECT_RICH_KEYLOOP                    ;#52BD: 20 CF
        LOAD_NAME_TABLE hl, 13, 9                              ;#52BF: 21 A9 39
        ld      a,0ACh                                         ;#52C2: 3E AC
        bit     7,b                                            ;#52C4: CB 78
        jr      nz,MENU_SELECT_RICH_TICK_WRITE                 ;#52C6: 20 04
        ld      a,0F5h                                         ;#52C8: 3E F5
        ld      b,7Fh                                          ;#52CA: 06 7F
MENU_SELECT_RICH_TICK_WRITE:
        ; Write the blink tile (B=7Fh) at the current cursor VRAM
        call    BIOS_WRTVRM                                    ;#52CC: CD 4D 00
        ld      c,0                                            ;#52CF: 0E 00
MENU_SELECT_RICH_NEXT_INDEX:
        ; Down-arrow path: inc MENU_RICH_BLINK_STATE cursor, clamp to MENU_MAX_INDEX
        ld      hl,MENU_RICH_BLINK_STATE                       ;#52D1: 21 44 D1
        inc     (hl)                                           ;#52D4: 34
        ld      hl,MENU_MAX_INDEX                              ;#52D5: 21 64 D1
        ld      de,MENU_CURRENT_INDEX                          ;#52D8: 11 65 D1
        ld      a,(de)                                         ;#52DB: 1A
        add     a,c                                            ;#52DC: 81
        jp      p,MENU_SELECT_RICH_BOUND_CHECK                 ;#52DD: F2 E1 52
        ld      a,(hl)                                         ;#52E0: 7E
MENU_SELECT_RICH_BOUND_CHECK:
        ; Compare new cursor against MENU_MAX_INDEX; on overflow wrap to 0
        cp      (hl)                                           ;#52E1: BE
        jr      c,MENU_SELECT_RICH_INDEX_RESET                 ;#52E2: 38 03
        jr      z,MENU_SELECT_RICH_INDEX_RESET                 ;#52E4: 28 01
        xor     a                                              ;#52E6: AF
MENU_SELECT_RICH_INDEX_RESET:
        ; Wrap-around: reset cursor to 0 and load next position
        ld      (de),a                                         ;#52E7: 12
        ld      b,a                                            ;#52E8: 47
        ld      hl,(MENU_TABLE_PTR)                            ;#52E9: 2A 6A D1
        add     a,a                                            ;#52EC: 87
        call    ADD_A_TO_HL                                    ;#52ED: CD ED 60
        ld      a,(hl)                                         ;#52F0: 7E
        inc     hl                                             ;#52F1: 23
        ld      h,(hl)                                         ;#52F2: 66
        ld      l,a                                            ;#52F3: 6F
        ld      de,(MENU_CURSOR_VRAM_ADDR)                     ;#52F4: ED 5B 68 D1
        ld      bc,(NAME_INPUT_BUFFER)                         ;#52F8: ED 4B 42 D1
        call    LDIRVM_TEXT_GRID                               ;#52FC: CD B6 76
        LOAD_NAME_TABLE de, 24, 8                              ;#52FF: 11 08 3B
        ld      a,(MENU_RICH_BLINK_STATE)                      ;#5302: 3A 44 D1
        rra                                                    ;#5305: 1F
        ld      hl,GFX_PRINTER_SCREEN_TAIL_B                   ;#5306: 21 E4 77
        jr      nc,ON_GAME_STATE_LOAD_TAIL_VRAM                ;#5309: 30 03
        ld      hl,GFX_PRINTER_SCREEN_TAIL                     ;#530B: 21 F4 77
ON_GAME_STATE_LOAD_TAIL_VRAM:
        ; Save AF and LDIRVM 10h bytes from GFX_PRINTER_SCREEN_TAIL_x
        push    af                                             ;#530E: F5
        ld      bc,10h                                         ;#530F: 01 10 00
        call    BIOS_LDIRVM                                    ;#5312: CD 5C 00
        pop     af                                             ;#5315: F1
        ld      hl,GFX_PRINTER_TITLE_GRID_A                    ;#5316: 21 2A 53
        jr      nc,ON_GAME_STATE_DRAW_GRID                     ;#5319: 30 03
        ld      hl,GFX_PRINTER_TITLE_GRID_B                    ;#531B: 21 36 53
ON_GAME_STATE_DRAW_GRID:
        ; LDIRVM_TEXT_GRID 4×3 from GFX_PRINTER_TITLE_GRID_x at VRAM 3A05h
        LOAD_NAME_TABLE de, 16, 5                              ;#531E: 11 05 3A
        ld      bc,403h                                        ;#5321: 01 03 04
        call    LDIRVM_TEXT_GRID                               ;#5324: CD B6 76
        jp      MENU_SELECT_RICH_KEYLOOP                       ;#5327: C3 8E 52

GFX_PRINTER_TITLE_GRID_A:
        ; 12-byte tile grid at VRAM 3A05h (3×4) when MENU_RICH_BLINK_STATE bit-0 clear
        dh      "00BFC0C3C4C5CFD0D1DADBDB"                     ;#532A: 00 BF C0 C3 C4 C5 CF D0 D1 DA DB DB

GFX_PRINTER_TITLE_GRID_B:
        ; 12-byte tile grid at VRAM 3A05h (3×4) when MENU_RICH_BLINK_STATE bit-0 set
        dh      "00EFC000F0F1F2F3F4DADBDB"                     ;#5336: 00 EF C0 00 F0 F1 F2 F3 F4 DA DB DB

RESET_MENU_STATE:
        ; BIOS_KILBUF + zero MENU_SELECTED/CURRENT_INDEX + NAME_INPUT_DECIMAL_FLAG
        call    BIOS_KILBUF                                    ;#5342: CD 56 01
        xor     a                                              ;#5345: AF
        ld      (MENU_SELECTED_INDEX),a                        ;#5346: 32 63 D1
        ld      (MENU_CURRENT_INDEX),a                         ;#5349: 32 65 D1
        ld      (NAME_INPUT_DECIMAL_FLAG),a                    ;#534C: 32 66 D1
        ret                                                    ;#534F: C9

ON_GAME_STATE_TRANSITION:
        ; ISR-CALSLT callback when GAME_RAM_TRIGGER_PTR hits the trigger
        ld      a,(MODIFY_FLAGS)                               ;#5350: 3A 17 D3
        ld      b,a                                            ;#5353: 47
        bit     0,b                                            ;#5354: CB 40
        call    nz,CHEAT_LIVES_DISPATCH_ENTRY                  ;#5356: C4 BA 53
        bit     1,b                                            ;#5359: CB 48
        call    nz,CHEAT_STAGE_DISPATCH_ENTRY                  ;#535B: C4 CB 53
        bit     2,b                                            ;#535E: CB 50
        call    nz,INVOKE_GAME_CHEAT_CALLBACK                  ;#5360: C4 E0 53
        ld      a,b                                            ;#5363: 78
        and     0F8h                                           ;#5364: E6 F8
        ld      d,a                                            ;#5366: 57
        call    CHECK_RANKING_AVAILABLE                        ;#5367: CD A8 54
        jr      z,ON_GAME_STATE_STORE_FLAGS                    ;#536A: 28 10
        ld      a,(GAME_ID)                                    ;#536C: 3A 01 D3
        cp      15h                                            ;#536F: FE 15
        jr      z,ON_GAME_STATE_STORE_FLAGS                    ;#5371: 28 09
        ld      hl,DISK_BASIC_CALSLT_PAIR                      ;#5373: 21 3A D3
        inc     (hl)                                           ;#5376: 34
        bit     1,(hl)                                         ;#5377: CB 4E
        jr      nz,ON_GAME_STATE_STORE_FLAGS                   ;#5379: 20 01
        ld      d,b                                            ;#537B: 50
ON_GAME_STATE_STORE_FLAGS:
        ; Store D (new MODIFY_FLAGS) back; check bit 7 for ranking insert
        ld      hl,MODIFY_FLAGS                                ;#537C: 21 17 D3
        ld      (hl),d                                         ;#537F: 72
        bit     7,d                                            ;#5380: CB 7A
        ret     z                                              ;#5382: C8
        res     7,(hl)                                         ;#5383: CB BE
        ld      a,0FFh                                         ;#5385: 3E FF
        ld      (IN_ISR_LOCK),a                                ;#5387: 32 3B D1
        ld      hl,RANKING_NAME_INPUT_1P                       ;#538A: 21 22 D3
        ld      de,RANKING_NAME_INPUT_1P+1                     ;#538D: 11 23 D3
        ld      (hl),3Ch                                       ;#5390: 36 3C
        ld      bc,0Fh                                         ;#5392: 01 0F 00
        ldir                                                   ;#5395: ED B0
        ld      hl,RANKING_INPUT_BUFFER_1P                     ;#5397: 21 1C D3
        ld      de,RANKING_INPUT_BUFFER_1P+1                   ;#539A: 11 1D D3
        ld      (hl),0                                         ;#539D: 36 00
        ld      bc,5                                           ;#539F: 01 05 00
        ldir                                                   ;#53A2: ED B0
        call    MUTE_ALL_PSG_CHANNELS                          ;#53A4: CD 91 4D
        call    SAVE_GAME_DISPLAY                              ;#53A7: CD F3 61
        call    DRAW_RANKING_DISPLAY                           ;#53AA: CD 11 54
        call    RESTORE_GAME_DISPLAY                           ;#53AD: CD 68 62
        xor     a                                              ;#53B0: AF
        ld      (IN_ISR_LOCK),a                                ;#53B1: 32 3B D1
        ld      a,0FFh                                         ;#53B4: 3E FF
        ld      (RANKING_AVAILABLE_FLAG),a                     ;#53B6: 32 32 D3
        ret                                                    ;#53B9: C9

CHEAT_LIVES_DISPATCH_ENTRY:
        ; Apply LIVES cheat: per-game via LIVES_CHEAT_DISPATCH_TABLE, else default
        ld      a,(GAME_STAGE_CHEAT_FLAG)                      ;#53BA: 3A 02 D3
        inc     a                                              ;#53BD: 3C
        jr      z,CHEAT_LIVES_APPLY_DEFAULT                    ;#53BE: 28 05
        ld      hl,LIVES_CHEAT_DISPATCH_TABLE                  ;#53C0: 21 50 59
        jr      STAGE_DISPATCH_PRESERVE_BC                     ;#53C3: 18 0F

CHEAT_LIVES_APPLY_DEFAULT:
        ; No per-game LIVES cheat: call CHEAT_LIVES_STORE_HEX (preserve BC)
        push    bc                                             ;#53C5: C5
        call    CHEAT_LIVES_STORE_HEX                          ;#53C6: CD D9 59
        pop     bc                                             ;#53C9: C1
        ret                                                    ;#53CA: C9

CHEAT_STAGE_DISPATCH_ENTRY:
        ; Apply STAGE cheat: per-game via STAGE_CHEAT_DISPATCH_TABLE, else generic
        ld      a,(GAME_STAGE_CHEAT_FLAG)                      ;#53CB: 3A 02 D3
        inc     a                                              ;#53CE: 3C
        jr      z,CHEAT_STAGE_APPLY_GENERIC                    ;#53CF: 28 09
        ld      hl,STAGE_CHEAT_DISPATCH_TABLE                  ;#53D1: 21 81 59
STAGE_DISPATCH_PRESERVE_BC:
        ; push bc; call DISPATCH_BY_GAME_ID_JP; pop bc; ret (LIVES/STAGE wrapper)
        push    bc                                             ;#53D4: C5
        call    DISPATCH_BY_GAME_ID_JP                         ;#53D5: CD EE 53
        pop     bc                                             ;#53D8: C1
        ret                                                    ;#53D9: C9

CHEAT_STAGE_APPLY_GENERIC:
        ; No per-game STAGE cheat: call CHEAT_STAGE_GENERIC (preserve BC)
        push    bc                                             ;#53DA: C5
        call    CHEAT_STAGE_GENERIC                            ;#53DB: CD EB 59
        pop     bc                                             ;#53DE: C1
        ret                                                    ;#53DF: C9

INVOKE_GAME_CHEAT_CALLBACK:
        ; CALSLT into the per-game callback at GAME_CHEAT_CALLBACK_PTR, IY=OWN_SLOT_RAW
        push    bc                                             ;#53E0: C5
        ld      ix,(GAME_CHEAT_CALLBACK_PTR)                   ;#53E1: DD 2A 14 D3
        ld      iy,(OWN_SLOT_RAW)                              ;#53E5: FD 2A 2E D1
        call    BIOS_CALSLT                                    ;#53E9: CD 1C 00
        pop     bc                                             ;#53EC: C1
        ret                                                    ;#53ED: C9

DISPATCH_BY_GAME_ID_JP:
        ; Walk 3-byte-stride table at HL; jp through entry on D301 match
        ld      a,(hl)                                         ;#53EE: 7E
        inc     a                                              ;#53EF: 3C
        ret     z                                              ;#53F0: C8
        ld      a,(GAME_ID)                                    ;#53F1: 3A 01 D3
        cp      (hl)                                           ;#53F4: BE
        inc     hl                                             ;#53F5: 23
        jr      z,DISPATCH_BY_GAME_ID_FOUND                    ;#53F6: 28 04
        inc     hl                                             ;#53F8: 23
        inc     hl                                             ;#53F9: 23
        jr      DISPATCH_BY_GAME_ID_JP                         ;#53FA: 18 F2

DISPATCH_BY_GAME_ID_FOUND:
        ; Match: read 2-byte handler word at HL, ex de,hl; jp (hl)
        ld      e,(hl)                                         ;#53FC: 5E
        inc     hl                                             ;#53FD: 23
        ld      d,(hl)                                         ;#53FE: 56
        ex      de,hl                                          ;#53FF: EB
        jp      (hl)                                           ;#5400: E9

DISPATCH_BY_GAME_ID_Z:
        ; Same scan as DISPATCH_BY_GAME_ID_JP; returns Z on match (no jp)
        ld      a,(hl)                                         ;#5401: 7E
        inc     a                                              ;#5402: 3C
        jr      z,DISPATCH_BY_GAME_ID_Z_DONE                   ;#5403: 28 0A
        ld      a,(GAME_ID)                                    ;#5405: 3A 01 D3
        cp      (hl)                                           ;#5408: BE
        ret     z                                              ;#5409: C8
        inc     hl                                             ;#540A: 23
        inc     hl                                             ;#540B: 23
        inc     hl                                             ;#540C: 23
        jr      DISPATCH_BY_GAME_ID_Z                          ;#540D: 18 F2

DISPATCH_BY_GAME_ID_Z_DONE:
        ; Match: inc A so or A clears Z; ret with Z reset (caller sees NZ)
        inc     a                                              ;#540F: 3C
        ret                                                    ;#5410: C9

DRAW_RANKING_DISPLAY:
        ; RANKING DISPLAY screen: clear name area, render TXT_RANKING_DISPLAY, fill scores
        LOAD_NAME_TABLE hl, 20, 12                             ;#5411: 21 8C 3A
        ld      bc,312h                                        ;#5414: 01 12 03
        xor     a                                              ;#5417: AF
        call    FILVRM_RANGE                                   ;#5418: CD AA 61
        ld      hl,TXT_RANKING_DISPLAY                         ;#541B: 21 1F 55
        call    DRAW_TEXT_STREAM                               ;#541E: CD 13 61
        call    DRAW_RANKING_NAMES                             ;#5421: CD ED 54
        LOAD_NAME_TABLE hl, 22, 12                             ;#5424: 21 CC 3A
        call    INPUT_PLAYER_NAME_ENTRY                        ;#5427: CD 9A 54
        jr      z,DRAW_RANKING_DISPLAY_2P                      ;#542A: 28 19
        ld      hl,NAME_INPUT_BUFFER                           ;#542C: 21 42 D1
        ld      de,RANKING_NAME_INPUT_1P                       ;#542F: 11 22 D3
        ld      bc,8                                           ;#5432: 01 08 00
        ldir                                                   ;#5435: ED B0
        ld      hl,RANKING_INPUT_BUFFER_1P                     ;#5437: 21 1C D3
        call    ZERO_3_BYTES_AT_HL                             ;#543A: CD A1 54
        ld      a,31h                                          ;#543D: 3E 31
        call    PURGE_RANKING_BY_TAG                           ;#543F: CD D9 54
        call    DRAW_RANKING_NAMES                             ;#5442: CD ED 54
DRAW_RANKING_DISPLAY_2P:
        ; Continuation when ranking has 2P entries: prompt for 2P name + verify menu
        call    CHECK_RANKING_AVAILABLE                        ;#5445: CD A8 54
        jr      z,DRAW_RANKING_DISPLAY_DONE                    ;#5448: 28 30
        ld      hl,TXT_RANKING_DISPLAY_2P                      ;#544A: 21 39 55
        call    DRAW_TEXT_STREAM                               ;#544D: CD 13 61
        LOAD_NAME_TABLE hl, 22, 12                             ;#5450: 21 CC 3A
        push    hl                                             ;#5453: E5
        ld      bc,0Ah                                         ;#5454: 01 0A 00
        xor     a                                              ;#5457: AF
        call    BIOS_FILVRM                                    ;#5458: CD 56 00
        pop     hl                                             ;#545B: E1
        call    INPUT_PLAYER_NAME_ENTRY                        ;#545C: CD 9A 54
        jr      z,DRAW_RANKING_DISPLAY_DONE                    ;#545F: 28 19
        ld      hl,NAME_INPUT_BUFFER                           ;#5461: 21 42 D1
        ld      de,RANKING_NAME_INPUT_2P                       ;#5464: 11 2A D3
        ld      bc,8                                           ;#5467: 01 08 00
        ldir                                                   ;#546A: ED B0
        ld      hl,RANKING_INPUT_BUFFER_2P                     ;#546C: 21 1F D3
        call    ZERO_3_BYTES_AT_HL                             ;#546F: CD A1 54
        ld      a,32h                                          ;#5472: 3E 32
        call    PURGE_RANKING_BY_TAG                           ;#5474: CD D9 54
        call    DRAW_RANKING_NAMES                             ;#5477: CD ED 54
DRAW_RANKING_DISPLAY_DONE:
        ; Common tail: fill the name input area on screen, then return
        LOAD_NAME_TABLE hl, 20, 12                             ;#547A: 21 8C 3A
        ld      bc,312h                                        ;#547D: 01 12 03
        xor     a                                              ;#5480: AF
        call    FILVRM_RANGE                                   ;#5481: CD AA 61
        ld      hl,TXT_RANKING_NAME_VERIFY                     ;#5484: 21 63 55
        call    DRAW_TEXT_STREAM                               ;#5487: CD 13 61
        ld      hl,RANKING_VERIFY_POSITIONS                    ;#548A: 21 70 55
        ld      b,2                                            ;#548D: 06 02
        call    MENU_SELECT                                    ;#548F: CD 00 64
        call    CALL_INDIRECT_A                                ;#5492: CD E7 61
RANKING_VERIFY_HANDLERS:
        ; 2-word handler table consumed inline by CALL_INDIRECT_A at 5492h
        dw      RANKING_VERIFY_OK_RET                          ;#5495: 99 54
        dw      DRAW_RANKING_DISPLAY                           ;#5497: 11 54

RANKING_VERIFY_OK_RET:
        ; 1-byte inline RET reached by RANKING_VERIFY_HANDLERS entry 0 (OK)
        ret                                                    ;#5499: C9

INPUT_PLAYER_NAME_ENTRY:
        ; Configure A=FEh, B=8 max chars, then jp RUN_NAME_INPUT_LOOP
        ld      a,0FEh                                         ;#549A: 3E FE
        ld      b,8                                            ;#549C: 06 08
        jp      RUN_NAME_INPUT_LOOP                            ;#549E: C3 D8 62

ZERO_3_BYTES_AT_HL:
        ; Write three zeros at (HL), HL += 3; ret (clears a 3-byte score field)
        xor     a                                              ;#54A1: AF
        ld      (hl),a                                         ;#54A2: 77
        inc     hl                                             ;#54A3: 23
        ld      (hl),a                                         ;#54A4: 77
        inc     hl                                             ;#54A5: 23
        ld      (hl),a                                         ;#54A6: 77
        ret                                                    ;#54A7: C9

CHECK_RANKING_AVAILABLE:
        ; NZ when SCORE_2P_PTR and RANKING_PTR set and per-game ranking byte ok
        ld      hl,(GAME_RAM_SCORE_2P_PTR)                     ;#54A8: 2A 10 D3
        ld      a,h                                            ;#54AB: 7C
        or      l                                              ;#54AC: B5
        ret     z                                              ;#54AD: C8
        ld      hl,(GAME_RAM_RANKING_PTR)                      ;#54AE: 2A 06 D3
        ld      a,h                                            ;#54B1: 7C
        or      l                                              ;#54B2: B5
        ret     z                                              ;#54B3: C8
        ld      a,(GAME_ID)                                    ;#54B4: 3A 01 D3
        ld      c,a                                            ;#54B7: 4F
        sub     3                                              ;#54B8: D6 03
        cp      2                                              ;#54BA: FE 02
        jr      c,CHECK_RANKING_AVAILABLE_BIT0                 ;#54BC: 38 10
        ld      a,c                                            ;#54BE: 79
        sub     10h                                            ;#54BF: D6 10
        cp      2                                              ;#54C1: FE 02
        jr      nc,CHECK_RANKING_AVAILABLE_BIT5                ;#54C3: 30 05
        ld      a,(hl)                                         ;#54C5: 7E
        cpl                                                    ;#54C6: 2F
        and     1                                              ;#54C7: E6 01
        ret                                                    ;#54C9: C9

CHECK_RANKING_AVAILABLE_BIT5:
        ; Subgroup test: returns bit 5 of game-specific RAM byte
        ld      a,(hl)                                         ;#54CA: 7E
        bit     5,a                                            ;#54CB: CB 6F
        ret                                                    ;#54CD: C9

CHECK_RANKING_AVAILABLE_BIT0:
        ; Subgroup test: returns bit 0 of game-specific RAM byte
        ld      a,(hl)                                         ;#54CE: 7E
        and     1                                              ;#54CF: E6 01
        ret                                                    ;#54D1: C9

PURGE_RANKING_BOTH:
        ; Clear ranking-table entries tagged '1' or '2' that match the current score
        ld      a,31h                                          ;#54D2: 3E 31
        call    PURGE_RANKING_BY_TAG                           ;#54D4: CD D9 54
        ld      a,32h                                          ;#54D7: 3E 32
PURGE_RANKING_BY_TAG:
        ; Walk RANKING_NAME_BLOCK (10×9); zero the tag byte if it matches A
        ld      hl,RANKING_NAME_BLOCK                          ;#54D9: 21 77 D4
        ld      b,0Ah                                          ;#54DC: 06 0A
        ld      c,a                                            ;#54DE: 4F
PURGE_RANKING_LOOP:
        ; Per-entry body: compare A with (HL); on match zero the slot
        ld      a,c                                            ;#54DF: 79
        cp      (hl)                                           ;#54E0: BE
        jr      nz,PURGE_RANKING_NEXT                          ;#54E1: 20 02
        ld      (hl),0                                         ;#54E3: 36 00
PURGE_RANKING_NEXT:
        ; Advance HL by 9 to next 9-byte name slot; djnz
        ld      a,9                                            ;#54E5: 3E 09
        call    ADD_A_TO_HL                                    ;#54E7: CD ED 60
        djnz    PURGE_RANKING_LOOP                             ;#54EA: 10 F3
        ret                                                    ;#54EC: C9

DRAW_RANKING_NAMES:
        ; Render "1P NAME>" + RANKING_NAME_INPUT_1P and "2P NAME>" + RANKING_NAME_INPUT_2P
        LOAD_NAME_TABLE hl, 17, 12                             ;#54ED: 21 2C 3A
        ld      bc,212h                                        ;#54F0: 01 12 02
        xor     a                                              ;#54F3: AF
        call    FILVRM_RANGE                                   ;#54F4: CD AA 61
        ld      hl,TXT_RANKING_LABEL_1                         ;#54F7: 21 49 55
        call    DRAW_TEXT_STREAM                               ;#54FA: CD 13 61
        ld      hl,RANKING_NAME_INPUT_1P                       ;#54FD: 21 22 D3
        LOAD_NAME_TABLE de, 17, 22                             ;#5500: 11 36 3A
        ld      bc,8                                           ;#5503: 01 08 00
        call    BIOS_LDIRVM                                    ;#5506: CD 5C 00
        call    CHECK_RANKING_AVAILABLE                        ;#5509: CD A8 54
        ret     z                                              ;#550C: C8
        ld      hl,TXT_RANKING_LABEL_2                         ;#550D: 21 56 55
        call    DRAW_TEXT_STREAM                               ;#5510: CD 13 61
        ld      hl,RANKING_NAME_INPUT_2P                       ;#5513: 21 2A D3
        LOAD_NAME_TABLE de, 18, 22                             ;#5516: 11 56 3A
        ld      bc,8                                           ;#5519: 01 08 00
        jp      BIOS_LDIRVM                                    ;#551C: C3 5C 00

TXT_RANKING_DISPLAY:
        ; Encoded text stream for the RANKING DISPLAY screen header and labels
        NAME_TABLE 17, 1                                       ;#551F: 21 3A
        db      "RANKING"                                      ;#5521: 52 41 4E 4B 49 4E 47
        TEXT_SEPARATOR                                         ;#5528: FE
        NAME_TABLE 20, 12                                      ;#5529: 8C 3A
        db      "INPUT", 0, "1P", 0, "NAME"                    ;#552B: 49 4E 50 55 54 00 31 50 00 4E 41 4D 45
        TEXT_TERMINATOR                                        ;#5538: FF

TXT_RANKING_DISPLAY_2P:
        ; Sub-stream loaded by DRAW_RANKING_DISPLAY_2P: "INPUT 2P NAME" prompt
        NAME_TABLE 20, 12                                      ;#5539: 8C 3A
        db      "INPUT", 0, "2P", 0, "NAME"                    ;#553B: 49 4E 50 55 54 00 32 50 00 4E 41 4D 45
        TEXT_TERMINATOR                                        ;#5548: FF

TXT_RANKING_LABEL_1:
        ; Encoded text stream: VRAM target 3A2Ch + "1P NAME>"
        NAME_TABLE 17, 12                                      ;#5549: 2C 3A
        db      "1P", 0, "NAME", 0, ">", 0                     ;#554B: 31 50 00 4E 41 4D 45 00 3E 00
        TEXT_TERMINATOR                                        ;#5555: FF

TXT_RANKING_LABEL_2:
        ; Encoded text stream: VRAM target 3A4Ch + "2P NAME>"
        NAME_TABLE 18, 12                                      ;#5556: 4C 3A
        db      "2P", 0, "NAME", 0, ">", 0                     ;#5558: 32 50 00 4E 41 4D 45 00 3E 00
        TEXT_TERMINATOR                                        ;#5562: FF

TXT_RANKING_NAME_VERIFY:
        ; "OK / RETRY" text stream for the post-name-input verify menu
        NAME_TABLE 20, 12                                      ;#5563: 8C 3A
        db      "OK"                                           ;#5565: 4F 4B
        TEXT_SEPARATOR                                         ;#5567: FE
        NAME_TABLE 22, 12                                      ;#5568: CC 3A
        db      "RETRY"                                        ;#556A: 52 45 54 52 59
        TEXT_TERMINATOR                                        ;#556F: FF

RANKING_VERIFY_POSITIONS:
        ; 2 VRAM-row addresses (3A8B, 3ACB) for the OK/RETRY menu cursor
        NAME_TABLE 20, 11                                      ;#5570: 8B 3A
        NAME_TABLE 22, 11                                      ;#5572: CB 3A

RANKING_RECORD_BOTH:
        ; Record primary score (tag '1') then secondary (tag '2') into RANKING_NAME_BLOCK
        ld      hl,RANKING_INPUT_BUFFER_1P+2                   ;#5574: 21 1E D3
        ld      a,31h                                          ;#5577: 3E 31
        call    RANKING_RECORD_SCORE                           ;#5579: CD 85 55
        call    CHECK_RANKING_AVAILABLE                        ;#557C: CD A8 54
        ret     z                                              ;#557F: C8
        ld      hl,RANKING_INPUT_BUFFER_2P+2                   ;#5580: 21 21 D3
        ld      a,32h                                          ;#5583: 3E 32
RANKING_RECORD_SCORE:
        ; Walk RANKING_NAME_BLOCK (10×9 entries); insert HL→3-byte score with tag A
        ld      de,RANKING_NAME_BLOCK                          ;#5585: 11 77 D4
        ex      de,hl                                          ;#5588: EB
        ld      c,a                                            ;#5589: 4F
        ld      b,0Ah                                          ;#558A: 06 0A
RANKING_RECORD_SEARCH_LOOP:
        ; Per-entry tag-byte compare; on match break to shift/insert path
        ld      a,c                                            ;#558C: 79
        cp      (hl)                                           ;#558D: BE
        jr      z,RANKING_RECORD_NO_INSERT                     ;#558E: 28 0B
        ld      a,9                                            ;#5590: 3E 09
        call    ADD_A_TO_HL                                    ;#5592: CD ED 60
        djnz    RANKING_RECORD_SEARCH_LOOP                     ;#5595: 10 F5
        ld      b,9                                            ;#5597: 06 09
        jr      RANKING_INSERT_COMPARE_AND_SHIFT               ;#5599: 18 07

RANKING_RECORD_NO_INSERT:
        ; No matching tag found: B=9 (insert-at-end), jr to compare-and-shift
        ld      a,0Ah                                          ;#559B: 3E 0A
        sub     b                                              ;#559D: 90
        ld      b,a                                            ;#559E: 47
        jp      z,RANKING_INSERT_APPEND_ONLY                   ;#559F: CA D6 55
RANKING_INSERT_COMPARE_AND_SHIFT:
        ; Walk D45Bh score block backwards for 3 bytes; on > shift, on = continue
        ld      a,c                                            ;#55A2: 79
        ld      c,0                                            ;#55A3: 0E 00
        ld      hl,RANKING_SCORE_BLOCK+2                       ;#55A5: 21 5B D4
RANKING_INSERT_COMPARE_PUSH:
        ; Save AF/BC/HL/DE before the 3-byte compare loop
        push    af                                             ;#55A8: F5
        push    bc                                             ;#55A9: C5
        push    hl                                             ;#55AA: E5
        push    de                                             ;#55AB: D5
        ld      b,3                                            ;#55AC: 06 03
        ex      de,hl                                          ;#55AE: EB
RANKING_INSERT_COMPARE_LOOP:
        ; Inner 3-byte compare body: cp (HL); c=found, nz=no-match
        ld      a,(de)                                         ;#55AF: 1A
        cp      (hl)                                           ;#55B0: BE
        jr      c,RANKING_INSERT_FOUND                         ;#55B1: 38 06
        jr      nz,RANKING_INSERT_NO_MATCH                     ;#55B3: 20 11
        dec     de                                             ;#55B5: 1B
        dec     hl                                             ;#55B6: 2B
        djnz    RANKING_INSERT_COMPARE_LOOP                    ;#55B7: 10 F6
RANKING_INSERT_FOUND:
        ; New entry beats current: pop regs, shift table, write name
        pop     de                                             ;#55B9: D1
        pop     hl                                             ;#55BA: E1
        pop     bc                                             ;#55BB: C1
        pop     af                                             ;#55BC: F1
        call    RANKING_TABLE_SHIFT_BOTH                       ;#55BD: CD DB 55
        call    RANKING_RECORD_SCORE_AT_C                      ;#55C0: CD 20 56
        jp      RANKING_WRITE_NAME_AT_ROW                      ;#55C3: C3 41 56

RANKING_INSERT_NO_MATCH:
        ; Continue with next entry: pop regs, advance HL by 3, inc c
        pop     de                                             ;#55C6: D1
        pop     hl                                             ;#55C7: E1
        pop     bc                                             ;#55C8: C1
        pop     af                                             ;#55C9: F1
        inc     hl                                             ;#55CA: 23
        inc     hl                                             ;#55CB: 23
        inc     hl                                             ;#55CC: 23
        inc     c                                              ;#55CD: 0C
        djnz    RANKING_INSERT_COMPARE_PUSH                    ;#55CE: 10 D8
        call    RANKING_RECORD_SCORE_AT_C                      ;#55D0: CD 20 56
        jp      RANKING_WRITE_NAME_AT_ROW                      ;#55D3: C3 41 56

RANKING_INSERT_APPEND_ONLY:
        ; No shift needed (entry beats only the last one): build c, fall into write
        ld      a,c                                            ;#55D6: 79
        ld      c,b                                            ;#55D7: 48
        jp      RANKING_RECORD_SCORE_AT_C                      ;#55D8: C3 20 56

RANKING_TABLE_SHIFT_BOTH:
        ; Shift both halves (D458 scores + D476 names) of the ranking table by BC entries
        ld      ix,RANKING_SCORE_BLOCK-1                       ;#55DB: DD 21 58 D4
        ld      iy,RANKING_SCORE_BLOCK+2                       ;#55DF: FD 21 5B D4
        ld      d,0                                            ;#55E3: 16 00
        call    RANKING_TABLE_SHIFT_HALF                       ;#55E5: CD F2 55
        ld      ix,RANKING_NAME_BLOCK-1                        ;#55E8: DD 21 76 D4
        ld      iy,RANKING_NAME_BLOCK+8                        ;#55EC: FD 21 7F D4
        ld      d,1                                            ;#55F0: 16 01
RANKING_TABLE_SHIFT_HALF:
        ; Worker: shift one half using a 3-byte (D=0) or 9-byte (D=1) stride via lddr
        push    af                                             ;#55F2: F5
        push    bc                                             ;#55F3: C5
        ld      e,b                                            ;#55F4: 58
        ld      a,c                                            ;#55F5: 79
        add     a,b                                            ;#55F6: 80
        ld      b,a                                            ;#55F7: 47
        add     a,a                                            ;#55F8: 87
        add     a,b                                            ;#55F9: 80
        bit     0,d                                            ;#55FA: CB 42
        jr      z,RANKING_SHIFT_BC_DEST                        ;#55FC: 28 03
        ld      b,a                                            ;#55FE: 47
        add     a,a                                            ;#55FF: 87
        add     a,b                                            ;#5600: 80
RANKING_SHIFT_BC_DEST:
        ; Assemble BC = entry count × stride for the destination ranges (HL/IY)
        ld      c,a                                            ;#5601: 4F
        ld      b,0                                            ;#5602: 06 00
        add     ix,bc                                          ;#5604: DD 09
        add     iy,bc                                          ;#5606: FD 09
        ld      a,e                                            ;#5608: 7B
        add     a,a                                            ;#5609: 87
        add     a,e                                            ;#560A: 83
        bit     0,d                                            ;#560B: CB 42
        jr      z,RANKING_SHIFT_BC_SOURCE                      ;#560D: 28 03
        ld      b,a                                            ;#560F: 47
        add     a,a                                            ;#5610: 87
        add     a,b                                            ;#5611: 80
RANKING_SHIFT_BC_SOURCE:
        ; Assemble BC = entry count × stride for the source ranges
        ld      c,a                                            ;#5612: 4F
        ld      b,0                                            ;#5613: 06 00
        push    ix                                             ;#5615: DD E5
        pop     hl                                             ;#5617: E1
        push    iy                                             ;#5618: FD E5
        pop     de                                             ;#561A: D1
        lddr                                                   ;#561B: ED B8
        pop     bc                                             ;#561D: C1
        pop     af                                             ;#561E: F1
        ret                                                    ;#561F: C9

RANKING_RECORD_SCORE_AT_C:
        ; Copy 3-byte score at HL into RANKING_INPUT_BUFFER_1P/_2P by tag (A=31h/32h)
        push    af                                             ;#5620: F5
        push    bc                                             ;#5621: C5
        push    af                                             ;#5622: F5
        ld      a,c                                            ;#5623: 79
        ld      b,a                                            ;#5624: 47
        add     a,a                                            ;#5625: 87
        add     a,b                                            ;#5626: 80
        ld      hl,RANKING_SCORE_BLOCK                         ;#5627: 21 59 D4
        call    ADD_A_TO_HL                                    ;#562A: CD ED 60
        pop     af                                             ;#562D: F1
        ld      de,RANKING_INPUT_BUFFER_1P                     ;#562E: 11 1C D3
        cp      32h                                            ;#5631: FE 32
        jr      nz,RANKING_WRITE_2P_SCORE                      ;#5633: 20 03
        ld      de,RANKING_INPUT_BUFFER_2P                     ;#5635: 11 1F D3
RANKING_WRITE_2P_SCORE:
        ; Copy 1P RANKING_INPUT_BUFFER → table; then RANKING_INPUT_BUFFER_2P → next slot
        ex      de,hl                                          ;#5638: EB
        ld      bc,3                                           ;#5639: 01 03 00
        ldir                                                   ;#563C: ED B0
        pop     bc                                             ;#563E: C1
        pop     af                                             ;#563F: F1
        ret                                                    ;#5640: C9

RANKING_WRITE_NAME_AT_ROW:
        ; Write 1P/2P name (per tag) into RANKING_NAME_BLOCK + row*9 slot
        push    af                                             ;#5641: F5
        push    bc                                             ;#5642: C5
        push    af                                             ;#5643: F5
        ld      a,c                                            ;#5644: 79
        ld      b,a                                            ;#5645: 47
        add     a,a                                            ;#5646: 87
        add     a,b                                            ;#5647: 80
        ld      b,a                                            ;#5648: 47
        add     a,a                                            ;#5649: 87
        add     a,b                                            ;#564A: 80
        ld      hl,RANKING_NAME_BLOCK                          ;#564B: 21 77 D4
        call    ADD_A_TO_HL                                    ;#564E: CD ED 60
        pop     af                                             ;#5651: F1
        ld      de,RANKING_NAME_INPUT_1P                       ;#5652: 11 22 D3
        cp      32h                                            ;#5655: FE 32
        jr      nz,RANKING_WRITE_2P_NAME                       ;#5657: 20 03
        ld      de,RANKING_NAME_INPUT_2P                       ;#5659: 11 2A D3
RANKING_WRITE_2P_NAME:
        ; Same shape for RANKING_NAME_INPUT_2P → 2P table slot
        ex      de,hl                                          ;#565C: EB
        ld      (de),a                                         ;#565D: 12
        inc     de                                             ;#565E: 13
        ld      bc,8                                           ;#565F: 01 08 00
        ldir                                                   ;#5662: ED B0
        pop     bc                                             ;#5664: C1
        pop     af                                             ;#5665: F1
        ret                                                    ;#5666: C9

VIEW_RANKING_TABLE:
        ; Clear VRAM, render the ranking table, run an interactive scroll loop
        LOAD_NAME_TABLE hl, 17, 9                              ;#5667: 21 29 3A
        ld      bc,616h                                        ;#566A: 01 16 06
        xor     a                                              ;#566D: AF
        call    FILVRM_RANGE                                   ;#566E: CD AA 61
        call    PATCH_MENU_FONT_TILES                          ;#5671: CD 73 64
        xor     a                                              ;#5674: AF
        ld      (MENU_SELECTED_INDEX),a                        ;#5675: 32 63 D1
        ld      (MENU_CURRENT_INDEX),a                         ;#5678: 32 65 D1
        LOAD_NAME_TABLE hl, 17, 9                              ;#567B: 21 29 3A
        ld      (MENU_TABLE_PTR),hl                            ;#567E: 22 6A D1
        inc     hl                                             ;#5681: 23
        ld      (MENU_CURSOR_VRAM_ADDR),hl                     ;#5682: 22 68 D1
        ld      a,0C0h                                         ;#5685: 3E C0
        ld      (MENU_MAX_INDEX),a                             ;#5687: 32 64 D1
        call    DRAW_MENU_CURSOR                               ;#568A: CD E8 63
VIEW_RANKING_REDRAW_LOOP:
        ; Main loop body: RENDER_RANKING_VISIBLE_ROWS, KILBUF, CHGET, decode arrow keys
        call    RENDER_RANKING_VISIBLE_ROWS                    ;#568D: CD F9 56
        call    BIOS_KILBUF                                    ;#5690: CD 56 01
VIEW_RANKING_POLL_KEY:
        ; Inner CHGET re-entry after ignored keys
        ld      hl,MENU_SELECTED_INDEX                         ;#5693: 21 63 D1
        ld      de,MENU_CURRENT_INDEX                          ;#5696: 11 65 D1
        call    BIOS_CHGET                                     ;#5699: CD 9F 00
        cp      CHAR_KEY_UP                                    ;#569C: FE 1E
        jr      z,VIEW_RANKING_UP_ARROW                        ;#569E: 28 43
        cp      CHAR_KEY_DOWN                                  ;#56A0: FE 1F
        jr      z,VIEW_RANKING_DOWN_ARROW                      ;#56A2: 28 05
        cp      CHAR_SPACE                                     ;#56A4: FE 20
        jr      nz,VIEW_RANKING_POLL_KEY                       ;#56A6: 20 EB
        ret                                                    ;#56A8: C9

VIEW_RANKING_DOWN_ARROW:
        ; Down-arrow path: bump current index, clamp at 9, compute step
        ld      a,9                                            ;#56A9: 3E 09
        cp      (hl)                                           ;#56AB: BE
        jr      z,VIEW_RANKING_POLL_KEY                        ;#56AC: 28 E5
        inc     (hl)                                           ;#56AE: 34
        ld      a,(de)                                         ;#56AF: 1A
        ld      b,a                                            ;#56B0: 47
        ld      a,(hl)                                         ;#56B1: 7E
        sub     b                                              ;#56B2: 90
        cp      5                                              ;#56B3: FE 05
        jr      c,VIEW_RANKING_DOWN_STEP_20                    ;#56B5: 38 08
        inc     b                                              ;#56B7: 04
        ld      a,b                                            ;#56B8: 78
        ld      (de),a                                         ;#56B9: 12
        ld      bc,0                                           ;#56BA: 01 00 00
        jr      VIEW_RANKING_BC_ADJUST                         ;#56BD: 18 03

VIEW_RANKING_DOWN_STEP_20:
        ; Full-row step (BC=20h) before falling into BC_ADJUST
        ld      bc,20h                                         ;#56BF: 01 20 00
VIEW_RANKING_BC_ADJUST:
        ; Adjust BC stride when current cell value is 9 (one short of a full 20h jump)
        ld      a,(hl)                                         ;#56C2: 7E
        cp      9                                              ;#56C3: FE 09
        jr      nz,VIEW_RANKING_MOVE_CURSOR                    ;#56C5: 20 01
        dec     bc                                             ;#56C7: 0B
VIEW_RANKING_MOVE_CURSOR:
        ; ERASE_MENU_CURSOR, add HL,BC, bounds-check via rst 20h, redraw cursor
        call    ERASE_MENU_CURSOR                              ;#56C8: CD F0 63
        add     hl,bc                                          ;#56CB: 09
        push    hl                                             ;#56CC: E5
        ld      de,(MENU_TABLE_PTR)                            ;#56CD: ED 5B 6A D1
        and     a                                              ;#56D1: A7
        sbc     hl,de                                          ;#56D2: ED 52
        ld      a,(MENU_MAX_INDEX)                             ;#56D4: 3A 64 D1
        ld      d,0                                            ;#56D7: 16 00
        ld      e,a                                            ;#56D9: 5F
        rst     20h                                            ;#56DA: E7
        pop     hl                                             ;#56DB: E1
        jr      nc,VIEW_RANKING_REDRAW                         ;#56DC: 30 03
        ld      (MENU_CURSOR_VRAM_ADDR),hl                     ;#56DE: 22 68 D1

VIEW_RANKING_REDRAW:
        ; After cursor moved successfully: store new addr, jr back to redraw loop
        jr      VIEW_RANKING_REDRAW_LOOP                       ;#56E1: 18 AA

VIEW_RANKING_UP_ARROW:
        ; Up-arrow path: read (hl), if 0 skip; else dec and compute backstep
        ld      a,(hl)                                         ;#56E3: 7E
        or      a                                              ;#56E4: B7
        jr      z,VIEW_RANKING_POLL_KEY                        ;#56E5: 28 AC
        dec     (hl)                                           ;#56E7: 35
        ex      de,hl                                          ;#56E8: EB
        ld      a,(de)                                         ;#56E9: 1A
        cp      (hl)                                           ;#56EA: BE
        jr      nc,VIEW_RANKING_UP_STEP_E0                     ;#56EB: 30 01
        dec     (hl)                                           ;#56ED: 35
VIEW_RANKING_UP_STEP_E0:
        ; Backstep BC=VRAM_ROW_BACK_STEP (one row up) before merging
        ld      bc,VRAM_ROW_BACK_STEP                          ;#56EE: 01 E0 FF
        ld      a,(de)                                         ;#56F1: 1A
        cp      8                                              ;#56F2: FE 08
        jr      nz,VIEW_RANKING_UP_MOVE                        ;#56F4: 20 01
        inc     bc                                             ;#56F6: 03
VIEW_RANKING_UP_MOVE:
        ; Up-arrow merge after backstep: jr back to MOVE_CURSOR with corrected BC
        jr      VIEW_RANKING_MOVE_CURSOR                       ;#56F7: 18 CF

RENDER_RANKING_VISIBLE_ROWS:
        ; Render the currently-visible 5 rows starting from MENU_CURRENT_INDEX
        ld      a,(MENU_CURRENT_INDEX)                         ;#56F9: 3A 65 D1
        call    GET_RANKING_NAME_PTR                           ;#56FC: CD CF 57
        push    hl                                             ;#56FF: E5
        pop     ix                                             ;#5700: DD E1
        ld      a,(MENU_CURRENT_INDEX)                         ;#5702: 3A 65 D1
        call    GET_RANKING_SCORE_PTR                          ;#5705: CD DD 57
        push    hl                                             ;#5708: E5
        pop     iy                                             ;#5709: FD E1
        ld      hl,(MENU_TABLE_PTR)                            ;#570B: 2A 6A D1
        inc     hl                                             ;#570E: 23
        ld      a,(MENU_CURRENT_INDEX)                         ;#570F: 3A 65 D1
        add     a,31h                                          ;#5712: C6 31
        ld      c,a                                            ;#5714: 4F
        ld      b,5                                            ;#5715: 06 05
RENDER_RANKING_ROW_LOOP:
        ; Outer 5-row body: push regs, clear row, draw cursor, render row
        push    bc                                             ;#5717: C5
        push    hl                                             ;#5718: E5
        push    hl                                             ;#5719: E5
        push    bc                                             ;#571A: C5
        xor     a                                              ;#571B: AF
        ld      bc,15h                                         ;#571C: 01 15 00
        call    BIOS_FILVRM                                    ;#571F: CD 56 00
        call    DRAW_MENU_CURSOR                               ;#5722: CD E8 63
        pop     bc                                             ;#5725: C1
        pop     hl                                             ;#5726: E1
        ld      a,c                                            ;#5727: 79
        cp      3Ah                                            ;#5728: FE 3A
        jr      z,RENDER_RANKING_RANK_10                       ;#572A: 28 06
        inc     hl                                             ;#572C: 23
        call    BIOS_WRTVRM                                    ;#572D: CD 4D 00
        jr      VIEW_RANKING_WRITE_NAME_ROW                    ;#5730: 18 0B

RENDER_RANKING_RANK_10:
        ; Special case rank == 10 (':' becomes "10"): write '1' then '0'
        ld      a,31h                                          ;#5732: 3E 31
        call    BIOS_WRTVRM                                    ;#5734: CD 4D 00
        inc     hl                                             ;#5737: 23
        ld      a,30h                                          ;#5738: 3E 30
        call    BIOS_WRTVRM                                    ;#573A: CD 4D 00
VIEW_RANKING_WRITE_NAME_ROW:
        ; Continue after rank digit(s): write ':' tile then 8-byte name via LDIRVM
        inc     hl                                             ;#573D: 23
        ld      a,3Bh                                          ;#573E: 3E 3B
        call    BIOS_WRTVRM                                    ;#5740: CD 4D 00
        inc     hl                                             ;#5743: 23
        push    ix                                             ;#5744: DD E5
        pop     de                                             ;#5746: D1
        ex      de,hl                                          ;#5747: EB
        ld      bc,8                                           ;#5748: 01 08 00
        push    de                                             ;#574B: D5
        push    bc                                             ;#574C: C5
        call    BIOS_LDIRVM                                    ;#574D: CD 5C 00
        ld      hl,SCRATCH_HEX_OUTPUT                          ;#5750: 21 00 DA
        ld      a,(iy+2)                                       ;#5753: FD 7E 02
        call    WRITE_BYTE_AS_ASCII_HEX                        ;#5756: CD 5D 67
        inc     hl                                             ;#5759: 23
        ld      a,(iy+1)                                       ;#575A: FD 7E 01
        call    WRITE_BYTE_AS_ASCII_HEX                        ;#575D: CD 5D 67
        inc     hl                                             ;#5760: 23
        ld      a,(iy)                                         ;#5761: FD 7E 00
        call    WRITE_BYTE_AS_ASCII_HEX                        ;#5764: CD 5D 67
        pop     bc                                             ;#5767: C1
        pop     hl                                             ;#5768: E1
        add     hl,bc                                          ;#5769: 09
        ld      a,3Eh                                          ;#576A: 3E 3E
        call    BIOS_WRTVRM                                    ;#576C: CD 4D 00
        inc     hl                                             ;#576F: 23
        ld      de,SCRATCH_HEX_OUTPUT                          ;#5770: 11 00 DA
        ld      bc,600h                                        ;#5773: 01 00 06
        ld      a,(GAME_ID)                                    ;#5776: 3A 01 D3
        cp      29h                                            ;#5779: FE 29
        jr      nz,RENDER_RANKING_SCORE_ZERO_LOOP              ;#577B: 20 03
        inc     de                                             ;#577D: 13
        dec     b                                              ;#577E: 05
        inc     c                                              ;#577F: 0C
RENDER_RANKING_SCORE_ZERO_LOOP:
        ; Skip leading zero digits in the 6-byte score
        ld      a,(de)                                         ;#5780: 1A
        cp      30h                                            ;#5781: FE 30
        jr      nz,RENDER_RANKING_SCORE_LDIR                   ;#5783: 20 0F
        inc     hl                                             ;#5785: 23
        inc     de                                             ;#5786: 13
        djnz    RENDER_RANKING_SCORE_ZERO_LOOP                 ;#5787: 10 F7
        bit     0,c                                            ;#5789: CB 41
        jr      nz,RENDER_RANKING_SCORE_DIGIT                  ;#578B: 20 01
        dec     hl                                             ;#578D: 2B
RENDER_RANKING_SCORE_DIGIT:
        ; First non-zero score digit: BIOS_WRTVRM the run
        call    BIOS_WRTVRM                                    ;#578E: CD 4D 00
        inc     hl                                             ;#5791: 23
        jr      VIEW_RANKING_WRITE_PTS_VRAM                    ;#5792: 18 18

RENDER_RANKING_SCORE_LDIR:
        ; LDIRVM the remaining score digits + write the "PTS" suffix
        push    bc                                             ;#5794: C5
        ld      c,b                                            ;#5795: 48
        ld      b,0                                            ;#5796: 06 00
        ex      de,hl                                          ;#5798: EB
        push    bc                                             ;#5799: C5
        push    de                                             ;#579A: D5
        call    BIOS_LDIRVM                                    ;#579B: CD 5C 00
        pop     hl                                             ;#579E: E1
        pop     bc                                             ;#579F: C1
        add     hl,bc                                          ;#57A0: 09
        pop     bc                                             ;#57A1: C1
        bit     0,c                                            ;#57A2: CB 41
        jr      z,VIEW_RANKING_WRITE_PTS_VRAM                  ;#57A4: 28 06
        ld      a,30h                                          ;#57A6: 3E 30
        call    BIOS_WRTVRM                                    ;#57A8: CD 4D 00
        inc     hl                                             ;#57AB: 23
VIEW_RANKING_WRITE_PTS_VRAM:
        ; Append the 3-byte "PTS" suffix to a row via LDIRVM (DE=TXT_PTS)
        ld      de,TXT_PTS                                     ;#57AC: 11 CC 57
        ex      de,hl                                          ;#57AF: EB
        ld      bc,3                                           ;#57B0: 01 03 00
        call    BIOS_LDIRVM                                    ;#57B3: CD 5C 00
        ld      bc,9                                           ;#57B6: 01 09 00
        add     ix,bc                                          ;#57B9: DD 09
        ld      bc,3                                           ;#57BB: 01 03 00
        add     iy,bc                                          ;#57BE: FD 09
        pop     hl                                             ;#57C0: E1
        ld      bc,20h                                         ;#57C1: 01 20 00
        add     hl,bc                                          ;#57C4: 09
        pop     bc                                             ;#57C5: C1
        inc     c                                              ;#57C6: 0C
        dec     b                                              ;#57C7: 05
        jp      nz,RENDER_RANKING_ROW_LOOP                     ;#57C8: C2 17 57
        ret                                                    ;#57CB: C9

TXT_PTS:
        ; 3-byte ASCII "PTS" suffix appended after each ranking score
        db      "PTS"                                          ;#57CC: 50 54 53

GET_RANKING_NAME_PTR:
        ; HL = RANKING_NAME_BLOCK + A*9 + 1 — entry A's 8-byte name field
        ld      b,a                                            ;#57CF: 47
        add     a,a                                            ;#57D0: 87
        add     a,b                                            ;#57D1: 80
        ld      b,a                                            ;#57D2: 47
        add     a,a                                            ;#57D3: 87
        add     a,b                                            ;#57D4: 80
        ld      hl,RANKING_NAME_BLOCK                          ;#57D5: 21 77 D4
        call    ADD_A_TO_HL                                    ;#57D8: CD ED 60
        inc     hl                                             ;#57DB: 23
        ret                                                    ;#57DC: C9

GET_RANKING_SCORE_PTR:
        ; HL = RANKING_SCORE_BLOCK + A*3 — pointer to ranking entry A's 3-byte score
        ld      b,a                                            ;#57DD: 47
        add     a,a                                            ;#57DE: 87
        add     a,b                                            ;#57DF: 80
        ld      hl,RANKING_SCORE_BLOCK                         ;#57E0: 21 59 D4
        call    ADD_A_TO_HL                                    ;#57E3: CD ED 60
        ret                                                    ;#57E6: C9

PRINT_RANKING_TABLE_TO_PRINTER:
        ; Clear pixel buffer, emit header + 10 rows, dispatch to raster output
        ld      (SP_SAVE_FOR_BDOS),sp                          ;#57E7: ED 73 27 D1
        ld      hl,PRINTER_PIXEL_BUFFER                        ;#57EB: 21 B1 D9
        ld      de,PRINTER_PIXEL_BUFFER+1                      ;#57EE: 11 B2 D9
        ld      (hl),20h                                       ;#57F1: 36 20
        ld      bc,3BFh                                        ;#57F3: 01 BF 03
        ldir                                                   ;#57F6: ED B0
        call    WAIT_PRINTER_READY                             ;#57F8: CD 08 71
        ld      a,0E0h                                         ;#57FB: 3E E0
        ld      (PRINTER_PAGE_HEIGHT),a                        ;#57FD: 32 76 DD
        ld      a,78h                                          ;#5800: 3E 78
        ld      (PRINTER_PAGE_WIDTH),a                         ;#5802: 32 75 DD
        ld      hl,TXT_PRINTER_RANKING_HEADER                  ;#5805: 21 35 58
        call    DECODE_PRINTER_TEXT_STREAM                     ;#5808: CD 24 58
        ld      a,(GAME_ID)                                    ;#580B: 3A 01 D3
        ld      hl,PRINTER_PIXEL_BUFFER+8                      ;#580E: 21 B9 D9
        call    WRITE_BYTE_AS_ASCII_HEX                        ;#5811: CD 5D 67
        xor     a                                              ;#5814: AF
        ld      (MENU_CURRENT_INDEX),a                         ;#5815: 32 65 D1
        ld      hl,PRINTER_RANKING_VRAM_TGT                    ;#5818: 21 41 DA
        ld      (MENU_TABLE_PTR),hl                            ;#581B: 22 6A D1
        call    BUILD_PRINTER_RANKING_ROWS                     ;#581E: CD 8B 58
        jp      PRINT_VRAM_AS_GRAPHICS                         ;#5821: C3 86 75

DECODE_PRINTER_TEXT_STREAM:
        ; Decode stream (DE=target word, bytes, FE=retarget, FF=end) into buffer
        ld      e,(hl)                                         ;#5824: 5E
        inc     hl                                             ;#5825: 23
        ld      d,(hl)                                         ;#5826: 56
        inc     hl                                             ;#5827: 23
DECODE_PRINTER_STREAM_BYTE:
        ; Inner byte loop: write (DE)=A then check next byte for FE/FF tokens
        ld      a,(hl)                                         ;#5828: 7E
        ld      b,a                                            ;#5829: 47
        inc     hl                                             ;#582A: 23
        inc     a                                              ;#582B: 3C
        ret     z                                              ;#582C: C8
        inc     a                                              ;#582D: 3C
        jr      z,DECODE_PRINTER_TEXT_STREAM                   ;#582E: 28 F4
        ld      a,b                                            ;#5830: 78
        ld      (de),a                                         ;#5831: 12
        inc     de                                             ;#5832: 13
        jr      DECODE_PRINTER_STREAM_BYTE                     ;#5833: 18 F3

TXT_PRINTER_RANKING_HEADER:
        ; Printer header for the ranking dump (86 bytes incl. dashes row)
        dh      "B1D92A2A2A2052432D3720202053434F"             ;#5835: B1 D9 2A 2A 2A 20 52 43 2D 37 20 20 20 53 43 4F
        dh      "52452052414E4B494E47202A2A2AFEEB"             ;#5845: 52 45 20 52 41 4E 4B 49 4E 47 20 2A 2A 2A FE EB
        dh      "D952616E6B2E20204E616D652E202020"             ;#5855: D9 52 61 6E 6B 2E 20 20 4E 61 6D 65 2E 20 20 20
        dh      "53636F72652EFE05DA2D2D2D2D2D2D2D"             ;#5865: 53 63 6F 72 65 2E FE 05 DA 2D 2D 2D 2D 2D 2D 2D
        dh      "2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D"             ;#5875: 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D
        dh      "2D2D2D2D2DFF"                                 ;#5885: 2D 2D 2D 2D 2D FF

BUILD_PRINTER_RANKING_ROWS:
        ; Render all 10 ranking rows into the printer pixel buffer at MENU_TABLE_PTR
        ld      a,(MENU_CURRENT_INDEX)                         ;#588B: 3A 65 D1
        call    GET_RANKING_NAME_PTR                           ;#588E: CD CF 57
        push    hl                                             ;#5891: E5
        pop     ix                                             ;#5892: DD E1
        ld      a,(MENU_CURRENT_INDEX)                         ;#5894: 3A 65 D1
        call    GET_RANKING_SCORE_PTR                          ;#5897: CD DD 57
        push    hl                                             ;#589A: E5
        pop     iy                                             ;#589B: FD E1
        ld      hl,(MENU_TABLE_PTR)                            ;#589D: 2A 6A D1
        ld      a,(MENU_CURRENT_INDEX)                         ;#58A0: 3A 65 D1
        add     a,31h                                          ;#58A3: C6 31
        ld      c,a                                            ;#58A5: 4F
        ld      b,0Ah                                          ;#58A6: 06 0A
PRINT_RANKING_ROW_LOOP:
        ; Outer 10-row body: push regs, write rank digit(s) into pixel buffer
        push    bc                                             ;#58A8: C5
        push    hl                                             ;#58A9: E5
        ld      a,c                                            ;#58AA: 79
        cp      3Ah                                            ;#58AB: FE 3A
        jr      z,PRINT_RANKING_RANK_10                        ;#58AD: 28 04
        inc     hl                                             ;#58AF: 23
        ld      (hl),a                                         ;#58B0: 77
        jr      PRINT_RANKING_ROW_WRITE_NAME                   ;#58B1: 18 07

PRINT_RANKING_RANK_10:
        ; Special case rank == 10: write '1' '0'
        ld      a,31h                                          ;#58B3: 3E 31
        ld      (hl),a                                         ;#58B5: 77
        inc     hl                                             ;#58B6: 23
        ld      a,30h                                          ;#58B7: 3E 30
        ld      (hl),a                                         ;#58B9: 77
PRINT_RANKING_ROW_WRITE_NAME:
        ; Printer-buffer analogue of VIEW_RANKING_WRITE_NAME_ROW (ldir to RAM)
        inc     hl                                             ;#58BA: 23
        ld      a,3Ah                                          ;#58BB: 3E 3A
        ld      (hl),a                                         ;#58BD: 77
        inc     hl                                             ;#58BE: 23
        push    ix                                             ;#58BF: DD E5
        pop     de                                             ;#58C1: D1
        ex      de,hl                                          ;#58C2: EB
        push    de                                             ;#58C3: D5
        ld      b,8                                            ;#58C4: 06 08
PRINT_RANKING_NAME_LOOP:
        ; 8-byte name copy with 3Ch→2Eh ('.' as placeholder) translation
        ld      a,(hl)                                         ;#58C6: 7E
        cp      3Ch                                            ;#58C7: FE 3C
        jr      nz,PRINT_RANKING_NAME_STORE                    ;#58C9: 20 02
        ld      a,2Eh                                          ;#58CB: 3E 2E
PRINT_RANKING_NAME_STORE:
        ; Per-byte store: ld (DE),A then advance both pointers
        ld      (de),a                                         ;#58CD: 12
        inc     hl                                             ;#58CE: 23
        inc     de                                             ;#58CF: 13
        djnz    PRINT_RANKING_NAME_LOOP                        ;#58D0: 10 F4
        ld      hl,NAME_INPUT_BUFFER                           ;#58D2: 21 42 D1
        ld      a,(iy+2)                                       ;#58D5: FD 7E 02
        call    WRITE_BYTE_AS_ASCII_HEX                        ;#58D8: CD 5D 67
        inc     hl                                             ;#58DB: 23
        ld      a,(iy+1)                                       ;#58DC: FD 7E 01
        call    WRITE_BYTE_AS_ASCII_HEX                        ;#58DF: CD 5D 67
        inc     hl                                             ;#58E2: 23
        ld      a,(iy)                                         ;#58E3: FD 7E 00
        call    WRITE_BYTE_AS_ASCII_HEX                        ;#58E6: CD 5D 67
        pop     hl                                             ;#58E9: E1
        ld      a,8                                            ;#58EA: 3E 08
        call    ADD_A_TO_HL                                    ;#58EC: CD ED 60
        ld      a,3Dh                                          ;#58EF: 3E 3D
        ld      (hl),a                                         ;#58F1: 77
        inc     hl                                             ;#58F2: 23
        ld      de,NAME_INPUT_BUFFER                           ;#58F3: 11 42 D1
        ld      bc,600h                                        ;#58F6: 01 00 06
        ld      a,(GAME_ID)                                    ;#58F9: 3A 01 D3
        cp      29h                                            ;#58FC: FE 29
        jr      nz,PRINT_RANKING_SCORE_ZERO_LOOP               ;#58FE: 20 03
        inc     de                                             ;#5900: 13
        dec     b                                              ;#5901: 05
        inc     c                                              ;#5902: 0C
PRINT_RANKING_SCORE_ZERO_LOOP:
        ; Skip leading zeros (printer twin of RENDER_RANKING_SCORE_ZERO_LOOP)
        ld      a,(de)                                         ;#5903: 1A
        cp      30h                                            ;#5904: FE 30
        jr      nz,PRINT_RANKING_SCORE_LDIR                    ;#5906: 20 0D
        inc     hl                                             ;#5908: 23
        inc     de                                             ;#5909: 13
        djnz    PRINT_RANKING_SCORE_ZERO_LOOP                  ;#590A: 10 F7
        bit     0,c                                            ;#590C: CB 41
        jr      nz,PRINT_RANKING_SCORE_BACK                    ;#590E: 20 01
        dec     hl                                             ;#5910: 2B
PRINT_RANKING_SCORE_BACK:
        ; Score body: dec hl, ld (hl),A — re-write the digit at the corrected slot
        ld      (hl),a                                         ;#5911: 77
        inc     hl                                             ;#5912: 23
        jr      PRINT_RANKING_ROW_WRITE_PTS                    ;#5913: 18 15

PRINT_RANKING_SCORE_LDIR:
        ; LDIR the remaining score digits into the pixel buffer
        push    bc                                             ;#5915: C5
        ld      c,b                                            ;#5916: 48
        ld      b,0                                            ;#5917: 06 00
        ex      de,hl                                          ;#5919: EB
        push    bc                                             ;#591A: C5
        push    de                                             ;#591B: D5
        ldir                                                   ;#591C: ED B0
        pop     hl                                             ;#591E: E1
        pop     bc                                             ;#591F: C1
        add     hl,bc                                          ;#5920: 09
        pop     bc                                             ;#5921: C1
        bit     0,c                                            ;#5922: CB 41
        jr      z,PRINT_RANKING_ROW_WRITE_PTS                  ;#5924: 28 04
        ld      a,30h                                          ;#5926: 3E 30
        ld      (hl),a                                         ;#5928: 77
        inc     hl                                             ;#5929: 23
PRINT_RANKING_ROW_WRITE_PTS:
        ; Printer-buffer analogue of VIEW_RANKING_WRITE_PTS_VRAM (ldir TXT_PTS to RAM)
        ld      de,TXT_PTS                                     ;#592A: 11 CC 57
        ex      de,hl                                          ;#592D: EB
        ld      bc,3                                           ;#592E: 01 03 00
        ldir                                                   ;#5931: ED B0
        ld      bc,9                                           ;#5933: 01 09 00
        add     ix,bc                                          ;#5936: DD 09
        ld      bc,3                                           ;#5938: 01 03 00
        add     iy,bc                                          ;#593B: FD 09
        pop     hl                                             ;#593D: E1
        ld      a,(PRINTER_PAGE_HEIGHT)                        ;#593E: 3A 76 DD
        and     0F8h                                           ;#5941: E6 F8
        rrca                                                   ;#5943: 0F
        rrca                                                   ;#5944: 0F
        rrca                                                   ;#5945: 0F
        call    ADD_A_TO_HL                                    ;#5946: CD ED 60
        pop     bc                                             ;#5949: C1
        inc     c                                              ;#594A: 0C
        dec     b                                              ;#594B: 05
        jp      nz,PRINT_RANKING_ROW_LOOP                      ;#594C: C2 A8 58
        ret                                                    ;#594F: C9

LIVES_CHEAT_DISPATCH_TABLE:
        ; Per-game-ID → LIVES-write handler table (3-byte stride, FFh end)
        CHEAT_LIVES ID_GAME_ATHLETIC_LAND, CHEAT_LIVES_STORE_DECIMAL  ;#5950: 00 D1 59
        CHEAT_LIVES ID_GAME_MONKEY_ACADEMY, CHEAT_LIVES_STORE_DECIMAL  ;#5953: 02 D1 59
        CHEAT_LIVES ID_GAME_TIME_PILOT, CHEAT_LIVES_STORE_DECIMAL  ;#5956: 03 D1 59
        CHEAT_LIVES ID_GAME_FROGGER, CHEAT_LIVES_STORE_DECIMAL  ;#5959: 04 D1 59
        CHEAT_LIVES ID_GAME_SUPER_COBRA, CHEAT_LIVES_STORE_DECIMAL  ;#595C: 05 D1 59
        CHEAT_LIVES ID_GAME_VIDEO_HUSTLER, CHEAT_LIVES_STORE_DECIMAL  ;#595F: 06 D1 59
        CHEAT_LIVES ID_GAME_CIRCUS_CHARLIE, CHEAT_LIVES_STORE_DECIMAL  ;#5962: 12 D1 59
        CHEAT_LIVES ID_GAME_MAGICAL_TREE, CHEAT_LIVES_STORE_DECIMAL  ;#5965: 13 D1 59
        CHEAT_LIVES ID_GAME_COMIC_BAKERY, CHEAT_LIVES_STORE_DECIMAL  ;#5968: 14 D1 59
        CHEAT_LIVES ID_GAME_CABBAGE_PATCH_KIDS, CHEAT_LIVES_STORE_DECIMAL  ;#596B: 16 D1 59
        CHEAT_LIVES ID_GAME_YIE_AR_KUNG_FU, CHEAT_LIVES_YIE_AR_KUNG_FU  ;#596E: 25 C1 59
        CHEAT_LIVES ID_GAME_SKY_JAGUAR, CHEAT_LIVES_STORE_DECIMAL  ;#5971: 21 D1 59
        CHEAT_LIVES ID_GAME_KINGS_VALLEY, CHEAT_LIVES_STORE_DECIMAL  ;#5974: 27 D1 59
        CHEAT_LIVES ID_GAME_MOPIRANGER, CHEAT_LIVES_MOPIRANGER  ;#5977: 28 DE 59
        CHEAT_LIVES ID_GAME_PIPPOLS, CHEAT_LIVES_STORE_HEX     ;#597A: 29 D9 59
        CHEAT_LIVES ID_GAME_YIE_AR_KUNG_FU_2, CHEAT_LIVES_STORE_HEX  ;#597D: 37 D9 59
        db      0FFh                                           ;#5980: FF

STAGE_CHEAT_DISPATCH_TABLE:
        ; Per-game-ID → STAGE-write handler table (3-byte stride, FFh end)
        CHEAT_STAGE ID_GAME_ATHLETIC_LAND, CHEAT_STAGE_BCD     ;#5981: 00 FA 59
        CHEAT_STAGE ID_GAME_ANTARCTIC_ADVENTURE, CHEAT_STAGE_ANTARCTIC  ;#5984: 01 1F 5A
        CHEAT_STAGE ID_GAME_HYPER_OLYMPIC_1, CHEAT_STAGE_HYPER_OLYMPIC  ;#5987: 10 5A 5A
        CHEAT_STAGE ID_GAME_HYPER_OLYMPIC_2, CHEAT_STAGE_HYPER_OLYMPIC  ;#598A: 11 5A 5A
        CHEAT_STAGE ID_GAME_CIRCUS_CHARLIE, CHEAT_STAGE_CIRCUS_CHARLIE  ;#598D: 12 A3 5A
        CHEAT_STAGE ID_GAME_MAGICAL_TREE, CHEAT_STAGE_MAGICAL_TREE  ;#5990: 13 B9 5A
        CHEAT_STAGE ID_GAME_COMIC_BAKERY, CHEAT_STAGE_COMIC_BAKERY  ;#5993: 14 0B 5B
        CHEAT_STAGE ID_GAME_HYPER_SPORTS_1, CHEAT_STAGE_HYPER_SPORTS_1  ;#5996: 15 0E 5B
        CHEAT_STAGE ID_GAME_CABBAGE_PATCH_KIDS, CHEAT_STAGE_BCD  ;#5999: 16 FA 59
        CHEAT_STAGE ID_GAME_HYPER_SPORTS_2, CHEAT_STAGE_HYPER_SPORTS_2  ;#599C: 17 15 5B
        CHEAT_STAGE ID_GAME_HYPER_RALLY, CHEAT_STAGE_HYPER_RALLY  ;#599F: 18 21 5B
        CHEAT_STAGE ID_GAME_SKY_JAGUAR, CHEAT_STAGE_SKY_JAGUAR  ;#59A2: 21 59 5B
        CHEAT_STAGE ID_GAME_YIE_AR_KUNG_FU, CHEAT_STAGE_YIE_AR_KUNG_FU  ;#59A5: 25 6A 5B
        CHEAT_STAGE ID_GAME_KINGS_VALLEY, CHEAT_STAGE_KINGS_VALLEY  ;#59A8: 27 9A 5B
        CHEAT_STAGE ID_GAME_MOPIRANGER, CHEAT_STAGE_MOPIRANGER  ;#59AB: 28 EB 5B
        CHEAT_STAGE ID_GAME_PIPPOLS, CHEAT_STAGE_PIPPOLS       ;#59AE: 29 06 5C
        CHEAT_STAGE ID_GAME_ROAD_FIGHTER, CHEAT_STAGE_ROAD_FIGHTER  ;#59B1: 30 19 5C
        CHEAT_STAGE ID_GAME_KONAMIS_SOCCER, CHEAT_STAGE_KONAMIS_SOCCER  ;#59B4: 32 38 5C
        CHEAT_STAGE ID_GAME_HYPER_SPORTS_3, CHEAT_STAGE_HYPER_SPORTS_3  ;#59B7: 33 41 5C
        CHEAT_STAGE ID_GAME_KONAMIS_BOXING, CHEAT_STAGE_KONAMIS_BOXING  ;#59BA: 36 4A 5C
        CHEAT_STAGE ID_GAME_YIE_AR_KUNG_FU_2, CHEAT_STAGE_YIE_AR_KUNG_FU_2  ;#59BD: 37 70 5C
        db      0FFh                                           ;#59C0: FF

CHEAT_LIVES_YIE_AR_KUNG_FU:
        ; YAK LIVES: set CHEAT_TARGET_YIE_AR_KUNG_FU_LIVES_CAP=FFh; clamp lives to 10
        ld      a,0FFh                                         ;#59C1: 3E FF
        ld      (CHEAT_TARGET_YIE_AR_KUNG_FU_LIVES_CAP),a      ;#59C3: 32 52 E0
        ld      a,(CHEAT_LIVES_DECIMAL)                        ;#59C6: 3A 18 D3
        cp      0Bh                                            ;#59C9: FE 0B
        jr      c,CHEAT_LIVES_CLAMP_10                         ;#59CB: 38 02
        ld      a,0Ah                                          ;#59CD: 3E 0A
CHEAT_LIVES_CLAMP_10:
        ; YAK LIVES clamp: if A > 10, A = 10 (and fall into CHEAT_LIVES_WRITE_BYTE)
        jr      CHEAT_LIVES_WRITE_BYTE                         ;#59CF: 18 03

CHEAT_LIVES_STORE_DECIMAL:
        ; Load CHEAT_LIVES_DECIMAL, fall into CHEAT_LIVES_WRITE_BYTE (default form)
        ld      a,(CHEAT_LIVES_DECIMAL)                        ;#59D1: 3A 18 D3
CHEAT_LIVES_WRITE_BYTE:
        ; Common LIVES tail: write A into the byte pointed to by GAME_RAM_LIVES_PTR
        ld      hl,(GAME_RAM_LIVES_PTR)                        ;#59D4: 2A 08 D3
        ld      (hl),a                                         ;#59D7: 77
        ret                                                    ;#59D8: C9

CHEAT_LIVES_STORE_HEX:
        ; Load CHEAT_LIVES_HEX, fall into CHEAT_LIVES_WRITE_BYTE (packed-BCD form)
        ld      a,(CHEAT_LIVES_HEX)                            ;#59D9: 3A 19 D3
        jr      CHEAT_LIVES_WRITE_BYTE                         ;#59DC: 18 F6

CHEAT_LIVES_MOPIRANGER:
        ; Mopi LIVES: write LIVES_DECIMAL → LIVES, LIVES_HEX → LIVES_BCD
        ld      a,(CHEAT_LIVES_DECIMAL)                        ;#59DE: 3A 18 D3
        ld      (CHEAT_TARGET_LIVES),a                         ;#59E1: 32 50 E0
        ld      a,(CHEAT_LIVES_HEX)                            ;#59E4: 3A 19 D3
        ld      (CHEAT_TARGET_LIVES_BCD),a                     ;#59E7: 32 51 E0
        ret                                                    ;#59EA: C9

CHEAT_STAGE_GENERIC:
        ; Default STAGE write: stage = ((D31A-1) mod D313)+1 via GAME_RAM_STAGE_PTR
        ld      a,(GAME_STAGE_COUNT)                           ;#59EB: 3A 13 D3
        ld      c,a                                            ;#59EE: 4F
        ld      a,(CHEAT_STAGE_DECIMAL)                        ;#59EF: 3A 1A D3
        call    DIVMOD_16BIT_BY_C                              ;#59F2: CD 8E 5C
        ld      a,l                                            ;#59F5: 7D
        inc     a                                              ;#59F6: 3C
        jp      CHEAT_STAGE_STORE_A                            ;#59F7: C3 95 5B

CHEAT_STAGE_BCD:
        ; Write (stage-1)*10 to STAGE_BCD_LO/HI + binary to STAGE_BIN; chain STORE_HEX
        ld      a,(CHEAT_STAGE_DECIMAL)                        ;#59FA: 3A 1A D3
        dec     a                                              ;#59FD: 3D
        ld      l,a                                            ;#59FE: 6F
        ld      h,0                                            ;#59FF: 26 00
        add     hl,hl                                          ;#5A01: 29
        ld      b,h                                            ;#5A02: 44
        ld      c,l                                            ;#5A03: 4D
        add     hl,hl                                          ;#5A04: 29
        add     hl,hl                                          ;#5A05: 29
        add     hl,bc                                          ;#5A06: 09
        call    BIN16_TO_BCD16                                 ;#5A07: CD BA 61
        ld      a,e                                            ;#5A0A: 7B
        ld      (CHEAT_TARGET_STAGE_BCD_LO),a                  ;#5A0B: 32 59 E0
        push    af                                             ;#5A0E: F5
        add     a,10h                                          ;#5A0F: C6 10
        daa                                                    ;#5A11: 27
        ld      (CHEAT_TARGET_STAGE_BCD_HI),a                  ;#5A12: 32 5A E0
        pop     af                                             ;#5A15: F1
        call    BCD_TO_BIN8                                    ;#5A16: CD CB 61
        ld      (CHEAT_TARGET_STAGE_BIN),a                     ;#5A19: 32 54 E0
        jp      CHEAT_STAGE_STORE_HEX                          ;#5A1C: C3 92 5B

CHEAT_STAGE_ANTARCTIC:
        ; STAGE via STAGE_ANTARCTIC_LUT_*: divmod 10, write encoded byte to ANTARCTIC_BYTE
        ld      a,(CHEAT_STAGE_DECIMAL)                        ;#5A1F: 3A 1A D3
        ld      c,0Ah                                          ;#5A22: 0E 0A
        call    DIVMOD_16BIT_BY_C                              ;#5A24: CD 8E 5C
        ld      a,l                                            ;#5A27: 7D
        ld      (CHEAT_TARGET_ANTARCTIC_INDEX),a               ;#5A28: 32 E1 E0
        ld      (CHEAT_TARGET_ANTARCTIC_BACKUP),a              ;#5A2B: 32 E8 E0
        ld      b,a                                            ;#5A2E: 47
        ld      a,(GAME_STAGE_LUT_SELECT)                      ;#5A2F: 3A 03 D3
        or      a                                              ;#5A32: B7
        ld      hl,STAGE_ANTARCTIC_LUT_DEFAULT                 ;#5A33: 21 46 5A
        jr      z,CHEAT_STAGE_ANTARCTIC_USE_VARIANT            ;#5A36: 28 03
        ld      hl,STAGE_ANTARCTIC_LUT_VARIANT                 ;#5A38: 21 50 5A
CHEAT_STAGE_ANTARCTIC_USE_VARIANT:
        ; Variant-LUT path: HL=STAGE_ANTARCTIC_LUT_VARIANT + B (GAME_VARIANT-chosen)
        ld      a,b                                            ;#5A3B: 78
        call    ADD_A_TO_HL                                    ;#5A3C: CD ED 60
        ld      a,(hl)                                         ;#5A3F: 7E
        ld      (CHEAT_TARGET_ANTARCTIC_BYTE),a                ;#5A40: 32 E2 E0
        jp      CHEAT_STAGE_STORE_HEX                          ;#5A43: C3 92 5B

STAGE_ANTARCTIC_LUT_DEFAULT:
        ; 10-byte stage→ANTARCTIC LUT for GAME_VARIANT=VARIANT_NO (most games)
        dh      "00060D131A22272D3335"                         ;#5A46: 00 06 0D 13 1A 22 27 2D 33 35

STAGE_ANTARCTIC_LUT_VARIANT:
        ; Alt stage→ANTARCTIC LUT for GAME_VARIANT=VARIANT_YES (Antarctic only)
        dh      "00070F141A20222F353C"                         ;#5A50: 00 07 0F 14 1A 20 22 2F 35 3C

CHEAT_STAGE_HYPER_OLYMPIC:
        ; STAGE for HO/Hyper Sports: divmod 4, copy 2-byte event pair from a table
        ld      a,(CHEAT_STAGE_DECIMAL)                        ;#5A5A: 3A 1A D3
        ld      c,4                                            ;#5A5D: 0E 04
        call    DIVMOD_16BIT_BY_C                              ;#5A5F: CD 8E 5C
        ld      a,l                                            ;#5A62: 7D
        inc     a                                              ;#5A63: 3C
        ld      hl,(GAME_RAM_STAGE_PTR)                        ;#5A64: 2A 0A D3
        ld      (hl),a                                         ;#5A67: 77
        ld      (CHEAT_TARGET_HYPER_OLYMPIC_EVENT),a           ;#5A68: 32 15 E0
        dec     a                                              ;#5A6B: 3D
        push    af                                             ;#5A6C: F5
        add     a,a                                            ;#5A6D: 87
        ld      b,a                                            ;#5A6E: 47
        ld      hl,STAGE_HYPER_OLYMPIC_PAIR_TABLE_DEF          ;#5A6F: 21 93 5A
        ld      a,(GAME_ID)                                    ;#5A72: 3A 01 D3
        cp      10h                                            ;#5A75: FE 10
        jr      z,CHEAT_STAGE_HYPER_OLYMPIC_USE_ALT            ;#5A77: 28 03
        ld      hl,STAGE_HYPER_OLYMPIC_PAIR_TABLE_ALT          ;#5A79: 21 9B 5A
CHEAT_STAGE_HYPER_OLYMPIC_USE_ALT:
        ; Alt-pair path: HL=STAGE_HYPER_OLYMPIC_PAIR_TABLE_ALT + B (GAME_VARIANT-selected)
        ld      a,b                                            ;#5A7C: 78
        call    ADD_A_TO_HL                                    ;#5A7D: CD ED 60
        ex      de,hl                                          ;#5A80: EB
        pop     af                                             ;#5A81: F1
        ld      b,a                                            ;#5A82: 47
        add     a,a                                            ;#5A83: 87
        add     a,b                                            ;#5A84: 80
        ld      hl,CHEAT_TARGET_LIVES                          ;#5A85: 21 50 E0
        call    ADD_A_TO_HL                                    ;#5A88: CD ED 60
        ex      de,hl                                          ;#5A8B: EB
        inc     de                                             ;#5A8C: 13
        ld      bc,2                                           ;#5A8D: 01 02 00
        ldir                                                   ;#5A90: ED B0
        ret                                                    ;#5A92: C9

STAGE_HYPER_OLYMPIC_PAIR_TABLE_DEF:
        ; Default 8-byte event-pair table for the HO STAGE cheat
        dh      "1400060080005500"                             ;#5A93: 14 00 06 00 80 00 55 00

STAGE_HYPER_OLYMPIC_PAIR_TABLE_ALT:
        ; Alternate event-pair table picked when D301 == 10h (HO-1)
        dh      "1500750002300430"                             ;#5A9B: 15 00 75 00 02 30 04 30

CHEAT_STAGE_CIRCUS_CHARLIE:
        ; STAGE for Circus Charlie: STAGE_STORE_HEX + divmod 5 → E052 alias
        call    CHEAT_STAGE_STORE_HEX                          ;#5AA3: CD 92 5B
        ld      a,(CHEAT_STAGE_DECIMAL)                        ;#5AA6: 3A 1A D3
        ld      l,a                                            ;#5AA9: 6F
        sub     5                                              ;#5AAA: D6 05
        jr      c,CHEAT_STAGE_HYPER_RALLY_DIFFICULTY           ;#5AAC: 38 06
        inc     a                                              ;#5AAE: 3C
        ld      c,5                                            ;#5AAF: 0E 05
        call    DIVMOD_16BIT_BY_C                              ;#5AB1: CD 8E 5C
CHEAT_STAGE_HYPER_RALLY_DIFFICULTY:
        ; After divmod 13: write quotient to CHEAT_TARGET_HYPER_RALLY_DIFFICULTY
        ld      a,l                                            ;#5AB4: 7D
        ld      (CHEAT_TARGET_HYPER_RALLY_DIFFICULTY),a        ;#5AB5: 32 52 E0
        ret                                                    ;#5AB8: C9

CHEAT_STAGE_MAGICAL_TREE:
        ; STAGE for game 13: direct + lookup into CHEAT_STAGE_MAGICAL_TREE_TABLE
        call    CHEAT_STAGE_STORE_HEX                          ;#5AB9: CD 92 5B
        ld      a,(CHEAT_STAGE_DECIMAL)                        ;#5ABC: 3A 1A D3
        ld      b,a                                            ;#5ABF: 47
        dec     a                                              ;#5AC0: 3D
        ld      (CHEAT_TARGET_MAGICAL_TREE_E05C),a             ;#5AC1: 32 5C E0
        cp      8                                              ;#5AC4: FE 08
        jr      c,CHEAT_STAGE_MAGICAL_TREE_TABLE_2_LOOKUP      ;#5AC6: 38 02
        ld      a,8                                            ;#5AC8: 3E 08
CHEAT_STAGE_MAGICAL_TREE_TABLE_2_LOOKUP:
        ; Index CHEAT_STAGE_MAGICAL_TREE_TABLE_2 with A*2 for 2-byte LUT
        ld      hl,CHEAT_STAGE_MAGICAL_TREE_TABLE              ;#5ACA: 21 F0 5A
        call    ADD_A_TO_HL                                    ;#5ACD: CD ED 60
        ld      a,(hl)                                         ;#5AD0: 7E
        ld      (CHEAT_TARGET_MAGICAL_TREE_E05D),a             ;#5AD1: 32 5D E0
        ld      a,8Ah                                          ;#5AD4: 3E 8A
        ld      (CHEAT_TARGET_STAGE_TRIGGER),a                 ;#5AD6: 32 56 E0
        ld      a,b                                            ;#5AD9: 78
        ld      c,9                                            ;#5ADA: 0E 09
        call    DIVMOD_16BIT_BY_C                              ;#5ADC: CD 8E 5C
        ld      a,l                                            ;#5ADF: 7D
        add     a,a                                            ;#5AE0: 87
        ld      hl,CHEAT_STAGE_MAGICAL_TREE_TABLE_2            ;#5AE1: 21 F9 5A
        call    ADD_A_TO_HL                                    ;#5AE4: CD ED 60
        ld      de,CHEAT_TARGET_STAGE_BIN                      ;#5AE7: 11 54 E0
        ld      bc,2                                           ;#5AEA: 01 02 00
        ldir                                                   ;#5AED: ED B0
        ret                                                    ;#5AEF: C9

CHEAT_STAGE_MAGICAL_TREE_TABLE:
        ; 9-byte stage→MT_E05D LUT used by CHEAT_STAGE_MAGICAL_TREE
        dh      "7733BBEE11BBEE1111"                           ;#5AF0: 77 33 BB EE 11 BB EE 11 11

CHEAT_STAGE_MAGICAL_TREE_TABLE_2:
        ; 18-byte stage→STAGE_BIN LUT used by CHEAT_STAGE_MAGICAL_TREE
        dh      "0000700C201A50283036E0434052C061"             ;#5AF9: 00 00 70 0C 20 1A 50 28 30 36 E0 43 40 52 C0 61
        dh      "D06E"                                         ;#5B09: D0 6E

CHEAT_STAGE_COMIC_BAKERY:
        ; STAGE for game 14 (Comic Bakery): direct jp CHEAT_STAGE_STORE_HEX
        jp      CHEAT_STAGE_STORE_HEX                          ;#5B0B: C3 92 5B

CHEAT_STAGE_HYPER_SPORTS_1:
        ; STAGE for game 15 (Hyper Sports 1): A = D31A - 1, write to GAME_RAM_STAGE_PTR
        ld      a,(CHEAT_STAGE_DECIMAL)                        ;#5B0E: 3A 1A D3
        dec     a                                              ;#5B11: 3D
        jp      CHEAT_STAGE_STORE_A                            ;#5B12: C3 95 5B

CHEAT_STAGE_HYPER_SPORTS_2:
        ; STAGE (game 17, HS2): divmod 3, write quotient to GAME_RAM_STAGE_PTR
        ld      a,(CHEAT_STAGE_DECIMAL)                        ;#5B15: 3A 1A D3
        ld      c,3                                            ;#5B18: 0E 03
        call    DIVMOD_16BIT_BY_C                              ;#5B1A: CD 8E 5C
        ld      a,l                                            ;#5B1D: 7D
        jp      CHEAT_STAGE_STORE_A                            ;#5B1E: C3 95 5B

CHEAT_STAGE_HYPER_RALLY:
        ; STAGE for game 18 (Hyper Rally): divmod 13, write HR_COURSE+HR_PAIR
        ld      a,(CHEAT_STAGE_DECIMAL)                        ;#5B21: 3A 1A D3
        ld      c,0Dh                                          ;#5B24: 0E 0D
        call    DIVMOD_16BIT_BY_C                              ;#5B26: CD 8E 5C
        ld      a,l                                            ;#5B29: 7D
        inc     a                                              ;#5B2A: 3C
        ld      (CHEAT_TARGET_HYPER_RALLY_COURSE),a            ;#5B2B: 32 60 E0
        dec     a                                              ;#5B2E: 3D
        add     a,a                                            ;#5B2F: 87
        ld      hl,CHEAT_STAGE_HYPER_RALLY_TABLE               ;#5B30: 21 3F 5B
        call    ADD_A_TO_HL                                    ;#5B33: CD ED 60
        ld      de,CHEAT_TARGET_HYPER_RALLY_PAIR               ;#5B36: 11 5B E0
        ld      bc,2                                           ;#5B39: 01 02 00
        ldir                                                   ;#5B3C: ED B0
        ret                                                    ;#5B3E: C9

CHEAT_STAGE_HYPER_RALLY_TABLE:
        ; 24-byte difficulty-pair LUT used by CHEAT_STAGE_HYPER_RALLY
        dh      "06800670067006700660065006500650"             ;#5B3F: 06 80 06 70 06 70 06 70 06 60 06 50 06 50 06 50
        dh      "0660066006500650"                             ;#5B4F: 06 60 06 60 06 50 06 50
        nop                                                    ;#5B57: 00
        add     a,b                                            ;#5B58: 80

CHEAT_STAGE_SKY_JAGUAR:
        ; STAGE (RC-721 Sky Jaguar): divmod 8; write H to CHEAT_TARGET_SHARED_E1B8
        ld      a,(CHEAT_STAGE_DECIMAL)                        ;#5B59: 3A 1A D3
        ld      c,8                                            ;#5B5C: 0E 08
        call    DIVMOD_16BIT_BY_C                              ;#5B5E: CD 8E 5C
        ld      h,l                                            ;#5B61: 65
        ld      l,0                                            ;#5B62: 2E 00
        ld      (CHEAT_TARGET_SKY_JAGUAR_EXTRA),hl             ;#5B64: 22 B8 E1
        jp      CHEAT_STAGE_STORE_HEX                          ;#5B67: C3 92 5B

CHEAT_STAGE_YIE_AR_KUNG_FU:
        ; STAGE for RC-725 Yie Ar Kung-Fu: write STAGE_BIN / STAGE_E056 / STAGE_BCD_LO
        call    CHEAT_STAGE_STORE_HEX                          ;#5B6A: CD 92 5B
        ld      a,(CHEAT_STAGE_DECIMAL)                        ;#5B6D: 3A 1A D3
        push    af                                             ;#5B70: F5
        ld      c,5                                            ;#5B71: 0E 05
        call    DIVMOD_16BIT_BY_C                              ;#5B73: CD 8E 5C
        ld      a,l                                            ;#5B76: 7D
        ld      (CHEAT_TARGET_STAGE_BIN),a                     ;#5B77: 32 54 E0
        pop     af                                             ;#5B7A: F1
        cp      6                                              ;#5B7B: FE 06
        ret     c                                              ;#5B7D: D8
        ld      b,a                                            ;#5B7E: 47
        sub     5                                              ;#5B7F: D6 05
        cp      4                                              ;#5B81: FE 04
        jr      c,CHEAT_STAGE_YIE_AR_KUNG_FU_SET_OPPONENT      ;#5B83: 38 02
        ld      a,3                                            ;#5B85: 3E 03
CHEAT_STAGE_YIE_AR_KUNG_FU_SET_OPPONENT:
        ; Stage > 5 path: write 3 to STAGE_E056 (opponent index)
        ld      (CHEAT_TARGET_STAGE_TRIGGER),a                 ;#5B87: 32 56 E0
        ld      a,b                                            ;#5B8A: 78
        dec     a                                              ;#5B8B: 3D
        and     3                                              ;#5B8C: E6 03
        ld      (CHEAT_TARGET_STAGE_BCD_LO),a                  ;#5B8E: 32 59 E0
        ret                                                    ;#5B91: C9

CHEAT_STAGE_STORE_HEX:
        ; Load CHEAT_STAGE_HEX and write to (GAME_RAM_STAGE_PTR) — generic STAGE tail
        ld      a,(CHEAT_STAGE_HEX)                            ;#5B92: 3A 1B D3
CHEAT_STAGE_STORE_A:
        ; Alt entry: write A directly to (GAME_RAM_STAGE_PTR) without re-reading D31B
        ld      hl,(GAME_RAM_STAGE_PTR)                        ;#5B95: 2A 0A D3
        ld      (hl),a                                         ;#5B98: 77
        ret                                                    ;#5B99: C9

CHEAT_STAGE_KINGS_VALLEY:
        ; STAGE for RC-727 King's Valley: divmod 15 + KV LUT into STAGE_BIN..KV_HI
        ld      a,(CHEAT_STAGE_DECIMAL)                        ;#5B9A: 3A 1A D3
        ld      c,0Fh                                          ;#5B9D: 0E 0F
        call    DIVMOD_16BIT_BY_C                              ;#5B9F: CD 8E 5C
        ld      a,e                                            ;#5BA2: 7B
        ld      (CHEAT_TARGET_KINGS_VALLEY_HI),a               ;#5BA3: 32 58 E0
        ld      a,l                                            ;#5BA6: 7D
        inc     a                                              ;#5BA7: 3C
        ld      (CHEAT_TARGET_KINGS_VALLEY_HI - 3),a           ;#5BA8: 32 55 E0
        dec     a                                              ;#5BAB: 3D
        ld      (CHEAT_TARGET_STAGE_BIN),a                     ;#5BAC: 32 54 E0
        ld      hl,CHEAT_STAGE_KINGS_VALLEY_TABLE              ;#5BAF: 21 CB 5B
        add     a,a                                            ;#5BB2: 87
        call    ADD_A_TO_HL                                    ;#5BB3: CD ED 60
        ld      a,(hl)                                         ;#5BB6: 7E
        ld      (CHEAT_TARGET_STAGE_TRIGGER),a                 ;#5BB7: 32 56 E0
        inc     hl                                             ;#5BBA: 23
        ld      a,(hl)                                         ;#5BBB: 7E
        ld      (CHEAT_TARGET_KINGS_VALLEY_HI - 1),a           ;#5BBC: 32 57 E0
        ld      a,(CHEAT_TARGET_KINGS_VALLEY_HI - 3)           ;#5BBF: 3A 55 E0
        cp      1                                              ;#5BC2: FE 01
        jr      z,CHEAT_STAGE_KINGS_VALLEY_CLEAR_LIVES_BCD     ;#5BC4: 28 01
        xor     a                                              ;#5BC6: AF
CHEAT_STAGE_KINGS_VALLEY_CLEAR_LIVES_BCD:
        ; KV tail: clear CHEAT_TARGET_LIVES_BCD and return
        ld      (CHEAT_TARGET_LIVES_BCD),a                     ;#5BC7: 32 51 E0
        ret                                                    ;#5BCA: C9

CHEAT_STAGE_KINGS_VALLEY_TABLE:
        ; 32-byte (16×2) stage→(E056,E057) LUT used by CHEAT_STAGE_KINGS_VALLEY
        dh      "08000408040801080804080404040408"             ;#5BCB: 08 00 04 08 04 08 01 08 08 04 08 04 04 04 04 08
        dh      "01080804080404040408040801020804"             ;#5BDB: 01 08 08 04 08 04 04 04 04 08 04 08 01 02 08 04

CHEAT_STAGE_MOPIRANGER:
        ; STAGE (RC-728 Mopiranger): clamp; write MOPI_STAGE + BCD-stage byte
        ld      a,(CHEAT_STAGE_DECIMAL)                        ;#5BEB: 3A 1A D3
        cp      33h                                            ;#5BEE: FE 33
        jr      c,CHEAT_STAGE_MOPIRANGER_STORE_DEC             ;#5BF0: 38 02
        sub     32h                                            ;#5BF2: D6 32
CHEAT_STAGE_MOPIRANGER_STORE_DEC:
        ; Merge after the decimal clamp: dec A and store to MOPI_STAGE
        dec     a                                              ;#5BF4: 3D
        ld      (CHEAT_TARGET_MOPIRANGER_STAGE),a              ;#5BF5: 32 53 E0
        ld      a,(CHEAT_STAGE_HEX)                            ;#5BF8: 3A 1B D3
        cp      51h                                            ;#5BFB: FE 51
        jr      c,CHEAT_STAGE_MOPIRANGER_STORE_BCD             ;#5BFD: 38 03
        sub     50h                                            ;#5BFF: D6 50
        daa                                                    ;#5C01: 27
CHEAT_STAGE_MOPIRANGER_STORE_BCD:
        ; Merge after BCD clamp: daa and store to CHEAT_TARGET_MOPIRANGER_STAGE_BCD
        ld      (CHEAT_TARGET_MOPIRANGER_STAGE_BCD),a          ;#5C02: 32 52 E0
        ret                                                    ;#5C05: C9

CHEAT_STAGE_PIPPOLS:
        ; STAGE for game 29 (RC-729 Pippols): divmod 8 quotient → E103; E1B8 = 00C0
        ld      a,(CHEAT_STAGE_DECIMAL)                        ;#5C06: 3A 1A D3
        ld      c,8                                            ;#5C09: 0E 08
        call    DIVMOD_16BIT_BY_C                              ;#5C0B: CD 8E 5C
        ld      a,l                                            ;#5C0E: 7D
        ld      (CHEAT_TARGET_PIPPOLS_STAGE),a                 ;#5C0F: 32 03 E1
        ld      hl,0C0h                                        ;#5C12: 21 C0 00
        ld      (CHEAT_TARGET_PIPPOLS_EXTRA),hl                ;#5C15: 22 B8 E1
        ret                                                    ;#5C18: C9

CHEAT_STAGE_ROAD_FIGHTER:
        ; STAGE for RC-730 Road Fighter: divmod 6, set STAGE_PTR + RF_LAP + RF_E000/E001
        ld      a,(CHEAT_STAGE_DECIMAL)                        ;#5C19: 3A 1A D3
        ld      c,6                                            ;#5C1C: 0E 06
        call    DIVMOD_16BIT_BY_C                              ;#5C1E: CD 8E 5C
        ld      a,e                                            ;#5C21: 7B
        ld      (CHEAT_TARGET_ROAD_FIGHTER_LAP),a              ;#5C22: 32 42 E0
        ld      a,l                                            ;#5C25: 7D
        ld      hl,(GAME_RAM_STAGE_PTR)                        ;#5C26: 2A 0A D3
        ld      (hl),a                                         ;#5C29: 77
        call    CLEAR_VRAM_NAME_TABLES                         ;#5C2A: CD AD 5C
        ld      a,4                                            ;#5C2D: 3E 04
        ld      (CHEAT_TARGET_ROAD_FIGHTER_E001),a             ;#5C2F: 32 01 E0
        ld      a,8                                            ;#5C32: 3E 08
        ld      (CHEAT_TARGET_ROAD_FIGHTER_E000),a             ;#5C34: 32 00 E0
        ret                                                    ;#5C37: C9

CHEAT_STAGE_KONAMIS_SOCCER:
        ; STAGE (RC-732 Konami's Soccer): clear VRAM; set GAME_RAM_TRIGGER_PTR=7
        call    CLEAR_VRAM_NAME_TABLES                         ;#5C38: CD AD 5C
        ld      hl,(GAME_RAM_TRIGGER_PTR)                      ;#5C3B: 2A 04 D3
        ld      (hl),7                                         ;#5C3E: 36 07
        ret                                                    ;#5C40: C9

CHEAT_STAGE_HYPER_SPORTS_3:
        ; STAGE for game 33 (RC-733 Hyper Sports 3): A = D31A-1 → GAME_RAM_STAGE_PTR
        ld      a,(CHEAT_STAGE_DECIMAL)                        ;#5C41: 3A 1A D3
        dec     a                                              ;#5C44: 3D
        ld      hl,(GAME_RAM_STAGE_PTR)                        ;#5C45: 2A 0A D3
        ld      (hl),a                                         ;#5C48: 77
        ret                                                    ;#5C49: C9

CHEAT_STAGE_KONAMIS_BOXING:
        ; STAGE for game 36 (RC-736 Konami's Boxing): write E206/E207 + clear VRAM
        ld      a,(CHEAT_STAGE_DECIMAL)                        ;#5C4A: 3A 1A D3
        dec     a                                              ;#5C4D: 3D
        ld      (CHEAT_TARGET_BOXING_OPPONENT),a               ;#5C4E: 32 06 E2
        call    CHEAT_STAGE_STORE_HEX                          ;#5C51: CD 92 5B
        ld      a,(CHEAT_STAGE_DECIMAL)                        ;#5C54: 3A 1A D3
        ld      c,3                                            ;#5C57: 0E 03
        call    DIVMOD_16BIT_BY_C                              ;#5C59: CD 8E 5C
        ld      a,e                                            ;#5C5C: 7B
        and     0Fh                                            ;#5C5D: E6 0F
        rrca                                                   ;#5C5F: 0F
        rrca                                                   ;#5C60: 0F
        rrca                                                   ;#5C61: 0F
        rrca                                                   ;#5C62: 0F
        add     a,l                                            ;#5C63: 85
        ld      (CHEAT_TARGET_BOXING_ROUND),a                  ;#5C64: 32 07 E2
        ld      a,9                                            ;#5C67: 3E 09
        ld      hl,(GAME_RAM_TRIGGER_PTR)                      ;#5C69: 2A 04 D3
        ld      (hl),a                                         ;#5C6C: 77
        jp      CLEAR_VRAM_NAME_TABLES                         ;#5C6D: C3 AD 5C

CHEAT_STAGE_YIE_AR_KUNG_FU_2:
        ; STAGE for RC-737 Yie Ar Kung-Fu II: divmod 8 → STAGE_PTR + YIE_AR_KUNG_FU_2_MODE
        ld      a,(CHEAT_STAGE_DECIMAL)                        ;#5C70: 3A 1A D3
        ld      c,8                                            ;#5C73: 0E 08
        call    DIVMOD_16BIT_BY_C                              ;#5C75: CD 8E 5C
        ld      a,l                                            ;#5C78: 7D
        ld      hl,(GAME_RAM_STAGE_PTR)                        ;#5C79: 2A 0A D3
        ld      (hl),a                                         ;#5C7C: 77
        ld      a,e                                            ;#5C7D: 7B
        cp      2                                              ;#5C7E: FE 02
        jr      c,CHEAT_STAGE_YIE_AR_KUNG_FU_2_SET_MODE        ;#5C80: 38 02
        ld      a,2                                            ;#5C82: 3E 02
CHEAT_STAGE_YIE_AR_KUNG_FU_2_SET_MODE:
        ; Stage > 8 path: write 2 to the high-stage flag, then fall through
        ld      (CHEAT_TARGET_YIE_AR_KUNG_FU_2_MODE),a         ;#5C84: 32 6A E0
        ld      a,(CHEAT_STAGE_HEX)                            ;#5C87: 3A 1B D3
        ld      (CHEAT_TARGET_MOPIRANGER_STAGE),a              ;#5C8A: 32 53 E0
        ret                                                    ;#5C8D: C9

DIVMOD_16BIT_BY_C:
        ; 16-bit divide (A-1)/C → quotient in E, remainder in L
        dec     a                                              ;#5C8E: 3D
        ld      e,a                                            ;#5C8F: 5F
        ld      d,0                                            ;#5C90: 16 00
        ld      b,d                                            ;#5C92: 42
        ld      hl,0                                           ;#5C93: 21 00 00
        exx                                                    ;#5C96: D9
        ld      b,10h                                          ;#5C97: 06 10
DIVMOD_LOOP_BODY:
        ; Per-bit body: exx; sla e; rl d; adc hl,hl; sbc hl,bc with restore-on-borrow
        exx                                                    ;#5C99: D9
        sla     e                                              ;#5C9A: CB 23
        rl      d                                              ;#5C9C: CB 12
        adc     hl,hl                                          ;#5C9E: ED 6A
        sbc     hl,bc                                          ;#5CA0: ED 42
        jr      c,DIVMOD_LOOP_RESTORE                          ;#5CA2: 38 03
        inc     e                                              ;#5CA4: 1C
        jr      DIVMOD_LOOP_END_ITER                           ;#5CA5: 18 01

DIVMOD_LOOP_RESTORE:
        ; Borrow path: restore HL by adding BC back
        add     hl,bc                                          ;#5CA7: 09
DIVMOD_LOOP_END_ITER:
        ; End of one bit iteration: exx; djnz back to body; exx; ret on count=0
        exx                                                    ;#5CA8: D9
        djnz    DIVMOD_LOOP_BODY                               ;#5CA9: 10 EE
        exx                                                    ;#5CAB: D9
        ret                                                    ;#5CAC: C9

CLEAR_VRAM_NAME_TABLES:
        ; Shared tail: clear VRAM 3800..3B00 (name table) and 3B00..3BFF
        LOAD_NAME_TABLE hl, 0, 0                               ;#5CAD: 21 00 38
        xor     a                                              ;#5CB0: AF
        ld      bc,300h                                        ;#5CB1: 01 00 03
        call    BIOS_FILVRM                                    ;#5CB4: CD 56 00
        LOAD_NAME_TABLE hl, 24, 0                              ;#5CB7: 21 00 3B
        ld      a,0D0h                                         ;#5CBA: 3E D0
        jp      BIOS_WRTVRM                                    ;#5CBC: C3 4D 00

IDENTIFY_GAME_CART_DISPATCH:
        ; Run game ID, then set a couple of post-ID state bytes from the result
        call    IDENTIFY_GAME_CART_BY_HEADER                   ;#5CBF: CD E3 5C
        ld      a,(GAME_ID)                                    ;#5CC2: 3A 01 D3
        ld      b,a                                            ;#5CC5: 47
        cp      36h                                            ;#5CC6: FE 36
        jr      nz,IDENTIFY_CART_CHECK_TP_FG                   ;#5CC8: 20 06
        ld      a,4                                            ;#5CCA: 3E 04
        ld      (GAME_STATE_TRIGGER_VAL),a                     ;#5CCC: 32 12 D3
        ret                                                    ;#5CCF: C9

IDENTIFY_CART_CHECK_TP_FG:
        ; Check IDs 3 (Time Pilot) / 4 (Frogger) — old games needing ISR_DISPATCH_FLAG
        ld      a,b                                            ;#5CD0: 78
        sub     3                                              ;#5CD1: D6 03
        cp      2                                              ;#5CD3: FE 02
        jr      c,IDENTIFY_CART_SET_ISR_FLAG                   ;#5CD5: 38 06
        ld      a,b                                            ;#5CD7: 78
        sub     10h                                            ;#5CD8: D6 10
        cp      2                                              ;#5CDA: FE 02
        ret     nc                                             ;#5CDC: D0
IDENTIFY_CART_SET_ISR_FLAG:
        ; Set ISR_DISPATCH_FLAG=1 for legacy games (forces alt ISR path)
        ld      a,1                                            ;#5CDD: 3E 01
        ld      (ISR_DISPATCH_FLAG),a                          ;#5CDF: 32 39 D3
        ret                                                    ;#5CE2: C9

IDENTIFY_GAME_CART_BY_HEADER:
        ; Probe game cart at GAME_BOOT; on 'AB'/'CD' copy 19-byte block
        ld      hl,DEFAULT_GAME_RECORD                         ;#5CE3: 21 B3 5E
        ld      de,GAME_RC_CODE_HIGH                           ;#5CE6: 11 00 D3
        ld      bc,16h                                         ;#5CE9: 01 16 00
        ldir                                                   ;#5CEC: ED B0
        ld      a,0FFh                                         ;#5CEE: 3E FF
        ld      (GAME_STAGE_COUNT),a                           ;#5CF0: 32 13 D3
        ld      hl,GAME_BOOT                                   ;#5CF3: 21 10 40
        call    READ_WORD_FROM_GAME_CART                       ;#5CF6: CD BA 40
        ld      hl,CART_MAGIC_AB                               ;#5CF9: 21 41 42
        rst     20h                                            ;#5CFC: E7
        jr      nz,UNPACK_CD_HEADER                            ;#5CFD: 20 0C
        ld      hl,GAME_START_ADDRESS                          ;#5CFF: 21 12 40
        ld      de,GAME_RC_CODE_HIGH                           ;#5D02: 11 00 D3
        ld      bc,13h                                         ;#5D05: 01 13 00
        jp      READ_BYTES_FROM_GAME_CART                      ;#5D08: C3 D3 4B

UNPACK_CD_HEADER:
        ; 'CD': 19 bytes GAME_START_ADDRESS → SCRATCH_HEADER_OR_DTA, bit-flag unpacker
        ; 'CD'-format header unpacker. Layout copied from cart
        ; GAME_START_ADDRESS..4024h into scratch SCRATCH_HEADER_OR_DTA..D363h,
        ; then selectively overlaid onto the GAME_RC_CODE_HIGH record:
        ;
        ; - scratch +1 (cart 4013h) → GAME_ID (game ID)
        ; - GAME_STAGE_CHEAT_FLAG is force-set to FFh (toggles MODIFY off the per-game
        ; STAGE_CHEAT_DISPATCH path that 'AB' carts walk when their
        ; GAME_HEADER byte = 0).
        ; - scratch +2 (cart 4014h) is the presence-flag byte. Each bit (LSB
        ; first, via rra) is consumed in turn; bit clear = field present
        ; in the stream, bit set = keep the DEFAULT_GAME_RECORD value.
        ;
        ; Bit → field mapping (bits 2..7 use CD_HEADER_PTR_DEST_TABLE order):
        ;
        ; bit 0  3 bytes  GAME_STATE_POINTER + GAME_STATE_TRIGGER_VAL
        ; bit 1  3 bytes  GAME_RAM_STAGE (D30A/D30B) + stage modulus GAME_STAGE_COUNT
        ; bit 2  2 bytes  GAME_RAM_LIVES (D308/D309)
        ; bit 3  2 bytes  GAME_RAM_HISCORE (D30C/D30D)
        ; bit 4  2 bytes  GAME_RAM_SCORE_1P (D30E/D30F)
        ; bit 5  2 bytes  GAME_RAM_SCORE_2P (D310/D311)
        ; bit 6  2 bytes  GAME_RAM_RANKING (D306/D307)
        ; bit 7  2 bytes  per-game CALSLT callback (D314/D315)
        ;
        ; The unconditional D302=FFh is the toggle that switches MODIFY_OPTION_*
        ; handlers from the legacy LIVES/STAGE dispatch-table path (used by
        ; 'AB' carts where GAME_HEADER was the +2 byte = 0) to the direct-
        ; pointer path that uses the new fields.
        ld      hl,CART_MAGIC_CD                               ;#5D0B: 21 43 44
        rst     20h                                            ;#5D0E: E7
        jr      nz,FINGERPRINT_GAME_CART                       ;#5D0F: 20 60
        ld      hl,GAME_START_ADDRESS                          ;#5D11: 21 12 40
        ld      de,SCRATCH_HEADER_OR_DTA                       ;#5D14: 11 51 D3
        ld      bc,13h                                         ;#5D17: 01 13 00
        call    READ_BYTES_FROM_GAME_CART                      ;#5D1A: CD D3 4B
        ld      hl,FILE_PICKER_DTA                             ;#5D1D: 21 52 D3
        ld      de,GAME_ID                                     ;#5D20: 11 01 D3
        ldi                                                    ;#5D23: ED A0
        ld      a,0FFh                                         ;#5D25: 3E FF
        ld      (de),a                                         ;#5D27: 12
        inc     de                                             ;#5D28: 13
        inc     de                                             ;#5D29: 13
        ld      a,(hl)                                         ;#5D2A: 7E
        rra                                                    ;#5D2B: 1F
        jr      c,UNPACK_CD_HEADER_BIT0                        ;#5D2C: 38 0B
        inc     hl                                             ;#5D2E: 23
        ld      bc,2                                           ;#5D2F: 01 02 00
        ldir                                                   ;#5D32: ED B0
        ld      de,GAME_STATE_TRIGGER_VAL                      ;#5D34: 11 12 D3
        ldi                                                    ;#5D37: ED A0

UNPACK_CD_HEADER_BIT0:
        ; Flag-bit 0 path (3-byte): D304/D305 + D312 game-state trigger
        rra                                                    ;#5D39: 1F
        jr      c,UNPACK_CD_HEADER_LOOP_INIT                   ;#5D3A: 38 0C
        ld      de,GAME_RAM_STAGE_PTR                          ;#5D3C: 11 0A D3
        ldi                                                    ;#5D3F: ED A0
        ldi                                                    ;#5D41: ED A0
        ld      de,GAME_STAGE_COUNT                            ;#5D43: 11 13 D3
        ldi                                                    ;#5D46: ED A0
UNPACK_CD_HEADER_LOOP_INIT:
        ; IX=CD_HEADER_PTR_DEST_TABLE, B=6 iterations over bits 2..7
        ld      ix,CD_HEADER_PTR_DEST_TABLE                    ;#5D48: DD 21 65 5D
        ld      b,6                                            ;#5D4C: 06 06
UNPACK_CD_HEADER_BIT_LOOP:
        ; Per-bit body: shift presence-flag, copy 2 bytes if bit clear
        push    bc                                             ;#5D4E: C5
        rra                                                    ;#5D4F: 1F
        jr      c,UNPACK_CD_HEADER_NEXT_BIT                    ;#5D50: 38 0B
        ld      e,(ix)                                         ;#5D52: DD 5E 00
        ld      d,(ix+1)                                       ;#5D55: DD 56 01
        ld      bc,2                                           ;#5D58: 01 02 00
        ldir                                                   ;#5D5B: ED B0
UNPACK_CD_HEADER_NEXT_BIT:
        ; Pop iteration count, advance IX, djnz
        pop     bc                                             ;#5D5D: C1
        inc     ix                                             ;#5D5E: DD 23
        inc     ix                                             ;#5D60: DD 23
        djnz    UNPACK_CD_HEADER_BIT_LOOP                      ;#5D62: 10 EA
        ret                                                    ;#5D64: C9

CD_HEADER_PTR_DEST_TABLE:
        ; 6 LE word destinations for the UNPACK_CD_HEADER bit-loop (flag bits 2..7)
        ; 6 LE word destinations consumed by the UNPACK_CD_HEADER bit loop in
        ; flag-bit order 2..7: D308 (LIVES), D30C (HI-SCORE), D30E (RANKING #1),
        ; D310 (RANKING-SCORE #2 ptr), D306 (RANKING-ENABLE flag ptr),
        ; D314 (callback). Note this is not the natural D-record-offset
        ; order: the ranking-enable pointer GAME_RAM_RANKING_PTR sits at flag bit 6.
        dw      GAME_RAM_LIVES_PTR                             ;#5D65: 08 D3
        dw      GAME_RAM_HISCORE_PTR                           ;#5D67: 0C D3
        dw      GAME_RAM_SCORE_1P_PTR                          ;#5D69: 0E D3
        dw      GAME_RAM_SCORE_2P_PTR                          ;#5D6B: 10 D3
        dw      GAME_RAM_RANKING_PTR                           ;#5D6D: 06 D3
        dw      GAME_CHEAT_CALLBACK_PTR                        ;#5D6F: 14 D3

FINGERPRINT_GAME_CART:
        ; Sum 256 bytes at game cart's 5000h into DE and look up the result in the table
        ld      a,(GAME_CART_SLOT)                             ;#5D71: 3A 2F D1
        ld      de,0                                           ;#5D74: 11 00 00
        ld      hl,5000h                                       ;#5D77: 21 00 50
        ld      b,0                                            ;#5D7A: 06 00
FINGERPRINT_SUM_LOOP:
        ; Per-byte body: push regs, RDSLT cart byte, add to running DE checksum
        push    af                                             ;#5D7C: F5
        push    bc                                             ;#5D7D: C5
        push    de                                             ;#5D7E: D5
        call    BIOS_RDSLT                                     ;#5D7F: CD 0C 00
        pop     de                                             ;#5D82: D1
        pop     bc                                             ;#5D83: C1
        add     a,e                                            ;#5D84: 83
        ld      e,a                                            ;#5D85: 5F
        jr      nc,FINGERPRINT_SUM_NEXT                        ;#5D86: 30 01
        inc     d                                              ;#5D88: 14
FINGERPRINT_SUM_NEXT:
        ; Pop sum, inc HL/DE/B back, djnz to next byte
        pop     af                                             ;#5D89: F1
        inc     hl                                             ;#5D8A: 23
        djnz    FINGERPRINT_SUM_LOOP                           ;#5D8B: 10 EF
LOOKUP_FINGERPRINT_IN_TABLE:
        ; Walk GAME_FINGERPRINT_TABLE; on match copy entry's 19 bytes to GAME_RC_CODE_HIGH
        ld      ix,GAME_FINGERPRINT_TABLE                      ;#5D8D: DD 21 B9 5D
FINGERPRINT_TABLE_WALK_LOOP:
        ; Per-entry body: HL=word at (IX), 0=end, compare game-id, copy on match
        ld      l,(ix)                                         ;#5D91: DD 6E 00
        ld      h,(ix+1)                                       ;#5D94: DD 66 01
        ld      a,l                                            ;#5D97: 7D
        or      h                                              ;#5D98: B4
        ret     z                                              ;#5D99: C8
        rst     20h                                            ;#5D9A: E7
        jr      z,FINGERPRINT_MATCH_COPY                       ;#5D9B: 28 0A
        inc     ix                                             ;#5D9D: DD 23
        inc     ix                                             ;#5D9F: DD 23
        inc     ix                                             ;#5DA1: DD 23
        inc     ix                                             ;#5DA3: DD 23
        jr      FINGERPRINT_TABLE_WALK_LOOP                    ;#5DA5: 18 EA

FINGERPRINT_MATCH_COPY:
        ; Match: copy the entry's 19-byte data block into GAME_RC_CODE_HIGH
        push    de                                             ;#5DA7: D5
        ld      l,(ix+2)                                       ;#5DA8: DD 6E 02
        ld      h,(ix+3)                                       ;#5DAB: DD 66 03
        ld      de,GAME_RC_CODE_HIGH                           ;#5DAE: 11 00 D3
        ld      bc,13h                                         ;#5DB1: 01 13 00
        ldir                                                   ;#5DB4: ED B0
        pop     de                                             ;#5DB6: D1
        scf                                                    ;#5DB7: 37
        ret                                                    ;#5DB8: C9

GAME_FINGERPRINT_TABLE:
        ; 62×4-byte entries (checksum, ptr) + 0000 terminator (5DB9..5EB2)
        GAME_FINGERPRINT "5058",GAME_DATA_ATHLETIC_LAND        ;#5DB9: 50 58 C6 5E
        GAME_FINGERPRINT "A455",GAME_DATA_ATHLETIC_LAND        ;#5DBD: A4 55 C6 5E
        GAME_FINGERPRINT "A96A",GAME_DATA_ANTARCTIC_JP         ;#5DC1: A9 6A D9 5E
        GAME_FINGERPRINT "4966",GAME_DATA_ANTARCTIC_JP         ;#5DC5: 49 66 D9 5E
        GAME_FINGERPRINT "D56C",GAME_DATA_ANTARCTIC_EU         ;#5DC9: D5 6C EC 5E
        GAME_FINGERPRINT "6166",GAME_DATA_ANTARCTIC_JP         ;#5DCD: 61 66 D9 5E
        GAME_FINGERPRINT "0368",GAME_DATA_ANTARCTIC_EU         ;#5DD1: 03 68 EC 5E
        GAME_FINGERPRINT "C565",GAME_DATA_MONKEY_ACADEMY       ;#5DD5: C5 65 FF 5E
        GAME_FINGERPRINT "4066",GAME_DATA_MONKEY_ACADEMY       ;#5DD9: 40 66 FF 5E
        GAME_FINGERPRINT "175F",GAME_DATA_MONKEY_ACADEMY       ;#5DDD: 17 5F FF 5E
        GAME_FINGERPRINT "7E5B",GAME_DATA_TIME_PILOT           ;#5DE1: 7E 5B 12 5F
        GAME_FINGERPRINT "E85C",GAME_DATA_TIME_PILOT           ;#5DE5: E8 5C 12 5F
        GAME_FINGERPRINT "E95B",GAME_DATA_TIME_PILOT           ;#5DE9: E9 5B 12 5F
        GAME_FINGERPRINT "4C6A",GAME_DATA_FROGGER              ;#5DED: 4C 6A 25 5F
        GAME_FINGERPRINT "175E",GAME_DATA_SUPER_COBRA          ;#5DF1: 17 5E 38 5F
        GAME_FINGERPRINT "0F5E",GAME_DATA_SUPER_COBRA          ;#5DF5: 0F 5E 38 5F
        GAME_FINGERPRINT "BC77",GAME_DATA_VIDEO_HUSTLER        ;#5DF9: BC 77 4B 5F
        GAME_FINGERPRINT "377A",GAME_DATA_VIDEO_HUSTLER        ;#5DFD: 37 7A 4B 5F
        GAME_FINGERPRINT "9478",GAME_DATA_VIDEO_HUSTLER        ;#5E01: 94 78 4B 5F
        GAME_FINGERPRINT "5B6D",GAME_DATA_MAHJONG_DOJO         ;#5E05: 5B 6D 5E 5F
        GAME_FINGERPRINT "4B77",GAME_DATA_HYPER_OLYMPIC_1      ;#5E09: 4B 77 71 5F
        GAME_FINGERPRINT "1779",GAME_DATA_HYPER_OLYMPIC_1      ;#5E0D: 17 79 71 5F
        GAME_FINGERPRINT "8978",GAME_DATA_HYPER_OLYMPIC_1      ;#5E11: 89 78 71 5F
        GAME_FINGERPRINT "6B76",GAME_DATA_HYPER_OLYMPIC_2      ;#5E15: 6B 76 84 5F
        GAME_FINGERPRINT "9F77",GAME_DATA_HYPER_OLYMPIC_2      ;#5E19: 9F 77 84 5F
        GAME_FINGERPRINT "D577",GAME_DATA_HYPER_OLYMPIC_2      ;#5E1D: D5 77 84 5F
        GAME_FINGERPRINT "7667",GAME_DATA_CIRCUS_CHARLIE       ;#5E21: 76 67 97 5F
        GAME_FINGERPRINT "725B",GAME_DATA_MAGICAL_TREE         ;#5E25: 72 5B AA 5F
        GAME_FINGERPRINT "215E",GAME_DATA_MAGICAL_TREE         ;#5E29: 21 5E AA 5F
        GAME_FINGERPRINT "654C",GAME_DATA_MAGICAL_TREE         ;#5E2D: 65 4C AA 5F
        GAME_FINGERPRINT "6167",GAME_DATA_COMIC_BAKERY         ;#5E31: 61 67 BD 5F
        GAME_FINGERPRINT "1466",GAME_DATA_COMIC_BAKERY         ;#5E35: 14 66 BD 5F
        GAME_FINGERPRINT "C668",GAME_DATA_COMIC_BAKERY         ;#5E39: C6 68 BD 5F
        GAME_FINGERPRINT "D447",GAME_DATA_HYPER_SPORTS_1       ;#5E3D: D4 47 D0 5F
        GAME_FINGERPRINT "A483",GAME_DATA_CABBAGE_PATCH_KIDS   ;#5E41: A4 83 E3 5F
        GAME_FINGERPRINT "2C6C",GAME_DATA_HYPER_SPORTS_2       ;#5E45: 2C 6C F6 5F
        GAME_FINGERPRINT "A272",GAME_DATA_HYPER_RALLY          ;#5E49: A2 72 09 60
        GAME_FINGERPRINT "1C71",GAME_DATA_HYPER_RALLY          ;#5E4D: 1C 71 09 60
        GAME_FINGERPRINT "A371",GAME_DATA_HYPER_RALLY          ;#5E51: A3 71 09 60
        GAME_FINGERPRINT "DC76",GAME_DATA_TENNIS               ;#5E55: DC 76 1C 60
        GAME_FINGERPRINT "9546",GAME_DATA_SKY_JAGUAR           ;#5E59: 95 46 2F 60
        GAME_FINGERPRINT "1E5E",GAME_DATA_GOLF                 ;#5E5D: 1E 5E 42 60
        GAME_FINGERPRINT "355E",GAME_DATA_GOLF                 ;#5E61: 35 5E 42 60
        GAME_FINGERPRINT "B05E",GAME_DATA_GOLF                 ;#5E65: B0 5E 42 60
        GAME_FINGERPRINT "7668",GAME_DATA_BASEBALL             ;#5E69: 76 68 55 60
        GAME_FINGERPRINT "D857",GAME_DATA_BASEBALL             ;#5E6D: D8 57 55 60
        GAME_FINGERPRINT "ED57",GAME_DATA_BASEBALL             ;#5E71: ED 57 55 60
        GAME_FINGERPRINT "856D",GAME_DATA_YIE_AR_KUNG_FU       ;#5E75: 85 6D 68 60
        GAME_FINGERPRINT "B86A",GAME_DATA_YIE_AR_KUNG_FU       ;#5E79: B8 6A 68 60
        GAME_FINGERPRINT "625D",GAME_DATA_KINGS_VALLEY         ;#5E7D: 62 5D 7B 60
        GAME_FINGERPRINT "3B64",GAME_DATA_KINGS_VALLEY         ;#5E81: 3B 64 7B 60
        GAME_FINGERPRINT "1865",GAME_DATA_KINGS_VALLEY         ;#5E85: 18 65 7B 60
        GAME_FINGERPRINT "9C71",GAME_DATA_MOPIRANGER           ;#5E89: 9C 71 8E 60
        GAME_FINGERPRINT "486B",GAME_DATA_MOPIRANGER           ;#5E8D: 48 6B 8E 60
        GAME_FINGERPRINT "AD68",GAME_DATA_PIPPOLS              ;#5E91: AD 68 A1 60
        GAME_FINGERPRINT "8D67",GAME_DATA_PIPPOLS              ;#5E95: 8D 67 A1 60
        GAME_FINGERPRINT "2E68",GAME_DATA_PIPPOLS              ;#5E99: 2E 68 A1 60
        GAME_FINGERPRINT "0274",GAME_DATA_ROAD_FIGHTER         ;#5E9D: 02 74 B4 60
        GAME_FINGERPRINT "0465",GAME_DATA_PING_PONG            ;#5EA1: 04 65 C7 60
        GAME_FINGERPRINT "0769",GAME_DATA_PING_PONG            ;#5EA5: 07 69 C7 60
        GAME_FINGERPRINT "226B",GAME_DATA_PING_PONG            ;#5EA9: 22 6B C7 60
        GAME_FINGERPRINT "B887",GAME_DATA_HYPER_SPORTS_3       ;#5EAD: B8 87 DA 60
        db      0,0                                            ;#5EB1: 00

DEFAULT_GAME_RECORD:
        ; Default fallback record (1-indexed base; record K at +K*13h, K=1..29)
        GAME_RC_CODE 0FFh                                      ;#5EB3: 00 FF
        GAME_HEADER HEADER_NONE                                ;#5EB5: 00
        GAME_VARIANT VARIANT_NO                                ;#5EB6: 00
        GAME_STATE_POINTER 0                                   ;#5EB7: 00 00
        GAME_RAM_RANKING 0                                     ;#5EB9: 00 00
        GAME_RAM_LIVES 0                                       ;#5EBB: 00 00
        GAME_RAM_STAGE 0                                       ;#5EBD: 00 00
        GAME_RAM_HISCORE 0                                     ;#5EBF: 00 00
        GAME_RAM_SCORE_1P 0                                    ;#5EC1: 00 00
        GAME_RAM_SCORE_2P 0                                    ;#5EC3: 00 00
        GAME_STATE_TRIGGER 0                                   ;#5EC5: 00

GAME_DATA_ATHLETIC_LAND:
        ; Per-game data record for RC-700 Athletic Land
        GAME_RC_CODE RC_GAME_ATHLETIC_LAND                     ;#5EC6: 07 00
        GAME_HEADER HEADER_NONE                                ;#5EC8: 00
        GAME_VARIANT VARIANT_NO                                ;#5EC9: 00
        GAME_STATE_POINTER GAME_STATE_ATHLETIC_LAND            ;#5ECA: 00 E0
        GAME_RAM_RANKING GAME_RANKING_ATHLETIC_LAND            ;#5ECC: 02 E0
        GAME_RAM_LIVES GAME_LIVES_ATHLETIC_LAND                ;#5ECE: 50 E0
        GAME_RAM_STAGE GAME_STAGE_ATHLETIC_LAND                ;#5ED0: 51 E0
        GAME_RAM_HISCORE GAME_HISCORE_ATHLETIC_LAND            ;#5ED2: 40 E0
        GAME_RAM_SCORE_1P GAME_SCORE_1P_ATHLETIC_LAND          ;#5ED4: 43 E0
        GAME_RAM_SCORE_2P GAME_SCORE_2P_ATHLETIC_LAND          ;#5ED6: 46 E0
        GAME_STATE_TRIGGER 9                                   ;#5ED8: 09

GAME_DATA_ANTARCTIC_JP:
        ; RC-701 Antarctic Adventure, Japanese cart revision
        GAME_RC_CODE RC_GAME_ANTARCTIC_ADVENTURE               ;#5ED9: 07 01
        GAME_HEADER HEADER_NONE                                ;#5EDB: 00
        GAME_VARIANT VARIANT_NO                                ;#5EDC: 00
        GAME_STATE_POINTER GAME_STATE_ANTARCTIC_JP             ;#5EDD: 00 E0
        GAME_RAM_RANKING 0                                     ;#5EDF: 00 00
        GAME_RAM_LIVES 0                                       ;#5EE1: 00 00
        GAME_RAM_STAGE GAME_STAGE_ANTARCTIC_JP                 ;#5EE3: E0 E0
        GAME_RAM_HISCORE GAME_HISCORE_ANTARCTIC_JP             ;#5EE5: 40 E0
        GAME_RAM_SCORE_1P GAME_SCORE_1P_ANTARCTIC_JP           ;#5EE7: 43 E0
        GAME_RAM_SCORE_2P 0                                    ;#5EE9: 00 00
        GAME_STATE_TRIGGER 9                                   ;#5EEB: 09

GAME_DATA_ANTARCTIC_EU:
        ; RC-701 Antarctic Adventure, European cart revision
        GAME_RC_CODE RC_GAME_ANTARCTIC_ADVENTURE               ;#5EEC: 07 01
        GAME_HEADER HEADER_NONE                                ;#5EEE: 00
        GAME_VARIANT VARIANT_YES                               ;#5EEF: 01
        GAME_STATE_POINTER GAME_STATE_ANTARCTIC_EU             ;#5EF0: 00 E0
        GAME_RAM_RANKING 0                                     ;#5EF2: 00 00
        GAME_RAM_LIVES 0                                       ;#5EF4: 00 00
        GAME_RAM_STAGE GAME_STAGE_ANTARCTIC_EU                 ;#5EF6: E0 E0
        GAME_RAM_HISCORE GAME_HISCORE_ANTARCTIC_EU             ;#5EF8: 40 E0
        GAME_RAM_SCORE_1P GAME_SCORE_1P_ANTARCTIC_EU           ;#5EFA: 43 E0
        GAME_RAM_SCORE_2P 0                                    ;#5EFC: 00 00
        GAME_STATE_TRIGGER 9                                   ;#5EFE: 09

GAME_DATA_MONKEY_ACADEMY:
        ; Per-game data record for RC-702 Monkey Academy
        GAME_RC_CODE RC_GAME_MONKEY_ACADEMY                    ;#5EFF: 07 02
        GAME_HEADER HEADER_NONE                                ;#5F01: 00
        GAME_VARIANT VARIANT_NO                                ;#5F02: 00
        GAME_STATE_POINTER GAME_STATE_MONKEY_ACADEMY           ;#5F03: 00 E0
        GAME_RAM_RANKING GAME_RANKING_MONKEY_ACADEMY           ;#5F05: 02 E0
        GAME_RAM_LIVES GAME_LIVES_MONKEY_ACADEMY               ;#5F07: 50 E0
        GAME_RAM_STAGE GAME_STAGE_MONKEY_ACADEMY               ;#5F09: 51 E0
        GAME_RAM_HISCORE GAME_HISCORE_MONKEY_ACADEMY           ;#5F0B: 40 E0
        GAME_RAM_SCORE_1P GAME_SCORE_1P_MONKEY_ACADEMY         ;#5F0D: 43 E0
        GAME_RAM_SCORE_2P GAME_SCORE_2P_MONKEY_ACADEMY         ;#5F0F: 46 E0
        GAME_STATE_TRIGGER 9                                   ;#5F11: 09

GAME_DATA_TIME_PILOT:
        ; Per-game data record for RC-703 Time Pilot
        GAME_RC_CODE RC_GAME_TIME_PILOT                        ;#5F12: 07 03
        GAME_HEADER HEADER_NONE                                ;#5F14: 00
        GAME_VARIANT VARIANT_NO                                ;#5F15: 00
        GAME_STATE_POINTER GAME_STATE_TIME_PILOT               ;#5F16: 02 E0
        GAME_RAM_RANKING GAME_RANKING_TIME_PILOT               ;#5F18: 00 E0
        GAME_RAM_LIVES GAME_LIVES_TIME_PILOT                   ;#5F1A: 02 E0
        GAME_RAM_STAGE 0                                       ;#5F1C: 00 00
        GAME_RAM_HISCORE GAME_HISCORE_TIME_PILOT               ;#5F1E: 11 E0
        GAME_RAM_SCORE_1P GAME_SCORE_1P_TIME_PILOT             ;#5F20: 0B E0
        GAME_RAM_SCORE_2P GAME_SCORE_2P_TIME_PILOT             ;#5F22: 0E E0
        GAME_STATE_TRIGGER 3                                   ;#5F24: 03

GAME_DATA_FROGGER:
        ; Per-game data record for RC-704 Frogger
        GAME_RC_CODE RC_GAME_FROGGER                           ;#5F25: 07 04
        GAME_HEADER HEADER_NONE                                ;#5F27: 00
        GAME_VARIANT VARIANT_NO                                ;#5F28: 00
        GAME_STATE_POINTER GAME_STATE_FROGGER                  ;#5F29: 02 E0
        GAME_RAM_RANKING GAME_RANKING_FROGGER                  ;#5F2B: 00 E0
        GAME_RAM_LIVES GAME_LIVES_FROGGER                      ;#5F2D: 02 E0
        GAME_RAM_STAGE 0                                       ;#5F2F: 00 00
        GAME_RAM_HISCORE GAME_HISCORE_FROGGER                  ;#5F31: 11 E0
        GAME_RAM_SCORE_1P GAME_SCORE_1P_FROGGER                ;#5F33: 0B E0
        GAME_RAM_SCORE_2P GAME_SCORE_2P_FROGGER                ;#5F35: 0E E0
        GAME_STATE_TRIGGER 3                                   ;#5F37: 03

GAME_DATA_SUPER_COBRA:
        ; Per-game data record for RC-705 Super Cobra
        GAME_RC_CODE RC_GAME_SUPER_COBRA                       ;#5F38: 07 05
        GAME_HEADER HEADER_NONE                                ;#5F3A: 00
        GAME_VARIANT VARIANT_NO                                ;#5F3B: 00
        GAME_STATE_POINTER GAME_STATE_SUPER_COBRA              ;#5F3C: 00 E0
        GAME_RAM_RANKING GAME_RANKING_SUPER_COBRA              ;#5F3E: 02 E0
        GAME_RAM_LIVES GAME_LIVES_SUPER_COBRA                  ;#5F40: 50 E0
        GAME_RAM_STAGE 0                                       ;#5F42: 00 00
        GAME_RAM_HISCORE GAME_HISCORE_SUPER_COBRA              ;#5F44: 40 E0
        GAME_RAM_SCORE_1P GAME_SCORE_1P_SUPER_COBRA            ;#5F46: 46 E0
        GAME_RAM_SCORE_2P GAME_SCORE_2P_SUPER_COBRA            ;#5F48: 43 E0
        GAME_STATE_TRIGGER 9                                   ;#5F4A: 09

GAME_DATA_VIDEO_HUSTLER:
        ; Per-game data record for RC-706 Video Hustler / Konami Billiards
        GAME_RC_CODE RC_GAME_VIDEO_HUSTLER                     ;#5F4B: 07 06
        GAME_HEADER HEADER_NONE                                ;#5F4D: 00
        GAME_VARIANT VARIANT_NO                                ;#5F4E: 00
        GAME_STATE_POINTER GAME_STATE_VIDEO_HUSTLER            ;#5F4F: 00 E0
        GAME_RAM_RANKING GAME_RANKING_VIDEO_HUSTLER            ;#5F51: 02 E0
        GAME_RAM_LIVES GAME_LIVES_VIDEO_HUSTLER                ;#5F53: 50 E0
        GAME_RAM_STAGE 0                                       ;#5F55: 00 00
        GAME_RAM_HISCORE GAME_HISCORE_VIDEO_HUSTLER            ;#5F57: 40 E0
        GAME_RAM_SCORE_1P GAME_SCORE_1P_VIDEO_HUSTLER          ;#5F59: 43 E0
        GAME_RAM_SCORE_2P GAME_SCORE_2P_VIDEO_HUSTLER          ;#5F5B: 46 E0
        GAME_STATE_TRIGGER 9                                   ;#5F5D: 09

GAME_DATA_MAHJONG_DOJO:
        ; Per-game data record for RC-707 Konami's Mahjong Dojo (zeroed: no cheats wired)
        GAME_RC_CODE RC_GAME_MAHJONG_DOJO                      ;#5F5E: 07 07
        GAME_HEADER HEADER_NONE                                ;#5F60: 00
        GAME_VARIANT VARIANT_NO                                ;#5F61: 00
        GAME_STATE_POINTER 0                                   ;#5F62: 00 00
        GAME_RAM_RANKING 0                                     ;#5F64: 00 00
        GAME_RAM_LIVES 0                                       ;#5F66: 00 00
        GAME_RAM_STAGE 0                                       ;#5F68: 00 00
        GAME_RAM_HISCORE 0                                     ;#5F6A: 00 00
        GAME_RAM_SCORE_1P 0                                    ;#5F6C: 00 00
        GAME_RAM_SCORE_2P 0                                    ;#5F6E: 00 00
        GAME_STATE_TRIGGER 0                                   ;#5F70: 00

GAME_DATA_HYPER_OLYMPIC_1:
        ; Per-game data record for RC-710 Hyper Olympic 1
        GAME_RC_CODE RC_GAME_HYPER_OLYMPIC_1                   ;#5F71: 07 10
        GAME_HEADER HEADER_NONE                                ;#5F73: 00
        GAME_VARIANT VARIANT_NO                                ;#5F74: 00
        GAME_STATE_POINTER GAME_STATE_HYPER_OLYMPIC_1          ;#5F75: 62 E1
        GAME_RAM_RANKING GAME_RANKING_HYPER_OLYMPIC_1          ;#5F77: 1B E0
        GAME_RAM_LIVES 0                                       ;#5F79: 00 00
        GAME_RAM_STAGE GAME_STAGE_HYPER_OLYMPIC_1              ;#5F7B: 16 E0
        GAME_RAM_HISCORE GAME_HISCORE_HYPER_OLYMPIC_1          ;#5F7D: 80 E0
        GAME_RAM_SCORE_1P GAME_SCORE_1P_HYPER_OLYMPIC_1        ;#5F7F: 83 E0
        GAME_RAM_SCORE_2P GAME_SCORE_2P_HYPER_OLYMPIC_1        ;#5F81: 86 E0
        GAME_STATE_TRIGGER 96h                                 ;#5F83: 96

GAME_DATA_HYPER_OLYMPIC_2:
        ; Per-game data record for RC-711 Hyper Olympic 2
        GAME_RC_CODE RC_GAME_HYPER_OLYMPIC_2                   ;#5F84: 07 11
        GAME_HEADER HEADER_NONE                                ;#5F86: 00
        GAME_VARIANT VARIANT_NO                                ;#5F87: 00
        GAME_STATE_POINTER GAME_STATE_HYPER_OLYMPIC_2          ;#5F88: 62 E1
        GAME_RAM_RANKING GAME_RANKING_HYPER_OLYMPIC_2          ;#5F8A: 1B E0
        GAME_RAM_LIVES 0                                       ;#5F8C: 00 00
        GAME_RAM_STAGE GAME_STAGE_HYPER_OLYMPIC_2              ;#5F8E: 16 E0
        GAME_RAM_HISCORE GAME_HISCORE_HYPER_OLYMPIC_2          ;#5F90: 80 E0
        GAME_RAM_SCORE_1P GAME_SCORE_1P_HYPER_OLYMPIC_2        ;#5F92: 83 E0
        GAME_RAM_SCORE_2P GAME_SCORE_2P_HYPER_OLYMPIC_2        ;#5F94: 86 E0
        GAME_STATE_TRIGGER 9Fh                                 ;#5F96: 9F

GAME_DATA_CIRCUS_CHARLIE:
        ; Per-game data record for RC-712 Circus Charlie
        GAME_RC_CODE RC_GAME_CIRCUS_CHARLIE                    ;#5F97: 07 12
        GAME_HEADER HEADER_NONE                                ;#5F99: 00
        GAME_VARIANT VARIANT_NO                                ;#5F9A: 00
        GAME_STATE_POINTER GAME_STATE_CIRCUS_CHARLIE           ;#5F9B: 00 E0
        GAME_RAM_RANKING GAME_RANKING_CIRCUS_CHARLIE           ;#5F9D: 02 E0
        GAME_RAM_LIVES GAME_LIVES_CIRCUS_CHARLIE               ;#5F9F: 50 E0
        GAME_RAM_STAGE GAME_STAGE_CIRCUS_CHARLIE               ;#5FA1: 51 E0
        GAME_RAM_HISCORE GAME_HISCORE_CIRCUS_CHARLIE           ;#5FA3: 43 E0
        GAME_RAM_SCORE_1P GAME_SCORE_1P_CIRCUS_CHARLIE         ;#5FA5: 49 E0
        GAME_RAM_SCORE_2P GAME_SCORE_2P_CIRCUS_CHARLIE         ;#5FA7: 46 E0
        GAME_STATE_TRIGGER 9                                   ;#5FA9: 09

GAME_DATA_MAGICAL_TREE:
        ; Per-game data record for RC-713 Magical Tree
        GAME_RC_CODE RC_GAME_MAGICAL_TREE                      ;#5FAA: 07 13
        GAME_HEADER HEADER_NONE                                ;#5FAC: 00
        GAME_VARIANT VARIANT_NO                                ;#5FAD: 00
        GAME_STATE_POINTER GAME_STATE_MAGICAL_TREE             ;#5FAE: 00 E0
        GAME_RAM_RANKING GAME_RANKING_MAGICAL_TREE             ;#5FB0: 02 E0
        GAME_RAM_LIVES GAME_LIVES_MAGICAL_TREE                 ;#5FB2: 50 E0
        GAME_RAM_STAGE GAME_STAGE_MAGICAL_TREE                 ;#5FB4: 51 E0
        GAME_RAM_HISCORE GAME_HISCORE_MAGICAL_TREE             ;#5FB6: 43 E0
        GAME_RAM_SCORE_1P GAME_SCORE_1P_MAGICAL_TREE           ;#5FB8: 49 E0
        GAME_RAM_SCORE_2P GAME_SCORE_2P_MAGICAL_TREE           ;#5FBA: 46 E0
        GAME_STATE_TRIGGER 9                                   ;#5FBC: 09

GAME_DATA_COMIC_BAKERY:
        ; Per-game data record for RC-714 Comic Bakery
        GAME_RC_CODE RC_GAME_COMIC_BAKERY                      ;#5FBD: 07 14
        GAME_HEADER HEADER_NONE                                ;#5FBF: 00
        GAME_VARIANT VARIANT_NO                                ;#5FC0: 00
        GAME_STATE_POINTER GAME_STATE_COMIC_BAKERY             ;#5FC1: 00 E0
        GAME_RAM_RANKING GAME_RANKING_COMIC_BAKERY             ;#5FC3: 02 E0
        GAME_RAM_LIVES GAME_LIVES_COMIC_BAKERY                 ;#5FC5: 50 E0
        GAME_RAM_STAGE GAME_STAGE_COMIC_BAKERY                 ;#5FC7: 51 E0
        GAME_RAM_HISCORE GAME_HISCORE_COMIC_BAKERY             ;#5FC9: 43 E0
        GAME_RAM_SCORE_1P GAME_SCORE_1P_COMIC_BAKERY           ;#5FCB: 49 E0
        GAME_RAM_SCORE_2P GAME_SCORE_2P_COMIC_BAKERY           ;#5FCD: 46 E0
        GAME_STATE_TRIGGER 9                                   ;#5FCF: 09

GAME_DATA_HYPER_SPORTS_1:
        ; Per-game data record for RC-715 Hyper Sports 1
        GAME_RC_CODE RC_GAME_HYPER_SPORTS_1                    ;#5FD0: 07 15
        GAME_HEADER HEADER_NONE                                ;#5FD2: 00
        GAME_VARIANT VARIANT_NO                                ;#5FD3: 00
        GAME_STATE_POINTER GAME_STATE_HYPER_SPORTS_1           ;#5FD4: 00 E0
        GAME_RAM_RANKING GAME_RANKING_HYPER_SPORTS_1           ;#5FD6: 02 E0
        GAME_RAM_LIVES 0                                       ;#5FD8: 00 00
        GAME_RAM_STAGE GAME_STAGE_HYPER_SPORTS_1               ;#5FDA: 52 E0
        GAME_RAM_HISCORE GAME_HISCORE_HYPER_SPORTS_1           ;#5FDC: 44 E0
        GAME_RAM_SCORE_1P GAME_SCORE_1P_HYPER_SPORTS_1         ;#5FDE: 4A E0
        GAME_RAM_SCORE_2P GAME_SCORE_2P_HYPER_SPORTS_1         ;#5FE0: 47 E0
        GAME_STATE_TRIGGER 9                                   ;#5FE2: 09

GAME_DATA_CABBAGE_PATCH_KIDS:
        ; Per-game data record for RC-716 Cabbage Patch Kids
        GAME_RC_CODE RC_GAME_CABBAGE_PATCH_KIDS                ;#5FE3: 07 16
        GAME_HEADER HEADER_NONE                                ;#5FE5: 00
        GAME_VARIANT VARIANT_NO                                ;#5FE6: 00
        GAME_STATE_POINTER GAME_STATE_CABBAGE_PATCH_KIDS       ;#5FE7: 00 E0
        GAME_RAM_RANKING GAME_RANKING_CABBAGE_PATCH_KIDS       ;#5FE9: 02 E0
        GAME_RAM_LIVES GAME_LIVES_CABBAGE_PATCH_KIDS           ;#5FEB: 50 E0
        GAME_RAM_STAGE GAME_STAGE_CABBAGE_PATCH_KIDS           ;#5FED: 51 E0
        GAME_RAM_HISCORE GAME_HISCORE_CABBAGE_PATCH_KIDS       ;#5FEF: 46 E0
        GAME_RAM_SCORE_1P GAME_SCORE_1P_CABBAGE_PATCH_KIDS     ;#5FF1: 49 E0
        GAME_RAM_SCORE_2P GAME_SCORE_2P_CABBAGE_PATCH_KIDS     ;#5FF3: 4C E0
        GAME_STATE_TRIGGER 9                                   ;#5FF5: 09

GAME_DATA_HYPER_SPORTS_2:
        ; Per-game data record for RC-717 Hyper Sports 2
        GAME_RC_CODE RC_GAME_HYPER_SPORTS_2                    ;#5FF6: 07 17
        GAME_HEADER HEADER_NONE                                ;#5FF8: 00
        GAME_VARIANT VARIANT_NO                                ;#5FF9: 00
        GAME_STATE_POINTER GAME_STATE_HYPER_SPORTS_2           ;#5FFA: 00 E0
        GAME_RAM_RANKING 0                                     ;#5FFC: 00 00
        GAME_RAM_LIVES 0                                       ;#5FFE: 00 00
        GAME_RAM_STAGE GAME_STAGE_HYPER_SPORTS_2               ;#6000: 80 E0
        GAME_RAM_HISCORE GAME_HISCORE_HYPER_SPORTS_2           ;#6002: 60 E0
        GAME_RAM_SCORE_1P GAME_SCORE_1P_HYPER_SPORTS_2         ;#6004: 63 E0
        GAME_RAM_SCORE_2P 0                                    ;#6006: 00 00
        GAME_STATE_TRIGGER 4                                   ;#6008: 04

GAME_DATA_HYPER_RALLY:
        ; Per-game data record for RC-718 Hyper Rally
        GAME_RC_CODE RC_GAME_HYPER_RALLY                       ;#6009: 07 18
        GAME_HEADER HEADER_NONE                                ;#600B: 00
        GAME_VARIANT VARIANT_NO                                ;#600C: 00
        GAME_STATE_POINTER GAME_STATE_HYPER_RALLY              ;#600D: 00 E0
        GAME_RAM_RANKING 0                                     ;#600F: 00 00
        GAME_RAM_LIVES 0                                       ;#6011: 00 00
        GAME_RAM_STAGE GAME_STAGE_HYPER_RALLY                  ;#6013: 60 E0
        GAME_RAM_HISCORE GAME_HISCORE_HYPER_RALLY              ;#6015: 55 E0
        GAME_RAM_SCORE_1P GAME_SCORE_1P_HYPER_RALLY            ;#6017: 58 E0
        GAME_RAM_SCORE_2P 0                                    ;#6019: 00 00
        GAME_STATE_TRIGGER 4                                   ;#601B: 04

GAME_DATA_TENNIS:
        ; Per-game data record for RC-720 Konami's Tennis (zeroed: no cheats wired)
        GAME_RC_CODE RC_GAME_TENNIS                            ;#601C: 07 20
        GAME_HEADER HEADER_NONE                                ;#601E: 00
        GAME_VARIANT VARIANT_NO                                ;#601F: 00
        GAME_STATE_POINTER 0                                   ;#6020: 00 00
        GAME_RAM_RANKING 0                                     ;#6022: 00 00
        GAME_RAM_LIVES 0                                       ;#6024: 00 00
        GAME_RAM_STAGE 0                                       ;#6026: 00 00
        GAME_RAM_HISCORE 0                                     ;#6028: 00 00
        GAME_RAM_SCORE_1P 0                                    ;#602A: 00 00
        GAME_RAM_SCORE_2P 0                                    ;#602C: 00 00
        GAME_STATE_TRIGGER 0                                   ;#602E: 00

GAME_DATA_SKY_JAGUAR:
        ; Per-game data record for RC-721 Sky Jaguar
        GAME_RC_CODE RC_GAME_SKY_JAGUAR                        ;#602F: 07 21
        GAME_HEADER HEADER_NONE                                ;#6031: 00
        GAME_VARIANT VARIANT_NO                                ;#6032: 00
        GAME_STATE_POINTER GAME_STATE_SKY_JAGUAR               ;#6033: 00 E0
        GAME_RAM_RANKING 0                                     ;#6035: 00 00
        GAME_RAM_LIVES GAME_LIVES_SKY_JAGUAR                   ;#6037: 50 E0
        GAME_RAM_STAGE GAME_STAGE_SKY_JAGUAR                   ;#6039: 51 E0
        GAME_RAM_HISCORE GAME_HISCORE_SKY_JAGUAR               ;#603B: 43 E0
        GAME_RAM_SCORE_1P GAME_SCORE_1P_SKY_JAGUAR             ;#603D: 49 E0
        GAME_RAM_SCORE_2P 0                                    ;#603F: 00 00
        GAME_STATE_TRIGGER 4                                   ;#6041: 04

GAME_DATA_GOLF:
        ; Per-game data record for RC-723 Konami's Golf (zeroed: no cheats wired)
        GAME_RC_CODE RC_GAME_GOLF                              ;#6042: 07 23
        GAME_HEADER HEADER_NONE                                ;#6044: 00
        GAME_VARIANT VARIANT_NO                                ;#6045: 00
        GAME_STATE_POINTER 0                                   ;#6046: 00 00
        GAME_RAM_RANKING 0                                     ;#6048: 00 00
        GAME_RAM_LIVES 0                                       ;#604A: 00 00
        GAME_RAM_STAGE 0                                       ;#604C: 00 00
        GAME_RAM_HISCORE 0                                     ;#604E: 00 00
        GAME_RAM_SCORE_1P 0                                    ;#6050: 00 00
        GAME_RAM_SCORE_2P 0                                    ;#6052: 00 00
        GAME_STATE_TRIGGER 0                                   ;#6054: 00

GAME_DATA_BASEBALL:
        ; Per-game data record for RC-724 Konami's Baseball (zeroed: no cheats wired)
        GAME_RC_CODE RC_GAME_BASEBALL                          ;#6055: 07 24
        GAME_HEADER HEADER_NONE                                ;#6057: 00
        GAME_VARIANT VARIANT_NO                                ;#6058: 00
        GAME_STATE_POINTER 0                                   ;#6059: 00 00
        GAME_RAM_RANKING 0                                     ;#605B: 00 00
        GAME_RAM_LIVES 0                                       ;#605D: 00 00
        GAME_RAM_STAGE 0                                       ;#605F: 00 00
        GAME_RAM_HISCORE 0                                     ;#6061: 00 00
        GAME_RAM_SCORE_1P 0                                    ;#6063: 00 00
        GAME_RAM_SCORE_2P 0                                    ;#6065: 00 00
        GAME_STATE_TRIGGER 0                                   ;#6067: 00

GAME_DATA_YIE_AR_KUNG_FU:
        ; Per-game data record for RC-725 Yie Ar Kung-Fu
        GAME_RC_CODE RC_GAME_YIE_AR_KUNG_FU                    ;#6068: 07 25
        GAME_HEADER HEADER_NONE                                ;#606A: 00
        GAME_VARIANT VARIANT_NO                                ;#606B: 00
        GAME_STATE_POINTER GAME_STATE_YIE_AR_KUNG_FU           ;#606C: 00 E0
        GAME_RAM_RANKING 0                                     ;#606E: 00 00
        GAME_RAM_LIVES GAME_LIVES_YIE_AR_KUNG_FU               ;#6070: 50 E0
        GAME_RAM_STAGE GAME_STAGE_YIE_AR_KUNG_FU               ;#6072: 51 E0
        GAME_RAM_HISCORE GAME_HISCORE_YIE_AR_KUNG_FU           ;#6074: 43 E0
        GAME_RAM_SCORE_1P GAME_SCORE_1P_YIE_AR_KUNG_FU         ;#6076: 49 E0
        GAME_RAM_SCORE_2P 0                                    ;#6078: 00 00
        GAME_STATE_TRIGGER 4                                   ;#607A: 04

GAME_DATA_KINGS_VALLEY:
        ; Per-game data record for RC-727 King's Valley
        GAME_RC_CODE RC_GAME_KINGS_VALLEY                      ;#607B: 07 27
        GAME_HEADER HEADER_NONE                                ;#607D: 00
        GAME_VARIANT VARIANT_NO                                ;#607E: 00
        GAME_STATE_POINTER GAME_STATE_KINGS_VALLEY             ;#607F: 00 E0
        GAME_RAM_RANKING 0                                     ;#6081: 00 00
        GAME_RAM_LIVES GAME_LIVES_KINGS_VALLEY                 ;#6083: 50 E0
        GAME_RAM_STAGE GAME_STAGE_KINGS_VALLEY                 ;#6085: 51 E0
        GAME_RAM_HISCORE GAME_HISCORE_KINGS_VALLEY             ;#6087: 43 E0
        GAME_RAM_SCORE_1P GAME_SCORE_1P_KINGS_VALLEY           ;#6089: 49 E0
        GAME_RAM_SCORE_2P 0                                    ;#608B: 00 00
        GAME_STATE_TRIGGER 4                                   ;#608D: 04

GAME_DATA_MOPIRANGER:
        ; Per-game data record for RC-728 Mopiranger
        GAME_RC_CODE RC_GAME_MOPIRANGER                        ;#608E: 07 28
        GAME_HEADER HEADER_NONE                                ;#6090: 00
        GAME_VARIANT VARIANT_NO                                ;#6091: 00
        GAME_STATE_POINTER GAME_STATE_MOPIRANGER               ;#6092: 00 E0
        GAME_RAM_RANKING GAME_RANKING_MOPIRANGER               ;#6094: 01 E0
        GAME_RAM_LIVES GAME_LIVES_MOPIRANGER                   ;#6096: 50 E0
        GAME_RAM_STAGE GAME_STAGE_MOPIRANGER                   ;#6098: 53 E0
        GAME_RAM_HISCORE GAME_HISCORE_MOPIRANGER               ;#609A: 47 E0
        GAME_RAM_SCORE_1P GAME_SCORE_1P_MOPIRANGER             ;#609C: 4D E0
        GAME_RAM_SCORE_2P 0                                    ;#609E: 00 00
        GAME_STATE_TRIGGER 4                                   ;#60A0: 04

GAME_DATA_PIPPOLS:
        ; Per-game data record for RC-729 Pippols
        GAME_RC_CODE RC_GAME_PIPPOLS                           ;#60A1: 07 29
        GAME_HEADER HEADER_NONE                                ;#60A3: 00
        GAME_VARIANT VARIANT_NO                                ;#60A4: 00
        GAME_STATE_POINTER GAME_STATE_PIPPOLS                  ;#60A5: 00 E0
        GAME_RAM_RANKING 0                                     ;#60A7: 00 00
        GAME_RAM_LIVES GAME_LIVES_PIPPOLS                      ;#60A9: 50 E0
        GAME_RAM_STAGE GAME_STAGE_PIPPOLS                      ;#60AB: 51 E0
        GAME_RAM_HISCORE GAME_HISCORE_PIPPOLS                  ;#60AD: 43 E0
        GAME_RAM_SCORE_1P GAME_SCORE_1P_PIPPOLS                ;#60AF: 46 E0
        GAME_RAM_SCORE_2P 0                                    ;#60B1: 00 00
        GAME_STATE_TRIGGER 4                                   ;#60B3: 04

GAME_DATA_ROAD_FIGHTER:
        ; Per-game data record for RC-730 Road Fighter
        GAME_RC_CODE RC_GAME_ROAD_FIGHTER                      ;#60B4: 07 30
        GAME_HEADER HEADER_NONE                                ;#60B6: 00
        GAME_VARIANT VARIANT_NO                                ;#60B7: 00
        GAME_STATE_POINTER GAME_STATE_ROAD_FIGHTER             ;#60B8: 00 E0
        GAME_RAM_RANKING GAME_RANKING_ROAD_FIGHTER             ;#60BA: 02 E0
        GAME_RAM_LIVES 0                                       ;#60BC: 00 00
        GAME_RAM_STAGE GAME_STAGE_ROAD_FIGHTER                 ;#60BE: 43 E0
        GAME_RAM_HISCORE GAME_HISCORE_ROAD_FIGHTER             ;#60C0: 3C E0
        GAME_RAM_SCORE_1P GAME_SCORE_1P_ROAD_FIGHTER           ;#60C2: 3F E0
        GAME_RAM_SCORE_2P 0                                    ;#60C4: 00 00
        GAME_STATE_TRIGGER 3                                   ;#60C6: 03

GAME_DATA_PING_PONG:
        ; Per-game data record for RC-731 Konami's Ping-Pong (zeroed: no cheats wired)
        GAME_RC_CODE RC_GAME_PING_PONG                         ;#60C7: 07 31
        GAME_HEADER HEADER_NONE                                ;#60C9: 00
        GAME_VARIANT VARIANT_NO                                ;#60CA: 00
        GAME_STATE_POINTER 0                                   ;#60CB: 00 00
        GAME_RAM_RANKING 0                                     ;#60CD: 00 00
        GAME_RAM_LIVES 0                                       ;#60CF: 00 00
        GAME_RAM_STAGE 0                                       ;#60D1: 00 00
        GAME_RAM_HISCORE 0                                     ;#60D3: 00 00
        GAME_RAM_SCORE_1P 0                                    ;#60D5: 00 00
        GAME_RAM_SCORE_2P 0                                    ;#60D7: 00 00
        GAME_STATE_TRIGGER 0                                   ;#60D9: 00

GAME_DATA_HYPER_SPORTS_3:
        ; Per-game data record for RC-733 Hyper Sports 3
        GAME_RC_CODE RC_GAME_HYPER_SPORTS_3                    ;#60DA: 07 33
        GAME_HEADER HEADER_NONE                                ;#60DC: 00
        GAME_VARIANT VARIANT_NO                                ;#60DD: 00
        GAME_STATE_POINTER GAME_STATE_HYPER_SPORTS_3           ;#60DE: 00 E0
        GAME_RAM_RANKING GAME_RANKING_HYPER_SPORTS_3           ;#60E0: 02 E0
        GAME_RAM_LIVES 0                                       ;#60E2: 00 00
        GAME_RAM_STAGE GAME_STAGE_HYPER_SPORTS_3               ;#60E4: 6A E0
        GAME_RAM_HISCORE GAME_HISCORE_HYPER_SPORTS_3           ;#60E6: 60 E0
        GAME_RAM_SCORE_1P GAME_SCORE_1P_HYPER_SPORTS_3         ;#60E8: 66 E0
        GAME_RAM_SCORE_2P GAME_SCORE_2P_HYPER_SPORTS_3         ;#60EA: 63 E0
        GAME_STATE_TRIGGER 4                                   ;#60EC: 04

ADD_A_TO_HL:
        ; HL += A (zero-extended); used for indexing 1-byte-stride tables
        add     a,l                                            ;#60ED: 85
        ld      l,a                                            ;#60EE: 6F
        ret     nc                                             ;#60EF: D0
        inc     h                                              ;#60F0: 24
        ret                                                    ;#60F1: C9

INIT_VDP_REGISTERS:
        ; Program VDP registers 0..7 from INITIAL_VDP_REGISTERS via BIOS_WRTVDP
        ld      hl,INITIAL_VDP_REGISTERS                       ;#60F2: 21 03 61
        ld      bc,800h                                        ;#60F5: 01 00 08
INIT_VDP_REGISTERS_LOOP:
        ; Per-register loop: read INITIAL_VDP_REGISTERS byte, WRTVDP, dec C
        push    bc                                             ;#60F8: C5
        ld      b,(hl)                                         ;#60F9: 46
        call    BIOS_WRTVDP                                    ;#60FA: CD 47 00
        pop     bc                                             ;#60FD: C1
        inc     hl                                             ;#60FE: 23
        inc     c                                              ;#60FF: 0C
        djnz    INIT_VDP_REGISTERS_LOOP                        ;#6100: 10 F6
        ret                                                    ;#6102: C9

INITIAL_VDP_REGISTERS:
        ; 8-byte VDP register init table (R0..R7) for SCREEN-2 mode used by the cart UI
        db      2    ; R0: SCREEN 2                            ;#6103: 02
        db      0E2h    ; R1: 16K, display on, IE, sprite 16×16 ;#6104: E2
        db      0Eh    ; R2: name table = 3800h                ;#6105: 0E
        db      7Fh    ; R3: colour table = 2000h              ;#6106: 7F
        db      7    ; R4: pattern base = 0                    ;#6107: 07
        db      76h    ; R5: sprite attr = 3B00h               ;#6108: 76
        db      3    ; R6: sprite pattern = 1800h              ;#6109: 03
        db      0E1h    ; R7: backdrop = white on black        ;#610A: E1

DRAW_TEXT_STREAM_BLANK:
        ; Same as DRAW_TEXT_STREAM but AND-mask=0: writes 0 through the layout to erase
        ld      c,0                                            ;#610B: 0E 00
        jr      DRAW_TEXT_STREAM_FETCH_TARGET                  ;#610D: 18 06

DRAW_TEXT_STREAM_AT_DE:
        ; Continue/draw a text stream with VRAM dst already in DE (no leading dw target)
        ld      c,0FFh                                         ;#610F: 0E FF
        jr      DRAW_TEXT_STREAM_BYTE_LOOP                     ;#6111: 18 06

DRAW_TEXT_STREAM:
        ; Render encoded text stream: word VRAM target + bytes (FE=retarget, FF=end)
        ld      c,0FFh                                         ;#6113: 0E FF
DRAW_TEXT_STREAM_FETCH_TARGET:
        ; Sub-entry: re-read dw target from (HL), then fall into byte loop
        ld      e,(hl)                                         ;#6115: 5E
        inc     hl                                             ;#6116: 23
        ld      d,(hl)                                         ;#6117: 56
        inc     hl                                             ;#6118: 23
DRAW_TEXT_STREAM_BYTE_LOOP:
        ; Byte loop: FE -> new target; FF -> ret; else write byte to VRAM[DE]
        ld      a,(hl)                                         ;#6119: 7E
        inc     hl                                             ;#611A: 23
        ld      b,a                                            ;#611B: 47
        inc     b                                              ;#611C: 04
        ret     z                                              ;#611D: C8
        inc     b                                              ;#611E: 04
        jr      z,DRAW_TEXT_STREAM_FETCH_TARGET                ;#611F: 28 F4
        and     c                                              ;#6121: A1
        ex      de,hl                                          ;#6122: EB
        call    BIOS_WRTVRM                                    ;#6123: CD 4D 00
        ex      de,hl                                          ;#6126: EB
        inc     de                                             ;#6127: 13
        jr      DRAW_TEXT_STREAM_BYTE_LOOP                     ;#6128: 18 EF

CLEAR_NAME_TABLE:
        ; Fill VRAM Screen-1 name table (3800h, 768 bytes) with 0
        LOAD_NAME_TABLE hl, 0, 0                               ;#612A: 21 00 38
        ld      bc,300h                                        ;#612D: 01 00 03
        xor     a                                              ;#6130: AF
        call    BIOS_FILVRM                                    ;#6131: CD 56 00
        LOAD_NAME_TABLE hl, 24, 0                              ;#6134: 21 00 3B
        ld      a,0D0h                                         ;#6137: 3E D0
        jp      BIOS_WRTVRM                                    ;#6139: C3 4D 00

FILVRM_3_BANKS:
        ; BIOS_FILVRM helper that fills the same range in all three pattern banks
        ld      d,3                                            ;#613C: 16 03
FILVRM_3_BANKS_LOOP:
        ; Per-bank iteration: push regs, call BIOS_FILVRM, advance DE by 800h
        push    bc                                             ;#613E: C5
        push    de                                             ;#613F: D5
        call    BIOS_FILVRM                                    ;#6140: CD 56 00
        ld      bc,800h                                        ;#6143: 01 00 08
        add     hl,bc                                          ;#6146: 09
        pop     de                                             ;#6147: D1
        pop     bc                                             ;#6148: C1
        dec     d                                              ;#6149: 15
        jr      nz,FILVRM_3_BANKS_LOOP                         ;#614A: 20 F2
        ret                                                    ;#614C: C9

LDIRVM_TO_3_BLOCKS:
        ; Repeat LDIRVM 3 times advancing DE by 800h each iteration (3 pattern banks)
        ld      a,3                                            ;#614D: 3E 03
LDIRVM_3_BANKS_LOOP:
        ; Per-bank LDIRVM: push regs, copy bytes, advance DE by 800h, djnz
        push    af                                             ;#614F: F5
        push    bc                                             ;#6150: C5
        push    hl                                             ;#6151: E5
        push    de                                             ;#6152: D5
        call    BIOS_LDIRVM                                    ;#6153: CD 5C 00
        pop     de                                             ;#6156: D1
        ld      hl,800h                                        ;#6157: 21 00 08
        add     hl,de                                          ;#615A: 19
        ex      de,hl                                          ;#615B: EB
        pop     hl                                             ;#615C: E1
        pop     bc                                             ;#615D: C1
        pop     af                                             ;#615E: F1
        dec     a                                              ;#615F: 3D
        jr      nz,LDIRVM_3_BANKS_LOOP                         ;#6160: 20 ED
        ret                                                    ;#6162: C9

LOAD_PATTERN_TO_VRAM_3_BANKS:
        ; Copy the pattern stream to all three Screen-2 pattern banks
        ld      b,3                                            ;#6163: 06 03
LOAD_PATTERN_TO_VRAM_LOOP:
        ; Per-bank body: push regs, call DECOMPRESS_RLE_TO_VRAM, restore for next bank
        push    bc                                             ;#6165: C5
        push    hl                                             ;#6166: E5
        push    de                                             ;#6167: D5
        call    DECOMPRESS_RLE_TO_VRAM                         ;#6168: CD 7A 61
        pop     de                                             ;#616B: D1
        ld      hl,800h                                        ;#616C: 21 00 08
        add     hl,de                                          ;#616F: 19
        ex      de,hl                                          ;#6170: EB
        pop     hl                                             ;#6171: E1
        pop     bc                                             ;#6172: C1
        djnz    LOAD_PATTERN_TO_VRAM_LOOP                      ;#6173: 10 F0
        ret                                                    ;#6175: C9

DECOMPRESS_RLE_WITH_TARGET:
        ; Reads a 2-byte VRAM target from the stream first, then RLE-decompresses
        ld      e,(hl)                                         ;#6176: 5E
        inc     hl                                             ;#6177: 23
        ld      d,(hl)                                         ;#6178: 56
        inc     hl                                             ;#6179: 23
DECOMPRESS_RLE_TO_VRAM:
        ; Stream HL through a VRAM RLE decoder (bit7=0 run, bit7=1 literal); DE=VRAM dest
        ex      de,hl                                          ;#617A: EB
        call    BIOS_SETWRT                                    ;#617B: CD 53 00
        ex      de,hl                                          ;#617E: EB
        ld      a,(BIOS_VDP_DR)                                ;#617F: 3A 06 00
        ld      c,a                                            ;#6182: 4F
DECOMPRESS_RLE_LOOP:
        ; Per-control-byte body: bit7 set -> copy run; else literal write to VRAM
        ld      a,(hl)                                         ;#6183: 7E
        and     7Fh                                            ;#6184: E6 7F
        ld      b,a                                            ;#6186: 47
        ld      a,(hl)                                         ;#6187: 7E
        inc     hl                                             ;#6188: 23
        jr      nz,DECOMPRESS_RLE_LITERAL                      ;#6189: 20 04
        cp      b                                              ;#618B: B8
        jr      nz,DECOMPRESS_RLE_WITH_TARGET                  ;#618C: 20 E8
        ret                                                    ;#618E: C9

DECOMPRESS_RLE_LITERAL:
        ; Literal-stream branch: emit B bytes verbatim through the VDP data port
        cp      b                                              ;#618F: B8
        jr      z,DECOMPRESS_RLE_RUN                           ;#6190: 28 0B
DECOMPRESS_RLE_LITERAL_BYTE:
        ; Per-byte body: emit (HL), inc HL, djnz back
        ld      a,(hl)                                         ;#6192: 7E
        inc     hl                                             ;#6193: 23
        out     (c),a                                          ;#6194: ED 79
        inc     de                                             ;#6196: 13
        push    hl                                             ;#6197: E5
        pop     hl                                             ;#6198: E1
        djnz    DECOMPRESS_RLE_LITERAL_BYTE                    ;#6199: 10 F7
        jr      DECOMPRESS_RLE_LOOP                            ;#619B: 18 E6

DECOMPRESS_RLE_RUN:
        ; Run-stream branch: fetch repeat byte, emit B copies
        ld      a,(hl)                                         ;#619D: 7E
        inc     hl                                             ;#619E: 23
DECOMPRESS_RLE_OUT_RUN:
        ; Output one byte of the current run (out (c),a; inc de)
        out     (c),a                                          ;#619F: ED 79
        inc     de                                             ;#61A1: 13
        push    ix                                             ;#61A2: DD E5
        pop     ix                                             ;#61A4: DD E1
        djnz    DECOMPRESS_RLE_OUT_RUN                         ;#61A6: 10 F7
        jr      DECOMPRESS_RLE_LOOP                            ;#61A8: 18 D9

FILVRM_RANGE:
        ; Fill B rows × C bytes at VRAM (HL) with A; +32 per row (screen-1 stride)
        push    bc                                             ;#61AA: C5
        ld      b,0                                            ;#61AB: 06 00
        push    af                                             ;#61AD: F5
        call    BIOS_FILVRM                                    ;#61AE: CD 56 00
        pop     af                                             ;#61B1: F1
        ld      bc,20h                                         ;#61B2: 01 20 00
        add     hl,bc                                          ;#61B5: 09
        pop     bc                                             ;#61B6: C1
        djnz    FILVRM_RANGE                                   ;#61B7: 10 F1
        ret                                                    ;#61B9: C9

BIN16_TO_BCD16:
        ; Convert HL (binary) -> DE (packed BCD) via 16-step double-dabble
        ld      b,10h                                          ;#61BA: 06 10
        ld      de,0                                           ;#61BC: 11 00 00
BIN16_TO_BCD16_LOOP:
        ; Per-bit body: shift HL, adc+daa per BCD digit, djnz back
        add     hl,hl                                          ;#61BF: 29
        ld      a,e                                            ;#61C0: 7B
        adc     a,a                                            ;#61C1: 8F
        daa                                                    ;#61C2: 27
        ld      e,a                                            ;#61C3: 5F
        ld      a,d                                            ;#61C4: 7A
        adc     a,a                                            ;#61C5: 8F
        daa                                                    ;#61C6: 27
        ld      d,a                                            ;#61C7: 57
        djnz    BIN16_TO_BCD16_LOOP                            ;#61C8: 10 F5
        ret                                                    ;#61CA: C9

BCD_TO_BIN8:
        ; Convert A (packed-BCD byte hi:lo) -> A (binary hi*10+lo)
        ld      c,a                                            ;#61CB: 4F
        and     0F0h                                           ;#61CC: E6 F0
        rrca                                                   ;#61CE: 0F
        rrca                                                   ;#61CF: 0F
        rrca                                                   ;#61D0: 0F
        rrca                                                   ;#61D1: 0F
        add     a,a                                            ;#61D2: 87
        ld      b,a                                            ;#61D3: 47
        add     a,a                                            ;#61D4: 87
        add     a,a                                            ;#61D5: 87
        add     a,b                                            ;#61D6: 80
        ld      b,a                                            ;#61D7: 47
        ld      a,c                                            ;#61D8: 79
        and     0Fh                                            ;#61D9: E6 0F
        add     a,b                                            ;#61DB: 80
        ret                                                    ;#61DC: C9

CLEAR_MENU_DISPLAY_AREA:
        ; FILVRM 613h bytes of 0 at SUBMENU_BODY_VRAM_BASE — wipe the menu body
        ld      bc,613h                                        ;#61DD: 01 13 06
        ld      hl,(SUBMENU_BODY_VRAM_BASE)                    ;#61E0: 2A 6E D1
        xor     a                                              ;#61E3: AF
        jp      FILVRM_RANGE                                   ;#61E4: C3 AA 61

CALL_INDIRECT_A:
        ; Pop return addr as table base, index by A (2-byte stride), jp to table[A]
        pop     hl                                             ;#61E7: E1
        add     a,a                                            ;#61E8: 87
        add     a,l                                            ;#61E9: 85
        ld      l,a                                            ;#61EA: 6F
        jr      nc,CALL_INDIRECT_A_LOAD                        ;#61EB: 30 01
        inc     h                                              ;#61ED: 24
CALL_INDIRECT_A_LOAD:
        ; Inner: load handler word from (HL); high-byte-carry merge target
        ld      e,(hl)                                         ;#61EE: 5E
        inc     hl                                             ;#61EF: 23
        ld      d,(hl)                                         ;#61F0: 56
        ex      de,hl                                          ;#61F1: EB
        jp      (hl)                                           ;#61F2: E9

SAVE_GAME_DISPLAY:
        ; Save game tiles+name-table to D8B1h/BIOS_WORK_AREA_COPY/SAVE_VRAM_NAMETABLE_*
        ld      hl,GAME_DISPLAY_SAVED                          ;#61F3: 21 2A D1
        ld      a,(hl)                                         ;#61F6: 7E
        or      a                                              ;#61F7: B7
        ret     nz                                             ;#61F8: C0
        dec     a                                              ;#61F9: 3D
        ld      (hl),a                                         ;#61FA: 77
        ld      de,SAVE_VRAM_NAMETABLE_BOT+1                   ;#61FB: 11 B1 D8
        LOAD_VRAM_ADDRESS hl, 1000h                            ;#61FE: 21 00 10
        ld      bc,80h                                         ;#6201: 01 80 00
        call    COPY_VRAM_TO_RAM_TWO_BANKS                     ;#6204: CD 55 62
        ld      de,BIOS_WORK_AREA_COPY                         ;#6207: 11 00 D5
        LOAD_VRAM_ADDRESS hl, 1180h                            ;#620A: 21 80 11
        ld      bc,158h                                        ;#620D: 01 58 01
        call    COPY_VRAM_TO_RAM_TWO_BANKS                     ;#6210: CD 55 62
        LOAD_NAME_TABLE hl, 16, 0                              ;#6213: 21 00 3A
        ld      de,SAVE_VRAM_NAMETABLE_TOP                     ;#6216: 11 B0 D7
        ld      bc,100h                                        ;#6219: 01 00 01
        call    BIOS_LDIRMV                                    ;#621C: CD 59 00
        LOAD_NAME_TABLE hl, 24, 0                              ;#621F: 21 00 3B
        ld      de,SAVE_VRAM_NAMETABLE_BOT                     ;#6222: 11 B0 D8
        ld      bc,1                                           ;#6225: 01 01 00
        call    BIOS_LDIRMV                                    ;#6228: CD 59 00
        LOAD_VRAM_ADDRESS hl, 1000h                            ;#622B: 21 00 10
        ld      bc,8                                           ;#622E: 01 08 00
        ld      a,55h                                          ;#6231: 3E 55
        call    BIOS_FILVRM                                    ;#6233: CD 56 00
        call    CLEAR_NAME_BOTTOM                              ;#6236: CD CE 62
        ld      hl,GFX_MENU_FONT_PATTERNS                      ;#6239: 21 13 51
        LOAD_VRAM_ADDRESS de, 3180h                            ;#623C: 11 80 31
        call    DECOMPRESS_RLE_TO_VRAM                         ;#623F: CD 7A 61
        LOAD_VRAM_ADDRESS hl, 1180h                            ;#6242: 21 80 11
        ld      a,0F5h                                         ;#6245: 3E F5
        ld      bc,158h                                        ;#6247: 01 58 01
        call    BIOS_FILVRM                                    ;#624A: CD 56 00
        LOAD_NAME_TABLE hl, 24, 0                              ;#624D: 21 00 3B
        ld      a,0D0h                                         ;#6250: 3E D0
        jp      BIOS_WRTVRM                                    ;#6252: C3 4D 00

COPY_VRAM_TO_RAM_TWO_BANKS:
        ; LDIRMV BC bytes, advance VRAM src by 2000h, LDIRMV BC bytes (dest continued)
        push    bc                                             ;#6255: C5
        push    de                                             ;#6256: D5
        push    hl                                             ;#6257: E5
        call    BIOS_LDIRMV                                    ;#6258: CD 59 00
        pop     hl                                             ;#625B: E1
        ld      bc,2000h                                       ;#625C: 01 00 20
        add     hl,bc                                          ;#625F: 09
        pop     de                                             ;#6260: D1
        pop     bc                                             ;#6261: C1
        ex      de,hl                                          ;#6262: EB
        add     hl,bc                                          ;#6263: 09
        ex      de,hl                                          ;#6264: EB
        jp      BIOS_LDIRMV                                    ;#6265: C3 59 00

RESTORE_GAME_DISPLAY:
        ; Restore game screen from D8B1h/BIOS_WORK_AREA_COPY/SAVE_VRAM_NAMETABLE_* to VRAM
        ld      hl,GAME_DISPLAY_SAVED                          ;#6268: 21 2A D1
        ld      a,(hl)                                         ;#626B: 7E
        or      a                                              ;#626C: B7
        ret     z                                              ;#626D: C8
        xor     a                                              ;#626E: AF
        ld      (hl),a                                         ;#626F: 77
        call    CLEAR_NAME_BOTTOM                              ;#6270: CD CE 62
        ld      hl,SAVE_VRAM_NAMETABLE_BOT+1                   ;#6273: 21 B1 D8
        LOAD_VRAM_ADDRESS de, 1000h                            ;#6276: 11 00 10
        ld      bc,80h                                         ;#6279: 01 80 00
        call    COPY_RAM_TO_VRAM_TWO_BANKS                     ;#627C: CD A3 62
        ld      hl,BIOS_WORK_AREA_COPY                         ;#627F: 21 00 D5
        LOAD_VRAM_ADDRESS de, 1180h                            ;#6282: 11 80 11
        ld      bc,158h                                        ;#6285: 01 58 01
        call    COPY_RAM_TO_VRAM_TWO_BANKS                     ;#6288: CD A3 62
        ld      hl,SAVE_VRAM_NAMETABLE_TOP                     ;#628B: 21 B0 D7
        LOAD_NAME_TABLE de, 16, 0                              ;#628E: 11 00 3A
        ld      bc,100h                                        ;#6291: 01 00 01
        call    BIOS_LDIRVM                                    ;#6294: CD 5C 00
        ld      hl,SAVE_VRAM_NAMETABLE_BOT                     ;#6297: 21 B0 D8
        LOAD_NAME_TABLE de, 24, 0                              ;#629A: 11 00 3B
        ld      bc,1                                           ;#629D: 01 01 00
        jp      BIOS_LDIRVM                                    ;#62A0: C3 5C 00

COPY_RAM_TO_VRAM_TWO_BANKS:
        ; LDIRVM BC bytes, advance VRAM dst by 2000h, LDIRVM BC bytes (src continued)
        push    bc                                             ;#62A3: C5
        push    hl                                             ;#62A4: E5
        push    de                                             ;#62A5: D5
        call    BIOS_LDIRVM                                    ;#62A6: CD 5C 00
        pop     hl                                             ;#62A9: E1
        ld      bc,2000h                                       ;#62AA: 01 00 20
        add     hl,bc                                          ;#62AD: 09
        pop     de                                             ;#62AE: D1
        pop     bc                                             ;#62AF: C1
        ex      de,hl                                          ;#62B0: EB
        add     hl,bc                                          ;#62B1: 09
        jp      BIOS_LDIRVM                                    ;#62B2: C3 5C 00

SAVE_GAME_DISPLAY_IF_GAME_ACTIVE:
        ; No-op unless GAME_DISPLAY_ACTIVE != 0, else jp SAVE_GAME_DISPLAY
        ld      a,(GAME_DISPLAY_ACTIVE)                        ;#62B5: 3A 3D D1
        or      a                                              ;#62B8: B7
        ret     z                                              ;#62B9: C8
        jp      SAVE_GAME_DISPLAY                              ;#62BA: C3 F3 61

RESTORE_GAME_DISPLAY_IF_GAME_ACTIVE:
        ; No-op unless GAME_DISPLAY_ACTIVE != 0, else jr RESTORE_GAME_DISPLAY
        ld      a,(GAME_DISPLAY_ACTIVE)                        ;#62BD: 3A 3D D1
        or      a                                              ;#62C0: B7
        ret     z                                              ;#62C1: C8
        jr      RESTORE_GAME_DISPLAY                           ;#62C2: 18 A4

CLEAR_NAME_AREA_BY_MODE:
        ; Pick clear range from MENU_CLEAR_RANGE_THRESHOLD: if <3Ah HL=3900h else HL=3A00h
        ld      a,(MENU_CLEAR_RANGE_THRESHOLD)                 ;#62C4: 3A 6D D1
        cp      3Ah                                            ;#62C7: FE 3A
        LOAD_NAME_TABLE hl, 8, 0                               ;#62C9: 21 00 39
        jr      c,CLEAR_VRAM_100_AT_HL                         ;#62CC: 38 03
CLEAR_NAME_BOTTOM:
        ; Fill VRAM 3A00..3B00 (8 rows from row 16) with 0 — used before drawing a submenu
        LOAD_NAME_TABLE hl, 16, 0                              ;#62CE: 21 00 3A
CLEAR_VRAM_100_AT_HL:
        ; Common tail: BC=100h, A=0, jp BIOS_FILVRM — fill 256 bytes
        ld      bc,100h                                        ;#62D1: 01 00 01
        xor     a                                              ;#62D4: AF
        jp      BIOS_FILVRM                                    ;#62D5: C3 56 00

RUN_NAME_INPUT_LOOP:
        ; Interactive name editor: BIOS_CHGET loop accepting 0-9, A-Z, RETURN, BS
        ld      (NAME_INPUT_FE_FLAG),a                         ;#62D8: 32 67 D1
        or      a                                              ;#62DB: B7
        ld      a,b                                            ;#62DC: 78
        jr      nz,NAME_INPUT_SETUP_DONE                       ;#62DD: 20 02
        ld      a,8                                            ;#62DF: 3E 08
NAME_INPUT_SETUP_DONE:
        ; Store A (max index, 8 or B-from-caller) and HL (cursor VRAM) into menu state
        ld      (MENU_MAX_INDEX),a                             ;#62E1: 32 64 D1
        ld      (MENU_CURSOR_VRAM_ADDR),hl                     ;#62E4: 22 68 D1
        ld      (MENU_TABLE_PTR),hl                            ;#62E7: 22 6A D1
        call    DRAW_MENU_CURSOR                               ;#62EA: CD E8 63
        call    CLEAR_NAME_INPUT_BUFFER                        ;#62ED: CD AA 63
NAME_INPUT_WAIT_KEY:
        ; Inner BIOS_CHGET wait-for-keypress entry of RUN_NAME_INPUT_LOOP
        call    BIOS_CHGET                                     ;#62F0: CD 9F 00
        cp      CHAR_RETURN                                    ;#62F3: FE 0D
        ld      b,a                                            ;#62F5: 47
        jr      nz,NAME_INPUT_KEY_BACKSPACE                    ;#62F6: 20 08
        ld      a,(MENU_CURRENT_INDEX)                         ;#62F8: 3A 65 D1
        ld      (MENU_SELECTED_INDEX),a                        ;#62FB: 32 63 D1
        or      a                                              ;#62FE: B7
        ret                                                    ;#62FF: C9

NAME_INPUT_KEY_BACKSPACE:
        ; Inner key-decode: check for backspace (1Dh)
        cp      CHAR_KEY_LEFT                                  ;#6300: FE 1D
        jr      z,NAME_INPUT_DO_BACKSPACE                      ;#6302: 28 04
        cp      CHAR_BACKSPACE                                 ;#6304: FE 08
        jr      nz,NAME_INPUT_KEY_DOT                          ;#6306: 20 25
NAME_INPUT_DO_BACKSPACE:
        ; Backspace path: bound-check, erase char, decrement cursor
        call    NAME_INPUT_BACKSPACE_GUARD                     ;#6308: CD F7 63
        ld      a,(MENU_CURRENT_INDEX)                         ;#630B: 3A 65 D1
        ld      hl,SAVED_GAME_ID                               ;#630E: 21 41 D1
        call    ADD_A_TO_HL                                    ;#6311: CD ED 60
        ld      a,(hl)                                         ;#6314: 7E
        sub     3Ch                                            ;#6315: D6 3C
        jr      nz,NAME_INPUT_DEC_CURSOR                       ;#6317: 20 03
        ld      (NAME_INPUT_DECIMAL_FLAG),a                    ;#6319: 32 66 D1
NAME_INPUT_DEC_CURSOR:
        ; Decrement MENU_CURRENT_INDEX after backspace
        ld      hl,MENU_CURRENT_INDEX                          ;#631C: 21 65 D1
        dec     (hl)                                           ;#631F: 35
        call    ERASE_MENU_CURSOR                              ;#6320: CD F0 63
        dec     hl                                             ;#6323: 2B
        ld      (MENU_CURSOR_VRAM_ADDR),hl                     ;#6324: 22 68 D1
        call    DRAW_MENU_CURSOR                               ;#6327: CD E8 63
        jp      NAME_INPUT_WAIT_KEY                            ;#632A: C3 F0 62

NAME_INPUT_KEY_DOT:
        ; Check for '.' (2Eh) — toggles NAME_INPUT_DECIMAL_FLAG
        cp      2Eh                                            ;#632D: FE 2E
        jr      nz,NAME_INPUT_KEY_DIGIT                        ;#632F: 20 17
        ld      a,(NAME_INPUT_FE_FLAG)                         ;#6331: 3A 67 D1
        cp      0FEh                                           ;#6334: FE FE
        jp      nz,NAME_INPUT_WAIT_KEY                         ;#6336: C2 F0 62
        call    NAME_INPUT_BACKSPACE_GUARD                     ;#6339: CD F7 63
        ld      a,3Ch                                          ;#633C: 3E 3C
        ld      hl,NAME_INPUT_DECIMAL_FLAG                     ;#633E: 21 66 D1
        cp      (hl)                                           ;#6341: BE
        jp      z,NAME_INPUT_WAIT_KEY                          ;#6342: CA F0 62
        ld      (hl),a                                         ;#6345: 77
        jr      NAME_INPUT_STORE_CHAR                          ;#6346: 18 2A

NAME_INPUT_KEY_DIGIT:
        ; Check for digit 0-9; valid → store as char
        ld      c,a                                            ;#6348: 4F
        sub     30h                                            ;#6349: D6 30
        cp      0Ah                                            ;#634B: FE 0A
        jr      nc,NAME_INPUT_KEY_UPPER                        ;#634D: 30 03
        ld      a,c                                            ;#634F: 79
        jr      NAME_INPUT_STORE_CHAR                          ;#6350: 18 20

NAME_INPUT_KEY_UPPER:
        ; Check for letter A-Z; valid → store as char
        ld      a,c                                            ;#6352: 79
        sub     41h                                            ;#6353: D6 41
        cp      1Ah                                            ;#6355: FE 1A
        jr      nc,NAME_INPUT_KEY_LOWER                        ;#6357: 30 0C
        ld      a,c                                            ;#6359: 79
NAME_INPUT_FILTER_FE_ESCAPE:
        ; When NAME_INPUT_FE_FLAG=FFh wait; else restore A=typed digit and fall into store
        ex      af,af'                                         ;#635A: 08
        ld      a,(NAME_INPUT_FE_FLAG)                         ;#635B: 3A 67 D1
        inc     a                                              ;#635E: 3C
        jp      z,NAME_INPUT_WAIT_KEY                          ;#635F: CA F0 62
        ex      af,af'                                         ;#6362: 08
        jr      NAME_INPUT_STORE_CHAR                          ;#6363: 18 0D

NAME_INPUT_KEY_LOWER:
        ; Check for letter a-z; convert to upper and store
        ld      a,c                                            ;#6365: 79
        sub     61h                                            ;#6366: D6 61
        cp      1Ah                                            ;#6368: FE 1A
        jp      nc,NAME_INPUT_WAIT_KEY                         ;#636A: D2 F0 62
        ld      a,c                                            ;#636D: 79
        sub     20h                                            ;#636E: D6 20
        jr      NAME_INPUT_FILTER_FE_ESCAPE                    ;#6370: 18 E8

NAME_INPUT_STORE_CHAR:
        ; Store B at name buffer + MENU_CURRENT_INDEX; jp WAIT_KEY if at MENU_MAX_INDEX
        ld      b,a                                            ;#6372: 47
        ld      hl,MENU_CURRENT_INDEX                          ;#6373: 21 65 D1
        ld      a,(MENU_MAX_INDEX)                             ;#6376: 3A 64 D1
        cp      (hl)                                           ;#6379: BE
        jp      z,NAME_INPUT_WAIT_KEY                          ;#637A: CA F0 62
        inc     (hl)                                           ;#637D: 34
        ld      a,(hl)                                         ;#637E: 7E
        cp      1                                              ;#637F: FE 01
        jr      nz,NAME_INPUT_AFTER_TILE_CLEAR                 ;#6381: 20 0C
        push    bc                                             ;#6383: C5
        ld      hl,(MENU_TABLE_PTR)                            ;#6384: 2A 6A D1
        ld      bc,0Eh                                         ;#6387: 01 0E 00
        xor     a                                              ;#638A: AF
        call    BIOS_FILVRM                                    ;#638B: CD 56 00
        pop     bc                                             ;#638E: C1
NAME_INPUT_AFTER_TILE_CLEAR:
        ; After clearing the cursor tile: restore VRAM target from MENU_CURSOR_VRAM_ADDR
        ld      hl,(MENU_CURSOR_VRAM_ADDR)                     ;#638F: 2A 68 D1
        ld      a,b                                            ;#6392: 78
        call    BIOS_WRTVRM                                    ;#6393: CD 4D 00
        inc     hl                                             ;#6396: 23
        ld      (MENU_CURSOR_VRAM_ADDR),hl                     ;#6397: 22 68 D1
        call    DRAW_MENU_CURSOR                               ;#639A: CD E8 63
        ld      a,(MENU_CURRENT_INDEX)                         ;#639D: 3A 65 D1
        ld      hl,SAVED_GAME_ID                               ;#63A0: 21 41 D1
        call    ADD_A_TO_HL                                    ;#63A3: CD ED 60
        ld      (hl),b                                         ;#63A6: 70
        jp      NAME_INPUT_WAIT_KEY                            ;#63A7: C3 F0 62

CLEAR_NAME_INPUT_BUFFER:
        ; Zero NAME_INPUT_BUFFER..D161h (32 bytes) and patch the input cursor tiles
        ld      hl,NAME_INPUT_BUFFER                           ;#63AA: 21 42 D1
        ld      de,NAME_INPUT_BUFFER+1                         ;#63AD: 11 43 D1
        ld      (hl),0                                         ;#63B0: 36 00
        ld      bc,1Fh                                         ;#63B2: 01 1F 00
        ldir                                                   ;#63B5: ED B0
        call    PATCH_NAME_INPUT_CURSOR_TILES                  ;#63B7: CD C8 63
        call    BIOS_KILBUF                                    ;#63BA: CD 56 01
        xor     a                                              ;#63BD: AF
        ld      (MENU_SELECTED_INDEX),a                        ;#63BE: 32 63 D1
        ld      (MENU_CURRENT_INDEX),a                         ;#63C1: 32 65 D1
        ld      (NAME_INPUT_DECIMAL_FLAG),a                    ;#63C4: 32 66 D1
        ret                                                    ;#63C7: C9

PATCH_NAME_INPUT_CURSOR_TILES:
        ; Copy GFX_NAME_INPUT_CURSOR_TILE to VRAM 21D0h/31D0h per GAME_DISPLAY_ACTIVE
        ld      hl,GFX_NAME_INPUT_CURSOR_TILE                  ;#63C8: 21 E0 63
        ld      bc,8                                           ;#63CB: 01 08 00
        ld      a,(GAME_DISPLAY_ACTIVE)                        ;#63CE: 3A 3D D1
        or      a                                              ;#63D1: B7
        jr      nz,PATCH_NAME_CURSOR_GAME_PAGE                 ;#63D2: 20 06
        LOAD_VRAM_ADDRESS de, 21D0h                            ;#63D4: 11 D0 21
        jp      LDIRVM_TO_3_BLOCKS                             ;#63D7: C3 4D 61

PATCH_NAME_CURSOR_GAME_PAGE:
        ; Game-display variant: ld de,31D0h, jp BIOS_LDIRVM (page-2 mirror)
        LOAD_VRAM_ADDRESS de, 31D0h                            ;#63DA: 11 D0 31
        jp      BIOS_LDIRVM                                    ;#63DD: C3 5C 00

GFX_NAME_INPUT_CURSOR_TILE:
        ; 8-byte tile pattern (00 7F×7) — the "input position" cursor underline
        dh      "007F7F7F7F7F7F7F"                             ;#63E0: 00 7F 7F 7F 7F 7F 7F 7F

DRAW_MENU_CURSOR:
        ; Write 3Ah (':' tile) at VRAM MENU_CURSOR_VRAM_ADDR — cursor ON at current row
        ld      hl,(MENU_CURSOR_VRAM_ADDR)                     ;#63E8: 2A 68 D1
        ld      a,3Ah                                          ;#63EB: 3E 3A
        jp      BIOS_WRTVRM                                    ;#63ED: C3 4D 00

ERASE_MENU_CURSOR:
        ; Write 0 at VRAM MENU_CURSOR_VRAM_ADDR — clear cursor before redraw/advance
        ld      hl,(MENU_CURSOR_VRAM_ADDR)                     ;#63F0: 2A 68 D1
        xor     a                                              ;#63F3: AF
        jp      BIOS_WRTVRM                                    ;#63F4: C3 4D 00

NAME_INPUT_BACKSPACE_GUARD:
        ; If MENU_CURRENT_INDEX==0, pop stack and jp NAME_INPUT_WAIT_KEY
        ld      a,(MENU_CURRENT_INDEX)                         ;#63F7: 3A 65 D1
        or      a                                              ;#63FA: B7
        ret     nz                                             ;#63FB: C0
        pop     hl                                             ;#63FC: E1
        jp      NAME_INPUT_WAIT_KEY                            ;#63FD: C3 F0 62

MENU_SELECT:
        ; Walk B word-entries from (HL); cursor up/down + SPACE; return picked index in A
        ld      a,b                                            ;#6400: 78
        dec     a                                              ;#6401: 3D
        ld      (MENU_MAX_INDEX),a                             ;#6402: 32 64 D1
        ld      (MENU_TABLE_PTR),hl                            ;#6405: 22 6A D1
        ld      a,(hl)                                         ;#6408: 7E
        inc     hl                                             ;#6409: 23
        ld      h,(hl)                                         ;#640A: 66
        ld      l,a                                            ;#640B: 6F
        ld      (MENU_CURSOR_VRAM_ADDR),hl                     ;#640C: 22 68 D1
        call    DRAW_MENU_CURSOR                               ;#640F: CD E8 63
        call    MENU_SELECT_INIT                               ;#6412: CD 62 64
MENU_SELECT_KEY_POLL:
        ; Inner CHGET key-poll entry of MENU_SELECT (re-entered after each ignored key)
        call    BIOS_CHGET                                     ;#6415: CD 9F 00
        cp      CHAR_SPACE                                     ;#6418: FE 20
        ld      b,a                                            ;#641A: 47
        jr      nz,MENU_SELECT_KEY_DECODE                      ;#641B: 20 0B
        call    ERASE_MENU_CURSOR                              ;#641D: CD F0 63
        ld      a,(MENU_CURRENT_INDEX)                         ;#6420: 3A 65 D1
        ld      (MENU_SELECTED_INDEX),a                        ;#6423: 32 63 D1
        or      a                                              ;#6426: B7
        ret                                                    ;#6427: C9

MENU_SELECT_KEY_DECODE:
        ; After CHGET: A=key, C=FFh mask; dispatch on cursor / space keys
        ld      c,0FFh                                         ;#6428: 0E FF
        cp      CHAR_KEY_UP                                    ;#642A: FE 1E
        jr      z,MENU_SELECT_DOWN_PATH                        ;#642C: 28 07
        ld      c,1                                            ;#642E: 0E 01
        cp      CHAR_KEY_DOWN                                  ;#6430: FE 1F
        jp      nz,MENU_SELECT_KEY_POLL                        ;#6432: C2 15 64
MENU_SELECT_DOWN_PATH:
        ; Down-arrow path: inc MENU_CURRENT_INDEX, clamp via MENU_MAX_INDEX
        ld      hl,MENU_MAX_INDEX                              ;#6435: 21 64 D1
        ld      de,MENU_CURRENT_INDEX                          ;#6438: 11 65 D1
        ld      a,(de)                                         ;#643B: 1A
        add     a,c                                            ;#643C: 81
        jp      p,MENU_SELECT_BOUND_CHECK                      ;#643D: F2 41 64
        ld      a,(hl)                                         ;#6440: 7E
MENU_SELECT_BOUND_CHECK:
        ; Compare new index against max; if at limit fall into reset-to-0
        cp      (hl)                                           ;#6441: BE
        jr      c,MENU_SELECT_INDEX_RESET                      ;#6442: 38 03
        jr      z,MENU_SELECT_INDEX_RESET                      ;#6444: 28 01
        xor     a                                              ;#6446: AF
MENU_SELECT_INDEX_RESET:
        ; Wrap-around: store 0 and reload first position
        ld      (de),a                                         ;#6447: 12
        ld      b,a                                            ;#6448: 47
        ld      hl,(MENU_TABLE_PTR)                            ;#6449: 2A 6A D1
        add     a,a                                            ;#644C: 87
        call    ADD_A_TO_HL                                    ;#644D: CD ED 60
        ld      a,(hl)                                         ;#6450: 7E
        inc     hl                                             ;#6451: 23
        ld      h,(hl)                                         ;#6452: 66
        ld      l,a                                            ;#6453: 6F
        push    hl                                             ;#6454: E5
        call    ERASE_MENU_CURSOR                              ;#6455: CD F0 63
        pop     hl                                             ;#6458: E1
        ld      (MENU_CURSOR_VRAM_ADDR),hl                     ;#6459: 22 68 D1
        call    DRAW_MENU_CURSOR                               ;#645C: CD E8 63
        jp      MENU_SELECT_KEY_POLL                           ;#645F: C3 15 64

MENU_SELECT_INIT:
        ; MENU_SELECT setup; clears D163/D165/D166 and redraws
        call    PATCH_MENU_FONT_TILES                          ;#6462: CD 73 64
        call    BIOS_KILBUF                                    ;#6465: CD 56 01
        xor     a                                              ;#6468: AF
        ld      (MENU_SELECTED_INDEX),a                        ;#6469: 32 63 D1
        ld      (MENU_CURRENT_INDEX),a                         ;#646C: 32 65 D1
        ld      (NAME_INPUT_DECIMAL_FLAG),a                    ;#646F: 32 66 D1
        ret                                                    ;#6472: C9

PATCH_MENU_FONT_TILES:
        ; Copy 8 GFX_MENU_FONT_TILES to VRAM 21D0 (or 31D0 if GAME_DISPLAY_ACTIVE)
        ld      hl,GFX_MENU_FONT_TILES                         ;#6473: 21 63 51
        ld      bc,8                                           ;#6476: 01 08 00
        ld      a,(GAME_DISPLAY_ACTIVE)                        ;#6479: 3A 3D D1
        or      a                                              ;#647C: B7
        jr      nz,PATCH_MENU_FONT_GAME_PAGE                   ;#647D: 20 06
        LOAD_VRAM_ADDRESS de, 21D0h                            ;#647F: 11 D0 21
        jp      LDIRVM_TO_3_BLOCKS                             ;#6482: C3 4D 61

PATCH_MENU_FONT_GAME_PAGE:
        ; Game-display variant: ld de,31D0h, jp BIOS_LDIRVM (page-2 mirror)
        LOAD_VRAM_ADDRESS de, 31D0h                            ;#6485: 11 D0 31
        jp      BIOS_LDIRVM                                    ;#6488: C3 5C 00

DISK_SAVE_GAME_FULL:
        ; Save GAME RAM, VRAM, then 82h-byte stack frame; reopen and reload GAME RAM
        ld      (SP_SAVE_FOR_BDOS),sp                          ;#648B: ED 73 27 D1
        call    PREPARE_RAM_FOR_BDOS                           ;#648F: CD C8 66
        call    BDOS_CREATE_FILE                               ;#6492: CD E6 67
        call    INIT_FCB_FOR_BLOCK_IO                          ;#6495: CD 9A 67
        call    DISK_SAVE_GAME_RAM                             ;#6498: CD A4 65
        call    DISK_SAVE_VRAM                                 ;#649B: CD 4A 66
        di                                                     ;#649E: F3
        ld      hl,0                                           ;#649F: 21 00 00
        add     hl,sp                                          ;#64A2: 39
        push    hl                                             ;#64A3: E5
        ld      hl,0                                           ;#64A4: 21 00 00
        add     hl,sp                                          ;#64A7: 39
        ld      de,SLOT_SCANNER_RAM                            ;#64A8: 11 00 C0
        ld      bc,82h                                         ;#64AB: 01 82 00
        ldir                                                   ;#64AE: ED B0
        pop     hl                                             ;#64B0: E1
        ei                                                     ;#64B1: FB
        ld      hl,82h                                         ;#64B2: 21 82 00
        call    BDOS_WRITE_BLOCK                               ;#64B5: CD 16 68
        pop     hl                                             ;#64B8: E1
        call    BDOS_CLOSE_FILE                                ;#64B9: CD F6 67
        call    CLEAR_FCB_NAME_EXT                             ;#64BC: CD 6F 67
        call    BDOS_OPEN_FILE                                 ;#64BF: CD D6 67
        call    INIT_FCB_FOR_BLOCK_IO                          ;#64C2: CD 9A 67
        call    DISK_LOAD_GAME_RAM                             ;#64C5: CD D5 65
        jp      RESTORE_RAM_AFTER_BDOS                         ;#64C8: C3 DF 66

DISK_SAVE_SCREEN:
        ; Make a .VRM file and write the screen (DISK_SAVE_VRAM_TRAILER + DISK_SAVE_VRAM)
        ld      (SP_SAVE_FOR_BDOS),sp                          ;#64CB: ED 73 27 D1
        call    PREPARE_RAM_FOR_BDOS                           ;#64CF: CD C8 66
        ld      hl,FCB_BUFFER                                  ;#64D2: 21 00 D1
        ld      (FCB_POINTER),hl                               ;#64D5: 22 25 D1
        call    CLEAR_FCB_NAME_EXT                             ;#64D8: CD 6F 67
        ld      de,FCB_EXT                                     ;#64DB: 11 09 D1
        ld      hl,TXT_EXT_VRM                                 ;#64DE: 21 F5 64
        ld      bc,3                                           ;#64E1: 01 03 00
        ldir                                                   ;#64E4: ED B0
        call    BDOS_CREATE_FILE                               ;#64E6: CD E6 67
        call    INIT_FCB_FOR_BLOCK_IO                          ;#64E9: CD 9A 67
        call    DISK_SAVE_VRAM_TRAILER                         ;#64EC: CD 74 66
        call    BDOS_CLOSE_FILE                                ;#64EF: CD F6 67
        jp      RESTORE_RAM_AFTER_BDOS                         ;#64F2: C3 DF 66

TXT_EXT_VRM:
        ; 3-byte ASCII "VRM" extension copied into FCB+9 for screen-dump files
        db      "VRM"                                          ;#64F5: 56 52 4D

DISK_SAVE_RANKING:
        ; Make file, write the ranking buffer via DISK_SAVE_RANKING_BUFFER, close
        ld      (SP_SAVE_FOR_BDOS),sp                          ;#64F8: ED 73 27 D1
        call    PREPARE_RAM_FOR_BDOS                           ;#64FC: CD C8 66
        call    BDOS_CREATE_FILE                               ;#64FF: CD E6 67
        call    INIT_FCB_FOR_BLOCK_IO                          ;#6502: CD 9A 67
        call    RANKING_RECORD_BOTH                            ;#6505: CD 74 55
        call    DISK_SAVE_RANKING_BUFFER                       ;#6508: CD B2 65
        call    BDOS_CLOSE_FILE                                ;#650B: CD F6 67
        jp      RESTORE_RAM_AFTER_BDOS                         ;#650E: C3 DF 66

DISK_SAVE_HISCORE:
        ; Make file, write 3 hi-score bytes via DISK_SAVE_HISCORE_BYTES, close
        ld      (SP_SAVE_FOR_BDOS),sp                          ;#6511: ED 73 27 D1
        call    PREPARE_RAM_FOR_BDOS                           ;#6515: CD C8 66
        call    BDOS_CREATE_FILE                               ;#6518: CD E6 67
        call    INIT_FCB_FOR_BLOCK_IO                          ;#651B: CD 9A 67
        call    DISK_SAVE_HISCORE_BYTES                        ;#651E: CD C0 65
        call    BDOS_CLOSE_FILE                                ;#6521: CD F6 67
        jp      RESTORE_RAM_AFTER_BDOS                         ;#6524: C3 DF 66

DISK_LOAD_GAME:
        ; Open file: load VRAM, restore the 82h stack frame, then game RAM and PSG vols
        ld      (SP_SAVE_FOR_BDOS),sp                          ;#6527: ED 73 27 D1
        call    PREPARE_RAM_FOR_BDOS                           ;#652B: CD C8 66
        call    BDOS_OPEN_FILE                                 ;#652E: CD D6 67
        call    INIT_FCB_FOR_BLOCK_IO                          ;#6531: CD 9A 67
        ld      hl,1100h                                       ;#6534: 21 00 11
        call    SET_FCB_RANDOM_RECORD                          ;#6537: CD C9 67
        call    DISK_LOAD_VRAM                                 ;#653A: CD 22 66
        ld      hl,82h                                         ;#653D: 21 82 00
        call    BDOS_READ_BLOCK                                ;#6540: CD 06 68
        ld      hl,(SLOT_SCANNER_RAM)                          ;#6543: 2A 00 C0
        ld      sp,hl                                          ;#6546: F9
        ld      de,RLE_COMPRESSED_OUTPUT                       ;#6547: 11 02 C0
        ex      de,hl                                          ;#654A: EB
        ld      bc,80h                                         ;#654B: 01 80 00
        ldir                                                   ;#654E: ED B0
        ld      hl,0                                           ;#6550: 21 00 00
        call    SET_FCB_RANDOM_RECORD                          ;#6553: CD C9 67
        call    DISK_LOAD_GAME_RAM                             ;#6556: CD D5 65
        call    MUTE_ALL_PSG_CHANNELS                          ;#6559: CD 91 4D
        call    SAVE_PSG_VOLUMES_TO_RAM                        ;#655C: CD A0 4D
        jp      RESTORE_RAM_AFTER_BDOS                         ;#655F: C3 DF 66

DISK_LOAD_SCREEN:
        ; Open file: load VRAM only via DISK_LOAD_VRAM, then resume
        ld      (SP_SAVE_FOR_BDOS),sp                          ;#6562: ED 73 27 D1
        call    PREPARE_RAM_FOR_BDOS                           ;#6566: CD C8 66
        call    BDOS_OPEN_FILE                                 ;#6569: CD D6 67
        call    INIT_FCB_FOR_BLOCK_IO                          ;#656C: CD 9A 67
        ld      hl,1100h                                       ;#656F: 21 00 11
        call    SET_FCB_RANDOM_RECORD                          ;#6572: CD C9 67
        call    DISK_LOAD_VRAM                                 ;#6575: CD 22 66
        jp      RESTORE_RAM_AFTER_BDOS                         ;#6578: C3 DF 66

DISK_LOAD_RANKING:
        ; Open file: load ranking via DISK_LOAD_RANKING_BUFFER, then PURGE_RANKING_BOTH
        ld      (SP_SAVE_FOR_BDOS),sp                          ;#657B: ED 73 27 D1
        call    PREPARE_RAM_FOR_BDOS                           ;#657F: CD C8 66
        call    BDOS_OPEN_FILE                                 ;#6582: CD D6 67
        call    INIT_FCB_FOR_BLOCK_IO                          ;#6585: CD 9A 67
        call    DISK_LOAD_RANKING_BUFFER                       ;#6588: CD E3 65
        call    PURGE_RANKING_BOTH                             ;#658B: CD D2 54
        jp      RESTORE_RAM_AFTER_BDOS                         ;#658E: C3 DF 66

DISK_LOAD_HISCORE:
        ; Open file: load 3 hi-score bytes via DISK_LOAD_HISCORE_BYTES
        ld      (SP_SAVE_FOR_BDOS),sp                          ;#6591: ED 73 27 D1
        call    PREPARE_RAM_FOR_BDOS                           ;#6595: CD C8 66
        call    BDOS_OPEN_FILE                                 ;#6598: CD D6 67
        call    INIT_FCB_FOR_BLOCK_IO                          ;#659B: CD 9A 67
        call    DISK_LOAD_HISCORE_BYTES                        ;#659E: CD F1 65
        jp      RESTORE_RAM_AFTER_BDOS                         ;#65A1: C3 DF 66

DISK_SAVE_GAME_RAM:
        ; Set DTA=SLOT_SCANNER_RAM, BDOS_WRITE_BLOCK 1100h bytes — save game-state RAM
        ld      de,SLOT_SCANNER_RAM                            ;#65A4: 11 00 C0
        ld      c,BDOS_SET_DTA                                 ;#65A7: 0E 1A
        call    BDOS                                           ;#65A9: CD 7D F3
        ld      hl,1100h                                       ;#65AC: 21 00 11
        jp      BDOS_WRITE_BLOCK                               ;#65AF: C3 16 68

DISK_SAVE_RANKING_BUFFER:
        ; DTA=RANKING_SCORE_BLOCK, BDOS_WRITE_BLOCK 78h bytes — save ranking
        ld      de,RANKING_SCORE_BLOCK                         ;#65B2: 11 59 D4
        ld      c,BDOS_SET_DTA                                 ;#65B5: 0E 1A
        call    BDOS                                           ;#65B7: CD 7D F3
        ld      hl,78h                                         ;#65BA: 21 78 00
        jp      BDOS_WRITE_BLOCK                               ;#65BD: C3 16 68

DISK_SAVE_HISCORE_BYTES:
        ; DTA=GAME_RAM_HISCORE_PTR-2000h, BDOS_WRITE_BLOCK 3 bytes — save hi-score
        ld      hl,(GAME_RAM_HISCORE_PTR)                      ;#65C0: 2A 0C D3
        ld      bc,2000h                                       ;#65C3: 01 00 20
        and     a                                              ;#65C6: A7
        sbc     hl,bc                                          ;#65C7: ED 42
        ex      de,hl                                          ;#65C9: EB
        ld      c,BDOS_SET_DTA                                 ;#65CA: 0E 1A
        call    BDOS                                           ;#65CC: CD 7D F3
        ld      hl,3                                           ;#65CF: 21 03 00
        jp      BDOS_WRITE_BLOCK                               ;#65D2: C3 16 68

DISK_LOAD_GAME_RAM:
        ; Set DTA=SLOT_SCANNER_RAM, BDOS_READ_BLOCK 1100h bytes — load game-state RAM
        ld      de,SLOT_SCANNER_RAM                            ;#65D5: 11 00 C0
        ld      c,BDOS_SET_DTA                                 ;#65D8: 0E 1A
        call    BDOS                                           ;#65DA: CD 7D F3
        ld      hl,1100h                                       ;#65DD: 21 00 11
        jp      BDOS_READ_BLOCK                                ;#65E0: C3 06 68

DISK_LOAD_RANKING_BUFFER:
        ; DTA=RANKING_SCORE_BLOCK, BDOS_READ_BLOCK 78h bytes — load ranking
        ld      de,RANKING_SCORE_BLOCK                         ;#65E3: 11 59 D4
        ld      c,BDOS_SET_DTA                                 ;#65E6: 0E 1A
        call    BDOS                                           ;#65E8: CD 7D F3
        ld      hl,78h                                         ;#65EB: 21 78 00
        jp      BDOS_READ_BLOCK                                ;#65EE: C3 06 68

DISK_LOAD_HISCORE_BYTES:
        ; DTA=GAME_RAM_HISCORE_PTR-2000h, BDOS_READ_BLOCK 3 bytes — load hi-score
        ld      hl,(GAME_RAM_HISCORE_PTR)                      ;#65F1: 2A 0C D3
        ld      bc,2000h                                       ;#65F4: 01 00 20
        and     a                                              ;#65F7: A7
        sbc     hl,bc                                          ;#65F8: ED 42
        ex      de,hl                                          ;#65FA: EB
        ld      c,BDOS_SET_DTA                                 ;#65FB: 0E 1A
        call    BDOS                                           ;#65FD: CD 7D F3
        ld      hl,3                                           ;#6600: 21 03 00
        jp      BDOS_READ_BLOCK                                ;#6603: C3 06 68
        ld      de,SLOT_SCANNER_RAM                            ;#6606: 11 00 C0
        ld      c,BDOS_SET_DTA                                 ;#6609: 0E 1A
        call    BDOS                                           ;#660B: CD 7D F3
        ld      hl,1000h                                       ;#660E: 21 00 10
        jp      BDOS_WRITE_BLOCK                               ;#6611: C3 16 68
        ld      de,SLOT_SCANNER_RAM                            ;#6614: 11 00 C0
        ld      c,BDOS_SET_DTA                                 ;#6617: 0E 1A
        call    BDOS                                           ;#6619: CD 7D F3
        ld      hl,1000h                                       ;#661C: 21 00 10
        jp      BDOS_READ_BLOCK                                ;#661F: C3 06 68

DISK_LOAD_VRAM:
        ; Loop: BDOS_READ_HL_WORD length, READ_BLOCK to SLOT_SCANNER_RAM, DECOMPRESS
        ld      de,0                                           ;#6622: 11 00 00
DISK_LOAD_VRAM_LOOP:
        ; Per-block body: push DE, read 2-byte size, read block, decompress to VRAM page
        push    de                                             ;#6625: D5
        call    BDOS_READ_HL_WORD                              ;#6626: CD 4E 68
        push    hl                                             ;#6629: E5
        ld      de,SLOT_SCANNER_RAM                            ;#662A: 11 00 C0
        ld      c,BDOS_SET_DTA                                 ;#662D: 0E 1A
        call    BDOS                                           ;#662F: CD 7D F3
        pop     hl                                             ;#6632: E1
        call    BDOS_READ_BLOCK                                ;#6633: CD 06 68
        pop     de                                             ;#6636: D1
        ld      hl,SLOT_SCANNER_RAM                            ;#6637: 21 00 C0
        push    de                                             ;#663A: D5
        call    DECOMPRESS_RLE_TO_VRAM                         ;#663B: CD 7A 61
        pop     de                                             ;#663E: D1
        ld      a,8                                            ;#663F: 3E 08
        add     a,d                                            ;#6641: 82
        ld      d,a                                            ;#6642: 57
        cp      40h                                            ;#6643: FE 40
        jr      nz,DISK_LOAD_VRAM_LOOP                         ;#6645: 20 DE
        jp      INIT_VDP_REGISTERS                             ;#6647: C3 F2 60

DISK_SAVE_VRAM:
        ; Loop: LDIRMV 800h to RLE_RAW_INPUT, RLE_COMPRESS, BDOS_WRITE_BLOCK
        ld      hl,0                                           ;#664A: 21 00 00
DISK_SAVE_VRAM_LOOP:
        ; Per-page body: push HL, LDIRMV 800h from VRAM to RLE_RAW_INPUT, compress, write
        push    hl                                             ;#664D: E5
        ld      de,RLE_RAW_INPUT                               ;#664E: 11 02 C8
        ld      bc,800h                                        ;#6651: 01 00 08
        call    BIOS_LDIRMV                                    ;#6654: CD 59 00
        call    RLE_COMPRESS_VRAM_BUFFER                       ;#6657: CD 39 6C
        ld      de,SLOT_SCANNER_RAM                            ;#665A: 11 00 C0
        ld      c,BDOS_SET_DTA                                 ;#665D: 0E 1A
        call    BDOS                                           ;#665F: CD 7D F3
        ld      hl,(SLOT_SCANNER_RAM)                          ;#6662: 2A 00 C0
        inc     hl                                             ;#6665: 23
        inc     hl                                             ;#6666: 23
        call    BDOS_WRITE_BLOCK                               ;#6667: CD 16 68
        pop     hl                                             ;#666A: E1
        ld      a,8                                            ;#666B: 3E 08
        add     a,h                                            ;#666D: 84
        ld      h,a                                            ;#666E: 67
        cp      40h                                            ;#666F: FE 40
        jr      nz,DISK_SAVE_VRAM_LOOP                         ;#6671: 20 DA
        ret                                                    ;#6673: C9

DISK_SAVE_VRAM_TRAILER:
        ; Write the 5-byte VRAM-file trailer: FEh marker + word HEADER_NONE + word 3FFFh
        ld      a,0FEh                                         ;#6674: 3E FE
        call    BDOS_WRITE_BYTE                                ;#6676: CD 2B 68
        ld      hl,0                                           ;#6679: 21 00 00
        call    BDOS_WRITE_HL_WORD                             ;#667C: CD 45 68
        ld      hl,3FFFh                                       ;#667F: 21 FF 3F
        call    BDOS_WRITE_HL_WORD                             ;#6682: CD 45 68
        ld      hl,0                                           ;#6685: 21 00 00
        call    BDOS_WRITE_HL_WORD                             ;#6688: CD 45 68
        LOAD_VRAM_ADDRESS hl, 2000h                            ;#668B: 21 00 20
        ld      b,3                                            ;#668E: 06 03
        call    SAVE_VRAM_PAGES_TO_FILE                        ;#6690: CD A8 66
        LOAD_NAME_TABLE hl, 0, 0                               ;#6693: 21 00 38
        ld      b,1                                            ;#6696: 06 01
        call    SAVE_VRAM_PAGES_TO_FILE                        ;#6698: CD A8 66
        ld      hl,0                                           ;#669B: 21 00 00
        ld      b,3                                            ;#669E: 06 03
        call    SAVE_VRAM_PAGES_TO_FILE                        ;#66A0: CD A8 66
        LOAD_VRAM_ADDRESS hl, 1800h                            ;#66A3: 21 00 18
        ld      b,1                                            ;#66A6: 06 01
SAVE_VRAM_PAGES_TO_FILE:
        ; Loop: LDIRMV 800h VRAM→C000, set DTA, BDOS_WRITE_BLOCK, advance HL +800h
        push    bc                                             ;#66A8: C5
        push    hl                                             ;#66A9: E5
        ld      de,SLOT_SCANNER_RAM                            ;#66AA: 11 00 C0
        ld      bc,800h                                        ;#66AD: 01 00 08
        push    bc                                             ;#66B0: C5
        push    de                                             ;#66B1: D5
        call    BIOS_LDIRMV                                    ;#66B2: CD 59 00
        pop     de                                             ;#66B5: D1
        ld      c,BDOS_SET_DTA                                 ;#66B6: 0E 1A
        call    BDOS                                           ;#66B8: CD 7D F3
        pop     hl                                             ;#66BB: E1
        call    BDOS_WRITE_BLOCK                               ;#66BC: CD 16 68
        pop     hl                                             ;#66BF: E1
        ld      a,8                                            ;#66C0: 3E 08
        add     a,h                                            ;#66C2: 84
        ld      h,a                                            ;#66C3: 67
        pop     bc                                             ;#66C4: C1
        djnz    SAVE_VRAM_PAGES_TO_FILE                        ;#66C5: 10 E1
        ret                                                    ;#66C7: C9

PREPARE_RAM_FOR_BDOS:
        ; Suspend ISR, SWAP_C000_E000_BLOCK, LDDR copy E000..F0FF up to E280..F37F
        di                                                     ;#66C8: F3
        call    SWAP_C000_E000_BLOCK                           ;#66C9: CD F0 66
        ld      hl,GAME_RAM_E000_LAST                          ;#66CC: 21 FF F0
        ld      de,GAME_RAM_SHADOW_END                         ;#66CF: 11 7F F3
        ld      bc,1100h                                       ;#66D2: 01 00 11
        lddr                                                   ;#66D5: ED B8
        ld      hl,0                                           ;#66D7: 21 00 00
        ld      (BIOS_KEY_REPEAT_STATE),hl                     ;#66DA: 22 C0 F1
        ei                                                     ;#66DD: FB
        ret                                                    ;#66DE: C9

RESTORE_RAM_AFTER_BDOS:
        ; Suspend ISR, LDIR copy E280..F37F back to E000..F0FF, SWAP_C000_E000_BLOCK
        di                                                     ;#66DF: F3
        ld      hl,GAME_RAM_SHADOW_E280                        ;#66E0: 21 80 E2
        ld      de,CHEAT_TARGET_ROAD_FIGHTER_E000              ;#66E3: 11 00 E0
        ld      bc,1100h                                       ;#66E6: 01 00 11
        ldir                                                   ;#66E9: ED B0
        call    SWAP_C000_E000_BLOCK                           ;#66EB: CD F0 66
        ei                                                     ;#66EE: FB
        ret                                                    ;#66EF: C9

SWAP_C000_E000_BLOCK:
        ; Swap 1100h bytes between SLOT_SCANNER_RAM and the game-RAM block at E000h
        ld      hl,CHEAT_TARGET_ROAD_FIGHTER_E000              ;#66F0: 21 00 E0
        ld      de,SLOT_SCANNER_RAM                            ;#66F3: 11 00 C0
        ld      bc,1100h                                       ;#66F6: 01 00 11
SAVE_VRAM_PAGES_LOOP:
        ; Per-page body: push BC, LDIRMV 800h into scratch, BDOS_WRITE_BLOCK
        push    bc                                             ;#66F9: C5
        ld      b,(hl)                                         ;#66FA: 46
        ld      a,(de)                                         ;#66FB: 1A
        ld      (hl),a                                         ;#66FC: 77
        ld      a,b                                            ;#66FD: 78
        ld      (de),a                                         ;#66FE: 12
        pop     bc                                             ;#66FF: C1
        inc     hl                                             ;#6700: 23
        inc     de                                             ;#6701: 13
        dec     bc                                             ;#6702: 0B
        ld      a,b                                            ;#6703: 78
        or      c                                              ;#6704: B1
        jr      nz,SAVE_VRAM_PAGES_LOOP                        ;#6705: 20 F2
        ret                                                    ;#6707: C9

INPUT_FILE_NAME_INIT_FCB:
        ; Name input in mode 0 (B chars at HL VRAM), then build FCB at FCB_BUFFER
        xor     a                                              ;#6708: AF
        call    RUN_NAME_INPUT_LOOP                            ;#6709: CD D8 62
        ld      a,(MENU_SELECTED_INDEX)                        ;#670C: 3A 63 D1
        or      a                                              ;#670F: B7
        ret     z                                              ;#6710: C8
        ld      hl,FCB_BUFFER                                  ;#6711: 21 00 D1
        ld      (FCB_POINTER),hl                               ;#6714: 22 25 D1
        ld      d,h                                            ;#6717: 54
        ld      e,l                                            ;#6718: 5D
        ld      (hl),20h                                       ;#6719: 36 20
        inc     de                                             ;#671B: 13
        ld      bc,8                                           ;#671C: 01 08 00
        ldir                                                   ;#671F: ED B0
        xor     a                                              ;#6721: AF
        ld      (de),a                                         ;#6722: 12
        inc     hl                                             ;#6723: 23
        inc     de                                             ;#6724: 13
        ld      bc,1Bh                                         ;#6725: 01 1B 00
        ldir                                                   ;#6728: ED B0
        ld      de,FCB_BUFFER                                  ;#672A: 11 00 D1
        ld      (de),a                                         ;#672D: 12
        inc     de                                             ;#672E: 13
        ld      a,(MENU_SELECTED_INDEX)                        ;#672F: 3A 63 D1
        ld      c,a                                            ;#6732: 4F
        ld      b,0                                            ;#6733: 06 00
        ld      hl,NAME_INPUT_BUFFER                           ;#6735: 21 42 D1
        ldir                                                   ;#6738: ED B0
        call    SET_FCB_EXTENSION_FROM_PARAM                   ;#673A: CD 41 67
        ld      a,0FFh                                         ;#673D: 3E FF
        or      a                                              ;#673F: B7
        ret                                                    ;#6740: C9

SET_FCB_EXTENSION_FROM_PARAM:
        ; Pick the extension first letter from FCB_EXT_LETTER_TABLE + 2 hex digits of D301
        ld      de,FCB_EXT                                     ;#6741: 11 09 D1
        ld      hl,FCB_EXT_LETTER_TABLE                        ;#6744: 21 59 67
        ld      a,(IN_GAME_MENU_PARAM)                         ;#6747: 3A 36 D1
        and     0Fh                                            ;#674A: E6 0F
        call    ADD_A_TO_HL                                    ;#674C: CD ED 60
        ldi                                                    ;#674F: ED A0
        ld      a,(GAME_ID)                                    ;#6751: 3A 01 D3
        ex      de,hl                                          ;#6754: EB
        call    WRITE_BYTE_AS_ASCII_HEX                        ;#6755: CD 5D 67
        ret                                                    ;#6758: C9

FCB_EXT_LETTER_TABLE:
        ; 4-byte table of file-extension first letters by op: "HSGR"
        ld      c,b                                            ;#6759: 48
        ld      d,e                                            ;#675A: 53
        ld      b,a                                            ;#675B: 47
        ld      d,d                                            ;#675C: 52
WRITE_BYTE_AS_ASCII_HEX:
        ; Write A as 2 ASCII hex digits at (HL), HL+=2 (used by tape and ranking display)
        ld      d,a                                            ;#675D: 57
        and     0F0h                                           ;#675E: E6 F0
        rrca                                                   ;#6760: 0F
        rrca                                                   ;#6761: 0F
        rrca                                                   ;#6762: 0F
        rrca                                                   ;#6763: 0F
        or      30h                                            ;#6764: F6 30
        ld      (hl),a                                         ;#6766: 77
        inc     hl                                             ;#6767: 23
        ld      a,d                                            ;#6768: 7A
        and     0Fh                                            ;#6769: E6 0F
        or      30h                                            ;#676B: F6 30
        ld      (hl),a                                         ;#676D: 77
        ret                                                    ;#676E: C9

CLEAR_FCB_NAME_EXT:
        ; Zero 25 bytes at FCB_CURRENT_BLOCK (clears 8.3 name + size/date region)
        ld      hl,FCB_CURRENT_BLOCK                           ;#676F: 21 0C D1
        ld      de,FCB_CURRENT_BLOCK+1                         ;#6772: 11 0D D1
        ld      (hl),0                                         ;#6775: 36 00
        ld      bc,18h                                         ;#6777: 01 18 00
        ldir                                                   ;#677A: ED B0
        ret                                                    ;#677C: C9

CHECK_DISK_BIOS_AVAILABLE:
        ; Returns Z when BIOS_H_PHYDIO is C9h (no disk-BIOS hook installed)
        ld      a,(BIOS_H_PHYDIO)                              ;#677D: 3A A7 FF
        cp      Z80_RET                                        ;#6780: FE C9
        ret                                                    ;#6782: C9

INIT_FCB_AT_DE:
        ; Zero-fill FCB at DE: drive byte 0, 11-byte name area, 25 bytes of reserved
        ld      (FCB_POINTER),de                               ;#6783: ED 53 25 D1
        xor     a                                              ;#6787: AF
        ld      (de),a                                         ;#6788: 12
        inc     de                                             ;#6789: 13
        ld      bc,0Bh                                         ;#678A: 01 0B 00
        ldir                                                   ;#678D: ED B0
        xor     a                                              ;#678F: AF
        ld      b,19h                                          ;#6790: 06 19
SET_FCB_EXTENSION_PAD_LOOP:
        ; Pad the rest of the FCB extension area with spaces
        ld      (de),a                                         ;#6792: 12
        inc     de                                             ;#6793: 13
        djnz    SET_FCB_EXTENSION_PAD_LOOP                     ;#6794: 10 FC
        ret                                                    ;#6796: C9

SET_FCB_POINTER:
        ; Store HL into FCB_POINTER for subsequent BDOS_* calls
        ld      (FCB_POINTER),hl                               ;#6797: 22 25 D1
INIT_FCB_FOR_BLOCK_IO:
        ; Set record size +0Eh=1 and zero +20h..+24h for byte-stride RDBLK/WRBLK
        ld      hl,(FCB_POINTER)                               ;#679A: 2A 25 D1
        ld      bc,0Ch                                         ;#679D: 01 0C 00
        add     hl,bc                                          ;#67A0: 09
        ld      (hl),b                                         ;#67A1: 70
        inc     hl                                             ;#67A2: 23
        ld      (hl),b                                         ;#67A3: 70
        inc     hl                                             ;#67A4: 23
        ld      bc,1                                           ;#67A5: 01 01 00
        ld      (hl),c                                         ;#67A8: 71
        inc     hl                                             ;#67A9: 23
        ld      (hl),b                                         ;#67AA: 70
        ld      bc,11h                                         ;#67AB: 01 11 00
        add     hl,bc                                          ;#67AE: 09
        ld      b,5                                            ;#67AF: 06 05
        xor     a                                              ;#67B1: AF
CLEAR_FCB_NAME_EXT_LOOP:
        ; Per-byte body: ld (hl),0; inc hl; djnz
        ld      (hl),a                                         ;#67B2: 77
        inc     hl                                             ;#67B3: 23
        djnz    CLEAR_FCB_NAME_EXT_LOOP                        ;#67B4: 10 FC
        ret                                                    ;#67B6: C9

GET_FCB_FILE_SIZE_LO:
        ; HL = first 2 bytes of file-size field (+10h) from current FCB
        ld      hl,(FCB_POINTER)                               ;#67B7: 2A 25 D1
        ld      bc,10h                                         ;#67BA: 01 10 00
        add     hl,bc                                          ;#67BD: 09
        ld      a,(hl)                                         ;#67BE: 7E
        inc     hl                                             ;#67BF: 23
        ld      h,(hl)                                         ;#67C0: 66
        ld      l,a                                            ;#67C1: 6F
        ret                                                    ;#67C2: C9

SET_FCB_RANDOM_RECORD_DE:
        ; Store DE into FCB_POINTER then set its +21h..+22h random-record field to DE
        ld      (FCB_POINTER),de                               ;#67C3: ED 53 25 D1
        jr      SET_FCB_RANDOM_RECORD_TAIL                     ;#67C7: 18 04

SET_FCB_RANDOM_RECORD:
        ; Use current FCB_POINTER and set +21h..+22h random-record field to DE
        ld      de,(FCB_POINTER)                               ;#67C9: ED 5B 25 D1
SET_FCB_RANDOM_RECORD_TAIL:
        ; Shared tail: HL=FCB_POINTER+21h, store DE word into the random-record field
        ex      de,hl                                          ;#67CD: EB
        ld      bc,21h                                         ;#67CE: 01 21 00
        add     hl,bc                                          ;#67D1: 09
        ld      (hl),e                                         ;#67D2: 73
        inc     hl                                             ;#67D3: 23
        ld      (hl),d                                         ;#67D4: 72
        ret                                                    ;#67D5: C9

BDOS_OPEN_FILE:
        ; Set DE=FCB_POINTER, C=0Fh (F_OPEN), call BDOS via BDOS
        ld      de,(FCB_POINTER)                               ;#67D6: ED 5B 25 D1
        ld      c,BDOS_OPEN                                    ;#67DA: 0E 0F
        call    BDOS                                           ;#67DC: CD 7D F3
        ld      c,0                                            ;#67DF: 0E 00
        inc     a                                              ;#67E1: 3C
        jp      z,BDOS_OP_ERROR_HANDLER                        ;#67E2: CA 59 68
        ret                                                    ;#67E5: C9

BDOS_CREATE_FILE:
        ; Set DE=FCB_POINTER, C=16h (F_MAKE), call BDOS via BDOS
        ld      de,(FCB_POINTER)                               ;#67E6: ED 5B 25 D1
        ld      c,BDOS_CREATE                                  ;#67EA: 0E 16
        call    BDOS                                           ;#67EC: CD 7D F3
        ld      c,1                                            ;#67EF: 0E 01
        inc     a                                              ;#67F1: 3C
        jp      z,BDOS_OP_ERROR_HANDLER                        ;#67F2: CA 59 68
        ret                                                    ;#67F5: C9

BDOS_CLOSE_FILE:
        ; Set DE=FCB_POINTER, C=10h (F_CLOSE), call BDOS via BDOS
        ld      de,(FCB_POINTER)                               ;#67F6: ED 5B 25 D1
        ld      c,BDOS_CLOSE                                   ;#67FA: 0E 10
        call    BDOS                                           ;#67FC: CD 7D F3
        ld      c,2                                            ;#67FF: 0E 02
        inc     a                                              ;#6801: 3C
        jp      z,BDOS_OP_ERROR_HANDLER                        ;#6802: CA 59 68
        ret                                                    ;#6805: C9

BDOS_READ_BLOCK:
        ; Set DE=FCB_POINTER, C=27h (F_RDBLK), call BDOS via BDOS
        ld      de,(FCB_POINTER)                               ;#6806: ED 5B 25 D1
        ld      c,BDOS_RDBLK                                   ;#680A: 0E 27
        call    BDOS                                           ;#680C: CD 7D F3
        ld      c,3                                            ;#680F: 0E 03
        or      a                                              ;#6811: B7
        jp      nz,BDOS_OP_ERROR_HANDLER                       ;#6812: C2 59 68
        ret                                                    ;#6815: C9

BDOS_WRITE_BLOCK:
        ; Set DE=FCB_POINTER, C=26h (F_WRBLK), call BDOS via BDOS
        ld      de,(FCB_POINTER)                               ;#6816: ED 5B 25 D1
        ld      c,BDOS_WRBLK                                   ;#681A: 0E 26
        call    BDOS                                           ;#681C: CD 7D F3
        ld      c,4                                            ;#681F: 0E 04
        or      a                                              ;#6821: B7
        jp      nz,BDOS_OP_ERROR_HANDLER                       ;#6822: C2 59 68
        ret                                                    ;#6825: C9

BDOS_READ_BYTE:
        ; Read 1 byte via F_RDBLK (record-size=1); result in A
        ld      bc,BDOS_READ_BLOCK                             ;#6826: 01 06 68
        jr      BDOS_RW_BYTE_COMMON                            ;#6829: 18 03

BDOS_WRITE_BYTE:
        ; Write 1 byte (A) via F_WRBLK with DTA pointing at the just-pushed A on stack
        ld      bc,BDOS_WRITE_BLOCK                            ;#682B: 01 16 68
BDOS_RW_BYTE_COMMON:
        ; Shared body of BDOS_READ_BYTE/WRITE_BYTE: stack 1 byte, F_SETDTA, tail-call BC
        push    af                                             ;#682E: F5
        ld      hl,1                                           ;#682F: 21 01 00
        add     hl,sp                                          ;#6832: 39
        push    bc                                             ;#6833: C5
        ex      de,hl                                          ;#6834: EB
        ld      c,BDOS_SET_DTA                                 ;#6835: 0E 1A
        call    BDOS                                           ;#6837: CD 7D F3
        pop     bc                                             ;#683A: C1
        call    BDOS_DISPATCH_BC_LEN_1                         ;#683B: CD 40 68
        pop     af                                             ;#683E: F1
        ret                                                    ;#683F: C9

BDOS_DISPATCH_BC_LEN_1:
        ; Dispatch to (BC) with HL=1 byte (used by BDOS_READ_BYTE/WRITE_BYTE)
        ld      hl,1                                           ;#6840: 21 01 00
        push    bc                                             ;#6843: C5
        ret                                                    ;#6844: C9

BDOS_WRITE_HL_WORD:
        ; Write HL as 2 separate 1-byte BDOS_WRITE_BYTE calls (low then high)
        push    hl                                             ;#6845: E5
        ld      a,l                                            ;#6846: 7D
        call    BDOS_WRITE_BYTE                                ;#6847: CD 2B 68
        pop     hl                                             ;#684A: E1
        ld      a,h                                            ;#684B: 7C
        jr      BDOS_WRITE_BYTE                                ;#684C: 18 DD

BDOS_READ_HL_WORD:
        ; Read HL from 2 separate 1-byte BDOS_READ_BYTE calls (low then high)
        call    BDOS_READ_BYTE                                 ;#684E: CD 26 68
        ld      l,a                                            ;#6851: 6F
        push    hl                                             ;#6852: E5
        call    BDOS_READ_BYTE                                 ;#6853: CD 26 68
        pop     hl                                             ;#6856: E1
        ld      h,a                                            ;#6857: 67
        ret                                                    ;#6858: C9

BDOS_OP_ERROR_HANDLER:
        ; Common disk-error path: C = failed-op code (0=open,1=make,2=close,3=rd,4=wr)
        push    bc                                             ;#6859: C5
        call    RESTORE_RAM_AFTER_BDOS                         ;#685A: CD DF 66
        call    SAVE_GAME_DISPLAY_IF_GAME_ACTIVE               ;#685D: CD B5 62
        call    DRAW_SUBMENU_HEADING                           ;#6860: CD 47 45
        call    DRAW_SUBMENU_SUBHEADING                        ;#6863: CD 9F 45
        call    DRAW_RC_CATALOG_CODE                           ;#6866: CD 2A 44
        ld      hl,TXT_DISK_ERROR_HEADER                       ;#6869: 21 87 68
        ld      de,(SUBMENU_BODY_VRAM_BASE)                    ;#686C: ED 5B 6E D1
        push    de                                             ;#6870: D5
        call    DRAW_TEXT_STREAM_AT_DE                         ;#6871: CD 0F 61
        pop     hl                                             ;#6874: E1
        ld      bc,40h                                         ;#6875: 01 40 00
        add     hl,bc                                          ;#6878: 09
        ex      de,hl                                          ;#6879: EB
        pop     bc                                             ;#687A: C1
        call    DRAW_DISK_ERROR_AND_WAIT                       ;#687B: CD 96 68
        call    RESTORE_GAME_DISPLAY_IF_GAME_ACTIVE            ;#687E: CD BD 62
DISK_ERROR_ABORT_FROM_BDOS:
        ; Restore SP from SP_SAVE_FOR_BDOS, scf, ret (caller sees CY = abort)
        ld      sp,(SP_SAVE_FOR_BDOS)                          ;#6881: ED 7B 27 D1
        scf                                                    ;#6885: 37
        ret                                                    ;#6886: C9

TXT_DISK_ERROR_HEADER:
        ; 16-byte "@@DISK\0ERROR@@" header drawn above the per-op disk error message
        db      "@@DISK", 0, "ERROR@@"                         ;#6887: 40 40 44 49 53 4B 00 45 52 52 4F 52 40 40
        TEXT_TERMINATOR                                        ;#6895: FF

DRAW_DISK_ERROR_AND_WAIT:
        ; Index DISK_ERROR_MSG_TABLE by 2*C, draw header+message, wait for key
        ld      a,c                                            ;#6896: 79
        add     a,a                                            ;#6897: 87
        ld      hl,DISK_ERROR_MSG_TABLE                        ;#6898: 21 CD 68
        call    ADD_A_TO_HL                                    ;#689B: CD ED 60
        ld      a,(hl)                                         ;#689E: 7E
        inc     hl                                             ;#689F: 23
        ld      h,(hl)                                         ;#68A0: 66
        ld      l,a                                            ;#68A1: 6F
        push    de                                             ;#68A2: D5
        call    DRAW_TEXT_STREAM_AT_DE                         ;#68A3: CD 0F 61
        pop     hl                                             ;#68A6: E1
        ld      bc,40h                                         ;#68A7: 01 40 00
        add     hl,bc                                          ;#68AA: 09
        ld      de,TXT_HIT_RETURN_KEY_2                        ;#68AB: 11 BE 68
        ex      de,hl                                          ;#68AE: EB
        call    DRAW_TEXT_STREAM_AT_DE                         ;#68AF: CD 0F 61
        call    BIOS_KILBUF                                    ;#68B2: CD 56 01
DRAW_DISK_ERROR_CHECK_RETRY:
        ; After drawing the error: sample row-7 of the keyboard for RETURN
        ld      a,7                                            ;#68B5: 3E 07
        ; SNSMAT row 7; RLA puts bit 7 in carry (RETURN key). No CPL,
        ; so a set bit means released — the loop spins while RETURN is not
        ; yet pressed (carry true → loop back).
        call    BIOS_SNSMAT                                    ;#68B7: CD 41 01
        rla                                                    ;#68BA: 17
        jr      c,DRAW_DISK_ERROR_CHECK_RETRY                  ;#68BB: 38 F8
        ret                                                    ;#68BD: C9

TXT_HIT_RETURN_KEY_2:
        ; Second copy of "HIT RETURN KEY" (disk-error path twin of TXT_HIT_RETURN_KEY)
        db      "HIT", 0, "RETURN", 0, "KEY"                   ;#68BE: 48 49 54 00 52 45 54 55 52 4E 00 4B 45 59
        TEXT_TERMINATOR                                        ;#68CC: FF

DISK_ERROR_MSG_TABLE:
        ; 6-entry word table: error-message pointer indexed by BDOS C=0..5
        dw      TXT_FILE_NOT_FOUND                             ;#68CD: D9 68
        dw      TXT_TOO_MANY_FILES                             ;#68CF: EA 68
        dw      TXT_DISK_FULL                                  ;#68D1: FB 68
        dw      TXT_DISK_READ_ERROR                            ;#68D3: 07 69
        dw      TXT_DISK_FULL                                  ;#68D5: FB 68
        dw      TXT_DISK_IO_ERROR                              ;#68D7: 19 69

TXT_FILE_NOT_FOUND:
        ; "=FILE NOT FOUND=" — open failed (BDOS C=0)
        db      "=FILE", 0, "NOT", 0, "FOUND="                 ;#68D9: 3D 46 49 4C 45 00 4E 4F 54 00 46 4F 55 4E 44 3D
        TEXT_TERMINATOR                                        ;#68E9: FF

TXT_TOO_MANY_FILES:
        ; "=TOO MANY FILES=" — make failed (BDOS C=1)
        db      "=TOO", 0, "MANY", 0, "FILES="                 ;#68EA: 3D 54 4F 4F 00 4D 41 4E 59 00 46 49 4C 45 53 3D
        TEXT_TERMINATOR                                        ;#68FA: FF

TXT_DISK_FULL:
        ; "=DISK FULL=" — close failed (BDOS C=2)
        db      "=DISK", 0, "FULL="                            ;#68FB: 3D 44 49 53 4B 00 46 55 4C 4C 3D
        TEXT_TERMINATOR                                        ;#6906: FF

TXT_DISK_READ_ERROR:
        ; "=DISK READ ERROR=" — read failed (BDOS C=3)
        db      "=DISK", 0, "READ", 0, "ERROR="                ;#6907: 3D 44 49 53 4B 00 52 45 41 44 00 45 52 52 4F 52 3D
        TEXT_TERMINATOR                                        ;#6918: FF

TXT_DISK_IO_ERROR:
        ; "=DISK IO ERROR=" — write failed (BDOS C=4)
        db      "=DISK", 0, "IO", 0, "ERROR="                  ;#6919: 3D 44 49 53 4B 00 49 4F 00 45 52 52 4F 52 3D
        TEXT_TERMINATOR                                        ;#6928: FF

SETUP_INTERSLOT_CALL:
        ; Copy INTERSLOT_CALL_TRAMPOLINE to (HL) and patch with OWN_SLOT_RAW + target DE
        ex      de,hl                                          ;#6929: EB
        ld      hl,INTERSLOT_CALL_TRAMPOLINE_RAM               ;#692A: 21 3E D3
        push    hl                                             ;#692D: E5
        ld      (INTERSLOT_CALL_TARGET),hl                     ;#692E: 22 3C D3
        ld      hl,INTERSLOT_CALL_TARGET                       ;#6931: 21 3C D3
        ld      (INTERSLOT_CALL_TARGET_PTR_DUP),hl             ;#6934: 22 A3 D0
        pop     hl                                             ;#6937: E1
        push    de                                             ;#6938: D5
        ld      de,INTERSLOT_CALL_TRAMPOLINE                   ;#6939: 11 4F 69
        ld      bc,0Dh                                         ;#693C: 01 0D 00
        ex      de,hl                                          ;#693F: EB
        ldir                                                   ;#6940: ED B0
        ld      hl,INTERSLOT_CALL_TRAMPOLINE_RAM+5             ;#6942: 21 43 D3
        ld      a,(OWN_SLOT_RAW)                               ;#6945: 3A 2E D1
        ld      (hl),a                                         ;#6948: 77
        inc     hl                                             ;#6949: 23
        pop     de                                             ;#694A: D1
        ld      (hl),e                                         ;#694B: 73
        inc     hl                                             ;#694C: 23
        ld      (hl),d                                         ;#694D: 72
        ret                                                    ;#694E: C9

INTERSLOT_CALL_TRAMPOLINE:
        ; 13-byte stub copied to RAM: push iy/ix, rst 30h (CALSLT), nop×3, pop ix/iy, ret
        push    iy                                             ;#694F: FD E5
        push    ix                                             ;#6951: DD E5
        rst     30h                                            ;#6953: F7
        nop                                                    ;#6954: 00
        nop                                                    ;#6955: 00
        nop                                                    ;#6956: 00
        pop     ix                                             ;#6957: DD E1
        pop     iy                                             ;#6959: FD E1
        ret                                                    ;#695B: C9

DISK_ERROR_RECOVER_AND_RETRY:
        ; After BDOS error: RESTORE+SAVE+DRAW_DISK_ERROR, then PREPARE for retry
        push    bc                                             ;#695C: C5
        call    RESTORE_RAM_AFTER_BDOS                         ;#695D: CD DF 66
        call    SAVE_GAME_DISPLAY_IF_GAME_ACTIVE               ;#6960: CD B5 62
        pop     bc                                             ;#6963: C1
        call    DRAW_DISK_ERROR_FROM_DOS                       ;#6964: CD 8C 69
        push    af                                             ;#6967: F5
        call    RESTORE_GAME_DISPLAY_IF_GAME_ACTIVE            ;#6968: CD BD 62
        pop     af                                             ;#696B: F1
        jp      c,DISK_ERROR_ABORT_FROM_BDOS                   ;#696C: DA 81 68
        call    PREPARE_RAM_FOR_BDOS                           ;#696F: CD C8 66
        ld      c,1                                            ;#6972: 0E 01
        ret                                                    ;#6974: C9

DISK_ERROR_RETRY_NO_SAVE:
        ; Simpler error path: RESTORE, DRAW_DISK_ERROR, CLEAR_MENU_AREA, PREPARE retry
        push    bc                                             ;#6975: C5
        call    RESTORE_RAM_AFTER_BDOS                         ;#6976: CD DF 66
        pop     bc                                             ;#6979: C1
        call    DRAW_DISK_ERROR_FROM_DOS                       ;#697A: CD 8C 69
        jp      c,DISK_ERROR_ABORT_FROM_BDOS                   ;#697D: DA 81 68
        call    CLEAR_MENU_DISPLAY_AREA                        ;#6980: CD DD 61
        call    DRAW_SELECT_FILE_NAME_PROMPT                   ;#6983: CD 5C 42
        call    PREPARE_RAM_FOR_BDOS                           ;#6986: CD C8 66
        ld      c,1                                            ;#6989: 0E 01
        ret                                                    ;#698B: C9

DRAW_DISK_ERROR_FROM_DOS:
        ; Render the disk-error screen + message text from BDOS error code C
        push    bc                                             ;#698C: C5
        call    DRAW_SUBMENU_HEADING                           ;#698D: CD 47 45
        call    DRAW_SUBMENU_SUBHEADING                        ;#6990: CD 9F 45
        call    DRAW_RC_CATALOG_CODE                           ;#6993: CD 2A 44
        ld      hl,TXT_DISK_ERROR_HEADER                       ;#6996: 21 87 68
        ld      de,(SUBMENU_BODY_VRAM_BASE)                    ;#6999: ED 5B 6E D1
        call    DRAW_TEXT_STREAM_AT_DE                         ;#699D: CD 0F 61
        pop     bc                                             ;#69A0: C1
        ld      a,c                                            ;#69A1: 79
        and     0Eh                                            ;#69A2: E6 0E
        rrca                                                   ;#69A4: 0F
        cp      2                                              ;#69A5: FE 02
        jr      c,DRAW_DISK_ERROR_WRITE_PROTECTED              ;#69A7: 38 06
        cp      6                                              ;#69A9: FE 06
        jr      c,DISK_ERROR_WAIT_SPACE                        ;#69AB: 38 46
        jr      DRAW_DISK_ERROR_OFFLINE_MSG                    ;#69AD: 18 06

DRAW_DISK_ERROR_WRITE_PROTECTED:
        ; Set HL=TXT_WRITE_PROTECTED for the "write protected" RC subset
        ld      hl,TXT_WRITE_PROTECTED                         ;#69AF: 21 05 6A
        rrca                                                   ;#69B2: 0F
        jr      nc,DRAW_DISK_ERROR_MSG_AT_DE                   ;#69B3: 30 03
DRAW_DISK_ERROR_OFFLINE_MSG:
        ; Set HL=TXT_DISK_OFFLINE when RC code maps to the "disk offline" subset
        ld      hl,TXT_DISK_OFFLINE                            ;#69B5: 21 16 6A
DRAW_DISK_ERROR_MSG_AT_DE:
        ; Common tail: render the chosen error-msg text at (SUBMENU_BODY_VRAM_BASE)+40h
        ex      de,hl                                          ;#69B8: EB
        ld      hl,(SUBMENU_BODY_VRAM_BASE)                    ;#69B9: 2A 6E D1
        ld      bc,40h                                         ;#69BC: 01 40 00
        add     hl,bc                                          ;#69BF: 09
        ex      de,hl                                          ;#69C0: EB
        ld      bc,11h                                         ;#69C1: 01 11 00
        push    de                                             ;#69C4: D5
        call    BIOS_LDIRVM                                    ;#69C5: CD 5C 00
        pop     hl                                             ;#69C8: E1
        ld      bc,40h                                         ;#69C9: 01 40 00
        add     hl,bc                                          ;#69CC: 09
        ex      de,hl                                          ;#69CD: EB
        ld      hl,TXT_RETURN_RETRY_PROMPT                     ;#69CE: 21 27 6A
        push    de                                             ;#69D1: D5
        call    DRAW_TEXT_STREAM_AT_DE                         ;#69D2: CD 0F 61
        pop     hl                                             ;#69D5: E1
        ld      bc,20h                                         ;#69D6: 01 20 00
        add     hl,bc                                          ;#69D9: 09
        ld      de,TXT_SPACE_ABORT_PROMPT                      ;#69DA: 11 39 6A
        ex      de,hl                                          ;#69DD: EB
        call    DRAW_TEXT_STREAM_AT_DE                         ;#69DE: CD 0F 61
        call    BIOS_KILBUF                                    ;#69E1: CD 56 01
DISK_ERROR_WAIT_KEY:
        ; Wait CHGET: RETURN -> retry (set CY), SPACE -> abort; ignore other keys
        call    BIOS_CHGET                                     ;#69E4: CD 9F 00
        cp      CHAR_RETURN                                    ;#69E7: FE 0D
        jr      z,DISK_ERROR_WAIT_RETURN                       ;#69E9: 28 06
        cp      CHAR_SPACE                                     ;#69EB: FE 20
        jr      z,DISK_ERROR_FINAL_ABORT                       ;#69ED: 28 11
        jr      DISK_ERROR_WAIT_KEY                            ;#69EF: 18 F3

DISK_ERROR_WAIT_RETURN:
        ; RETURN pressed: clear CY, ret (caller retries)
        and     a                                              ;#69F1: A7
        ret                                                    ;#69F2: C9

DISK_ERROR_WAIT_SPACE:
        ; SPACE pressed: redraw abort message at (SUBMENU_BODY_VRAM_BASE)+40h
        ld      hl,(SUBMENU_BODY_VRAM_BASE)                    ;#69F3: 2A 6E D1
        ld      bc,40h                                         ;#69F6: 01 40 00
        add     hl,bc                                          ;#69F9: 09
        ex      de,hl                                          ;#69FA: EB
        ld      c,5                                            ;#69FB: 0E 05
        call    DRAW_DISK_ERROR_AND_WAIT                       ;#69FD: CD 96 68
DISK_ERROR_FINAL_ABORT:
        ; Clear menu display, scf, ret — abort propagates up to SP_SAVE_FOR_BDOS
        call    CLEAR_MENU_DISPLAY_AREA                        ;#6A00: CD DD 61
        scf                                                    ;#6A03: 37
        ret                                                    ;#6A04: C9

TXT_WRITE_PROTECTED:
        ; 17-byte "=WRITE PROTECTED=" message line for the disk-error UI
        db      "=WRITE", 0, "PROTECTED="                      ;#6A05: 3D 57 52 49 54 45 00 50 52 4F 54 45 43 54 45 44 3D

TXT_DISK_OFFLINE:
        ; 17-byte "==DISK OFFLINE==" message line for the disk-error UI
        db      "=DISK", 0, "OFFLINE=", 0, 0, 0                ;#6A16: 3D 44 49 53 4B 00 4F 46 46 4C 49 4E 45 3D 00 00 00

TXT_RETURN_RETRY_PROMPT:
        ; 18-byte "RETURN KEY@@RETRY" prompt text stream
        db      "RETURN", 0, "KEY@@RETRY"                      ;#6A27: 52 45 54 55 52 4E 00 4B 45 59 40 40 52 45 54 52 59
        TEXT_TERMINATOR                                        ;#6A38: FF

TXT_SPACE_ABORT_PROMPT:
        ; 18-byte "SPACE KEY@@ABORT" prompt text stream
        db      "SPACE", 0, "KEY", 0, "@@ABORT"                ;#6A39: 53 50 41 43 45 00 4B 45 59 00 40 40 41 42 4F 52 54
        TEXT_TERMINATOR                                        ;#6A4A: FF

FILE_PICKER:
        ; Interactive file-picker submenu: scan directory, render list, navigate, pick
        xor     a                                              ;#6A4B: AF
        ld      (MENU_SELECTED_INDEX),a                        ;#6A4C: 32 63 D1
        ld      (MENU_CURRENT_INDEX),a                         ;#6A4F: 32 65 D1
        LOAD_NAME_TABLE hl, 19, 12                             ;#6A52: 21 6C 3A
        ld      (MENU_CURSOR_VRAM_ADDR),hl                     ;#6A55: 22 68 D1
        ld      (MENU_TABLE_PTR),hl                            ;#6A58: 22 6A D1
        ld      a,80h                                          ;#6A5B: 3E 80
        ld      (MENU_MAX_INDEX),a                             ;#6A5D: 32 64 D1
ENTER_FILE_PICKER_AT_VRAM:
        ; Entry that calls PATCH_MENU_FONT_TILES then falls into FILE_PICKER
        call    PATCH_MENU_FONT_TILES                          ;#6A60: CD 73 64
        ld      (SP_SAVE_FOR_BDOS),sp                          ;#6A63: ED 73 27 D1
        call    INIT_BDOS_FILENAME_BUFFER                      ;#6A67: CD 89 6B
        call    SCAN_DIRECTORY_FOR_FILES                       ;#6A6A: CD B3 6B
        jp      z,DRAW_NO_FILE_PROMPT                          ;#6A6D: CA 02 6B
        call    DRAW_SELECT_FILE_NAME_PROMPT                   ;#6A70: CD 5C 42
        call    DRAW_MENU_CURSOR                               ;#6A73: CD E8 63
FILE_PICKER_REDRAW_POLL:
        ; Render file list page + KILBUF/CHGET key-poll loop body (jr nz back here)
        call    RENDER_FILE_LIST_PAGE                          ;#6A76: CD 3D 6B
        call    BIOS_KILBUF                                    ;#6A79: CD 56 01
FILE_PICKER_POLL_KEY:
        ; KILBUF + CHGET inner loop reentry after an ignored key
        ld      hl,MENU_SELECTED_INDEX                         ;#6A7C: 21 63 D1
        ld      de,MENU_CURRENT_INDEX                          ;#6A7F: 11 65 D1
        call    BIOS_CHGET                                     ;#6A82: CD 9F 00
        cp      CHAR_KEY_UP                                    ;#6A85: FE 1E
        jr      z,FILE_PICKER_UP_ARROW                         ;#6A87: 28 69
        cp      CHAR_KEY_DOWN                                  ;#6A89: FE 1F
        jr      z,FILE_PICKER_DOWN_ARROW                       ;#6A8B: 28 2D
        cp      CHAR_SPACE                                     ;#6A8D: FE 20
        jr      nz,FILE_PICKER_POLL_KEY                        ;#6A8F: 20 EB
        ld      a,(MENU_SELECTED_INDEX)                        ;#6A91: 3A 63 D1
        ld      hl,FILE_LIST_COUNT                             ;#6A94: 21 4E D3
        cp      (hl)                                           ;#6A97: BE
        ccf                                                    ;#6A98: 3F
        ret     c                                              ;#6A99: D8
        call    GET_FILE_LIST_SLOT_ADDR                        ;#6A9A: CD 1B 6C
        push    hl                                             ;#6A9D: E5
        call    INIT_FCB_WILDCARD                              ;#6A9E: CD 96 6B
        pop     hl                                             ;#6AA1: E1
        ld      de,FCB_BUFFER                                  ;#6AA2: 11 00 D1
        ld      (FCB_POINTER),de                               ;#6AA5: ED 53 25 D1
        inc     de                                             ;#6AA9: 13
        ld      a,(TOP_MENU_MODE)                              ;#6AAA: 3A 29 D1
        cp      1                                              ;#6AAD: FE 01
        ld      bc,8                                           ;#6AAF: 01 08 00
        jr      nz,FILE_PICKER_COPY_NAME                       ;#6AB2: 20 02
        ld      c,0Bh                                          ;#6AB4: 0E 0B
FILE_PICKER_COPY_NAME:
        ; LDIR Bh- or 8-byte filename from picker selection into the FCB
        ldir                                                   ;#6AB6: ED B0
        or      a                                              ;#6AB8: B7
        ret                                                    ;#6AB9: C9

FILE_PICKER_DOWN_ARROW:
        ; Down-arrow path: clamp current index against FILE_LIST_COUNT
        ld      a,(FILE_LIST_COUNT)                            ;#6ABA: 3A 4E D3
        cp      (hl)                                           ;#6ABD: BE
        jr      z,FILE_PICKER_POLL_KEY                         ;#6ABE: 28 BC
        inc     (hl)                                           ;#6AC0: 34
        ld      a,(de)                                         ;#6AC1: 1A
        ld      b,a                                            ;#6AC2: 47
        ld      a,(hl)                                         ;#6AC3: 7E
        sub     b                                              ;#6AC4: 90
        cp      3                                              ;#6AC5: FE 03
        jr      c,FILE_PICKER_DOWN_STEP_20                     ;#6AC7: 38 08
        inc     b                                              ;#6AC9: 04
        ld      a,b                                            ;#6ACA: 78
        ld      (de),a                                         ;#6ACB: 12
        ld      bc,0                                           ;#6ACC: 01 00 00
        jr      FILE_PICKER_MOVE_CURSOR                        ;#6ACF: 18 03

FILE_PICKER_DOWN_STEP_20:
        ; Set BC=20h (full-row step) before falling into MOVE_CURSOR
        ld      bc,20h                                         ;#6AD1: 01 20 00
FILE_PICKER_MOVE_CURSOR:
        ; ERASE_MENU_CURSOR, add hl,bc, range-check via rst 20h, redraw cursor
        call    ERASE_MENU_CURSOR                              ;#6AD4: CD F0 63
        add     hl,bc                                          ;#6AD7: 09
        push    hl                                             ;#6AD8: E5
        ld      de,(MENU_TABLE_PTR)                            ;#6AD9: ED 5B 6A D1
        and     a                                              ;#6ADD: A7
        sbc     hl,de                                          ;#6ADE: ED 52
        ld      a,(MENU_MAX_INDEX)                             ;#6AE0: 3A 64 D1
        ld      d,0                                            ;#6AE3: 16 00
        ld      e,a                                            ;#6AE5: 5F
        rst     20h                                            ;#6AE6: E7
        pop     hl                                             ;#6AE7: E1
        jr      nc,FILE_PICKER_REDRAW_CURSOR                   ;#6AE8: 30 03
        ld      (MENU_CURSOR_VRAM_ADDR),hl                     ;#6AEA: 22 68 D1

FILE_PICKER_REDRAW_CURSOR:
        ; Common merge after cursor moved: redraw at new position
        call    DRAW_MENU_CURSOR                               ;#6AED: CD E8 63
        jr      FILE_PICKER_REDRAW_POLL                        ;#6AF0: 18 84

FILE_PICKER_UP_ARROW:
        ; Up-arrow path: read (hl), if 0 ignore; else compute backstep
        ld      a,(hl)                                         ;#6AF2: 7E
        or      a                                              ;#6AF3: B7
        jr      z,FILE_PICKER_POLL_KEY                         ;#6AF4: 28 86
        dec     (hl)                                           ;#6AF6: 35
        ex      de,hl                                          ;#6AF7: EB
        ld      a,(de)                                         ;#6AF8: 1A
        cp      (hl)                                           ;#6AF9: BE
        jr      nc,CHECK_FILE_NAME_INPUT_END                   ;#6AFA: 30 01
        dec     (hl)                                           ;#6AFC: 35
CHECK_FILE_NAME_INPUT_END:
        ; Helper inside FILE_PICKER's UP-arrow path — adjust cursor on bounds
        ld      bc,VRAM_ROW_BACK_STEP                          ;#6AFD: 01 E0 FF
        jr      FILE_PICKER_MOVE_CURSOR                        ;#6B00: 18 D2

DRAW_NO_FILE_PROMPT:
        ; Show "NO FILE / HIT RETURN KEY" empty-directory prompt, wait for RETURN
        ld      hl,TXT_NO_FILE                                 ;#6B02: 21 26 6B
        ld      de,(MENU_TABLE_PTR)                            ;#6B05: ED 5B 6A D1
        call    DRAW_TEXT_STREAM_AT_DE                         ;#6B09: CD 0F 61
        ld      de,TXT_HIT_RETURN_KEY_3                        ;#6B0C: 11 2E 6B
        ld      hl,(MENU_TABLE_PTR)                            ;#6B0F: 2A 6A D1
        ld      bc,40h                                         ;#6B12: 01 40 00
        add     hl,bc                                          ;#6B15: 09
        ex      de,hl                                          ;#6B16: EB
        call    DRAW_TEXT_STREAM_AT_DE                         ;#6B17: CD 0F 61
        call    BIOS_KILBUF                                    ;#6B1A: CD 56 01
FILE_PICKER_NO_FILE_WAIT:
        ; "NO FILE / RETURN" prompt: KILBUF + CHGET wait-for-RETURN loop
        call    BIOS_CHGET                                     ;#6B1D: CD 9F 00
        cp      CHAR_RETURN                                    ;#6B20: FE 0D
        jr      nz,FILE_PICKER_NO_FILE_WAIT                    ;#6B22: 20 F9
        scf                                                    ;#6B24: 37
        ret                                                    ;#6B25: C9

TXT_NO_FILE:
        ; 8-byte "NO FILE" message rendered when the directory scan finds nothing
        db      "NO", 0, "FILE"                                ;#6B26: 4E 4F 00 46 49 4C 45
        TEXT_TERMINATOR                                        ;#6B2D: FF

TXT_HIT_RETURN_KEY_3:
        ; Third copy of "HIT RETURN KEY" used by the file picker's empty-dir path
        db      "HIT", 0, "RETURN", 0, "KEY"                   ;#6B2E: 48 49 54 00 52 45 54 55 52 4E 00 4B 45 59
        TEXT_TERMINATOR                                        ;#6B3C: FF

RENDER_FILE_LIST_PAGE:
        ; Render 3 file-list rows at MENU_CURSOR_VRAM_ADDR (8-byte name + optional ext)
        ld      a,(MENU_CURRENT_INDEX)                         ;#6B3D: 3A 65 D1
        call    GET_FILE_LIST_SLOT_ADDR                        ;#6B40: CD 1B 6C
        ld      de,(MENU_TABLE_PTR)                            ;#6B43: ED 5B 6A D1
        inc     de                                             ;#6B47: 13
        inc     de                                             ;#6B48: 13
        ex      de,hl                                          ;#6B49: EB
        ld      b,3                                            ;#6B4A: 06 03
RENDER_FILE_LIST_ROW:
        ; Per-row body: save count, set up name+ext write
        push    bc                                             ;#6B4C: C5
        push    hl                                             ;#6B4D: E5
        push    hl                                             ;#6B4E: E5
        xor     a                                              ;#6B4F: AF
        ld      bc,0Ch                                         ;#6B50: 01 0C 00
        call    BIOS_FILVRM                                    ;#6B53: CD 56 00
        pop     hl                                             ;#6B56: E1
        ld      b,8                                            ;#6B57: 06 08
RENDER_FILE_LIST_NAME_LOOP:
        ; 8-byte name copy with space-padding (3Ch for trailing)
        ld      a,(de)                                         ;#6B59: 1A
        cp      CHAR_SPACE                                     ;#6B5A: FE 20
        jr      z,RENDER_FILE_LIST_NEXT_BYTE                   ;#6B5C: 28 04
        call    BIOS_WRTVRM                                    ;#6B5E: CD 4D 00
        inc     hl                                             ;#6B61: 23
RENDER_FILE_LIST_NEXT_BYTE:
        ; Advance both pointers, djnz to continue
        inc     de                                             ;#6B62: 13
        djnz    RENDER_FILE_LIST_NAME_LOOP                     ;#6B63: 10 F4
        ld      a,(TOP_MENU_MODE)                              ;#6B65: 3A 29 D1
        cp      1                                              ;#6B68: FE 01
        jr      nz,RENDER_FILE_LIST_NEXT_ROW                   ;#6B6A: 20 14
        ld      a,(de)                                         ;#6B6C: 1A
        or      a                                              ;#6B6D: B7
        jr      z,RENDER_FILE_LIST_DOT                         ;#6B6E: 28 02
        ld      a,3Ch                                          ;#6B70: 3E 3C
RENDER_FILE_LIST_DOT:
        ; Write '.' separator before extension (when row has an ext)
        call    BIOS_WRTVRM                                    ;#6B72: CD 4D 00
        inc     hl                                             ;#6B75: 23
        ld      b,3                                            ;#6B76: 06 03
RENDER_FILE_LIST_EXT_LOOP:
        ; 3-byte extension copy
        ld      a,(de)                                         ;#6B78: 1A
        call    BIOS_WRTVRM                                    ;#6B79: CD 4D 00
        inc     de                                             ;#6B7C: 13
        inc     hl                                             ;#6B7D: 23
        djnz    RENDER_FILE_LIST_EXT_LOOP                      ;#6B7E: 10 F8
RENDER_FILE_LIST_NEXT_ROW:
        ; Pop start, advance by 20h to next row, djnz outer loop
        pop     hl                                             ;#6B80: E1
        ld      bc,20h                                         ;#6B81: 01 20 00
        add     hl,bc                                          ;#6B84: 09
        pop     bc                                             ;#6B85: C1
        djnz    RENDER_FILE_LIST_ROW                           ;#6B86: 10 C4
        ret                                                    ;#6B88: C9

INIT_BDOS_FILENAME_BUFFER:
        ; Zero 108h bytes at SCRATCH_HEADER_OR_DTA — the DTA for F_SFIRST/F_SNEXT to fill
        ld      hl,SCRATCH_HEADER_OR_DTA                       ;#6B89: 21 51 D3
        ld      de,FILE_PICKER_DTA                             ;#6B8C: 11 52 D3
        ld      (hl),0                                         ;#6B8F: 36 00
        ld      bc,107h                                        ;#6B91: 01 07 01
        ldir                                                   ;#6B94: ED B0
INIT_FCB_WILDCARD:
        ; FCB at FCB_BUFFER: zero header, set 11-byte name area to "???????????"
        ld      hl,FCB_BUFFER                                  ;#6B96: 21 00 D1
        ld      de,FCB_NAME                                    ;#6B99: 11 01 D1
        ld      (hl),0                                         ;#6B9C: 36 00
        ld      bc,24h                                         ;#6B9E: 01 24 00
        ldir                                                   ;#6BA1: ED B0
        ld      hl,FCB_NAME                                    ;#6BA3: 21 01 D1
        ld      de,FCB_NAME+1                                  ;#6BA6: 11 02 D1
        ld      (hl),"?"                                       ;#6BA9: 36 3F
        ld      bc,0Ah                                         ;#6BAB: 01 0A 00
        ldir                                                   ;#6BAE: ED B0
        jp      SET_FCB_EXTENSION_FROM_PARAM                   ;#6BB0: C3 41 67

SCAN_DIRECTORY_FOR_FILES:
        ; PREPARE_FOR_BDOS, F_SFIRST then F_SNEXT loop, fill file list, append "END"
        call    PREPARE_RAM_FOR_BDOS                           ;#6BB3: CD C8 66
        xor     a                                              ;#6BB6: AF
        ld      (FILE_LIST_COUNT),a                            ;#6BB7: 32 4E D3
        ld      de,SCRATCH_HEADER_OR_DTA                       ;#6BBA: 11 51 D3
        ld      c,BDOS_SET_DTA                                 ;#6BBD: 0E 1A
        call    BDOS                                           ;#6BBF: CD 7D F3
        ld      de,FCB_BUFFER                                  ;#6BC2: 11 00 D1
        ld      c,BDOS_SEARCH_FIRST                            ;#6BC5: 0E 11
        call    BDOS                                           ;#6BC7: CD 7D F3
        inc     a                                              ;#6BCA: 3C
        jr      z,SCAN_DIRECTORY_RESTORE                       ;#6BCB: 28 29
SCAN_DIRECTORY_STORE_ENTRY:
        ; Found a name: inc FILE_LIST_COUNT, store name into next slot
        ld      hl,FILE_LIST_COUNT                             ;#6BCD: 21 4E D3
        inc     (hl)                                           ;#6BD0: 34
        push    hl                                             ;#6BD1: E5
        call    STORE_FOUND_FILENAME                           ;#6BD2: CD 06 6C
        pop     hl                                             ;#6BD5: E1
        ld      a,(hl)                                         ;#6BD6: 7E
        cp      14h                                            ;#6BD7: FE 14
        jr      z,SCAN_DIRECTORY_DONE                          ;#6BD9: 28 0B
        ld      de,FCB_BUFFER                                  ;#6BDB: 11 00 D1
        ld      c,BDOS_SEARCH_NEXT                             ;#6BDE: 0E 12
        call    BDOS                                           ;#6BE0: CD 7D F3
        inc     a                                              ;#6BE3: 3C
        jr      nz,SCAN_DIRECTORY_STORE_ENTRY                  ;#6BE4: 20 E7
SCAN_DIRECTORY_DONE:
        ; After F_SNEXT loop: push count, append "@@END@@" sentinel, restore RAM
        ld      a,(FILE_LIST_COUNT)                            ;#6BE6: 3A 4E D3
        push    af                                             ;#6BE9: F5
        ld      de,TXT_END_FILE_ENTRY                          ;#6BEA: 11 FB 6B
        call    COPY_NAME_TO_LIST_ENTRY                        ;#6BED: CD 0D 6C
        call    RESTORE_RAM_AFTER_BDOS                         ;#6BF0: CD DF 66
        pop     af                                             ;#6BF3: F1
        or      a                                              ;#6BF4: B7
        ret                                                    ;#6BF5: C9

SCAN_DIRECTORY_RESTORE:
        ; RESTORE_RAM_AFTER_BDOS + clear A and return
        call    RESTORE_RAM_AFTER_BDOS                         ;#6BF6: CD DF 66
        xor     a                                              ;#6BF9: AF
        ret                                                    ;#6BFA: C9

TXT_END_FILE_ENTRY:
        ; 11-byte "@@END@@" entry appended to the file list as the last navigable item
        db      "@@END@@", 0, 0, 0, 0                          ;#6BFB: 40 40 45 4E 44 40 40 00 00 00 00

STORE_FOUND_FILENAME:
        ; Copy filename from FILE_PICKER_DTA into the next FILE_LIST_BUFFER slot
        ld      de,FILE_PICKER_DTA                             ;#6C06: 11 52 D3
        ld      a,(FILE_LIST_COUNT)                            ;#6C09: 3A 4E D3
        dec     a                                              ;#6C0C: 3D
COPY_NAME_TO_LIST_ENTRY:
        ; Copy 8 (or 11 if SELF mode) bytes from DE to FILE_LIST_BUFFER slot at index A
        call    GET_FILE_LIST_SLOT_ADDR                        ;#6C0D: CD 1B 6C
        ex      de,hl                                          ;#6C10: EB
        ld      bc,8                                           ;#6C11: 01 08 00
        jr      z,STORE_FOUND_FILENAME_DO                      ;#6C14: 28 02
        ld      c,0Bh                                          ;#6C16: 0E 0B
STORE_FOUND_FILENAME_DO:
        ; Merge after stride selection: LDIR the name bytes into the slot
        ldir                                                   ;#6C18: ED B0
        ret                                                    ;#6C1A: C9

GET_FILE_LIST_SLOT_ADDR:
        ; HL = FILE_LIST_BUFFER + A*(8 or 11 by TOP_MENU_MODE) — slot A pointer
        ld      l,a                                            ;#6C1B: 6F
        ld      h,0                                            ;#6C1C: 26 00
        ld      a,(TOP_MENU_MODE)                              ;#6C1E: 3A 29 D1
        cp      1                                              ;#6C21: FE 01
        jr      z,GET_FILE_LIST_SLOT_STRIDE8                   ;#6C23: 28 05
        add     hl,hl                                          ;#6C25: 29
        add     hl,hl                                          ;#6C26: 29
        add     hl,hl                                          ;#6C27: 29
        jr      GET_FILE_LIST_SLOT_TAIL                        ;#6C28: 18 09

GET_FILE_LIST_SLOT_STRIDE8:
        ; 8-byte-stride path (non-SELF mode): HL = A*8
        ld      b,h                                            ;#6C2A: 44
        ld      c,l                                            ;#6C2B: 4D
        add     hl,hl                                          ;#6C2C: 29
        add     hl,bc                                          ;#6C2D: 09
        add     hl,hl                                          ;#6C2E: 29
        add     hl,hl                                          ;#6C2F: 29
        and     a                                              ;#6C30: A7
        sbc     hl,bc                                          ;#6C31: ED 42
GET_FILE_LIST_SLOT_TAIL:
        ; Merge after stride computation: add FILE_LIST_BUFFER base, clear CY, ret
        ld      bc,FILE_LIST_BUFFER                            ;#6C33: 01 72 D3
        add     hl,bc                                          ;#6C36: 09
        or      a                                              ;#6C37: B7
        ret                                                    ;#6C38: C9

RLE_COMPRESS_VRAM_BUFFER:
        ; Encode 2KB RLE_RAW_INPUT to RLE_COMPRESSED_OUTPUT (DECOMPRESS_RLE format)
        ld      hl,RLE_RAW_INPUT                               ;#6C39: 21 02 C8
        ld      de,RLE_COMPRESSED_OUTPUT                       ;#6C3C: 11 02 C0
RLE_COMPRESS_NEW_BLOCK:
        ; Start a new run/literal block: save DE as RLE_RUN_HEADER_PTR, set header byte
        ld      a,81h                                          ;#6C3F: 3E 81
        ld      (RLE_RUN_HEADER_BYTE),a                        ;#6C41: 32 3E D1
        ld      c,(hl)                                         ;#6C44: 4E
        ld      (RLE_RUN_HEADER_PTR),de                        ;#6C45: ED 53 3F D1
        inc     de                                             ;#6C49: 13
        ld      a,c                                            ;#6C4A: 79
        ld      (de),a                                         ;#6C4B: 12
        inc     hl                                             ;#6C4C: 23
        inc     de                                             ;#6C4D: 13
        call    CHECK_RLE_RAW_INPUT_END                        ;#6C4E: CD C2 6C
        jp      z,RLE_FINALIZE_TERMINATE                       ;#6C51: CA E1 6C
        ld      a,c                                            ;#6C54: 79
        cp      (hl)                                           ;#6C55: BE
        jr      z,RLE_LIT_TO_RUN                               ;#6C56: 28 3D
        ld      a,1                                            ;#6C58: 3E 01
        ld      (RLE_RUN_HEADER_BYTE),a                        ;#6C5A: 32 3E D1
RLE_COMPRESS_LITERAL_BYTE:
        ; Literal-mode loop body: emit (HL), inc HL, end-check, count (cap 7Fh)
        ld      c,(hl)                                         ;#6C5D: 4E
        inc     hl                                             ;#6C5E: 23
        ld      a,c                                            ;#6C5F: 79
        ld      (de),a                                         ;#6C60: 12
        inc     de                                             ;#6C61: 13
        call    CHECK_RLE_RAW_INPUT_END                        ;#6C62: CD C2 6C
        jp      z,RLE_FINALIZE_INC_HEADER                      ;#6C65: CA D8 6C
        cp      (hl)                                           ;#6C68: BE
        jr      nz,RLE_LIT_INC_COUNT                           ;#6C69: 20 1D
        inc     hl                                             ;#6C6B: 23
        call    CHECK_RLE_RAW_INPUT_END                        ;#6C6C: CD C2 6C
        jr      z,RLE_FINALIZE_BACKTRACK                       ;#6C6F: 28 5C
        cp      (hl)                                           ;#6C71: BE
        dec     hl                                             ;#6C72: 2B
        jr      nz,RLE_LIT_INC_COUNT                           ;#6C73: 20 13
RLE_LIT_CAP_REACHED:
        ; Literal-run cap (7Fh) reached: backtrack 1 byte and start a new block
        dec     hl                                             ;#6C75: 2B
        dec     de                                             ;#6C76: 1B
        push    hl                                             ;#6C77: E5
        ld      hl,(RLE_RUN_HEADER_PTR)                        ;#6C78: 2A 3F D1
        ld      a,(RLE_RUN_HEADER_BYTE)                        ;#6C7B: 3A 3E D1
        set     7,a                                            ;#6C7E: CB FF
        ld      (hl),a                                         ;#6C80: 77
        pop     hl                                             ;#6C81: E1
        ld      (RLE_RUN_HEADER_PTR),de                        ;#6C82: ED 53 3F D1
        jr      RLE_COMPRESS_NEW_BLOCK                         ;#6C86: 18 B7

RLE_LIT_INC_COUNT:
        ; Increment literal-run header byte and continue
        ld      a,(RLE_RUN_HEADER_BYTE)                        ;#6C88: 3A 3E D1
        cp      7Fh                                            ;#6C8B: FE 7F
        jr      z,RLE_LIT_CAP_REACHED                          ;#6C8D: 28 E6
        inc     a                                              ;#6C8F: 3C
        ld      (RLE_RUN_HEADER_BYTE),a                        ;#6C90: 32 3E D1
        jr      RLE_COMPRESS_LITERAL_BYTE                      ;#6C93: 18 C8

RLE_LIT_TO_RUN:
        ; Switch to run mode after detecting a repeat
        ld      a,2                                            ;#6C95: 3E 02
        ld      (RLE_RUN_HEADER_BYTE),a                        ;#6C97: 32 3E D1
RLE_COMPRESS_RUN_BYTE:
        ; Run-mode loop body: same byte repeated, end-check, count (cap 7Fh)
        inc     hl                                             ;#6C9A: 23
        call    CHECK_RLE_RAW_INPUT_END                        ;#6C9B: CD C2 6C
        jr      z,RLE_FINALIZE_TERMINATE                       ;#6C9E: 28 41
        ld      a,c                                            ;#6CA0: 79
        cp      (hl)                                           ;#6CA1: BE
        jr      z,RLE_RUN_INC_COUNT                            ;#6CA2: 28 11
RLE_RUN_FLUSH_AND_NEW:
        ; Run terminated by non-match: write header, start new block
        ld      de,(RLE_RUN_HEADER_PTR)                        ;#6CA4: ED 5B 3F D1
        ld      a,(RLE_RUN_HEADER_BYTE)                        ;#6CA8: 3A 3E D1
        ld      (de),a                                         ;#6CAB: 12
        inc     de                                             ;#6CAC: 13
        inc     de                                             ;#6CAD: 13
        ld      (RLE_RUN_HEADER_PTR),de                        ;#6CAE: ED 53 3F D1
        jp      RLE_COMPRESS_NEW_BLOCK                         ;#6CB2: C3 3F 6C

RLE_RUN_INC_COUNT:
        ; Increment run-byte count
        ld      a,(RLE_RUN_HEADER_BYTE)                        ;#6CB5: 3A 3E D1
        cp      7Fh                                            ;#6CB8: FE 7F
        jr      z,RLE_RUN_FLUSH_AND_NEW                        ;#6CBA: 28 E8
        inc     a                                              ;#6CBC: 3C
        ld      (RLE_RUN_HEADER_BYTE),a                        ;#6CBD: 32 3E D1
        jr      RLE_COMPRESS_RUN_BYTE                          ;#6CC0: 18 D8

CHECK_RLE_RAW_INPUT_END:
        ; Z if HL == D002h (end of the 2KB RLE_RAW_INPUT compression input buffer)
        push    hl                                             ;#6CC2: E5
        push    de                                             ;#6CC3: D5
        ld      de,RLE_RAW_INPUT+800h                          ;#6CC4: 11 02 D0
        and     a                                              ;#6CC7: A7
        sbc     hl,de                                          ;#6CC8: ED 52
        pop     de                                             ;#6CCA: D1
        pop     hl                                             ;#6CCB: E1
        ret                                                    ;#6CCC: C9

RLE_FINALIZE_BACKTRACK:
        ; End-of-input cleanup: backtrack and re-emit last byte
        dec     hl                                             ;#6CCD: 2B
        ld      a,(hl)                                         ;#6CCE: 7E
        ld      (de),a                                         ;#6CCF: 12
        inc     de                                             ;#6CD0: 13
        ld      a,(RLE_RUN_HEADER_BYTE)                        ;#6CD1: 3A 3E D1
        inc     a                                              ;#6CD4: 3C
        ld      (RLE_RUN_HEADER_BYTE),a                        ;#6CD5: 32 3E D1
RLE_FINALIZE_INC_HEADER:
        ; Bump the in-progress header byte for the last byte
        ld      a,(RLE_RUN_HEADER_BYTE)                        ;#6CD8: 3A 3E D1
        inc     a                                              ;#6CDB: 3C
        set     7,a                                            ;#6CDC: CB FF
        ld      (RLE_RUN_HEADER_BYTE),a                        ;#6CDE: 32 3E D1
RLE_FINALIZE_TERMINATE:
        ; Final terminator: xor a, ld (de),a — null-byte end marker
        xor     a                                              ;#6CE1: AF
        ld      (de),a                                         ;#6CE2: 12
        ld      a,(RLE_RUN_HEADER_BYTE)                        ;#6CE3: 3A 3E D1
        ld      hl,(RLE_RUN_HEADER_PTR)                        ;#6CE6: 2A 3F D1
        ld      (hl),a                                         ;#6CE9: 77
        ex      de,hl                                          ;#6CEA: EB
        ld      de,SLOT_SCANNER_RAM+1                          ;#6CEB: 11 01 C0
        and     a                                              ;#6CEE: A7
        sbc     hl,de                                          ;#6CEF: ED 52
        ld      (SLOT_SCANNER_RAM),hl                          ;#6CF1: 22 00 C0
        ret                                                    ;#6CF4: C9

TAPE_SAVE_GAME_DATA:
        ; TAPE SAVE GAME DATA: 1100h bytes from E000 with "GAMEDT" header
        ld      hl,0                                           ;#6CF5: 21 00 00
        add     hl,sp                                          ;#6CF8: 39
        push    hl                                             ;#6CF9: E5
        ld      (SP_SAVE_FOR_BDOS),hl                          ;#6CFA: 22 27 D1
        ld      hl,TAPE_HEADER_GAME_DATA                       ;#6CFD: 21 A7 6E
        call    TAPE_INIT                                      ;#6D00: CD 50 6E
        call    TAPE_WRITE_GAME_STATE_RAM                      ;#6D03: CD C4 6E
        call    TAPE_WRITE_VRAM_AS_BLOCKS                      ;#6D06: CD D6 6E
        call    TAPE_WRITE_STACK_AREA                          ;#6D09: CD CC 6E
        pop     hl                                             ;#6D0C: E1
        call    TAPE_DELAY_MEDIUM                              ;#6D0D: CD 43 6E
        call    TAPE_DISPLAY_RESULT                            ;#6D10: CD BF 6E
        ret                                                    ;#6D13: C9

TAPE_SAVE_SCREEN:
        ; TAPE SAVE SCREEN: 82h-byte screen dump at SP_SAVE_FOR_BDOS ("SCREEN" header)
        ld      (SP_SAVE_FOR_BDOS),sp                          ;#6D14: ED 73 27 D1
        ld      hl,TAPE_HEADER_SCREEN                          ;#6D18: 21 AD 6E
        call    TAPE_INIT                                      ;#6D1B: CD 50 6E
        call    TAPE_WRITE_VRAM_AS_BLOCKS                      ;#6D1E: CD D6 6E
        call    TAPE_DELAY_MEDIUM                              ;#6D21: CD 43 6E
        call    TAPE_DISPLAY_RESULT                            ;#6D24: CD BF 6E
        ret                                                    ;#6D27: C9

TAPE_SAVE_RANKING:
        ; TAPE SAVE item RANKING DATA: save ranking buffer with "RANKDT" header
        ld      (SP_SAVE_FOR_BDOS),sp                          ;#6D28: ED 73 27 D1
        ld      hl,TAPE_HEADER_RANKING                         ;#6D2C: 21 B9 6E
        call    TAPE_INIT                                      ;#6D2F: CD 50 6E
        call    RANKING_RECORD_BOTH                            ;#6D32: CD 74 55
        call    TAPE_WRITE_RANKING_BUFFER                      ;#6D35: CD 0F 6F
        call    TAPE_DELAY_MEDIUM                              ;#6D38: CD 43 6E
        call    TAPE_DISPLAY_RESULT                            ;#6D3B: CD BF 6E
        ret                                                    ;#6D3E: C9

TAPE_SAVE_HISCORE:
        ; TAPE SAVE item HI SCORE: save hi-score buffer with "HISCOR" header
        ld      (SP_SAVE_FOR_BDOS),sp                          ;#6D3F: ED 73 27 D1
        ld      hl,TAPE_HEADER_HISCORE                         ;#6D43: 21 B3 6E
        call    TAPE_INIT                                      ;#6D46: CD 50 6E
        call    TAPE_WRITE_HISCORE_3                           ;#6D49: CD 17 6F
        call    TAPE_DELAY_MEDIUM                              ;#6D4C: CD 43 6E
        call    TAPE_DISPLAY_RESULT                            ;#6D4F: CD BF 6E
        ret                                                    ;#6D52: C9

TAPE_LOAD_GAME_DATA:
        ; TAPE LOAD GAME DATA: 1100h bytes back to E000 with "GAMEDT" header
        ld      (SP_SAVE_FOR_BDOS),sp                          ;#6D53: ED 73 27 D1
        ld      hl,TAPE_HEADER_GAME_DATA                       ;#6D57: 21 A7 6E
        call    TAPE_LOAD_FIND_HEADER                          ;#6D5A: CD 47 6F
        call    TAPE_READ_GAME_STATE_RAM                       ;#6D5D: CD 25 70
        call    TAPE_READ_VRAM_AS_BLOCKS                       ;#6D60: CD 2D 70
        ld      hl,SLOT_SCANNER_RAM                            ;#6D63: 21 00 C0
        ld      bc,82h                                         ;#6D66: 01 82 00
        call    TAPE_READ_DATA_BLOCK                           ;#6D69: CD 69 70
        ld      de,RLE_COMPRESSED_OUTPUT                       ;#6D6C: 11 02 C0
        ld      hl,(SLOT_SCANNER_RAM)                          ;#6D6F: 2A 00 C0
        ld      sp,hl                                          ;#6D72: F9
        ex      de,hl                                          ;#6D73: EB
        ld      bc,80h                                         ;#6D74: 01 80 00
        ldir                                                   ;#6D77: ED B0
        jp      TAPE_CLOSE_INPUT                               ;#6D79: C3 20 70

TAPE_LOAD_SCREEN:
        ; TAPE LOAD screen dump with "SCREEN" header; called from LOAD_SCREEN_FROM_TAPE
        ld      (SP_SAVE_FOR_BDOS),sp                          ;#6D7C: ED 73 27 D1
        ld      hl,TAPE_HEADER_SCREEN                          ;#6D80: 21 AD 6E
        call    TAPE_LOAD_FIND_HEADER                          ;#6D83: CD 47 6F
        call    TAPE_DELAY_BRIEF                               ;#6D86: CD 3F 6E
        call    TAPE_READ_VRAM_AS_BLOCKS                       ;#6D89: CD 2D 70
        call    TAPE_CLOSE_INPUT                               ;#6D8C: CD 20 70
        ret                                                    ;#6D8F: C9

TAPE_LOAD_RANKING:
        ; TAPE LOAD item RANKING DATA: load ranking buffer with "RANKDT" header
        ld      (SP_SAVE_FOR_BDOS),sp                          ;#6D90: ED 73 27 D1
        ld      hl,TAPE_HEADER_RANKING                         ;#6D94: 21 B9 6E
        call    TAPE_LOAD_FIND_HEADER                          ;#6D97: CD 47 6F
        call    TAPE_READ_RANKING_BUFFER                       ;#6D9A: CD 59 70
        call    PURGE_RANKING_BOTH                             ;#6D9D: CD D2 54
        call    TAPE_CLOSE_INPUT                               ;#6DA0: CD 20 70
        ret                                                    ;#6DA3: C9

TAPE_LOAD_HISCORE:
        ; TAPE LOAD item HI SCORE: load hi-score buffer with "HISCOR" header
        ld      (SP_SAVE_FOR_BDOS),sp                          ;#6DA4: ED 73 27 D1
        ld      hl,TAPE_HEADER_HISCORE                         ;#6DA8: 21 B3 6E
        call    TAPE_LOAD_FIND_HEADER                          ;#6DAB: CD 47 6F
        call    TAPE_READ_HISCORE_3                            ;#6DAE: CD 61 70
        call    TAPE_CLOSE_INPUT                               ;#6DB1: CD 20 70
        ret                                                    ;#6DB4: C9

TAPE_FAIL_IO_ERROR:
        ; Show "TAPE IO ERROR" + "HIT RETURN KEY"; wait; restore sp from SP_SAVE_FOR_BDOS
        xor     a                                              ;#6DB5: AF
        jr      TAPE_FAIL_BODY                                 ;#6DB6: 18 02

TAPE_FAIL_SUM_ERROR:
        ; Show "SUM CHECK ERROR" + "HIT RETURN KEY"; wait; restore SP_SAVE_FOR_BDOS
        ld      a,1                                            ;#6DB8: 3E 01
TAPE_FAIL_BODY:
        ; Shared body: stops motor (STMOTR FF), draws message + prompt, polls key
        push    af                                             ;#6DBA: F5
        ld      a,0FFh                                         ;#6DBB: 3E FF
        call    BIOS_STMOTR                                    ;#6DBD: CD F3 00
        call    SAVE_GAME_DISPLAY_IF_GAME_ACTIVE               ;#6DC0: CD B5 62
        call    DRAW_SUBMENU_HEADING                           ;#6DC3: CD 47 45
        call    DRAW_SUBMENU_SUBHEADING                        ;#6DC6: CD 9F 45
        pop     af                                             ;#6DC9: F1
        or      a                                              ;#6DCA: B7
        ld      hl,TXT_TAPE_IO_ERROR                           ;#6DCB: 21 F8 6D
        jr      z,TAPE_ERROR_DRAW_MSG                          ;#6DCE: 28 03
        ld      hl,TXT_SUM_CHECK_ERROR                         ;#6DD0: 21 08 6E
TAPE_ERROR_DRAW_MSG:
        ; Common tail: draw chosen error message at SUBMENU_BODY_VRAM_BASE
        ld      de,(SUBMENU_BODY_VRAM_BASE)                    ;#6DD3: ED 5B 6E D1
        push    de                                             ;#6DD7: D5
        call    DRAW_TEXT_STREAM_AT_DE                         ;#6DD8: CD 0F 61
        pop     hl                                             ;#6DDB: E1
        ld      bc,40h                                         ;#6DDC: 01 40 00
        add     hl,bc                                          ;#6DDF: 09
        ld      de,TXT_HIT_RETURN_KEY                          ;#6DE0: 11 18 6E
        ex      de,hl                                          ;#6DE3: EB
        call    DRAW_TEXT_STREAM_AT_DE                         ;#6DE4: CD 0F 61
TAPE_ERROR_WAIT_KEY:
        ; Sample row-7 of keyboard until RETURN/SPACE pressed
        ld      a,7                                            ;#6DE7: 3E 07
        ; SNSMAT row 7; RLA puts bit 7 in carry (RETURN key). Same
        ; 'wait for RETURN press' idiom as 68B7h, here used to dismiss the
        ; tape I/O error screen.
        call    BIOS_SNSMAT                                    ;#6DE9: CD 41 01
        rla                                                    ;#6DEC: 17
        jr      c,TAPE_ERROR_WAIT_KEY                          ;#6DED: 38 F8
        call    RESTORE_GAME_DISPLAY_IF_GAME_ACTIVE            ;#6DEF: CD BD 62
        ld      sp,(SP_SAVE_FOR_BDOS)                          ;#6DF2: ED 7B 27 D1
        scf                                                    ;#6DF6: 37
        ret                                                    ;#6DF7: C9

TXT_TAPE_IO_ERROR:
        ; 16-byte text stream "TAPE IO ERROR\0\0\xFF"
        db      "TAPE", 0, "IO", 0, "ERROR", 0, 0              ;#6DF8: 54 41 50 45 00 49 4F 00 45 52 52 4F 52 00 00
        TEXT_TERMINATOR                                        ;#6E07: FF

TXT_SUM_CHECK_ERROR:
        ; 16-byte text stream "SUM CHECK ERROR\xFF"
        db      "SUM", 0, "CHECK", 0, "ERROR"                  ;#6E08: 53 55 4D 00 43 48 45 43 4B 00 45 52 52 4F 52
        TEXT_TERMINATOR                                        ;#6E17: FF

TXT_HIT_RETURN_KEY:
        ; 16-byte text stream "HIT RETURN KEY\xFF" used as the press-to-continue prompt
        db      "HIT", 0, "RETURN", 0, "KEY"                   ;#6E18: 48 49 54 00 52 45 54 55 52 4E 00 4B 45 59
        TEXT_TERMINATOR                                        ;#6E26: FF

TAPE_OPEN_OUTPUT_LONG:
        ; TAPOON with A=FFh (long header); on carry jumps to TAPE_FAIL_IO_ERROR
        ld      a,0FFh                                         ;#6E27: 3E FF
        call    BIOS_TAPOON                                    ;#6E29: CD EA 00
        jp      c,TAPE_FAIL_IO_ERROR                           ;#6E2C: DA B5 6D
        ret                                                    ;#6E2F: C9

TAPE_DELAY_LONG:
        ; Long inter-block delay: B=0Fh × TAPE_DELAY_INNER (also toggles STMOTR start)
        ld      b,0Fh                                          ;#6E30: 06 0F
        jr      TAPE_DELAY_WITH_MOTOR                          ;#6E32: 18 02

TAPE_DELAY_SHORT:
        ; Shorter delay variant: B=5 × TAPE_DELAY_INNER (also toggles STMOTR start)
        ld      b,5                                            ;#6E34: 06 05
TAPE_DELAY_WITH_MOTOR:
        ; Shared body: push BC, STMOTR(1), pop BC, fall into TAPE_DELAY_INNER
        push    bc                                             ;#6E36: C5
        ld      a,1                                            ;#6E37: 3E 01
        call    BIOS_STMOTR                                    ;#6E39: CD F3 00
        pop     bc                                             ;#6E3C: C1
        jr      TAPE_DELAY_INNER                               ;#6E3D: 18 06

TAPE_DELAY_BRIEF:
        ; Pure busy-loop delay: B=3 × TAPE_DELAY_INNER (no motor toggle)
        ld      b,3                                            ;#6E3F: 06 03
        jr      TAPE_DELAY_INNER                               ;#6E41: 18 02

TAPE_DELAY_MEDIUM:
        ; Pure busy-loop delay: B=5 × TAPE_DELAY_INNER (no motor toggle)
        ld      b,5                                            ;#6E43: 06 05
TAPE_DELAY_INNER:
        ; Inner busy loop: 16-bit dec-to-zero, repeated B times — calibration constant
        ld      de,0                                           ;#6E45: 11 00 00
TAPE_DELAY_INNER_BODY:
        ; Per-iteration body: dec de; or-test for zero; jr nz back
        dec     de                                             ;#6E48: 1B
        ld      a,d                                            ;#6E49: 7A
        or      e                                              ;#6E4A: B3
        jr      nz,TAPE_DELAY_INNER_BODY                       ;#6E4B: 20 FB
        djnz    TAPE_DELAY_INNER                               ;#6E4D: 10 F6
        ret                                                    ;#6E4F: C9

TAPE_INIT:
        ; Common tape-stream init (HL = tape header data block)
        call    PUSH_TAPE_FILE_HEADER                          ;#6E50: CD 97 6E
        ld      hl,SCRATCH_HEADER_OR_DTA                       ;#6E53: 21 51 D3
        ld      de,TXT_FILE_NAME                               ;#6E56: 11 8E 6E
        ld      bc,9                                           ;#6E59: 01 09 00
        call    DRAW_TAPE_FILE_LABEL                           ;#6E5C: CD F6 6F
        call    TAPE_DELAY_LONG                                ;#6E5F: CD 30 6E
        call    TAPE_OPEN_OUTPUT_LONG                          ;#6E62: CD 27 6E
        ld      b,0Ah                                          ;#6E65: 06 0A
TAPE_WRITE_LEADER_LOOP:
        ; Write 10 leader bytes (0Bh each) via BIOS_TAPOUT
        ld      a,0Bh                                          ;#6E67: 3E 0B
        push    bc                                             ;#6E69: C5
        call    BIOS_TAPOUT                                    ;#6E6A: CD ED 00
        pop     bc                                             ;#6E6D: C1
        jp      c,TAPE_FAIL_IO_ERROR                           ;#6E6E: DA B5 6D
        djnz    TAPE_WRITE_LEADER_LOOP                         ;#6E71: 10 F4
        ld      hl,SCRATCH_HEADER_OR_DTA                       ;#6E73: 21 51 D3
        ld      b,8                                            ;#6E76: 06 08
TAPE_WRITE_HEADER_LOOP:
        ; Write the 8 header bytes (filename + RC code) via BIOS_TAPOUT
        ld      a,(hl)                                         ;#6E78: 7E
        push    bc                                             ;#6E79: C5
        push    hl                                             ;#6E7A: E5
        call    BIOS_TAPOUT                                    ;#6E7B: CD ED 00
        pop     hl                                             ;#6E7E: E1
        pop     bc                                             ;#6E7F: C1
        jp      c,TAPE_FAIL_IO_ERROR                           ;#6E80: DA B5 6D
        inc     hl                                             ;#6E83: 23
        djnz    TAPE_WRITE_HEADER_LOOP                         ;#6E84: 10 F2
        call    RESTORE_GAME_DISPLAY_IF_GAME_ACTIVE            ;#6E86: CD BD 62
        xor     a                                              ;#6E89: AF
        call    BIOS_TAPOON                                    ;#6E8A: CD EA 00
        ret                                                    ;#6E8D: C9

TXT_FILE_NAME:
        ; 9-byte "FILE NAME" label rendered above the per-file =HEADER= block
        db      "FILE", 0, "NAME"                              ;#6E8E: 46 49 4C 45 00 4E 41 4D 45

PUSH_TAPE_FILE_HEADER:
        ; Copy caller's 6-byte header to SCRATCH_HEADER_OR_DTA + 2 hex digits of D301
        ld      de,SCRATCH_HEADER_OR_DTA                       ;#6E97: 11 51 D3
        ld      bc,6                                           ;#6E9A: 01 06 00
        ldir                                                   ;#6E9D: ED B0
        ex      de,hl                                          ;#6E9F: EB
        ld      a,(GAME_ID)                                    ;#6EA0: 3A 01 D3
        call    WRITE_BYTE_AS_ASCII_HEX                        ;#6EA3: CD 5D 67
        ret                                                    ;#6EA6: C9

TAPE_HEADER_GAME_DATA:
        ; 6-byte "GAMEDT" header for TAPE_{SAVE,LOAD}_GAME_DATA
        db      "GAMEDT"                                       ;#6EA7: 47 41 4D 45 44 54

TAPE_HEADER_SCREEN:
        ; 6-byte "SCREEN" header for TAPE_{SAVE,LOAD}_SCREEN
        db      "SCREEN"                                       ;#6EAD: 53 43 52 45 45 4E

TAPE_HEADER_HISCORE:
        ; 6-byte "HISCOR" header for TAPE_{SAVE,LOAD}_HISCORE
        db      "HISCOR"                                       ;#6EB3: 48 49 53 43 4F 52

TAPE_HEADER_RANKING:
        ; 6-byte "RANKDT" header for TAPE_{SAVE,LOAD}_RANKING
        db      "RANKDT"                                       ;#6EB9: 52 41 4E 4B 44 54

TAPE_DISPLAY_RESULT:
        ; Show success/error message after a tape operation
        call    BIOS_TAPOOF                                    ;#6EBF: CD F0 00
        xor     a                                              ;#6EC2: AF
        ret                                                    ;#6EC3: C9

TAPE_WRITE_GAME_STATE_RAM:
        ; Write 1100h game-state bytes (E000 RAM) to tape via TAPE_WRITE_DATA_BLOCK
        ld      hl,CHEAT_TARGET_ROAD_FIGHTER_E000              ;#6EC4: 21 00 E0
        ld      bc,1100h                                       ;#6EC7: 01 00 11
        jr      TAPE_WRITE_DATA_BLOCK                          ;#6ECA: 18 53

TAPE_WRITE_STACK_AREA:
        ; Write 82h bytes from SP_SAVE_FOR_BDOS-2 to tape (captured stack frame)
        ld      hl,(SP_SAVE_FOR_BDOS)                          ;#6ECC: 2A 27 D1
        dec     hl                                             ;#6ECF: 2B
        dec     hl                                             ;#6ED0: 2B
        ld      bc,82h                                         ;#6ED1: 01 82 00
        jr      TAPE_WRITE_DATA_BLOCK                          ;#6ED4: 18 49

TAPE_WRITE_VRAM_AS_BLOCKS:
        ; Write VRAM 0..3FFFh as 8× compressed 2KB blocks (RLE_COMPRESS_VRAM_BUFFER)
        ld      hl,0                                           ;#6ED6: 21 00 00
TAPE_WRITE_DATA_LOOP:
        ; Write each data byte via BIOS_TAPOUT, track running sum
        push    hl                                             ;#6ED9: E5
        ld      de,RLE_RAW_INPUT                               ;#6EDA: 11 02 C8
        ld      bc,800h                                        ;#6EDD: 01 00 08
        call    BIOS_LDIRMV                                    ;#6EE0: CD 59 00
        call    RLE_COMPRESS_VRAM_BUFFER                       ;#6EE3: CD 39 6C
        xor     a                                              ;#6EE6: AF
        call    BIOS_TAPOON                                    ;#6EE7: CD EA 00
        ld      hl,(SLOT_SCANNER_RAM)                          ;#6EEA: 2A 00 C0
        push    hl                                             ;#6EED: E5
        ld      a,l                                            ;#6EEE: 7D
        call    BIOS_TAPOUT                                    ;#6EEF: CD ED 00
        pop     hl                                             ;#6EF2: E1
        ld      a,h                                            ;#6EF3: 7C
        call    BIOS_TAPOUT                                    ;#6EF4: CD ED 00
        ld      hl,RLE_COMPRESSED_OUTPUT                       ;#6EF7: 21 02 C0
        ld      bc,(SLOT_SCANNER_RAM)                          ;#6EFA: ED 4B 00 C0
        call    TAPE_WRITE_DATA_BLOCK                          ;#6EFE: CD 1F 6F
        pop     hl                                             ;#6F01: E1
        ld      bc,800h                                        ;#6F02: 01 00 08
        add     hl,bc                                          ;#6F05: 09
        ld      a,h                                            ;#6F06: 7C
        cp      40h                                            ;#6F07: FE 40
        jr      nz,TAPE_WRITE_DATA_LOOP                        ;#6F09: 20 CE
        xor     a                                              ;#6F0B: AF
        jp      BIOS_TAPOON                                    ;#6F0C: C3 EA 00

TAPE_WRITE_RANKING_BUFFER:
        ; Write 78h ranking bytes at RANKING_SCORE_BLOCK via TAPE_WRITE_DATA_BLOCK
        ld      hl,RANKING_SCORE_BLOCK                         ;#6F0F: 21 59 D4
        ld      bc,78h                                         ;#6F12: 01 78 00
        jr      TAPE_WRITE_DATA_BLOCK                          ;#6F15: 18 08

TAPE_WRITE_HISCORE_3:
        ; Write 3 bytes from (GAME_RAM_HISCORE_PTR) to tape (hi-score record)
        ld      hl,(GAME_RAM_HISCORE_PTR)                      ;#6F17: 2A 0C D3
        ld      bc,3                                           ;#6F1A: 01 03 00
        jr      TAPE_WRITE_DATA_BLOCK                          ;#6F1D: 18 00

TAPE_WRITE_DATA_BLOCK:
        ; Write BC bytes from (HL) + 1 byte sum to tape; on carry jp TAPE_FAIL_IO_ERROR
        ld      d,0                                            ;#6F1F: 16 00
TAPE_WRITE_DATA_SUM:
        ; Compute LE word from header and emit data sum byte
        ld      a,(hl)                                         ;#6F21: 7E
        ld      e,a                                            ;#6F22: 5F
        push    bc                                             ;#6F23: C5
        push    hl                                             ;#6F24: E5
        push    de                                             ;#6F25: D5
        call    BIOS_TAPOUT                                    ;#6F26: CD ED 00
        pop     de                                             ;#6F29: D1
        pop     hl                                             ;#6F2A: E1
        pop     bc                                             ;#6F2B: C1
        jp      c,TAPE_FAIL_IO_ERROR                           ;#6F2C: DA B5 6D
        ld      a,e                                            ;#6F2F: 7B
        add     a,d                                            ;#6F30: 82
        ld      d,a                                            ;#6F31: 57
        inc     hl                                             ;#6F32: 23
        dec     bc                                             ;#6F33: 0B
        ld      a,b                                            ;#6F34: 78
        or      c                                              ;#6F35: B1
        jr      nz,TAPE_WRITE_DATA_SUM                         ;#6F36: 20 E9
        ld      a,d                                            ;#6F38: 7A
        call    BIOS_TAPOUT                                    ;#6F39: CD ED 00
        jp      c,TAPE_FAIL_IO_ERROR                           ;#6F3C: DA B5 6D
        ret                                                    ;#6F3F: C9

TAPE_OPEN_INPUT:
        ; TAPION (open tape input); on carry jp TAPE_FAIL_IO_ERROR
        call    BIOS_TAPION                                    ;#6F40: CD E1 00
        jp      c,TAPE_FAIL_IO_ERROR                           ;#6F43: DA B5 6D
        ret                                                    ;#6F46: C9

TAPE_LOAD_FIND_HEADER:
        ; Open tape, scan leader bytes (10x 0Bh), read header, retry until match
        call    PUSH_TAPE_FILE_HEADER                          ;#6F47: CD 97 6E
        call    CLEAR_MENU_DISPLAY_AREA                        ;#6F4A: CD DD 61
TAPE_SEARCH_FILE_LOOP:
        ; Loop: draw "SEARCH FILE", open tape, scan leader, read header; retry on miss
        ld      de,(SUBMENU_BODY_VRAM_BASE)                    ;#6F4D: ED 5B 6E D1
        ld      hl,TXT_SEARCH_FILE                             ;#6F51: 21 E5 6F
        call    DRAW_TEXT_STREAM_AT_DE                         ;#6F54: CD 0F 61
        call    TAPE_OPEN_INPUT                                ;#6F57: CD 40 6F
        ld      b,0Ah                                          ;#6F5A: 06 0A
TAPE_READ_LEADER_LOOP:
        ; Read 10 leader bytes (0Bh) via BIOS_TAPIN, verify each
        push    bc                                             ;#6F5C: C5
        call    BIOS_TAPIN                                     ;#6F5D: CD E4 00
        pop     bc                                             ;#6F60: C1
        cp      0Bh                                            ;#6F61: FE 0B
        jr      nz,TAPE_SEARCH_FILE_LOOP                       ;#6F63: 20 E8
        djnz    TAPE_READ_LEADER_LOOP                          ;#6F65: 10 F5
        ld      hl,SCRATCH_HEADER_OR_DTA                       ;#6F67: 21 51 D3
        ld      de,SCRATCH_HEX_OUTPUT                          ;#6F6A: 11 00 DA
        ld      a,(TOP_MENU_MODE)                              ;#6F6D: 3A 29 D1
        cp      1                                              ;#6F70: FE 01
        ld      b,6                                            ;#6F72: 06 06
        jr      z,TAPE_READ_HEADER_LOOP                        ;#6F74: 28 02
        ld      b,8                                            ;#6F76: 06 08
TAPE_READ_HEADER_LOOP:
        ; Read the 8 header bytes via BIOS_TAPIN
        ld      c,0                                            ;#6F78: 0E 00
TAPE_READ_HEADER_LOOP_INNER:
        ; Per-byte body: push BC, push HL, read+compare
        push    bc                                             ;#6F7A: C5
        push    hl                                             ;#6F7B: E5
        push    de                                             ;#6F7C: D5
        call    BIOS_TAPIN                                     ;#6F7D: CD E4 00
        jp      c,TAPE_FAIL_IO_ERROR                           ;#6F80: DA B5 6D
        pop     de                                             ;#6F83: D1
        pop     hl                                             ;#6F84: E1
        pop     bc                                             ;#6F85: C1
        ld      (de),a                                         ;#6F86: 12
        ld      a,c                                            ;#6F87: 79
        or      a                                              ;#6F88: B7
        jr      nz,TAPE_READ_HEADER_NEXT                       ;#6F89: 20 06
        ld      a,(de)                                         ;#6F8B: 1A
        cp      (hl)                                           ;#6F8C: BE
        jr      z,TAPE_READ_HEADER_NEXT                        ;#6F8D: 28 02
        ld      c,0FFh                                         ;#6F8F: 0E FF
TAPE_READ_HEADER_NEXT:
        ; Advance pointers after one matched byte
        inc     hl                                             ;#6F91: 23
        inc     de                                             ;#6F92: 13
        djnz    TAPE_READ_HEADER_LOOP_INNER                    ;#6F93: 10 E5
        ld      a,(TOP_MENU_MODE)                              ;#6F95: 3A 29 D1
        cp      1                                              ;#6F98: FE 01
        jr      nz,TAPE_READ_HEADER_VERIFY                     ;#6F9A: 20 0F
        push    bc                                             ;#6F9C: C5
        push    de                                             ;#6F9D: D5
        call    BIOS_TAPIN                                     ;#6F9E: CD E4 00
        pop     de                                             ;#6FA1: D1
        ld      (de),a                                         ;#6FA2: 12
        inc     de                                             ;#6FA3: 13
        push    de                                             ;#6FA4: D5
        call    BIOS_TAPIN                                     ;#6FA5: CD E4 00
        pop     de                                             ;#6FA8: D1
        ld      (de),a                                         ;#6FA9: 12
        pop     bc                                             ;#6FAA: C1
TAPE_READ_HEADER_VERIFY:
        ; After 8 bytes: check final mismatch byte (jr to fail or continue)
        ld      a,c                                            ;#6FAB: 79
        or      a                                              ;#6FAC: B7
        jr      nz,TAPE_SKIP_FILE_DRAW                         ;#6FAD: 20 18
        ld      a,(TOP_MENU_MODE)                              ;#6FAF: 3A 29 D1
        cp      1                                              ;#6FB2: FE 01
        jr      z,TAPE_RETRY_CLEAR_AND_OPEN                    ;#6FB4: 28 0C
        ld      a,(GAME_DISPLAY_ACTIVE)                        ;#6FB6: 3A 3D D1
        or      a                                              ;#6FB9: B7
        jr      z,TAPE_RETRY_CLEAR_AND_OPEN                    ;#6FBA: 28 06
        call    RESTORE_GAME_DISPLAY_IF_GAME_ACTIVE            ;#6FBC: CD BD 62
TAPE_RETRY_OPEN_INPUT:
        ; Restore game display if active, then jp TAPE_OPEN_INPUT for the next attempt
        jp      TAPE_OPEN_INPUT                                ;#6FBF: C3 40 6F

TAPE_RETRY_CLEAR_AND_OPEN:
        ; Clear middle name area first, then retry TAPE_OPEN_INPUT
        call    CLEAR_MIDDLE_NAME_AREA                         ;#6FC2: CD 4D 4B
        jr      TAPE_RETRY_OPEN_INPUT                          ;#6FC5: 18 F8

TAPE_SKIP_FILE_DRAW:
        ; Draw "SKIP FILE" prompt and retry tape scan
        ld      de,TXT_SKIP_FILE                               ;#6FC7: 11 D8 6F
        ld      a,40h                                          ;#6FCA: 3E 40
        ld      bc,0Dh                                         ;#6FCC: 01 0D 00
        call    DRAW_TAPE_FILE_LABEL_FROM_SCRATCH              ;#6FCF: CD F1 6F
        call    TAPE_OPEN_INPUT                                ;#6FD2: CD 40 6F
        jp      TAPE_SEARCH_FILE_LOOP                          ;#6FD5: C3 4D 6F

TXT_SKIP_FILE:
        ; "SKIP FILE" prompt — displayed when a non-matching tape file is skipped
        db      "SKIP", 0, "FILE", 0, 0, 0, 0                  ;#6FD8: 53 4B 49 50 00 46 49 4C 45 00 00 00 00

TXT_SEARCH_FILE:
        ; "SEARCH FILE" prompt — displayed while scanning for the matching header
        db      "SEARCH", 0, "FILE"                            ;#6FE5: 53 45 41 52 43 48 00 46 49 4C 45
        TEXT_TERMINATOR                                        ;#6FF0: FF

DRAW_TAPE_FILE_LABEL_FROM_SCRATCH:
        ; Entry with HL=SCRATCH_HEX_OUTPUT; falls into DRAW_TAPE_FILE_LABEL
        ld      hl,SCRATCH_HEX_OUTPUT                          ;#6FF1: 21 00 DA
        jr      DRAW_TAPE_FILE_LABEL_KEEP_A                    ;#6FF4: 18 01

DRAW_TAPE_FILE_LABEL:
        ; Render "FILE NAME" at SUBMENU_BODY_VRAM_BASE + "=HEADER=" (HL=header src)
        xor     a                                              ;#6FF6: AF
DRAW_TAPE_FILE_LABEL_KEEP_A:
        ; Sub-entry skipping the leading xor a (preserves caller's A for ADD_A_TO_HL)
        push    hl                                             ;#6FF7: E5
        ld      hl,(SUBMENU_BODY_VRAM_BASE)                    ;#6FF8: 2A 6E D1
        call    ADD_A_TO_HL                                    ;#6FFB: CD ED 60
        ex      de,hl                                          ;#6FFE: EB
        push    de                                             ;#6FFF: D5
        call    BIOS_LDIRVM                                    ;#7000: CD 5C 00
        pop     hl                                             ;#7003: E1
        ld      bc,40h                                         ;#7004: 01 40 00
        add     hl,bc                                          ;#7007: 09
        pop     de                                             ;#7008: D1
        ld      a,3Dh                                          ;#7009: 3E 3D
        call    BIOS_WRTVRM                                    ;#700B: CD 4D 00
        inc     hl                                             ;#700E: 23
        ex      de,hl                                          ;#700F: EB
        ld      bc,8                                           ;#7010: 01 08 00
        push    bc                                             ;#7013: C5
        push    de                                             ;#7014: D5
        call    BIOS_LDIRVM                                    ;#7015: CD 5C 00
        pop     hl                                             ;#7018: E1
        pop     bc                                             ;#7019: C1
        add     hl,bc                                          ;#701A: 09
        ld      a,3Dh                                          ;#701B: 3E 3D
        jp      BIOS_WRTVRM                                    ;#701D: C3 4D 00

TAPE_CLOSE_INPUT:
        ; TAPIOF (close tape input) + xor a + ret
        call    BIOS_TAPIOF                                    ;#7020: CD E7 00
        xor     a                                              ;#7023: AF
        ret                                                    ;#7024: C9

TAPE_READ_GAME_STATE_RAM:
        ; Read 1100h bytes from tape into E000 RAM via TAPE_READ_DATA_BLOCK
        ld      hl,CHEAT_TARGET_ROAD_FIGHTER_E000              ;#7025: 21 00 E0
        ld      bc,1100h                                       ;#7028: 01 00 11
        jr      TAPE_READ_DATA_BLOCK                           ;#702B: 18 3C

TAPE_READ_VRAM_AS_BLOCKS:
        ; Read 8 compressed blocks back into VRAM (twin of TAPE_WRITE_VRAM_AS_BLOCKS)
        ld      de,0                                           ;#702D: 11 00 00
TAPE_READ_VRAM_BLOCK_LOOP:
        ; Per-block body: push counter, open input, read block size + payload
        push    de                                             ;#7030: D5
        call    BIOS_TAPION                                    ;#7031: CD E1 00
        call    BIOS_TAPIN                                     ;#7034: CD E4 00
        ld      c,a                                            ;#7037: 4F
        push    bc                                             ;#7038: C5
        call    BIOS_TAPIN                                     ;#7039: CD E4 00
        pop     bc                                             ;#703C: C1
        ld      b,a                                            ;#703D: 47
        ld      hl,RLE_COMPRESSED_OUTPUT                       ;#703E: 21 02 C0
        call    TAPE_READ_DATA_BLOCK                           ;#7041: CD 69 70
        pop     de                                             ;#7044: D1
        push    de                                             ;#7045: D5
        ld      hl,RLE_COMPRESSED_OUTPUT                       ;#7046: 21 02 C0
        call    DECOMPRESS_RLE_TO_VRAM                         ;#7049: CD 7A 61
        pop     hl                                             ;#704C: E1
        ld      bc,800h                                        ;#704D: 01 00 08
        add     hl,bc                                          ;#7050: 09
        ld      a,h                                            ;#7051: 7C
        cp      40h                                            ;#7052: FE 40
        jr      nz,TAPE_READ_VRAM_BLOCK_LOOP                   ;#7054: 20 DA
        jp      BIOS_TAPION                                    ;#7056: C3 E1 00

TAPE_READ_RANKING_BUFFER:
        ; Read 78h bytes from tape into RANKING_SCORE_BLOCK via TAPE_READ_DATA_BLOCK
        ld      hl,RANKING_SCORE_BLOCK                         ;#7059: 21 59 D4
        ld      bc,78h                                         ;#705C: 01 78 00
        jr      TAPE_READ_DATA_BLOCK                           ;#705F: 18 08

TAPE_READ_HISCORE_3:
        ; Read 3 bytes from tape into the address held in GAME_RAM_HISCORE_PTR
        ld      hl,(GAME_RAM_HISCORE_PTR)                      ;#7061: 2A 0C D3
        ld      bc,3                                           ;#7064: 01 03 00
        jr      TAPE_READ_DATA_BLOCK                           ;#7067: 18 00

TAPE_READ_DATA_BLOCK:
        ; Read BC bytes from tape into (HL), then read+verify trailing sum byte
        ld      d,0                                            ;#7069: 16 00
TAPE_READ_VRAM_DECOMPRESS_AT_HL:
        ; Save BC/HL, set DE pre-decompression, call DECOMPRESS_RLE
        push    bc                                             ;#706B: C5
        push    hl                                             ;#706C: E5
        push    de                                             ;#706D: D5
        call    BIOS_TAPIN                                     ;#706E: CD E4 00
        pop     de                                             ;#7071: D1
        pop     hl                                             ;#7072: E1
        pop     bc                                             ;#7073: C1
        jp      c,TAPE_FAIL_IO_ERROR                           ;#7074: DA B5 6D
        ld      (hl),a                                         ;#7077: 77
        add     a,d                                            ;#7078: 82
        ld      d,a                                            ;#7079: 57
        inc     hl                                             ;#707A: 23
        dec     bc                                             ;#707B: 0B
        ld      a,b                                            ;#707C: 78
        or      c                                              ;#707D: B1
        jr      nz,TAPE_READ_VRAM_DECOMPRESS_AT_HL             ;#707E: 20 EB
        push    de                                             ;#7080: D5
        call    BIOS_TAPIN                                     ;#7081: CD E4 00
        pop     de                                             ;#7084: D1
        jp      c,TAPE_FAIL_IO_ERROR                           ;#7085: DA B5 6D
        cp      d                                              ;#7088: BA
        jp      c,TAPE_FAIL_SUM_ERROR                          ;#7089: DA B8 6D
        ret                                                    ;#708C: C9

ENTER_PRINTER_MENU:
        ; IN_GAME_MENU_PARAM=70h, SET_DEFAULT_HANDLERS, SAVE_GAME_DISPLAY, run menu
        ld      a,PRINTER_MODE_TOC                             ;#708D: 3E 70
        ld      (IN_GAME_MENU_PARAM),a                         ;#708F: 32 36 D1
        call    SET_DEFAULT_HANDLERS                           ;#7092: CD D5 41
        call    SAVE_GAME_DISPLAY                              ;#7095: CD F3 61
        call    PRINTER_MENU_BODY                              ;#7098: CD 9E 70
        jr      c,ENTER_PRINTER_MENU                           ;#709B: 38 F0
        ret                                                    ;#709D: C9

PRINTER_MENU_BODY:
        ; Save SP, draw header, MENU_SELECT (3 items), dispatch via CALL_INDIRECT_A
        ld      (SP_SAVE_FOR_BDOS),sp                          ;#709E: ED 73 27 D1
        call    DRAW_PRINTER_HEADER                            ;#70A2: CD 92 71
        ld      hl,PRINTER_MENU_POSITIONS                      ;#70A5: 21 D6 71
        ld      b,3                                            ;#70A8: 06 03
        call    MENU_SELECT                                    ;#70AA: CD 00 64
        call    CALL_INDIRECT_A                                ;#70AD: CD E7 61
PRINTER_MENU_HANDLERS:
        ; 3-word handler table consumed inline by CALL_INDIRECT_A at 70ADh
        dw      PRINTER_MENU_ENTRY_70                          ;#70B0: BB 70
        dw      PRINTER_MENU_ENTRY_AUTO                        ;#70B2: BF 70
        dw      PRINTER_MENU_ENTRY_END                         ;#70B4: B6 70

PRINTER_MENU_ENTRY_END:
        ; Inline END handler: RESTORE_GAME_DISPLAY, xor a, ret
        call    RESTORE_GAME_DISPLAY                           ;#70B6: CD 68 62
        xor     a                                              ;#70B9: AF
        ret                                                    ;#70BA: C9

PRINTER_MENU_ENTRY_70:
        ; Top printer option (mode 70h): full dump including the table-of-contents stream
        ld      a,PRINTER_MODE_TOC                             ;#70BB: 3E 70
        jr      PRINTER_DISPATCH                               ;#70BD: 18 0D

PRINTER_MENU_ENTRY_AUTO:
        ; Auto-select mode 71h or 72h based on SNSMAT row 6 bit 1 (STOP key state)
        ld      a,6                                            ;#70BF: 3E 06
        ; SNSMAT row 6 → AND 2 keeps bit 1 (STOP). Without CPL, a set
        ; bit means released — STOP released selects PRINTER_MODE_WIDE,
        ; STOP held selects PRINTER_MODE_NARROW.
        call    BIOS_SNSMAT                                    ;#70C1: CD 41 01
        and     2                                              ;#70C4: E6 02
        ld      a,PRINTER_MODE_WIDE                            ;#70C6: 3E 72
        jr      z,PRINTER_DISPATCH                             ;#70C8: 28 02
        ld      a,PRINTER_MODE_NARROW                          ;#70CA: 3E 71
PRINTER_DISPATCH:
        ; Store mode in IN_GAME_MENU_PARAM, prepare display + buffer, jump to body
        ld      (IN_GAME_MENU_PARAM),a                         ;#70CC: 32 36 D1
        call    RESTORE_GAME_DISPLAY                           ;#70CF: CD 68 62
        call    CLEAR_PRINT_LINE_BUFFER                        ;#70D2: CD E6 70
        call    BUILD_PIXEL_ROW_FROM_NAMETABLE                 ;#70D5: CD 09 73
        call    WAIT_PRINTER_READY                             ;#70D8: CD 08 71
        ld      a,(IN_GAME_MENU_PARAM)                         ;#70DB: 3A 36 D1
        cp      PRINTER_MODE_TOC                               ;#70DE: FE 70
        jp      z,PRINTER_FINISH_PAGE                          ;#70E0: CA 81 72
        jp      PRINTER_PRINT_BOTTOM_GRAPHICS                  ;#70E3: C3 A5 74

CLEAR_PRINT_LINE_BUFFER:
        ; Zero 3C0h bytes at PRINTER_PIXEL_BUFFER — clears the line-print scratch area
        ld      hl,PRINTER_PIXEL_BUFFER                        ;#70E6: 21 B1 D9
        ld      de,PRINTER_PIXEL_BUFFER+1                      ;#70E9: 11 B2 D9
        ld      bc,3BFh                                        ;#70EC: 01 BF 03
        ld      (hl),0                                         ;#70EF: 36 00
        ldir                                                   ;#70F1: ED B0
        ret                                                    ;#70F3: C9

CHECK_USER_ABORT_KEYS:
        ; NZ if SNSMAT row 7 bit 4 (any key) or row 6 bit 1 (STOP) is pressed
        ld      a,7                                            ;#70F4: 3E 07
        ; SNSMAT row 7 → AND 10h keeps bit 4 (STOP-equivalent on row 7
        ; in this cart's matrix). No CPL: bit set = released. CHECK_USER_ABORT_KEYS
        ; returns NZ when the key is released (i.e., do not abort).
        call    BIOS_SNSMAT                                    ;#70F6: CD 41 01
        and     10h                                            ;#70F9: E6 10
        ret     nz                                             ;#70FB: C0
        ld      a,6                                            ;#70FC: 3E 06
        ; SNSMAT row 6 → AND 2 keeps bit 1 (STOP). No CPL: bit set =
        ; released. Second leg of the abort check — both 70F6 and 70FE must
        ; read as released for the abort path to be skipped.
        call    BIOS_SNSMAT                                    ;#70FE: CD 41 01
        and     2                                              ;#7101: E6 02
        ret     nz                                             ;#7103: C0
        ld      c,1                                            ;#7104: 0E 01
        jr      PRINTER_MENU_REDRAW                            ;#7106: 18 16

WAIT_PRINTER_READY:
        ; Poll BIOS_LPTSTT until A=FFh, with a 1×256×256 timeout; otherwise show error
        ld      h,1                                            ;#7108: 26 01
WAIT_PRINTER_READY_LOOP:
        ; Outer 256-iteration loop entry
        ld      c,0                                            ;#710A: 0E 00
WAIT_PRINTER_INNER:
        ; Inner 256-iteration body
        ld      b,0                                            ;#710C: 06 00
WAIT_PRINTER_POLL:
        ; Per-poll: BIOS_LPTSTT; A=FFh → success, else djnz/dec
        call    BIOS_LPTSTT                                    ;#710E: CD A8 00
        jr      z,WAIT_PRINTER_DEC_INNER                       ;#7111: 28 03
        cp      0FFh                                           ;#7113: FE FF
        ret     z                                              ;#7115: C8
WAIT_PRINTER_DEC_INNER:
        ; Inner-loop djnz / dec C continuation
        djnz    WAIT_PRINTER_POLL                              ;#7116: 10 F6
        dec     c                                              ;#7118: 0D
        jr      nz,WAIT_PRINTER_INNER                          ;#7119: 20 F1
        dec     h                                              ;#711B: 25
        jr      nz,WAIT_PRINTER_READY_LOOP                     ;#711C: 20 EC
PRINTER_MENU_REDRAW:
        ; Re-entry after error: SAVE_GAME_DISPLAY, redraw heading + RC code, retry prompt
        push    bc                                             ;#711E: C5
        call    SAVE_GAME_DISPLAY                              ;#711F: CD F3 61
        call    DRAW_SUBMENU_HEADING                           ;#7122: CD 47 45
        call    DRAW_RC_CODE_IF_VALID                          ;#7125: CD DC 71
        pop     bc                                             ;#7128: C1
        ld      a,c                                            ;#7129: 79
        cp      1                                              ;#712A: FE 01
        jr      z,PRINTER_PROMPT_DRAW                          ;#712C: 28 06
        call    DRAW_PRINTER_MODE_PROMPT                       ;#712E: CD E5 71
        jp      PRINTER_KILBUF_WAIT_KEY                        ;#7131: C3 77 71

PRINTER_PROMPT_DRAW:
        ; Render the "PRINTER MODE / NOT READY" prompt + KILBUF before waiting
        call    DRAW_PRINTER_PROMPT_TEXT                       ;#7134: CD 34 72
        call    BIOS_KILBUF                                    ;#7137: CD 56 01
PRINTER_PROMPT_WAIT_KEY:
        ; CHGET loop accepting RETURN (retry, set CY) or SPACE (abort, clear CY)
        call    BIOS_CHGET                                     ;#713A: CD 9F 00
        cp      CHAR_RETURN                                    ;#713D: FE 0D
        jr      z,PRINTER_PROMPT_RETRY_OK                      ;#713F: 28 06
        cp      CHAR_SPACE                                     ;#7141: FE 20
        jr      z,PRINTER_PROMPT_RETRY_WAIT                    ;#7143: 28 06
        jr      PRINTER_PROMPT_WAIT_KEY                        ;#7145: 18 F3

PRINTER_PROMPT_RETRY_OK:
        ; RETURN: RESTORE_GAME_DISPLAY, ret (caller retries)
        call    RESTORE_GAME_DISPLAY                           ;#7147: CD 68 62
        ret                                                    ;#714A: C9

PRINTER_PROMPT_RETRY_WAIT:
        ; RETURN with not-ready: restore display + spin on BIOS_LPTSTT
        call    RESTORE_GAME_DISPLAY                           ;#714B: CD 68 62
PRINTER_PROMPT_LPTSTT_LOOP:
        ; Inner spin: poll BIOS_LPTSTT (Z = ready) and loop while not ready
        call    BIOS_LPTSTT                                    ;#714E: CD A8 00
        jr      z,PRINTER_PROMPT_LPTSTT_LOOP                   ;#7151: 28 FB
        cp      0FFh                                           ;#7153: FE FF
        jr      nz,PRINTER_PROMPT_LPTSTT_LOOP                  ;#7155: 20 F7
        ld      hl,200h                                        ;#7157: 21 00 02
PRINTER_FORM_FEED:
        ; Emit 200h chars of A=00h (form feed) via BIOS_LPTOUT
        xor     a                                              ;#715A: AF
        call    BIOS_LPTOUT                                    ;#715B: CD A5 00
        dec     hl                                             ;#715E: 2B
        ld      a,h                                            ;#715F: 7C
        or      l                                              ;#7160: B5
        jr      nz,PRINTER_FORM_FEED                           ;#7161: 20 F7
        ld      b,8                                            ;#7163: 06 08
PRINTER_FORM_FEED_NEWLINES:
        ; Output 8 CR newlines (B=8, A=0Dh) after form feed
        ld      a,CHAR_RETURN                                  ;#7165: 3E 0D
        call    BIOS_LPTOUT                                    ;#7167: CD A5 00
        ld      a,CHAR_LF                                      ;#716A: 3E 0A
        call    BIOS_LPTOUT                                    ;#716C: CD A5 00
        djnz    PRINTER_FORM_FEED_NEWLINES                     ;#716F: 10 F4
PRINTER_ABORT_AND_RET:
        ; Restore SP from SP_SAVE_FOR_BDOS, scf, ret (abort exit after LPTOUT failure)
        ld      sp,(SP_SAVE_FOR_BDOS)                          ;#7171: ED 7B 27 D1
        scf                                                    ;#7175: 37
        ret                                                    ;#7176: C9

PRINTER_KILBUF_WAIT_KEY:
        ; KILBUF then fall into PRINTER_WAIT_KEY (clean queue first)
        call    BIOS_KILBUF                                    ;#7177: CD 56 01
PRINTER_WAIT_KEY:
        ; CHGET RETURN/SPACE loop (used by printer-not-ready and finished prompts)
        call    BIOS_CHGET                                     ;#717A: CD 9F 00
        cp      0Dh                                            ;#717D: FE 0D
        jr      z,PRINTER_PROMPT_RETRY_READY                   ;#717F: 28 0B
        cp      CHAR_SPACE                                     ;#7181: FE 20
        jr      z,PRINTER_PROMPT_ABORT_PATH                    ;#7183: 28 02
        jr      PRINTER_WAIT_KEY                               ;#7185: 18 F3

PRINTER_PROMPT_ABORT_PATH:
        ; Abort merge: RESTORE_GAME_DISPLAY then PRINTER_ABORT_AND_RET
        call    RESTORE_GAME_DISPLAY                           ;#7187: CD 68 62
        jr      PRINTER_ABORT_AND_RET                          ;#718A: 18 E5

PRINTER_PROMPT_RETRY_READY:
        ; Restore display then jp WAIT_PRINTER_READY (re-arm after retry)
        call    RESTORE_GAME_DISPLAY                           ;#718C: CD 68 62
        jp      WAIT_PRINTER_READY                             ;#718F: C3 08 71

DRAW_PRINTER_HEADER:
        ; Heading + RC code + the "SELECT PRINTER" prompt
        call    DRAW_SUBMENU_HEADING                           ;#7192: CD 47 45
        call    DRAW_RC_CODE_IF_VALID                          ;#7195: CD DC 71
        ld      hl,TXT_PRINTER_SELECT_HEADER                   ;#7198: 21 9E 71
        jp      DRAW_TEXT_STREAM                               ;#719B: C3 13 61

TXT_PRINTER_SELECT_HEADER:
        ; VRAM target 4040h + "@@SELECT@@ / @@PRINTER@@ / =SP= ... =RE..." prompt
        NAME_TABLE 17, 12                                      ;#719E: 2C 3A
        db      "@@SELECT", 0, "PRINTER@@"                     ;#71A0: 40 40 53 45 4C 45 43 54 00 50 52 49 4E 54 45 52 40 40
        TEXT_SEPARATOR                                         ;#71B2: FE
        NAME_TABLE 19, 12                                      ;#71B3: 6C 3A
        db      "EPSON=PI@40="                                 ;#71B5: 45 50 53 4F 4E 3D 50 49 40 34 30 3D
        TEXT_SEPARATOR                                         ;#71C1: FE
        NAME_TABLE 20, 12                                      ;#71C2: 8C 3A
        db      "MSX", 0, "PRINTER"                            ;#71C4: 4D 53 58 00 50 52 49 4E 54 45 52
        TEXT_SEPARATOR                                         ;#71CF: FE
        NAME_TABLE 22, 12                                      ;#71D0: CC 3A
        db      "END"                                          ;#71D2: 45 4E 44
        TEXT_TERMINATOR                                        ;#71D5: FF

PRINTER_MENU_POSITIONS:
        ; 3 LE word VRAM-row addresses (3A6B, 3A8B, 3ACB) for the printer menu cursor
        NAME_TABLE 19, 11                                      ;#71D6: 6B 3A
        NAME_TABLE 20, 11                                      ;#71D8: 8B 3A
        NAME_TABLE 22, 11                                      ;#71DA: CB 3A

DRAW_RC_CODE_IF_VALID:
        ; Same as DRAW_RC_CATALOG_CODE but returns silently when GAME_ID=FFh (no game)
        ld      a,(GAME_ID)                                    ;#71DC: 3A 01 D3
        cp      0FFh                                           ;#71DF: FE FF
        ret     z                                              ;#71E1: C8
        jp      DRAW_RC_CATALOG_CODE                           ;#71E2: C3 2A 44

DRAW_PRINTER_MODE_PROMPT:
        ; Draws the "PRINTER MODE / =NOT READY= / SPACE/RETURN" prompt stream
        ld      hl,TXT_PRINTER_MODE_BODY                       ;#71E5: 21 EB 71
        jp      DRAW_TEXT_STREAM                               ;#71E8: C3 13 61

TXT_PRINTER_MODE_BODY:
        ; "PRINTER MODE / =MODE= / =NOT READY= / SPACE / RETURN" text stream
        NAME_TABLE 17, 12                                      ;#71EB: 2C 3A
        db      "@@PRINTER", 0, "MODE@@"                       ;#71ED: 40 40 50 52 49 4E 54 45 52 00 4D 4F 44 45 40 40
        TEXT_SEPARATOR                                         ;#71FD: FE
        NAME_TABLE 19, 12                                      ;#71FE: 6C 3A
        db      "=NOT", 0, "READY="                            ;#7200: 3D 4E 4F 54 00 52 45 41 44 59 3D
        TEXT_SEPARATOR                                         ;#720B: FE
        NAME_TABLE 21, 12                                      ;#720C: AC 3A
        db      "RETURN", 0, "KEY@@RETRY"                      ;#720E: 52 45 54 55 52 4E 00 4B 45 59 40 40 52 45 54 52 59
        TEXT_SEPARATOR                                         ;#721F: FE
        NAME_TABLE 22, 12                                      ;#7220: CC 3A
        db      "SPACE", 0, "KEY", 0, "@@ABORT"                ;#7222: 53 50 41 43 45 00 4B 45 59 00 40 40 41 42 4F 52 54
        TEXT_TERMINATOR                                        ;#7233: FF

DRAW_PRINTER_PROMPT_TEXT:
        ; ld hl,TXT_PRINTER_OPTIONS_BODY; jp DRAW_TEXT_STREAM (printer-mode prompt)
        ld      hl,TXT_PRINTER_OPTIONS_BODY                    ;#7234: 21 3A 72
        jp      DRAW_TEXT_STREAM                               ;#7237: C3 13 61

TXT_PRINTER_OPTIONS_BODY:
TXT_PRINTER_PROMPT_TEXT:
        ; Encoded "PRINTER MODE / =AUSING= / RETURN KEY / SPACE KEY" prompt
        NAME_TABLE 17, 12                                      ;#723A: 2C 3A
        db      "@@PRINTER", 0, "MODE@@"                       ;#723C: 40 40 50 52 49 4E 54 45 52 00 4D 4F 44 45 40 40
        TEXT_SEPARATOR                                         ;#724C: FE
        NAME_TABLE 19, 12                                      ;#724D: 6C 3A
        db      "=PAUSING="                                    ;#724F: 3D 50 41 55 53 49 4E 47 3D
        TEXT_SEPARATOR                                         ;#7258: FE
        NAME_TABLE 21, 12                                      ;#7259: AC 3A
        db      "RETURN", 0, "KEY@@START"                      ;#725B: 52 45 54 55 52 4E 00 4B 45 59 40 40 53 54 41 52 54
        TEXT_SEPARATOR                                         ;#726C: FE
        NAME_TABLE 22, 12                                      ;#726D: CC 3A
        db      "SPACE", 0, "KEY", 0, "@@ABORT"                ;#726F: 53 50 41 43 45 00 4B 45 59 00 40 40 41 42 4F 52 54
        TEXT_TERMINATOR                                        ;#7280: FF

PRINTER_FINISH_PAGE:
        ; Page footer: 4 spaces + PRINT_FULL_PAGE_PIXELS body + 8 newlines; A=0
        call    PRINTER_PUT_4_SPACES                           ;#7281: CD AA 72
        call    PRINT_FULL_PAGE_PIXELS                         ;#7284: CD B4 72
        call    PRINTER_PUT_8_NEWLINES                         ;#7287: CD F7 72
        xor     a                                              ;#728A: AF
        ret                                                    ;#728B: C9

PRINTER_PUT_CHAR:
        ; Send A to printer: poll BIOS_LPTSTT until ready, then BIOS_LPTOUT
        push    ix                                             ;#728C: DD E5
        push    hl                                             ;#728E: E5
        push    de                                             ;#728F: D5
        push    bc                                             ;#7290: C5
        push    af                                             ;#7291: F5
        push    af                                             ;#7292: F5
PRINTER_PUT_CHAR_POLL:
        ; Inner poll body: CHECK_USER_ABORT_KEYS + BIOS_LPTSTT until ready
        call    CHECK_USER_ABORT_KEYS                          ;#7293: CD F4 70
        call    BIOS_LPTSTT                                    ;#7296: CD A8 00
        jr      z,PRINTER_PUT_CHAR_POLL                        ;#7299: 28 F8
        cp      0FFh                                           ;#729B: FE FF
        jr      nz,PRINTER_PUT_CHAR_POLL                       ;#729D: 20 F4
        pop     af                                             ;#729F: F1
        call    BIOS_LPTOUT                                    ;#72A0: CD A5 00
        pop     af                                             ;#72A3: F1
        pop     bc                                             ;#72A4: C1
        pop     de                                             ;#72A5: D1
        pop     hl                                             ;#72A6: E1
        pop     ix                                             ;#72A7: DD E1
        ret                                                    ;#72A9: C9

PRINTER_PUT_4_SPACES:
        ; Output four 20h space characters
        ld      b,4                                            ;#72AA: 06 04
PRINTER_PUT_4_SPACES_LOOP:
        ; Per-space body
        ld      a,20h                                          ;#72AC: 3E 20
        call    PRINTER_PUT_CHAR                               ;#72AE: CD 8C 72
        djnz    PRINTER_PUT_4_SPACES_LOOP                      ;#72B1: 10 F9
        ret                                                    ;#72B3: C9

PRINT_FULL_PAGE_PIXELS:
        ; Emit 100h-row x C0h-col pixel page: PRINTER_RENDER_BOTTOM_ROW + CHAR per cell
        ld      b,0                                            ;#72B4: 06 00
        ld      h,0                                            ;#72B6: 26 00
PRINT_FULL_PAGE_OUTER:
        ; Outer 256-row body of PRINT_FULL_PAGE_PIXELS
        push    bc                                             ;#72B8: C5
        push    hl                                             ;#72B9: E5
        call    PRINTER_INIT_PRINT_MODE                        ;#72BA: CD E1 72
        ld      b,0C0h                                         ;#72BD: 06 C0
PRINT_FULL_PAGE_INNER:
        ; Inner C0-column body of PRINT_FULL_PAGE_PIXELS
        push    bc                                             ;#72BF: C5
        ld      l,b                                            ;#72C0: 68
        dec     l                                              ;#72C1: 2D
        ld      (PRINTER_CURSOR_PIXEL_XY),hl                   ;#72C2: 22 71 DD
        call    PRINTER_RENDER_BOTTOM_ROW                      ;#72C5: CD 99 73
        call    PRINTER_PUT_CHAR                               ;#72C8: CD 8C 72
        ld      hl,(PRINTER_CURSOR_PIXEL_XY)                   ;#72CB: 2A 71 DD
        pop     bc                                             ;#72CE: C1
        djnz    PRINT_FULL_PAGE_INNER                          ;#72CF: 10 EE
        pop     hl                                             ;#72D1: E1
        inc     h                                              ;#72D2: 24
        pop     bc                                             ;#72D3: C1
        djnz    PRINT_FULL_PAGE_OUTER                          ;#72D4: 10 E2
        ld      a,0Dh                                          ;#72D6: 3E 0D
        call    PRINTER_PUT_CHAR                               ;#72D8: CD 8C 72
        ld      a,0Ah                                          ;#72DB: 3E 0A
        call    PRINTER_PUT_CHAR                               ;#72DD: CD 8C 72
        ret                                                    ;#72E0: C9

PRINTER_INIT_PRINT_MODE:
        ; Send the 5-byte ESC I 1 9 2 sequence to set Konami's print mode
        push    hl                                             ;#72E1: E5
        push    bc                                             ;#72E2: C5
        ld      hl,PRINTER_INIT_SEQUENCE                       ;#72E3: 21 F2 72
        ld      b,5                                            ;#72E6: 06 05
PRINTER_INIT_SEQ_LOOP:
        ; Per-byte body: emit (HL), inc HL, djnz back
        ld      a,(hl)                                         ;#72E8: 7E
        inc     hl                                             ;#72E9: 23
        call    PRINTER_PUT_CHAR                               ;#72EA: CD 8C 72
        djnz    PRINTER_INIT_SEQ_LOOP                          ;#72ED: 10 F9
        pop     bc                                             ;#72EF: C1
        pop     hl                                             ;#72F0: E1
        ret                                                    ;#72F1: C9

PRINTER_INIT_SEQUENCE:
        ; 5-byte init data "1Bh 49h 31h 39h 32h" = "ESC I 1 9 2"
        PRINTER_ESC                                            ;#72F2: 1B
        db      "I192"                                         ;#72F3: 49 31 39 32

PRINTER_PUT_8_NEWLINES:
        ; Output 8 CRLFs via PRINTER_PUT_CRLF
        ld      b,8                                            ;#72F7: 06 08
PRINTER_PUT_8_NEWLINES_LOOP:
        ; Per-CRLF body: PRINTER_PUT_CRLF and djnz
        call    PRINTER_PUT_CRLF                               ;#72F9: CD FF 72
        djnz    PRINTER_PUT_8_NEWLINES_LOOP                    ;#72FC: 10 FB
        ret                                                    ;#72FE: C9

PRINTER_PUT_CRLF:
        ; Output 0Dh then 0Ah via PRINTER_PUT_CHAR
        ld      a,0Dh                                          ;#72FF: 3E 0D
        call    PRINTER_PUT_CHAR                               ;#7301: CD 8C 72
        ld      a,0Ah                                          ;#7304: 3E 0A
        jp      PRINTER_PUT_CHAR                               ;#7306: C3 8C 72

BUILD_PIXEL_ROW_FROM_NAMETABLE:
        ; Scan 20h cells of bottom name-table row, write column index into D9B1+row*5
        ld      b,20h                                          ;#7309: 06 20
        ld      c,0                                            ;#730B: 0E 00
BUILD_PIXEL_ROW_COL_LOOP:
        ; Per-column body: probe tile and decide if it's a separator
        push    bc                                             ;#730D: C5
        ld      a,c                                            ;#730E: 79
        call    PRINTER_PROBE_TILE                             ;#730F: CD 67 73
        cp      0D2h                                           ;#7312: FE D2
        jr      z,BUILD_PIXEL_ROW_NEXT_COL                     ;#7314: 28 1E
        cp      0D1h                                           ;#7316: FE D1
        jr      z,BUILD_PIXEL_ROW_DONE                         ;#7318: 28 1F
        call    GET_RANKING_PIXEL_ROW                          ;#731A: CD 3B 73
        ld      b,10h                                          ;#731D: 06 10
BUILD_PIXEL_ROW_ROW_LOOP:
        ; Per-row body: 10h pixel-row entries per column
        ld      a,(hl)                                         ;#731F: 7E
        cp      4                                              ;#7320: FE 04
        jr      nc,BUILD_PIXEL_ROW_ADVANCE                     ;#7322: 30 09
        inc     a                                              ;#7324: 3C
        ld      (hl),a                                         ;#7325: 77
        ld      e,a                                            ;#7326: 5F
        ld      d,0                                            ;#7327: 16 00
        push    hl                                             ;#7329: E5
        add     hl,de                                          ;#732A: 19
        ld      (hl),c                                         ;#732B: 71
        pop     hl                                             ;#732C: E1
BUILD_PIXEL_ROW_ADVANCE:
        ; Pop HL, add 5 to advance to next row slot
        ld      a,5                                            ;#732D: 3E 05
        call    ADD_A_TO_HL                                    ;#732F: CD ED 60
        djnz    BUILD_PIXEL_ROW_ROW_LOOP                       ;#7332: 10 EB
BUILD_PIXEL_ROW_NEXT_COL:
        ; Restore counters, inc column index, djnz outer
        pop     bc                                             ;#7334: C1
        inc     c                                              ;#7335: 0C
        djnz    BUILD_PIXEL_ROW_COL_LOOP                       ;#7336: 10 D5
        ret                                                    ;#7338: C9

BUILD_PIXEL_ROW_DONE:
        ; Cleanup: pop bc and ret
        pop     bc                                             ;#7339: C1
        ret                                                    ;#733A: C9

GET_RANKING_PIXEL_ROW:
        ; HL = PRINTER_PIXEL_BUFFER + A*5 — address of ranking row A's pixel-output slot
        push    de                                             ;#733B: D5
        push    bc                                             ;#733C: C5
        ld      l,a                                            ;#733D: 6F
        ld      h,0                                            ;#733E: 26 00
        ld      b,h                                            ;#7340: 44
        ld      c,l                                            ;#7341: 4D
        add     hl,hl                                          ;#7342: 29
        add     hl,hl                                          ;#7343: 29
        add     hl,bc                                          ;#7344: 09
        ld      de,PRINTER_PIXEL_BUFFER                        ;#7345: 11 B1 D9
        add     hl,de                                          ;#7348: 19
        pop     bc                                             ;#7349: C1
        pop     de                                             ;#734A: D1
        ret                                                    ;#734B: C9

GET_VRAM_BOTTOM_ROW_ADDR:
        ; HL = 3B00h + A*4 — name-table address of bottom-row tile A
        push    de                                             ;#734C: D5
        ld      l,a                                            ;#734D: 6F
        ld      h,0                                            ;#734E: 26 00
        add     hl,hl                                          ;#7350: 29
        add     hl,hl                                          ;#7351: 29
        LOAD_NAME_TABLE de, 24, 0                              ;#7352: 11 00 3B
        add     hl,de                                          ;#7355: 19
        pop     de                                             ;#7356: D1
        ret                                                    ;#7357: C9

GET_VRAM_PATTERN_ADDR:
        ; HL = 1800h + (A & FCh)*8 — pattern bank address of tile A
        push    de                                             ;#7358: D5
        and     0FCh                                           ;#7359: E6 FC
        ld      l,a                                            ;#735B: 6F
        ld      h,0                                            ;#735C: 26 00
        add     hl,hl                                          ;#735E: 29
        add     hl,hl                                          ;#735F: 29
        add     hl,hl                                          ;#7360: 29
        LOAD_VRAM_ADDRESS de, 1800h                            ;#7361: 11 00 18
        add     hl,de                                          ;#7364: 19
        pop     de                                             ;#7365: D1
        ret                                                    ;#7366: C9

PRINTER_PROBE_TILE:
        ; Read VRAM tile A's first byte (734C+RDVRM); inc A
        push    hl                                             ;#7367: E5
        call    GET_VRAM_BOTTOM_ROW_ADDR                       ;#7368: CD 4C 73
        call    BIOS_RDVRM                                     ;#736B: CD 4A 00
        inc     a                                              ;#736E: 3C
        pop     hl                                             ;#736F: E1
        ret                                                    ;#7370: C9

PRINTER_PROBE_TILE_HIGH:
        ; Read VRAM tile A's second byte; preserve BC/HL
        push    hl                                             ;#7371: E5
        push    bc                                             ;#7372: C5
        call    GET_VRAM_BOTTOM_ROW_ADDR                       ;#7373: CD 4C 73
        inc     hl                                             ;#7376: 23
        call    BIOS_RDVRM                                     ;#7377: CD 4A 00
        pop     bc                                             ;#737A: C1
        pop     hl                                             ;#737B: E1
        ret                                                    ;#737C: C9

PRINTER_READ_4_TILE_BYTES:
        ; Read 4 consecutive bottom-row tile bytes into A/BC/DE
        push    hl                                             ;#737D: E5
        push    af                                             ;#737E: F5
        call    GET_VRAM_BOTTOM_ROW_ADDR                       ;#737F: CD 4C 73
        call    BIOS_RDVRM                                     ;#7382: CD 4A 00
        inc     a                                              ;#7385: 3C
        ld      c,a                                            ;#7386: 4F
        inc     hl                                             ;#7387: 23
        call    BIOS_RDVRM                                     ;#7388: CD 4A 00
        ld      b,a                                            ;#738B: 47
        inc     hl                                             ;#738C: 23
        call    BIOS_RDVRM                                     ;#738D: CD 4A 00
        ld      e,a                                            ;#7390: 5F
        inc     hl                                             ;#7391: 23
        call    BIOS_RDVRM                                     ;#7392: CD 4A 00
        ld      d,a                                            ;#7395: 57
        pop     af                                             ;#7396: F1
        pop     hl                                             ;#7397: E1
        ret                                                    ;#7398: C9

PRINTER_RENDER_BOTTOM_ROW:
        ; Per-column render: probe tile, lookup pattern, output to printer
        call    PRINTER_READ_PIXEL_ROW_X                       ;#7399: CD A7 73
        or      a                                              ;#739C: B7
        ret     nz                                             ;#739D: C0
        call    PRINTER_READ_VRAM_AT_PIXEL                     ;#739E: CD 35 74
        or      a                                              ;#73A1: B7
        ret     nz                                             ;#73A2: C0
        call    CHECK_R7SAV_BACKDROP_EQ_4                      ;#73A3: CD 2A 74
        ret                                                    ;#73A6: C9

PRINTER_READ_PIXEL_ROW_X:
        ; Get pixel-row buffer byte at (D9B1+(DD71.l)*5); return A=byte, NZ when set
        ld      hl,(PRINTER_CURSOR_PIXEL_XY)                   ;#73A7: 2A 71 DD
        ld      a,l                                            ;#73AA: 7D
        call    GET_RANKING_PIXEL_ROW                          ;#73AB: CD 3B 73
        ld      a,(hl)                                         ;#73AE: 7E
        or      a                                              ;#73AF: B7
        ret     z                                              ;#73B0: C8
        ld      b,a                                            ;#73B1: 47
        inc     hl                                             ;#73B2: 23
        ld      a,10h                                          ;#73B3: 3E 10
        dec     a                                              ;#73B5: 3D
PRINTER_PIXEL_ROW_BODY:
        ; Inner 10h-iteration body of PRINTER_READ_PIXEL_ROW_X (per-slot loop)
        push    bc                                             ;#73B6: C5
        push    af                                             ;#73B7: F5
        ld      b,a                                            ;#73B8: 47
        ld      a,(hl)                                         ;#73B9: 7E
        call    PRINTER_PROBE_TILE_HIGH                        ;#73BA: CD 71 73
        ld      c,a                                            ;#73BD: 4F
        add     a,b                                            ;#73BE: 80
        ld      b,a                                            ;#73BF: 47
        ld      de,(PRINTER_CURSOR_PIXEL_XY)                   ;#73C0: ED 5B 71 DD
        jr      c,PRINTER_RENDER_COMPARE_HI                    ;#73C4: 38 16
        ld      a,d                                            ;#73C6: 7A
        cp      c                                              ;#73C7: B9
        jr      c,PRINTER_PIXEL_NEXT_ENTRY                     ;#73C8: 38 0B
        ld      a,b                                            ;#73CA: 78
        cp      d                                              ;#73CB: BA
        jr      c,PRINTER_PIXEL_NEXT_ENTRY                     ;#73CC: 38 07
PRINTER_RENDER_PROBE_TILE:
        ; Read VRAM tile byte and call PRINTER_PROBE_PIXEL_PATTERN
        ld      a,(hl)                                         ;#73CE: 7E
        call    PRINTER_PROBE_PIXEL_PATTERN                    ;#73CF: CD E9 73
        or      a                                              ;#73D2: B7
        jr      nz,PRINTER_RENDER_DONE_RET                     ;#73D3: 20 11
PRINTER_PIXEL_NEXT_ENTRY:
        ; Pop af/bc, inc HL, djnz back to body — iterate to next pixel-buffer entry
        pop     af                                             ;#73D5: F1
        pop     bc                                             ;#73D6: C1
        inc     hl                                             ;#73D7: 23
        djnz    PRINTER_PIXEL_ROW_BODY                         ;#73D8: 10 DC
        xor     a                                              ;#73DA: AF
        ret                                                    ;#73DB: C9

PRINTER_RENDER_COMPARE_HI:
        ; After CY: compare D and C, route to continue or back-step path
        ld      a,d                                            ;#73DC: 7A
        cp      c                                              ;#73DD: B9
        jr      nc,PRINTER_RENDER_PROBE_TILE                   ;#73DE: 30 EE
        ld      a,b                                            ;#73E0: 78
        cp      d                                              ;#73E1: BA
        jr      nc,PRINTER_RENDER_PROBE_TILE                   ;#73E2: 30 EA
        jr      PRINTER_PIXEL_NEXT_ENTRY                       ;#73E4: 18 EF

PRINTER_RENDER_DONE_RET:
        ; Cleanup tail: pop pushed HL × 2 and return
        pop     hl                                             ;#73E6: E1
        pop     hl                                             ;#73E7: E1
        ret                                                    ;#73E8: C9

PRINTER_PROBE_PIXEL_PATTERN:
        ; Read 4 tile bytes + GET_VRAM_PATTERN_ADDR + RDVRM; test target pixel
        push    hl                                             ;#73E9: E5
        push    de                                             ;#73EA: D5
        push    bc                                             ;#73EB: C5
        call    PRINTER_READ_4_TILE_BYTES                      ;#73EC: CD 7D 73
        push    de                                             ;#73EF: D5
        push    de                                             ;#73F0: D5
        call    PRINTER_PIXEL_OFFSET_FROM_CURSOR               ;#73F1: CD 14 74
        pop     de                                             ;#73F4: D1
        ld      a,e                                            ;#73F5: 7B
        push    hl                                             ;#73F6: E5
        call    GET_VRAM_PATTERN_ADDR                          ;#73F7: CD 58 73
        pop     de                                             ;#73FA: D1
        push    de                                             ;#73FB: D5
        ld      d,0                                            ;#73FC: 16 00
        add     hl,de                                          ;#73FE: 19
        call    BIOS_RDVRM                                     ;#73FF: CD 4A 00
        pop     bc                                             ;#7402: C1
        inc     b                                              ;#7403: 04
PRINTER_PROBE_PIXEL_SHIFT:
        ; Inner shift loop: shift pattern byte left B times (extract MSB)
        add     a,a                                            ;#7404: 87
        djnz    PRINTER_PROBE_PIXEL_SHIFT                      ;#7405: 10 FD
        jr      c,PRINTER_PROBE_PIXEL_HIT                      ;#7407: 38 06
        pop     af                                             ;#7409: F1
        xor     a                                              ;#740A: AF
PRINTER_PIXEL_PROBE_DONE:
        ; Common cleanup: pop bc/de/hl, ret (with A from caller for hit/miss result)
        pop     bc                                             ;#740B: C1
        pop     de                                             ;#740C: D1
        pop     hl                                             ;#740D: E1
        ret                                                    ;#740E: C9

PRINTER_PROBE_PIXEL_HIT:
        ; Pixel set: A = original byte & 0Fh; jr PRINTER_PIXEL_PROBE_DONE tail
        pop     af                                             ;#740F: F1
        and     0Fh                                            ;#7410: E6 0F
        jr      PRINTER_PIXEL_PROBE_DONE                       ;#7412: 18 F7

PRINTER_PIXEL_OFFSET_FROM_CURSOR:
        ; PRINTER_CURSOR_PIXEL_XY - (B,C) pixel delta; cross-tile fixup
        ld      hl,(PRINTER_CURSOR_PIXEL_XY)                   ;#7414: 2A 71 DD
        ld      a,h                                            ;#7417: 7C
        sub     b                                              ;#7418: 90
        ld      h,a                                            ;#7419: 67
        ld      a,l                                            ;#741A: 7D
        sub     c                                              ;#741B: 91
        ld      l,a                                            ;#741C: 6F
        ld      a,h                                            ;#741D: 7C
        cp      8                                              ;#741E: FE 08
        ret     c                                              ;#7420: D8
        ld      a,h                                            ;#7421: 7C
        sub     8                                              ;#7422: D6 08
        ld      h,a                                            ;#7424: 67
        ld      a,l                                            ;#7425: 7D
        add     a,10h                                          ;#7426: C6 10
        ld      l,a                                            ;#7428: 6F
        ret                                                    ;#7429: C9

CHECK_R7SAV_BACKDROP_EQ_4:
        ; (BIOS_RG7SAV)&0Fh: ret Z if backdrop=4 else A=1 (per-cell content gate)
        ld      a,(BIOS_RG7SAV)                                ;#742A: 3A E6 F3
        and     0Fh                                            ;#742D: E6 0F
        cp      4                                              ;#742F: FE 04
        ret     z                                              ;#7431: C8
        ld      a,1                                            ;#7432: 3E 01
        ret                                                    ;#7434: C9

PRINTER_READ_VRAM_AT_PIXEL:
        ; Read 1 VRAM byte at the name-table cell containing pixel PRINTER_CURSOR_PIXEL_XY
        ld      hl,(PRINTER_CURSOR_PIXEL_XY)                   ;#7435: 2A 71 DD
        call    PIXEL_HL_TO_NAMETABLE_VRAM                     ;#7438: CD 91 74
        call    BIOS_RDVRM                                     ;#743B: CD 4A 00
        ld      h,0                                            ;#743E: 26 00
        ld      l,a                                            ;#7440: 6F
        add     hl,hl                                          ;#7441: 29
        add     hl,hl                                          ;#7442: 29
        add     hl,hl                                          ;#7443: 29
        ld      de,(PRINTER_CURSOR_PIXEL_XY)                   ;#7444: ED 5B 71 DD
        ld      a,e                                            ;#7448: 7B
        and     7                                              ;#7449: E6 07
        ld      e,a                                            ;#744B: 5F
        ld      d,0                                            ;#744C: 16 00
        add     hl,de                                          ;#744E: 19
        ld      de,(PRINTER_CURSOR_PIXEL_XY)                   ;#744F: ED 5B 71 DD
        ld      a,e                                            ;#7453: 7B
        ld      de,0                                           ;#7454: 11 00 00
        cp      40h                                            ;#7457: FE 40
        jr      c,PRINTER_READ_VRAM_LOAD_XY                    ;#7459: 38 09
        ld      d,8                                            ;#745B: 16 08
        cp      80h                                            ;#745D: FE 80
        jr      c,PRINTER_READ_VRAM_HI_ROW                     ;#745F: 38 02
        ld      d,10h                                          ;#7461: 16 10
PRINTER_READ_VRAM_HI_ROW:
        ; Y >= 8 path: add 10h row stride before RDVRM
        add     hl,de                                          ;#7463: 19
PRINTER_READ_VRAM_LOAD_XY:
        ; Load PRINTER_CURSOR_PIXEL_XY into DE for read
        ld      de,(PRINTER_CURSOR_PIXEL_XY)                   ;#7464: ED 5B 71 DD
        ld      a,d                                            ;#7468: 7A
        push    hl                                             ;#7469: E5
        LOAD_VRAM_ADDRESS de, 2000h                            ;#746A: 11 00 20
        add     hl,de                                          ;#746D: 19
        and     7                                              ;#746E: E6 07
        inc     a                                              ;#7470: 3C
        ld      b,a                                            ;#7471: 47
        call    BIOS_RDVRM                                     ;#7472: CD 4A 00
PRINTER_READ_VRAM_SHIFT:
        ; Shift VRAM byte to extract target pixel bit
        add     a,a                                            ;#7475: 87
        djnz    PRINTER_READ_VRAM_SHIFT                        ;#7476: 10 FD
        pop     hl                                             ;#7478: E1
        push    af                                             ;#7479: F5
        ld      de,0                                           ;#747A: 11 00 00
        add     hl,de                                          ;#747D: 19
        call    BIOS_RDVRM                                     ;#747E: CD 4A 00
        ld      b,a                                            ;#7481: 47
        pop     af                                             ;#7482: F1
        jr      c,PRINTER_READ_VRAM_HI_NIB                     ;#7483: 38 04
        ld      a,b                                            ;#7485: 78
        and     0Fh                                            ;#7486: E6 0F
        ret                                                    ;#7488: C9

PRINTER_READ_VRAM_HI_NIB:
        ; High-nibble path: A & F0h, rotate, return
        ld      a,b                                            ;#7489: 78
        and     0F0h                                           ;#748A: E6 F0
        rrca                                                   ;#748C: 0F
        rrca                                                   ;#748D: 0F
        rrca                                                   ;#748E: 0F
        rrca                                                   ;#748F: 0F
        ret                                                    ;#7490: C9

PIXEL_HL_TO_NAMETABLE_VRAM:
        ; Convert pixel coords (HL) to name-table cell address (3800h | (y/8)*32 + x/8)
        ld      a,l                                            ;#7491: 7D
        rra                                                    ;#7492: 1F
        rra                                                    ;#7493: 1F
        rra                                                    ;#7494: 1F
        rra                                                    ;#7495: 1F
        rr      h                                              ;#7496: CB 1C
        rra                                                    ;#7498: 1F
        rr      h                                              ;#7499: CB 1C
        rra                                                    ;#749B: 1F
        rr      h                                              ;#749C: CB 1C
        ld      l,h                                            ;#749E: 6C
        and     3                                              ;#749F: E6 03
        add     a,38h                                          ;#74A1: C6 38
        ld      h,a                                            ;#74A3: 67
        ret                                                    ;#74A4: C9

PRINTER_PRINT_BOTTOM_GRAPHICS:
        ; Main "print the bottom-row graphics" entry: T16 + conditional S384/S768
        call    PRINTER_SEND_T16                               ;#74A5: CD 2E 75
        ld      b,40h                                          ;#74A8: 06 40
        ld      h,0                                            ;#74AA: 26 00
PRINT_BOTTOM_OUTER:
        ; Outer 40h-row body of PRINTER_PRINT_BOTTOM_GRAPHICS
        push    bc                                             ;#74AC: C5
        ld      de,PRINTER_SEQ_S384                            ;#74AD: 11 44 75
        ld      a,(IN_GAME_MENU_PARAM)                         ;#74B0: 3A 36 D1
        cp      PRINTER_MODE_NARROW                            ;#74B3: FE 71
        jr      z,PRINT_BOTTOM_AFTER_WIDTH                     ;#74B5: 28 03
        ld      de,PRINTER_SEQ_S768                            ;#74B7: 11 4B 75
PRINT_BOTTOM_AFTER_WIDTH:
        ; Merge after width-selection: ld b,C0h for inner loop
        call    PRINTER_SEND_SEQ_TO_FF                         ;#74BA: CD 33 75
        ld      b,0C0h                                         ;#74BD: 06 C0
PRINT_BOTTOM_INNER:
        ; Inner C0h-col body
        push    bc                                             ;#74BF: C5
        push    hl                                             ;#74C0: E5
        ld      l,b                                            ;#74C1: 68
        dec     l                                              ;#74C2: 2D
        ld      (PRINTER_CURSOR_PIXEL_XY),hl                   ;#74C3: 22 71 DD
        ld      ix,PRINTER_PIXEL_BYTE_LO                       ;#74C6: DD 21 73 DD
        xor     a                                              ;#74CA: AF
        ld      (ix),a                                         ;#74CB: DD 77 00
        ld      (ix+1),a                                       ;#74CE: DD 77 01
        ld      bc,403h                                        ;#74D1: 01 03 04
PRINT_BOTTOM_PIXEL_BODY:
        ; Per-pixel body: RENDER_BOTTOM_ROW + LOOKUP_PIXEL_BITS + accumulate
        push    bc                                             ;#74D4: C5
        call    PRINTER_RENDER_BOTTOM_ROW                      ;#74D5: CD 99 73
        call    LOOKUP_PRINTER_PIXEL_BITS                      ;#74D8: CD 59 75
        pop     bc                                             ;#74DB: C1
        ld      a,d                                            ;#74DC: 7A
        and     c                                              ;#74DD: A1
        or      (ix)                                           ;#74DE: DD B6 00
        ld      (ix),a                                         ;#74E1: DD 77 00
        ld      a,e                                            ;#74E4: 7B
        and     c                                              ;#74E5: A1
        or      (ix+1)                                         ;#74E6: DD B6 01
        ld      (ix+1),a                                       ;#74E9: DD 77 01
        rlc     c                                              ;#74EC: CB 01
        rlc     c                                              ;#74EE: CB 01
        ld      hl,(PRINTER_CURSOR_PIXEL_XY)                   ;#74F0: 2A 71 DD
        inc     h                                              ;#74F3: 24
        ld      (PRINTER_CURSOR_PIXEL_XY),hl                   ;#74F4: 22 71 DD
        djnz    PRINT_BOTTOM_PIXEL_BODY                        ;#74F7: 10 DB
        ld      a,(ix)                                         ;#74F9: DD 7E 00
        call    PRINTER_PUT_CHAR                               ;#74FC: CD 8C 72
        call    PRINTER_PUT_CHAR_IF_72                         ;#74FF: CD 1E 75
        ld      a,(ix+1)                                       ;#7502: DD 7E 01
        call    PRINTER_PUT_CHAR                               ;#7505: CD 8C 72
        call    PRINTER_PUT_CHAR_IF_72                         ;#7508: CD 1E 75
        pop     hl                                             ;#750B: E1
        pop     bc                                             ;#750C: C1
        djnz    PRINT_BOTTOM_INNER                             ;#750D: 10 B0
        call    PRINTER_PUT_CRLF                               ;#750F: CD FF 72
        ld      a,4                                            ;#7512: 3E 04
        add     a,h                                            ;#7514: 84
        ld      h,a                                            ;#7515: 67
        pop     bc                                             ;#7516: C1
        djnz    PRINT_BOTTOM_OUTER                             ;#7517: 10 93
        call    PRINTER_PUT_8_NEWLINES                         ;#7519: CD F7 72
        xor     a                                              ;#751C: AF
        ret                                                    ;#751D: C9

PRINTER_PUT_CHAR_IF_72:
        ; Output A only when IN_GAME_MENU_PARAM=72h (full-width print mode)
        ld      b,a                                            ;#751E: 47
        ld      a,(IN_GAME_MENU_PARAM)                         ;#751F: 3A 36 D1
        cp      PRINTER_MODE_WIDE                              ;#7522: FE 72
        ld      a,b                                            ;#7524: 78
        jp      z,PRINTER_PUT_CHAR                             ;#7525: CA 8C 72
        ret                                                    ;#7528: C9

PRINTER_SEND_S240:
        ; Send PRINTER_SEQ_S240 (ESC S 0240) to set line width to 240 dots
        ld      de,PRINTER_SEQ_S240                            ;#7529: 11 52 75
        jr      PRINTER_SEND_SEQ_TO_FF                         ;#752C: 18 05

PRINTER_SEND_T16:
        ; Send PRINTER_SEQ_T16 (ESC T 1 6) to set line spacing to 16/72"
        ld      de,PRINTER_SEQ_T16                             ;#752E: 11 3D 75
        jr      PRINTER_SEND_SEQ_TO_FF                         ;#7531: 18 00

PRINTER_SEND_SEQ_TO_FF:
        ; Worker: emit (DE), inc DE, repeat until byte = FFh (then ret on the FFh+1=0)
        ld      a,(de)                                         ;#7533: 1A
        inc     a                                              ;#7534: 3C
        ret     z                                              ;#7535: C8
        dec     a                                              ;#7536: 3D
        call    PRINTER_PUT_CHAR                               ;#7537: CD 8C 72
        inc     de                                             ;#753A: 13
        jr      PRINTER_SEND_SEQ_TO_FF                         ;#753B: 18 F6

PRINTER_SEQ_T16:
        ; 7-byte "ESC T 1 6 \r \n \xFF" — set printer line spacing to 16/72"
        PRINTER_ESC                                            ;#753D: 1B
        db      "T16", 0Dh, 0Ah                                ;#753E: 54 31 36 0D 0A
        TEXT_TERMINATOR                                        ;#7543: FF

PRINTER_SEQ_S384:
        ; 7-byte "ESC S 0 3 8 4 \xFF" — set printer line width to 384 dots
        PRINTER_ESC                                            ;#7544: 1B
        db      "S0384"                                        ;#7545: 53 30 33 38 34
        TEXT_TERMINATOR                                        ;#754A: FF

PRINTER_SEQ_S768:
        ; 7-byte "ESC S 0 7 6 8 \xFF" — set printer line width to 768 dots
        PRINTER_ESC                                            ;#754B: 1B
        db      "S0768"                                        ;#754C: 53 30 37 36 38
        TEXT_TERMINATOR                                        ;#7551: FF

PRINTER_SEQ_S240:
        ; 7-byte "ESC S 0 2 4 0 \xFF" — set printer line width to 240 dots
        PRINTER_ESC                                            ;#7552: 1B
        db      "S0240"                                        ;#7553: 53 30 32 34 30
        TEXT_TERMINATOR                                        ;#7558: FF

LOOKUP_PRINTER_PIXEL_BITS:
        ; Index PRINTER_PIXEL_BIT_TABLE by 2*A; return word in DE
        push    hl                                             ;#7559: E5
        ld      hl,PRINTER_PIXEL_BIT_TABLE                     ;#755A: 21 66 75
        add     a,a                                            ;#755D: 87
        call    ADD_A_TO_HL                                    ;#755E: CD ED 60
        ld      d,(hl)                                         ;#7561: 56
        inc     hl                                             ;#7562: 23
        ld      e,(hl)                                         ;#7563: 5E
        pop     hl                                             ;#7564: E1
        ret                                                    ;#7565: C9

PRINTER_PIXEL_BIT_TABLE:
        ; 32-byte table of 2-byte pixel masks for raster-mode printer output
        dh      "FFFFFFFF55AA0055AAFFAAAAFFAA00AA"             ;#7566: FF FF FF FF 55 AA 00 55 AA FF AA AA FF AA 00 AA
        dh      "AA55AA00FF000055FF5500FF55000000"             ;#7576: AA 55 AA 00 FF 00 00 55 FF 55 00 FF 55 00 00 00

PRINT_VRAM_AS_GRAPHICS:
        ; Main raster-output: walk VRAM as a bitmap, emit 16-bit pixel pairs per cell
        call    PRINTER_SEND_T16                               ;#7586: CD 2E 75
        ld      a,(PRINTER_PAGE_HEIGHT)                        ;#7589: 3A 76 DD
        srl     a                                              ;#758C: CB 3F
        srl     a                                              ;#758E: CB 3F
        ld      b,a                                            ;#7590: 47
        ld      h,0                                            ;#7591: 26 00
PRINT_VRAM_OUTER:
        ; Outer vstrip body of PRINT_VRAM_AS_GRAPHICS
        push    bc                                             ;#7593: C5
        call    PRINTER_SEND_S240                              ;#7594: CD 29 75
        ld      a,(PRINTER_PAGE_WIDTH)                         ;#7597: 3A 75 DD
        ld      b,a                                            ;#759A: 47
PRINT_VRAM_INNER:
        ; Inner column body
        push    bc                                             ;#759B: C5
        push    hl                                             ;#759C: E5
        ld      l,b                                            ;#759D: 68
        dec     l                                              ;#759E: 2D
        ld      (PRINTER_CURSOR_PIXEL_XY),hl                   ;#759F: 22 71 DD
        ld      ix,PRINTER_PIXEL_BYTE_LO                       ;#75A2: DD 21 73 DD
        xor     a                                              ;#75A6: AF
        ld      (ix),a                                         ;#75A7: DD 77 00
        ld      (ix+1),a                                       ;#75AA: DD 77 01
        ld      bc,403h                                        ;#75AD: 01 03 04
PRINT_VRAM_PIXEL_BODY:
        ; Per-pixel: PROBE_PIXEL + LOOKUP + accumulate into DD73/DD74
        push    bc                                             ;#75B0: C5
        call    PRINTER_PROBE_PIXEL                            ;#75B1: CD EE 75
        pop     bc                                             ;#75B4: C1
        ld      a,d                                            ;#75B5: 7A
        and     c                                              ;#75B6: A1
        or      (ix)                                           ;#75B7: DD B6 00
        ld      (ix),a                                         ;#75BA: DD 77 00
        ld      a,e                                            ;#75BD: 7B
        and     c                                              ;#75BE: A1
        or      (ix+1)                                         ;#75BF: DD B6 01
        ld      (ix+1),a                                       ;#75C2: DD 77 01
        rlc     c                                              ;#75C5: CB 01
        rlc     c                                              ;#75C7: CB 01
        ld      hl,PRINTER_CURSOR_Y_BYTE                       ;#75C9: 21 72 DD
        inc     (hl)                                           ;#75CC: 34
        djnz    PRINT_VRAM_PIXEL_BODY                          ;#75CD: 10 E1
        ld      a,(ix)                                         ;#75CF: DD 7E 00
        call    PRINTER_PUT_CHAR                               ;#75D2: CD 8C 72
        ld      a,(ix+1)                                       ;#75D5: DD 7E 01
        call    PRINTER_PUT_CHAR                               ;#75D8: CD 8C 72
        pop     hl                                             ;#75DB: E1
        pop     bc                                             ;#75DC: C1
        djnz    PRINT_VRAM_INNER                               ;#75DD: 10 BC
        call    PRINTER_PUT_CRLF                               ;#75DF: CD FF 72
        ld      a,4                                            ;#75E2: 3E 04
        add     a,h                                            ;#75E4: 84
        ld      h,a                                            ;#75E5: 67
        pop     bc                                             ;#75E6: C1
        djnz    PRINT_VRAM_OUTER                               ;#75E7: 10 AA
        call    PRINTER_PUT_8_NEWLINES                         ;#75E9: CD F7 72
        xor     a                                              ;#75EC: AF
        ret                                                    ;#75ED: C9

PRINTER_PROBE_PIXEL:
        ; Read 1 bit at PRINTER_CURSOR_PIXEL_XY (x,y); DE = 0 or FFFFh mask
        ld      hl,(PRINTER_CURSOR_PIXEL_XY)                   ;#75EE: 2A 71 DD
        call    PRINTER_PIXEL_VRAM_ADDR                        ;#75F1: CD 17 76
        ld      a,(hl)                                         ;#75F4: 7E
        call    PRINTER_TILE_TO_PATTERN                        ;#75F5: CD 48 76
        ld      de,(PRINTER_CURSOR_PIXEL_XY)                   ;#75F8: ED 5B 71 DD
        ld      a,e                                            ;#75FC: 7B
        and     7                                              ;#75FD: E6 07
        ld      e,a                                            ;#75FF: 5F
        ld      d,0                                            ;#7600: 16 00
        add     hl,de                                          ;#7602: 19
        ld      a,(PRINTER_CURSOR_Y_BYTE)                      ;#7603: 3A 72 DD
        and     7                                              ;#7606: E6 07
        inc     a                                              ;#7608: 3C
        ld      b,a                                            ;#7609: 47
        ld      a,(hl)                                         ;#760A: 7E
PRINTER_PROBE_PIXEL_TEST:
        ; Inner shift loop: extract target bit (shifts MSB into carry)
        add     a,a                                            ;#760B: 87
        djnz    PRINTER_PROBE_PIXEL_TEST                       ;#760C: 10 FD
        ld      de,0                                           ;#760E: 11 00 00
        jr      nc,PRINTER_PROBE_PIXEL_HIT_RET                 ;#7611: 30 03
        ld      de,0FFFFh                                      ;#7613: 11 FF FF
PRINTER_PROBE_PIXEL_HIT_RET:
        ; Pixel set: return DE=FFFFh (the bit-set tail)
        ret                                                    ;#7616: C9

PRINTER_PIXEL_VRAM_ADDR:
        ; Resolve (x,y) → name-table tile addr; HL points to the matching VRAM byte
        push    hl                                             ;#7617: E5
        ld      a,l                                            ;#7618: 7D
        and     0F8h                                           ;#7619: E6 F8
        rrca                                                   ;#761B: 0F
        rrca                                                   ;#761C: 0F
        rrca                                                   ;#761D: 0F
        ld      h,a                                            ;#761E: 67
        ld      a,(PRINTER_PAGE_HEIGHT)                        ;#761F: 3A 76 DD
        and     0F8h                                           ;#7622: E6 F8
        rrca                                                   ;#7624: 0F
        rrca                                                   ;#7625: 0F
        rrca                                                   ;#7626: 0F
        call    PRINTER_BUILD_VRAM_PTR                         ;#7627: CD 3A 76
        pop     hl                                             ;#762A: E1
        ld      a,h                                            ;#762B: 7C
        and     0F8h                                           ;#762C: E6 F8
        rrca                                                   ;#762E: 0F
        rrca                                                   ;#762F: 0F
        rrca                                                   ;#7630: 0F
        ex      de,hl                                          ;#7631: EB
        call    ADD_A_TO_HL                                    ;#7632: CD ED 60
        ld      bc,PRINTER_PIXEL_BUFFER                        ;#7635: 01 B1 D9
        add     hl,bc                                          ;#7638: 09
        ret                                                    ;#7639: C9

PRINTER_BUILD_VRAM_PTR:
        ; HL = (3800h | (y/8)*32 + x/8) — name-table cell address from pixel coords
        ld      e,a                                            ;#763A: 5F
        ld      d,0                                            ;#763B: 16 00
        ld      l,d                                            ;#763D: 6A
        ld      b,8                                            ;#763E: 06 08
PRINTER_BUILD_VRAM_BIT_LOOP:
        ; 8-iter shift body building the VRAM offset bit-by-bit
        add     hl,hl                                          ;#7640: 29
        jr      nc,PRINTER_BUILD_VRAM_ADD                      ;#7641: 30 01
        add     hl,de                                          ;#7643: 19
PRINTER_BUILD_VRAM_ADD:
        ; Carry path: add DE before next shift
        djnz    PRINTER_BUILD_VRAM_BIT_LOOP                    ;#7644: 10 FA
        ex      de,hl                                          ;#7646: EB
        ret                                                    ;#7647: C9

PRINTER_TILE_TO_PATTERN:
        ; HL = (BIOS_CHARSET) + A*8 — pattern[0..7] base address for tile A
        ld      h,0                                            ;#7648: 26 00
        ld      l,a                                            ;#764A: 6F
        add     hl,hl                                          ;#764B: 29
        add     hl,hl                                          ;#764C: 29
        add     hl,hl                                          ;#764D: 29
        ld      b,h                                            ;#764E: 44
        ld      c,l                                            ;#764F: 4D
        ld      hl,(BIOS_CHARSET)                              ;#7650: 2A 04 00
        add     hl,bc                                          ;#7653: 09
        ret                                                    ;#7654: C9

INIT_PRINTER_PATTERNS:
        ; Clear VRAM 0300..071F, then load three RLE pattern streams into VRAM
        ld      a,0F0h                                         ;#7655: 3E F0
        LOAD_VRAM_ADDRESS hl, 300h                             ;#7657: 21 00 03
        ld      bc,420h                                        ;#765A: 01 20 04
        call    BIOS_FILVRM                                    ;#765D: CD 56 00
        LOAD_VRAM_ADDRESS de, 2300h                            ;#7660: 11 00 23
        ld      hl,GFX_PRINTER_PATTERN_RLE_3                   ;#7663: 21 F5 79
        call    LOAD_PATTERN_TO_VRAM_3_BANKS                   ;#7666: CD 63 61
        LOAD_VRAM_ADDRESS de, 508h                             ;#7669: 11 08 05
        ld      hl,GFX_PRINTER_PATTERN_RLE                     ;#766C: 21 04 78
        call    LOAD_PATTERN_TO_VRAM_3_BANKS                   ;#766F: CD 63 61
        LOAD_VRAM_ADDRESS de, 1800h                            ;#7672: 11 00 18
        ld      hl,GFX_PRINTER_PATTERN_RLE_2                   ;#7675: 21 A8 79
        jp      DECOMPRESS_RLE_TO_VRAM                         ;#7678: C3 7A 61

DRAW_PRINTER_SCREEN_LAYOUT:
        ; Fill mid-VRAM, draw printer-screen tile grids + RLE pattern decoration
        ld      a,0FCh                                         ;#767B: 3E FC
        ld      hl,980h                                        ;#767D: 21 80 09
        ld      bc,180h                                        ;#7680: 01 80 01
        call    BIOS_FILVRM                                    ;#7683: CD 56 00
        ld      hl,GFX_PRINTER_SCREEN_GRID_1                   ;#7686: 21 CC 76
        LOAD_NAME_TABLE de, 2, 13                              ;#7689: 11 4D 38
        ld      bc,207h                                        ;#768C: 01 07 02
        call    LDIRVM_TEXT_GRID                               ;#768F: CD B6 76
        ld      hl,GFX_PRINTER_SCREEN_RLE_1                    ;#7692: 21 DA 76
        call    DECOMPRESS_RLE_WITH_TARGET                     ;#7695: CD 76 61
        ld      hl,GFX_PRINTER_SCREEN_GRID_2                   ;#7698: 21 50 77
        LOAD_NAME_TABLE de, 13, 6                              ;#769B: 11 A6 39
        ld      bc,314h                                        ;#769E: 01 14 03
        call    LDIRVM_TEXT_GRID                               ;#76A1: CD B6 76
        ld      hl,GFX_PRINTER_SCREEN_RLE_2                    ;#76A4: 21 8C 77
        call    DECOMPRESS_RLE_WITH_TARGET                     ;#76A7: CD 76 61
        LOAD_NAME_TABLE de, 24, 0                              ;#76AA: 11 00 3B
        ld      hl,GFX_PRINTER_SCREEN_FOOTER                   ;#76AD: 21 DC 77
        ld      bc,18h                                         ;#76B0: 01 18 00
        jp      BIOS_LDIRVM                                    ;#76B3: C3 5C 00

LDIRVM_TEXT_GRID:
        ; For B rows: LDIRVM C bytes HL→DE, then HL+=C, DE+=20h — draws a text rectangle
        push    bc                                             ;#76B6: C5
        push    hl                                             ;#76B7: E5
        ld      b,0                                            ;#76B8: 06 00
        push    bc                                             ;#76BA: C5
        push    de                                             ;#76BB: D5
        call    BIOS_LDIRVM                                    ;#76BC: CD 5C 00
        pop     hl                                             ;#76BF: E1
        ld      bc,20h                                         ;#76C0: 01 20 00
        add     hl,bc                                          ;#76C3: 09
        ex      de,hl                                          ;#76C4: EB
        pop     bc                                             ;#76C5: C1
        pop     hl                                             ;#76C6: E1
        add     hl,bc                                          ;#76C7: 09
        pop     bc                                             ;#76C8: C1
        djnz    LDIRVM_TEXT_GRID                               ;#76C9: 10 EB
        ret                                                    ;#76CB: C9

GFX_PRINTER_SCREEN_GRID_1:
        ; 14-byte tile grid drawn at VRAM 384Dh (2x7) at top of the printer screen
        dh      "606162636465666768696A6B6C6D"                 ;#76CC: 60 61 62 63 64 65 66 67 68 69 6A 6B 6C 6D

GFX_PRINTER_SCREEN_RLE_1:
        ; RLE-compressed pattern stream decompressed via DECOMPRESS_RLE_WITH_TARGET
        dh      "8338016E186F017080A4389871727374"             ;#76DA: 83 38 01 6E 18 6F 01 70 80 A4 38 98 71 72 73 74
        dh      "75767778797A7B7C7D7E007F80818283"             ;#76EA: 75 76 77 78 79 7A 7B 7C 7D 7E 00 7F 80 81 82 83
        dh      "8384008580C43898868788898A8B8C8D"             ;#76FA: 83 84 00 85 80 C4 38 98 86 87 88 89 8A 8B 8C 8D
        dh      "8E8F909192939495969798999A9B9C9D"             ;#770A: 8E 8F 90 91 92 93 94 95 96 97 98 99 9A 9B 9C 9D
        dh      "80E338019E189F01A0804D390C0C01A1"             ;#771A: 80 E3 38 01 9E 18 9F 01 A0 80 4D 39 0C 0C 01 A1
        dh      "80673984A2A3A4A50200030C86404D45"             ;#772A: 80 67 39 84 A2 A3 A4 A5 02 00 03 0C 86 40 4D 45
        dh      "4E5540030C01A180873984A6A7A8A902"             ;#773A: 4E 55 40 03 0C 01 A1 80 87 39 84 A6 A7 A8 A9 02
        dh      "000C0C01A100"                                 ;#774A: 00 0C 0C 01 A1 00

GFX_PRINTER_SCREEN_GRID_2:
        ; 60-byte tile grid drawn at VRAM 39A6h as the 3x20 main printer-screen region
        dh      "00AAABACAD0000AEAF0C47414D450C0C"             ;#7750: 00 AA AB AC AD 00 00 AE AF 0C 47 41 4D 45 0C 0C
        dh      "0C0C0CA1B0B1B2B3B4B5B6B7B80C4D4F"             ;#7760: 0C 0C 0C A1 B0 B1 B2 B3 B4 B5 B6 B7 B8 0C 4D 4F
        dh      "444946590C0C0CA1B9BABBBCBDBE000C"             ;#7770: 44 49 46 59 0C 0C 0C A1 B9 BA BB BC BD BE 00 0C
        dh      "0C0C53454C460C0C0C0C0CA1"                     ;#7780: 0C 0C 53 45 4C 46 0C 0C 0C 0C 0C A1

GFX_PRINTER_SCREEN_RLE_2:
        ; Second RLE-compressed pattern stream for the printer screen
        dh      "063A87BFC00F0FC1C2000C0C01A18025"             ;#778C: 06 3A 87 BF C0 0F 0F C1 C2 00 0C 0C 01 A1 80 25
        dh      "3A8AC3C4C5C60FC7C8C9CACB08CA83CC"             ;#779C: 3A 8A C3 C4 C5 C6 0F C7 C8 C9 CA CB 08 CA 83 CC
        dh      "CACD80403A05CE8ACFD0D1D2D3D4D5D6"             ;#77AC: CA CD 80 40 3A 05 CE 8A CF D0 D1 D2 D3 D4 D5 D6
        dh      "CED708CE01D808CE05D901DA06DB83DC"             ;#77BC: CE D7 08 CE 01 D8 08 CE 05 D9 01 DA 06 DB 83 DC
        dh      "DDDE08DF82E0E107D920E220E220E300"             ;#77CC: DD DE 08 DF 82 E0 E1 07 D9 20 E2 20 E2 20 E3 00

GFX_PRINTER_SCREEN_FOOTER:
        ; 24-byte tile row drawn at VRAM 3B00h as the printer-screen footer line
        dh      "6750000F5F30100F"                             ;#77DC: 67 50 00 0F 5F 30 10 0F

GFX_PRINTER_SCREEN_TAIL_B:
        ; Alt-variant 16-byte trailing data block (variant 2 of GFX_PRINTER_SCREEN_TAIL)
        dh      "8A340C0F9360080A8B4D140186320401"             ;#77E4: 8A 34 0C 0F 93 60 08 0A 8B 4D 14 01 86 32 04 01

GFX_PRINTER_SCREEN_TAIL:
        ; 16-byte trailing data block right after the footer row
        dh      "8E2E18018E2E1C0A8B4D14019360080A"             ;#77F4: 8E 2E 18 01 8E 2E 1C 0A 8B 4D 14 01 93 60 08 0A

GFX_PRINTER_PATTERN_RLE:
        ; RLE pattern stream loaded into all three Screen-2 pattern banks by 766Fh
        dh      "08B00400071003410510034102100400"             ;#7804: 08 B0 04 00 07 10 03 41 05 10 03 41 02 10 04 00
        dh      "05108200400710034102F183F4101003"             ;#7814: 05 10 82 00 40 07 10 03 41 02 F1 83 F4 10 10 03
        dh      "4102F184F41000400D1002F003F185F0"             ;#7824: 41 02 F1 84 F4 10 00 40 0D 10 02 F0 03 F1 85 F0
        dh      "FAFAF0F003F183F0FAFA081005C003FC"             ;#7834: FA FA F0 F0 03 F1 83 F0 FA FA 08 10 05 C0 03 FC
        dh      "81C005FC82C0C10300081004A18341FA"             ;#7844: 81 C0 05 FC 82 C0 C1 03 00 08 10 04 A1 83 41 FA
        dh      "A103A003A182FAA103A003A102108141"             ;#7854: A1 03 A0 03 A1 82 FA A1 03 A0 03 A1 02 10 81 41
        dh      "04A18241100541031081F1041002C002"             ;#7864: 04 A1 82 41 10 05 41 03 10 81 F1 04 10 02 C0 02
        dh      "FC05C181C003C105C0081008F103FA05"             ;#7874: FC 05 C1 81 C0 03 C1 05 C0 08 10 08 F1 03 FA 05
        dh      "F002EA83FAFEFE03F002E106F10F1081"             ;#7884: F0 02 EA 83 FA FE FE 03 F0 02 E1 06 F1 0F 10 81
        dh      "A00CF104F00810060007A003A108FA08"             ;#7894: A0 0C F1 04 F0 08 10 06 00 07 A0 03 A1 08 FA 08
        dh      "F104FE81F103FE041004E081F003E004"             ;#78A4: F1 04 FE 81 F1 03 FE 04 10 04 E0 81 F0 03 E0 04
        dh      "0084FAFEE0E0040084FAFEE01004E084"             ;#78B4: 00 84 FA FE E0 E0 04 00 84 FA FE E0 10 04 E0 84
        dh      "FAFEE01004E081F003E0040094540054"             ;#78C4: FA FE E0 10 04 E0 81 F0 03 E0 04 00 94 54 00 54
        dh      "0054000054A400540054101041A4A0A4"             ;#78D4: 00 54 00 00 54 A4 00 54 00 54 10 10 41 A4 A0 A4
        dh      "A003A1811003FA04EA811003F002FE03"             ;#78E4: A0 03 A1 81 10 03 FA 04 EA 81 10 03 F0 02 FE 03
        dh      "E003F004FE82E1FE06EA84A1E4A0A405"             ;#78F4: E0 03 F0 04 FE 82 E1 FE 06 EA 84 A1 E4 A0 A4 05
        dh      "A19B5400540054101041E4E0E4E0E4E0"             ;#7904: A1 9B 54 00 54 00 54 10 10 41 E4 E0 E4 E0 E4 E0
        dh      "E0E4E4E0E4E0E4E0E0E400005403008A"             ;#7914: E0 E4 E4 E0 E4 E0 E4 E0 E0 E4 00 00 54 03 00 8A
        dh      "5400101041100000545005418E005450"             ;#7924: 54 00 10 10 41 10 00 00 54 50 05 41 8E 00 54 50
        dh      "10104110000054501010510300825400"             ;#7934: 10 10 41 10 00 00 54 50 10 10 51 03 00 82 54 00
        dh      "03E18810000054001010510300825400"             ;#7944: 03 E1 88 10 00 00 54 00 10 10 51 03 00 82 54 00
        dh      "03E18810000054001010510300815404"             ;#7954: 03 E1 88 10 00 00 54 00 10 10 51 03 00 81 54 04
        dh      "0081540B0081540A10811F0D1002C081"             ;#7964: 00 81 54 0B 00 81 54 0A 10 81 1F 0D 10 02 C0 81
        dh      "F004C00F10811F111007C082FCCF071C"             ;#7974: F0 04 C0 0F 10 81 1F 11 10 07 C0 82 FC CF 07 1C
        dh      "06CF021C0C1004E004EF811F03EF0540"             ;#7984: 06 CF 02 1C 0C 10 04 E0 04 EF 81 1F 03 EF 05 40
        dh      "02108441E4A0A4051A02FE05AE81E106"             ;#7994: 02 10 84 41 E4 A0 A4 05 1A 02 FE 05 AE 81 E1 06
        dh      "1F02AF00"                                     ;#79A4: 1F 02 AF 00

GFX_PRINTER_PATTERN_RLE_2:
        ; RLE pattern stream loaded into VRAM 1800h by 7678h DECOMPRESS_RLE_TO_VRAM
        dh      "028005C081801900870121121C200000"             ;#79A8: 02 80 05 C0 81 80 19 00 87 01 21 12 1C 20 00 00
        dh      "03801100020482083003802000811003"             ;#79B8: 03 80 11 00 02 04 82 08 30 03 80 20 00 81 10 03
        dh      "3081102D008502040009010503810108"             ;#79C8: 30 81 10 2D 00 85 02 04 00 09 01 05 03 81 01 08
        dh      "0083010608090084384080801A0087C0"             ;#79D8: 00 83 01 06 08 09 00 84 38 40 80 80 1A 00 87 C0
        dh      "2010080804020D000340170000"                   ;#79E8: 20 10 08 08 04 02 0D 00 03 40 17 00 00

GFX_PRINTER_PATTERN_RLE_3:
        ; RLE pattern stream loaded into VRAM 2300h by 7666h LOAD_PATTERN_TO_VRAM_3_BANKS
        dh      "0200837FFF7F050096C0E0E7EFE7E000"             ;#79F5: 02 00 83 7F FF 7F 05 00 96 C0 E0 E7 EF E7 E0 00
        dh      "207070FEFFFE7000387F3F07387F3F03"             ;#7A05: 20 70 70 FE FF FE 70 00 38 7F 3F 07 38 7F 3F 03
        dh      "0085C0E0C000C00400840E3F64440500"             ;#7A15: 00 85 C0 E0 C0 00 C0 04 00 84 0E 3F 64 44 05 00
        dh      "8380C0400300857FFF7F000003E08AE7"             ;#7A25: 83 80 C0 40 03 00 85 7F FF 7F 00 00 03 E0 8A E7
        dh      "EFC7000070F0E0E0C003008507387F3F"             ;#7A35: EF C7 00 00 70 F0 E0 E0 C0 03 00 85 07 38 7F 3F
        dh      "07030090E0C000C0E0C0000084888848"             ;#7A45: 07 03 00 90 E0 C0 00 C0 E0 C0 00 00 84 88 88 48
        dh      "7021000003208340C0800400831F001F"             ;#7A55: 70 21 00 00 03 20 83 40 C0 80 04 00 83 1F 00 1F
        dh      "050083FF00FF050083F800F808008301"             ;#7A65: 05 00 83 FF 00 FF 05 00 83 F8 00 F8 08 00 83 01
        dh      "31300500024007000201060002800500"             ;#7A75: 31 30 05 00 02 40 07 00 02 01 06 00 02 80 05 00
        dh      "8718FFFF070F1F1F0407820F1F063993"             ;#7A85: 87 18 FF FF 07 0F 1F 1F 04 07 82 0F 1F 06 39 93
        dh      "0181C3C3C7C7CFCF87BFBF9818187F7F"             ;#7A95: 01 81 C3 C3 C7 C7 CF CF 87 BF BF 98 18 18 7F 7F
        dh      "00E0E003C702F09D78707EFEFEF0EFEF"             ;#7AA5: 00 E0 E0 03 C7 02 F0 9D 78 70 7E FE FE F0 EF EF
        dh      "00010307060E8C9C7CFFFF3331313070"             ;#7AB5: 00 01 03 07 06 0E 8C 9C 7C FF FF 33 31 31 30 70
        dh      "1E0E8ECECE03EE820E4E037F020E863E"             ;#7AC5: 1E 0E 8E CE CE 03 EE 82 0E 4E 03 7F 02 0E 86 3E
        dh      "0018BC9E8C0800020C817F070081C005"             ;#7AD5: 00 18 BC 9E 8C 08 00 02 0C 81 7F 07 00 81 C0 05
        dh      "00030C050003300400900585C5607F7F"             ;#7AE5: 00 03 0C 05 00 03 30 04 00 90 05 85 C5 60 7F 7F
        dh      "E343070E1C08C0C01F1F0400020396E3"             ;#7AF5: E3 43 07 0E 1C 08 C0 C0 1F 1F 04 00 02 03 96 E3
        dh      "E6060F0F0E8000303919FCFC0C3078FF"             ;#7B05: E6 06 0F 0F 0E 80 00 30 39 19 FC FC 0C 30 78 FF
        dh      "DFBC707F3F08070539843F1F0FCF05C3"             ;#7B15: DF BC 70 7F 3F 08 07 05 39 84 3F 1F 0F CF 05 C3
        dh      "9B8303003F3F30303F3F3001E1E16363"             ;#7B25: 9B 83 03 00 3F 3F 30 30 3F 3F 30 01 E1 E1 63 63
        dh      "E3E767CFC0C080B8BF3F1F9C031C8C0C"             ;#7B35: E3 E7 67 CF C0 C0 80 B8 BF 3F 1F 9C 03 1C 8C 0C
        dh      "CFC7C36060E0E1C1C3C78703EE96CECF"             ;#7B45: CF C7 C3 60 60 E0 E1 C1 C3 C7 87 03 EE 96 CE CF
        dh      "8787030000040E1EFCF8F07EEECECEFF"             ;#7B55: 87 87 03 00 00 04 0E 1E FC F8 F0 7E EE CE CE FF
        dh      "7F370300031C853CFCF8F07F040C871C"             ;#7B65: 7F 37 03 00 03 1C 85 3C FC F8 F0 7F 04 0C 87 1C
        dh      "7B31C0C0DFDF03C085800E0FEFED060C"             ;#7B75: 7B 31 C0 C0 DF DF 03 C0 85 80 0E 0F EF ED 06 0C
        dh      "9E8CCCE04007033632337060E0C180D9"             ;#7B85: 9E 8C CC E0 40 07 03 36 32 33 70 60 E0 C1 80 D9
        dh      "5958183071E1C12282C6460CFCF8E003"             ;#7B95: 59 58 18 30 71 E1 C1 22 82 C6 46 0C FC F8 E0 03
        dh      "00831F001F050083FF00FF050085F800"             ;#7BA5: 00 83 1F 00 1F 05 00 83 FF 00 FF 05 00 85 F8 00
        dh      "F800000880040087030F3F0F030F3F03"             ;#7BB5: F8 00 00 08 80 04 00 87 03 0F 3F 0F 03 0F 3F 03
        dh      "0085BF7FC0F0FC030082FDFE04008EC0"             ;#7BC5: 00 85 BF 7F C0 F0 FC 03 00 82 FD FE 04 00 8E C0
        dh      "F0FCF00300000307070F0F403F030085"             ;#7BD5: F0 FC F0 03 00 00 03 07 07 0F 0F 40 3F 03 00 85
        dh      "1C7EFF02FC03008D387EFFC00000C0E0"             ;#7BE5: 1C 7E FF 02 FC 03 00 8D 38 7E FF C0 00 00 C0 E0
        dh      "E0F0F01F1F063F02FF03FD85FFFCF8FF"             ;#7BF5: E0 F0 F0 1F 1F 06 3F 02 FF 03 FD 85 FF FC F8 FF
        dh      "FF03BF85FF3F1FF8F806FC05FF8B0106"             ;#7C05: FF 03 BF 85 FF 3F 1F F8 F8 06 FC 05 FF 8B 01 06
        dh      "18FF0006186080FFF90300880103070F"             ;#7C15: 18 FF 00 06 18 60 80 FF F9 03 00 88 01 03 07 0F
        dh      "1F3F3F7F04018300F07F03FF85F7EBFC"             ;#7C25: 1F 3F 3F 7F 04 01 83 00 F0 7F 03 FF 85 F7 EB FC
        dh      "0FFE03FF86DFAF7FFCFE00048082000F"             ;#7C35: 0F FE 03 FF 86 DF AF 7F FC FE 00 04 80 82 00 0F
        dh      "050095FEF8F801FEFEF0C000006080FE"             ;#7C45: 05 00 95 FE F8 F8 01 FE FE F0 C0 00 00 60 80 FE
        dh      "F9E79F7FFFE79F7F05FF811F033F897F"             ;#7C55: F9 E7 9F 7F FF E7 9F 7F 05 FF 81 1F 03 3F 89 7F
        dh      "7D7E7E01070F1F1F033F83C0F0F805FF"             ;#7C65: 7D 7E 7E 01 07 0F 1F 1F 03 3F 83 C0 F0 F8 05 FF
        dh      "83010F1F05FF8580E0F0F8F803FC81E0"             ;#7C75: 83 01 0F 1F 05 FF 85 80 E0 F0 F8 F8 03 FC 81 E0
        dh      "03C00480847D3D1F070403047F04FF04"             ;#7C85: 03 C0 04 80 84 7D 3D 1F 07 04 03 04 7F 04 FF 04
        dh      "FE04FF08C0060002019007377B7877AF"             ;#7C95: FE 04 FF 08 C0 06 00 02 01 90 07 37 7B 78 77 AF
        dh      "CFDF7F1F07030101C0E004FF81FE03FF"             ;#7CA5: CF DF 7F 1F 07 03 01 01 C0 E0 04 FF 81 FE 03 FF
        dh      "06FE02FC02C0028081C003E0030F0500"             ;#7CB5: 06 FE 02 FC 02 C0 02 80 81 C0 03 E0 03 0F 05 00
        dh      "83FF00FF050083FF00FF04188434FF00"             ;#7CC5: 83 FF 00 FF 05 00 83 FF 00 FF 04 18 84 34 FF 00
        dh      "FF0418812C03F00D008101040092071F"             ;#7CD5: FF 04 18 81 2C 03 F0 0D 00 81 01 04 00 92 07 1F
        dh      "C0DF9F1F0F0F0701FFE0E0C001010307"             ;#7CE5: C0 DF 9F 1F 0F 0F 07 01 FF E0 E0 C0 01 01 03 07
        dh      "04FF827F0706FF95FC800000FCF0FEFC"             ;#7CF5: 04 FF 82 7F 07 06 FF 95 FC 80 00 00 FC F0 FE FC
        dh      "F8F8E0C001C0F0FEFB9DEEF6F6050083"             ;#7D05: F8 F8 E0 C0 01 C0 F0 FE FB 9D EE F6 F6 05 00 83
        dh      "E0F8030334046681C3032C046681C308"             ;#7D15: E0 F8 03 03 34 04 66 81 C3 03 2C 04 66 81 C3 08
        dh      "00023F82E0070C0002FC8207E0040082"             ;#7D25: 00 02 3F 82 E0 07 0C 00 02 FC 82 07 E0 04 00 82
        dh      "0F3F060082C3C0060002FF060082C303"             ;#7D35: 0F 3F 06 00 82 C3 C0 06 00 02 FF 06 00 82 C3 03
        dh      "060082F0FC160082037F05FF83FEE0FC"             ;#7D45: 06 00 82 F0 FC 16 00 82 03 7F 05 FF 83 FE E0 FC
        dh      "03FE88F08000F8E0E0C0C0038008FF02"             ;#7D55: 03 FE 88 F0 80 00 F8 E0 E0 C0 C0 03 80 08 FF 02
        dh      "0081F805FF03008A80F0FCFEFEFFFEF0"             ;#7D65: 00 81 F8 05 FF 03 00 8A 80 F0 FC FE FE FF FE F0
        dh      "C0C0038081FC070007FF02F0030087F0"             ;#7D75: C0 C0 03 80 81 FC 07 00 07 FF 02 F0 03 00 87 F0
        dh      "0F0000FF0FF003FF86F00F7D3D1F0706"             ;#7D85: 0F 00 00 FF 0F F0 03 FF 86 F0 0F 7D 3D 1F 07 06
        dh      "03020181030307068002C098FF00FF00"             ;#7D95: 03 02 01 81 03 03 07 06 80 02 C0 98 FF 00 FF 00
        dh      "FF071FC0010F7F20468890901F0780C0"             ;#7DA5: FF 07 1F C0 01 0F 7F 20 46 88 90 90 1F 07 80 C0
        dh      "C0E0F80188000030603000C0E000"                 ;#7DB5: C0 E0 F8 01 88 00 00 30 60 30 00 C0 E0 00

PADDING_FF:
        ; 551-byte FFh padding between the last RLE pattern and the GAME_TRAILER
        rept    551
        db      0FFh
        endr                                                   ;#7DC3: FF FF FF FF FF FF FF ...

GAME_TRAILER:
        ; End-of-ROM Konami trailer block (game name + size + RC + AAh)
        ; Game name is "10バイタノシムカートリッジ" ("Jūbai tanoshimu
        ; kātorijji", the Japanese subtitle of "Game Master" — roughly
        ; "a cartridge that's 10x more fun"), written backwards in the
        ; GAME_NAME field. The encoding used is:
        ; 80:ア   81:イ   82:ウ   83:エ   84:オ
        ; 85:カ   86:キ   87:ク   88:ケ   89:コ
        ; 8A:サ   8B:シ   8C:ス   8D:セ   8E:ソ
        ; 8F:タ   90:チ   91:ツ   92:テ   93:ト
        ; 94:ナ   95:ニ   96:ヌ   97:ネ   98:ノ
        ; 99:ハ   9A:ヒ   9B:フ   9C:ヘ   9D:ホ
        ; 9E:マ   9F:ミ   A0:ム   A1:メ   A2:モ
        ; A3:ヤ   A4:ユ   A5:ヨ
        ; A6:ラ   A7:リ   A8:ル   A9:レ   AA:ロ
        ; AB:ワ   AC:ン
        ; B1:ャ   B2:ュ   B3:ョ   B5:ッ   B6:ァ
        ; B7:゛   B8:゜   B9:・   BA:ー
        ; The 00 byte is used as a separator between words of the title.
        ; Reading the bytes back-to-front gives "10" + "バイ" (倍, "times")
        ; + "タノシム" (楽しむ, "to enjoy") + "カートリッジ" (cartridge),
        ; natural-order "10倍楽しむカートリッジ". The 35h RC suffix is BCD
        ; "35" — Game Master is Konami catalog RC-735.
        GAME_NAME       "B78BB5A793BA8500A08B988F0081B799003031"  ;#7FEA: B7 8B B5 A7 93 BA 85 00 A0 8B 98 8F 00 81 B7 99 00 30 31
        GAME_NAME_SIZE  13h                                    ;#7FFD: 13
        RC_NUMBER       35h                                    ;#7FFE: 35
        GAME_TERMINATOR                                        ;#7FFF: AA

END_POINTER:
        end
