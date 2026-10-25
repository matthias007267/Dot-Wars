/* Sequential army arithmetic. State/policy parameters and terrain fields come
 * from GDScript. Contacts observe earlier stable IDs' moves, never a snapshot. */
static const GDExtensionVariantType army_types[]={GDEXTENSION_VARIANT_TYPE_ARRAY,GDEXTENSION_VARIANT_TYPE_ARRAY,B,N,N};
typedef struct { int32_t uid, slot; } ArmyOrder;
typedef struct { int32_t id, cell; int warrior; } ArmyEnemy;
static int army_compare(const void *a,const void *b) {
    int32_t x=((const ArmyOrder *)a)->uid,y=((const ArmyOrder *)b)->uid;
    return (x>y)-(x<y);
}
static int army_allied(int a,int b,const int32_t *teams) { return a==b || teams[a]==teams[b]; }
static ArmyEnemy army_enemy(int32_t origin,int owner,int radius,int32_t w,int32_t n,
        const int32_t *occ,const uint8_t *owners,const int32_t *workers,const uint8_t *worker_owners,const int32_t *teams) {
    ArmyEnemy best={-1,-1,0}; int rank=INT_MAX,ox=origin%w,oy=origin/w,h=n/w;
    int y0=oy-radius>0?oy-radius:0,y1=oy+radius<h?oy+radius:h-1;
    int x0=ox-radius>0?ox-radius:0,x1=ox+radius<w?ox+radius:w-1;
    for(int y=y0;y<=y1;y++) for(int x=x0;x<=x1;x++) {
        int distance=abs(x-ox)+abs(y-oy); if(!distance || distance>radius) continue;
        int32_t cell=y*w+x,other=occ[cell],worker=workers[cell];
        if(other>=0 && !army_allied(owner,owners[other],teams) && distance*2<rank) {
            rank=distance*2; best=(ArmyEnemy){other,cell,1};
        }
        if(worker>=0 && !army_allied(owner,worker_owners[worker],teams) && distance*2+1<rank) {
            rank=distance*2+1; best=(ArmyEnemy){worker,cell,0};
        }
    }
    return best;
}
/* Same bounded reverse BFS as ArmyState._local_field, N/E/S/W insertion order.
 * The largest accepted radius is eight: at most 17x17 scratch entries. */
static int army_local_index(int32_t c,int ox,int oy,int radius,int w) {
    if(c<0) return -1;
    int dx=c%w-ox,dy=c/w-oy;
    if(abs(dx)+abs(dy)>radius) return -1;
    return (dy+radius)*(radius*2+1)+dx+radius;
}
static void army_local_field(int32_t origin,int32_t goal,int radius,int32_t w,int32_t n,const uint8_t *terrain,int32_t *dist) {
    int side=radius*2+1; for(int i=0;i<side*side;i++) dist[i]=-1;
    int32_t queue[289]; int head=0,tail=0,ox=origin%w,oy=origin/w;
    int start=army_local_index(goal,ox,oy,radius,w); if(start<0) return;
    dist[start]=0; queue[tail++]=goal;
    while(head<tail) {
        int32_t cell=queue[head++]; if(cell==origin) break;
        int current=army_local_index(cell,ox,oy,radius,w);
        for(int d=0;d<4;d++) {
            int32_t next=neighbor(cell,d,w,n); int at=army_local_index(next,ox,oy,radius,w);
            if(at<0 || dist[at]>=0 || terrain[next]!=0) continue;
            dist[at]=dist[current]+1; queue[tail++]=next;
        }
    }
}
static int army_distance(int32_t cell,const int32_t *field,const int32_t *local,int ox,int oy,int radius,int w) {
    if(!local) return field[cell];
    int at=army_local_index(cell,ox,oy,radius,w); return at<0?-1:local[at];
}
static int army_free_endpoint(int32_t origin,int owner,int32_t w,int32_t n,const uint8_t *terrain,const int32_t *occ,const int32_t *workers,const uint8_t *worker_owners) {
    for(int d=0;d<4;d++) {
        int32_t next=neighbor(origin,d,w,n);
        while(next>=0 && terrain[next]==0 && occ[next]<0) {
            int worker=workers[next];
            if(worker<0) return 1;
            if(worker_owners[worker]!=owner) break;
            next=neighbor(next,d,w,n);
        }
    }
    return 0;
}
static int army_clear_l(const ArmyCache *cache,int32_t a,int32_t b) {
    int32_t corner=(a/cache->w)*cache->w+b%cache->w;
    if(army_clear_rectangle(cache,a,corner) && army_clear_rectangle(cache,corner,b)) return 1;
    corner=(b/cache->w)*cache->w+a%cache->w;
    return army_clear_rectangle(cache,a,corner) && army_clear_rectangle(cache,corner,b);
}
/* A clear L proves the Manhattan lower bound is attained. Only use the fast
 * gradient if the first dynamically eligible endpoint has the same proof;
 * otherwise the complete BFS must decide. Thus no tie or detour is skipped. */
