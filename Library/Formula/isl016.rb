class Isl016 < Formula
  desc "Integer Set Library for the polyhedral model"
  homepage "https://libisl.sourceforge.io"
  # Track gcc infrastructure releases.
  url "https://libisl.sourceforge.io/isl-0.16.1.tar.bz2"
  mirror "https://gcc.gnu.org/pub/gcc/infrastructure/isl-0.16.1.tar.bz2"
  sha256 '412538bb65c799ac98e17e8cfcdacbb257a57362acfaaff254b0fcae970126d2'

  keg_only "Conflicts with isl in main repository."

  depends_on "gmp"

  def install
    system "./configure", "--disable-dependency-tracking",
                          "--disable-silent-rules",
                          "--prefix=#{prefix}",
                          "--with-gmp=system",
                          "--with-gmp-prefix=#{Formula["gmp"].opt_prefix}"
    system "make"
    system "make", "install"
    (share/"gdb/auto-load").install Dir["#{lib}/*-gdb.py"]
  end

  test do
    (testpath/"test.c").write <<-EOS.undent
      #include <isl/ctx.h>

      int main()
      {
        isl_ctx* ctx = isl_ctx_alloc();
        isl_ctx_free(ctx);
        return 0;
      }
    EOS
    system ENV.cc, "test.c", "-I#{include}", "-L#{lib}", "-lisl", "-o", "test"
    system "./test"
  end
end
