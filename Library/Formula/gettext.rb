class Gettext < Formula
  desc "GNU internationalization (i18n) and localization (l10n) library"
  homepage "https://www.gnu.org/software/gettext/"
  # audit --strict complained about this URL.
  url "http://ftpmirror.gnu.org/gettext/gettext-0.22.5.tar.lz"
  mirror "https://ftp.gnu.org/gnu/gettext/gettext-0.22.5.tar.lz"
  sha256 "caa44aed29c9b4900f1a401d68f6599a328a3744569484dc95f62081e80ad6cb"
  # switched to the LZip’d version because it’s a lot smaller

  unless MacOS.version <= :leopard  # what Mac OS version would be correct here?
    keg_only :shadowed_by_osx, "OS X provides the BSD gettext library and some software gets confused if both are in the library path."
  end

  option :universal
  # former option to leave out the examples is no longer available in `configure`

  # Fix lang-python-* failures when a traditional French locale
  # https://git.savannah.gnu.org/gitweb/?p=gettext.git;a=patch;h=3c7e67be7d4dab9df362ab19f4f5fa3b9ca0836b
  # Skip the gnulib tests as they have their own set of problems which has nothing to do with what's being built.
  patch :p0, :DATA

  # `class_exec` doesn't exist in Tiger/Leopard stock Ruby.  Ideally, find a workaround
  Pathname.class_exec {
    # binread does not exist in Leopard stock Ruby 1.8.6, and Tigerbrew's
    # cobbled-in version doesn't work, so use this instead
    def b_read(offset = 0, length = self.size)
      self.open('rb') do |f|
        f.pos = offset
        f.read(length)
      end
    end

    def is_bare_mach_o?
      # MH_MAGIC    = 'feedface'
      # MH_MAGIC_64 = 'feedfacf' -- same value with lowest-order bit inverted
      [self.b_read(0,4).unpack('N').first & 0xfffffffe].pack('N').unpack('H8').first == 'feedface'
    end
  }

  def install
    def scour_keg(stash, sub_path)
      s_p = (sub_path == '' ? '' : sub_path + '/')
      Dir["#{prefix}/#{s_p}*"].each do |f|
        pn = Pathname(f)
        spb = s_p + pn.basename
        if pn.directory?
          mkdir "#{stash}/#{spb}"
          scour_keg(stash, spb)
        elsif ((not pn.symlink?) and pn.file? and pn.is_bare_mach_o?)
          cp pn, "#{stash}/#{spb}"
        end
      end
    end

    def merge_mach_o_stashes(arch_dirs, sub_path)
      s_p = (sub_path == '' ? '' : sub_path + '/')
      Dir["#{arch_dirs.first}/#{s_p}*"].each do |f|
        pn = Pathname(f)
        spb = s_p + pn.basename
        if pn.directory?
          merge_mach_o_stashes(arch_dirs, spb)
        else
          system 'lipo', '-create', *Dir["{#{arch_dirs.join(',')}}/#{spb}"],
                         '-output', prefix/spb
        end
      end
    end

    ENV.libxml2

    if build.universal?
      archs = Hardware::CPU.universal_archs
      ENV.permit_arch_flags
    elsif MacOS.prefer_64_bit?
      archs = [Hardware::CPU.arch_64_bit]
    else
      archs = [Hardware::CPU.arch_32_bit]
    end

    dirs = []

    archs.each do |arch|
      if build.universal?
        ENV.append_to_cflags "-arch #{arch}"
        dir = "build-#{arch}"
        dirs << dir
        mkdir dir
      end

      args = %W[
        --disable-dependency-tracking
        --disable-debug
        --prefix=#{prefix}
        --with-included-gettext
        --with-included-libunistring
        --with-emacs
        --with-lispdir=#{share}/emacs/site-lisp/gettext
        --disable-java
        --disable-csharp
        --without-git
        --without-cvs
        --without-xz
      ]
      args << (ARGV.verbose? ? "--disable-silent-rules" : "--enable-silent-rules")

      system './configure', *args
      system 'make'
      system 'make', 'check'
      # install doesn't support multiple make jobs
      ENV.deparallelize do
        system 'make', 'install'
      end

      if build.universal?
        # undo architecture-specific tweak before next run
        ENV.remove_from_cflags "-arch #{arch}"
        scour_keg(dir, '')
        system 'make', 'clean'
      end
    end # archs.each

    merge_mach_o_stashes(dirs, '') if build.universal?
  end # install

  test do
    system "#{bin}/gettext", '--version'
    system "#{bin}/gettext", '--help'
  end
end

__END__
--- gettext-tools/tests/lang-python-1.orig	2023-09-18 21:10:32.000000000 +0100
+++ gettext-tools/tests/lang-python-1	2023-11-30 23:15:43.000000000 +0000
@@ -3,9 +3,10 @@
 
 # Test of gettext facilities in the Python language.
 
-# Note: This test fails with Python 2.3 ... 2.7 when an UTF-8 locale is present.
+# Note: This test fails with Python 2.3 ... 2.7 when an ISO-8859-1 locale is
+# present.
 # It looks like a bug in Python's gettext.py. This here is a quick workaround:
-UTF8_LOCALE_UNSUPPORTED=yes
+ISO8859_LOCALE_UNSUPPORTED=yes
 
 cat <<\EOF > prog1.py
 import gettext
@@ -82,16 +83,16 @@
 
 : ${LOCALE_FR=fr_FR}
 : ${LOCALE_FR_UTF8=fr_FR.UTF-8}
