use bcc::ring_buf::{RingBufBuilder, RingCallback};
use bcc::BccError;
use bcc::{Kprobe, Kretprobe, BPF};

use core::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

/// <https://elixir.bootlin.com/linux/latest/source/include/linux/sched.h#L212>
const TASK_COMM_LEN: usize = 16;
/// <https://elixir.bootlin.com/linux/latest/source/include/linux/dcache.h#L78>
const DNAME_INLINE_LEN: usize = 32;
const MAX_BUF_SIZE: usize = 256 * 1024;

#[repr(C)]
struct RingBufData {
    pid: u32,
    tid: u32,
    size: u32,
    ret_size: u32,
    file_name_len: u32,
    parent_name_len: u32,
    file_name: [u8; DNAME_INLINE_LEN],
    parent_name: [u8; DNAME_INLINE_LEN],
    comm: [u8; TASK_COMM_LEN],
    buf: [u8; MAX_BUF_SIZE],
}

fn do_main(runnable: Arc<AtomicBool>) -> Result<(), BccError> {
    let code = include_str!("write.c");

    let mut module = BPF::new(code)?;
    Kprobe::new()
        .handler("trace_write_entry")
        .function("vfs_write")
        .attach(&mut module)?;
    Kretprobe::new()
        .handler("trace_write_return")
        .function("vfs_write")
        .attach(&mut module)?;

    let cb = RingCallback::new(Box::new(ring_buf_callback));

    let table = module.table("ringbuf")?;
    let mut ring_buf = RingBufBuilder::new(table, cb).build()?;

    println!(
        "{:-32} {:10} {:10} {:10} {:10} {:65} {:32}",
        "COMM", "PID", "TID", "SIZE", "RET", "FILE", "BUF",
    );
    while runnable.load(Ordering::SeqCst) {
        ring_buf.consume();
        std::thread::sleep(std::time::Duration::from_millis(500));
    }
    Ok(())
}

fn parse_struct(x: &[u8]) -> RingBufData {
    unsafe { std::ptr::read(x.as_ptr() as *const _) }
}

fn get_string(x: &[u8]) -> String {
    match x.iter().position(|&r| r == 0) {
        Some(zero_pos) => String::from_utf8_lossy(&x[0..zero_pos]).to_string(),
        None => String::from_utf8_lossy(x).to_string(),
    }
}

fn ring_buf_callback(data: &[u8]) {
    let ring_buf_data = parse_struct(data);

    println!(
        "{:-32} {:10} {:10} {:10} {:10} {}/{}",
        get_string(&ring_buf_data.comm),
        ring_buf_data.pid,
        ring_buf_data.tid,
        ring_buf_data.size,
        ring_buf_data.ret_size,
        get_string(&ring_buf_data.parent_name),
        get_string(&ring_buf_data.file_name),
    );
}

fn main() {
    let runnable = Arc::new(AtomicBool::new(true));
    let r = runnable.clone();
    ctrlc::set_handler(move || {
        r.store(false, Ordering::SeqCst);
    })
    .expect("Failed to set handler for SIGINT / SIGTERM");

    match do_main(runnable) {
        Err(x) => {
            eprintln!("Error: {}", x);
            std::process::exit(1);
        }
        _ => {}
    }
}
