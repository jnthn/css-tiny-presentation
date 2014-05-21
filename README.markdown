# Learning by Porting a Perl 5 module to Perl 6

This repository contains the source for the above presentation.

* `presentation` contains the actual presentation; open index.html to view it
* `Tiny.pm` is the module that was being ported
* `tools/codestory.pl` is the tool used to build most of the slides

All of the commits in the repository - with the exception of those that are
marked `[meta]`, tell the "story" of porting the module. In fact, you can see
a text version of the presentation with something like:

    git log --reverse -p --grep="^[^[][^m][^e][^t][^a]"
