# this is a monkey-patched bit of idiocy to make up for there not being a release tarball, just an
# undifferentiated Git repo
class Rtmpdump < Formula
  desc "Tool and library for downloading RTMP streaming media"
  homepage "https://rtmpdump.mplayerhq.hu"
  head "git://git.ffmpeg.org/rtmpdump"
  version "2.6"

  option :universal

  # Tiger's ld fails with:
  # "common symbols not allowed with MH_DYLIB output format with the -multi_module option"
  depends_on :ld64 if MacOS.version < :leopard
  depends_on "openssl"

# is this still true?  hells if I know
#  fails_with :llvm do
#    build 2336
#    cause "Crashes at runtime"
#  end

  def install
    ENV.universal_binary if build.universal?
    ENV.deparallelize
    system "make", "VERSION=v2.6", "SYS=darwin", "prefix=#{prefix}", "mandir=#{man}", "sbindir=#{bin}", "install"
  end
end
