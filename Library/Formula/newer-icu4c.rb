class NewerIcu4c < Formula
  desc "C and C++ libraries for Unicode and globalization"
  homepage "https://icu.unicode.org/"
  url "https://github.com/unicode-org/icu/releases/download/release-58-3/icu4c-58_3-src.tgz"
  version "58.3"
  sha256 "2680f3c547cd26cba1d7ebd819cd336ff92cf444a270e195fd3b10bfdf22276c"

  keg_only :provided_by_osx, "OS X provides libicucore.dylib (but nothing else)."

  option :cxx11
  option :universal

  # build tries to pass -compatibility_version to ld, which Tiger's ld can't grok
  depends_on :ld64 if MacOS.version < :leopard

  # These are nearly identical patches as were submitted upstream regarding ICU4C 55.1.
  patch :p0, :DATA

  def install
    ENV.universal_binary if build.universal?

    # Tiger's libtool chokes if it's passed -w
    ENV.enable_warnings if MacOS.version < :leopard

    args = %W[
      --prefix=#{prefix}
      --disable-dependency-tracking
      --disable-samples
      --enable-static
      --with-data-packaging=archive
    ]
    # "data-packaging=archive" per recommendations in the package for building a system library

    args << "--with-library-bits=64" if MacOS.prefer_64_bit?

    # Per the instructions in the package, when building a system library these should be set:
    ENV["CPPFLAGS"] = "-DU_CHARSET_IS_UTF8=1 -DU_DISABLE_RENAMING=1"
    # Some of those could also be done by arguments to runConfigureICU, but that method elicits
    # irritating and unhelpful usage warnings.

    cd "source" do
      system "./runConfigureICU", "MacOSX", *args
      system "make"
      system "make", "check"
      system "make", "install"
    end

    # Per the instructions in the package:  Ideally, the C++-specific header files – which are not
    # distinctively named, but in many cases contain a comment that includes “\brief C++ API” –
    # ought to not be installed when the rest of them are.  Don't know how to arrange that except
    # by individually deleting members of a hand-assembled list from `include`.
    cxxheaders = %w[
      layout/LayoutEngine.h
      layout/LEFontInstance.h
      layout/LEGlyphFilter.h
      layout/LEGlyphStorage.h
      layout/LEInsertionList.h
      layout/LELanguages.h
      layout/LEScripts.h
      layout/LESwaps.h
      layout/LETableReference.h
      layout/ParagraphLayout.h
      layout/RunArrays.h
      unicode/alphaindex.h
      unicode/appendable.h
      unicode/basictz.h
      unicode/brkiter.h
      unicode/bytestream.h
      unicode/bytestrie.h
      unicode/bytestriebuilder.h
      unicode/calendar.h
      unicode/caniter.h
      unicode/chariter.h
      unicode/choicfmt.h
      unicode/coleitr.h
      unicode/coll.h
      unicode/compactdecimalformat.h
      unicode/curramt.h
      unicode/currpinf.h
      unicode/currunit.h
      unicode/datefmt.h
      unicode/dbbi.h
      unicode/dcfmtsym.h
      unicode/decimfmt.h
      unicode/dtfmtsym.h
      unicode/dtintrv.h
      unicode/dtitvfmt.h
      unicode/dtitvinf.h
      unicode/dtptngen.h
      unicode/dtrule.h
      unicode/enumset.h
      unicode/errorcode.h
      unicode/fieldpos.h
      unicode/filteredbrk.h
      unicode/fmtable.h
      unicode/format.h
      unicode/fpositer.h
      unicode/gender.h
      unicode/gregocal.h
      unicode/idna.h
      unicode/listformatter.h
      unicode/localpointer.h
      unicode/locdspnm.h
      unicode/locid.h
      unicode/measfmt.h
      unicode/measunit.h
      unicode/measure.h
      unicode/messagepattern.h
      unicode/msgfmt.h
      unicode/normalizer2.h
      unicode/normlzr.h
      unicode/numfmt.h
      unicode/numsys.h
      unicode/parsepos.h
      unicode/plurfmt.h
      unicode/plurrule.h
      unicode/rbbi.h
      unicode/rbnf.h
      unicode/rbtz.h
      unicode/regex.h
      unicode/region.h
      unicode/reldatefmt.h
      unicode/rep.h
      unicode/resbund.h
      unicode/schriter.h
      unicode/scientificnumberformatter.h
      unicode/search.h
      unicode/selfmt.h
      unicode/simpletz.h
      unicode/smpdtfmt.h
      unicode/sortkey.h
      unicode/std_string.h
      unicode/strenum.h
      unicode/stringpiece.h
      unicode/stringtriebuilder.h
      unicode/stsearch.h
      unicode/symtable.h
      unicode/tblcoll.h
      unicode/timezone.h
      unicode/tmunit.h
      unicode/tmutamt.h
      unicode/tmutfmt.h
      unicode/translit.h
      unicode/tzfmt.h
      unicode/tznames.h
      unicode/tzrule.h
      unicode/tztrans.h
      unicode/ucharstrie.h
      unicode/ucharstriebuilder.h
      unicode/uchriter.h
      unicode/unifilt.h
      unicode/unifunct.h
      unicode/unimatch.h
      unicode/unirepl.h
      unicode/uniset.h
      unicode/unistr.h
      unicode/uobject.h
      unicode/usetiter.h
      unicode/ustream.h
      unicode/vtzone.h
    ]
    oh1 "deleting unsafe C++ header files"
    cd include do
      File.delete(*cxxheaders)
    end
  end

  def post_install
    # The generated dylibs unpredictably refer to some or all of their required libraries using the
    # "@loader_path" syntax, which ld refuses to recognize even though it wrote them that way.  Not
    # even Tigerbrew’s newer ld64 works.  Work around this by editing any such link names:
    oh1 "verifying that dynamic libraries are linked correctly"
    Dir["#{opt_lib}/*.#{version}.dylib"].each do |l|
      FileUtils::chmod "a+w", l
      `#{OS::Mac.otool.to_s} -L #{l}`.lines.select { |s|
        s =~ /\@loader_path/
      }.map { |s|
        s.match(/\@loader_path\S+/)
      }.each do |n|
        system OS::Mac.install_name_tool.to_s, "-change", n, n.to_s.sub("@loader_path", opt_lib), l
      end
      FileUtils::chmod "a-w", l
    end
  end

  test do
    system "#{bin}/gendict", "--uchars", "/usr/share/dict/words", "dict"
  end
