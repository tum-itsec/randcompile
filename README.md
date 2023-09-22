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

After a sucessfull build you should find the following files in the ```kernels/``` folder:

- ```base.{bzImage|vmlinux}```: An unpatched 5.15 kernel. The vmlinux ELF file contains debugging symbols (i.e. for closer inspection in GDB).
- ```base_ftrace.{bzImage|vmlinux```: An unpatched 5.15 kernel with Ftrace enabled
- ```forensic_hardening.{bzImage|vmlinux}```: A kernel without randomized arguments, no externalized printk format strings, but pointer encryption for the ```task_struct.tasks.{next|prev}``` pointers and string encryption of ```tasks_struct.comm```. This should defeat/confuse tools like Fossil (only the task listing!) and HyperLink/TrustZone Rootkit.
- ```nobogus.{bzImage|vmlinux}```: Forensic_hardening + Parameter Order Randomization applied on all but blacklisted kernel functions.
- ```bogusargs.{bzImage|vmlinux}```: nobogus + Additional bogus arguments are inserted in case a function has less then 6 arguments.
- ```bogusmem.{bzImage|vmlinux}```: bogusargs + Bogus arguments are filled with artifical memory accesses.

## Analyzing Memory with our HyperLink GDB Plugin

Start QEMU (allowing connections from GDB on port 1234):
```
$> qemu-system-x86_64 -enable-kvm -nographic -s -cpu host -m 1g -kernel kernels/base.bzImage -initrd kernels/rootfs.cpio.gz -append 'console=ttyS0 nokaslr'
```

Start some programs or do whatever you want inside the VM. 

Afterward, debug the running VM using GDB. You can omit the vmlinux file in case you are doing a real analysis of an unknown system. However, if you want to verify that RandCompile functions correctly, you might want add the debugging symbols to the GDB session and add the ```nokaslr``` switch to the kernel command line (like shown above). We used GDB version 13.1 for our experiments. However, we haven't experienced incompatibilites with other versions of GDB so far.

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
[...]
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
[...]
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
[...]
0xffff8880031350d0 PID: 61, Comm: kworker/u2:3
0xffff888003134150 PID: 62, Comm: kworker/0:2
0xffff8880031331d0 PID: 63, Comm: mld
0xffff888003132250 PID: 64, Comm: ipv6_addrconf
0xffff8880031312d0 PID: 86, Comm: syslogd
0xffff88800311e050 PID: 90, Comm: klogd
0xffff88803f85efd0 PID: 109, Comm: sh
0xffffffff826148d0 PID: 0, Comm: swapper/0
```

## Analyzing Memory with Katana

First, build our docker image containing the Katana Forensic Framework:

```
$> cd katana-docker && docker build -t randcompile-katana .
```

In contrast to our reimplementation of HyperLink, Katana works on offline memory dumps that need to be provided as Core-Files in ELF format. You can create these dumps using the QEMU Monitor Mode command ```dump-guest-memory <filename>``` (we will use ```base_ftrace.core``` as filename here). Launch the VM you want to analyze using Katana and issue a dump-guest-memory command. In case, you are using the ```-nograpic``` command line switch (as done above), you can enter monitor mode using Ctrl-A C. You can leave QEMU nographic mode anytime using Ctrl-A X.

#### Recover symbols: Adapted way (recommended, works with all kernels)

*Please Note: Katana's kallsysms recovery mechanism currently only supports to analyze kernels that have the ftrace/kprobes feature enabled!*  To support all of our kernels above, we adapted the ```kallsyms_finder.py``` from the https://github.com/marin-m/vmlinux-to-elf project.

Create an empty symtab file for the core file (this is not a problem, as all information of the symtab will likewise be contained in the kallsyms information) and call our adapted ```kallsyms_finder.py``` script afterward:

```
$> touch base_ftrace.core-symtab
$> docker run --rm -v $(pwd):/mnt -it randcompile-katana python3 kallsyms_finder.py /mnt/base_ftrace.core
```

#### Alternative way to recover symbols (traditional Katana way; should not be necessary)

Let Katana recover all function starts for analysis in the memory dump:
```
$> docker run --rm -v $(pwd):/mnt -it randcompile-katana ./search-any-symtab.sh /mnt/base_ftrace.core
```

Next, let Katana augment the symtab symbols with the symbols from the kallsyms mechanism:

```
$> docker run --rm -v $(pwd):/mnt -it randcompile-katana python3 emu_kallsyms_x64.py /mnt/base_ftrace.core
```

#### Actual Field Offset Recovery

Finally, let Katana perfom the actual analysis and recover the field offsets of all structures in the Linux kernel. *Note: This will take some time. Do not get irritated by the "missing delay slot instruction" messages. They do not indicate a Bug on x86-64*:

```
$> docker run --rm -v $(pwd):/mnt -it randcompile-katana evaluation/recover-offsets-from-dump.sh /mnt/base_ftrace.core db/fields.v5.15.5-def.txt db/structinfo.v5.15.5-def.json
```

This analysis process of Katana will place a ```<filename>-layout-processed``` file into the same directory as the core file being analyzed. It contains all offsets it could deduct from the text segment of the kernel in the respective memory dump. The results are not aggregated, so every *vote* for a field can be extracted of the field. For example, *votes* for fields inside the ```task_struct``` can be filtered out of the file using the ```jq``` utility:

```
$> jq '.reconstructed.task_struct.[] | select(.[0]=="comm")' < base_ftrace.core-layout-processed
``` 

Afterward, we can execute the different information extraction plugins of Katana. We used for our research the following four plugins:

*List kernel modules (the list is empty as the test kernel does not load any modules):*
```
$> docker run --rm -v $(pwd):/mnt -it randcompile-katana python3 list_modules.py -s db/structinfo.v5.15.5-def.json /mnt/base_ftrace.core 

