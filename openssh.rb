class Openssh < Formula
  desc "OpenBSD freely-licensed SSH connectivity tools"
  homepage "https://www.openssh.com/"
  url "https://ftp.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-7.8p1.tar.gz"
  mirror "https://mirror.vdms.io/pub/OpenBSD/OpenSSH/portable/openssh-7.8p1.tar.gz"
  version "7.8p1"
  sha256 "1a484bb15152c183bb2514e112aa30dd34138c3cfb032eee5490a66c507144ca"

  option "with-keychain-support", "Add native OS X Keychain and Launch Daemon support to ssh-agent"
  option "with-libressl", "Build with LibreSSL instead of OpenSSL"

  depends_on "autoconf" => :build if build.with? "keychain-support"
  depends_on "openssl" => :recommended
  depends_on "libressl" => :optional
  depends_on "ldns" => :optional
  depends_on "pkg-config" => :build if build.with? "ldns"

  resource "com.openssh.sshd.sb" do
    url "https://gist.githubusercontent.com/leonklingele/01c01e6d9d143fa5b1df8e2354d808e4/raw/273738ffa125857cec5494fe89768ab6e080e0f6/com.openssh.sshd.sb"
    sha256 "a273f86360ea5da3910cfa4c118be931d10904267605cdd4b2055ced3a829774"
  end

  if build.with? "keychain-support"
    patch do
      url "https://gist.githubusercontent.com/leonklingele/01c01e6d9d143fa5b1df8e2354d808e4/raw/273738ffa125857cec5494fe89768ab6e080e0f6/0001-apple-keychain-integration-other-changes.patch"
      sha256 "f8041d6409779e753823ddf7295115240f7978481402aa812df5cd909a4994cc"
    end
  end

  patch do
    url "https://gist.githubusercontent.com/leonklingele/01c01e6d9d143fa5b1df8e2354d808e4/raw/273738ffa125857cec5494fe89768ab6e080e0f6/0002-apple-sandbox-named-external.patch"
    sha256 "184440542077982a737bba1d2a947dbc602686877d20d6f9fc79e25ed0b06494"
  end

  def install
    system "autoreconf", "-i" if build.with? "keychain-support"

    if build.with? "keychain-support"
      ENV.append "CPPFLAGS", "-D__APPLE_LAUNCHD__ -D__APPLE_KEYCHAIN__"
      ENV.append "LDFLAGS", "-framework CoreFoundation -framework SecurityFoundation -framework Security"
    end

    ENV.append "CPPFLAGS", "-D__APPLE_SANDBOX_NAMED_EXTERNAL__"

    # Ensure sandbox profile prefix is correct.
    # We introduce this issue with patching, it's not an upstream bug.
    inreplace "sandbox-darwin.c", "@PREFIX@/share/openssh", etc/"ssh"

    args = %W[
      --with-libedit
      --with-kerberos5
      --prefix=#{prefix}
      --sysconfdir=#{etc}/ssh
      --with-pam
    ]

    args << "--with-ldns" if build.with? "ldns"

    if build.with? "libressl"
      args << "--with-ssl-dir=#{Formula["libressl"].opt_prefix}"
    else
      args << "--with-ssl-dir=#{Formula["openssl"].opt_prefix}"
    end

    system "./configure", *args
    system "make"
    ENV.deparallelize
    system "make", "install"

    # This was removed by upstream with very little announcement and has
    # potential to break scripts, so recreate it for now.
    # Debian have done the same thing.
    bin.install_symlink bin/"ssh" => "slogin"

    buildpath.install resource("com.openssh.sshd.sb")
    (etc/"ssh").install "com.openssh.sshd.sb" => "org.openssh.sshd.sb"
  end

  test do
    assert_match "OpenSSH_", shell_output("#{bin}/ssh -V 2>&1")

    begin
      pid = fork { exec sbin/"sshd", "-D", "-p", "8022" }
      sleep 2
      assert_match "sshd", shell_output("lsof -i :8022")
    ensure
      Process.kill(9, pid)
      Process.wait(pid)
    end
  end
end
