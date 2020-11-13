#!/bin/sh
set -eux
cargo rustc --lib --release -- --emit=llvm-ir
cargo rustc --lib --release -- --emit=llvm-bc
cp target/release/deps/data-sync-*.ll hello.ll
cp target/release/deps/data-sync-*.bc hello.bc
llc-9 hello.bc -march=bpf -filetype=obj -o hello.o

