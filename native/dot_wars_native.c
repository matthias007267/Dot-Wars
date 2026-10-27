/* DOT WARS: deterministic grid kernels through Godot's public GDExtension C ABI.
 * No Godot Nodes per worker; no worker state or gameplay policy lives here.
 */
#include "gdextension_interface.h"
#include <stdint.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>

typedef union { max_align_t alignment; unsigned char bytes[64]; } Value;
typedef struct { int32_t *queue, *parent; uint32_t *seen; size_t count, queue_capacity; uint32_t stamp; void *army_cache; } Search;
static GDExtensionClassLibraryPtr library;
static Value class_name, parent_name, empty_name, empty_string;
static GDExtensionInterfaceStringNameNewWithUtf8Chars sn_new;
static GDExtensionInterfaceStringNewWithUtf8Chars string_new;
static GDExtensionInterfaceClassdbConstructObject construct_object;
static GDExtensionInterfaceObjectSetInstance set_instance;
static GDExtensionInterfaceClassdbRegisterExtensionClass3 register_class;
static GDExtensionInterfaceClassdbUnregisterExtensionClass unregister_class;
static GDExtensionInterfaceClassdbRegisterExtensionClassMethod register_method;
static GDExtensionInterfaceVariantGetType variant_type;
static GDExtensionInterfaceVariantDestroy variant_destroy;
static GDExtensionInterfaceVariantNewNil variant_nil;
static GDExtensionInterfaceVariantHasKey has_key;
static GDExtensionInterfacePackedByteArrayOperatorIndexConst bytes_const;
static GDExtensionInterfacePackedInt32ArrayOperatorIndexConst ints_const;
static GDExtensionInterfacePackedByteArrayOperatorIndex bytes_mutable;
static GDExtensionInterfacePackedInt32ArrayOperatorIndex ints_mutable;
static GDExtensionInterfaceArrayOperatorIndex array_at;
static GDExtensionInterfacePackedInt64ArrayOperatorIndex longs_mutable;
static GDExtensionVariantFromTypeConstructorFunc from_longs;
static GDExtensionPtrConstructor new_bytes, new_longs;
static GDExtensionPtrDestructor destroy_longs;
static GDExtensionPtrBuiltInMethod resize_bytes, resize_longs;
static GDExtensionTypeFromVariantConstructorFunc to_bytes, to_ints, to_int, to_bool;
static GDExtensionVariantFromTypeConstructorFunc from_int, from_bytes, from_ints, from_array;
static GDExtensionPtrDestructor destroy_bytes, destroy_ints, destroy_array, destroy_sn, destroy_string;
static GDExtensionPtrConstructor new_array, new_ints;
static GDExtensionPtrBuiltInMethod size_bytes, size_ints, resize_ints, resize_array;

