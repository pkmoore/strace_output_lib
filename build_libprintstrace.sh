#!/bin/bash

#./bootstrap
# This always fails at the end but we need the objects in place for the next
# make
make clean
make CFLAGS=-DLIBPRINTSTRACE_COMPILE -j2 || true
make -f othermake libprintstrace.a

