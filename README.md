# RandCompile

This Git repository contains our Anti-Forensic patch for the Linux kernel. 
It has been tested for our research paper against Linux v5.15.63. 
As GitFront, which was used during the review process, was unable to host repositories above a certain size, we will just provide it in the form of a patch.

## Building the hardened kernels

### Recommendend: Using Docker

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
If you want to fully reproduce our results, you can recreate our buildroot setup with the following command. *Note: This will take some considerable amount of time as buildroot is bootstraping the compiler and compiles all userspace components.*

```
$> docker run -v $(pwd)/kernels:/home/randcompile/kernels -it randcompile build-initrd
```

The final ramdisk is placed in ```kernels/rootfs.cpio.gz```. The password for the user ```root``` is set to *asd*.

### Manual Build

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

## Kernels generated


## Analyzing Memory with our HyperLink GDB Plugin

Start QEMU (allowing connections from GDB on port 1234):
```
$> qemu-system-x86_64 -enable-kvm -nographic -s -cpu host -m 1g -kernel kernels/base.bzImage -initrd kernels/rootfs.cpio.gz -append 'console=ttyS0 nokaslr'
```

Start some programs or do whatever you want inside the VM. 

Afterward, debug the running VM using GDB. You can omit the vmlinux file in case you are doing a real analysis of an unknown system. However, if you want to verify that RandCompile functions correctly, you might want add the debugging symbols to the GDB session and add the ```nokaslr``` switch to the kernel command line (like shown above).

```
$> gdb -ex 'target remote :1234' kernels/base.vmlinux
```

For an efficient search for the ```swapper/0``` string in memory of QEMU, we refer to the gdb-pt-dump plugin for GDB which we provide as a submodule in our Git.

```
(gdb) source hyperlink-gdb/gdbpt/pt.py
(gdb) pt -ss 'swapper/0'
Found at 0xffff888002614f38 in   0xffff888002411000 : 0x929000 | W:1 X:0 S:1 UC:0 WB:1
Found at 0xffffffff82614f38 in   0xffffffff82411000 : 0x929000 | W:1 X:0 S:1 UC:0 WB:1
```

In a second step, we use the memory address to recover the offset of the ```task_struct->tasks.next``` pointer and to list all running tasks from there on:

