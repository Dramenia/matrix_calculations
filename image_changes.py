from skimage import io
from skimage.external import tifffile
import tkFileDialog
import os
import numpy as np

fluors = []
channels = []


def read_image(channel, unmix_matrix, new_images):
    file_image = tkFileDialog.askopenfile(title="Select tiff file of experiment channel %s" % channel).name
    img = io.imread(file_image)
    bg_per_slide = read_avg_bg(channel)
    if len(img.shape) > 2:
        for slide_nr, img_slide in enumerate(img):
            for row_nr, row in enumerate(img_slide):
                for pix_nr, pix in enumerate(row):
                    corrected_pix = np.asscalar(pix) - bg_per_slide[slide_nr]
                    for fluor in fluors:
                        fluor_pix = corrected_pix * unmix_matrix[fluor][channels.index(channel)]
                        if fluor not in new_images:
                            new_images[fluor] = []
                        if len(new_images[fluor])-1 < slide_nr:
                            new_images[fluor].append([])
                        if len(new_images[fluor][slide_nr])-1 < row_nr:
                            new_images[fluor][slide_nr].append([])
                        if len(new_images[fluor][slide_nr][row_nr])-1 < pix_nr:
                            new_images[fluor][slide_nr][row_nr].append(fluor_pix)
                        else:
                            new_images[fluor][slide_nr][row_nr][pix_nr] += fluor_pix
    else:
        for row_nr, row in enumerate(img):
            for pix_nr, pix in enumerate(row):
                corrected_pix = np.asscalar(pix) - bg_per_slide[0]
                for fluor in fluors:
                    fluor_pix = corrected_pix * unmix_matrix[fluor][channels.index(channel)]
                    if fluor not in new_images:
                        new_images[fluor] = []
                    if len(new_images[fluor]) - 1 < row_nr:
                        new_images[fluor].append([])
                    if len(new_images[fluor][row_nr]) - 1 < pix_nr:
                        new_images[fluor][row_nr].append(fluor_pix)
                    else:
                        new_images[fluor][row_nr][pix_nr] += fluor_pix
    return new_images


def read_unmix_matrix():
    unmix_matrix = {}
    matrix_file = tkFileDialog.askopenfile(title="Select unmixing matrix")
    for i, line in enumerate(matrix_file.readlines()):
        line = line.split(",")
        if i == 0:
            del line[0]
            for line_part in line:
                channels.append(line_part.rstrip())
        else:
            for j, line_part in enumerate(line):
                if j == 0:
                    fluor = line_part
                    fluors.append(fluor)
                    if fluor not in unmix_matrix:
                        unmix_matrix[fluor] = []
                else:
                    result = float(line_part.rstrip())
                    unmix_matrix[fluor].append(result)
    return unmix_matrix


def read_avg_bg(channel):
    bg_per_slide_list = []
    bg_slide_file = tkFileDialog.askopenfile(title="Select background file for %s" % channel)
    skip_line = bg_slide_file.readline()
    for i, line in enumerate(bg_slide_file.readlines()):
        line = line.split(",")
        bg_per_slide_list.append(float(line[1].rstrip()))
    bg_slide_file.close()
    return bg_per_slide_list


def save_image(fluor_name, image):
    output_file = os.path.join(output_dir, "%s.tiff" % fluor_name)
    if len(base_img.shape) == 2:
        slide = image
        for nr_row, row in enumerate(slide):
            for nr_pix, pix in enumerate(row):
                base_img[nr_row][nr_pix] = np.uint16(image[nr_row][nr_pix])
    else:
        for nr_slide, slide in enumerate(image):
            for nr_row, row in enumerate(slide):
                for nr_pix, pix in enumerate(row):
                    base_img[nr_slide][nr_row][nr_pix] = np.uint16(image[nr_slide][nr_row][nr_pix])
    io.imsave(fname=output_file, arr=base_img)
    return


output_image = {}
matrix = read_unmix_matrix()
for work_channel in channels:
    output_image = read_image(work_channel, matrix, output_image)
output_dir = tkFileDialog.askdirectory(title="Where do you want the unmixed images saved?")
base_img = io.imread(tkFileDialog.askopenfile(title="Select tiff file for format information").name)
for fluor in fluors:
    save_image(fluor, output_image[fluor])
