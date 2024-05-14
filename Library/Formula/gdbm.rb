class Gdbm < Formula
  desc "GNU database manager"
  homepage "https://www.gnu.org/software/gdbm/"
  # audit --strict complains about these URLs
  url "http://ftpmirror.gnu.org/gdbm/gdbm-1.23.tar.gz"
  mirror "https://ftp.gnu.org/gnu/gdbm/gdbm-1.23.tar.gz"
  sha256 "74b1081d21fff13ae4bd7c16e5d6e504a4c26f7cde1dca0d963a484174bbcacd"

  bottle do
    cellar :any
    sha256 "adfa78e136cc5c3cddf6b4d2b953a072eda010d22677d869ec7996d70cbb504f" => :tiger_altivec
  end

  option :universal
  option "with-libgdbm-compat", "Build libgdbm_compat, a compatibility layer which provides UNIX-like dbm and ndbm interfaces."

  if build.with? 'libgdbm-compat'
    keg_only :provided_by_osx, 'libgdbm_compat incorporates a header file that would shadow a system header.'
  end

  depends_on "readline"

  def install
    ENV.universal_binary if build.universal?

    args = %W[
      --disable-dependency-tracking
      --prefix=#{prefix}
    ]
    args << (ARGV.verbose? ? "--disable-silent-rules" : "--enable-silent-rules")
    args << "--enable-libgdbm-compat" if build.with? "libgdbm-compat"

    system "./configure", *args
    system "make", "install"
  end

  test do
    pipe_output("#{bin}/gdbmtool --norc --newdb test", "store 1 2\nquit\n")
    assert File.exist?("test")
    assert_match /2/, pipe_output("#{bin}/gdbmtool --norc test", "fetch 1\nquit\n")
  end
end
