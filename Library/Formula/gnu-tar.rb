class GnuTar < Formula
  desc "GNU version of the tar archiving utility"
  homepage "https://www.gnu.org/software/tar/"
  url "http://ftpmirror.gnu.org/tar/tar-1.34.tar.xz"
  mirror "https://ftp.gnu.org/gnu/tar/tar-1.34.tar.xz"
  sha256 "63bebd26879c5e1eea4352f0d03c991f966aeb3ddeb3c7445c902568d5411d28"

  bottle do
    sha256 "f57c9b390419b477944bcbf7eaa18ae8bd2dc62007534679843e47cdde8143e1" => :tiger_altivec
  end

  option "with-libiconv", "Build with text encoding support"
  depends_on "libiconv" => :optional
  option "with-self-test", "Run the package’s post-installation tests (currently fails)"

  def caveats; <<-_.undent
      gnu-tar (and its manpage) are installed as "gtar", to avoid collision with the system-
      supplied binary.
    _
  end

  def install
    args = %W[
      --prefix=#{prefix}
      --disable-dependency-tracking
      --disable-year2038
      --mandir=#{man}
      --program-prefix=g
    ]
    args << "--with-libiconv-prefix=#{Formula["libiconv"].opt_prefix}" if build.with? "libiconv"

    system "./configure", *args
    system "make", "install"
    system "make", "installcheck" if build.with? "self-test"
  end

  test do
    (testpath/"test").write("test")
    system "gtar", "-czvf", "test.tar.gz", "test"
    assert_match /test/, shell_output("gtar -xOzf test.tar.gz")
  end
end
