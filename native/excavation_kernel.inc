/* Lexicographic group Dijkstra: blocks, work, steps, cell ID. Costs come from
 * Materials.WORK; no intelligence or faction policy is hidden in this kernel. */
typedef struct { int32_t blocks,work,steps,cell; } ExcavationNode;
typedef struct { ExcavationNode *items; size_t size,capacity; } ExcavationHeap;
static int excavation_less(ExcavationNode a,ExcavationNode b) {
    if(a.blocks!=b.blocks) return a.blocks<b.blocks;
    if(a.work!=b.work) return a.work<b.work;
    if(a.steps!=b.steps) return a.steps<b.steps;
    return a.cell<b.cell;
}
static int excavation_push(ExcavationHeap *heap,ExcavationNode node) {
    if(heap->size==heap->capacity) {
        size_t capacity=heap->capacity?heap->capacity*2:256;
        if(capacity>SIZE_MAX/sizeof(ExcavationNode)) return 0;
        void *items=realloc(heap->items,capacity*sizeof(ExcavationNode));
        if(!items) return 0;
        heap->items=items; heap->capacity=capacity;
    }
    size_t at=heap->size++;
    while(at) {
        size_t parent=(at-1)/2;
        if(!excavation_less(node,heap->items[parent])) break;
        heap->items[at]=heap->items[parent]; at=parent;
    }
    heap->items[at]=node; return 1;
}
static ExcavationNode excavation_pop(ExcavationHeap *heap) {
    ExcavationNode result=heap->items[0],last=heap->items[--heap->size];
    if(!heap->size) return result;
    size_t at=0;
    while(at*2+1<heap->size) {
        size_t child=at*2+1;
        if(child+1<heap->size && excavation_less(heap->items[child+1],heap->items[child])) child++;
        if(!excavation_less(heap->items[child],last)) break;
        heap->items[at]=heap->items[child]; at=child;
    }
    heap->items[at]=last; return result;
}
static const GDExtensionVariantType excavation_types[]={B,B,I,B,I,N};
static void excavation_call(void *data,void *instance,const void *const *args,int64_t argc,void *out,GDExtensionCallError *error) {
    (void)data; (void)instance;
    if(!validate_args(args,argc,excavation_types,6,error)) { return_nil(out); return; }
    Value ca,ba,oa,ta,wa,path;
    to_bytes(&ca,(void *)args[0]); to_bytes(&ba,(void *)args[1]); to_ints(&oa,(void *)args[2]);
    to_bytes(&ta,(void *)args[3]); to_ints(&wa,(void *)args[4]); new_ints(&path,NULL);
    int64_t n=array_size(size_bytes,&ca),bn=array_size(size_bytes,&ba),on=array_size(size_ints,&oa),tn=array_size(size_bytes,&ta),wn=array_size(size_ints,&wa),w64=read_int(args[5]);
    int valid=0; int32_t *parent=NULL,*blocks=NULL,*work=NULL,*steps=NULL;
    ExcavationHeap heap={0};
    if(n<=0 || n>16777216 || bn>n || tn!=n || wn!=13 || w64<=0 || w64>n || n%w64) goto cleanup;
    const uint8_t *cells=bytes_const(&ca,0),*blocked=bn?bytes_const(&ba,0):NULL,*targets=bytes_const(&ta,0);
    const int32_t *origins=on?ints_const(&oa,0):NULL,*cost=ints_const(&wa,0);
    if(cost[0]!=0) goto cleanup;
    for(int i=1;i<13;i++) if(cost[i]<0 || cost[i]>128) goto cleanup;
    for(int32_t i=0;i<n;i++) if(cells[i]>=13 || targets[i]>1) goto cleanup;
    parent=malloc((size_t)n*sizeof(int32_t)); blocks=malloc((size_t)n*sizeof(int32_t));
    work=malloc((size_t)n*sizeof(int32_t)); steps=malloc((size_t)n*sizeof(int32_t));
    if(!parent || !blocks || !work || !steps) goto cleanup;
    for(int32_t i=0;i<n;i++) parent[i]=-2;
    for(int64_t i=0;i<on;i++) {
        int32_t cell=origins[i];
        if(cell<0 || cell>=n || !open_cell(cell,cells,blocked,bn) || parent[cell]!=-2) continue;
        parent[cell]=-1; blocks[cell]=0; work[cell]=0; steps[cell]=0;
        if(!excavation_push(&heap,(ExcavationNode){0,0,0,cell})) goto cleanup;
    }
    int32_t found=-1;
    while(heap.size) {
        ExcavationNode node=excavation_pop(&heap); int32_t cell=node.cell;
        if(node.blocks!=blocks[cell] || node.work!=work[cell] || node.steps!=steps[cell]) continue;
        if(targets[cell]) { found=cell; break; }
        for(int d=0;d<4;d++) {
            int32_t next=neighbor(cell,d,(int32_t)w64,(int32_t)n);
            if(next<0 || (next<bn && blocked[next]) || cells[next]==4) continue;
            if(node.work>INT_MAX-cost[cells[next]]) continue;
            ExcavationNode candidate={node.blocks+(cells[next]!=0),node.work+cost[cells[next]],node.steps+1,next};
            if(parent[next]!=-2 && !excavation_less(candidate,(ExcavationNode){blocks[next],work[next],steps[next],next})) continue;
            parent[next]=cell; blocks[next]=candidate.blocks; work[next]=candidate.work; steps[next]=candidate.steps;
            if(!excavation_push(&heap,candidate)) goto cleanup;
        }
    }
    int32_t length=0;
    for(int32_t cell=found;cell>=0;cell=parent[cell]) length++;
    if(!resize(resize_ints,&path,length)) goto cleanup;
    int32_t *result=length?ints_mutable(&path,0):NULL;
    for(int32_t cell=found,index=0;cell>=0;cell=parent[cell]) result[index++]=cell;
    variant_destroy(out); from_ints(out,&path); valid=1;
cleanup:
    free(parent); free(blocks); free(work); free(steps); free(heap.items);
    destroy_bytes(&ca); destroy_bytes(&ba); destroy_ints(&oa); destroy_bytes(&ta); destroy_ints(&wa); destroy_ints(&path);
    if(!valid) return_nil(out);
}
