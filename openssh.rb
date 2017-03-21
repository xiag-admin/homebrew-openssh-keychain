class Openssh < Formula
  desc "OpenBSD freely-licensed SSH connectivity tools"
  homepage "http://www.openssh.com/"
  url "https://ftp.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-7.5p1.tar.gz"
  version "7.5p1"
  sha256 "9846e3c5fab9f0547400b4d2c017992f914222b3fd1f8eee6c7dc6bc5e59f9f0"

  option "with-keychain-support", "Add native OS X Keychain and Launch Daemon support to ssh-agent"
  option "with-libressl", "Build with LibreSSL instead of OpenSSL"

  depends_on "autoconf" => :build if build.with? "keychain-support"
  depends_on "openssl" => :recommended
  depends_on "libressl" => :optional
  depends_on "ldns" => :optional
  depends_on "pkg-config" => :build if build.with? "ldns"

  if build.with? "keychain-support"
    patch do
      url "https://gist.githubusercontent.com/leonklingele/afdb457f1b378b42bdbfdbc5fd59f55c/raw/5477b573087cf652c868e873b94056622c3a8647/0001-apple-keychain-integration-other-changes.patch"
      sha256 "7fa9c74d04fb4292b3e8ebc7e2588b204b65b3c80d3137c8c93b1e7d20efd464"
    end
  end

  patch do
    url "https://gist.githubusercontent.com/leonklingele/afdb457f1b378b42bdbfdbc5fd59f55c/raw/5477b573087cf652c868e873b94056622c3a8647/0002-apple-sandbox-named-external.patch"
    sha256 "b8c2596d27a931d557e550b756c8477a3acf8de9e1af96188ad5fa83c428f647"
  end

  # Patch for SSH tunnelling issues caused by launchd changes on Yosemite
  patch do
    url "https://gist.githubusercontent.com/leonklingele/afdb457f1b378b42bdbfdbc5fd59f55c/raw/5477b573087cf652c868e873b94056622c3a8647/0003-launchd.patch"
    sha256 "eafbbc0992601539af73fbf3144fdb2fb55154cdef68a1de19cd690597dafb54"
  end

  def install
    system "autoreconf -i" if build.with? "keychain-support"

    if build.with? "keychain-support"
      ENV.append "CPPFLAGS", "-D__APPLE_LAUNCHD__ -D__APPLE_KEYCHAIN__"
      ENV.append "LDFLAGS", "-framework CoreFoundation -framework SecurityFoundation -framework Security"
    end

    ENV.append "CPPFLAGS", "-D__APPLE_SANDBOX_NAMED_EXTERNAL__"

    args = %W[
      --with-libedit
      --with-pam
      --with-kerberos5
      --prefix=#{prefix}
      --sysconfdir=#{etc}/ssh
    ]

    if build.with? "libressl"
      args << "--with-ssl-dir=#{Formula["libressl"].opt_prefix}"
    else
      args << "--with-ssl-dir=#{Formula["openssl"].opt_prefix}"
    end

    args << "--with-ldns" if build.with? "ldns"

    system "./configure", *args
    system "make"
    system "make", "install"
  end

  def caveats
    if build.with? "keychain-support" then <<-EOS.undent
        NOTE: replacing system daemons is unsupported. Proceed at your own risk.

        For complete functionality, please modify:
          /System/Library/LaunchAgents/org.openbsd.ssh-agent.plist

        and change ProgramArguments from
          /usr/bin/ssh-agent
        to
          #{HOMEBREW_PREFIX}/bin/ssh-agent

        You will need to restart or issue the following commands
        for the changes to take effect:

          launchctl unload /System/Library/LaunchAgents/org.openbsd.ssh-agent.plist
          launchctl load /System/Library/LaunchAgents/org.openbsd.ssh-agent.plist

        Finally, add  these lines somewhere to your ~/.bash_profile:
          eval $(ssh-agent)

          function cleanup {
            echo "Killing SSH-Agent"
            kill -9 $SSH_AGENT_PID
          }

          trap cleanup EXIT

        After that, you can start storing private key passwords in
        your OS X Keychain.
      EOS
    end
  end
end
