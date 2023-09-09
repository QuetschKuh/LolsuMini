#!/bin/bash

# File: write.sh
# Author: Leo Harter
# Date: 09.09.2023
# Version: 1.0

# Check if command exists
if ! command -v minipro &> /dev/null
then
    echo "Programmer software not found, please install minipro"
    exit
fi

# Variables
filename="${@}"
chip_id="AT28C64"

# Clear logs
rm -f logs.txt

# Write EEPROM
echo "Writing EEPROM..."
log=$(minipro -p $chip_id -w $filename -e 2>&1)
if [[ $log == *"Verification OK"* ]]; then
    echo "Write EEPROM success!"
else
    echo -e "\e[31m\e[47mFailed to write to EEPROM, check logs for info\e[0m"
    echo $log >> logs.txt
fi

# Verify just for safety
echo "Verifying EEPROM..."
log=$(minipro -p $chip_id -m $filename -e 2>&1)
if [[ $log == *"Verification OK"* ]]; then
    echo "Verify EEPROM success!"
else
    echo -e "\e[31m\e[47mFailed to verify EEPROM, check logs for info\e[0m"
    echo $log >> logs.txt
fi