static int army_safe_manhattan(const ArmyCache *cache,int32_t origin,int32_t goal,int owner,const int32_t *occ,const int32_t *workers,const uint8_t *worker_owners) {
    if(!army_clear_l(cache,origin,goal)) return 0;
    int32_t w=cache->w,n=cache->n;
    for(int d=0;d<4;d++) {
        int32_t previous=origin,next=neighbor(origin,d,w,n);
        while(next>=0 && cache->terrain[next]==0 && occ[next]<0) {
            int pd=abs(previous%w-goal%w)+abs(previous/w-goal/w),dd=abs(next%w-goal%w)+abs(next/w-goal/w);
            if(dd>=pd) break;
            int worker=workers[next];
            if(worker<0) return army_clear_l(cache,next,goal);
            if(worker_owners[worker]!=owner) break;
            previous=next; next=neighbor(next,d,w,n);
        }
    }
    return 1;
}

static void army_call_impl(void *data,void *instance,const void *const *args,int64_t argc,void *out,GDExtensionCallError *error,int use_cache) {
    (void)data; (void)instance;
    if(!validate_args(args,argc,army_types,5,error)) { return_nil(out); return; }
    Value bundle,fields,terrain,wa[13],fa[16]; int wn=0,fn=0,valid=0;
    ArmyCache *route_cache=NULL; int32_t *occ=NULL,*warrior_damage=NULL,*worker_damage=NULL; ArmyOrder *order=NULL;
    const GDExtensionVariantType types[13]={I,I,B,I,I,I,I,I,B,I,I,I,I};
    to_array(&bundle,(void *)args[0]); to_array(&fields,(void *)args[1]); to_bytes(&terrain,(void *)args[2]);
    int64_t n=array_size(size_bytes,&terrain),w64=read_int(args[3]),tick=read_int(args[4]);
    if(n<=0 || n>16777216 || w64<=0 || w64>n || n%w64 || tick<0 || tick>INT32_MAX || array_size(size_array,&bundle)!=13) goto cleanup;
    for(int i=0;i<13;i++) {
        const void *v=array_const(&bundle,i); if(variant_type(v)!=types[i]) goto cleanup;
        if(types[i]==I) to_ints(&wa[i],(void *)v); else to_bytes(&wa[i],(void *)v); wn++;
    }
    int64_t count=array_size(size_ints,&wa[0]),worker_count=array_size(size_bytes,&wa[8]),field_count=array_size(size_ints,&wa[11]);
    if(count>n || worker_count>n || field_count>16 || array_size(size_array,&fields)!=field_count) goto cleanup;
    for(int i=1;i<=5;i++) if(array_size(types[i]==I?size_ints:size_bytes,&wa[i])!=count) goto cleanup;
    if(array_size(size_ints,&wa[6])!=n || array_size(size_ints,&wa[7])!=n || array_size(size_ints,&wa[9])!=4 || array_size(size_ints,&wa[10])!=4 || array_size(size_ints,&wa[12])!=5) goto cleanup;
    const int32_t *keys=field_count?ints_const(&wa[11],0):NULL,*routes[16];
    for(int i=0;i<field_count;i++) {
        const void *v=array_const(&fields,i); if(variant_type(v)!=I || keys[i]<0 || keys[i]>=n) goto cleanup;
        for(int j=0;j<i;j++) if(keys[i]==keys[j]) goto cleanup;
        to_ints(&fa[fn++],(void *)v); if(array_size(size_ints,&fa[i])!=n) goto cleanup;
        routes[i]=ints_const(&fa[i],0);
    }
    const int32_t *params=ints_const(&wa[12],0);
    int32_t damage=params[0],attack_period=params[1],move_period=params[2],radius=params[3],scan_period=params[4];
    if(damage<=0 || damage>100000 || attack_period<=0 || move_period<=0 || radius<1 || radius>8 || scan_period<=0 || tick+(int64_t)move_period*n>INT32_MAX || count*damage>INT32_MAX) goto cleanup;
    const uint8_t *cells=bytes_const(&terrain,0),*owners=count?bytes_const(&wa[2],0):NULL,*worker_owners=worker_count?bytes_const(&wa[8],0):NULL;
    const int32_t *uids=count?ints_const(&wa[0],0):NULL,*goals=count?ints_const(&wa[3],0):NULL,*workers=ints_const(&wa[7],0),*teams=ints_const(&wa[9],0),*ai=ints_const(&wa[10],0);
    /* Mutable copies are returned explicitly; no mutation of caller arguments. */
    int32_t *positions=count?ints_mutable(&wa[1],0):NULL,*moves=count?ints_mutable(&wa[4],0):NULL,*attacks=count?ints_mutable(&wa[5],0):NULL,*occupancy=ints_mutable(&wa[6],0);
    occ=malloc((size_t)n*sizeof(int32_t)); warrior_damage=calloc((size_t)(count?count:1),sizeof(int32_t)); worker_damage=calloc((size_t)(worker_count?worker_count:1),sizeof(int32_t)); order=malloc((size_t)(count?count:1)*sizeof(ArmyOrder));
    if(!occ || !warrior_damage || !worker_damage || !order) goto cleanup;
    for(int64_t c=0;c<n;c++) { occ[c]=-1; if(workers[c]<-1 || workers[c]>=worker_count) goto cleanup; }
    for(int64_t i=0;i<worker_count;i++) if(worker_owners[i]>3) goto cleanup;
    for(int i=0;i<4;i++) if(ai[i]<-1 || ai[i]>=n) goto cleanup;
    for(int32_t i=0;i<count;i++) {
        int32_t c=positions[i];
        if(uids[i]<0 || c<0 || c>=n || cells[c]!=0 || workers[c]>=0 || occ[c]>=0 || owners[i]>3 || goals[i]<-1 || goals[i]>=n || occupancy[c]!=uids[i]) goto cleanup;
        occ[c]=i; order[i]=(ArmyOrder){uids[i],i};
        int32_t goal=goals[i]<0?ai[owners[i]]:goals[i];
        if(goal>=0) { int found=0; for(int f=0;f<field_count;f++) if(keys[f]==goal) found=1; if(!found && !use_cache) goto cleanup; }
    }
    for(int64_t c=0;c<n;c++) if(occ[c]<0 && occupancy[c]!=-1) goto cleanup;
    qsort(order,(size_t)count,sizeof(ArmyOrder),army_compare);
    for(int64_t i=1;i<count;i++) if(order[i-1].uid==order[i].uid) goto cleanup;
    int32_t w=(int32_t)w64;
    if(use_cache) { if(!instance) goto cleanup; route_cache=army_cache_prepare(instance,cells,(int32_t)n,w); if(!route_cache) goto cleanup; for(int32_t i=0;i<count;i++) { int32_t goal=goals[i]<0?ai[owners[i]]:goals[i]; if(goal>=0 && route_cache->goal_frequency[goal]<255) route_cache->goal_frequency[goal]++; } }
    for(int32_t at=0;at<count;at++) {
        int32_t i=order[at].slot,uid=order[at].uid,c=positions[i]; int owner=owners[i];
        ArmyEnemy enemy=army_enemy(c,owner,1,w,(int32_t)n,occ,owners,workers,worker_owners,teams);
        if(enemy.id>=0) {
            if(tick-(int64_t)attacks[i]>=attack_period) {
                attacks[i]=(int32_t)tick;
                if(enemy.warrior) warrior_damage[enemy.id]+=damage; else worker_damage[enemy.id]+=damage;
            }
            continue;
        }
        if(tick<moves[i]) continue;
        int manhattan=0; int32_t goal=goals[i],local[289]; const int32_t *local_dist=NULL,*field=NULL;
        if((tick+uid)%scan_period==0) {
            enemy=army_enemy(c,owner,radius,w,(int32_t)n,occ,owners,workers,worker_owners,teams);
            if(enemy.id>=0) { goal=enemy.cell; local_dist=local; }
        }
        if(goal<0) goal=ai[owner];
        if(goal<0 || goal==c) continue;
        if(use_cache && !army_free_endpoint(c,owner,w,(int32_t)n,cells,occ,workers,worker_owners)) continue;
        int ox=c%w,oy=c/w;
        if(local_dist) army_local_field(c,goal,radius,w,(int32_t)n,cells,local);
        else {
            for(int f=0;f<field_count;f++) if(keys[f]==goal) { field=routes[f]; break; }
            if(!field && use_cache) {
                if(army_clear_rectangle(route_cache,c,goal) || army_safe_manhattan(route_cache,c,goal,owner,occ,workers,worker_owners)) manhattan=1;
                else {
                    int cached=0; for(int k=0;k<route_cache->used;k++) if(route_cache->keys[k]==goal) { cached=1; break; }
                    if(!cached && (route_cache->used>=route_cache->capacity || route_cache->warm_budget<=0) && route_cache->goal_frequency[goal]<4) field=army_corner_route(route_cache,c,goal,owner,occ,workers,worker_owners);
                    if(!field) { if(!cached && route_cache->goal_frequency[goal]<4 && route_cache->warm_budget>0) route_cache->warm_budget--; field=army_cached_field(route_cache,goal); }
                }
            }
            if(!field && !manhattan) goto cleanup;
        }
        if(!manhattan && army_distance(c,field,local_dist,ox,oy,radius,w)<0) continue;
        for(int d=0;d<4;d++) {
            int32_t dest=neighbor(c,d,w,(int32_t)n),previous=c,distance=1;
            while(dest>=0 && occ[dest]<0 && cells[dest]==0) {
                int dd=manhattan?abs(dest%w-goal%w)+abs(dest/w-goal/w):army_distance(dest,field,local_dist,ox,oy,radius,w),pd=manhattan?abs(previous%w-goal%w)+abs(previous/w-goal/w):army_distance(previous,field,local_dist,ox,oy,radius,w);
                if(dd<0 || dd>=pd) break;
                int worker=workers[dest];
                if(worker<0) {
                    occ[c]=-1; occ[dest]=i; occupancy[c]=-1; occupancy[dest]=uid;
                    positions[i]=dest; moves[i]=(int32_t)(tick+(int64_t)move_period*distance); break;
                }
                if(worker_owners[worker]!=owner) break;
                previous=dest; dest=neighbor(dest,d,w,(int32_t)n); distance++;
            }
            if(positions[i]!=c) break;
        }
    }
    Value result,hit_warriors,hit_workers; new_array(&result,NULL); new_ints(&hit_warriors,NULL); new_ints(&hit_workers,NULL);
    int64_t aw=0,ww=0;
    for(int64_t i=0;i<count;i++) if(warrior_damage[i]) aw+=2;
    for(int64_t i=0;i<worker_count;i++) if(worker_damage[i]) ww+=2;
    if(!resize(resize_array,&result,6) || !resize(resize_ints,&hit_warriors,aw) || !resize(resize_ints,&hit_workers,ww)) { destroy_array(&result); destroy_ints(&hit_warriors); destroy_ints(&hit_workers); goto cleanup; }
    int32_t *ap=aw?ints_mutable(&hit_warriors,0):NULL,*wp=ww?ints_mutable(&hit_workers,0):NULL; aw=0; ww=0;
    for(int64_t i=0;i<count;i++) if(warrior_damage[i]) { ap[aw++]=uids[i]; ap[aw++]=warrior_damage[i]; }
    for(int64_t i=0;i<worker_count;i++) if(worker_damage[i]) { wp[ww++]=(int32_t)i; wp[ww++]=worker_damage[i]; }
    int outputs[4]={1,4,5,6};
    for(int i=0;i<4;i++) { void *v=array_at(&result,i); variant_destroy(v); from_ints(v,&wa[outputs[i]]); }
    void *v=array_at(&result,4); variant_destroy(v); from_ints(v,&hit_warriors);
    v=array_at(&result,5); variant_destroy(v); from_ints(v,&hit_workers);
    variant_destroy(out); from_array(out,&result); valid=1;
    destroy_array(&result); destroy_ints(&hit_warriors); destroy_ints(&hit_workers);
cleanup:
    free(occ); free(warrior_damage); free(worker_damage); free(order);
    for(int i=0;i<wn;i++) { if(types[i]==I) destroy_ints(&wa[i]); else destroy_bytes(&wa[i]); }
    for(int i=0;i<fn;i++) destroy_ints(&fa[i]);
    destroy_array(&bundle); destroy_array(&fields); destroy_bytes(&terrain);
    if(!valid) return_nil(out);
}

static void army_call(void *data,void *instance,const void *const *args,int64_t argc,void *out,GDExtensionCallError *error) {
    army_call_impl(data,instance,args,argc,out,error,0);
}
static void army_cached_call(void *data,void *instance,const void *const *args,int64_t argc,void *out,GDExtensionCallError *error) {
    army_call_impl(data,instance,args,argc,out,error,1);
}