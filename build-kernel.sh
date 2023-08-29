#!/bin/bash
set -eux

CURDIR=$PWD

TARGETS="config_base config_base_ftrace config_bogusmem config_bogusargs config_nobogus config_forensic_hardening"

function config_base() {
	cp "../config-base" .config
	
	# Disable Ftrace & Kprobes: Apparantly the patch points at the start of the
	# kernel functions do not get NOPed out correctly
	scripts/config -d CONFIG_KPROBES
	scripts/config -d CONFIG_FTRACE
	scripts/config -d CONFIG_FORENSIC_HARDENING
}

function config_base_ftrace() {
	config_base
	scripts/config -e CONFIG_KPROBES
	scripts/config -e CONFIG_FTRACE
	scripts/config -e CONFIG_FUNCTION_TRACER
	scripts/config -e CONFIG_DYNAMIC_FTRACE
	scripts/config -e CONFIG_FUNCTION_PROFILER
	scripts/config -e CONFIG_FUNCTION_GRAPH_TRACER
	scripts/config -e CONFIG_FTRACE_SYSCALLS
}

function config_forensic_hardening {
	config_base
	scripts/config -e CONFIG_FORENSIC_HARDENING
}

function config_base_ftrace_no_graph() {
	config_base
	scripts/config -e CONFIG_KPROBES
	scripts/config -e CONFIG_FTRACE
	scripts/config -e CONFIG_FUNCTION_TRACER
	scripts/config -e CONFIG_DYNAMIC_FTRACE
	scripts/config -e CONFIG_FUNCTION_PROFILER
	scripts/config -d CONFIG_FUNCTION_GRAPH_TRACER
	scripts/config -e CONFIG_FTRACE_SYSCALLS
}

function config_base_ftrace_with_graph() {
	config_base
	scripts/config -e CONFIG_KPROBES
	scripts/config -e CONFIG_FTRACE
	scripts/config -e CONFIG_FUNCTION_TRACER
	scripts/config -e CONFIG_DYNAMIC_FTRACE
	scripts/config -e CONFIG_FUNCTION_PROFILER
	scripts/config -e CONFIG_FUNCTION_GRAPH_TRACER
	scripts/config -e CONFIG_FTRACE_SYSCALLS
}

function config_bogusmem() {
	config_forensic_hardening
	scripts/config -e CONFIG_RANDFUN
	scripts/config -e CONFIG_RANDFUN_USE_RANDSTRUCT_ATTRS
	scripts/config -e CONFIG_RANDFUN_NO_RANDOMIZE_ABI_FILE
	scripts/config -e CONFIG_RANDFUN_GENERATE_BOGUS_ARGS
	scripts/config -e CONFIG_RANDFUN_GENERATE_BOGUS_MEMOFFSETS
	scripts/config -d CONFIG_RANDFUN_CALLEELIST_FILE
}

function config_bogusargs() {
	config_forensic_hardening
	scripts/config -e CONFIG_RANDFUN
	scripts/config -e CONFIG_RANDFUN_USE_RANDSTRUCT_ATTRS
	scripts/config -e CONFIG_RANDFUN_NO_RANDOMIZE_ABI_FILE
	scripts/config -e CONFIG_RANDFUN_GENERATE_BOGUS_ARGS
	scripts/config -d CONFIG_RANDFUN_GENERATE_BOGUS_MEMOFFSETS
	scripts/config -d CONFIG_RANDFUN_CALLEELIST_FILE
}

function config_nobogus() {
	config_forensic_hardening
	scripts/config -e CONFIG_RANDFUN
	scripts/config -e CONFIG_RANDFUN_USE_RANDSTRUCT_ATTRS
	scripts/config -e CONFIG_RANDFUN_NO_RANDOMIZE_ABI_FILE
	scripts/config -d CONFIG_RANDFUN_GENERATE_BOGUS_ARGS
	scripts/config -d CONFIG_RANDFUN_GENERATE_BOGUS_MEMOFFSETS
	scripts/config -d CONFIG_RANDFUN_CALLEELIST_FILE
}
function build_kernel() {
	#FILENAME=$(basename $f)
	#FILENAME_CLN="${FILENAME//.config-/}"
	FILENAME=$1
	FILENAME_CLN="${FILENAME//config_/}"
	echo $FILENAME
	echo $FILENAME_CLN

	if [[ "$FILENAME_CLN" == "base" || "$FILENAME_CLN" == "base_ftrace" ]]; then
		pushd source-unpatched
	else
		pushd "source"
	fi
	# Configure kernel
	$1
	#cp $f .config
	make oldconfig
	# ./rebuild.sh &> buildlog
	make clean
	make CONFIG_SECTION_MISMATCH_WARN_ONLY=y -j$(nproc) &> $CURDIR/kernels/$FILENAME_CLN.buildlog
	cp vmlinux $CURDIR/kernels/$FILENAME_CLN.vmlinux
	cp arch/x86/boot/bzImage $CURDIR/kernels/$FILENAME_CLN.bzImage
	cp System.map $CURDIR/kernels/$FILENAME_CLN.systemmap
	popd
}

function build_rootfs() {
	curl https://buildroot.org/downloads/buildroot-2023.02.3.tar.gz -o - | tar -xz
	cd buildroot-2023*
	cp ../config-buildroot .config
	make olddefconfig
	make
	cp output/images/rootfs.cpio.gz ../kernels/
}

if [ -z "${1+x}" ] ; then
	for f in $TARGETS; do
		build_kernel $f
	done
else
	if [[ "$1" == "build-initrd" ]]; then
		build_rootfs
	else
		build_kernel $1
	fi
fi
