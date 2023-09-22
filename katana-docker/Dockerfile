FROM debian:bookworm

RUN apt-get update -y && apt-get -y install build-essential git python3 python3-pip python3-venv wget default-jre-headless default-jdk-headless unzip
RUN git clone https://github.com/tum-itsec/katana.git /katana

ENV VIRTUAL_ENV=/katana/env
RUN python3 -m venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

RUN wget https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_10.0.4_build/ghidra_10.0.4_PUBLIC_20210928.zip
RUN unzip ghidra_10.0.4_PUBLIC_20210928.zip
RUN ln -s /ghidra_10.0.4_PUBLIC/support/analyzeHeadless /bin/ghidra-analyzeHeadless

RUN pip install pyelftools hexdump cffi unicorn capstone sympy numpy
WORKDIR /katana
COPY db/ /katana/db/
COPY kallsyms_finder.py .
COPY katana.patch .
RUN git apply katana.patch
RUN make

