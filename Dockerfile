FROM gcc:11.4-bullseye
RUN apt-get update -y && apt-get install -y git build-essential libelf-dev flex bison bc
RUN mkdir randcompile randcompile/kernels randcompile/source
ADD randfun.patch /home/randcompile/
ADD build-kernel.sh /home/randcompile/

# Checkout an unmodified 5.15.63 kernel.
# Getting it from Git should work for quite a while. If this faults at some day, 5.15 is an LTS release. It should be possible to obtain it from an alternative source... 
RUN git clone git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git --depth 1 --branch v5.15.63 /home/randcompile/source
WORKDIR /home/randcompile/source

# Apply our patch
RUN patch -p1 ../randfun.path

WORKDIR /home/randcompile/
RUN build-kernel.sh