static int64_t read_int(GDExtensionConstVariantPtr v) { int64_t x; to_int(&x, (void *)v); return x; }
static int64_t array_size(GDExtensionPtrBuiltInMethod fn, void *a) { int64_t n=0; fn(a,NULL,&n,0); return n; }
static void return_int(void *out, int64_t n) { variant_destroy(out); from_int(out,&n); }
static void return_nil(void *out) { variant_destroy(out); variant_nil(out); }
static int resize(GDExtensionPtrBuiltInMethod fn, void *a, int64_t n) { const void *args[]={&n}; int64_t result=0; fn(a,args,&result,1); return result==0; }
static int grow_queue(Search *s, size_t needed) {
    if (needed<=s->queue_capacity) return 1;
    if (needed>(size_t)INT32_MAX || needed>SIZE_MAX/sizeof(int32_t)) return 0;
    size_t capacity=s->queue_capacity?s->queue_capacity:256;
    while (capacity<needed) { if (capacity>(size_t)INT32_MAX/2) { capacity=needed; break; } capacity*=2; }
    int32_t *p=realloc(s->queue,capacity*sizeof(int32_t));
    if (!p) return 0;
    s->queue=p; s->queue_capacity=capacity; return 1;
}
static int prepare(Search *s, size_t n) {
    if (!grow_queue(s,n)) return 0;
    if (n>s->count) {
        int32_t *p=realloc(s->parent,n*sizeof(int32_t)); if (!p) return 0; s->parent=p;
        uint32_t *v=realloc(s->seen,n*sizeof(uint32_t)); if (!v) return 0; s->seen=v;
        memset(s->seen+s->count,0,(n-s->count)*sizeof(uint32_t)); s->count=n;
    }
    if (++s->stamp==0) { memset(s->seen,0,s->count*sizeof(uint32_t)); s->stamp=1; }
    return 1;
}
static int32_t neighbor(int32_t c, int d, int32_t w, int32_t n) {
    switch(d) {
        case 0: return c>=w?c-w:-1;
        case 1: return c%w<w-1?c+1:-1;
        case 2: return c<n-w?c+w:-1;
        default: return c%w>0?c-1:-1;
    }
}
static int open_cell(int32_t c, const uint8_t *cells, const uint8_t *blocked, int64_t blocked_n) {
    return cells[c]==0 && (c>=blocked_n || blocked[c]==0);
}
static int validate_args(const void *const *args, int64_t argc, const GDExtensionVariantType *types, int count, GDExtensionCallError *error) {
    error->error=GDEXTENSION_CALL_OK;
    if (argc!=count) { error->error=argc<count?GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS:GDEXTENSION_CALL_ERROR_TOO_MANY_ARGUMENTS; error->expected=count; return 0; }
    for (int i=0;i<count;i++) if (variant_type(args[i])!=types[i]) {
        error->error=GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT; error->argument=i; error->expected=types[i]; return 0;
    }
    return 1;
}
#define B GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY
#define I GDEXTENSION_VARIANT_TYPE_PACKED_INT32_ARRAY
#define N GDEXTENSION_VARIANT_TYPE_INT
#define D GDEXTENSION_VARIANT_TYPE_DICTIONARY
#define BOOL GDEXTENSION_VARIANT_TYPE_BOOL
static const GDExtensionVariantType search_types[]={B,I,B,B,D,N,N,N,N,N,N};
static const GDExtensionVariantType flow_types[]={B,B,I,B,I,N,N,BOOL,N};

/* target<0: nearest unclaimed marked rock, otherwise the first path step.
 * Budgets count valid neighbor examinations, including the original continue
 * behavior at the budget boundary. N/E/S/W ordering is deliberately unchanged.
 */
static void search_call(void *data, void *instance, const void *const *args, int64_t argc, void *out, GDExtensionCallError *error) {
    (void)data;
    if (!validate_args(args,argc,search_types,11,error) || !instance) { return_int(out,-1); return; }
    Search *s=instance;
    Value ca,oa,ma,ba; to_bytes(&ca,(void *)args[0]); to_ints(&oa,(void *)args[1]); to_bytes(&ma,(void *)args[2]); to_bytes(&ba,(void *)args[3]);
    int64_t n=array_size(size_bytes,&ca), on=array_size(size_ints,&oa), mn=array_size(size_bytes,&ma), bn=array_size(size_bytes,&ba);
    int64_t faction=read_int(args[5]), w64=read_int(args[6]), origin64=read_int(args[7]), budget=read_int(args[8]), target64=read_int(args[9]), ban=read_int(args[10]);
    int64_t result=-1;
    if (n<=0 || n>16777216 || on!=n || mn!=n || bn>n || w64<=0 || w64>n || n%w64 || origin64<0 || origin64>=n || target64>=n || faction<0 || faction>255 || budget<0) goto cleanup;
    const uint8_t *cells=bytes_const(&ca,0), *mask=bytes_const(&ma,0), *blocked=bn?bytes_const(&ba,0):NULL;
    const int32_t *occ=ints_const(&oa,0);
    int32_t w=(int32_t)w64, origin=(int32_t)origin64, target=(int32_t)target64;
    if (target<0 && !open_cell(origin,cells,blocked,bn)) goto cleanup;
    if (target>=0) for(int d=0;d<4;d++) if(neighbor(origin,d,w,(int32_t)n)==target) { result=origin; goto cleanup; }
    if (!prepare(s,(size_t)n)) goto cleanup;
    s->seen[origin]=s->stamp; s->parent[origin]=-1; s->queue[0]=origin;
    size_t head=0,tail=1; int32_t stand=-1;
    while(head<tail && budget>0 && stand<0) {
        int32_t c=s->queue[head++];
        for(int d=0;d<4;d++) {
            int32_t next=neighbor(c,d,w,(int32_t)n); if(next<0) continue;
            budget--;
            if(target<0) {
                if(cells[next]>=1 && cells[next]<=12 && cells[next]!=4 && mask[next]==1 && next!=ban) {
                    Value key; int64_t raw=faction*16777216+next; from_int(&key,&raw);
                    GDExtensionBool valid=0; int claimed=has_key(args[4],&key,&valid); variant_destroy(&key);
                    if(valid && !claimed) { result=next; goto cleanup; }
                }
                if(s->seen[next]!=s->stamp && open_cell(next,cells,blocked,bn) && occ[next]==-1) {
                    s->seen[next]=s->stamp; s->queue[tail++]=next;
                }
            } else {
                if(next==target) { stand=c; break; }
                if(s->seen[next]==s->stamp) continue;
                if(open_cell(next,cells,blocked,bn) && occ[next]==-1) {
                    s->seen[next]=s->stamp; s->parent[next]=c; s->queue[tail++]=next;
                }
            }
            if(budget<=0) break;
        }
    }
    if(stand>=0) {
        int32_t step=stand;
        while(s->parent[step]!=origin && s->parent[step]>=0) step=s->parent[step];
        result=step;
    }
cleanup:
    destroy_bytes(&ca); destroy_ints(&oa); destroy_bytes(&ma); destroy_bytes(&ba); return_int(out,result);
}

