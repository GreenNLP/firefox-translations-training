# Author: Ona de Gibert Bonet
# Datestamp: 14-12-2023
# Usage: 

import matplotlib.pyplot as plt
from datetime import datetime
import sys
import os
import re

def plot_data(log_dir):
    bleu_logs = [log_dir+'/'+file for file in os.listdir(log_dir) if file.endswith(".bleu.log")]
    print(bleu_logs)
    print(log_dir)
    #log_dir = os.path.dirname(bleu_logs)
    updates = [int(line) for line in open(log_dir+"/updates.log", 'r').read().splitlines()]
    epochs = [int(line) for line in open(log_dir+"/epochs.log", 'r').read().splitlines()]
    plt.figure(figsize=(10, 10))
    fig, ax1 = plt.subplots()

    for log_file in bleu_logs:
        lang_pair=re.findall(r"\b[a-z]{2}-[a-z]{2}\b",log_file)[0]
        bleu=[float(line) for line in open(log_file).read().splitlines()]
        print(log_file, lang_pair, len(bleu))
        ax1.plot(updates, bleu, label=lang_pair)

    ax1.set_xlabel('Updates')
    ax1.set_ylabel('BLEU')
    ax1.set_title('BLEU over Model Updates')
    
    # Add a second axis for epochs
    ax2 = ax1.twiny()
    ax2.set_xticks(epochs)
    ax2.set_xticklabels(epochs, rotation=45)
    ax2.xaxis.set_label_position('bottom') # set the position of the second x-axis to bottom
    ax2.xaxis.set_ticks_position('bottom') # set the position of the second x-axis to bottom
    ax2.spines['bottom'].set_position(('outward', 40))
    #ax2.plot(epochs, label='Metrics', color='red', linestyle='dashed')
    ax2.set_xlabel('Epochs')
    fig.legend(loc='center right')
   
    plt.grid(True)
    plt.savefig(log_dir+'/bleu_all_pairs.png', bbox_inches='tight', pad_inches=0.02, dpi=150)
    #fig.savefig(log_basename+'.png')  # Provide the desired path and filename

log_dir = sys.argv[1]
plot_data(log_dir)


