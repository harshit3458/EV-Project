function [parent,pbranch,order] = build_tree(branch,nbus)

adj = cell(nbus,1);

for k = 1:size(branch,1)
    f = branch(k,1);
    t = branch(k,2);

    adj{f} = [adj{f};t k];
    adj{t} = [adj{t};f k];
end

parent = zeros(nbus,1);
pbranch = zeros(nbus,1);
order = 1;

visited = false(nbus,1);
visited(1) = true;
q = 1;

while ~isempty(q)
    cur = q(1);
    q(1) = [];

    for e = 1:size(adj{cur},1)
        nb = adj{cur}(e,1);
        k = adj{cur}(e,2);

        if ~visited(nb)
            visited(nb) = true;
            parent(nb) = cur;
            pbranch(nb) = k;
            order(end+1) = nb;
            q(end+1) = nb;
        end
    end
end

if any(~visited)
    error('Some buses are disconnected from bus 1.');
end

end