/* Returns explicit output arrays: no dependency on argument copy-on-write.
 * The caller retains publication, area bookkeeping and all gameplay policy.
 */
static void flow_call(void *data, void *instance, const void *const *args, int64_t argc, void *out, GDExtensionCallError *error) {
    (void)data;
    if(!validate_args(args,argc,flow_types,9,error) || !instance) { return_nil(out); return; }
    Search *s=instance; Value ca,ba,da,ra,qa;
    to_bytes(&ca,(void *)args[0]); to_bytes(&ba,(void *)args[1]); to_ints(&da,(void *)args[2]); to_bytes(&ra,(void *)args[3]); to_ints(&qa,(void *)args[4]);
    int64_t n=array_size(size_bytes,&ca),bn=array_size(size_bytes,&ba),dn=array_size(size_ints,&da),rn=array_size(size_bytes,&ra),qn=array_size(size_ints,&qa);
    int64_t head=read_int(args[5]),remaining=read_int(args[6]),w64=read_int(args[8]); uint8_t improve=0; to_bool(&improve,(void *)args[7]);
    int valid=0;
    if(n<=0 || n>16777216 || dn!=n || rn!=n || bn>n || head<0 || head>qn || qn>INT32_MAX || remaining<0 || w64<=0 || w64>n || n%w64) goto cleanup;
    if(!grow_queue(s,(size_t)qn)) goto cleanup;
    const uint8_t *cells=bytes_const(&ca,0),*blocked=bn?bytes_const(&ba,0):NULL;
    const int32_t *input=qn?ints_const(&qa,0):NULL;
    if(qn) memcpy(s->queue,input,(size_t)qn*sizeof(int32_t));
    for(int64_t i=0;i<qn;i++) if(s->queue[i]<0 || s->queue[i]>=n) goto cleanup;
    int32_t *dist=ints_mutable(&da,0); uint8_t *dirs=bytes_mutable(&ra,0); int32_t w=(int32_t)w64;
    size_t tail=(size_t)qn;
    while((size_t)head<tail) {
        if(remaining<=0) break;
        remaining--; int32_t c=s->queue[head++],distance=dist[c]+1;
        /* Existing flow-field tie order is W/E/N/S, unlike personal search. */
        int32_t nexts[]={c%w>0?c-1:-1,c%w<w-1?c+1:-1,c>=w?c-w:-1,c<n-w?c+w:-1};
        const uint8_t directions[]={2,4,3,1};
        for(int d=0;d<4;d++) {
            int32_t next=nexts[d]; if(next<0 || !open_cell(next,cells,blocked,bn)) continue;
            if(improve) { if(dist[next]!=-1 && dist[next]<=distance) continue; }
            else if(dist[next]!=-1) continue;
            if(!grow_queue(s,tail+1)) goto cleanup;
            dist[next]=distance; dirs[next]=directions[d]; s->queue[tail++]=next;
        }
    }
    if(!resize(resize_ints,&qa,(int64_t)tail)) goto cleanup;
    if(tail) memcpy(ints_mutable(&qa,0),s->queue,tail*sizeof(int32_t));
    Value result; new_array(&result,NULL);
    if(!resize(resize_array,&result,5)) { destroy_array(&result); goto cleanup; }
    void *v=array_at(&result,0); variant_destroy(v); from_ints(v,&da);
    v=array_at(&result,1); variant_destroy(v); from_bytes(v,&ra);
    v=array_at(&result,2); variant_destroy(v); from_ints(v,&qa);
    v=array_at(&result,3); variant_destroy(v); from_int(v,&head);
    v=array_at(&result,4); variant_destroy(v); from_int(v,&remaining);
    variant_destroy(out); from_array(out,&result); destroy_array(&result); valid=1;
cleanup:
    destroy_bytes(&ca); destroy_bytes(&ba); destroy_ints(&da); destroy_bytes(&ra); destroy_ints(&qa);
    if(!valid) return_nil(out);
}

