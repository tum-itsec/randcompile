# RandCompile

This Git repository contains our Anti-Forensic patch for the Linux kernel. It has been tested for our research paper against Linux v5.15.63. As GitFront is unable to host repositories above a certain size, we will just provide it in the form of a patch.

To apply it follow the following steps:

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
