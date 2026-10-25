/* Godot 4.3 synchronously probes all joypads on every WM_DEVICECHANGE. Ignore
 * only generic DBT_DEVNODES_CHANGED when the complete raw-input device set is
 * provably unchanged. Actual arrival/removal and query errors always pass.
 * This subclasses only a window owned by this process and restores its proc. */
#ifdef _WIN32
#include <windows.h>
#include <dbt.h>
typedef struct { UINT id; uintptr_t event; int64_t count,total,max; } WindowMessageTiming;
static HWND traced_window;
static WNDPROC traced_original;
static LARGE_INTEGER traced_frequency;
static WindowMessageTiming traced_messages[128];
static int traced_count,trace_collecting,device_guard_enabled;
static int64_t device_skipped,device_forwarded,device_query_errors,device_changed;
static RAWINPUTDEVICELIST *known_devices;
static HDEVNOTIFY guard_hid,guard_xinput;
static const GUID guard_hid_guid={0x4d1e55b2,0xf16f,0x11cf,{0x88,0xcb,0x00,0x11,0x11,0x00,0x00,0x30}};
static const GUID guard_xinput_guid={0xec87f1e3,0xc13b,0x4100,{0xb5,0xf7,0x8b,0x84,0xd5,0x42,0x60,0xcb}};
static void guard_unregister(void) {
    if(guard_hid) UnregisterDeviceNotification(guard_hid);
    if(guard_xinput) UnregisterDeviceNotification(guard_xinput);
    guard_hid=guard_xinput=NULL;
}
static int guard_register(HWND hwnd) {
    guard_unregister();
    DEV_BROADCAST_DEVICEINTERFACE_W filter={0};
    filter.dbcc_size=sizeof(filter); filter.dbcc_devicetype=DBT_DEVTYP_DEVICEINTERFACE;
    filter.dbcc_classguid=guard_hid_guid;
    guard_hid=RegisterDeviceNotificationW(hwnd,&filter,DEVICE_NOTIFY_WINDOW_HANDLE);
    filter.dbcc_classguid=guard_xinput_guid;
    guard_xinput=RegisterDeviceNotificationW(hwnd,&filter,DEVICE_NOTIFY_WINDOW_HANDLE);
    if(!guard_hid || !guard_xinput) { guard_unregister(); return 0; }
    return 1;
}
static UINT known_count;
static int known_valid;
static int raw_device_compare(const void *a,const void *b) {
    const RAWINPUTDEVICELIST *x=a,*y=b;
    uintptr_t p=(uintptr_t)x->hDevice,q=(uintptr_t)y->hDevice;
    if(p!=q) return (p>q)-(p<q);
    return (x->dwType>y->dwType)-(x->dwType<y->dwType);
}
static int input_devices_changed(void) {
    UINT count=0;
    if(GetRawInputDeviceList(NULL,&count,sizeof(RAWINPUTDEVICELIST))==(UINT)-1 || count>8192) { device_query_errors++; return 1; }
    RAWINPUTDEVICELIST *items=count?calloc(count,sizeof(RAWINPUTDEVICELIST)):NULL;
    if(count && !items) { device_query_errors++; return 1; }
    UINT read=count;
    if(count && GetRawInputDeviceList(items,&read,sizeof(RAWINPUTDEVICELIST))==(UINT)-1) { free(items); device_query_errors++; return 1; }
    count=read;
    if(count) qsort(items,count,sizeof(RAWINPUTDEVICELIST),raw_device_compare);
    int changed=!known_valid || count!=known_count;
    if(!changed) for(UINT i=0;i<count;i++) if(items[i].hDevice!=known_devices[i].hDevice || items[i].dwType!=known_devices[i].dwType) { changed=1; break; }
    free(known_devices); known_devices=items; known_count=count; known_valid=1;
    if(changed) device_changed++;
    return changed;
}
static LRESULT CALLBACK traced_window_proc(HWND hwnd,UINT msg,WPARAM wp,LPARAM lp) {
    if(msg==WM_DEVICECHANGE && device_guard_enabled) {
        if(wp==DBT_DEVNODES_CHANGED && !input_devices_changed()) { device_skipped++; return DefWindowProcW(hwnd,msg,wp,lp); }
        device_forwarded++;
    }
    LARGE_INTEGER begin,end;
    if(trace_collecting) QueryPerformanceCounter(&begin);
    LRESULT result=CallWindowProcW(traced_original,hwnd,msg,wp,lp);
    if(trace_collecting) {
        QueryPerformanceCounter(&end);
        int64_t usec=(end.QuadPart-begin.QuadPart)*1000000/traced_frequency.QuadPart;
        int slot=-1;
        for(int i=0;i<traced_count;i++) if(traced_messages[i].id==msg && traced_messages[i].event==(uintptr_t)wp) { slot=i; break; }
        if(slot<0 && traced_count<128) { slot=traced_count++; traced_messages[slot].id=msg; traced_messages[slot].event=(uintptr_t)wp; }
        if(slot>=0) { WindowMessageTiming *m=&traced_messages[slot]; m->count++; m->total+=usec; if(usec>m->max) m->max=usec; }
    }
    return result;
}
static void window_probe_stop(void) {
    if(traced_window && IsWindow(traced_window) && (WNDPROC)GetWindowLongPtrW(traced_window,GWLP_WNDPROC)==traced_window_proc)
        SetWindowLongPtrW(traced_window,GWLP_WNDPROC,(LONG_PTR)traced_original);
    traced_window=NULL; trace_collecting=0; device_guard_enabled=0; guard_unregister();
    free(known_devices); known_devices=NULL; known_count=0; known_valid=0;
}
static int window_probe_attach(HWND hwnd) {
    DWORD pid=0;
    if(!IsWindow(hwnd) || !GetWindowThreadProcessId(hwnd,&pid) || pid!=GetCurrentProcessId()) return 0;
    if(traced_window==hwnd) return 1;
    window_probe_stop(); QueryPerformanceFrequency(&traced_frequency);
    SetLastError(0);
    WNDPROC previous=(WNDPROC)SetWindowLongPtrW(hwnd,GWLP_WNDPROC,(LONG_PTR)traced_window_proc);
    if(!previous) return 0;
    traced_original=previous; traced_window=hwnd; return 1;
}
#else
static void window_probe_stop(void) {}
#endif
static const GDExtensionVariantType window_probe_types[]={N,BOOL};
static void window_probe_call(void *data,void *instance,const void *const *args,int64_t argc,void *out,GDExtensionCallError *error) {
    (void)data; (void)instance;
    if(!validate_args(args,argc,window_probe_types,2,error)) { return_nil(out); return; }
#ifdef _WIN32
    uint8_t start=0; to_bool(&start,(void *)args[1]);
    if(start) {
        if(!window_probe_attach((HWND)(uintptr_t)read_int(args[0]))) { return_nil(out); return; }
        memset(traced_messages,0,sizeof(traced_messages)); traced_count=0; trace_collecting=1;
    } else { trace_collecting=0; if(!device_guard_enabled) window_probe_stop(); }
    Value result; new_longs(&result,NULL);
    if(!resize(resize_longs,&result,traced_count*5)) { destroy_longs(&result); return_nil(out); return; }
    int64_t *values=traced_count?longs_mutable(&result,0):NULL;
    for(int i=0;i<traced_count;i++) {
        values[i*5]=traced_messages[i].id; values[i*5+1]=(int64_t)traced_messages[i].event;
        values[i*5+2]=traced_messages[i].count; values[i*5+3]=traced_messages[i].total; values[i*5+4]=traced_messages[i].max;
    }
    variant_destroy(out); from_longs(out,&result); destroy_longs(&result);
#else
    return_nil(out);
#endif
}
static void device_guard_call(void *data,void *instance,const void *const *args,int64_t argc,void *out,GDExtensionCallError *error) {
    (void)data; (void)instance;
    if(!validate_args(args,argc,window_probe_types,2,error)) { return_nil(out); return; }
#ifdef _WIN32
    uint8_t enabled=0; to_bool(&enabled,(void *)args[1]);
    if(enabled) {
        if(!window_probe_attach((HWND)(uintptr_t)read_int(args[0]))) { return_nil(out); return; }
        if(!guard_register(traced_window)) { if(!trace_collecting) window_probe_stop(); return_nil(out); return; } device_skipped=device_forwarded=device_query_errors=device_changed=0;
        input_devices_changed(); device_guard_enabled=1;
    }
    Value result; new_longs(&result,NULL);
    if(!resize(resize_longs,&result,5)) { destroy_longs(&result); return_nil(out); return; }
    int64_t *values=longs_mutable(&result,0);
    values[0]=device_guard_enabled; values[1]=device_skipped; values[2]=device_forwarded; values[3]=device_query_errors; values[4]=device_changed;
    if(!enabled) { device_guard_enabled=0; guard_unregister(); if(!trace_collecting) window_probe_stop(); }
    variant_destroy(out); from_longs(out,&result); destroy_longs(&result);
#else
    return_nil(out);
#endif
}

