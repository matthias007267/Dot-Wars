/* Terrain-only routes, independent of dynamic occupancy. The exact terrain copy
 * permits safe reuse across interleaved simulations, even equal revision IDs. */
#define ARMY_CACHE_BYTES (32u*1024u*1024u)
#define ARMY_CACHE_FIELDS 128
typedef struct {
    int32_t n,w,capacity,used;
    uint8_t *terrain;
    int32_t *prefix,*queue;
    int32_t *fields[ARMY_CACHE_FIELDS];
    /* main[f][cell]=1: the cell belongs to the goal's own free component(s). */
    uint8_t *main[ARMY_CACHE_FIELDS];
    int32_t keys[ARMY_CACHE_FIELDS];
    uint64_t ages[ARMY_CACHE_FIELDS],clock; void *corners; uint8_t *goal_frequency; int64_t full_builds,graph_queries,opened_updates; int warm_budget;
    int32_t *region; uint32_t *mark; uint32_t stamp;
} ArmyCache;
static void army_corners_free(void *pointer);
static void army_corners_invalidate(void *pointer);
static void army_cache_free(void *ptr) {
    ArmyCache *cache=ptr; if(!cache) return;
    for(int i=0;i<ARMY_CACHE_FIELDS;i++) { free(cache->fields[i]); free(cache->main[i]); }
    army_corners_free(cache->corners); free(cache->goal_frequency); free(cache->terrain); free(cache->prefix); free(cache->queue);
    free(cache->region); free(cache->mark); free(cache);
}
static int army_cache_open_cells(ArmyCache *c,const uint8_t *terrain);
static ArmyCache *army_cache_prepare(Search *search,const uint8_t *terrain,int32_t n,int32_t w) {
    ArmyCache *c=search->army_cache;
    if(c && (c->n!=n || c->w!=w)) { army_cache_free(c); search->army_cache=NULL; c=NULL; }
    if(!c) {
        c=calloc(1,sizeof(ArmyCache)); if(!c) return NULL;
        c->n=n; c->w=w;
        c->capacity=(int32_t)(ARMY_CACHE_BYTES/((size_t)n*sizeof(int32_t)));
        if(c->capacity<1) c->capacity=1;
        if(c->capacity>ARMY_CACHE_FIELDS) c->capacity=ARMY_CACHE_FIELDS;
        c->goal_frequency=malloc((size_t)n);
        c->terrain=malloc((size_t)n);
        c->prefix=malloc((size_t)n*sizeof(int32_t));
        c->queue=malloc((size_t)n*sizeof(int32_t));
        c->region=malloc((size_t)n*sizeof(int32_t));
        c->mark=calloc((size_t)n,sizeof(uint32_t));
        if(!c->goal_frequency || !c->terrain || !c->prefix || !c->queue || !c->region || !c->mark) { army_cache_free(c); return NULL; }
        /* Counts are reset after each call only where they were raised. */
        memset(c->goal_frequency,0,(size_t)n);
        /* Force the first comparison to differ without reading uninitialised bytes. */
        memcpy(c->terrain,terrain,(size_t)n); c->terrain[0]^=255;
        search->army_cache=c;
    }
    if(memcmp(c->terrain,terrain,(size_t)n)) {
        /* Mining only opens cells: cached fields follow exactly. Anything else
         * (a closed cell, many changes) drops the cache as before. */
        if(!army_cache_open_cells(c,terrain)) { c->used=0; c->clock=0; }
        memcpy(c->terrain,terrain,(size_t)n);
        army_corners_invalidate(c->corners);
        for(int32_t y=0;y<n/w;y++) {
            int32_t row=0;
            for(int32_t x=0;x<w;x++) {
                int32_t at=y*w+x; row+=(terrain[at]!=0);
                c->prefix[at]=row+(y?c->prefix[at-w]:0);
            }
        }
    }
    c->warm_budget=8; return c;
}
static int army_clear_rectangle(const ArmyCache *c,int32_t a,int32_t b) {
    if(b<0 || b>=c->n) return 0;
    int ax=a%c->w,ay=a/c->w,bx=b%c->w,by=b/c->w;
    int x0=ax<bx?ax:bx,x1=ax>bx?ax:bx,y0=ay<by?ay:by,y1=ay>by?ay:by;
    int32_t sum=c->prefix[y1*c->w+x1];
    if(x0) sum-=c->prefix[y1*c->w+x0-1];
    if(y0) sum-=c->prefix[(y0-1)*c->w+x1];
    if(x0 && y0) sum+=c->prefix[(y0-1)*c->w+x0-1];
    return sum==0;
}
static const int32_t *army_cached_field(ArmyCache *c,int32_t goal) {
    for(int i=0;i<c->used;i++) if(c->keys[i]==goal) { c->ages[i]=++c->clock; return c->fields[i]; }
    c->full_builds++; int slot=c->used;
    if(slot<c->capacity) c->used++;
    else {
        slot=0;
        for(int i=1;i<c->used;i++) if(c->ages[i]<c->ages[slot]) slot=i;
    }
    if(!c->fields[slot]) c->fields[slot]=malloc((size_t)c->n*sizeof(int32_t));
    int32_t *dist=c->fields[slot]; if(!dist) { if(slot==c->used-1) c->used--; return NULL; }
    if(!c->main[slot]) c->main[slot]=malloc((size_t)c->n);
    uint8_t *main=c->main[slot]; if(!main) { if(slot==c->used-1) c->used--; return NULL; }
    for(int i=0;i<c->n;i++) dist[i]=-1;
    int32_t head=0,tail=0;
    if(c->terrain[goal]==0) { dist[goal]=0; c->queue[tail++]=goal; }
    else for(int d=0;d<4;d++) {
        int32_t next=neighbor(goal,d,c->w,c->n);
        if(next>=0 && c->terrain[next]==0) { dist[next]=0; c->queue[tail++]=next; }
    }
    while(head<tail) {
        int32_t cell=c->queue[head++];
        for(int d=0;d<4;d++) {
            int32_t next=neighbor(cell,d,c->w,c->n);
            if(next>=0 && dist[next]<0 && c->terrain[next]==0) { dist[next]=dist[cell]+1; c->queue[tail++]=next; }
        }
    }
    for(int32_t i=0;i<c->n;i++) main[i]=dist[i]>=0;
    /* Populate all other free components as well: one nearest reachable stand
     * per component, shared by every warrior with this requested goal. */
    for(int32_t origin=0;origin<c->n;origin++) {
        if(c->terrain[origin] || dist[origin]!=-1) continue;
        int32_t best_rank=INT_MAX;
        head=0; tail=1; c->queue[0]=origin; dist[origin]=-2;
        while(head<tail) {
            int32_t cell=c->queue[head++];
            int rank=abs(cell%c->w-goal%c->w)+abs(cell/c->w-goal/c->w);
            if(rank<best_rank) best_rank=rank;
            for(int d=0;d<4;d++) {
                int32_t next=neighbor(cell,d,c->w,c->n);
                if(next>=0 && !c->terrain[next] && dist[next]==-1) { dist[next]=-2; c->queue[tail++]=next; }
            }
        }
        /* Compact every equally near stand into the front of the component
         * queue; write index never exceeds read index. One multi-source field
         * then gives each unit its shortest walk to a nearest stand. */
        int32_t component_size=tail; tail=0; head=0;
        for(int32_t i=0;i<component_size;i++) {
            int32_t cell=c->queue[i];
            int rank=abs(cell%c->w-goal%c->w)+abs(cell/c->w-goal/c->w);
            if(rank==best_rank) { dist[cell]=0; c->queue[tail++]=cell; }
        }
        while(head<tail) {
            int32_t cell=c->queue[head++];
            for(int d=0;d<4;d++) {
                int32_t next=neighbor(cell,d,c->w,c->n);
                if(next>=0 && dist[next]==-2) { dist[next]=dist[cell]+1; c->queue[tail++]=next; }
            }
        }
    }
    c->keys[slot]=goal; c->ages[slot]=++c->clock;
    return dist;
}
/* Multi-source stand field of one disconnected component, exactly as built in
 * army_cached_field: every cell of minimal Manhattan rank to the goal is a stand. */