/* One snapshot of immutable neighbourhoods before the sequential swarm pass.
 * Search changes aims, never occupancy: changed aims use the reference watcher.
 */
static const GDExtensionVariantType neighborhood_types[]={B,I,I,B,I,N};
static void neighborhood_call(void *data,void *instance,const void *const *args,int64_t argc,void *out,GDExtensionCallError *error) {
    (void)data; (void)instance;
    if(!validate_args(args,argc,neighborhood_types,6,error)) { return_nil(out); return; }
    Value ca,oa,wa,fa,aa,boxed,watches;
    to_bytes(&ca,(void *)args[0]); to_ints(&oa,(void *)args[1]); to_ints(&wa,(void *)args[2]);
    to_bytes(&fa,(void *)args[3]); to_ints(&aa,(void *)args[4]);
    new_bytes(&boxed,NULL); new_longs(&watches,NULL);
    int valid=0;
    int64_t n=array_size(size_bytes,&ca),count=array_size(size_ints,&wa),w=read_int(args[5]);
    if(n<=0 || n>16777216 || w<=0 || n%w || array_size(size_ints,&oa)!=n || array_size(size_bytes,&fa)!=count || array_size(size_ints,&aa)!=count) goto cleanup;
    if(!resize(resize_bytes,&boxed,count) || !resize(resize_longs,&watches,count)) goto cleanup;
    const uint8_t *cells=bytes_const(&ca,0),*factions=count?bytes_const(&fa,0):NULL;
    const int32_t *occ=ints_const(&oa,0),*workers=count?ints_const(&wa,0):NULL,*aims=count?ints_const(&aa,0):NULL;
    uint8_t *b=count?bytes_mutable(&boxed,0):NULL; int64_t *watch=count?longs_mutable(&watches,0):NULL;
    for(int64_t id=0;id<count;id++) {
        int32_t cell=workers[id]; if(cell<0 || cell>=n) goto cleanup;
        int64_t sig=(int64_t)aims[id]*3+cell+1; int is_boxed=1,neighbors=0;
        for(int d=0;d<4;d++) {
            int32_t next=neighbor(cell,d,(int32_t)w,(int32_t)n); if(next<0) continue;
            neighbors++; int32_t occupant=occ[next];
            sig=sig*11+occupant+(int64_t)cells[next]*17;
            if(occupant<0 || occupant==id || occupant>=count || factions[occupant]!=factions[id]) is_boxed=0;
        }
        b[id]=(uint8_t)(neighbors && is_boxed); watch[id]=sig;
    }
    Value result; new_array(&result,NULL);
    if(!resize(resize_array,&result,2)) { destroy_array(&result); goto cleanup; }
    void *v=array_at(&result,0); variant_destroy(v); from_bytes(v,&boxed);
    v=array_at(&result,1); variant_destroy(v); from_longs(v,&watches);
    variant_destroy(out); from_array(out,&result); destroy_array(&result); valid=1;
cleanup:
    destroy_bytes(&ca); destroy_ints(&oa); destroy_ints(&wa); destroy_bytes(&fa); destroy_ints(&aa);
    destroy_bytes(&boxed); destroy_longs(&watches); if(!valid) return_nil(out);
}
static const GDExtensionVariantType nearest_types[]={B,B,I,N,N};
static void nearest_call(void *data,void *instance,const void *const *args,int64_t argc,void *out,GDExtensionCallError *error) {
    (void)data;
    if(!validate_args(args,argc,nearest_types,5,error) || !instance) { return_int(out,-1); return; }
    Search *s=instance; Value ca,ba,aa;
    to_bytes(&ca,(void *)args[0]); to_bytes(&ba,(void *)args[1]); to_ints(&aa,(void *)args[2]);
    int64_t n=array_size(size_bytes,&ca),bn=array_size(size_bytes,&ba),an=array_size(size_ints,&aa),w64=read_int(args[3]),goal64=read_int(args[4]),result=-1;
    if(n<=0 || n>16777216 || bn>n || w64<=0 || w64>n || n%w64 || goal64<0 || goal64>=n) goto cleanup;
    const uint8_t *cells=bytes_const(&ca,0),*blocked=bn?bytes_const(&ba,0):NULL;
    const int32_t *anchors=an?ints_const(&aa,0):NULL;
    int32_t w=(int32_t)w64,goal=(int32_t)goal64;
    if(!an) { if(open_cell(goal,cells,blocked,bn)) result=goal; goto cleanup; }
    if(!prepare(s,(size_t)n)) goto cleanup;
    int best_rank=INT_MAX; size_t head=0,tail=0;
    for(int64_t i=0;i<an;i++) {
        int32_t cell=anchors[i];
        if(cell<0 || cell>=n || s->seen[cell]==s->stamp || !open_cell(cell,cells,blocked,bn)) continue;
        s->seen[cell]=s->stamp; s->queue[tail++]=cell;
        int rank=abs(cell%w-goal%w)+abs(cell/w-goal/w);
        if(rank<best_rank) { best_rank=rank; result=cell; }
        if(!best_rank) goto cleanup;
    }
    while(head<tail) {
        int32_t cell=s->queue[head++];
        for(int d=0;d<4;d++) {
            int32_t next=neighbor(cell,d,w,(int32_t)n);
            if(next<0 || s->seen[next]==s->stamp || !open_cell(next,cells,blocked,bn)) continue;
            s->seen[next]=s->stamp; s->queue[tail++]=next;
            int rank=abs(next%w-goal%w)+abs(next/w-goal/w);
            if(rank<best_rank) { best_rank=rank; result=next; }
            if(!best_rank) goto cleanup;
        }
    }
cleanup:
    destroy_bytes(&ca); destroy_bytes(&ba); destroy_ints(&aa); return_int(out,result);
}
#include "movement_kernel.inc"
#include "energy_kernel.inc"
#include "army_cache.inc"
#include "army_corners.inc"
#include "army_kernel.inc"
#include "fog_kernel.inc"
#include "window_probe.inc"

