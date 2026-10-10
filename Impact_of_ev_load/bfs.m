function [V,loss] = bfs(Pd,Qd,parent,pbranch,order,R,X,baseMVA)

nbus = length(Pd);
nbr = length(R);

S = complex(Pd,Qd)/(1000*baseMVA);
V = ones(nbus,1);

for iter = 1:100
    Vold = V;
    I = complex(zeros(nbr,1));
    Idown = complex(zeros(nbus,1));

    % Backward sweep
    for idx = length(order):-1:2
        j = order(idx);

        I(pbranch(j)) = conj(S(j)/V(j)) + Idown(j);
        Idown(parent(j)) = ...
            Idown(parent(j)) + I(pbranch(j));
    end

    % Forward sweep
    for idx = 2:length(order)
        j = order(idx);
        k = pbranch(j);

        V(j) = V(parent(j)) - I(k)*complex(R(k),X(k));
    end

    if max(abs(V-Vold)) < 1e-8
        break;
    end
end

if iter == 100 && max(abs(V-Vold)) >= 1e-8
    error('Load flow failed to converge.');
end

loss = sum(abs(I).^2.*R)*baseMVA*1000;

end

