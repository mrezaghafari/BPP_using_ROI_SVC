#!/bin/bash

for name in COD DEVIL FORZA PES; do
  ~/MG/jsvm-master/bin/H264AVCEncoderLibTestStatic -pf /home/resist/MG/jsvm-master/bin/NEW_forNonROI/main_quality_${name}.cfg
done