static void *create(void *data) {
    (void)data; Search *s=calloc(1,sizeof(Search)); if(!s) return NULL;
    void *object=construct_object(&parent_name);
    if(!object) { free(s); return NULL; }
    set_instance(object,&class_name,s); return object;
}
static void release(void *data,void *instance) {
    (void)data; Search *s=instance; if(!s) return;
    free(s->queue); free(s->parent); free(s->seen); army_cache_free(s->army_cache); free(s);
}
static void bind_method(const char *name,GDExtensionClassMethodCall fn,const GDExtensionVariantType *types,int argc,GDExtensionVariantType result_type) {
    Value method_name; sn_new(&method_name,name);
    GDExtensionPropertyInfo info[16]={0},result={0};
    GDExtensionClassMethodArgumentMetadata metadata[16]={0};
    for(int i=0;i<argc;i++) { info[i].type=types[i]; info[i].name=&empty_name; info[i].class_name=&empty_name; info[i].hint_string=&empty_string; info[i].usage=6; }
    result.type=result_type; result.name=&empty_name; result.class_name=&empty_name; result.hint_string=&empty_string; result.usage=6;
    GDExtensionClassMethodInfo method={0}; method.name=&method_name; method.call_func=fn; method.method_flags=GDEXTENSION_METHOD_FLAG_NORMAL;
    method.has_return_value=1; method.return_value_info=&result; method.argument_count=argc; method.arguments_info=info; method.arguments_metadata=metadata;
    register_method(library,&class_name,&method); destroy_sn(&method_name);
}
static void initialize(void *data,GDExtensionInitializationLevel level) {
    (void)data; if(level!=GDEXTENSION_INITIALIZATION_SCENE) return;
    sn_new(&class_name,"DotWarsNativeSearch"); sn_new(&parent_name,"RefCounted"); sn_new(&empty_name,""); string_new(&empty_string,"");
    GDExtensionClassCreationInfo3 info={0}; info.is_exposed=1; info.create_instance_func=create; info.free_instance_func=release;
    register_class(library,&class_name,&parent_name,&info);
    bind_method("neighborhoods",neighborhood_call,neighborhood_types,6,GDEXTENSION_VARIANT_TYPE_ARRAY);
    bind_method("nearest_stand",nearest_call,nearest_types,5,N);
    bind_method("move_workers",movement_call,movement_types,10,GDEXTENSION_VARIANT_TYPE_ARRAY);
    bind_method("energy_next",energy_call,energy_types,5,I);
    bind_method("army_step",army_call,army_types,5,GDEXTENSION_VARIANT_TYPE_ARRAY);
    bind_method("army_step_cached",army_cached_call,army_types,5,GDEXTENSION_VARIANT_TYPE_ARRAY);
    bind_method("fog_visible_depth",fog_call,fog_types,4,GDEXTENSION_VARIANT_TYPE_ARRAY);
    bind_method("army_route_stats",army_route_stats_call,NULL,0,GDEXTENSION_VARIANT_TYPE_PACKED_INT64_ARRAY);
    bind_method("trace_window",window_probe_call,window_probe_types,2,GDEXTENSION_VARIANT_TYPE_PACKED_INT64_ARRAY);
    bind_method("device_change_guard",device_guard_call,window_probe_types,2,GDEXTENSION_VARIANT_TYPE_PACKED_INT64_ARRAY);
    bind_method("device_change_guard_self_test",device_guard_test_call,window_test_types,1,GDEXTENSION_VARIANT_TYPE_PACKED_INT64_ARRAY);
    bind_method("search",search_call,search_types,11,N);
    bind_method("flow_spread",flow_call,flow_types,9,GDEXTENSION_VARIANT_TYPE_ARRAY);
}
static void deinitialize(void *data,GDExtensionInitializationLevel level) {
    (void)data; if(level!=GDEXTENSION_INITIALIZATION_SCENE) return;
    window_probe_stop(); unregister_class(library,&class_name); destroy_sn(&class_name); destroy_sn(&parent_name); destroy_sn(&empty_name); destroy_string(&empty_string);
}
#if defined(_WIN32)
#define EXPORT __declspec(dllexport)
#else
#define EXPORT __attribute__((visibility("default")))
#endif
#define LOAD(variable,type,name) do { variable=(type)get_proc(name); if(!variable) return 0; } while(0)
EXPORT GDExtensionBool dot_wars_native_init(GDExtensionInterfaceGetProcAddress get_proc,GDExtensionClassLibraryPtr lib,GDExtensionInitialization *init) {
    library=lib;
    LOAD(sn_new,GDExtensionInterfaceStringNameNewWithUtf8Chars,"string_name_new_with_utf8_chars");
    LOAD(string_new,GDExtensionInterfaceStringNewWithUtf8Chars,"string_new_with_utf8_chars");
    LOAD(construct_object,GDExtensionInterfaceClassdbConstructObject,"classdb_construct_object");
    LOAD(set_instance,GDExtensionInterfaceObjectSetInstance,"object_set_instance");
    LOAD(register_class,GDExtensionInterfaceClassdbRegisterExtensionClass3,"classdb_register_extension_class3");
    LOAD(unregister_class,GDExtensionInterfaceClassdbUnregisterExtensionClass,"classdb_unregister_extension_class");
    LOAD(register_method,GDExtensionInterfaceClassdbRegisterExtensionClassMethod,"classdb_register_extension_class_method");
    LOAD(variant_type,GDExtensionInterfaceVariantGetType,"variant_get_type");
    LOAD(variant_destroy,GDExtensionInterfaceVariantDestroy,"variant_destroy");
    LOAD(variant_nil,GDExtensionInterfaceVariantNewNil,"variant_new_nil");
    LOAD(has_key,GDExtensionInterfaceVariantHasKey,"variant_has_key");
    LOAD(bytes_const,GDExtensionInterfacePackedByteArrayOperatorIndexConst,"packed_byte_array_operator_index_const");
    LOAD(ints_const,GDExtensionInterfacePackedInt32ArrayOperatorIndexConst,"packed_int32_array_operator_index_const");
    LOAD(bytes_mutable,GDExtensionInterfacePackedByteArrayOperatorIndex,"packed_byte_array_operator_index");
    LOAD(ints_mutable,GDExtensionInterfacePackedInt32ArrayOperatorIndex,"packed_int32_array_operator_index");
    LOAD(longs_mutable,GDExtensionInterfacePackedInt64ArrayOperatorIndex,"packed_int64_array_operator_index");
    LOAD(array_const,GDExtensionInterfaceArrayOperatorIndexConst,"array_operator_index_const");
    LOAD(array_at,GDExtensionInterfaceArrayOperatorIndex,"array_operator_index");
    GDExtensionInterfaceGetVariantToTypeConstructor to_type;
    GDExtensionInterfaceGetVariantFromTypeConstructor from_type;
    GDExtensionInterfaceVariantGetPtrDestructor destructor;
    GDExtensionInterfaceVariantGetPtrConstructor constructor;
    GDExtensionInterfaceVariantGetPtrBuiltinMethod builtin;
    LOAD(to_type,GDExtensionInterfaceGetVariantToTypeConstructor,"get_variant_to_type_constructor");
    LOAD(from_type,GDExtensionInterfaceGetVariantFromTypeConstructor,"get_variant_from_type_constructor");
    LOAD(destructor,GDExtensionInterfaceVariantGetPtrDestructor,"variant_get_ptr_destructor");
    LOAD(constructor,GDExtensionInterfaceVariantGetPtrConstructor,"variant_get_ptr_constructor");
    LOAD(builtin,GDExtensionInterfaceVariantGetPtrBuiltinMethod,"variant_get_ptr_builtin_method");
    to_array=to_type(GDEXTENSION_VARIANT_TYPE_ARRAY);
    to_bytes=to_type(B); to_ints=to_type(I); to_int=to_type(N); to_bool=to_type(BOOL);
    from_int=from_type(N); from_bytes=from_type(B); from_ints=from_type(I); from_array=from_type(GDEXTENSION_VARIANT_TYPE_ARRAY);
    destroy_bytes=destructor(B); destroy_ints=destructor(I); destroy_array=destructor(GDEXTENSION_VARIANT_TYPE_ARRAY);
    destroy_sn=destructor(GDEXTENSION_VARIANT_TYPE_STRING_NAME); destroy_string=destructor(GDEXTENSION_VARIANT_TYPE_STRING);
    from_longs=from_type(GDEXTENSION_VARIANT_TYPE_PACKED_INT64_ARRAY);
    new_bytes=constructor(B,0); new_longs=constructor(GDEXTENSION_VARIANT_TYPE_PACKED_INT64_ARRAY,0);
    destroy_longs=destructor(GDEXTENSION_VARIANT_TYPE_PACKED_INT64_ARRAY);
    new_array=constructor(GDEXTENSION_VARIANT_TYPE_ARRAY,0); new_ints=constructor(I,0);
    Value size_name,resize_name; sn_new(&size_name,"size"); sn_new(&resize_name,"resize");
    size_array=builtin(GDEXTENSION_VARIANT_TYPE_ARRAY,&size_name,3173160232LL);
    size_bytes=builtin(B,&size_name,3173160232LL); size_ints=builtin(I,&size_name,3173160232LL);
    resize_ints=builtin(I,&resize_name,848867239); resize_array=builtin(GDEXTENSION_VARIANT_TYPE_ARRAY,&resize_name,848867239);
    resize_bytes=builtin(B,&resize_name,848867239); resize_longs=builtin(GDEXTENSION_VARIANT_TYPE_PACKED_INT64_ARRAY,&resize_name,848867239);
    destroy_sn(&size_name); destroy_sn(&resize_name);
    if(!size_bytes || !size_ints || !resize_ints || !resize_array || !new_array || !new_ints) return 0;
    init->minimum_initialization_level=GDEXTENSION_INITIALIZATION_SCENE;
    init->initialize=initialize; init->deinitialize=deinitialize; init->userdata=NULL; return 1;
}
