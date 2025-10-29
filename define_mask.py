import cv2
import numpy as np
import os
import tkinter as tk
from tkinter import filedialog
import math

# Reference resolution
REF_WIDTH = 2560
REF_HEIGHT = 1440
REF_AREA = REF_WIDTH * REF_HEIGHT

# Variables
drawing = False
start_point = None
rectangles = []
image = None
temp_image = None
scale_factor = 1.0

def draw_rectangle(event, x, y, flags, param):
    global drawing, start_point, image, temp_image, rectangles, scale_factor
    x = int(x / scale_factor)
    y = int(y / scale_factor)
    if event == cv2.EVENT_LBUTTONDOWN:
        drawing = True
        start_point = (x, y)
    elif event == cv2.EVENT_MOUSEMOVE:
        if drawing:
            temp_image = image.copy()
            cv2.rectangle(temp_image, start_point, (x, y), (0, 255, 0), 2)
    elif event == cv2.EVENT_LBUTTONUP:
        drawing = False
        end_point = (x, y)
        rectangles.append((start_point, end_point))
        cv2.rectangle(image, start_point, end_point, (0, 255, 0), 2)
        temp_image = image.copy()

def select_image():
    root = tk.Tk()
    root.withdraw()
    file_path = filedialog.askopenfilename(
        title="Select PNG image",
        filetypes=[("PNG files", "*.png"), ("All files", "*.*")]
    )
    return file_path

def calculate_percentage(rects):
    total_area = 0
    for (p1, p2) in rects:
        w = abs(p2[0] - p1[0])
        h = abs(p2[1] - p1[1])
        total_area += w * h
    return total_area, (total_area / REF_AREA) * 100

def resize_for_screen(img):
    global scale_factor
    screen_w = 1920
    screen_h = 1080
    h, w = img.shape[:2]
    scale_factor = min(screen_w / w, screen_h / h, 1.0)
    if scale_factor < 1.0:
        new_w = int(w * scale_factor)
        new_h = int(h * scale_factor)
        return cv2.resize(img, (new_w, new_h), interpolation=cv2.INTER_AREA)
    else:
        return img

def add_center_ellipse(mask, existing_area, target_fraction):
    target_area = REF_AREA * target_fraction
    needed_area = target_area - existing_area
    if needed_area <= 0:
        return mask, existing_area  # No ellipse needed, area unchanged

    # Solve for ellipse axes: area = π * a * b
    # Let's keep ratio b = 0.6 * a (ellipse shape, vertical axis smaller than horizontal)
    # So area = π * a * (0.6a) = π * 0.6 * a^2
    a = math.sqrt(needed_area / (math.pi * 0.6))
    b = 0.6 * a

    center = (REF_WIDTH // 2, REF_HEIGHT // 2)
    axes = (int(a), int(b))
    # Draw filled black ellipse (0) on white (255) mask
    cv2.ellipse(mask, center, axes, 0, 0, 360, 0, -1)

    # Return updated mask and updated total black area (rects + ellipse area)
    total_area = existing_area + needed_area
    return mask, total_area

if __name__ == "__main__":
    img_path = select_image()
    if not img_path:
        print("No image selected.")
        exit()

    original_image = cv2.imread(img_path)
    if original_image is None:
        print("Failed to load image.")
        exit()

    image = original_image.copy()
    temp_image = image.copy()

    cv2.namedWindow("Draw Rectangles - Press 'd' when done", cv2.WINDOW_NORMAL)
    display_img = resize_for_screen(image)
    cv2.setMouseCallback("Draw Rectangles - Press 'd' when done", draw_rectangle)

    while True:
        show_img = cv2.resize(temp_image, (display_img.shape[1], display_img.shape[0]))
        cv2.imshow("Draw Rectangles - Press 'd' when done", show_img)
        key = cv2.waitKey(1) & 0xFF
        if key == ord('d'):
            break
        elif key == 27:
            rectangles.clear()
            break

    cv2.destroyAllWindows()

    if rectangles:
        boxes_area, boxes_percentage = calculate_percentage(rectangles)
        print(f"Rectangles area: {boxes_percentage:.2f}% of a {REF_WIDTH}x{REF_HEIGHT} frame.")

        # --- Save manual mask with just boxes ---
        mask = np.ones((REF_HEIGHT, REF_WIDTH), dtype=np.uint8) * 255
        for (p1, p2) in rectangles:
            cv2.rectangle(mask, p1, p2, 0, -1)
        base_name = os.path.splitext(img_path)[0]
        manual_mask_path = f"{base_name}_manualMask.png"
        cv2.imwrite(manual_mask_path, mask)
        print(f"Saved: {manual_mask_path}")

        # --- Save %25 mask ---
        mask25 = np.ones((REF_HEIGHT, REF_WIDTH), dtype=np.uint8) * 255
        for (p1, p2) in rectangles:
            cv2.rectangle(mask25, p1, p2, 0, -1)
        mask25, total_area_25 = add_center_ellipse(mask25, boxes_area, 0.25)
        percentage_25 = (total_area_25 / REF_AREA) * 100
        mask25_path = f"{base_name}_manualMask%25.png"
        cv2.imwrite(mask25_path, mask25)
        print(f"Saved: {mask25_path}")
        print(f"Total black area (rectangles + ellipse) at 25% target: {percentage_25:.2f}%")

        # --- Save %50 mask ---
        mask50 = np.ones((REF_HEIGHT, REF_WIDTH), dtype=np.uint8) * 255
        for (p1, p2) in rectangles:
            cv2.rectangle(mask50, p1, p2, 0, -1)
        mask50, total_area_50 = add_center_ellipse(mask50, boxes_area, 0.50)
        percentage_50 = (total_area_50 / REF_AREA) * 100
        mask50_path = f"{base_name}_manualMask%50.png"
        cv2.imwrite(mask50_path, mask50)
        print(f"Saved: {mask50_path}")
        print(f"Total black area (rectangles + ellipse) at 50% target: {percentage_50:.2f}%")

    else:
        print("No rectangles drawn.")
