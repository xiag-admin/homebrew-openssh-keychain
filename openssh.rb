class Openssh < Formula
  desc "OpenBSD freely-licensed SSH connectivity tools"
  homepage "http://www.openssh.com/"
  url "http://ftp.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-6.9p1.tar.gz"
  version "6.9p1"
  sha256 "6e074df538f357d440be6cf93dc581a21f22d39e236f217fcd8eacbb6c896cfe"

  option "with-keychain-support", "Add native OS X Keychain and Launch Daemon support to ssh-agent"
  option "with-libressl", "Build with LibreSSL instead of OpenSSL"

  depends_on "autoconf" => :build if build.with? "keychain-support"
  depends_on "openssl" => :recommended
  depends_on "libressl" => :optional
  depends_on "ldns" => :optional
  depends_on "pkg-config" => :build if build.with? "ldns"

  if build.with? "keychain-support"
    patch do
      url "https://trac.macports.org/export/138647/trunk/dports/net/openssh/files/0002-Apple-keychain-integration-other-changes.patch"
      sha256 "a707f34c9c639ea5963d5040bee0e543cb87e663c0f525933258f4c0e4290acb"
    end
  end

  patch do
    url "https://gist.githubusercontent.com/jacknagel/e4d68a979dca7f968bdb/raw/f07f00f9d5e4eafcba42cc0be44a47b6e1a8dd2a/sandbox.diff"
    sha256 "82c287053eed12ce064f0b180eac2ae995a2b97c6cc38ad1bdd7626016204205"
  end

  # Patch for SSH tunnelling issues caused by launchd changes on Yosemite
  patch do
    url "https://trac.macports.org/export/138238/trunk/dports/net/openssh/files/launchd.patch"
    sha256 "012ee24bf0265dedd5bfd2745cf8262c3240a6d70edcd555e5b35f99ed070590"
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
