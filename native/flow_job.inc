/* A budgeted flow-field build that stays in native memory between calls. The
 * spread loop is exactly flow_spread's (W/E/N/S ties, budget per dequeued cell,
 * live terrain each call); only the copy-on-write of the whole field per call is
 * avoided. Each FlowField owns its own instance, so the job dies with it. */
static const GDExtensionVariantType job_begin_types[]={B,B,I,B,I,N,N,BOOL,N};
static const GDExtensionVariantType job_step_types[]={B,B,N,N};
static void job_drop(Search *s) { s->job_active=0; }
static int job_reserve(Search *s,int64_t n,int64_t queue) {
    if(s->job_n!=n) {
        free(s->job_dist); free(s->job_dir); s->job_dist=malloc((size_t)n*sizeof(int32_t)); s->job_dir=malloc((size_t)n); s->job_n=n;
        if(!s->job_dist || !s->job_dir) { free(s->job_dist); free(s->job_dir); s->job_dist=NULL; s->job_dir=NULL; s->job_n=0; return 0; }
    }
    if(queue>s->job_capacity) {
        int64_t capacity=s->job_capacity?s->job_capacity:256;
        while(capacity<queue) capacity*=2;
        int32_t *grown=realloc(s->job_queue,(size_t)capacity*sizeof(int32_t)); if(!grown) return 0;
        s->job_queue=grown; s->job_capacity=capacity;
    }
    return 1;
}
/* Returns the remaining budget, or -1 when the queue could not grow. */
static int64_t job_run(Search *s,const uint8_t *cells,const uint8_t *blocked,int64_t bn,int32_t w,int64_t remaining) {
    int32_t n=(int32_t)s->job_n; int32_t *dist=s->job_dist; uint8_t *dirs=s->job_dir;
    while(s->job_head<s->job_tail) {
        if(remaining<=0) break;
        remaining--; int32_t c=s->job_queue[s->job_head++],distance=dist[c]+1;
        int32_t nexts[]={c%w>0?c-1:-1,c%w<w-1?c+1:-1,c>=w?c-w:-1,c<n-w?c+w:-1};
        const uint8_t directions[]={2,4,3,1};
        for(int d=0;d<4;d++) {
            int32_t next=nexts[d]; if(next<0 || !open_cell(next,cells,blocked,bn)) continue;
            if(s->job_improve) { if(dist[next]!=-1 && dist[next]<=distance) continue; }
            else if(dist[next]!=-1) continue;
            if(s->job_tail>=s->job_capacity && !job_reserve(s,n,s->job_tail+1)) return -1;
            dist[next]=distance; dirs[next]=directions[d]; s->job_queue[s->job_tail++]=next;
        }
    }
    return remaining;
}
/* [done, head, remaining, dist, dir, queue]; arrays only when finished or exported. */
static int job_result(Search *s,void *out,int64_t remaining,int with_arrays) {
    Value result; new_array(&result,NULL);
    if(!resize(resize_array,&result,6)) { destroy_array(&result); return 0; }
    int64_t done=s->job_head>=s->job_tail,head=s->job_head;
    void *v=array_at(&result,0); variant_destroy(v); from_int(v,&done);
    v=array_at(&result,1); variant_destroy(v); from_int(v,&head);
    v=array_at(&result,2); variant_destroy(v); from_int(v,&remaining);
    if(done || with_arrays) {
        Value da,ra,qa; new_ints(&da,NULL); new_bytes(&ra,NULL); new_ints(&qa,NULL);
        if(!resize(resize_ints,&da,s->job_n) || !resize(resize_bytes,&ra,s->job_n) || !resize(resize_ints,&qa,s->job_tail)) {
            destroy_ints(&da); destroy_bytes(&ra); destroy_ints(&qa); destroy_array(&result); return 0;
        }
        memcpy(ints_mutable(&da,0),s->job_dist,(size_t)s->job_n*sizeof(int32_t));
        memcpy(bytes_mutable(&ra,0),s->job_dir,(size_t)s->job_n);
        if(s->job_tail) memcpy(ints_mutable(&qa,0),s->job_queue,(size_t)s->job_tail*sizeof(int32_t));
        v=array_at(&result,3); variant_destroy(v); from_ints(v,&da);
        v=array_at(&result,4); variant_destroy(v); from_bytes(v,&ra);
        v=array_at(&result,5); variant_destroy(v); from_ints(v,&qa);
        destroy_ints(&da); destroy_bytes(&ra); destroy_ints(&qa);
    }
    if(done) job_drop(s);
    variant_destroy(out); from_array(out,&result); destroy_array(&result); return 1;
}
static void job_begin_call(void *data,void *instance,const void *const *args,int64_t argc,void *out,GDExtensionCallError *error) {
    (void)data;
    if(!validate_args(args,argc,job_begin_types,9,error) || !instance) { return_nil(out); return; }
    Search *s=instance; job_drop(s); Value ca,ba,da,ra,qa;
    to_bytes(&ca,(void *)args[0]); to_bytes(&ba,(void *)args[1]); to_ints(&da,(void *)args[2]); to_bytes(&ra,(void *)args[3]); to_ints(&qa,(void *)args[4]);
    int64_t n=array_size(size_bytes,&ca),bn=array_size(size_bytes,&ba),dn=array_size(size_ints,&da),rn=array_size(size_bytes,&ra),qn=array_size(size_ints,&qa);
    int64_t head=read_int(args[5]),remaining=read_int(args[6]),w64=read_int(args[8]); uint8_t improve=0; to_bool(&improve,(void *)args[7]);
    int valid=0;
    if(n<=0 || n>16777216 || dn!=n || rn!=n || bn>n || head<0 || head>qn || qn>INT32_MAX || remaining<0 || w64<=0 || w64>n || n%w64) goto cleanup;
    const int32_t *queue=qn?ints_const(&qa,0):NULL;
    for(int64_t i=0;i<qn;i++) if(queue[i]<0 || queue[i]>=n) goto cleanup;
    if(!job_reserve(s,n,qn>256?qn:256)) goto cleanup;
    memcpy(s->job_dist,ints_const(&da,0),(size_t)n*sizeof(int32_t));
    memcpy(s->job_dir,bytes_const(&ra,0),(size_t)n);
    if(qn) memcpy(s->job_queue,queue,(size_t)qn*sizeof(int32_t));
    s->job_head=head; s->job_tail=qn; s->job_improve=improve; s->job_width=(int32_t)w64; s->job_active=1;
    remaining=job_run(s,bytes_const(&ca,0),bn?bytes_const(&ba,0):NULL,bn,(int32_t)w64,remaining);
    if(remaining<0 || !job_result(s,out,remaining,0)) { job_drop(s); goto cleanup; }
    valid=1;
cleanup:
    destroy_bytes(&ca); destroy_bytes(&ba); destroy_ints(&da); destroy_bytes(&ra); destroy_ints(&qa);
    if(!valid) return_nil(out);
}
static void job_step_call(void *data,void *instance,const void *const *args,int64_t argc,void *out,GDExtensionCallError *error) {
    (void)data;
    if(!validate_args(args,argc,job_step_types,4,error) || !instance) { return_nil(out); return; }
    Search *s=instance; Value ca,ba; to_bytes(&ca,(void *)args[0]); to_bytes(&ba,(void *)args[1]);
    int64_t n=array_size(size_bytes,&ca),bn=array_size(size_bytes,&ba),remaining=read_int(args[2]),w64=read_int(args[3]);
    int valid=0;
    if(!s->job_active || n!=s->job_n || bn>n || remaining<0 || w64!=s->job_width) goto cleanup;
    remaining=job_run(s,bytes_const(&ca,0),bn?bytes_const(&ba,0):NULL,bn,(int32_t)w64,remaining);
    if(remaining<0 || !job_result(s,out,remaining,0)) goto cleanup;
    valid=1;
cleanup:
    destroy_bytes(&ca); destroy_bytes(&ba);
    if(!valid) return_nil(out);
}
/* Current arrays of an unfinished job (save, inspection); the job continues. */
static void job_export_call(void *data,void *instance,const void *const *args,int64_t argc,void *out,GDExtensionCallError *error) {
    (void)data;
    if(!validate_args(args,argc,NULL,0,error) || !instance || !((Search *)instance)->job_active) { return_nil(out); return; }
    if(!job_result(instance,out,0,1)) return_nil(out);
}
static void job_drop_call(void *data,void *instance,const void *const *args,int64_t argc,void *out,GDExtensionCallError *error) {
    (void)data;
    if(!validate_args(args,argc,NULL,0,error) || !instance) { return_nil(out); return; }
    job_drop(instance); return_int(out,0);
}
