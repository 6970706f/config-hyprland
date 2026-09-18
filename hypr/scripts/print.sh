#!/bin/bash

SAVE_DIR=~/pictures/prints
mkdir -p $SAVE_DIR
OUTPUT=$SAVE_DIR/print_$(date +%Y-%m-%d_%H-%M-%S).png

AREA=$(slurp) && grim -g "$AREA" - | tee $OUTPUT | wl-copy
