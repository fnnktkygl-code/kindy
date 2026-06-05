from PIL import Image
import numpy as np

img = Image.open('icon/app_icon.png').convert('RGBA')
arr = np.array(img)

# Print some stats about colors
r, g, b, a = arr[:,:,0], arr[:,:,1], arr[:,:,2], arr[:,:,3]
unique_colors = len(np.unique(arr.reshape(-1, arr.shape[2]), axis=0))
print(f"Unique colors: {unique_colors}")
print(f"Shape: {arr.shape}")
