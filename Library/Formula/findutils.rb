class Findutils < Formula
  desc "Collection of GNU find, xargs, and locate"
  homepage "https://www.gnu.org/software/findutils/"
  url "http://ftpmirror.gnu.org/findutils/findutils-4.9.0.tar.xz"
  mirror "https://ftp.gnu.org/gnu/findutils/findutils-4.9.0.tar.xz"
  sha256 "a2bfb8c09d436770edc59f50fa483e785b161a3b7b9d547573cb08065fd462fe"

  bottle do
    sha256 "9a4f2d8a09718df3da29ba5bdca5eb4c92cf28b00163966bea7ccd005c7188db" => :tiger_altivec
  end

  def caveats; <<-EOS.undent
      All commands (and their manpages) are installed with a leading "g" on their names, because
      Mac OS X already includes commands with most of the normal names.  The sole exception, the
      realpath command (with its manpage), is also made available by its normal name.
    EOS
  end

  def install
    args = %W[
      --prefix=#{prefix}
      --disable-dependency-tracking
      --disable-debug
      --localstatedir=#{var}/locate
      --program-prefix=g
    ]

    system "./configure", *args
    system "make", "install"

    # Symlink non-conflicting binaries
    bin.install_symlink "grealpath" => "realpath"
    man1.install_symlink "grealpath.1" => "realpath.1"
  end

  test do
    system "#{bin}/gfind", "--version"
  end
end
