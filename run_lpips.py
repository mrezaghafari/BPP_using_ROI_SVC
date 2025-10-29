############### PRE REQUISITE ##############################
# MAKE SURE TO INSTALL
#  pip install torch torchvision lpips opencv-python numpy
############### PRE REQUISITE ##############################
################################
#Name: lpips
#Version: 0.1.4
#Summary: LPIPS Similarity metric
################################

import numpy as np
import cv2
import torch
import lpips
import os

def read_yuv_frame(filename, width, height, frame_num):
    frame_size = width * height * 3 // 2
    with open(filename, 'rb') as f:
        f.seek(frame_num * frame_size)
        yuv = np.frombuffer(f.read(frame_size), dtype=np.uint8)

    if yuv.size != frame_size:
        return None

    y = yuv[0:width * height].reshape((height, width))
    u = yuv[width * height:width * height + (width // 2) * (height // 2)].reshape((height // 2, width // 2))
    v = yuv[width * height + (width // 2) * (height // 2):].reshape((height // 2, width // 2))

    # Upsample U and V to match Y channel size
    u_up = cv2.resize(u, (width, height), interpolation=cv2.INTER_LINEAR)
    v_up = cv2.resize(v, (width, height), interpolation=cv2.INTER_LINEAR)

    # Merge and convert to RGB
    yuv_img = cv2.merge((y, u_up, v_up))
    rgb_img = cv2.cvtColor(yuv_img, cv2.COLOR_YUV2RGB)

    return rgb_img

def calculate_lpips(img1, img2, lpips_model, device):
    # Convert to float32 tensor, normalize to [-1, 1]
    img1_t = torch.tensor(img1).permute(2, 0, 1).unsqueeze(0).float().to(device) / 127.5 - 1.0
    img2_t = torch.tensor(img2).permute(2, 0, 1).unsqueeze(0).float().to(device) / 127.5 - 1.0

    with torch.no_grad():
        dist = lpips_model(img1_t, img2_t)

    return dist.item()

def compare_yuv_videos(file1, file2, width, height, num_frames):
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    loss_fn = lpips.LPIPS(net='alex').to(device)  # or net='vgg'

    total_lpips = 0
    count = 0

    for i in range(num_frames):
        img1 = read_yuv_frame(file1, width, height, i)
        img2 = read_yuv_frame(file2, width, height, i)

        if img1 is None or img2 is None:
            print(f"End of video or read error at frame {i}")
            break

        lpips_val = calculate_lpips(img1, img2, loss_fn, device)
        print(f"Frame {i}: LPIPS = {lpips_val:.4f}")
        total_lpips += lpips_val
        count += 1

    if count > 0:
        avg_lpips = total_lpips / count
        print(f"\nAverage LPIPS over {count} frames: {avg_lpips:.4f}")
    else:
        print("No frames compared.")

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Compare two YUV videos using LPIPS.")
    parser.add_argument("--video1", type=str, required=True, help="Path to first YUV file (reference).")
    parser.add_argument("--video2", type=str, required=True, help="Path to second YUV file (distorted).")
    parser.add_argument("--width", type=int, required=True, help="Width of the video frames.")
    parser.add_argument("--height", type=int, required=True, help="Height of the video frames.")
    parser.add_argument("--frames", type=int, required=True, help="Number of frames to compare.")
    args = parser.parse_args()

    compare_yuv_videos(args.video1, args.video2, args.width, args.height, args.frames)



########## HOW TO USE #########
# python lpips_yuv_compare.py \
#  --video1 ref.yuv \
#  --video2 distorted.yuv \
#  --width 2560 \
#  --height 1440 \
#  --frames 300
##############################
