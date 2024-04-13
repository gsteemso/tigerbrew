class Libpsl < Formula
  desc "C library for the Public Suffix List"
  homepage "rockdaboot.github.io/libpsl"
  url "https://github.com/rockdaboot/libpsl/archive/refs/tags/0.21.5.tar.gz"
  version "0.21.5"
  sha256 "d6717685a5f221403041907cca98ae9f72aef163b9d813d40d417c2663373a32"

  def install
    # ENV.deparallelize  # if your formula fails when building in parallel

    system "./configure", "--disable-debug",
                          "--disable-dependency-tracking",
                          "--disable-silent-rules",
                          "--prefix=#{prefix}"
    system "make"
    system "make", "check"
    system "make", "install"
  end

  test do
    # `test do` will create, run in and delete a temporary directory.
    #
    # This test will fail and we won't accept that! It's enough to just replace
    # "false" with the main program this formula installs, but it'd be nice if you
    # were more thorough. Run the test with `brew test libpsl`. Options passed
    # to `brew install` such as `--HEAD` also need to be provided to `brew test`.
    #
    # The installed folder is not in the path, so use the entire path to any
    # executables being tested: `system "#{bin}/program", "do", "something"`.
    system "false"
  end
end