-if test $LOCALE_FR != none; then
-  prepare_locale_ fr $LOCALE_FR
-  LANGUAGE= LC_ALL=$LOCALE_FR python prog1.py > prog.out || Exit 1
-  ${DIFF} prog.ok prog.out || Exit 1
+if test $LOCALE_FR_UTF8 != none; then
+  prepare_locale_ fr $LOCALE_FR_UTF8
+  LANGUAGE= LC_ALL=$LOCALE_FR_UTF8 python prog1.py > prog.out || Exit 1
+  ${DIFF} prog.oku prog.out || Exit 1
 fi
-if test -z "$UTF8_LOCALE_UNSUPPORTED"; then
-  if test $LOCALE_FR_UTF8 != none; then
-    prepare_locale_ fr $LOCALE_FR_UTF8
-    LANGUAGE= LC_ALL=$LOCALE_FR_UTF8 python prog1.py > prog.out || Exit 1
-    ${DIFF} prog.oku prog.out || Exit 1
+if test -z "$ISO8859_LOCALE_UNSUPPORTED"; then
+  if test $LOCALE_FR != none; then
+    prepare_locale_ fr $LOCALE_FR
+    LANGUAGE= LC_ALL=$LOCALE_FR python prog1.py > prog.out || Exit 1
+    ${DIFF} prog.ok prog.out || Exit 1
   fi
   if test $LOCALE_FR = none && test $LOCALE_FR_UTF8 = none; then
     if test -f /usr/bin/localedef; then
@@ -102,11 +103,11 @@
     Exit 77
   fi
 else
-  if test $LOCALE_FR = none; then
+  if test $LOCALE_FR_UTF8 = none; then
     if test -f /usr/bin/localedef; then
-      echo "Skipping test: no traditional french locale is installed"
+      echo "Skipping test: no french Unicode locale is installed"
     else
-      echo "Skipping test: no traditional french locale is supported"
+      echo "Skipping test: no french Unicode locale is supported"
     fi
     Exit 77
   fi
--- gettext-tools/tests/lang-python-2.orig	2023-09-18 21:10:32.000000000 +0100
+++ gettext-tools/tests/lang-python-2	2023-11-30 23:15:43.000000000 +0000
@@ -4,9 +4,10 @@
 # Test of gettext facilities (including plural handling) in the Python
 # language.
 
-# Note: This test fails with Python 2.3 ... 2.7 when an UTF-8 locale is present.
+# Note: This test fails with Python 2.3 ... 2.7 when an ISO-8859-1 locale is
+# present.
 # It looks like a bug in Python's gettext.py. This here is a quick workaround:
-UTF8_LOCALE_UNSUPPORTED=yes
+ISO8859_LOCALE_UNSUPPORTED=yes
 
 cat <<\EOF > prog2.py
 import sys
@@ -103,16 +104,16 @@
 
 : ${LOCALE_FR=fr_FR}
 : ${LOCALE_FR_UTF8=fr_FR.UTF-8}
-if test $LOCALE_FR != none; then
-  prepare_locale_ fr $LOCALE_FR
-  LANGUAGE= LC_ALL=$LOCALE_FR python prog2.py 2 > prog.out || Exit 1
-  ${DIFF} prog.ok prog.out || Exit 1
+if test $LOCALE_FR_UTF8 != none; then
+  prepare_locale_ fr $LOCALE_FR_UTF8
+  LANGUAGE= LC_ALL=$LOCALE_FR_UTF8 python prog2.py 2 > prog.out || Exit 1
+  ${DIFF} prog.oku prog.out || Exit 1
 fi
-if test -z "$UTF8_LOCALE_UNSUPPORTED"; then
-  if test $LOCALE_FR_UTF8 != none; then
-    prepare_locale_ fr $LOCALE_FR_UTF8
-    LANGUAGE= LC_ALL=$LOCALE_FR_UTF8 python prog2.py 2 > prog.out || Exit 1
-    ${DIFF} prog.oku prog.out || Exit 1
+if test -z "$ISO8859_LOCALE_UNSUPPORTED"; then
+  if test $LOCALE_FR != none; then
+    prepare_locale_ fr $LOCALE_FR
+    LANGUAGE= LC_ALL=$LOCALE_FR python prog2.py 2 > prog.out || Exit 1
+    ${DIFF} prog.ok prog.out || Exit 1
   fi
   if test $LOCALE_FR = none && test $LOCALE_FR_UTF8 = none; then
     if test -f /usr/bin/localedef; then
@@ -123,11 +124,11 @@
     Exit 77
   fi
 else
-  if test $LOCALE_FR = none; then
+  if test $LOCALE_FR_UTF8 = none; then
     if test -f /usr/bin/localedef; then
-      echo "Skipping test: no traditional french locale is installed"
+      echo "Skipping test: no french Unicode locale is installed"
     else
-      echo "Skipping test: no traditional french locale is supported"
+      echo "Skipping test: no french Unicode locale is supported"
     fi
     Exit 77
   fi
--- gettext-tools/Makefile.in.orig	2024-04-09 14:16:44.000000000 +0000
+++ gettext-tools/Makefile.in	2024-04-09 14:17:28.000000000 +0000
@@ -3416,7 +3416,7 @@
 top_srcdir = @top_srcdir@
 AUTOMAKE_OPTIONS = 1.5 gnu no-dependencies
 ACLOCAL_AMFLAGS = -I m4 -I ../gettext-runtime/m4 -I ../m4 -I gnulib-m4 -I libgrep/gnulib-m4 -I libgettextpo/gnulib-m4
-SUBDIRS = gnulib-lib libgrep src libgettextpo po its projects styles emacs misc man m4 tests system-tests gnulib-tests examples doc
+SUBDIRS = gnulib-lib libgrep src libgettextpo po its projects styles emacs misc man m4 tests system-tests examples doc
 
 # Allow users to use "gnulib-tool --update".
 
