import cv2
import numpy as np

def blit(source:np.ndarray, destination:np.ndarray, xPos:int, yPos:int):
    y1, y2 = yPos, yPos + source.shape[0]
    x1, x2 = xPos, xPos + source.shape[1]
    print(source.shape)
    alpha_s = source[:, :, 3] / 255.0
    alpha_l = 1.0 - alpha_s

    for c in range(0, 4):
        destination[y1:y2, x1:x2, c] = (alpha_s * source[:, :, c] +
                                alpha_l * destination[y1:y2, x1:x2, c])
    # destination[yPos:yPos+source.shape[0], xPos:xPos+source.shape[1]] = source


image = cv2.imread(r"Gui\IconMap.png", cv2.IMREAD_UNCHANGED)
logo = cv2.imread(r"C:\Users\Ben H\Downloads\MT_logo.png", cv2.IMREAD_UNCHANGED)

imageSize = 96

for i in range(64):
    x = i%10*imageSize
    y = i//10*imageSize
    blit(logo, image, x, y)

cv2.imshow("Image", image)

cv2.waitKey(0)


cv2.destroyAllWindows()

if input("save? (y/n): ") == "y":
    cv2.imwrite(r"Gui\IconMap.png", image)