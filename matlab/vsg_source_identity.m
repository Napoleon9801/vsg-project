function identity = vsg_source_identity(paths)
% Record content hashes: Git HEAD alone cannot identify a dirty working tree.
identity = struct('path',{},'sha256',{});
for k=1:numel(paths)
    fid=fopen(paths{k},'rb');
    assert(fid>=0,'VSG:MissingSource','Missing source: %s',paths{k});
    bytes=fread(fid,Inf,'*uint8'); fclose(fid);
    md=java.security.MessageDigest.getInstance('SHA-256');
    md.update(bytes);
    digest=typecast(md.digest(),'uint8');
    identity(k).path=paths{k};
    identity(k).sha256=lower(reshape(dec2hex(digest,2).',1,[]));
end
end
