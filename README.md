# This is likely not the strace you are looking for

# What is this?

This is a hacked up version of strace and its build system that allow it to be
built as a library.  This library can be used to generate correct strace output
based on the data supplied from your application.  This is done by configuring a
bunch of strace's global state and calling a set of decoding and tracing
functions in the correct order.  I'm using this to generate strace output during
an replay execution being handled by [rr](https://github.com/mozilla/rr). 

__If you find this useful, let me know!  If you want to make this less hacky,
I'd be glad to help!__

## Building

Building this version of strace first requires going through the normal strace
build process.

```
./bootstrap
make
```

This will fail because strace's build system (automake) will try to generate a
final executable but I have removed main()'s definition via preprocessor
directives.

Next, you can build the library based on the objects that now exist.

```
make -f othermake libprintstrace.a
```

Note, this library does NOT contain symbols for umovestr() or umoven().  You
will need to implement these in such a way that, when called, they perform their
respective copy operations into strace's provided buffer.  I removed these
symbols because in actual strace they do this using ptrace calls that can't work
in the absence of a usable ptrace handle.

You will need to include the provided strace_defs.h header to use a bunch of the
symbols you'll need.

## Configuration

Some of strace's global state must be configured as follows:

```
// This is also set up by strace.  Needs to be run once
acolumn_spaces = xmalloc(acolumn + 1);
memset(acolumn_spaces, ' ', acolumn);
acolumn_spaces[acolumn] = '\0';
```

This configures a buffer used by strace to space out return values in its
output.  This code must be run once.

```
// Tell strace to be super verbose and filter nothing
qualify("trace=all");
qualify("abbrev=none");
qualify("verbose=all");
qualify("signal=all");
print_pid_pfx = true; // Tell strace to print out the PID information
max_strlen = 65535;
```

The above code configures strace's output for max verbosity (what I needed for
my work).  You could likely change this to meet your needs.  Must be run once.

```
// Data that we need to decode.  We can set this stuff each time
struct tcb tcp;
current_tcp = &tcp;
clear_regs(&tcp); // Unset regs error
tcp._priv_data = NULL; // Must be initialized to null
tcp.curcol = 0;
tcp.outf = stdout;
tcp.pid = 555;
tcp.scno = 5;
// These values go into registers
tcp.u_rval = 5;
tcp.u_arg[0] = <reg val>
tcp.u_arg[1] = <reg val>
tcp.u_arg[2] = <reg val>
tcp.u_arg[3] = <reg val>
tcp.u_arg[4] = <reg val>
tcp.u_arg[5] = <reg val>
```

This configuration must be performed each time you want to output a line of
strace output.  tcp.outf is a FILE\* to which the line should be output.  Pid
and scno are the pid and system call number that should be used in outputting
the line.  The u\_\* values are the registers EAX through EBP in the order
defined by Linux 32-bit system call conventions.


```
res = syscall_entering_decode(&tcp);
// We must save the return value from here
res = syscall_entering_trace(&tcp, 0);
// And pass it in here
syscall_entering_finish(&tcp, res);

// Must have a struct ts allocated even if we don't use it
res = syscall_exiting_decode(&tcp, &ts);
// We must also save the return value here
syscall_exiting_trace(&tcp, NULL, res);
// And pass it in here
syscall_exiting_finish(&tcp);
```

The above calls must be made in exactly this fashion in order to get a line of
strace output to be generated.

## Caveats

My modifications assume a 32-bit Linux system.  There are bits around gathering
registers and values that I had to modify to get things going.  I did not
replicate these modifications in all the places that deal with different
architectures and configurations.  Looking at the modifications I made will give
you an idea of what needs to be done.

strace - the linux syscall tracer
=================================

This is [strace](https://strace.io) -- a diagnostic, debugging and instructional userspace utility with a traditional command-line interface for Linux.  It is used to monitor and tamper with interactions between processes and the Linux kernel, which include system calls, signal deliveries, and changes of process state.  The operation of strace is made possible by the kernel feature known as [ptrace](http://man7.org/linux/man-pages/man2/ptrace.2.html).

strace is released under a Berkeley-style license at the request of Paul Kranenburg; see the file [COPYING](COPYING) for details.

See the file [NEWS](NEWS) for information on what has changed in recent versions.

Please read the file [INSTALL-git](INSTALL-git.md) for installation instructions.

The user discussion and development of strace take place on [the strace mailing list](https://lists.strace.io/mailman/listinfo/strace-devel) -- everyone is welcome to post bug reports, feature requests, comments and patches to strace-devel@lists.strace.io.  The mailing list archives are available at https://lists.strace.io/pipermail/strace-devel/ and other archival sites.

The GIT repository of strace is available at [GitHub](https://github.com/strace/strace/) and [GitLab](https://gitlab.com/strace/strace/).

The latest binary strace packages are available in many repositories, including
[OBS](https://build.opensuse.org/package/show/home:ldv_alt/strace/),
[Fedora rawhide](https://apps.fedoraproject.org/packages/strace), and
[Sisyphus](https://packages.altlinux.org/en/Sisyphus/srpms/strace).

[![Build Status](https://travis-ci.org/strace/strace.svg?branch=master)](https://travis-ci.org/strace/strace) [![Code Coverage](https://codecov.io/github/strace/strace/coverage.svg?branch=master)](https://codecov.io/github/strace/strace?branch=master)