static void army_component_stands(ArmyCache *c,int32_t *dist,int32_t goal,int32_t start) {
    int32_t w=c->w,n=c->n,size=0,head=0,tail=0; uint32_t stamp=++c->stamp;
    if(!stamp) { memset(c->mark,0,(size_t)n*sizeof(uint32_t)); stamp=c->stamp=1; }
    int best=INT_MAX;
    c->region[size++]=start; c->mark[start]=stamp;
    for(int32_t i=0;i<size;i++) {
        int32_t cell=c->region[i];
        int rank=abs(cell%w-goal%w)+abs(cell/w-goal/w); if(rank<best) best=rank;
        for(int d=0;d<4;d++) {
            int32_t next=neighbor(cell,d,w,n);
            if(next>=0 && !c->terrain[next] && c->mark[next]!=stamp) { c->mark[next]=stamp; c->region[size++]=next; }
        }
    }
    for(int32_t i=0;i<size;i++) dist[c->region[i]]=-1;
    for(int32_t i=0;i<size;i++) {
        int32_t cell=c->region[i];
        if(abs(cell%w-goal%w)+abs(cell/w-goal/w)==best) { dist[cell]=0; c->queue[tail++]=cell; }
    }
    while(head<tail) {
        int32_t cell=c->queue[head++];
        for(int d=0;d<4;d++) {
            int32_t next=neighbor(cell,d,w,n);
            if(next>=0 && c->mark[next]==stamp && dist[next]==-1) { dist[next]=dist[cell]+1; c->queue[tail++]=next; }
        }
    }
}
/* One opened cell with the cache terrain already updated. Opening only adds a
 * vertex: the goal's component keeps exact BFS distances by relaxing through
 * the new cell, joined components take real distances, and an isolated merged
 * component recomputes its nearest stands. Returns 0 when goal seeds change. */
