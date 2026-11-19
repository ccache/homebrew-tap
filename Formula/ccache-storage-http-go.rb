class CcacheStorageHttpGo < Formula
  desc "Ccache HTTP(S) storage helper (Go)"
  homepage "https://github.com/ccache/ccache-storage-http-go"
  url "https://github.com/ccache/ccache-storage-http-go/archive/refs/tags/v0.10.1.tar.gz"
  sha256 "e9f78a4df3a56178ab7003a3a82c4e8e982fde3e0b227af44f973f8ca5446741"
  license "MIT"

  bottle do
    root_url "https://ghcr.io/v2/ccache/tap"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "ce584d8e4168a712f5a9d4132fb37fe3c490fe75d9a8d64793dcfd2ceec393ea"
    sha256 cellar: :any,                 x86_64_linux: "6f1d756a67a02120b6c25a51424ea3c48b160a6b5065eec5aa13f7d99015baa7"
  end

  depends_on "go" => :build

  deny_network_access!

  def fetch
    system "go", "mod", "download"
  end

  def install
    system "go", "build", *std_go_args(output: bin/"ccache-storage-http")
    bin.install_symlink "ccache-storage-http" => "ccache-storage-https"
  end

  test do
    system "true"
    # system bin/"ccache-storage-http", "--version"
  end
end
