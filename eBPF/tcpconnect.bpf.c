// minimal CO-RE kprobe; counts tcp_connect per PID
#include <vmlinux.h>
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_tracing.h>

struct {
  __uint(type, BPF_MAP_TYPE_HASH);
  __type(key, u32);     // PID
  __type(value, u64);   // count
  __uint(max_entries, 8192);
} counts SEC(".maps");

SEC("kprobe/tcp_connect")
int BPF_KPROBE(on_tcp_connect, struct sock *sk) {
  u32 pid = bpf_get_current_pid_tgid() >> 32;
  u64 init = 1, *val = bpf_map_lookup_elem(&counts, &pid);
  if (val) __sync_fetch_and_add(val, 1);
  else bpf_map_update_elem(&counts, &pid, &init, BPF_ANY);
  return 0;
}

char LICENSE[] SEC("license") = "GPL";
