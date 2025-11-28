#!/bin/bash
# Script to copy EA files to Desktop

DESKTOP=$HOME/Desktop
mkdir -p $DESKTOP/FVG_Trading_EA
cp /workspace/FVG_Trading_EA.mq5 $DESKTOP/FVG_Trading_EA/
cp /workspace/*.md $DESKTOP/FVG_Trading_EA/
cp /workspace/*.txt $DESKTOP/FVG_Trading_EA/
echo 'Files copied to Desktop/FVG_Trading_EA/'
