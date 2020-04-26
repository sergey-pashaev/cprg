# cprg
cprg - Custom Project RipGrep search

This package allows user to setup his own filetype search filters for
projectile-ripgrep and select and run them form convenient ui (via hydra).

# dependencies
* `projectile`
* `ripgrep`
* `hydra`

# TODO: install from MELPA
`M-x package-install RET cprg RET`

# usage
For example one might work on project with a lot of files and one don't want to
grep over all of them each time if one needs only grep over c++ files and not
over some c++ test files, for example. So, one adds search filters in his
config like this:

``` emacs-lisp
(require 'cprg)

(cprg-set-globs "_c_++"    '("*.h" "*.c" "*.cc"))
(cprg-set-globs "_e_lisp"  '("*.el"))
(cprg-set-globs "_t_ests"  '("*test.cc" "*tests.cc"))

(cprg-load-hydra)
```

Now one can run hydra ui with "M-x cprg-hydra" and see that he can add defined
c++ globs to "Include" glob set with 'c' key and test files globs with 't' key.
Once globs in a "Include" set one can move them to "Exclude" set by repeating
appropriate key and remove it from exclude set with one more key press.

Once user setup globs he can press:
* `s` - to search.
* `r` - to reset "Include"/"Exclude" sets.
* `q` - to quit.

# how it looks
![screenshot](https://github.com/sergey-pashaev/cprg/raw/master/img/scr.png)
