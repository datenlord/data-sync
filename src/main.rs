use bcc::perf_event;
use bcc::{BccError, Kprobe, Kretprobe, BPF};

use core::sync::atomic::{AtomicBool, Ordering};
use std::ptr;
use std::sync::Arc;

/// <https://elixir.bootlin.com/linux/latest/source/include/linux/sched.h#L212>
const TASK_COMM_LEN: usize = 16;
/// <https://elixir.bootlin.com/linux/latest/source/include/linux/dcache.h#L78>
const DNAME_INLINE_LEN: usize = 32;

#[repr(C)]
struct event_data_t {
    pid: u32,
    sz: u32,
    delta_us: u64,
    name_len: u32,
    parent_name_len: u32,
    name: [u8; DNAME_INLINE_LEN],
    parent_name: [u8; DNAME_INLINE_LEN],
    comm: [u8; TASK_COMM_LEN],
}

fn do_main(runnable: Arc<AtomicBool>) -> Result<(), BccError> {
    let bpf_code = include_str!("vfs_write.c");

    let mut module = BPF::new(bpf_code)?;
    Kprobe::new()
        .handler("trace_write_entry")
        .function("vfs_write")
        .attach(&mut module)?;
    Kretprobe::new()
        .handler("trace_write_return")
        .function("vfs_write")
        .attach(&mut module)?;

    let table = module.table("events")?;
    let mut perf_map = perf_event::init_perf_map(table, perf_data_callback)?;
    // Print header
    println!(
        "{:-7} {:-7} {:-7} {}",
        "COMM", "BYTES", "LAT(us)", "FILENAME"
    );
    // This `.poll()` loop is what makes our callback get called
    while runnable.load(Ordering::SeqCst) {
        perf_map.poll(200);
    }
    Ok(())
}

fn perf_data_callback() -> Box<dyn FnMut(&[u8]) + Send> {
    Box::new(|x| {
        // This callback
        let data = parse_struct(x);
        println!(
            "{:-7} {:>7} {:>7} {}/{}",
            get_string(&data.comm),
            data.sz,
            data.delta_us,
            get_string(&data.parent_name),
            get_string(&data.name),
        );
    })
}

fn parse_struct(x: &[u8]) -> event_data_t {
    unsafe { ptr::read(x.as_ptr() as *const event_data_t) }
}

fn get_string(x: &[u8]) -> String {
    match x.iter().position(|&r| r == 0) {
        Some(zero_pos) => String::from_utf8_lossy(&x[0..zero_pos]).to_string(),
        None => String::from_utf8_lossy(x).to_string(),
    }
}

fn main() {
    let runnable = Arc::new(AtomicBool::new(true));
    let r = runnable.clone();
    ctrlc::set_handler(move || {
        r.store(false, Ordering::SeqCst);
    })
    .expect("Failed to set handler for SIGINT / SIGTERM");

    if let Err(x) = do_main(runnable) {
        eprintln!("Error: {}", x);
        std::process::exit(1);
    }
}
