class Libxml2 < Formula
  desc "GNOME XML library"
  homepage "http://xmlsoft.org"
  url "https://download.gnome.org/sources/libxml2/2.11/libxml2-2.11.6.tar.xz"
  sha256 "c90eee7506764abbe07bb616b82da452529609815aefef423d66ef080eb0c300"

  head do
    url "https://git.gnome.org/browse/libxml2", :using => :git

    depends_on "autoconf" => :build
    depends_on "automake" => :build
    depends_on "libtool" => :build
  end

  option :universal

  depends_on 'icu4c' => :recommended
  depends_on "python" => :optional
  depends_on "python3" if build.with? "python"
  depends_on "xz"
  depends_on "zlib"

  keg_only :provided_by_osx

  def caveats
    if build.with? "python"
      <<-EOS.undent
        The Python installer warns loudly of a failed test.  While the warning is,
        technically, correct, it is misleading – this is a keg-only brew and your
        Python is not _supposed_ to be able to see it without help.

        Put briefly:  Ignore the huge, strident failure message -- the installation
        is, in fact, successful.
      EOS
    end
  end

  def install
    ENV.deparallelize
    ENV.universal_binary if build.universal?
    if build.head?
      inreplace "autogen.sh", "libtoolize", "glibtoolize"
      system "./autogen.sh"
    end

    args = %W[
      --prefix=#{prefix}
      --disable-dependency-tracking
      --with-ftp
      --with-lzma=#{Formula["xz"].opt_prefix}
      --with-zlib=#{Formula["zlib"].opt_prefix}
    ]
    args << '--with-icu' unless build.without? 'icu4c'
    # the package builds the python bindings by default
    args << "--without-python" if build.without? "python"

    system "./configure", *args
    system "make"
    system "make", "check"
    system "make", "install"

    if build.with? "python"
      cd "python" do
        # We need to insert our include dir first
        inreplace "setup.py", "includes_dir = [", "includes_dir = ['#{include}', '#{MacOS.sdk_path}/usr/include',"
        system "python3", "setup.py", "install", "--prefix=#{prefix}"
      end
    end
  end

  test do
    (testpath/"test.c").write <<-EOS.undent
      #include <libxml/tree.h>

      int main()
      {
        xmlDocPtr doc = xmlNewDoc(BAD_CAST "1.0");
        xmlNodePtr root_node = xmlNewNode(NULL, BAD_CAST "root");
        xmlDocSetRootElement(doc, root_node);
        xmlFreeDoc(doc);
        return 0;
      }
    EOS
    args = `#{bin}/xml2-config --cflags --libs`.split
    args += %w[test.c -o test]
    system ENV.cc, *args
    system "./test"
  end
end
