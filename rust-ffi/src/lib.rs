//! LumenLink iOS FFI
//!
//! C ABI bindings for Swift/XCFramework integration.
//! Exposes tunnel management, packet processing, and statistics.

use std::collections::HashMap;
use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_int, c_void};
use std::ptr;
use std::sync::atomic::{AtomicI64, AtomicU64, Ordering};
use std::sync::{Arc, Mutex};

/// Tunnel handle storage (thread-safe)
static TUNNELS: Mutex<HashMap<i64, Arc<Mutex<TunnelState>>>> = Mutex::new(HashMap::new());
static NEXT_HANDLE: AtomicI64 = AtomicI64::new(1);

/// Per-tunnel statistics (thread-safe)
#[derive(Default)]
struct TunnelStats {
    bytes_sent: AtomicU64,
    bytes_received: AtomicU64,
}

/// Tunnel state
struct TunnelState {
    config: String,
    mode: i32,
    is_running: bool,
    stats: TunnelStats,
}

/// Gateway mode state (thread-safe)
static GATEWAY_MODE: Mutex<Option<GatewayModeState>> = Mutex::new(None);

struct GatewayModeState {
    bandwidth_limit_mbps: i32,
}

fn get_next_handle() -> i64 {
    NEXT_HANDLE.fetch_add(1, Ordering::SeqCst)
}

/// Start tunnel with config JSON.
/// Returns handle (pointer-sized) or 0 on error.
#[no_mangle]
pub extern "C" fn lumenlink_start_tunnel(config_json: *const c_char) -> *mut c_void {
    let result = || -> Result<*mut c_void, Box<dyn std::error::Error>> {
        let config_str = if config_json.is_null() {
            "{}".to_string()
        } else {
            unsafe { CStr::from_ptr(config_json).to_string_lossy().into_owned() }
        };

        serde_json::from_str::<serde_json::Value>(&config_str)
            .map_err(|e| format!("Invalid config JSON: {}", e))?;

        let handle = get_next_handle();
        let tunnel_state = Arc::new(Mutex::new(TunnelState {
            config: config_str,
            mode: 1, // LEAF
            is_running: true,
            stats: TunnelStats::default(),
        }));

        let mut tunnels = TUNNELS.lock().map_err(|_| "Lock poisoned")?;
        tunnels.insert(handle, tunnel_state);

        Ok(handle as *mut c_void)
    };

    match result() {
        Ok(handle) => handle,
        Err(e) => {
            eprintln!("lumenlink_start_tunnel error: {}", e);
            ptr::null_mut()
        }
    }
}

/// Stop tunnel.
#[no_mangle]
pub extern "C" fn lumenlink_stop_tunnel(handle: *mut c_void) {
    if handle.is_null() {
        return;
    }
    let h = handle as i64;
    let mut tunnels = TUNNELS.lock().unwrap();
    if let Some(tunnel_state) = tunnels.remove(&h) {
        let mut state = tunnel_state.lock().unwrap();
        state.is_running = false;
    }
}

/// Handle packet from TUN interface.
/// Returns 0 on success, -1 on error.
/// Response is written to output buffers (caller allocates).
#[no_mangle]
pub extern "C" fn lumenlink_handle_packet(
    handle: *mut c_void,
    packet: *const u8,
    packet_len: i32,
    response_out: *mut *mut u8,
    response_len_out: *mut i32,
) -> i32 {
    if handle.is_null() || packet.is_null() || packet_len <= 0 {
        return -1;
    }
    if !response_out.is_null() {
        unsafe { *response_out = ptr::null_mut() };
    }
    if !response_len_out.is_null() {
        unsafe { *response_len_out = 0 };
    }

    let h = handle as i64;
    let tunnels = TUNNELS.lock().unwrap();
    let tunnel_state = match tunnels.get(&h) {
        Some(t) => t.clone(),
        None => return -1,
    };
    drop(tunnels);

    let mut state = tunnel_state.lock().unwrap();
    if !state.is_running {
        return -1;
    }

    let packet_slice = unsafe { std::slice::from_raw_parts(packet, packet_len as usize) };
    state.stats.bytes_received.fetch_add(packet_len as u64, Ordering::Relaxed);

    // TODO: Process packet through lumenlink_core transport layer
    // For now, no response (return 0 = success, no response packet)
    0
}

/// Get tunnel statistics as JSON string.
/// Caller must free with lumenlink_free_string.
#[no_mangle]
pub extern "C" fn lumenlink_get_statistics(handle: *mut c_void) -> *mut c_char {
    if handle.is_null() {
        return ptr::null_mut();
    }

    let h = handle as i64;
    let tunnels = TUNNELS.lock().unwrap();
    let tunnel_state = match tunnels.get(&h) {
        Some(t) => t.clone(),
        None => return ptr::null_mut(),
    };
    drop(tunnels);

    let state = tunnel_state.lock().unwrap();
    let stats = serde_json::json!({
        "handle": h,
        "is_running": state.is_running,
        "bytes_sent": state.stats.bytes_sent.load(Ordering::Relaxed),
        "bytes_received": state.stats.bytes_received.load(Ordering::Relaxed),
        "transport": "unknown",
        "gateway": null
    });

    match CString::new(stats.to_string()) {
        Ok(s) => s.into_raw(),
        Err(_) => ptr::null_mut(),
    }
}

/// Free string allocated by Rust (lumenlink_get_statistics, etc.)
#[no_mangle]
pub extern "C" fn lumenlink_free_string(s: *mut c_char) {
    if !s.is_null() {
        unsafe { let _ = CString::from_raw(s); }
    }
}

/// Enable gateway mode (PERSIA mode).
#[no_mangle]
pub extern "C" fn lumenlink_enable_gateway_mode(bandwidth_limit_mbps: c_int) {
    let mut gw = GATEWAY_MODE.lock().unwrap();
    *gw = Some(GatewayModeState {
        bandwidth_limit_mbps: bandwidth_limit_mbps as i32,
    });
}

/// Disable gateway mode.
#[no_mangle]
pub extern "C" fn lumenlink_disable_gateway_mode() {
    let mut gw = GATEWAY_MODE.lock().unwrap();
    *gw = None;
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::ffi::{CStr, CString};

    #[test]
    fn test_start_stop_tunnel() {
        let config = CString::new(r#"{"gateways":[],"transports":["masque"]}"#).unwrap();
        let handle = lumenlink_start_tunnel(config.as_ptr());
        assert!(!handle.is_null());
        lumenlink_stop_tunnel(handle);
    }

    #[test]
    fn test_start_tunnel_invalid_config() {
        let config = CString::new("invalid json").unwrap();
        let handle = lumenlink_start_tunnel(config.as_ptr());
        assert!(handle.is_null());
    }

    #[test]
    fn test_get_statistics() {
        let config = CString::new("{}").unwrap();
        let handle = lumenlink_start_tunnel(config.as_ptr());
        assert!(!handle.is_null());
        let stats = lumenlink_get_statistics(handle);
        assert!(!stats.is_null());
        let s = unsafe { CStr::from_ptr(stats).to_string_lossy() };
        assert!(s.contains("bytes_sent"));
        lumenlink_free_string(stats);
        lumenlink_stop_tunnel(handle);
    }

    #[test]
    fn test_enable_gateway_mode() {
        lumenlink_enable_gateway_mode(100);
        lumenlink_disable_gateway_mode();
    }
}
