#!/bin/bash

# File: compile.sh
# Author: Leo Harter
# Date: 09.09.2023
# Version: 1.0

# Check for command
if ! command -v vasm6502_oldstyle &> /dev/null
then
    echo "Compiler not found, please install vasm, specifically vasm6502_oldstyle"
    exit
fi

# Variable
filename="${1}"

# Compile
vasm6502_oldstyle -c02 -Fbin -dotdir -o "${filename::-4}.bin" ${filename}
