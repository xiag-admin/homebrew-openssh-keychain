class Openssh < Formula
  desc "OpenBSD freely-licensed SSH connectivity tools"
  homepage "http://www.openssh.com/"
  url "https://ftp.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-7.7p1.tar.gz"
  version "7.7p1"
  sha256 "d73be7e684e99efcd024be15a30bffcbe41b012b2f7b3c9084aed621775e6b8f"

  option "with-keychain-support", "Add native OS X Keychain and Launch Daemon support to ssh-agent"
  option "with-libressl", "Build with LibreSSL instead of OpenSSL"

  depends_on "autoconf" => :build if build.with? "keychain-support"
  depends_on "openssl" => :recommended
  depends_on "libressl" => :optional
  depends_on "ldns" => :optional
  depends_on "pkg-config" => :build if build.with? "ldns"

  if build.with? "keychain-support"
    patch do
      url "https://gist.github.com/leonklingele/076b3a93c26b904313e4c37344624a93/raw/19af1b999ab3f59208e016696126b3b277d49e81/0001-apple-keychain-integration-other-changes.patch"
      sha256 "25931009b1b3a6247b74d292b1accbeb5bdb336dfac43d095a91d97e5a0238b3"
    end
  end

  patch do
    url "https://gist.github.com/leonklingele/076b3a93c26b904313e4c37344624a93/raw/19af1b999ab3f59208e016696126b3b277d49e81/0002-apple-sandbox-named-external.patch"
    sha256 "8944fc5af65bd8fe7c5fd5b8ab46ca113c6bd47886fad7b0e7011af53aea73ff"
  end

  # Patch for SSH tunnelling issues caused by launchd changes on Yosemite
  patch do
    url "https://gist.github.com/leonklingele/076b3a93c26b904313e4c37344624a93/raw/19af1b999ab3f59208e016696126b3b277d49e81/0003-launchd.patch"
    sha256 "af531f3f27b4cfc71e56a4d96ab050bd4212afd5be227d9a6f78552455893103"
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
