/* Terrain-only routes, independent of dynamic occupancy. The exact terrain copy
 * permits safe reuse across interleaved simulations, even equal revision IDs. */
#define ARMY_CACHE_BYTES (32u*1024u*1024u)
#define ARMY_CACHE_FIELDS 128
typedef struct {
    int32_t n,w,capacity,used;
    uint8_t *terrain;
    int32_t *prefix,*queue;
    int32_t *fields[ARMY_CACHE_FIELDS];
    int32_t keys[ARMY_CACHE_FIELDS];
    uint64_t ages[ARMY_CACHE_FIELDS],clock; void *corners; uint8_t *goal_frequency; int64_t full_builds,graph_queries; int warm_budget;
} ArmyCache;
static void army_corners_free(void *pointer);
static void army_corners_invalidate(void *pointer);
static void army_cache_free(void *ptr) {
    ArmyCache *cache=ptr; if(!cache) return;
    for(int i=0;i<ARMY_CACHE_FIELDS;i++) free(cache->fields[i]);
    army_corners_free(cache->corners); free(cache->goal_frequency); free(cache->terrain); free(cache->prefix); free(cache->queue); free(cache);
}
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
        if(!c->goal_frequency || !c->terrain || !c->prefix || !c->queue) { army_cache_free(c); return NULL; }
        /* Force the first comparison to differ without reading uninitialised bytes. */
        memcpy(c->terrain,terrain,(size_t)n); c->terrain[0]^=255;
        search->army_cache=c;
    }
    if(memcmp(c->terrain,terrain,(size_t)n)) {
        memcpy(c->terrain,terrain,(size_t)n);
        c->used=0; c->clock=0; army_corners_invalidate(c->corners);
        for(int32_t y=0;y<n/w;y++) {
            int32_t row=0;
            for(int32_t x=0;x<w;x++) {
                int32_t at=y*w+x; row+=(terrain[at]!=0);
                c->prefix[at]=row+(y?c->prefix[at-w]:0);
            }
        }
    }
    memset(c->goal_frequency,0,(size_t)n); c->warm_budget=8; return c;
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
    c->keys[slot]=goal; c->ages[slot]=++c->clock;
    return dist;
}