Extracted offsets:
    module->list.next: 0x88
    module->name:      0x260

Module struct @ 0xffffffff95550f58 (
```

*List running processes (Task Listing):*
```
$> docker run --rm -v $(pwd):/mnt -it randcompile-katana python3 list_procs.py -s db/structinfo.v5.15.5-def.json /mnt/base_ftrace.core

Extracted offsets:
    task_struct->tasks.next: 0x798
    task_struct->state:      0x18
    task_struct->pid:        0x678
    task_struct->comm:       0x878
    task_struct->mm:         0x8b8
    mm_struct->pgd:          0x230

Attributes found, skipping for now

    task_struct->cred:       0xa08
    cred->uid                0x08

0xffffffff95414940
PID: 0 (swapper/0       ) State: 0x0 MM 0x0 UID 0x00
Task struct @ 0xffffffff95414940 CR3 (0x0000000000000000)
0xffff93b601218000
PID: 1 (init            ) State: 0x1 MM 0xffff93b601230440 UID 0x00
Task struct @ 0xffff93b601218000 CR3 (0xffff93b60104c000          0x104c000)
0xffff93b601218fc0
PID: 2 (kthreadd        ) State: 0x1 MM 0x0 UID 0x00
Task struct @ 0xffff93b601218fc0 CR3 (0x0000000000000000)
0xffff93b601219f80
PID: 3 (rcu_gp          ) State: 0x402 MM 0x0 UID 0x00
Task struct @ 0xffff93b601219f80 CR3 (0x0000000000000000)
0xffff93b60121af40
PID: 4 (rcu_par_gp      ) State: 0x402 MM 0x0 UID 0x00
Task struct @ 0xffff93b60121af40 CR3 (0x0000000000000000)
0xffff93b60121bf00
PID: 5 (netns           ) State: 0x402 MM 0x0 UID 0x00
Task struct @ 0xffff93b60121bf00 CR3 (0x0000000000000000)
0xffff93b60121cec0
PID: 6 (kworker/0:0     ) State: 0x402 MM 0x0 UID 0x00
Task struct @ 0xffff93b60121cec0 CR3 (0x0000000000000000)
0xffff93b60121de80
[...]
```

*List opened files of running processes:*
```
$> docker run --rm -v $(pwd):/mnt -it randcompile-katana python3 list_files.py -s db/structinfo.v5.15.5-def.json /mnt/base_ftrace.core
```

*Extract the Dmesg Log:*
```
$> docker run --rm -v $(pwd):/mnt -it randcompile-katana python3 extract_dmesg.py -s db/structinfo.v5.15.5-def.json /mnt/base_ftrace.core
```


## Performance Evaluation

To reproduce our performance evaluation, execute the ```./testproc.sh``` script (part of the ```buildroot-overlay``` folder and, therefore, also part of the created initrd) 10 times for a given test kernel. Afterward, you need to copy and paste the output of the ```./testproc.sh``` runs from QEMU into a text file and place it inside the ```results``` folder. Our analysis script to generate the charts (```analyze_results.py```) will normalize the results by using the results file called ```base```.

*Please Note:* Our measurements for *Signal handler installation* and *Protection fault* were within the general 1-3% overhead range and we, therefore, intentionally removed them to save space in the paper.