end

__END__
--- source/common/putil.cpp.old           2024-01-11 15:21:48.000000000 -0800
+++ source/common/putil.cpp               2024-01-11 15:24:06.000000000 -0800
@@ -117,6 +117,13 @@
 #endif
 
 /*
+ * Mac OS X 10.4 doesn't use its localtime_r() declaration in <time.h> if either _ANSI_SOURCE or _POSIX_C_SOURCE is #defined.
+ */
+#if defined(U_TZNAME) && U_PLATFORM_IS_DARWIN_BASED && (defined(_ANSI_SOURCE) || defined(_POSIX_C_SOURCE))
+U_CFUNC struct tm *localtime_r(const time_t *, struct tm *);
+#endif
+
+/*
  * Only include langinfo.h if we have a way to get the codeset. If we later
  * depend on more feature, we can test on U_HAVE_NL_LANGINFO.
  *
--- source/tools/toolutil/pkg_genc.c.old  2024-01-11 16:29:38.000000000 -0800
+++ source/tools/toolutil/pkg_genc.c      2024-01-11 16:31:15.000000000 -0800
@@ -113,13 +113,13 @@
     int8_t      hexType; /* HEX_0X or HEX_0h */
 } assemblyHeader[] = {
     /* For gcc assemblers, the meaning of .align changes depending on the */
-    /* hardware, so we use .balign 16 which always means 16 bytes. */
+    /* hardware, so we use .p2align 4 which always means 16 bytes. */
     /* https://sourceware.org/binutils/docs/as/Pseudo-Ops.html */
     {"gcc",
         ".globl %s\n"
         "\t.section .note.GNU-stack,\"\",%%progbits\n"
         "\t.section .rodata\n"
-        "\t.balign 16\n"
+        "\t.p2align 4\n"
         "#ifdef U_HIDE_DATA_SYMBOL\n"
         "\t.hidden %s\n"
         "#endif\n"
@@ -137,7 +137,7 @@
         "#endif\n"
         "\t.data\n"
         "\t.const\n"
-        "\t.balign 16\n"
+        "\t.p2align 4\n"
         "_%s:\n\n",
 
         ".long ","",HEX_0X
@@ -145,7 +145,7 @@
     {"gcc-cygwin",
         ".globl _%s\n"
         "\t.section .rodata\n"
-        "\t.balign 16\n"
+        "\t.p2align 4\n"
         "_%s:\n\n",
 
         ".long ","",HEX_0X
@@ -153,7 +153,7 @@
     {"gcc-mingw64",
         ".globl %s\n"
         "\t.section .rodata\n"
-        "\t.balign 16\n"
+        "\t.p2align 4\n"
         "%s:\n\n",
 
         ".long ","",HEX_0X
