#include <uapi/linux/ptrace.h>
#include <linux/fs.h>
#include <linux/sched.h>

#define MAX_BUF_SIZE 256 * 1024

struct entry_data_t {
    u32 size;
    u32 file_name_len;
    u32 parent_name_len;
    u32 padding;
    char *buf;
    // de->d_name.name may point to de->d_iname so limit len accordingly
    char file_name[DNAME_INLINE_LEN];
    char parent_name[DNAME_INLINE_LEN];
    char comm[TASK_COMM_LEN];
};

struct ret_data_t {
    u32 pid;
    u32 tid;
    u32 size;
    u32 ret_size;
    u32 file_name_len;
    u32 parent_name_len;
    char file_name[DNAME_INLINE_LEN];
    char parent_name[DNAME_INLINE_LEN];
    char comm[TASK_COMM_LEN];
    char buf[MAX_BUF_SIZE];
};

BPF_HASH(entryinfo, u64, struct entry_data_t);
BPF_RINGBUF_OUTPUT(ringbuf, 1 << 15); // Ring buffer size 2^15 * 4K = 128M

static int trace_rw_entry(struct pt_regs *ctx, struct file *file,
    char __user *buf, size_t count)
{
    u64 tpid = bpf_get_current_pid_tgid();
    // skip I/O lacking a filename
    struct dentry *de = file->f_path.dentry;
    struct dentry *parent_de = de->d_parent;
    int mode = file->f_inode->i_mode;
    // skip non-file IO
    if (de->d_name.len == 0 || !S_ISREG(mode)) {
        return 0;
    }
    struct entry_data_t entry_data = {};
    entry_data.size = count;
    struct qstr d_name = de->d_name;
    entry_data.file_name_len = d_name.len;
    struct qstr parent_d_name = parent_de->d_name;
    entry_data.parent_name_len = parent_d_name.len;
    entry_data.buf = buf;
    bpf_probe_read_kernel(&entry_data.file_name, sizeof(entry_data.file_name), d_name.name);
    bpf_probe_read_kernel(&entry_data.parent_name, sizeof(entry_data.parent_name), parent_d_name.name);
    bpf_get_current_comm(&entry_data.comm, sizeof(entry_data.comm));
    entryinfo.update(&tpid, &entry_data);
    return 0;
}

static int trace_rw_return(struct pt_regs *ctx, int type)
{
    struct entry_data_t *entry_data;
    u64 tpid = bpf_get_current_pid_tgid();
    entry_data = entryinfo.lookup(&tpid);
    if (!entry_data) {
        // missed tracing issue or filtered
        return 0;
    }
    entryinfo.delete(&tpid);
    int ret_val = PT_REGS_RC(ctx);
    if (ret_val <= 0 || ret_val > entry_data->size) {
        // read or write return error or
	// return value larger than buffer size
        return 0;
    }
    struct ret_data_t *ret_data = ringbuf.ringbuf_reserve(sizeof(struct ret_data_t));
    if (!ret_data) {
        return 1;
    }
    ret_data->pid = tpid;
    ret_data->tid = tpid >> 32;
    ret_data->size = entry_data->size;
    ret_data->ret_size = ret_val;
    ret_data->file_name_len = entry_data->file_name_len;
    ret_data->parent_name_len = entry_data->parent_name_len;
    bpf_probe_read_kernel(ret_data->file_name, sizeof(ret_data->file_name), entry_data->file_name);
    bpf_probe_read_kernel(ret_data->parent_name, sizeof(ret_data->parent_name), entry_data->parent_name);
    bpf_probe_read_kernel(ret_data->comm, sizeof(ret_data->comm), entry_data->comm);
    if (!entry_data->buf) {
	ringbuf.ringbuf_discard(ret_data, BPF_RB_NO_WAKEUP);
        return 0;
    }
    bpf_probe_read_user(ret_data->buf, sizeof(ret_data->buf), entry_data->buf);
    ringbuf.ringbuf_submit(ret_data, BPF_RB_NO_WAKEUP);
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

int trace_read_return(struct pt_regs *ctx)
{
    return trace_rw_return(ctx, 0);
}
int trace_write_return(struct pt_regs *ctx)
{
    return trace_rw_return(ctx, 1);
}
