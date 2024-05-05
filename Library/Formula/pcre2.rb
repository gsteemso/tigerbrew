class Pcre2 < Formula
  desc "Perl-compatible regular expressions library with revised API"
  homepage "https://www.pcre.org/"
  url "https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.43/pcre2-10.43.tar.bz2"
  sha256 "e2a53984ff0b07dfdb5ae4486bbb9b21cca8e7df2434096cc9bf1b728c350bcb"

  head do
    url "https://github.com/PCRE2Project/pcre2"

    depends_on "autoconf" => :build
    depends_on "automake" => :build
    depends_on "libtool" => :build
  end

  option :universal

  # Fix JIT support on Mac OSes before 11.0
  # (previous patch for Tiger compatibility now incorporated upstream)
  patch :p0 do
   url "https://raw.githubusercontent.com/macports/macports-ports/master/devel/pcre/files/MAP_JIT.patch"
   sha256 "abbf0ece0c75581d653d4556eee4c5d27ef4505a8a6298f79c7f87f4a72da49d"
  end

  # Fix thread support – uncertain if actually needed but other distros use it
  patch :p0, :DATA

  def install
    ENV.universal_binary if build.universal?
    ENV.deparallelize

    system "./autogen.sh" if build.head?

    args = %W[
      --prefix=#{prefix}
      --disable-dependency-tracking
      --enable-pcre2-16
      --enable-pcre2-32
      --enable-pcre2grep-libz
      --enable-pcre2grep-libbz2
      --enable-pcre2test-libedit
    ]
    args << (build.include?('verbose') ? '--disable-silent-rules' : '--enable-silent-rules')
    # PPC64 JIT is explicitly supported in the package’s source code, but for reasons yet to be
    # determined, fails to build properly under Mac OS 10.5
    args << "--enable-jit" unless Hardware::CPU.ppc? and MacOS.prefer_64_bit?

    system "./configure", *args
    system "make"
    system "make", "check"
    system "make", "install"
  end

  test do
    system bin/"pcre2grep", "regular expression", share/"doc/pcre2/README"
  end
end

__END__
--- configure.orig
+++ configure
@@ -15818,10 +15818,6 @@
 
         ax_pthread_flags="-pthreads pthread -mt -pthread $ax_pthread_flags"
         ;;
-
-        darwin*)
-        ax_pthread_flags="-pthread $ax_pthread_flags"
-        ;;
 esac
 
 if test x"$ax_pthread_ok" = xno; then
