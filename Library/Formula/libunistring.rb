class Libunistring < Formula
  desc "C string library for manipulating Unicode strings"
  homepage "https://www.gnu.org/software/libunistring/"
  url "http://ftpmirror.gnu.org/libunistring/libunistring-1.2.tar.gz"
  mirror "https://ftp.gnu.org/gnu/libunistring/libunistring-1.2.tar.gz"
  sha256 "fd6d5662fa706487c48349a758b57bc149ce94ec6c30624ec9fdc473ceabbc8e"

  option :universal

  def install
    ENV.universal_binary if build.universal?

    system "./configure", "--disable-dependency-tracking",
                          "--disable-silent-rules",
                          "--prefix=#{prefix}"
    system "make"
    system "make", "install"
  end
end
