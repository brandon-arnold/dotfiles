#!/bin/bash
FILE=$1
QUESTION=$2
if [ ! -f "$FILE" ]; then
    echo "Error: File $FILE not found"
    exit 1
fi
# Use ag for precise context
CODE=$(ag --cpp -A 100 -B 20 "initial_sbox|TF1|TF2|m_sbox|m_select|data_w|data_r|m_output" "$FILE" 2>/dev/null || cat "$FILE")
# Add zn.cpp, emu.h
ZN=$(ag --cpp -A 20 -B 10 "cat702_2|ROM_REGION|MCFG_DEVICE_ADD" ~/src/mame/src/drivers/zn.cpp 2>/dev/null | head -n 100)
EMU=$(ag --cpp -A 10 -B 10 "device_t|NAME|FUNC|save_item" ~/src/mame/emu.h 2>/dev/null | head -n 100)
CONTEXT="Context: I’m analyzing the CAT702 security chip in Sony’s ZN-1 arcade system (Street Fighter EX). DATA_OUT connects to the uPD78081’s RxD, verified by volt meter. The chip has an 8-bit state (m_output), initialized to 0xfc (not 0xff). TF2 uses initial_sbox to transform m_output to ~0x0b at start. TF1 uses m_sbox (e.g., kn02 from zn.cpp’s ROM_REGION), applying per input bit = 0 with Shift-derived sboxes. SELECT pin (active-low, ~0V) enables communication. MAME uses macros like NAME(), FUNC(), save_item() from emu.h. Input comes via data_w, not a vague ‘game board signal’.\n"
ollama run codellama:34b "$CONTEXT\nIn $FILE, zn.cpp, emu.h:\n$CODE\n\nzn.cpp:\n$ZN\n\nemu.h:\n$EMU\n$QUESTION"
