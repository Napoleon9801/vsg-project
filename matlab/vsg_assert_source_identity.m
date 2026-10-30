function vsg_assert_source_identity(expected)
% Fail if inputs changed during a run or do not match a pinned manifest.
actual=vsg_source_identity({expected.path});
for k=1:numel(expected)
    assert(strcmp(actual(k).sha256,expected(k).sha256),'VSG:SourceChanged', ...
        'Source content changed: %s',expected(k).path);
end
end
