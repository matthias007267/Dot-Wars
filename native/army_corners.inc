/* Exact rectilinear visibility graph for small obstacle-corner sets. Every edge
 * is a verified free L path. More complex terrain falls back to full grid BFS. */
#define ARMY_CORNER_LIMIT 256
typedef struct {
    int ready,count,last_goal,seed_count;
    int32_t points[ARMY_CORNER_LIMIT],matrix[ARMY_CORNER_LIMIT*ARMY_CORNER_LIMIT];
    int32_t goal_dist[ARMY_CORNER_LIMIT],seeds[4];
    int32_t *route,*touched,touched_count;
} ArmyCorners;
static void army_corners_free(void *pointer) {
    ArmyCorners *c=pointer; if(!c) return; free(c->route); free(c->touched); free(c);
}
static int army_corner_l(const ArmyCache *cache,int32_t a,int32_t b) {
    int32_t corner=(a/cache->w)*cache->w+b%cache->w;
    if(army_clear_rectangle(cache,a,corner) && army_clear_rectangle(cache,corner,b)) return 1;
    corner=(b/cache->w)*cache->w+a%cache->w;
    return army_clear_rectangle(cache,a,corner) && army_clear_rectangle(cache,corner,b);
}
static int army_corner_add(ArmyCorners *c,int32_t cell) {
    for(int i=0;i<c->count;i++) if(c->points[i]==cell) return 1;
    if(c->count>=ARMY_CORNER_LIMIT) return 0;
    c->points[c->count++]=cell; return 1;
}
static int army_corners_prepare(ArmyCache *cache) {
    ArmyCorners *c=cache->corners;
    if(!c) {
        c=calloc(1,sizeof(ArmyCorners)); if(!c) return 0;
        c->route=malloc((size_t)cache->n*sizeof(int32_t)); c->touched=malloc((size_t)cache->n*sizeof(int32_t));
        if(!c->route || !c->touched) { army_corners_free(c); return 0; }
        for(int i=0;i<cache->n;i++) c->route[i]=-1;
        cache->corners=c;
    }
    if(c->ready) return c->ready>0;
    c->count=0; c->last_goal=-1;
    int w=cache->w,h=cache->n/w;
    for(int y=0;y<h;y++) for(int x=0;x<w;x++) {
        int32_t cell=y*w+x; if(cache->terrain[cell]) continue;
        int is_corner=(x==0 || x==w-1) && (y==0 || y==h-1);
        for(int dy=-1;dy<=1 && !is_corner;dy+=2) for(int dx=-1;dx<=1;dx+=2) {
            if(x+dx<0 || x+dx>=w || y+dy<0 || y+dy>=h) continue;
            if(cache->terrain[(y+dy)*w+x+dx] && !cache->terrain[y*w+x+dx] && !cache->terrain[(y+dy)*w+x]) { is_corner=1; break; }
        }
        if(is_corner && !army_corner_add(c,cell)) { c->ready=-1; return 0; }
    }
    int count=c->count;
    for(int i=0;i<count;i++) for(int j=0;j<count;j++) {
        int a=c->points[i],b=c->points[j];
        c->matrix[i*count+j]=army_corner_l(cache,a,b)?abs(a%w-b%w)+abs(a/w-b/w):INT32_MAX/4;
    }
    for(int k=0;k<count;k++) for(int i=0;i<count;i++) {
        int first=c->matrix[i*count+k]; if(first==INT32_MAX/4) continue;
        for(int j=0;j<count;j++) {
            int candidate=first+c->matrix[k*count+j];
            if(candidate<c->matrix[i*count+j]) c->matrix[i*count+j]=candidate;
        }
    }
    c->ready=1; return 1;
}
static void army_corners_invalidate(void *pointer) { ArmyCorners *c=pointer; if(c) c->ready=0; }
static int army_corner_distance(const ArmyCache *cache,const ArmyCorners *c,int32_t origin) {
    int best=INT32_MAX/4,w=cache->w;
    for(int s=0;s<c->seed_count;s++) if(army_corner_l(cache,origin,c->seeds[s])) {
        int goal=c->seeds[s],value=abs(origin%w-goal%w)+abs(origin/w-goal/w); if(value<best) best=value;
    }
    for(int i=0;i<c->count;i++) if(c->goal_dist[i]<best && army_corner_l(cache,origin,c->points[i])) {
        int p=c->points[i],value=c->goal_dist[i]+abs(origin%w-p%w)+abs(origin/w-p/w); if(value<best) best=value;
    }
    return best==INT32_MAX/4?-1:best;
}
static const int32_t *army_corner_route(ArmyCache *cache,int32_t origin,int32_t goal,int owner,const int32_t *occ,const int32_t *workers,const uint8_t *worker_owners) {
    if(!army_corners_prepare(cache)) return NULL; cache->graph_queries++;
    ArmyCorners *c=cache->corners; int w=cache->w;
    if(c->last_goal!=goal) {
        c->last_goal=goal; c->seed_count=0;
        if(!cache->terrain[goal]) c->seeds[c->seed_count++]=goal;
        else for(int d=0;d<4;d++) { int next=neighbor(goal,d,w,cache->n); if(next>=0 && !cache->terrain[next]) c->seeds[c->seed_count++]=next; }
        int32_t direct[ARMY_CORNER_LIMIT];
        for(int i=0;i<c->count;i++) {
            direct[i]=INT32_MAX/4;
            for(int s=0;s<c->seed_count;s++) if(army_corner_l(cache,c->points[i],c->seeds[s])) {
                int a=c->points[i],b=c->seeds[s],distance=abs(a%w-b%w)+abs(a/w-b/w);
                if(distance<direct[i]) direct[i]=distance;
            }
        }
        for(int i=0;i<c->count;i++) {
            int best=INT32_MAX/4;
            for(int j=0;j<c->count;j++) { int value=c->matrix[i*c->count+j]+direct[j]; if(value<best) best=value; }
            c->goal_dist[i]=best;
        }
    }
    for(int i=0;i<c->touched_count;i++) c->route[c->touched[i]]=-1;
    c->touched_count=0;
    int distance=army_corner_distance(cache,c,origin);
    c->route[origin]=distance; c->touched[c->touched_count++]=origin;
    if(distance<0) return c->route;
    for(int d=0;d<4;d++) {
        int next=neighbor(origin,d,w,cache->n),length=1;
        while(next>=0 && !cache->terrain[next] && occ[next]<0 && length<=distance) {
            int worker=workers[next];
            if(worker<0) {
                if(army_corner_distance(cache,c,next)==distance-length) {
                    int cell=origin;
                    for(int k=1;k<=length;k++) { cell=neighbor(cell,d,w,cache->n); c->route[cell]=distance-k; c->touched[c->touched_count++]=cell; }
                    return c->route;
                }
                break;
            }
            if(worker_owners[worker]!=owner) break;
            next=neighbor(next,d,w,cache->n); length++;
        }
    }
    return c->route;
}

static void army_route_stats_call(void *data,void *instance,const void *const *args,int64_t argc,void *out,GDExtensionCallError *error) {
    (void)data;
    if(!validate_args(args,argc,NULL,0,error) || !instance) { return_nil(out); return; }
    Search *s=instance; ArmyCache *cache=s->army_cache;
    Value result; new_longs(&result,NULL);
    if(!resize(resize_longs,&result,4)) { destroy_longs(&result); return_nil(out); return; }
    int64_t *v=longs_mutable(&result,0);
    v[0]=cache?cache->used:0; v[1]=cache && cache->corners?((ArmyCorners *)cache->corners)->count:0;
    v[2]=cache?cache->full_builds:0; v[3]=cache?cache->graph_queries:0;
    variant_destroy(out); from_longs(out,&result); destroy_longs(&result);
}