/* Energy dots do not occupy cells; all consult the same worker occupancy. */
static const GDExtensionVariantType energy_types[]={I,B,I,I,N};
static void energy_call(void *data,void *instance,const void *const *args,int64_t argc,void *out,GDExtensionCallError *error) {
    (void)data; (void)instance;
    if(!validate_args(args,argc,energy_types,5,error)) { return_nil(out); return; }
    Value positions,terrain,occupancy,distances;
    to_ints(&positions,(void *)args[0]); to_bytes(&terrain,(void *)args[1]);
    to_ints(&occupancy,(void *)args[2]); to_ints(&distances,(void *)args[3]);
    int valid=0;
    int64_t n=array_size(size_bytes,&terrain),count=array_size(size_ints,&positions),width=read_int(args[4]);
    if(n<=0 || n>16777216 || width<=0 || width>n || n%width || array_size(size_ints,&occupancy)!=n || array_size(size_ints,&distances)!=n) goto cleanup;
    const uint8_t *cells=bytes_const(&terrain,0);
    const int32_t *occ=ints_const(&occupancy,0),*dist=ints_const(&distances,0);
    int32_t *energy=count?ints_mutable(&positions,0):NULL;
    for(int64_t i=0;i<count;i++) {
        int32_t cell=energy[i]; if(cell<0 || cell>=n || dist[cell]<0) continue;
        for(int d=0;d<4;d++) {
            int32_t dest=neighbor(cell,d,(int32_t)width,(int32_t)n);
            if(dest>=0 && dist[dest]>=0 && dist[dest]<dist[cell] && cells[dest]==0 && occ[dest]==-1) { energy[i]=dest; break; }
        }
    }
    variant_destroy(out); from_ints(out,&positions); valid=1;
cleanup:
    destroy_ints(&positions); destroy_bytes(&terrain); destroy_ints(&occupancy); destroy_ints(&distances);
    if(!valid) return_nil(out);
}
