class BerkeleyDb4 < Formula
  desc "High performance key/value database"
  homepage "https://www.oracle.com/technology/products/berkeley-db/index.html"
  url "http://download.oracle.com/berkeley-db/db-4.8.30.tar.gz"
  sha256 "e0491a07cdb21fb9aa82773bbbedaeb7639cbd0e7f96147ab46141e0045db72a"

  bottle do
    cellar :any
    sha256 "50bf69bfe5d7e5085d8ed1f2ac60882a7ca5c408489143f092751441dfa11787" => :tiger_altivec
  end

  option :universal

  keg_only "BDB 4.8.30 is provided for software that doesn't compile against newer versions."

  # Fix build under Xcode 4.6
  patch :DATA

  # `class_exec` doesn't exist in Tiger/Leopard stock Ruby.  Ideally, find a workaround
  Pathname.class_exec {
    # binread does not exist in Leopard stock Ruby 1.8.6, and Tigerbrew's
    # cobbled-in version doesn't work, so use this instead
    def b_read(offset = 0, length = self.size)
      self.open('rb') do |f|
        f.pos = offset
        f.read(length)
      end
    end

    def is_bare_mach_o?
      # MH_MAGIC    = 'feedface'
      # MH_MAGIC_64 = 'feedfacf' -- same value with lowest-order bit inverted
      [self.b_read(0,4).unpack('N').first & 0xfffffffe].pack('N').unpack('H8').first == 'feedface'
    end
  }

  def arg_format(arch)
    case arch
      when :x86_64 then 'darwin64-x86_64-cc'
      when :i386   then 'darwin-i386-cc'
      when :ppc    then 'darwin-ppc-cc'
      when :ppc64  then 'darwin64-ppc-cc'
    end
  end

  def install
    def scour_keg(stash, sub_path)
      s_p = (sub_path == '' ? '' : sub_path + '/')
      Dir["#{prefix}/#{s_p}*"].each do |f|
        pn = Pathname(f)
        spb = s_p + pn.basename
        if pn.directory?
          mkdir "#{stash}/#{spb}"
          scour_keg(stash, spb)
        elsif ((not pn.symlink?) and pn.file? and pn.is_bare_mach_o?)
          cp pn, "#{stash}/#{spb}"
        end
      end
    end

    def merge_mach_o_stashes(arch_dirs, sub_path)
      s_p = (sub_path == '' ? '' : sub_path + '/')
      Dir["#{arch_dirs.first}/#{s_p}*"].each do |f|
        pn = Pathname(f)
        spb = s_p + pn.basename
        if pn.directory?
          merge_mach_o_stashes(arch_dirs, spb)
        else
          system 'lipo', '-create', *Dir["{#{arch_dirs.join(',')}}/#{spb}"],
                         '-output', prefix/spb
        end
      end
    end

    # BerkeleyDB dislikes parallel builds
    ENV.deparallelize

    if build.universal?
      ENV.permit_arch_flags
      archs = Hardware::CPU.universal_archs
      dirs = []
    elsif MacOS.prefer_64_bit?
      archs = [Hardware::CPU.arch_64_bit]
    else
      archs = [Hardware::CPU.arch_32_bit]
    end

    archs.each do |arch|
      if build.universal?
        ENV.append_to_cflags "-arch #{arch}"
        dir = "stash-#{arch}"
        mkdir dir
        dirs << dir
      end

      # “debug” is already disabled
      # per the package instructions, “docdir” is supposed to not have a leading “--”
      args = ["--prefix=#{prefix}",
              "docdir=#{doc}",
              "--enable-cxx"]

      # BerkeleyDB requires you to build everything from a build subdirectory
      cd 'build_unix' do
        system "../dist/configure", *args
        system "make"
        system "make", "install"
        if build.universal?
          system 'make', 'clean'
          # undo architecture-specific tweak before next run
          ENV.remove_from_cflags "-arch #{arch}"
          scour_keg("../#{dir}", '')
        end # if build.universal?
      end # cd build_unix do
    end # archs.each do
    merge_mach_o_stashes(dirs, '') if build.universal?
  end # def install
end

__END__
diff --git a/dbinc/atomic.h b/dbinc/atomic.h
index 0034dcc..50b8b74 100644
--- a/dbinc/atomic.h
+++ b/dbinc/atomic.h
@@ -144,7 +144,7 @@ typedef LONG volatile *interlocked_val;
 #define	atomic_inc(env, p)	__atomic_inc(p)
 #define	atomic_dec(env, p)	__atomic_dec(p)
 #define	atomic_compare_exchange(env, p, o, n)	\
-	__atomic_compare_exchange((p), (o), (n))
+	__atomic_compare_exchange_db((p), (o), (n))
 static inline int __atomic_inc(db_atomic_t *p)
 {
 	int	temp;
@@ -176,7 +176,7 @@ static inline int __atomic_dec(db_atomic_t *p)
  * http://gcc.gnu.org/onlinedocs/gcc-4.1.0/gcc/Atomic-Builtins.html
  * which configure could be changed to use.
  */
-static inline int __atomic_compare_exchange(
+static inline int __atomic_compare_exchange_db(
 	db_atomic_t *p, atomic_value_t oldval, atomic_value_t newval)
 {
 	atomic_value_t was;
