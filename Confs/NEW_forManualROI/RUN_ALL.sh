#!/bin/bash

for name in COD; do
  ~/MG/jsvm-master/bin/H264AVCEncoderLibTestStatic -pf /home/resist/MG/jsvm-master/bin/NEW_forManualROI//main_quality_roi_${name}.cfg
done