```
(gdb) source hyperlink-gdb/hyperlink.py
(gdb) hyperlink-ps 0xffffffff82614f38
Looking for kernel pointers around 0xffff8880026149b8
-9b8 0xffff888002614000: ffff82bdf000007f -> <invalid addr>
-998 0xffff888002614020: ffff8260400001ff -> <invalid addr>
-8d8 0xffff8880026140e0: ffffffff826140e0 -> ffffffff826140e0 [circular len=0, comm const]
-8d0 0xffff8880026140e8: ffffffff826140e0 -> ffffffff826140e0 [circular len=0]
-8b8 0xffff888002614100: ffffffff822ba335 -> 54002f3d454d4f48
-8b0 0xffff888002614108: ffffffff822ba33c -> 6e696c3d4d524554
-798 0xffff888002614220: ffffffff822ba30f -> 622f0074696e692f
-790 0xffff888002614228: ffff88803f6ed68e -> 726c73616b6f6e
-688 0xffff888002614330: ffffffff822ba30f -> 622f0074696e692f
-670 0xffff888002614348: ffffffff8200f0a0 -> 0
-660 0xffff888002614358: ffffffff8264b040 -> 1
-4b8 0xffff888002614500: ffffffff822e0b74 -> 1007366746f6f72
-4a8 0xffff888002614510: ffffffff810008e0 -> 750001d3d7553d80
-490 0xffff888002614528: ffffffff811a9f50 -> bf8b4853fd894855
-478 0xffff888002614540: ffff8880030acab8 -> 0
-468 0xffff888002614550: ffffffff82614550 -> ffffffff82614550 [circular len=0, comm const]
-460 0xffff888002614558: ffffffff82614550 -> ffffffff82614550 [circular len=0]
-3f8 0xffff8880026145c0: ffff88800304a000 -> 1
-3e0 0xffff8880026145d8: ffffffffffffffff -> <invalid addr>
-368 0xffff888002614650: ffffffff8273a2c0 -> 2a
-2c8 0xffff8880026146f0: ffffffff82614580 -> 4000
--Type <RET> for more, q to quit, c to continue without paging--
-288 0xffff888002614730: ffffffff82614580 -> 4000
-280 0xffff888002614738: ffffffff8273a740 -> 0
-268 0xffff888002614750: ffffffff82614750 -> ffffffff82614750 [circular len=0, comm const]
-260 0xffff888002614758: ffffffff82614750 -> ffffffff82614750 [circular len=0]
-1e0 0xffff8880026147d8: ffffffff810dba40 -> 5441554156415741
-168 0xffff888002614850: ffffffff82614ad0 -> 1
-158 0xffff888002614860: ffffffff82614860 -> ffffffff82614860 [circular len=0, comm const]
-150 0xffff888002614868: ffffffff82614860 -> ffffffff82614860 [circular len=0]
-138 0xffff888002614880: ffffffffffffffff -> <invalid addr>
-120 0xffff888002614898: ffffffffffffffff -> <invalid addr>
-108 0xffff8880026148b0: ffffffffffffffff -> <invalid addr>
-0e8 0xffff8880026148d0: ffff8880030c8350 -> ffff8880030c92d0 [circular len=45, comm const]
-0e0 0xffff8880026148d8: ffff88803f85efd0 -> ffffffff826148d0 [circular len=45]
-0c8 0xffff8880026148f0: ffffffff826148f0 -> ffffffff826148f0 [circular len=0, comm const]
-0c0 0xffff8880026148f8: ffffffff826148f0 -> ffffffff826148f0 [circular len=0]
-0b8 0xffff888002614900: ffffffff82614900 -> ffffffff82614900 [circular len=0, comm const]
-0b0 0xffff888002614908: ffffffff82614900 -> ffffffff82614900 [circular len=0]
-090 0xffff888002614928: ffff8880030b0440 -> 0
-078 0xffff888002614940: ffffffff82614940 -> ffffffff82614940 [circular len=0, comm const]
-070 0xffff888002614948: ffffffff82614940 -> ffffffff82614940 [circular len=0]
-068 0xffff888002614950: ffffffff82614950 -> ffffffff82614950 [circular len=0, comm const]
-060 0xffff888002614958: ffffffff82614950 -> ffffffff82614950 [circular len=0]
--Type <RET> for more, q to quit, c to continue without paging--
-050 0xffff888002614968: ffffffff82616dd8 -> ffffffff82614968 [circular len=1]
-048 0xffff888002614970: ffffffff82616dd8 -> ffffffff82614968 [circular len=1]
-038 0xffff888002614980: ffffffff826169e0 -> 0
-018 0xffff8880026149a0: ffffffff82600000 -> 57ac6e9d
0098 0xffff888002614a50: ffffffff82614a50 -> ffffffff82614a50 [circular len=0, comm const]
00a0 0xffff888002614a58: ffffffff82614a50 -> ffffffff82614a50 [circular len=0]
0160 0xffff888002614b18: ffffffff8106e400 -> e9fffffffcc0c748
0190 0xffff888002614b48: ffffffff8264b900 -> 2d
01a0 0xffff888002614b58: ffffffff82399640 -> ffffffff81091b90
01a8 0xffff888002614b60: ffffffff826161c0 -> 100000000
0218 0xffff888002614bd0: ffffffff82614580 -> 4000
0270 0xffff888002614c28: ffffffff82614c28 -> ffffffff82614c28 [circular len=0, comm const]
0278 0xffff888002614c30: ffffffff82614c28 -> ffffffff82614c28 [circular len=0]
0398 0xffff888002614d50: ffff88803e4216c0 -> 0
0428 0xffff888002614de0: ffffffff82d58780 -> ffffffff827320b0 [circular len=1]
0438 0xffff888002614df0: ffffffff8264bb20 -> ffffffff8264b040
0440 0xffff888002614df8: ffffffff8264bb20 -> ffffffff8264b040
0518 0xffff888002614ed0: ffff8880030c83d0 -> ffff8880030c9350 [circular len=2]
0520 0xffff888002614ed8: ffff8880030c9350 -> ffffffff82614ed0 [circular len=2]
0548 0xffff888002614f00: ffffffff82731260 -> ffffffff82735f40 [circular len=2]
0568 0xffff888002614f20: ffffffff82614f20 -> ffffffff82614f20 [circular len=0, comm const]
0570 0xffff888002614f28: ffffffff82614f20 -> ffffffff82614f20 [circular len=0]
--Type <RET> for more, q to quit, c to continue without paging--
0580 0xffff888002614f38: ffffffff82614f38 -> ffffffff82614f38 [circular len=0, comm const]
0588 0xffff888002614f40: ffffffff82614f38 -> ffffffff82614f38 [circular len=0]
0598 0xffff888002614f50: ffffffff82614f50 -> ffffffff82614f50 [circular len=0, comm const]
05a0 0xffff888002614f58: ffffffff82614f50 -> ffffffff82614f50 [circular len=0]
05b0 0xffff888002614f68: ffffffff8264b7c0 -> 1
05c0 0xffff888002614f78: ffffffff82614f78 -> ffffffff82614f78 [circular len=0, comm const]
0618 0xffff888002614fd0: ffffffff82614fd0 -> ffffffff82614fd0 [circular len=0, comm const]
0640 0xffff888002614ff8: ffffffff8109e4f0 -> 415641ff89495741
0648 0xffff888002615000: ffff88803e41dcc0 -> ffff88803e41dc80
0658 0xffff888002615010: ffffffff82615010 -> ffffffff82615010 [circular len=0, comm const]
0680 0xffff888002615038: ffffffff8109ed50 -> 5441554156415741
0688 0xffff888002615040: ffff88803e41dcc0 -> ffff88803e41dc80
0698 0xffff888002615050: ffffffff82614f78 -> ffffffff82614f78 [circular len=0]
0720 0xffff8880026150d8: ffffffff82603e28 -> fffb9501
Guessed offset of task_struct->tasks.next: -0xe8
Guessed PID offset: -0x2d8

=== Process List ===
0xffff8880026148d0 PID: 0, Comm: swapper/0
0xffff8880030c8350 PID: 1, Comm: init
0xffff8880030c92d0 PID: 2, Comm: kthreadd
0xffff8880030ca250 PID: 3, Comm: rcu_gp
--Type <RET> for more, q to quit, c to continue without paging--
0xffff8880030cb1d0 PID: 4, Comm: rcu_par_gp
0xffff8880030cc150 PID: 5, Comm: netns
0xffff8880030cd0d0 PID: 6, Comm: kworker/0:0
0xffff8880030ce050 PID: 7, Comm: kworker/0:0H
0xffff8880030cefd0 PID: 8, Comm: kworker/u2:0
0xffff888003090350 PID: 9, Comm: kworker/0:1H
0xffff8880030912d0 PID: 10, Comm: mm_percpu_wq
0xffff888003092250 PID: 11, Comm: ksoftirqd/0
0xffff8880030931d0 PID: 12, Comm: rcu_sched
0xffff888003094150 PID: 13, Comm: migration/0
0xffff8880030950d0 PID: 14, Comm: cpuhp/0
0xffff888003096050 PID: 15, Comm: kdevtmpfs
0xffff888003096fd0 PID: 16, Comm: inet_frag_wq
0xffff888003118350 PID: 17, Comm: kauditd
0xffff8880031192d0 PID: 18, Comm: oom_reaper
0xffff88800311a250 PID: 19, Comm: writeback
0xffff88800311b1d0 PID: 20, Comm: kcompactd0
0xffff8880032292d0 PID: 42, Comm: kblockd
0xffff88800322a250 PID: 43, Comm: blkcg_punt_bio
0xffff888003228350 PID: 44, Comm: kworker/0:1
0xffff88800322b1d0 PID: 45, Comm: ata_sff
0xffff88800322c150 PID: 46, Comm: md
--Type <RET> for more, q to quit, c to continue without paging--
0xffff88800322d0d0 PID: 47, Comm: rpciod
0xffff88800322e050 PID: 48, Comm: kworker/u3:0
0xffff88800322efd0 PID: 49, Comm: xprtiod
0xffff888003226fd0 PID: 50, Comm: cfg80211
0xffff888003226050 PID: 51, Comm: kworker/u2:1
0xffff8880032250d0 PID: 52, Comm: kswapd0
0xffff888003224150 PID: 53, Comm: nfsiod
0xffff8880032231d0 PID: 55, Comm: acpi_thermal_pm
0xffff888003222250 PID: 56, Comm: kworker/u2:2
0xffff8880032212d0 PID: 57, Comm: scsi_eh_0
0xffff888003220350 PID: 58, Comm: scsi_tmf_0
0xffff888003136fd0 PID: 59, Comm: scsi_eh_1
0xffff888003136050 PID: 60, Comm: scsi_tmf_1
0xffff8880031350d0 PID: 61, Comm: kworker/u2:3
0xffff888003134150 PID: 62, Comm: kworker/0:2
0xffff8880031331d0 PID: 63, Comm: mld
0xffff888003132250 PID: 64, Comm: ipv6_addrconf
0xffff8880031312d0 PID: 86, Comm: syslogd
0xffff88800311e050 PID: 90, Comm: klogd
0xffff88803f85efd0 PID: 109, Comm: sh
0xffffffff826148d0 PID: 0, Comm: swapper/0
```
