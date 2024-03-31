class Findutils < Formula
  desc "Collection of GNU find, xargs, and locate"
  homepage "https://www.gnu.org/software/findutils/"
  url "http://ftpmirror.gnu.org/findutils/findutils-4.9.0.tar.xz"
  mirror "https://ftp.gnu.org/gnu/findutils/findutils-4.9.0.tar.xz"
  sha256 "a2bfb8c09d436770edc59f50fa483e785b161a3b7b9d547573cb08065fd462fe"

  bottle do
    sha256 "9a4f2d8a09718df3da29ba5bdca5eb4c92cf28b00163966bea7ccd005c7188db" => :tiger_altivec
  end

<<<<<<< HEAD
  deprecated_option "default-names" => "with-default-names"

  option "with-default-names", "Do not prepend 'g' to the binary"
=======
  def caveats; <<-EOS.undent
      All commands (and their manpages) are installed with a leading "g" on their names, because
      Mac OS X already includes commands with most of the normal names.  The sole exception, the
      realpath command (with its manpage), is also made available by its normal name.
    EOS
  end
>>>>>>> 364b89a2ef (Ongoing efforts to unstupid superenv and to add more --universal builds)

  def install
    args = ["--prefix=#{prefix}",
            "--localstatedir=#{var}/locate",
            "--disable-dependency-tracking"]
    args << (ARGV.verbose? ? '--disable-silent-rules' : '--enable-silent-rules')
    args << "--program-prefix=g" if build.without? "default-names"

    system "./configure", *args
    system "make", "install"
  end

  test do
    _find = (build.with?('default-names') ? 'find' : 'gfind')
    system bin/_find, "--version"
  end
end
