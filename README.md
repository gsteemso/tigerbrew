Leopardbrew
===========

A fork of [Tigerbrew][tigerbrew], itself a fork of [Homebrew][homebrew], that focusses on universal / 64-bit builds and properly supporting pure Darwin (i.e., non‐OS‐X) installations.  Despite the name, which was only chosen to differentiate it from its ancestor, it still aims for compatibility with Tiger (Darwin 8) systems.

Installation
============

You will first need the newest version of Xcode compatible with your operating system installed. For Tiger that’s [Xcode 2.5, available from Apple here](https://developer.apple.com/download/more/?=xcode%202.5). For Leopard, [Xcode 3.1.4, available from Apple here](https://developer.apple.com/download/more/?=xcode%203.1.4). Both downloads will require an Apple Developer account.

On the computer you’re reading this on, control or right click this link and save it (the option will be something like “Save Link As” or “Download Linked File”, depending on your browser) to disk:

<https://raw.github.com/gsteemso/leopardbrew/go/install>

(It used to be possible to instead use TenFourFox directly from the target machine, but that software is no longer maintained and is now unable to handle most pages on Github.)

Transfer the saved file to your Tiger, Leopard or Darwin machine, along with Xcode.

On the target machine, type `ruby` followed by a space into your terminal prompt, then drag and drop the `install` file onto the same terminal window, and press return.

You’ll also want to make sure that /usr/local/bin and /usr/local/sbin are in your PATH. (Unlike later Mac OS versions, /usr/local/bin isn’t in the default PATH.) If you use bash as your shell, add this line to your ~/.bash_profile:

```sh
export PATH=/usr/local/sbin:/usr/local/bin:$PATH
```

What Packages Are Available?
----------------------------
1. You can [browse the Formula directory on GitHub][formula].
2. Or type `brew search` for a list.
3. Or use `brew desc` to browse packages from the command line.

More Documentation
------------------
`brew help` or `man brew`.  At some point a wiki may be resurrected, but do not hold your breath.

FAQ
---

### How do I switch from Homebrew or Tigerbrew?

Run these commands from your terminal. You must have git installed.

```
cd `brew --repository`
git remote set-url origin https://github.com/gsteemso/leopardbrew.git
git fetch origin
git reset --hard origin/master
```

### Something broke!

Some of the formulae in the repository have been tested, but there are still many that haven't. If something doesn't work, [report a bug][issues] (or submit a [pull request][prs]!) and I'll try to get it working.

Credits
-------

Homebrew is originally by [mxcl][mxcl]. The Tigerbrew fork is by [Misty De Méo][mistydemeo], incorporating some code originally written by @sceaga. This fork is by [Gordon Steemson][gsteemso].

License
-------
Code is under the [BSD 2 Clause (NetBSD) license][license].

[Tigerbrew]:https://github.com/mistydemeo/tigerbrew
[Homebrew]:http://brew.sh
[formula]:https://github.com/gsteemso/leopardbrew/tree/master/Library/Formula
[issues]:https://github.com/gsteemso/leopardbrew/issues
[prs]:https://github.com/gsteemso/leopardbrew/pulls
[mxcl]:http://twitter.com/mxcl
[mistydemeo]:https://github.com/mistydemeo
[gsteemso]:https://github.com/gsteemso
[license]:https://github.com/gsteemso/leopardbrew/blob/master/LICENSE.txt
