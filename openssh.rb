class Openssh < Formula
  desc "OpenBSD freely-licensed SSH connectivity tools"
  homepage "http://www.openssh.com/"
  url "https://ftp.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-7.4p1.tar.gz"
  version "7.4p1"
  sha256 "1b1fc4a14e2024293181924ed24872e6f2e06293f3e8926a376b8aec481f19d1"

  option "with-keychain-support", "Add native OS X Keychain and Launch Daemon support to ssh-agent"
  option "with-libressl", "Build with LibreSSL instead of OpenSSL"

  depends_on "autoconf" => :build if build.with? "keychain-support"
  depends_on "openssl" => :recommended
  depends_on "libressl" => :optional
  depends_on "ldns" => :optional
  depends_on "pkg-config" => :build if build.with? "ldns"

  if build.with? "keychain-support"
    patch do
      url "https://gist.githubusercontent.com/leonklingele/fef82aa5be1fe5939ccdefd438959d67/raw/58f1af28dd10ee840c0b645425cd7528c0bc2700/0001-apple-keychain-integration-other-changes.patch"
      sha256 "a9cb10c6fda5e76f4605f71cceae57953f2a79cd9f06e57de7e897f902f1b375"
    end
  end

  patch do
    url "https://gist.githubusercontent.com/leonklingele/fef82aa5be1fe5939ccdefd438959d67/raw/58f1af28dd10ee840c0b645425cd7528c0bc2700/0002-apple-sandbox-named-external.patch"
    sha256 "0aa0df2377e655b0e4401417c65c41e7f1a075c37ee89c4d0e83adcb7424a08b"
  end

  # Patch for SSH tunnelling issues caused by launchd changes on Yosemite
  patch do
    url "https://gist.githubusercontent.com/leonklingele/fef82aa5be1fe5939ccdefd438959d67/raw/58f1af28dd10ee840c0b645425cd7528c0bc2700/0003-launchd.patch"
    sha256 "ef296fa6812e6af018316b8db461e0c56ead9c3eb47762b6372b37b5e759e4a9"
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
