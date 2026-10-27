/* Exact union of four-cell obstacle-depth sight. Sources are seven integers:
 * owner, origin, radius, own footprint x/y/width/height (zero size for units). */
static const GDExtensionVariantType fog_types[]={B,I,N,N};
static int fog_line_clear(const uint8_t *blocking,int32_t w,int32_t x,int32_t y,int32_t tx,int32_t ty,int32_t fx,int32_t fy,int32_t fw,int32_t fh) {
    int32_t dx=abs(tx-x),dy=abs(ty-y),sx=x<tx?1:-1,sy=y<ty?1:-1,err=dx-dy;
    int32_t depth=0;
    while(x!=tx || y!=ty) {
        int32_t twice=err*2;
        if(twice>-dy) { err-=dy; x+=sx; }
        if(twice<dx) { err+=dx; y+=sy; }
        if(!(x>=fx && y>=fy && x<fx+fw && y<fy+fh)) {
            if(depth) depth++;
            else if(blocking[y*w+x]) depth=1;
            if(depth>4) return 0;
        }
        if(x==tx && y==ty) return 1;
    }
    return 1;
}
static void fog_call(void *data,void *instance,const void *const *args,int64_t argc,void *out,GDExtensionCallError *error) {
    (void)data; (void)instance;
    if(!validate_args(args,argc,fog_types,4,error)) { return_nil(out); return; }
    Value ba,sa,result;
    to_bytes(&ba,(void *)args[0]); to_ints(&sa,(void *)args[1]);
    int64_t n=array_size(size_bytes,&ba),sn=array_size(size_ints,&sa),factions=read_int(args[2]),width=read_int(args[3]);
    uint8_t *seen=NULL;
    int32_t *cells=NULL;
    int64_t counts[256]={0};
    int valid=0;
    if(n<=0 || n>16777216 || width<=0 || width>n || n%width || sn%7 || sn>7000000 || factions<=0 || factions>256 || n>16777216/factions) goto cleanup;
    const int32_t *sources=sn?ints_const(&sa,0):NULL;
    for(int64_t i=0;i<sn;i+=7) {
        if(sources[i]<0 || sources[i]>=factions || sources[i+1]<0 || sources[i+1]>=n || sources[i+2]<0 || sources[i+2]>64) goto cleanup;
        int64_t x=sources[i+3],y=sources[i+4],fw=sources[i+5],fh=sources[i+6];
        if(x<0 || y<0 || fw<0 || fh<0 || x+fw>width || y+fh>n/width || (!fw != !fh)) goto cleanup;
        if(fw && (sources[i+1]%width<x || sources[i+1]%width>=x+fw || sources[i+1]/width<y || sources[i+1]/width>=y+fh)) goto cleanup;
    }
    seen=calloc((size_t)(n*factions),1);
    cells=malloc((size_t)(n*factions)*sizeof(int32_t));
    if(!seen || !cells) goto cleanup;
    const uint8_t *blocking=bytes_const(&ba,0);
    int32_t w=(int32_t)width,h=(int32_t)(n/width);
    for(int64_t i=0;i<sn;i+=7) {
        int32_t owner=sources[i],origin=sources[i+1],r=sources[i+2],ox=origin%w,oy=origin/w;
        int32_t left=ox>r?ox-r:0,right=ox+r+1<w?ox+r+1:w;
        int32_t top=oy>r?oy-r:0,bottom=oy+r+1<h?oy+r+1:h;
        uint8_t *mask=seen+(size_t)owner*n;
        int32_t *list=cells+(size_t)owner*n;
        for(int32_t y=top;y<bottom;y++) for(int32_t x=left;x<right;x++) {
            int32_t cell=y*w+x,dx=x-ox,dy=y-oy;
            if(mask[cell] || dx*dx+dy*dy>r*r) continue;
            if(fog_line_clear(blocking,w,ox,oy,x,y,sources[i+3],sources[i+4],sources[i+5],sources[i+6])) { mask[cell]=1; list[counts[owner]++]=cell; }
        }
    }
    new_array(&result,NULL);
    if(!resize(resize_array,&result,factions)) { destroy_array(&result); goto cleanup; }
    for(int64_t owner=0;owner<factions;owner++) {
        Value list;
        new_ints(&list,NULL);
        if(!resize(resize_ints,&list,counts[owner])) { destroy_ints(&list); destroy_array(&result); goto cleanup; }
        if(counts[owner]) memcpy(ints_mutable(&list,0),cells+(size_t)owner*n,(size_t)counts[owner]*sizeof(int32_t));
        void *item=array_at(&result,owner);
        variant_destroy(item); from_ints(item,&list);
        destroy_ints(&list);
    }
    variant_destroy(out); from_array(out,&result); destroy_array(&result); valid=1;
cleanup:
    free(seen); free(cells); destroy_bytes(&ba); destroy_ints(&sa);
    if(!valid) return_nil(out);
}
