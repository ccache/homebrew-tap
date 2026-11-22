class CcacheStorageRedis < Formula
  desc "Ccache Redis storage helper"
  homepage "https://github.com/ccache/ccache-storage-redis"
  url "https://github.com/ccache/ccache-storage-redis/archive/refs/tags/v0.2.1.tar.gz"
  sha256 "56cd23972860ba2caa17efffcff31dc9a327cfd717217ab680cac8e94871c006"
  license "MIT"

  bottle do
    root_url "https://github.com/ccache/homebrew-tap/releases/download/ccache-storage-redis-0.2.1"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "e681adcf252cab97b6833ffa57a5a7bc938982aa664114c03ee4d18606eb1f30"
    sha256 cellar: :any,                 x86_64_linux: "e31400ff059a109731c31c398d08e471fed88e4a810a8ac2bcdf2fa7906afc10"
  end

  depends_on "go" => :build
  depends_on "ccache" => :test
  depends_on "redis" => :test

  deny_network_access!

  def fetch
    system "go", "mod", "download"
  end

  def install
    system "go", "build", *std_go_args
    bin.install_symlink "ccache-storage-redis" => "ccache-storage-rediss"
    bin.install_symlink "ccache-storage-redis" => "ccache-storage-redis+unix"
  end

  test do
    # Launch the storage helper ourselves instead of letting ccache spawn it:
    # the test sandbox only allows Unix socket connections below testpath, but
    # ccache puts the helper socket in /tmp/ccache-tmp-<uid>, and moving it
    # below testpath via XDG_RUNTIME_DIR exceeds the 104-byte socket path limit.
    ccache_bin = formula_opt_bin("ccache")/"ccache"
    crsh_socket = testpath/"crsh.sock"
    redis_server = formula_opt_bin("redis")/"redis-server"
    redis_cli = formula_opt_bin("redis")/"redis-cli"
    redis_socket = testpath/"redis.sock"

    ENV["CCACHE_DIR"] = testpath/"ccache"
    ENV["CCACHE_REMOTE_ONLY"] = "1"
    ENV["CCACHE_REMOTE_STORAGE"] = "crsh:#{crsh_socket}"

    ENV["CRSH_IPC_ENDPOINT"] = crsh_socket
    ENV["CRSH_URL"] = "redis+unix://#{redis_socket}"

    (testpath/"test.c").write("int main(void) { return 0; }\n")

    with_test_process(redis_server, "--port", "0", "--unixsocket", redis_socket,
                      "--unixsocketperm", "700", "--loglevel", "nothing") do
      50.times do
        break if File.socket?(redis_socket)

        sleep 0.1
      end
      assert_predicate redis_socket, :socket?, "Redis did not create its Unix socket"
      assert_equal "PONG", shell_output("#{redis_cli} -s #{redis_socket} ping").strip,
                   "Redis did not answer PING on its Unix socket"

      with_test_process(bin/"ccache-storage-redis") do
        50.times do
          break if crsh_socket.socket?

          sleep 0.1
        end
        assert_predicate crsh_socket, :socket?, "Storage helper did not create its IPC socket"

        3.times do
          system ccache_bin, ENV.cc, "-c", "test.c"
        end

        stats = JSON.parse(shell_output("#{ccache_bin} --print-stats --format json"))
        expected = {
          "remote_storage_error"   => 0,
          "remote_storage_timeout" => 0,
          "remote_storage_miss"    => 1,
          "remote_storage_hit"     => 2,
        }
        assert_equal expected, stats.slice(*expected.keys),
                     "Expected one remote miss followed by two remote hits via Redis"
      end
    end
  end
end
