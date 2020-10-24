use bcc::perf_event;
use bcc::{BccError, Tracepoint, BPF};

use core::sync::atomic::{AtomicBool, Ordering};
use std::ptr;
use std::sync::Arc;

#[repr(C)]
struct event_data_t {
    tpid: u64,
    fd: u32,
    padding: u32,
    count: usize,
    buf: [u8; 1024],
}

fn do_main(runnable: Arc<AtomicBool>) -> Result<(), BccError> {
    let bpf_code = include_str!("sys_write.c");

    let mut module = BPF::new(bpf_code)?;
    Tracepoint::new()
        .handler("write_entry")
        .subsystem("syscalls")
        .tracepoint("sys_enter_write")
        .attach(&mut module)?;
    Tracepoint::new()
        .handler("write_exit")
        .subsystem("syscalls")
        .tracepoint("sys_exit_write")
        .attach(&mut module)?;

    let table = module.table("events")?;
    let mut perf_map = perf_event::init_perf_map(table, perf_data_callback)?;
    // Print header
    println!("{:-7} {:-7} {:-7} {}", "PID", "FD", "SIZE", "BUFFER");
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
            "{:-7} {:>7} {:>7} {}",
            data.tpid >> 32,
            data.fd,
            data.count,
            get_string(&data.buf)
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