static const GDExtensionVariantType window_test_types[]={N};
static void device_guard_test_call(void *data,void *instance,const void *const *args,int64_t argc,void *out,GDExtensionCallError *error) {
    (void)data; (void)instance;
    if(!validate_args(args,argc,window_test_types,1,error)) { return_nil(out); return; }
#ifdef _WIN32
    HWND hwnd=(HWND)(uintptr_t)read_int(args[0]);
    if(hwnd!=traced_window || !device_guard_enabled || !IsWindow(hwnd)) { return_nil(out); return; }
    int64_t skipped=device_skipped,forwarded=device_forwarded;
    WNDPROC original=traced_original;
    SendMessageW(hwnd,WM_DEVICECHANGE,DBT_DEVNODES_CHANGED,0);
    DEV_BROADCAST_DEVICEINTERFACE_W notice={0}; notice.dbcc_size=sizeof(notice);
    notice.dbcc_devicetype=DBT_DEVTYP_DEVICEINTERFACE; notice.dbcc_classguid=guard_hid_guid;
    SendMessageW(hwnd,WM_DEVICECHANGE,DBT_DEVICEARRIVAL,(LPARAM)&notice);
    int64_t skip_delta=device_skipped-skipped,forward_delta=device_forwarded-forwarded;
    window_probe_stop();
    Value result; new_longs(&result,NULL);
    if(!resize(resize_longs,&result,3)) { destroy_longs(&result); return_nil(out); return; }
    int64_t *values=longs_mutable(&result,0);
    values[0]=skip_delta; values[1]=forward_delta; values[2]=((WNDPROC)GetWindowLongPtrW(hwnd,GWLP_WNDPROC)==original);
    variant_destroy(out); from_longs(out,&result); destroy_longs(&result);
#else
    return_nil(out);
#endif
}