static int army_field_open(ArmyCache *c,int slot,int32_t cell) {
    int32_t *dist=c->fields[slot],goal=c->keys[slot],w=c->w,n=c->n; uint8_t *main=c->main[slot];
    if(goal<0) return 1;
    if(!main || !dist || cell==goal) return 0;
    if(c->terrain[goal]) for(int d=0;d<4;d++) if(neighbor(goal,d,w,n)==cell) return 0;
    int32_t best=-1; int joined=0;
    for(int d=0;d<4;d++) {
        int32_t next=neighbor(cell,d,w,n);
        if(next<0 || c->terrain[next] || !main[next]) continue;
        joined=1; if(best<0 || dist[next]+1<best) best=dist[next]+1;
    }
    main[cell]=0;
    if(!joined) { army_component_stands(c,dist,goal,cell); return 1; }
    for(int d=0;d<4;d++) {
        int32_t start=neighbor(cell,d,w,n);
        if(start<0 || c->terrain[start] || main[start] || dist[start]==-1) continue;
        int32_t head=0,tail=0; dist[start]=-1; c->queue[tail++]=start;
        while(head<tail) {
            int32_t at=c->queue[head++];
            for(int e=0;e<4;e++) {
                int32_t next=neighbor(at,e,w,n);
                if(next>=0 && next!=cell && !c->terrain[next] && !main[next] && dist[next]!=-1) { dist[next]=-1; c->queue[tail++]=next; }
            }
        }
    }
    int32_t head=0,tail=0; dist[cell]=best; main[cell]=1; c->queue[tail++]=cell;
    while(head<tail) {
        int32_t at=c->queue[head++],next_distance=dist[at]+1;
        for(int d=0;d<4;d++) {
            int32_t next=neighbor(at,d,w,n);
            if(next<0 || c->terrain[next] || (dist[next]!=-1 && dist[next]<=next_distance)) continue;
            dist[next]=next_distance; main[next]=1; c->queue[tail++]=next;
        }
    }
    return 1;
}
static int army_cache_open_cells(ArmyCache *c,const uint8_t *terrain) {
    if(!c->used) return 0;
    int32_t opened[64]; int count=0;
    for(int32_t i=0;i<c->n;i++) {
        if(c->terrain[i]==terrain[i]) continue;
        if(!c->terrain[i] && terrain[i]) return 0;
        if(c->terrain[i] && !terrain[i]) { if(count>=64) return 0; opened[count++]=i; }
    }
    for(int k=0;k<count;k++) {
        c->terrain[opened[k]]=0;
        for(int slot=0;slot<c->used;slot++) if(!army_field_open(c,slot,opened[k])) { c->keys[slot]=-1; c->ages[slot]=0; }
    }
    c->opened_updates+=count;
    return 1;
}
