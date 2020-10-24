const int BUF_SIZE = 128;

typedef struct write_val {
    u32 fd;
    u32 padding;
    size_t count;
    const char *buf;
} write_val_t;

typedef struct event_data {
    u64 tpid;
    u32 fd;
    u32 padding;
    size_t count;
    char buf[BUF_SIZE];
} event_data_t;

BPF_HASH(write_data, u64, write_val_t);
BPF_PERF_OUTPUT(events);

//TRACEPOINT_PROBE(syscalls, sys_enter_write) {
int write_entry(struct tracepoint__syscalls__sys_enter_write *args) {
    u64 tpid = bpf_get_current_pid_tgid();

    write_val_t val = {};
    val.fd = args->fd;
    val.padding = 0;
    val.count = args->count;
    val.buf = args->buf;

    write_data.update(&tpid, &val);
    return 0;
}

//TRACEPOINT_PROBE(syscalls, sys_exit_write) {
int write_exit(struct tracepoint__syscalls__sys_exit_write *args) {
    u64 tpid = bpf_get_current_pid_tgid();
    write_val_t *val;

    val = write_data.lookup(&tpid);
    if (val != NULL) {
        event_data_t data = {};
	data.tpid = tpid;
	data.fd = val->fd;
	data.padding = 0;
	data.count = args->ret;
	bpf_probe_read(&data.buf, sizeof(data.buf), val->buf);
        bpf_trace_printk("write fd: %d, write size: %d, buf content: %s\\n", val->fd, args->ret, data.buf);

	events.perf_submit(args, &data, sizeof(data));
        write_data.delete(&tpid);
    }
    return 0;
}
