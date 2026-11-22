class CcacheStorageRedis < Formula
  desc "Ccache Redis storage helper"
  homepage "https://github.com/ccache/ccache-storage-redis"
  url "https://github.com/ccache/ccache-storage-redis/archive/refs/tags/v0.2.1.tar.gz"
  sha256 "56cd23972860ba2caa17efffcff31dc9a327cfd717217ab680cac8e94871c006"
  license "MIT"

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
    # We need to launch the storage helper on our own because even with
    # XDG_RUNTIME_DIR set to testpath the Unix domain socket path generated
    # by ccache for the helper is too long (131 >= 104), e.g.:
    #   /private/tmp/ccache-storage-redis-test-20261121-32771-4xpbql/
    #   ccache-tmp/storage-redis+unix-4f7a92adc62d75f37ca95ea6a17623f4d1647683

    ccache_bin = formula_opt_bin("ccache")/"ccache"
    crsh_socket = testpath/"crsh.sock"
    redis_server = formula_opt_bin("redis")/"redis-server"
    redis_cli = formula_opt_bin("redis")/"redis-cli"
    redis_socket = testpath/"redis.sock"

    ENV["CCACHE_DIR"] = (testpath/"ccache").to_s
    ENV["CCACHE_REMOTE_ONLY"] = "1"
    ENV["CCACHE_REMOTE_STORAGE"] = "crsh:#{crsh_socket}"

    ENV["CRSH_IPC_ENDPOINT"] = crsh_socket.to_s
    ENV["CRSH_URL"] = "redis+unix://#{redis_socket}"

    (testpath/"test.c").write("int main(void) { return 0; }\n")

    with_test_process(redis_server, "--port", "0", "--unixsocket", redis_socket,
                      "--unixsocketperm", "700", "--loglevel", "nothing") do
      50.times do
        break if File.socket?(redis_socket)

        sleep 0.1
      end
      assert_predicate redis_socket, :socket?, "Redis did not create its Unix socket"
      assert_equal "PONG", shell_output("#{redis_cli} -s #{redis_socket} ping").strip

      with_test_process(bin/"ccache-storage-redis") do
        50.times do
          break if crsh_socket.socket?

          sleep 0.1
        end
        assert_predicate crsh_socket, :socket?, "Storage helper did not create its IPC socket"

        3.times do
          system ccache_bin, "cc", "-c", "test.c"
        end
        stats = JSON.parse(shell_output("#{ccache_bin} --print-stats --format json"))
        assert_equal 0, stats["remote_storage_error"]
        assert_equal 0, stats["remote_storage_timeout"]
        assert_equal 1, stats["remote_storage_miss"]
        assert_equal 2, stats["remote_storage_hit"]
      end
    end
  end
end
