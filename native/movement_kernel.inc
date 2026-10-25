/* Sequential movement for size-one workers. Larger footprints retain reference.
 * Never reorder workers: swaps and free-cell decisions see previous IDs' writes.
 */
static GDExtensionTypeFromVariantConstructorFunc to_array;
static GDExtensionPtrBuiltInMethod size_array;
static GDExtensionInterfaceArrayOperatorIndexConst array_const;
static const GDExtensionVariantType movement_types[]={GDEXTENSION_VARIANT_TYPE_ARRAY,GDEXTENSION_VARIANT_TYPE_ARRAY,B,B,GDEXTENSION_VARIANT_TYPE_ARRAY,B,N,N,N,N};
static int32_t move_neighbor(int32_t c,int direction,int32_t w,int32_t n) {
    if(direction<1 || direction>4) return -1;
    return neighbor(c,direction-1,w,n);
}
static int forbidden_cell(int32_t c,const uint8_t *blocked,int64_t count) { return c<count && blocked[c]==1; }
static int direction_between(int32_t c,int32_t dest,int32_t w) {
    if(dest==c-w) return 1;
    if(dest==c+w) return 3;
    if(dest==c+1 && c%w<w-1) return 2;
    if(dest==c-1 && c%w>0) return 4;
    return 0;
}
static void move_worker(int32_t id,int32_t dest,int64_t tick,int32_t *positions,int32_t *occ,uint8_t *states,int32_t *last) {
    occ[positions[id]]=-1; occ[dest]=id; positions[id]=dest; states[id]=1; last[id]=(int32_t)tick;
}
static void movement_call(void *data,void *instance,const void *const *args,int64_t argc,void *out,GDExtensionCallError *error) {
    (void)data; (void)instance;
    if(!validate_args(args,argc,movement_types,10,error)) { return_nil(out); return; }
    Value workers,fields,masks,terrain,blocked,periods,wa[11],fa[512],ma[256];
    int wn=0,fn=0,mn=0,valid=0;
    to_array(&workers,(void *)args[0]); to_array(&fields,(void *)args[1]); to_array(&masks,(void *)args[4]);
    to_bytes(&terrain,(void *)args[2]); to_bytes(&blocked,(void *)args[3]); to_bytes(&periods,(void *)args[5]);
    int64_t n=array_size(size_bytes,&terrain),bn=array_size(size_bytes,&blocked),pn=array_size(size_bytes,&periods);
    int64_t width=read_int(args[6]),tick=read_int(args[7]),pace=read_int(args[8]),speed=read_int(args[9]);
    int64_t groups=array_size(size_array,&masks);
    if(n<=0 || n>16777216 || bn>n || width<=0 || width>n || n%width || pace<=0 || speed<0 || speed>100000 || tick<0 || groups<=0 || groups>256 || array_size(size_array,&workers)!=11 || array_size(size_array,&fields)!=groups*2) goto cleanup;
    const GDExtensionVariantType types[11]={I,B,B,B,I,I,I,I,I,B,I};
    for(int i=0;i<11;i++) {
        const void *v=array_const(&workers,i); if(variant_type(v)!=types[i]) goto cleanup;
        if(types[i]==I) to_ints(&wa[i],(void *)v); else to_bytes(&wa[i],(void *)v);
        wn++;
    }
    int64_t count=array_size(size_ints,&wa[0]);
    if(count>n || array_size(size_ints,&wa[10])!=n) goto cleanup;
    for(int i=1;i<10;i++) if(array_size(types[i]==I?size_ints:size_bytes,&wa[i])!=count) goto cleanup;
    const uint8_t *sizes=count?bytes_const(&wa[9],0):NULL;
    for(int64_t i=0;i<count;i++) if(sizes[i]!=1) goto cleanup;
    const uint8_t *dirs[256],*marks[256]; const int32_t *distances[256];
    for(int64_t g=0;g<groups;g++) {
        const void *d=array_const(&fields,g*2),*r=array_const(&fields,g*2+1),*m=array_const(&masks,g);
        if(variant_type(d)!=B || variant_type(r)!=I || variant_type(m)!=B) goto cleanup;
        to_bytes(&fa[fn++],(void *)d); to_ints(&fa[fn++],(void *)r); to_bytes(&ma[mn++],(void *)m);
        if(array_size(size_bytes,&fa[g*2])!=n || array_size(size_ints,&fa[g*2+1])!=n || array_size(size_bytes,&ma[g])!=n) goto cleanup;
        dirs[g]=bytes_const(&fa[g*2],0); distances[g]=ints_const(&fa[g*2+1],0); marks[g]=bytes_const(&ma[g],0);
    }
    const uint8_t *cells=bytes_const(&terrain,0),*block=bn?bytes_const(&blocked,0):NULL,*period=pn?bytes_const(&periods,0):NULL;
    const uint8_t *group=count?bytes_const(&wa[1],0):NULL,*faction=count?bytes_const(&wa[2],0):NULL;
    const int32_t *aim=count?ints_const(&wa[5],0):NULL,*step=count?ints_const(&wa[6],0):NULL;
    int32_t *positions=count?ints_mutable(&wa[0],0):NULL,*target=count?ints_mutable(&wa[4],0):NULL;
    int32_t *last=count?ints_mutable(&wa[7],0):NULL,*credit=count?ints_mutable(&wa[8],0):NULL,*occ=ints_mutable(&wa[10],0);
    uint8_t *state=count?bytes_mutable(&wa[3],0):NULL;
    for(int64_t id=0;id<count;id++) if(positions[id]<0 || positions[id]>=n || group[id]>=groups) goto cleanup;
    for(int64_t cell=0;cell<n;cell++) if(occ[cell]<-1 || occ[cell]>=count) goto cleanup;
    int64_t stride=(speed>0 || pn)?1:pace,first=(speed>0 || pn)?0:(pace-tick%pace)%pace;
    for(int64_t id=first;id<count;id+=stride) {
        if(pn) { int p=faction[id]<pn?period[faction[id]]:(int)pace; if(p>1 && (tick+id)%p) continue; }
        if(speed>0) { credit[id]+=(int32_t)speed; if(credit[id]<100) continue; credit[id]-=100; }
        if(state[id]==2 || state[id]==4) continue;
        int32_t c=positions[id]; int direction=dirs[group[id]][c],personal=aim[id];
        if(personal>=0) {
            int32_t dest=step[id];
            if(dest==c) {
                if(personal<n && direction_between(c,personal,(int32_t)width) && cells[personal]>=1 && cells[personal]<=3 && marks[group[id]][personal]==1) { target[id]=personal; state[id]=2; }
                else state[id]=0;
                continue;
            }
            if(dest<0) { state[id]=0; continue; }
            int personal_direction=direction_between(c,dest,(int32_t)width);
            if(personal_direction) direction=personal_direction;
        }
        if(direction==5) {
            int32_t found=-1;
            for(int d=0;d<4;d++) { int32_t next=neighbor(c,d,(int32_t)width,(int32_t)n); if(next>=0 && cells[next]>=1 && cells[next]<=3 && marks[group[id]][next]==1) { found=next; break; } }
            if(found>=0) { target[id]=found; state[id]=2; } else state[id]=0;
            continue;
        }
        if(!direction) { state[id]=0; continue; }
        int32_t next=move_neighbor(c,direction,(int32_t)width,(int32_t)n);
        if(next<0 || cells[next]!=0 || forbidden_cell(next,block,bn)) { state[id]=0; continue; }
        int32_t other=occ[next];
        if(other==-1) { move_worker((int32_t)id,next,tick,positions,occ,state,last); continue; }
        if(state[other]!=2 && state[other]!=4 && last[other]!=tick && move_neighbor(next,dirs[group[other]][next],(int32_t)width,(int32_t)n)==c) {
            positions[id]=next; positions[other]=c; occ[next]=(int32_t)id; occ[c]=other;
            state[id]=1; state[other]=1; last[id]=(int32_t)tick; last[other]=(int32_t)tick;
            continue;
        }
        int vertical=direction==1 || direction==3;
        int side_dirs[2]={vertical?4:1,vertical?2:3},moved=0;
        int32_t own_distance=distances[group[id]][c];
        for(int side=0;side<2;side++) {
            int32_t dest=move_neighbor(c,side_dirs[side],(int32_t)width,(int32_t)n);
            if(dest<0 || cells[dest]!=0 || forbidden_cell(dest,block,bn) || occ[dest]!=-1) continue;
            int32_t distance=distances[group[id]][dest];
            if(distance<0 || distance>=own_distance) continue;
            move_worker((int32_t)id,dest,tick,positions,occ,state,last); moved=1; break;
        }
        if(!moved) state[id]=3;
    }
    Value result; new_array(&result,NULL);
    if(!resize(resize_array,&result,6)) { destroy_array(&result); goto cleanup; }
    const int outputs[6]={0,3,4,7,8,10};
    for(int i=0;i<6;i++) { int index=outputs[i]; void *v=array_at(&result,i); variant_destroy(v); if(types[index]==I) from_ints(v,&wa[index]); else from_bytes(v,&wa[index]); }
    variant_destroy(out); from_array(out,&result); destroy_array(&result); valid=1;
cleanup:
    for(int i=0;i<wn;i++) { if(i==0 || i==4 || i==5 || i==6 || i==7 || i==8 || i==10) destroy_ints(&wa[i]); else destroy_bytes(&wa[i]); }
    for(int i=0;i<fn;i++) { if(i%2) destroy_ints(&fa[i]); else destroy_bytes(&fa[i]); }
    for(int i=0;i<mn;i++) destroy_bytes(&ma[i]);
    destroy_array(&workers); destroy_array(&fields); destroy_array(&masks); destroy_bytes(&terrain); destroy_bytes(&blocked); destroy_bytes(&periods);
    if(!valid) return_nil(out);
}
