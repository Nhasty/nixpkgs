{ lib, stdenv, fetchurl, perl, openldap, pam, db, cyrus_sasl, libcap
, expat, libxml2, openssl, pkg-config, systemd
, cppunit
, fetchpatch
}:

stdenv.mkDerivation rec {
  pname = "squid";
  version = "6.7";

  src = fetchurl {
    url = "http://www.squid-cache.org/Versions/v6/${pname}-${version}.tar.xz";
    hash = "sha256-00000000";
  };

  patches = [
    (fetchpatch {
      name = "SQUID-2023_1.patch";
      url = "https://www.squid-cache.org/Versions/v6/SQUID-2023_1.patch";
      hash = "sha256-0000000";
    })
    (fetchpatch {
      name = "SQUID-2023_2.patch";
      url = "https://www.squid-cache.org/Versions/v6/SQUID-2023_2.patch";
      hash = "sha256-000000000";
    })
    (fetchpatch {
      name = "SQUID-2023_2_b.patch";
      url = "https://www.squid-cache.org/Versions/v6/SQUID-2023_2_b.patch";
      hash = "sha256-000000000";
    })
    (fetchpatch {
      name = "SQUID-2023_2_c.patch";
      url = "https://www.squid-cache.org/Versions/v6/SQUID-2023_2_c.patch";
      hash = "sha256-00000000";
    })
    (fetchpatch {
      name = "SQUID-2023_3.patch";
      url = "https://www.squid-cache.org/Versions/v6/SQUID-2023_3.patch";
      hash = "sha256-00000000";
    })
    (fetchpatch {
      name = "SQUID-2023_4.patch";
      url = "https://www.squid-cache.org/Versions/v6/SQUID-2023_4.patch";
      hash = "sha256-00000000";
    })
    (fetchpatch {
      name = "SQUID-2023_5.patch";
      url = "https://www.squid-cache.org/Versions/v6/SQUID-2023_5.patch";
      hash = "sha256-0000000000";
    })
    (fetchpatch {
      name = "SQUID-2023_7.patch";
      url = "https://www.squid-cache.org/Versions/v6/SQUID-2023_7.patch";
      hash = "sha256-0000000000";
    })
    (fetchpatch {
      name = "SQUID-2023_8.patch";
      url = "https://www.squid-cache.org/Versions/v6/SQUID-2023_8.patch";
      hash = "sha256-0000000000";
    })
    (fetchpatch {
      name = "SQUID-2023_10.patch";
      url = "https://www.squid-cache.org/Versions/v6/SQUID-2023_10.patch";
      hash = "sha256-0000000000";
    })
    (fetchpatch {
      name = "SQUID-2023_11.patch";
      url = "https://www.squid-cache.org/Versions/v6/SQUID-2023_11.patch";
      hash = "sha256-0000000000";
    })
  ];

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [
    perl openldap db cyrus_sasl expat libxml2 openssl
  ] ++ lib.optionals stdenv.isLinux [ libcap pam systemd ];

  enableParallelBuilding = true;

  configureFlags = [
    "--enable-ipv6"
    "--disable-strict-error-checking"
    "--disable-arch-native"
    "--with-openssl"
    "--enable-ssl-crtd"
    "--enable-storeio=ufs,aufs,diskd,rock"
    "--enable-removal-policies=lru,heap"
    "--enable-delay-pools"
    "--enable-x-accelerator-vary"
    "--enable-htcp"
  ] ++ lib.optional (stdenv.isLinux && !stdenv.hostPlatform.isMusl)
    "--enable-linux-netfilter";

  doCheck = true;
  nativeCheckInputs = [ cppunit ];
  preCheck = ''
    # tests attempt to copy around "/bin/true" to make some things
    # no-ops but this doesn't work if our "true" is a multi-call
    # binary, so make our own fake "true" which will work when used
    # this way
    echo "#!$SHELL" > fake-true
    chmod +x fake-true
    grep -rlF '/bin/true' test-suite/ | while read -r filename ; do
      substituteInPlace "$filename" \
        --replace "$(type -P true)" "$(realpath fake-true)" \
        --replace "/bin/true" "$(realpath fake-true)"
    done
  '';

  meta = with lib; {
    description = "A caching proxy for the Web supporting HTTP, HTTPS, FTP, and more";
    homepage = "http://www.squid-cache.org";
    license = licenses.gpl2Plus;
    platforms = platforms.linux;
    maintainers = with maintainers; [ raskin ];
    knownVulnerabilities = [
      "GHSA-rj5h-46j6-q2g5"
      "CVE-2023-5824"
      "CVE-2023-46728"
      "CVE-2023-49286"
      "Several outstanding, unnumbered issues from https://megamansec.github.io/Squid-Security-Audit/ with unclear status"
    ];
  };
}
