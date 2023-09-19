#!/usr/bin/env python3

import glob
import os
import re
from collections import defaultdict
import statistics
import math
import argparse

p = argparse.ArgumentParser()
p.add_argument("--tex", action="store_true")
args = p.parse_args()

DIR = "results"
PATTERN = re.compile("(.+): ([0-9]+\.[0-9]+) microseconds")
NORM_FILE = "base"

measurements = dict()

for fn in glob.glob(DIR + "/*"):
    with open(fn) as f:
        base_fn = os.path.basename(fn)
        measurements[base_fn] = defaultdict(list)
        for l in f:
            m = PATTERN.match(l)
            measurements[base_fn][m.group(1)].append(float(m.group(2)))

for fn, ms in measurements.items():
    if fn != NORM_FILE:
        if not args.tex:
            print(f"File: {fn}")
        else:
            print(fn)
            print(r"\addplot[error bars/.cd, y dir=both, y explicit] coordinates {")
        for k, v in ms.items():
            norm_v = measurements[NORM_FILE][k]
            res = statistics.mean(v) / statistics.mean(norm_v)
            diff = statistics.mean(v) - statistics.mean(norm_v)
            dev = math.sqrt(pow(statistics.stdev(v) / statistics.mean(v), 2)+ pow(statistics.stdev(norm_v) / statistics.mean(norm_v), 2))
            if not args.tex:
                highlight_start, highlight_end = ("\x1b[33m", "\x1b[0m") if not 0.95 < res < 1.05 else ("", "")
                print(f"  {k}: {highlight_start}{res*100} %, diff {diff}, stdev {dev*100}{highlight_end}")
            else:
                if k in ["Protection fault", "Signal handler installation"]:
                    continue
                k = k.replace("Simple", "").replace("latency", "").replace("Pipe", "pipe").replace("Process", "").replace("AF_UNIX sock stream", "AF\_UNIX sock").replace("TCP  using localhost", "TCP sock").replace("Signal handler overhead", "signal handling").replace("Select on 500 fd's", "select(500 fds)").replace("Select on 500 tcp fd's", "select(500 tcp fds)").replace("fork+/bin/sh -c", "fork+/bin/sh")
                k = k.strip()
                print(f"    ({k}, {res:0.4}) +- ({dev:0.3},{dev:0.3})")
        print("};")


#import pprint
#pprint.pprint(measurements_norm)
