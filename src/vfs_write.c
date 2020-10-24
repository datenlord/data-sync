#include <uapi/linux/ptrace.h>
#include <linux/fs.h>
#include <linux/sched.h>

struct val_t {
    u32 sz;
    u64 ts;
    u32 name_len;
    u32 parent_name_len;
    // de->d_name.name may point to de->d_iname so limit len accordingly
    char name[DNAME_INLINE_LEN];
    char parent_name[DNAME_INLINE_LEN];
    char comm[TASK_COMM_LEN];
};
struct data_t {
    u32 pid;
    u32 sz;
    u64 delta_us;
    u32 name_len;
    u32 parent_name_len;
    char name[DNAME_INLINE_LEN];
    char parent_name[DNAME_INLINE_LEN];
    char comm[TASK_COMM_LEN];
};
BPF_HASH(entryinfo, pid_t, struct val_t);
BPF_PERF_OUTPUT(events);
// store timestamp and size on entry
static int trace_rw_entry(struct pt_regs *ctx, struct file *file,
    char __user *buf, size_t count)
{
    u32 tgid = bpf_get_current_pid_tgid() >> 32;
    //if (TGID_FILTER)
    //    return 0;
    u32 pid = bpf_get_current_pid_tgid();
    // skip I/O lacking a filename
    struct dentry *de = file->f_path.dentry;
    struct dentry *parent_de = de->d_parent;
    int mode = file->f_inode->i_mode;
    //if (de->d_name.len == 0 || TYPE_FILTER)
    if (de->d_name.len == 0 || !S_ISREG(mode))
        return 0;
    // store size and timestamp by pid
    struct val_t val = {};
    val.sz = count;
    val.ts = bpf_ktime_get_ns();
    struct qstr d_name = de->d_name;
    val.name_len = d_name.len;
    struct qstr parent_d_name = parent_de->d_name;
    val.parent_name_len = parent_d_name.len;
    //bpf_probe_read_kernel(&val.name, sizeof(val.name), d_name.name);
    bpf_probe_read(&val.name, sizeof(val.name), d_name.name);
    bpf_probe_read(&val.parent_name, sizeof(val.parent_name), parent_d_name.name);
    bpf_get_current_comm(&val.comm, sizeof(val.comm));
    entryinfo.update(&pid, &val);
    return 0;
}
int trace_read_entry(struct pt_regs *ctx, struct file *file,
    char __user *buf, size_t count)
{
    // skip non-sync I/O; see kernel code for __vfs_read()
    if (!(file->f_op->read_iter))
        return 0;
    return trace_rw_entry(ctx, file, buf, count);
}
int trace_write_entry(struct pt_regs *ctx, struct file *file,
    char __user *buf, size_t count)
{
    // skip non-sync I/O; see kernel code for __vfs_write()
    if (!(file->f_op->write_iter))
        return 0;
    return trace_rw_entry(ctx, file, buf, count);
}
// output
static int trace_rw_return(struct pt_regs *ctx, int type)
{
    struct val_t *valp;
    u32 pid = bpf_get_current_pid_tgid();
    valp = entryinfo.lookup(&pid);
    if (valp == 0) {
        // missed tracing issue or filtered
        return 0;
    }
    u64 delta_us = (bpf_ktime_get_ns() - valp->ts) / 1000;
    entryinfo.delete(&pid);
    //if (delta_us < MIN_US)
    //    return 0;
    struct data_t data = {};
    //data.mode = type;
    data.pid = pid;
    data.sz = valp->sz;
    data.delta_us = delta_us;
    data.name_len = valp->name_len;
    data.parent_name_len = valp->parent_name_len;
    //bpf_probe_read_kernel(&data.name, sizeof(data.name), valp->name);
    //bpf_probe_read_kernel(&data.comm, sizeof(data.comm), valp->comm);
    bpf_probe_read(&data.name, sizeof(data.name), valp->name);
    bpf_probe_read(&data.parent_name, sizeof(data.parent_name), valp->parent_name);
    bpf_probe_read(&data.comm, sizeof(data.comm), valp->comm);
    events.perf_submit(ctx, &data, sizeof(data));
    return 0;
}
int trace_read_return(struct pt_regs *ctx)
{
    return trace_rw_return(ctx, 0);
}
int trace_write_return(struct pt_regs *ctx)
{
    return trace_rw_return(ctx, 1);
}
