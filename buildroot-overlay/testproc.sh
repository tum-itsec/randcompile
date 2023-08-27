#!/bin/sh

ARG="-P 1 -N 10"
lat_syscall $ARG null
lat_syscall $ARG open
lat_syscall $ARG read
lat_syscall $ARG write
lat_syscall $ARG stat
lat_syscall $ARG fstat
lat_select $ARG -n 500 file
lat_select $ARG -n 500 tcp
lat_pipe $ARG
lat_proc $ARG shell
lat_unix $ARG
lat_tcp $ARG localhost
lat_sig $ARG install
lat_sig $ARG catch
lat_sig $ARG prot /hello
