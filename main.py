################
#
#
#
################
import tkFileDialog
import tkSimpleDialog
import numpy as np
from numpy.linalg import pinv
from Tkinter import *

window_channels = ["CFP", "GFP", "YFP", "RFP"]
fluor_list = []
channels_list = []
x_list = []


def open_file(control_info):
    row_result = []
    input_file = tkFileDialog.askopenfile(title=control_info)
    remove_line = input_file.readline()
    for i, line in enumerate(input_file.readlines()):
        line = line.split(",")
        bg = 0.0
        for y, value in enumerate(line):
            if y == 1:
                bg = float(value.rstrip())
            elif y > 1:
                row_result.append(remove_bg(bg, float(value)))
    input_file.close()
    return row_result


def combine_channels(return_dict):
    current_fluor = len(fluor_list) + 1
    fluor = tkSimpleDialog.askstring("String", "Input the name of the FP %s: " % current_fluor)  # fill with message
    fluor_list.append(fluor)
    nr_repeats = tkSimpleDialog.askinteger("Number", "Input the number of repeats: ")  # fill with message
    nr_windows = len(window_channels)
    nr_channels = len(channels_list)
    i = 0
    while i < nr_channels:
        rep = 0
        cells = 0
        while rep < nr_repeats:
            j = 0
            while j < nr_windows:
                c = cells
                if fluor not in return_dict:
                    return_dict[fluor] = {}
                if channels_list[i] not in return_dict[fluor]:
                    return_dict[fluor][channels_list[i]] = {}
                if "total" not in return_dict[fluor]:
                    return_dict[fluor]["total"] = {}
                if window_channels[j] not in return_dict[fluor][channels_list[i]]:
                    return_dict[fluor][channels_list[i]][window_channels[j]] = {}
                row_results = open_file("Fluor: %s, Channel: %s, Filter: %s, Repeat: %s" % (
                    fluor, channels_list[i], window_channels[j], rep+1))
                for result in row_results:
                    if c not in return_dict[fluor][channels_list[i]][window_channels[j]]:
                        return_dict[fluor][channels_list[i]][window_channels[j]][c] = result
                    else:
                        return_dict[fluor][channels_list[i]][window_channels[j]][c] += result
                    if c not in return_dict[fluor]["total"]:
                        return_dict[fluor]["total"][c] = result
                    else:
                        return_dict[fluor]["total"][c] += result
                    c += 1
                j += 1
            cells = c
            rep += 1
        i += 1
    return return_dict


def remove_bg(bg, result):
    return_result = float(result - bg)
    return return_result


def calcu_ratio(results_dict):
    print results_dict
    for fluor, fluor_values in results_dict.iteritems():
        for channel, channel_values in fluor_values.iteritems():
            if channel is not "total":
                for split_window, split_window_values in channel_values.iteritems():
                    for cell, cell_value in split_window_values.iteritems():
                        results_dict[fluor][channel][split_window][cell] = float(cell_value) \
                                                                           / float(fluor_values["total"][cell])
    print results_dict
    return results_dict


def make_avg(ratio_dict):
    for fluor, fluor_values in ratio_dict.iteritems():
        for channel, channel_values in fluor_values.iteritems():
            if channel is not "total":
                for split_window, split_window_values in channel_values.iteritems():
                    cells_list = split_window_values.values()
                    ratio_dict[fluor][channel][split_window]["average"] = np.average(cells_list)
                    ratio_dict[fluor][channel][split_window]["std"] = np.std(cells_list)
    return ratio_dict


def make_matrix(ratio_dict):
    matrix = []  # y = channel+split_window, x = fluor
    for channel in channels_list:
        for split_window in window_channels:
            x_list.append("%s*%s" % (channel, split_window))
    for x_pos, x_name in enumerate(x_list):
        matrix.append([])
        for fluor_numb, fluor in enumerate(fluor_list):
            x_name = x_name.split("*")
            channel = x_name[0]
            split_window = x_name[1]
            matrix[x_pos].append(ratio_dict[fluor][channel][split_window]["average"])
    return np.array(matrix)


def inv_matrix(input_matrix):
    # input matrix: y = channel + split window, x = fluor
    # output matrix: y = fluor, x = channel+split window
    return pinv(input_matrix)


def save_unmix_matrix(unmix_matrix):
    save_matrix = tkFileDialog.askdirectory(title="Where do you want the unmixing matrix saved?")
    output_file = open(save_matrix + "/unmixing_matrix.csv", mode='w')
    row = " "
    for x_name in x_list:
        row = "%s,%s" % (row, x_name)
    row += "\n"
    output_file.write(row)
    for fluor_numb, fluor in enumerate(fluor_list):
        row = "%s" % fluor
        for x_numb, x_name in enumerate(x_list):
            row = "%s,%s" % (row, unmix_matrix[fluor_numb][x_numb])
        row += "\n"
        output_file.write(row)
    output_file.close()
    return


def main():
    root = Tk()

    info_dict = {}
    nr_fluors = tkSimpleDialog.askinteger("Number", "Input the number of used FPs per control: ")  # fill with message
    nr_channels = tkSimpleDialog.askinteger("Number",
                                            "Input the number of used channels per control: ")  # fill with message

    i = 0
    if nr_channels > 1:
        while i < nr_channels:
            channels_list.append(
                tkSimpleDialog.askstring("String", "Input the name of channel %s: " % (i + 1)))  # fill with message
            i += 1
    else:
        channels_list.append(tkSimpleDialog.askstring("String", "Input the name of the channel: "))  # fill with message

    while nr_fluors > 0:
        info_dict = combine_channels(info_dict)
        nr_fluors -= 1

    info_dict = calcu_ratio(info_dict)
    info_dict = make_avg(info_dict)
    ratio_matrix = make_matrix(info_dict)
    unmix_matrix_here = inv_matrix(ratio_matrix)
    save_unmix_matrix(unmix_matrix_here)

main()
