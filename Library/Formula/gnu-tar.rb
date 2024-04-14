class GnuTar < Formula
  desc "GNU version of the tar archiving utility"
  homepage "https://www.gnu.org/software/tar/"
  url "http://ftpmirror.gnu.org/tar/tar-1.34.tar.xz"
  mirror "https://ftp.gnu.org/gnu/tar/tar-1.34.tar.xz"
  sha256 "63bebd26879c5e1eea4352f0d03c991f966aeb3ddeb3c7445c902568d5411d28"

  bottle do
    sha256 "f57c9b390419b477944bcbf7eaa18ae8bd2dc62007534679843e47cdde8143e1" => :tiger_altivec
  end

  option "with-default-names", "Do not prepend 'g' to the binary"
  option "with-libiconv", "Build with text encoding support"
  depends_on "libiconv" => :optional

  def install
    args = %W[
      --prefix=#{prefix}
      --disable-dependency-tracking
      --disable-year2038
      --mandir=#{man}
      --program-prefix=g
    ]
    args << "--with-libiconv-prefix=#{Formula["libiconv"].opt_prefix}" if build.with? "libiconv"
    args << "--program-prefix=g" if build.without? "default-names"

    system "./configure", *args
    system "make", "install"
  end

  def caveats
    if build.without? "default-names" then <<-EOS.undent
      gnu-tar has been installed as "gtar".

      If you really need to use it as "tar", you can add a "gnubin" directory
      to your PATH from your bashrc like:

          PATH="#{opt_libexec}/gnubin:$PATH"
      EOS
    end
  end

  test do
    tar = build.with?("default-names") ? bin/"tar" : bin/"gtar"
    (testpath/"test").write("test")
    system "gtar", "-czvf", "test.tar.gz", "test"
    assert_match /test/, shell_output("gtar -xOzf test.tar.gz")
  end
end
