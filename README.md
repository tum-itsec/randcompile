# RandCompile

This Git repository contains our Anti-Forensic patch for the Linux kernel. 
It has been tested for our research paper against Linux v5.15.63. 
As GitFront, which was used during the review process, was unable to host repositories above a certain size, we will just provide it in the form of a patch.

## Recommendend: Build RandCompile using Docker

Use the following commands to apply the patch to a kernel and to build all variants of RandCompile used in our evaluation (including an unmodified defconfig kernel for reference).

```
$> docker build -t randcompile .
$> docker run -v $(pwd)/kernels:/home/randcompile/kernels -it randcompile
```

If you are only interested in testing the effectivness of RandCompile, you can also just build a single RandCompile kernel:

```
$> docker run -v $(pwd)/kernels:/home/randcompile/kernels -it randcompile config_bogusmem
```

Afterwards you can run a specific kernel using QEMU:

```
$> qemu-system-x86_64 -enable-kvm -nographic -cpu host -m 1g -kernel kernels/base.bzImage -initrd <some-initrd> -append 'console=ttyS0'
```

Please replace *<some-initrd>* with some initial ramdisk that can serve as a rootfs for testing. 
For a quick test of RandCompile, you can reuse a ramdisk of you current Linux install from /boot. 
If you want to fully reproduce our results, you can recreate our buildroot setup with the following command. *Note: This will take some time*

```
$> docker run -v $(pwd)/kernels:/home/randcompile/kernels -it randcompile build-initrd
```

The final ramdisk is placed in ```kernels/rootfs.cpio.gz```.

## Manual Build Process

If you cannot or do not want to use Docker, you can also apply our patch by following the steps below:

1. Get the matching version of the Linux kernel by cloning the Linux Git.

```
$> git clone git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git source
$> cd source
$> git checkout v5.15.63
```

2. Apply the patch inside the directory with the checked out kernel. This patch contains our precompiled blacklist for this kernel so that the 2-pass compilation step can be skipped.


```
$> patch -p1 < ../randfun.patch
```

3. Use our build script `./build-kernel.sh` to build the configurations mentioned in our research paper. Please note that `config_base` and `config_base_ftrace` require a prior reset of the kernel Git to its **unpatched** state as not all of our modifications can be disabled via ifdefs. Our compiler plugin is tested on GCC-11 and GCC-12.

```
$> ./build-kernel.sh {config_base|config_base_ftrace|config_forensic_hardening|
config_bogusmem|
config_bogusargs|
config_nobogus}
```
