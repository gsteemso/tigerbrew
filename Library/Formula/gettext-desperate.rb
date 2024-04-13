class Pathname
  # binread does not exist in Leopard stock Ruby 1.8.6, and Tigerbrew's
  # cobbled-in version isn't very good at all, so use this instead
  def b_read(offset = 0, length = self.size)
    self.open('rb') do |f|
      f.pos = offset
      f.read(length)
    end
  end

  def is_bare_mach_o?
    def MH_MAGIC ; 'feedface' ; end
   # MH_MAGIC_64 = 'feedfacf' -- same value with lowest-order bit inverted
    (self.b_read(0,4) & 0xfffffffe).unpack('H8').first == MH_MAGIC
  end
end

class GettextDesperate < Formula
  desc "GNU internationalization (i18n) and localization (l10n) library"
  homepage "https://www.gnu.org/software/gettext/"
  url "https://ftpmirror.gnu.org/gettext/gettext-0.22.5.tar.lz"
  mirror "https://ftp.gnu.org/gnu/gettext/gettext-0.22.5.tar.lz"
  sha256 "caa44aed29c9b4900f1a401d68f6599a328a3744569484dc95f62081e80ad6cb"
  # switched to the LZip’d version because it’s a lot smaller

#  bottle do
#    sha256 "c64bb31029e29599442653fe1e0f2216ae8fe144451a0541896f6e367df0018f" => :tiger_altivec
#  end

#  unless MacOS.version <= :leopard  # what Mac OS version would be correct here?
    keg_only :shadowed_by_osx, "OS X provides the BSD gettext library and some software gets confused if both are in the library path."
#  end

  option :universal
  option "with-examples", "Keep example files"

  # Fix lang-python-* failures when a traditional French locale
  # https://git.savannah.gnu.org/gitweb/?p=gettext.git;a=patch;h=3c7e67be7d4dab9df362ab19f4f5fa3b9ca0836b
  # Skip the gnulib tests as they have their own set of problems which has nothing to do with what's being built.
  patch :p0, :DATA

  def install
    build_dir = Dir.getwd

    # fix_library_paths:  A routine to edit any library-reference paths that start with the build
    # directory so they start with the opt_prefix instead.
    # • “target” should be a Pathname object indicating the file which is to have its reference
    #   paths edited.
    def fix_library_paths(target)
      target.chmod "a+w"
      `#{OS::Mac.otool.to_s} -L #{target.to_s}`.lines.select { |s|
        s =~ /#{build_dir}/
      }.map { |s|
        s.match(/#{build_dir}\S+/)
      }.each do |n|
        system OS::Mac.install_name_tool.to_s, '-change', n.to_s, n.to_s.sub(build_dir, opt_prefix.to_s), target.to_s
      end
      target.chmod "a-w"
    end

    # merge_built_stuff:  A routine to scrutinize every item in an architecture-specific build
    # directory.  Mach-O files are installed via the construction of fat binaries, other files are
    # installed via simple copying, and any subdirectories are recursed into.
    # • arch_dirs is an array of strings giving architecture-specific pathnames, which are expected
    #   to have identical lists of contents.
    # • sub_path is a string giving the path within each arch_dir to the directory to be examined.
    def merge_built_stuff(arch_dirs, sub_path)
      Dir["#{arch_dirs.first}/#{sub_path}/*"].each do |f|
        pn = Pathname.new(f)
        bn = pn.basename
        if pn.directory?
          (prefix/sub_path/bn).mkdir
          merge_built_stuff(arch_dirs, "#{sub_path}/#{bn}")
        elsif (pn.file? and pn.is_bare_mach_o?)
          if build.universal?
            # build the fat binaries directly into place
            system 'lipo', '-create', *Dir["{#{arch_dirs.join(',')}}/#{sub_path}/#{bn}"],
                           '-output', (prefix/sub_path/bn).to_s
          else
            (prefix/sub_path).install f
          end
          fix_library_paths prefix/sub_path/bn
        else
          (prefix/sub_path).install f
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
      ENV.append_to_cflags "-arch #{arch}"

      dir = "build-#{arch}"
      dirs << dir
      mkdir dir
      cd dir

      args = %W[
        --disable-dependency-tracking
        --disable-debug
        --prefix=#{prefix}
        --exec-prefix=#{Dir.pwd}
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
      args << (build.with?("examples") ? "--with-examples" : "--without-examples")

      system '../configure', *args
      system 'make'
#      system 'make', 'check'
      ENV.deparallelize # install doesn't support multiple make jobs
      system 'make', 'install'

      # undo architecture-specific tweak before next run
      ENV.remove_from_cflags "-arch #{arch}"

      cd '..'
    end # archs.each

    bin.mkdir
    merge_built_stuff dirs, 'bin'
    lib.mkdir
    merge_built_stuff dirs, 'lib'

    # for some reason there are no dylib aliases.  Probably need those.
    cd lib
    Dir['*.dylib'].each do |dylib|
      shorter = dylib.match(/^(.+).\d+.dylib$/)[1]
      system 'ln', '-s', dylib, "#{shorter}.dylib"
      while shorter = shorter.match(/^(.+)[-.]\d+$/)[1]
        system 'ln', '-s', dylib, "#{shorter}.dylib"
      end
    end

    raise  # debugging aid, lets me check what got moved and whether it was done correctly

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
 
